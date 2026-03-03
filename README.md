# Session Clock Execution Bot (EURUSD)

Trading bot architecture for a 30,000 USD account using trend + pullback entries, bounded DCA, and strict risk controls.

## Features
- Evaluate entries only at minute `00` and `30` in VN sessions (Asia/Europe/US windows).
- One active basket at a time.
- DCA hybrid: ATR-based spacing with lot and layer caps.
- Kill switch at adverse move > `3.0 ATR` from L1 and 24h cooldown.
- Risk guard for daily DD, intraday peak DD, total DD, and daily profit cap.
- Event-driven minute engine with basket monitoring every minute.
- CSV and app logging:
  - `logs/app.log`
  - `logs/trades.csv`

## Package Structure
- `trading_bot/config.py`: runtime and risk parameters.
- `trading_bot/time_filter.py`: session-clock and half-hour gate.
- `trading_bot/strategy.py`: trend/pullback signal logic.
- `trading_bot/dca.py`: layer spacing and kill-switch detection.
- `trading_bot/exits.py`: prioritized basket exits.
- `trading_bot/risk.py`: equity and drawdown guards.
- `trading_bot/engine.py`: event loop and execution state machine.
- `trading_bot/backtest.py`: returns equity curve and requested metrics.
- `trading_bot/walkforward.py`: rolling 3M train / 1M test optimization.

## Quick Start
```bash
python -m pip install -U pandas pytest
pytest -q
```

For backtest input, prepare minute-indexed DataFrame with columns:
`close, ema50_h1, ema200_h1, rsi14_h1, rsi5_m15, adx_h1, atr_h1, spread_pips`.
