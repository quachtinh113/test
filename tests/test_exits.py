from datetime import datetime, timedelta, timezone

from trading_bot.config import BotConfig
from trading_bot.exits import ExitRules
from trading_bot.models import Basket, Layer


def _basket(age_min: int) -> tuple[Basket, datetime]:
    now = datetime.now(timezone.utc)
    opened = now - timedelta(minutes=age_min)
    b = Basket(side="BUY", opened_at=opened, l1_price=1.1, atr_at_open=0.002)
    b.layers.append(Layer(timestamp=opened, price=1.1, lot=0.3))
    return b, now


def test_quick_profit_exit():
    rules = ExitRules(BotConfig())
    basket, now = _basket(10)
    assert rules.evaluate(basket, now, total_pnl=25, kill_switch=False) == "quick_profit_window"


def test_hard_time_stop_exit():
    rules = ExitRules(BotConfig())
    basket, now = _basket(13 * 60)
    assert rules.evaluate(basket, now, total_pnl=-1, kill_switch=False) == "hard_time_stop"
