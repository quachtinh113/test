from __future__ import annotations

from .config import DCAConfig
from .models import Basket


class DCAEngine:
    def __init__(self, cfg: DCAConfig) -> None:
        self.cfg = cfg

    def next_layer_price(self, basket: Basket) -> float:
        step = self.cfg.layer_step_atr * basket.atr_at_open
        if basket.side == "BUY":
            return basket.last_entry_price - step
        return basket.last_entry_price + step

    def should_add_layer(self, basket: Basket, market_price: float) -> bool:
        if len(basket.layers) >= self.cfg.max_layers:
            return False
        if basket.total_lot + self.cfg.fixed_lot_per_layer > self.cfg.max_total_lot:
            return False
        trigger = self.next_layer_price(basket)
        return market_price <= trigger if basket.side == "BUY" else market_price >= trigger

    def adverse_move_atr(self, basket: Basket, market_price: float) -> float:
        if basket.side == "BUY":
            move = basket.l1_price - market_price
        else:
            move = market_price - basket.l1_price
        return move / basket.atr_at_open if basket.atr_at_open else 0.0

    def kill_switch_triggered(self, basket: Basket, market_price: float) -> bool:
        return self.adverse_move_atr(basket, market_price) > self.cfg.kill_switch_atr
