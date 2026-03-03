from dataclasses import dataclass, field
from datetime import time


@dataclass(slots=True)
class SessionConfig:
    asia_start: time = time(8, 0)
    asia_end: time = time(11, 30)
    eu_start: time = time(13, 0)
    eu_end: time = time(16, 30)
    us_start: time = time(19, 0)
    us_end: time = time(22, 30)


@dataclass(slots=True)
class RiskConfig:
    initial_capital: float = 30_000.0
    daily_dd_limit_pct: float = 0.02
    intraday_peak_dd_pct: float = 0.015
    total_dd_limit_pct: float = 0.08
    daily_profit_cap_pct: float = 0.01


@dataclass(slots=True)
class DCAConfig:
    max_layers: int = 10
    fixed_lot_per_layer: float = 0.30
    max_total_lot: float = 3.0
    layer_step_atr: float = 0.35
    kill_switch_atr: float = 3.0


@dataclass(slots=True)
class EntryConfig:
    spread_max_pips: float = 2.0
    adx_trade_threshold: float = 20.0
    adx_no_trade_threshold: float = 18.0
    rsi_m15_buy_threshold: float = 30.0
    rsi_m15_sell_threshold: float = 70.0


@dataclass(slots=True)
class BotConfig:
    symbol: str = "EURUSD"
    timezone: str = "Asia/Ho_Chi_Minh"
    max_trades_per_day: int = 6
    hard_time_stop_hours: int = 12
    quick_window_min_age: int = 5
    quick_window_max_age: int = 29
    quick_profit_usd: float = 20.0
    early_loss_cut_usd: float = -20.0
    session: SessionConfig = field(default_factory=SessionConfig)
    risk: RiskConfig = field(default_factory=RiskConfig)
    dca: DCAConfig = field(default_factory=DCAConfig)
    entry: EntryConfig = field(default_factory=EntryConfig)
