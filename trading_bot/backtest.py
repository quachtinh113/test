from __future__ import annotations

from collections import defaultdict

import pandas as pd

from .engine import SessionClockExecutionBot
from .strategy import IndicatorSnapshot


class BacktestRunner:
    def __init__(self, bot: SessionClockExecutionBot) -> None:
        self.bot = bot

    def run(self, data: pd.DataFrame) -> dict:
        equity_curve: list[tuple[pd.Timestamp, float]] = []
        for ts, row in data.iterrows():
            snapshot = IndicatorSnapshot(
                ema50_h1=row["ema50_h1"],
                ema200_h1=row["ema200_h1"],
                rsi14_h1=row["rsi14_h1"],
                rsi5_m15=row["rsi5_m15"],
                adx_h1=row["adx_h1"],
                atr_h1=row["atr_h1"],
                spread_pips=row["spread_pips"],
            )
            self.bot.on_minute(ts.to_pydatetime(), snapshot, row["close"])
            equity_curve.append((ts, self.bot.state.equity))

        eq_df = pd.DataFrame(equity_curve, columns=["timestamp", "equity"]).set_index("timestamp")
        dd = (eq_df["equity"].cummax() - eq_df["equity"]).max() if not eq_df.empty else 0.0

        session_perf = defaultdict(float)
        hour_perf = defaultdict(float)
        for t in self.bot.closed_trades:
            session_perf[t.session] += t.gross_pnl
            hour_perf[t.hour_block] += t.gross_pnl

        return {
            "equity_curve": eq_df,
            "max_drawdown": dd,
            "winrate": self.bot.stats()["winrate"],
            "profit_factor": self.bot.stats()["profit_factor"],
            "avg_basket_duration": self.bot.stats()["avg_basket_duration_min"],
            "avg_layers_used": self.bot.stats()["avg_layers_used"],
            "performance_by_session": dict(session_perf),
            "performance_by_hour_block": dict(hour_perf),
        }
