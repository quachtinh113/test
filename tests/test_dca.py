from datetime import datetime, timezone

from trading_bot.config import DCAConfig
from trading_bot.dca import DCAEngine
from trading_bot.models import Basket, Layer


def _basket(side: str = "BUY") -> Basket:
    b = Basket(side=side, opened_at=datetime.now(timezone.utc), l1_price=1.1, atr_at_open=0.002)
    b.layers.append(Layer(timestamp=b.opened_at, price=1.1, lot=0.3))
    return b


def test_dca_spacing_buy():
    engine = DCAEngine(DCAConfig(layer_step_atr=0.35))
    basket = _basket("BUY")
    expected = 1.1 - 0.35 * 0.002
    assert abs(engine.next_layer_price(basket) - expected) < 1e-9


def test_kill_switch_triggered():
    engine = DCAEngine(DCAConfig(kill_switch_atr=3.0))
    basket = _basket("BUY")
    assert engine.kill_switch_triggered(basket, 1.0939)
