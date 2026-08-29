# E2 Status

## ADXBB Sprint 2 — indicator equivalence and signal engine

E2 now contains a completed-M5 observational ADXBB signal engine using custom Pine-style DMI/ADX and ATR RMA calculations plus population-standard-deviation Bollinger Bands. Candidates freeze the full indicator snapshot, ATR risk distance, and immediate-next-M5 execution window. Consecutive qualifying candles remain independent.

Retained foundations are explicit M5 completed-candle access, environment and symbol/account metadata, MT5-native monetary sizing, generic order requests, execution safety/executor, magic-number ownership, logging, CSV mechanics, minimal reporting, and generic input/core/risk verification.

There is no planner or order-producing path. `InpOneTradePerDay`, sizing requests, quote/stop planning, execution integration, ADXBB recovery, and production SIGNALS/TRADES schemas do not exist. The optional CSV is validation-only and documented in [ADXBB_INDICATOR_VALIDATION.md](ADXBB_INDICATOR_VALIDATION.md).

The frozen historical strategy and its documentation remain available through Git history/releases. No new tag or release is created by Sprint 1.
