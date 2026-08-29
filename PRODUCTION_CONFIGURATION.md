# E2 ADXBB Production Configuration

Attach E2 to an M5 chart or run it in the Strategy Tester on M5. Initialization rejects other chart timeframes.

With `InpTradingEnabled=true`, a fresh candidate can produce one market attempt in its immediate next M5 candle. Entry is initially SL-protected; TP is then attached from the authoritative fill and immutable Original R. `InpOneTradePerDay=false` allows sequential same-day fills after closure; `true` locks the symbol/server-date after the first successful fill.

At shutdown, the signal, indicator, plan, execution, Original-R, day-lock, recovery, reconciliation, and financial blocks audit the complete lifecycle. `[E2_INPUT_VERIFY]` must show 22 inputs and zero mapping defects.

No custom chart objects are created. When `InpCsvExportEnabled=true`, paired production files use `E2_<SYMBOL>_<MMDD>_<HASH4>_S.csv` and `_T.csv` under Common Files `E2\Reports`. If either requested member exists, both advance together to `_2`, `_3`, and so on. The full run ID and eight-character configuration hash remain authoritative inside the datasets.

ADXBB’s mechanical contract is [ADXBB_STRATEGY.md](ADXBB_STRATEGY.md). Reporting and financial realized-R details are in [ADXBB_REPORTING.md](ADXBB_REPORTING.md).
