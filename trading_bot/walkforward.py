from __future__ import annotations

from dataclasses import replace

import pandas as pd

from .config import BotConfig
from .engine import SessionClockExecutionBot
from .backtest import BacktestRunner


def rolling_walk_forward(
    data: pd.DataFrame,
    base_cfg: BotConfig,
    layer_steps: list[float],
    adx_thresholds: list[float],
    folds: int = 3,
    train_months: int = 3,
    test_months: int = 1,
) -> list[dict]:
    monthly = data.groupby(pd.Grouper(freq="MS"))
    month_keys = [k for k, v in monthly if not v.empty]
    results = []

    for i in range(folds):
        train_start = i
        train_end = train_start + train_months
        test_end = train_end + test_months
        if test_end > len(month_keys):
            break

        train_idx = month_keys[train_start:train_end]
        test_idx = month_keys[train_end:test_end]
        train_df = data[data.index.to_period("M").isin([m.to_period("M") for m in train_idx])]
        test_df = data[data.index.to_period("M").isin([m.to_period("M") for m in test_idx])]

        best = None
        for step in layer_steps:
            for adx in adx_thresholds:
                cfg = replace(base_cfg)
                cfg.dca.layer_step_atr = step
                cfg.entry.adx_trade_threshold = adx
                bt = BacktestRunner(SessionClockExecutionBot(cfg, log_dir="logs"))
                metric = bt.run(train_df)["profit_factor"]
                if best is None or metric > best[0]:
                    best = (metric, step, adx)

        cfg = replace(base_cfg)
        cfg.dca.layer_step_atr = best[1]
        cfg.entry.adx_trade_threshold = best[2]
        test_bt = BacktestRunner(SessionClockExecutionBot(cfg, log_dir="logs"))
        test_result = test_bt.run(test_df)
        results.append({"fold": i + 1, "best_layer_step": best[1], "best_adx": best[2], **test_result})

    return results
