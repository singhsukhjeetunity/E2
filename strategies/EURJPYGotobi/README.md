# EURJPY Gotobi

Retained candidate for further development. Moved into `strategies/EURJPYGotobi/` on user instruction after screening five candidates. EuroFX reversal, daily IBS, S&P failed breakout and DAX gap reversal were rejected; their source/research folders were removed. Historical evidence remains available in Git history. Moving this EA does not change E2's three-system allocation, certify it for live trading or attach it to an account.

## Install and baseline test

Copy this entire folder into `MQL5/Experts/E2/EURJPYGotobi/`, keeping `include/`. Compile `EURJPY_Gotobi.mq5` with MetaEditor. Test EURJPY, M1, real ticks, visual mode/optimisation off. Use a verified historical feed clock: `InpBrokerWinterUTCMinutes`, `InpBrokerDST`, then `InpBrokerClockVerified=true`. A current clock setting does not establish the historical profile.

For comparable screening: 2023–2025, starting USD balance 100000, cash risk 1000, stop 60 pips, safety TP 200 pips, maximum spread 30 broker points, pip size 0 (automatic), one entry/day, Friday flattening on and CSV export on. Positive cash risk overrides percent risk. Standard three-digit EURJPY uses 10 points per pip; size overrides are available for other conventions. Broker commission, financing, slippage and minimum-lot rejection must match intended execution.

## Rules and clocks

Buy at 15:55 UTC on the calendar day before eligible Japanese payment dates; close at 00:55 UTC (09:55 Japan) the following day. Eligible Japanese dates: 5/10/15/20/25/30; weekend dates roll back to the preceding Friday. No nonexistent 30th day. Japanese bank holidays are manual exclusions using `InpExcludedJapaneseDates` as `YYYYMMDD|YYYYMMDD`; no automatic holiday rescheduling. Sunday entries before Monday fixes are skipped. Entries must occur within the fixed 60-second grace window. Stops/targets are pip-based; ATR stop/target inputs are hidden and unused.

Default magic 420603. One owned position per EA/symbol and restart-safe deal-history entry limits. No grid, averaging or martingale. Netting accounts cannot safely host another strategy concurrently on EURJPY. Protective SL is included in the initial order. Timed/fix and Friday exits require tradable ticks; a closed market or disconnected terminal can delay closure. Fixed Friday flatten is 20:00 UTC. Defaults are starting points, not optimised parameters.

## Reports

Automatic CSV output now goes to `Terminal/Common/Files/E2/EURJPYGotobi/`. The Journal prints the absolute location. Unique filenames include symbol, mode, account and run ID:

- `_Trades_T.csv`: E2 ledger columns, one position per row, actual-entry cash risk and net R, partial fills/exits, commission/swap/fees. Historical owned entries and manual/broker exits are reconstructed. Unassignable account-level charges cannot be allocated to a position.
- `_Equity_E.csv`: account equity, balance and free margin, approximately once per minute. Samples do not capture every intraminute drawdown. Live samples include the whole account.
- `_Settings.csv`: strategy, clock and risk configuration.

Backtests buffer equity writes and finalize the trade ledger at completion/shutdown. Live/demo ledger refresh and flush behavior are unchanged. Use local tester agents for local reports. Unexpected process termination can leave buffered output incomplete. Original entry-risk conversion snapshots are in memory: after a live restart, old entries retain recovered P&L but risk/R can be blank with `INITIAL_RISK_UNAVAILABLE`; no current conversion is passed off as the historical initial risk. Existing exports from the old research location are not moved or deleted.

## Status and next work

[Observed baseline](BASELINE.md): 709 trades, +49.82R, PF 1.40 over 2016–2025. The 2023–2025 subset has 212 trades, +10.21R, PF 1.22. Source costs show zero commission; Japanese holiday exclusions are blank. These results are not independent profitability certification. The remaining initial screen is complete. Next: verify feed clock, data continuity, costs and Japanese calendar, assess a small predeclared robustness set, then evaluate correlation and combined drawdown with E2. Keep 2026 for final out-of-sample evaluation after rules are frozen.

No source entry/exit/risk defaults changed in this relocation. Native MetaEditor compilation, real fills and end-to-end portfolio acceptance remain to verify.

## Portable checks

```sh
python tests/gotobi/run_checks.py
python -m unittest discover -s tests -p 'test_*.py'
```

The portable API shim exercises the actual EA and included runtime, ownership, sizing, export/recovery, clocks and session reconstruction. It is not an MQL5 compiler or a broker-fill simulator. Incremental completed-session reconstruction is checked against full-window rebuilds across year/DST changes and a missing session. The production trio's files are unchanged.
