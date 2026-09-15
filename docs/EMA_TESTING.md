# EMA pullback testing

Entry: `strategies/EMAPullback/EMA_Pullback_Long.mq5`.
Copy the complete `strategies` tree into `MQL5/Experts/E2` and compile the entry in MetaEditor.

This EA is Strategy Tester only. It accepts any selected symbol, retaining the New York session and US calendar. Baseline: Nasdaq-100 CFD (USTEC/NSXUSD), M30 bars rebuilt from completed M1 bars, long only, EMA 20/50, ATR 14, stop 3 ATR, target 0.5R. See [all settings](STRATEGY_REFERENCE.txt).

1. Load M1 history from the explicit indicator seed (default 2022-01-01 UTC).
2. Select the verified historical broker clock and winter offset; clock UNSET is rejected. The calendar covers 2022–2026.
3. Test using real ticks and the same inputs, data and date range as the baseline. Spread and deviation are raw price units; adjust them deliberately for other instruments.
4. Confirm SL/TP on each entry, entry at the next completed M30 boundary, and no extra entries after the broker session cutoff.
5. Inspect `E2_Trades_T.csv`, `E2_Signals_S.csv` and `E2_Equity_E.csv` in the printed run folder. Long trades must say LONG. Match run IDs before analyzing.
6. Verify no weekend holds or overdue exits. Scheduled exits use the earlier of the cash-session deadline and broker session end minus the configured buffer. More than 60 seconds overdue invalidates a run; failed closes retry every five seconds. Preserve this behavior when comparing results.
7. Run an identical test twice. Each run must create a different folder without overwriting earlier files. Test a symbol with punctuation to verify folder handling.

```sh
python tools/analyze_run.py "<run-folder>/E2_Trades_T.csv" --equity "<run-folder>/E2_Equity_E.csv" --start 2022-07-01 --end 2026-01-01
```

The end date is exclusive. Use actual tester bounds, not the first/last trade dates. The analyzer checks one EMA run, rejects incomplete/flagged trades, and reports closed-trade results and sampled floating drawdown. Its equity input uses the new `equity_r` and `equity_cash` columns. Legacy combined equity files require conversion; do not mix them with this format.

Portable tests cover indicator logic, clock conversion, session deadlines and reporting calculations. MetaEditor compilation, full Strategy Tester regression and broker rejection/retry tests still require MT5. End-of-test liquidation is explicitly flagged.
