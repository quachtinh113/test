from __future__ import annotations

import csv
import logging
from dataclasses import asdict
from datetime import datetime
from pathlib import Path

from .config import BotConfig
from .dca import DCAEngine
from .exits import ExitRules
from .models import Basket, Layer, TradeRecord
from .risk import RiskGuard
from .strategy import EntryStrategy, IndicatorSnapshot
from .time_filter import SessionClock

PIP_VALUE_PER_LOT = 10.0
PIP_SIZE = 0.0001


class SessionClockExecutionBot:
    def __init__(self, cfg: BotConfig | None = None, log_dir: str = "logs") -> None:
        self.cfg = cfg or BotConfig()
        self.clock = SessionClock(self.cfg.session, self.cfg.timezone)
        self.strategy = EntryStrategy(self.cfg.entry)
        self.dca = DCAEngine(self.cfg.dca)
        self.exits = ExitRules(self.cfg)
        self.risk = RiskGuard(self.cfg.risk)
        self.state = self.risk.init_state()
        self.active_basket: Basket | None = None
        self.closed_trades: list[TradeRecord] = []
        self.trades_today = 0
        self.last_block_traded: tuple[datetime.date, str] | None = None
        self._setup_logging(log_dir)

    def _setup_logging(self, log_dir: str) -> None:
        Path(log_dir).mkdir(parents=True, exist_ok=True)
        self.logger = logging.getLogger("session_clock_bot")
        self.logger.setLevel(logging.INFO)
        if not self.logger.handlers:
            fh = logging.FileHandler(Path(log_dir) / "app.log")
            fh.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
            self.logger.addHandler(fh)
        self.csv_path = Path(log_dir) / "trades.csv"
        if not self.csv_path.exists():
            with self.csv_path.open("w", newline="") as f:
                writer = csv.DictWriter(
                    f,
                    fieldnames=[
                        "open_time",
                        "close_time",
                        "side",
                        "layers",
                        "gross_pnl",
                        "reason",
                        "duration_minutes",
                        "session",
                        "hour_block",
                    ],
                )
                writer.writeheader()

    def _mark_to_market_pnl(self, basket: Basket, price: float) -> float:
        pnl = 0.0
        for layer in basket.layers:
            pips = (price - layer.price) / PIP_SIZE if basket.side == "BUY" else (layer.price - price) / PIP_SIZE
            pnl += pips * layer.lot * PIP_VALUE_PER_LOT
        return pnl

    def _open_basket(self, ts: datetime, side: str, price: float, atr: float) -> None:
        basket = Basket(side=side, opened_at=ts, l1_price=price, atr_at_open=atr)
        basket.layers.append(Layer(timestamp=ts, price=price, lot=self.cfg.dca.fixed_lot_per_layer))
        self.active_basket = basket
        self.trades_today += 1
        self.last_block_traded = (ts.astimezone().date(), self.clock.hour_block(ts))
        self.logger.info("OPEN %s @ %.5f", side, price)

    def _close_basket(self, ts: datetime, price: float, reason: str) -> None:
        basket = self.active_basket
        if basket is None:
            return
        pnl = self._mark_to_market_pnl(basket, price)
        basket.closed_at = ts
        basket.closed_reason = reason
        self.risk.apply_realized_pnl(self.state, pnl)

        session = self.clock.session_name(basket.opened_at) or "OFF"
        record = TradeRecord(
            open_time=basket.opened_at,
            close_time=ts,
            side=basket.side,
            layers=len(basket.layers),
            gross_pnl=pnl,
            reason=reason,
            duration_minutes=basket.age_minutes(ts),
            session=session,
            hour_block=self.clock.hour_block(basket.opened_at),
        )
        self.closed_trades.append(record)
        with self.csv_path.open("a", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(asdict(record).keys()))
            writer.writerow(asdict(record))
        if reason == "kill_switch":
            self.risk.apply_kill_switch_cooldown(self.state, ts, 24)
        self.risk.evaluate_limits(self.state)
        self.logger.info("CLOSE %s pnl=%.2f reason=%s", basket.side, pnl, reason)
        self.active_basket = None

    def on_minute(self, ts: datetime, snapshot: IndicatorSnapshot, price: float) -> None:
        if ts.minute == 0 and ts.hour == 0:
            self.trades_today = 0
            self.risk.reset_day(self.state)

        if self.active_basket:
            basket = self.active_basket
            if self.dca.should_add_layer(basket, price):
                basket.layers.append(Layer(timestamp=ts, price=price, lot=self.cfg.dca.fixed_lot_per_layer))
                self.logger.info("ADD_LAYER side=%s price=%.5f layers=%s", basket.side, price, len(basket.layers))

            pnl = self._mark_to_market_pnl(basket, price)
            kill_switch = self.dca.kill_switch_triggered(basket, price)
            exit_reason = self.exits.evaluate(basket, ts, pnl, kill_switch)
            if exit_reason:
                self._close_basket(ts, price, exit_reason)
            return

        if not self.risk.can_trade(self.state, ts):
            return
        if self.trades_today >= self.cfg.max_trades_per_day:
            return
        if not self.clock.can_evaluate_entry(ts):
            return
        block_key = (ts.astimezone().date(), self.clock.hour_block(ts))
        if self.last_block_traded == block_key:
            return

        signal = self.strategy.generate_signal(snapshot)
        if signal in ("BUY", "SELL"):
            self._open_basket(ts, signal, price, snapshot.atr_h1)

    def stats(self) -> dict:
        trades = self.closed_trades
        wins = [t for t in trades if t.gross_pnl > 0]
        losses = [t for t in trades if t.gross_pnl < 0]
        gross_win = sum(t.gross_pnl for t in wins)
        gross_loss = -sum(t.gross_pnl for t in losses)
        profit_factor = gross_win / gross_loss if gross_loss else float("inf")
        avg_duration = sum(t.duration_minutes for t in trades) / len(trades) if trades else 0.0
        avg_layers = sum(t.layers for t in trades) / len(trades) if trades else 0.0
        return {
            "equity": self.state.equity,
            "trades": len(trades),
            "winrate": len(wins) / len(trades) if trades else 0.0,
            "profit_factor": profit_factor,
            "avg_basket_duration_min": avg_duration,
            "avg_layers_used": avg_layers,
        }
