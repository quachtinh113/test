from __future__ import annotations

from datetime import datetime, timedelta

from .config import RiskConfig
from .models import RiskState


class RiskGuard:
    def __init__(self, cfg: RiskConfig) -> None:
        self.cfg = cfg

    def init_state(self) -> RiskState:
        eq = self.cfg.initial_capital
        return RiskState(equity=eq, day_start_equity=eq, day_peak_equity=eq)

    def reset_day(self, state: RiskState) -> None:
        state.day_start_equity = state.equity
        state.day_peak_equity = state.equity
        state.stop_for_day = False

    def can_trade(self, state: RiskState, now: datetime) -> bool:
        if state.stop_for_day:
            return False
        if state.trading_paused_until and now < state.trading_paused_until:
            return False
        return True

    def apply_realized_pnl(self, state: RiskState, pnl: float) -> None:
        state.equity += pnl
        state.day_peak_equity = max(state.day_peak_equity, state.equity)

    def evaluate_limits(self, state: RiskState) -> str | None:
        daily_pnl = state.equity - state.day_start_equity
        peak_pullback = state.day_peak_equity - state.equity
        total_drawdown = self.cfg.initial_capital - state.equity

        if daily_pnl >= self.cfg.initial_capital * self.cfg.daily_profit_cap_pct:
            state.stop_for_day = True
            return "daily_profit_cap"
        if -daily_pnl >= self.cfg.initial_capital * self.cfg.daily_dd_limit_pct:
            state.stop_for_day = True
            return "daily_dd_limit"
        if peak_pullback >= self.cfg.initial_capital * self.cfg.intraday_peak_dd_pct:
            state.stop_for_day = True
            return "intraday_peak_dd"
        if total_drawdown >= self.cfg.initial_capital * self.cfg.total_dd_limit_pct:
            state.stop_for_day = True
            return "total_dd_limit"
        return None

    def apply_kill_switch_cooldown(self, state: RiskState, now: datetime, hours: int = 24) -> None:
        state.trading_paused_until = now + timedelta(hours=hours)
