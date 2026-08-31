# E2 ADXBB Production Configuration

Attach E2 to an M5 chart or run it in the Strategy Tester on M5. Initialization rejects other chart timeframes.

With `InpTradingEnabled=true`, a qualifying HYBRID_V1_Q50 candidate can produce one market attempt in its immediate next M5 candle. Entry is initially SL-protected; TP is then attached from the authoritative fill and immutable Original R. The fixed production methodology permits one successful entry per symbol and broker/server calendar day.

Weekend Flat Protection is enabled by default. At 30 minutes before the final Friday broker trading-session close, E2 expires any pending setup, blocks new planning and execution, and closes only the position matching the chart symbol and E2 magic number. The gate remains closed until the symbol's next broker trading session. Set `InpWeekendFlatEnabled=false` only when exact legacy weekend behavior is required.

At shutdown, the signal, indicator, plan, execution, Original-R, day-lock, recovery, reconciliation, and financial blocks audit the complete lifecycle. `[E2_INPUT_VERIFY]` must show 13 inputs and zero mapping defects.

No custom chart objects are created. When `InpCsvExportEnabled=true`, paired production files use `E2_<SYMBOL>_<MMDD>_<HASH4>_S.csv` and `_T.csv` under Common Files `E2\Reports`. If either requested member exists, both advance together to `_2`, `_3`, and so on. The full run ID and eight-character configuration hash remain authoritative inside the datasets.

ADXBB’s mechanical contract is [ADXBB_STRATEGY.md](ADXBB_STRATEGY.md). Reporting and financial realized-R details are in [ADXBB_REPORTING.md](ADXBB_REPORTING.md).
