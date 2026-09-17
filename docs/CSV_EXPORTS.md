# CSV exports

One folder per strategy, under MT5's shared `Terminal/Common/Files`:

- `E2/GoldSessionFade/`
- `E2/EMAPullback/`
- `E2/CompressionBreakout/` (research EA)

There are no account, symbol, mode or run subfolders. Filenames identify the symbol, Test/Demo/Live mode, account number and unique run. All files from one run share the same prefix; repeated tests get distinct names. The report log prints the folder location.

| Filename ending | Contents |
|---|---|
| `_Trades_T.csv` | Trade ledger |
| `_Signals_S.csv` | Gold signal outcomes or EMA/compression diagnostic events |
| `_Equity_E.csv` | EMA/compression sampled equity |
| `_Settings.txt` | EMA/compression settings |

Gold exports at shutdown/test completion; EMA and compression export signals/equity during operation and updates its trade ledger after settlement and at shutdown/test completion. Existing CSV columns and strategy identifiers are unchanged.

## Importing

Upload the selected run's `_T.csv` into its journal dataset. For automatic imports, use a filename pattern limited to the intended account/mode/run, for example `E2_v-USTEC_Test_123_<run>_*_T.csv`. Do not use a broad watch when the strategy folder contains multiple accounts or backtests. The default `E2_*_T.csv` is suitable only when every matching report belongs to the selected dataset. Upload gold signals separately; EMA diagnostics/equity are for inspection and analysis.

Existing exports stay where they are; this layout applies to new exports after compilation. Recovery and pending-entry state files are unchanged.
