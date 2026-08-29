# E2 Status

## ADXBB Sprint 1 — strategy-free core

E2 is stripped to a compiling, runnable, non-trading core in preparation for ADXBB. The active runtime contains no strategy engine, candidates, trade-request producer, opening-range/session/weekday machinery, news runtime, custom visual subsystem, strategy recovery, preset, or strategy CSV output.

Retained foundations are explicit M5 completed-candle access, environment and symbol/account metadata, MT5-native monetary sizing, generic order requests, execution safety/executor, magic-number ownership, logging, CSV mechanics, minimal reporting, and generic input/core/risk verification.

ADXBB is specified but not implemented. Sprint 2 is the first authorized signal-engine sprint. `InpOneTradePerDay`, ADX/DMI, Bollinger Bands, strategy ATR, ADXBB recovery, and ADXBB SIGNALS/TRADES schemas do not exist at runtime.

The frozen historical strategy and its documentation remain available through Git history/releases. No new tag or release is created by Sprint 1.
