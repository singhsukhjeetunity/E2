# E2 Status, Reporting, and Technical Debt

## Verified state

**Release baseline: E2 v1.0.0 — Mechanically Verified Backtesting & Execution Engine.** Sprint 6.3 is verified and no Sprint 7 edge research is included in this baseline. Future strategy research and changes belong in later branches and versions. Mechanical verification establishes trustworthy implementation and reporting; it does not establish profitability or trading edge.

**Development line: E2 v1.1.0-alpha.** Sprint 1.1 is runtime regression-verified. Sprint 1.2 H4 Regime Engine V2 is implemented but not runtime-verified. It reconstructs causal H4 research state in parallel and remains isolated from the v1.0 strategy, sessions, risk base, planning, execution, reporting, and visualization behavior. The v1.0.0 tag remains the recovery guarantee.

Sprint 1.2 verification support adds an H4-only read-only visual audit overlay behind `InpVisualShowH4RegimeV2` (default `true`). It remains part of the unverified Sprint 1.2 diagnostic surface and cannot influence engine or trading state.

Sprint 1.3.1 H1 Zone V2 corrective repair is implemented but not runtime-verified. It replaces the combinatorial historical-pair expansion with one nearest qualifying prior same-role source pivot per newly qualified pivot, preserves thresholds and closed-bar causality, and adds role-lifecycle verification counts. H4/H1/TC updates are source-bar gated; the M15 median is reused once per candidate candle; TC confirmation is restricted to active retests. It remains isolated from the existing v1.0 zone/strategy/setup/planning/execution/reporting path.

Sprint 1.4 Objective M15 Confirmation Engine is implemented but not runtime-verified. `E2M15ConfirmationEngine` is a parallel completed-M15 research layer that consumes immutable H1 Zone V2 context, uses a preceding-20 median-body benchmark, and produces four detailed pass/fail snapshots. `InpVisualShowM15ConfirmationV2` (default `true`) enables passed-only M15 audit markers. The active v1.0 strategy continues to use `E2ConfirmationAnalyzer`; no V2 confirmation can alter trading, reporting, or account state.

Sprint 1.5 Trend Continuation V2 is implemented but not runtime-verified. It emits research candidates only and cannot place or influence trades.

Sprint 1.6 Trend Continuation V2 planning is implemented and compile-verified, with runtime verification pending. Candidates receive a single next-M15 research plan attempt using entry-time H4/session/news/exposure/quote checks, confirmation-frozen H1 ATR stops, causal active opposing-zone targets, available-R management routing, and fixed-initial-balance risk. No V2 order submission or later-sprint management behavior is connected.

Corrective Sprint 1.3.3 performance architecture is implemented and compile-verified. Persistent H1 zone IDs use sorted lookup, active support/resistance indexes own invalidation iteration and active exports, terminal records remain retained for anti-resurrection, and TC breakout gating is H1-event-driven while M15 retest/confirmation work remains M15-driven. The optimization changes no thresholds, zone IDs, lifetime rules, or causal timestamps; exact one-year semantic/runtime comparison remains required.

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
- Sprint 6.2–6.2.3 audit-only visualization is accepted with an MT5 limitation: visual inspection may require separate H4/H1/M15 Tester runs. Programmatic period switching is intentionally avoided because it can reinitialize the EA. Visualization remains isolated from trading decisions.
- Sprint 6.3 is VERIFIED. [INTEGRITY_AUDIT.md](INTEGRITY_AUDIT.md) records the source findings and accepted manual regression checklist for closed-bar analysis, setup lifecycle, filters, planning/execution, reporting, summary, determinism, reconciliation, and visualizer isolation.
- v1.1.0-alpha framework controls are intentionally inert until later strategy and management routers exist. Future management routing must reject incompatible simultaneous modes.
- The session filter requires a manually configured fixed broker UTC offset for a historical run; a future session/time-source sprint owns any change.
- Future fixed-risk work must add a distinct initial-Tester-balance/no-compounding risk mode without changing the v1.0 current-equity sizing path.
- Sprint 1.2 uses a bounded deterministic 300-H4-bar minimum reconstruction and internal Wilder/EMA seeding. Its result requires manual causal timestamp, threshold/range-boundary, and legacy no-regression verification; see [H4_REGIME_V2.md](H4_REGIME_V2.md).
