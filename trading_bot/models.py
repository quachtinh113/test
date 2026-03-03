from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Literal

Side = Literal["BUY", "SELL"]


@dataclass(slots=True)
class Layer:
    timestamp: datetime
    price: float
    lot: float


@dataclass(slots=True)
class Basket:
    side: Side
    opened_at: datetime
    l1_price: float
    atr_at_open: float
    layers: list[Layer] = field(default_factory=list)
    closed_at: datetime | None = None
    closed_reason: str | None = None

    @property
    def total_lot(self) -> float:
        return sum(layer.lot for layer in self.layers)

    @property
    def last_entry_price(self) -> float:
        return self.layers[-1].price

    def age_minutes(self, now: datetime) -> int:
        return int((now - self.opened_at).total_seconds() // 60)


@dataclass(slots=True)
class TradeRecord:
    open_time: datetime
    close_time: datetime
    side: Side
    layers: int
    gross_pnl: float
    reason: str
    duration_minutes: int
    session: str
    hour_block: str


@dataclass(slots=True)
class RiskState:
    equity: float
    day_start_equity: float
    day_peak_equity: float
    trading_paused_until: datetime | None = None
    stop_for_day: bool = False
