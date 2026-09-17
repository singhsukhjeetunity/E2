# CSV exports

One folder per strategy, under MT5's shared `Terminal/Common/Files`:

- `E2/GoldSessionFade/`
- `E2/EMAPullback/`
- `E2/CompressionBreakout/`

There are no account, symbol, mode or run subfolders. Filenames identify the symbol, Test/Demo/Live mode, account number and unique run. All files from one run share the same prefix; repeated tests get distinct names. The report log prints the folder location.

| Filename ending | Contents |
|---|---|
| `_Trades_T.csv` | Trade ledger |
| `_Signals_S.csv` | Gold signal outcomes or EMA/compression diagnostic events |
| `_Equity_E.csv` | EMA/compression sampled equity |
| `_Settings.txt` | EMA/compression settings |

Gold exports at shutdown/test completion; EMA and compression export signals/equity during operation and update their trade ledgers after settlement and at shutdown/test completion. Existing CSV columns and strategy identifiers are unchanged.

## Importing

Upload the selected run's `_T.csv` into its journal dataset. For automatic imports, use a filename pattern limited to the intended account/mode/run, for example `E2_v-USTEC_Test_123_<run>_*_T.csv`. Do not use a broad watch when the strategy folder contains multiple accounts or backtests. The default `E2_*_T.csv` is suitable only when every matching report belongs to the selected dataset. Upload gold signals separately; EMA and compression diagnostics/equity are for inspection and analysis.

Existing exports stay where they are; this layout applies to new exports after compilation. Recovery and pending-entry state files are unchanged.

## Combining the trio

Use matching date ranges and verified report clocks, keeping independent backtests as separate journal datasets. The selected allocation is **20:40:40 Gold / EMA / Compression**: at 2% total planned risk on 100,000, use **400 / 800 / 800** fixed risk per trade. Historical files exported at 1000 risk per trade do not automatically represent this allocation. For an external fixed-risk comparison, multiply each trade's net R by its strategy's selected cash risk; do not overwrite original exports. See [the allocation reference](STRATEGY_REFERENCE.md#selected-portfolio-allocation).
