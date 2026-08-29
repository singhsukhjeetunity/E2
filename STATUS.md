# E2 Status

## ADXBB Sprint 3 — planning, execution, risk, daily limit, and recovery

E2 now contains a completed-M5 observational ADXBB signal engine using custom Pine-style DMI/ADX and ATR RMA calculations plus population-standard-deviation Bollinger Bands. Candidates freeze the full indicator snapshot, ATR risk distance, and immediate-next-M5 execution window. Consecutive qualifying candles remain independent.

Retained foundations are explicit M5 completed-candle access, environment and symbol/account metadata, MT5-native monetary sizing, generic order requests, execution safety/executor, magic-number ownership, logging, CSV mechanics, minimal reporting, and generic input/core/risk verification.

Sprint 3 adds immediate-next-M5 planning, outward-only SL normalization, MT5-native monetary sizing, generic execution, authoritative fill capture, immutable Original R, fixed-R TP attachment, one-position-per-symbol enforcement, optional successful-fill daily locking, lifecycle reporting, and fail-safe restart recovery. Final production CSV schemas remain deferred.

The frozen historical strategy and its documentation remain available through Git history/releases. No new tag or release is created by Sprint 1.
