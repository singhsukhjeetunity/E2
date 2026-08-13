# E2 Status, Reporting, and Technical Debt

## Verified state

The modular foundation, multi-timeframe data, H4 trend/range, H1 zones, M15 confirmation, session filter, risk/planning, native MT5 execution, spread correction, existing-position short-circuit, finalized trade reporting, unresolved-trade correction, and Sprint 6.1 summary are implemented. Sprint 6.1 was verified using this engineering case:

| EURUSD, 2025.12.24–2025.12.27 | Value |
|---|---:|
| Finalized trades / wins / losses | 2 / 1 / 1 |
| Win rate | 50.00% |
| Net R / average R | 0.9349 / approximately 0.4675 |
| Profit factor / maximum R drawdown | 1.9150 / 1.00R |
| Finalized-trade net profit | 92.23 |
| Open or unresolved | 1 |
| MT5 final balance / account net change | 10124.48 / 124.48 |
| Reconciliation difference | 32.25 |

This tiny case is an engineering verification only, not evidence of profitability or edge.

## Trade CSV

`E2_trades_<symbol>_<run-id>.csv` contains finalized rows only. Its schema is:

`trade_id, symbol, direction, zone_id, zone_role, zone_visit, signal_time, confirmation_time, entry_time, exit_time, session, trend, adx, confirmation_engulfing, confirmation_pin, confirmation_momentum, confirmation_previous_break, planned_entry, fill_price, stop_loss, take_profit, stop_pips, planned_rr, volume, equity_at_entry, target_risk, planned_actual_risk, planned_risk_pct, exit_price, exit_reason, gross_profit, commission, swap, fees, net_profit, realized_r, holding_minutes`.

`realized_r = net_profit / planned_actual_risk` when planned risk is valid. Exit/P&L values originate from MT5 deals, not candle-price reconstruction.

## Summary CSV

`E2_summary_<symbol>_<run-id>.csv` contains one tester-run row. It includes finalized-trade counts and outcomes; gross/net money; Net/Average/Median/expectancy R; average win/loss, best/worst R; profit factor; consecutive outcomes; chronological R drawdown; holding-time statistics; long/short, session, exit-reason, and ADX breakdowns; unresolved count; initial/final MT5 account values; reconciliation fields; and the strategy-critical configuration snapshot.

Wins/losses/breakeven use realized-R epsilon `1e-8`. Sequence metrics sort by `exit_time`, then `position_id`. Profit factor is `INF` for a positive-profit zero-loss run and `NA` if undefined. Median is statistical median. R drawdown is peak-to-trough cumulative realized R, not MT5 intratrade equity drawdown; its percentage is `NA` when cumulative R makes that percentage ambiguous.

`FinalizedTradeNetProfit` is the E2 finalized-trade sum. `AccountNetChange = FinalBalance - InitialDeposit`; `ReconciliationDifference = AccountNetChange - FinalizedTradeNetProfit`. It is diagnostic and may legitimately be non-zero—for example, where a Tester forced-close is not authoritatively observable before EA shutdown and is excluded from finalized E2 data.

## News-filter status

Sprint 4.6 historical news filtering is runtime verified. `E2NewsFilter` reads a deterministic cached FILE_COMMON CSV with UTC event times, explicit broker UTC offset, currency relevance, impact selection, inclusive blackout buffers, and fail-closed validation. It runs before setup consumption; a rejected candidate can preserve an ARMED visit. The operational CSV must be maintained in MT5 common files.

## Technical debt and limitations

- Historical news CSV path/data maintenance is operationally required.
- Broker UTC offset is fixed for a run and must be configured correctly.
- Entry metadata is in memory and is lost across EA/process restart.
- Tester forced-close deal availability before EA shutdown is not guaranteed; unresolved trades are excluded, never fabricated.
- No large-sample, robustness, out-of-sample, walk-forward, multi-pair/regime, or forward/live validation has been completed.
- Sprint 6.2 audit-only visualization is implemented but manually runtime-unverified; visual correctness and enabled-vs-disabled result parity require Strategy Tester validation.
- Sprint 6.2.1 adds H4/H1/M15 object visibility, compact labels, and optional trade-focus clutter reduction. It is manually runtime-unverified. Tester exposes one EA chart, so auditing uses timeframe switching rather than three programmatically controlled simultaneous charts.
- Sprint 6.2.2 replaces the weak boolean focus behavior with Strategy Audit, All Trades, and Single Trade audit modes. It is implemented but manually runtime-unverified.
- Sprint 6.2.3 adds a non-interactive E2VIS audit-view instruction. MT5's native timeframe selector on the same E2-attached chart is the supported H4/H1/M15 audit switch; E2 deliberately does not call `ChartSetSymbolPeriod` during an active test because it can reinitialize the EA. Separate Tester chart tabs are not synchronized E2 audit charts. It is implemented but manually runtime-unverified.
- Sprint 6.3 source audit is complete; [INTEGRITY_AUDIT.md](INTEGRITY_AUDIT.md) records PASS/PASS WITH LIMITATION findings for closed-bar analysis, setup lifecycle, filters, planning/execution, reporting, summary, and visualizer isolation. It remains manually runtime-unverified pending visual/headless parity, deterministic repeat-run, fixture, and MT5 deal-history/reconciliation checks.
