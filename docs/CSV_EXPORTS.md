# CSV exports — independent of E2 journal UI

The E2 journal application was retired. **CSV exporters remain active in each EA** for standalone research, spreadsheet analysis, reconciliation and portfolio simulations.

Files are stored under MT5 **Terminal/Common/Files/E2/<Strategy>/**, e.g. `GoldSessionFade`, `CompressionBreakout`, `EURJPYGotobi`, `NQOpeningRange`, `BundDonchian`. Filenames include symbol, mode, account and a unique run identifier.

| Suffix | Content |
|---|---|
| `_Trades_T.csv` | Owned trades with deal-based realized P&L, risk/R where available, commission/swap/fees |
| `_Signals_S.csv` | Diagnostic events or strategy signal decisions, where implemented |
| `_Equity_E.csv` | Sampled equity/strategy P&L, where implemented |
| `_Settings.txt` or `_Settings.csv` | Run configuration and broker-time assumptions |

Existing trade CSV schema fields and strategy identifiers have **not** been intentionally changed by removing the journal UI. Existing export behavior for Gold, EMA, Compression, Gotobi and NQ remains in their EA source.

For comparison, use **one distinct run per strategy and date range**, align exit timestamps in UTC, and calculate cash P&L as trade net R × selected fixed cash risk where R is authoritative. Do not treat the 2.5% nominal risk allocation as a portfolio-wide enforced daily cap.

If an initial-risk field is blank or flagged, do not invent a denominator. Validate broker timestamps and DST before using annual results. New Bund backtests need extra attention to futures rollover, swaps and instrument point value.
