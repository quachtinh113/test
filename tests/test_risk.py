from datetime import datetime, timezone

from trading_bot.config import RiskConfig
from trading_bot.risk import RiskGuard


def test_daily_profit_cap_stops_trading():
    guard = RiskGuard(RiskConfig(initial_capital=30_000, daily_profit_cap_pct=0.01))
    state = guard.init_state()
    guard.apply_realized_pnl(state, 301)
    assert guard.evaluate_limits(state) == "daily_profit_cap"
    assert not guard.can_trade(state, datetime.now(timezone.utc))


def test_total_drawdown_limit():
    guard = RiskGuard(RiskConfig(initial_capital=30_000, daily_dd_limit_pct=0.5, intraday_peak_dd_pct=0.5, total_dd_limit_pct=0.08))
    state = guard.init_state()
    guard.apply_realized_pnl(state, -2400)
    assert guard.evaluate_limits(state) == "total_dd_limit"
