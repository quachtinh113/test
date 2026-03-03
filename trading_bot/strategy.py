from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from .config import EntryConfig

Signal = Literal["BUY", "SELL", "NONE"]


@dataclass(slots=True)
class IndicatorSnapshot:
    ema50_h1: float
    ema200_h1: float
    rsi14_h1: float
    rsi5_m15: float
    adx_h1: float
    atr_h1: float
    spread_pips: float


class EntryStrategy:
    def __init__(self, cfg: EntryConfig) -> None:
        self.cfg = cfg

    def generate_signal(self, data: IndicatorSnapshot) -> Signal:
        if data.spread_pips > self.cfg.spread_max_pips:
            return "NONE"
        if data.adx_h1 < self.cfg.adx_no_trade_threshold:
            return "NONE"
        if data.adx_h1 <= self.cfg.adx_trade_threshold:
            return "NONE"

        if data.ema50_h1 > data.ema200_h1:
            if data.rsi14_h1 >= 50 and data.rsi5_m15 <= self.cfg.rsi_m15_buy_threshold:
                return "BUY"
        elif data.ema50_h1 < data.ema200_h1:
            if data.rsi14_h1 <= 50 and data.rsi5_m15 >= self.cfg.rsi_m15_sell_threshold:
                return "SELL"
        return "NONE"
