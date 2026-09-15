# CSV exports

Both EAs now export under MT5's shared `Terminal/Common/Files` directory:

```text
E2/Reports/<Backtests|Demo|Live>/<broker-server_account>/<strategy>/<symbol>/<run>/
```

Strategy folders are `GoldSessionFade` and `EMAPullback`. Broker and symbol folder names use a `v-` prefix and encode punctuation (for example `v-USTEC`); broker/symbol names remain exact inside the reports. Separate run folders keep repeated tests apart. Gold exports on EA shutdown/test completion. EMA writes signals and sampled equity during the test, then its trade ledger at completion.

| File | Contents |
|---|---|
| `E2_Trades_T.csv` | Closed gold trades; EMA trade ledger including integrity/status fields |
| `E2_Signals_S.csv` | Signal outcomes (gold) or diagnostic events (EMA) |
| `E2_Equity_E.csv` | EMA sampled floating equity, position count and run-failure flag |
| `Settings.txt` | EMA canonical configuration, symbol and reporting clock |

Gold may append a numeric suffix to its paired filenames if needed to avoid a collision. Trade CSV schemas and strategy identifiers stay compatible with existing journal imports. EMA equity is now single-strategy: `run_id,time_utc,equity_r,equity_cash,open_positions,run_failed`.

## Journal automatic imports

The folder watcher now searches subfolders. Use the default `E2_*_T.csv` pattern to import trades from either EA. Point a live/demo watch at the matching account/strategy folder. For backtests, select a **single run folder per dataset**, because different tests of the same account must not be pooled. Gold and EMA clocks must be aligned before combining exports.

Use manual upload for signal reports. The journal's signal importer accepts gold signal outcomes; EMA diagnostic and equity files are intended for inspection/analysis, not journal trade imports. Avoid broad `E2_*.csv` watches on EMA folders.

## Existing installations

Old exports are retained in their existing locations and remain readable. This change affects newly generated reports only. Repoint journal watches to the new folders after compiling the new EAs. A watch at the old mixed `E2/Reports` root would recurse into every account/test, so replace it with a scoped folder.

Recovery state and pending-entry files are operational records, not reports. Their existing locations and behavior are preserved; do not delete them as part of CSV housekeeping.
