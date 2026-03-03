from __future__ import annotations

from datetime import datetime, timedelta

from .config import BotConfig
from .models import Basket


class ExitRules:
    def __init__(self, cfg: BotConfig) -> None:
        self.cfg = cfg

    def evaluate(self, basket: Basket, now: datetime, total_pnl: float, kill_switch: bool) -> str | None:
        age_m = basket.age_minutes(now)
        in_quick_window = self.cfg.quick_window_min_age <= age_m <= self.cfg.quick_window_max_age

        if in_quick_window and total_pnl >= self.cfg.quick_profit_usd:
            return "quick_profit_window"
        if in_quick_window and total_pnl <= self.cfg.early_loss_cut_usd:
            return "early_loss_cut"
        if now - basket.opened_at >= timedelta(hours=self.cfg.hard_time_stop_hours) and total_pnl <= 0:
            return "hard_time_stop"
        if kill_switch:
            return "kill_switch"
        return None
