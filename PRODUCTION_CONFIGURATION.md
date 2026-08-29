# E2 ADXBB Sprint 2 Configuration

Sprint 2 is a signal-validation checkpoint, not a trading release. Attach E2 to an M5 chart or run it in the Strategy Tester on M5. Initialization rejects other chart timeframes.

The core initializes the generic foundations plus the observational ADXBB indicator/signal engine. It may produce candidates, but cannot produce order requests regardless of `InpTradingEnabled` because no planner or execution connection exists.

At shutdown, `[ADXBB_SIGNAL_VERIFY]` and `[ADXBB_INDICATOR_VERIFY]` report signal and calculation integrity. `[E2_CORE_VERIFY]` may report candidates but must report zero requests, attempts, successes, registrations, and finalizations. `[E2_RISK_VERIFY]` must show zero sizing activity. `[E2_INPUT_VERIFY]` must show 21 inputs and zero mapping defects.

No custom chart objects or production strategy CSV files are created. When `InpCsvExportEnabled=true`, the validation-only `E2_ADXBB_<symbol>_M5_INDICATOR_VALIDATION.csv` is written under Common Files.

ADXBB’s mechanical contract is [ADXBB_STRATEGY.md](ADXBB_STRATEGY.md). The transition/removal design is [ADXBB_ARCHITECTURE_AUDIT.md](ADXBB_ARCHITECTURE_AUDIT.md). ADXBB signals, indicators, daily limiting, execution integration, recovery, and final CSV schemas are later-sprint work.
