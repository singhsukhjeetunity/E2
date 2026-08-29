# E2 ADXBB Sprint 3 Configuration

Sprint 3 is a trading implementation checkpoint. Attach E2 to an M5 chart or run it in the Strategy Tester on M5. Initialization rejects other chart timeframes.

With `InpTradingEnabled=true`, a fresh candidate can produce one market attempt in its immediate next M5 candle. Entry is initially SL-protected; TP is then attached from the authoritative fill and immutable Original R. `InpOneTradePerDay=false` allows sequential same-day fills after closure; `true` locks the symbol/server-date after the first successful fill.

At shutdown, the signal/indicator blocks remain, while `[E2_PLAN_VERIFY]`, `[E2_EXEC_VERIFY]`, `[E2_R_VERIFY]`, `[E2_DAY_VERIFY]`, and `[E2_RECOVERY_VERIFY]` audit the Sprint 3 lifecycle. `[E2_INPUT_VERIFY]` must show 22 inputs and zero mapping defects.

No custom chart objects or production strategy CSV files are created. When `InpCsvExportEnabled=true`, the validation-only `E2_ADXBB_<symbol>_M5_INDICATOR_VALIDATION.csv` is written under Common Files.

ADXBB’s mechanical contract is [ADXBB_STRATEGY.md](ADXBB_STRATEGY.md). The transition/removal design is [ADXBB_ARCHITECTURE_AUDIT.md](ADXBB_ARCHITECTURE_AUDIT.md). ADXBB signals, indicators, daily limiting, execution integration, recovery, and final CSV schemas are later-sprint work.
