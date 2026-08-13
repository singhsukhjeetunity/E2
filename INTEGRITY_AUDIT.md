# E2 Sprint 6.3 — Visual + Mechanical Integrity Audit

## Verdict

**VERIFIED — source audit passed and the required manual MT5 runtime regressions were accepted, with the documented visualization limitation.**

The inspected implementation is mechanically designed to use only closed market data, native MT5 execution/deal data, and an observational visualization layer. No source-level look-ahead path or visualization-to-trading dependency was found. This is not an assertion that E2 has a trading edge.

## Scope and evidence

Inspected: `E2.mq5`, configuration/environment/core modules, market data, trend, zones, confirmation, setup tracker, session/news filters, planner/sizer, execution safety/guard/manager/executor, trade reporter/summary/CSV exporter, and visualizer. Source findings below retain their original **PASS** and **PASS WITH LIMITATION** classifications; the closing checklist records the subsequently accepted manual verification.

## Pipeline inspected

The implemented order is:

```text
OnTick -> PositionManager.Refresh -> new closed M15 guard
-> Zone evaluation + SetupTracker.Update + visual zone update
-> StrategyAnalyzer (H4 trend, M15 confirmation, H1 zones)
-> SetupTracker eligibility -> session -> news -> existing-position short-circuit
-> planner -> executor (PositionGuard, safety, native CTrade)
-> SetupTracker.Consume after successful execution
-> reporter capture -> OnTradeTransaction exit aggregation -> summary/deinit reconciliation
```

This differs slightly from the conceptual ordering: zones/setup are refreshed before the strategy analyzer repeats its own zone evaluation. Both use the same `evaluation_time`; no trade is placed by either evaluation.

## No-look-ahead and timeframe alignment

**PASS.** `E2MarketData::GetClosedBarAsOf` rejects a bar whose open time plus `PeriodSeconds(timeframe)` is later than `evaluation_time`; `GetClosedBarsAsOf` anchors every range to that result. All analysis modules consume that closed-only accessor.

- H4 trend: pivot scan excludes the newest `sensitivity` bars, so each pivot has its required right-side closed bars. Internal Wilder ADX receives only the bounded closed-H4 range.
- H1 zones: each pivot at `p` becomes known only at the close of bar `p + sensitivity`; `Replay` ignores bars before `known_from_time`. Zone lifecycle events run chronologically over closed H1 bars.
- M15 confirmation: the selected candle is the last closed bar. Engulfing and previous-break use it plus its closed predecessor; pin uses it alone; momentum averages only preceding closed bodies.

Concrete server-time examples for the configured H4/H1/M15 hierarchy:

| Evaluation time | Closed M15 | Closed H1 | Closed H4 |
|---|---:|---:|---:|
| 2025.12.24 20:45 | 20:30 | 19:00 | 16:00 |
| 2025.12.24 21:00 boundary | 20:45 | 20:00 | 16:00 |
| 2025.12.25 00:00 H4/H1 boundary | 23:45 | 23:00 | 20:00 |

At an exact boundary the newly opened bar is rejected as forming and the preceding bar is selected. These timestamps require a manual Journal diagnostic cross-check against the chosen broker server clock.

## Trend / ADX

**PASS WITH LIMITATION.** Structure uses alternating resolved pivots, labels HH/HL or LH/LL, and classifies all other states as RANGE. ADX is valid only after `2*period+1` closed H4 bars, uses numeric checks, and requires `ADX >= InpAdxMinimumThreshold`.

The deterministic Wilder seed uses only a bounded 29-bar window at the default period 14. It can differ slightly from a terminal indicator seeded from deeper history, particularly near the ADX threshold. This is intentional technical debt; it must be quantified around threshold-crossing examples before treating threshold decisions as runtime-verified. `iADX` is not reintroduced.

## H1 zones and setup lifecycle

**PASS WITH LIMITATION.** Candidate creation, merge compatibility, known-from timing, replayed touch debounce, active/broken/retest/reversed/invalidated transitions, actionable suppression, and deterministic winner preference are source-backed. The setup tracker keys `(symbol, zone_id, role)`, arms on first overlap, leaves session/news/planner/execution rejections armed, consumes only after a successful native execution, and resets on a non-overlapping closed M15 candle.

Zone IDs are deterministic inside an evaluation but are reconstructed from a bounded rolling H1 lookback. A manual continuous-overlap/re-entry regression is still required to prove that rolling history never changes a setup identity in a way that permits a duplicate execution. No source change is made without that evidence because changing the identity scheme would alter established setup semantics.

## Sessions and news

**PASS WITH LIMITATION.** Session time is converted with the explicit configured broker UTC offset; London and New York DST rules, start-inclusive/end-exclusive windows, overlap, weekends, both-disabled, and invalid-offset fail-closed cases are implemented. One historical run assumes one configured server UTC offset.

The news loader uses `FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ`, validates the exact seven-column schema, one META row, coverage, event fields, sorting/deduplication, pair currencies, and inclusive blackout boundaries. Missing/invalid/out-of-range data fails closed before setup consumption. The synthetic USD HIGH event at 2025.12.26 08:30 UTC with 60/60-minute buffers remains a required runtime fixture check: 10:30 and 11:00 server candidates blocked; 12:15 allowed for broker UTC+2.

## Risk, execution, position, and exits

**PASS WITH LIMITATION.** LONG plans use executable ASK and an outward normalized stop below support; SHORT uses executable BID and an outward normalized stop above resistance. TP is normalized target R. Sizing uses `OrderCalcProfit`, equity, downward volume normalization, and a post-normalization risk loop that refuses risk above target beyond tolerance.

The executor does not recalculate a plan. It applies PositionGuard, safety/quote/spread/cooldown/deviation/geometry/broker-stop/margin checks, then sends synchronous native `CTrade` orders with magic/comment/SL/TP and captures actual result fields. The existing-position short-circuit is an additional pre-planner guard.

**PASS WITH LIMITATION.** Reporter identity is `DEAL_POSITION_ID`, not an assumption that order/deal/position tickets match. Exit deals are accepted only for the E2 magic, aggregated by deal ticket and position identifier, and finalized once only when native position absence and complete exit data coexist. TP/SL/other reason is MT5 `DEAL_REASON`; no candle-price inference or shadow P&L is used. Partial exits aggregate money, volume, and volume-weighted exit price; the final closing deal supplies the final exit reason. An unavailable Tester forced-close is reported unresolved and excluded rather than fabricated.

The representative 2025.12.24 20:45 plan and E2-2/E2-4 monetary examples require manual MT5 deal-history comparison; they are not encoded as production expectations.

## Summary and reconciliation

**PASS WITH LIMITATION.** Summary metrics are calculated only from reporter-finalized records and handle zero counts, all-win/all-loss, zero gross loss (`INF`/`NA`), and unresolved-record exclusion. Account reconciliation is explicitly `account_net_change - finalized_trade_net_profit`; it is diagnostic and intentionally not forced to zero. R drawdown percentage is omitted (`NA`) when its denominator would be misleading.

## Visualization and determinism

**PASS (source isolation); runtime behavior accepted with MT5 limitation.** The visualizer only receives copied analysis/result metadata and is never read by strategy, planner, executor, filters, or reporter. Object failures return locally; they do not alter decisions. It uses deterministic `E2VIS_` names and timeframe visibility: H4 context, H1 zones/trade context, M15 confirmations/execution, H1+M15 trade objects. Separate H4/H1/M15 Tester runs are the accepted audit workflow where MT5 does not expose reliable timeframe switching; separate Tester tabs are not synchronized E2 audit charts.

Visual-versus-headless parity and same-settings repeat-run determinism require the manual comparison below. Run IDs may differ by design; compare CSV content after excluding run-id filenames/columns.

## Logging and failure policy

Normal mode keeps lifecycle, executed trade, finalized trade result, and final result. Candidate/zone/confirmation/session/news diagnostics are debug-gated. The remaining normal-mode warnings/errors identify configuration, fail-closed filters, execution, or reporting infrastructure failures.

| Component unavailable/invalid | Policy | Evidence |
|---|---|---|
| Closed market history, trend, zones, confirmation | FAIL-CLOSED / SKIP | analyzer returns not-ready/no signal |
| Session offset/window | FAIL-CLOSED | `eligible=false` |
| News data/coverage/currency/time | FAIL-CLOSED | `eligible=false` before consume |
| Symbol/account/planner/sizer | SKIP + diagnostic | no valid plan |
| Execution safety/guard/broker | SKIP + warning/error | no native order, no consume |
| Reporting/CSV | WARNING, observational only | EA continues; no trade action |
| Visualization | SKIP, observational only | never read by trading path |

## Defects found and corrections

No source-level mechanical defect was established during this audit; therefore no trading-path correction was made. The previously corrected misleading visual timeframe buttons remain absent; the non-interactive audit instruction remains the only timeframe UX.

## Manual MT5 verification checklist

The following checklist was completed and accepted to close Sprint 6.3. The visualization workflow retains an MT5 limitation: audit views may need to be run separately for H4, H1, and M15 because the Tester does not provide a reliable synchronized multi-timeframe audit-chart workflow.

Use the engineering window: EURUSD, 2025.12.24–2025.12.27, Every Tick, broker UTC offset +2, `TradingEnabled=true`, `ExecutionTestEnabled=false`, CSV enabled, Debug enabled for diagnostics.

1. Run headless and visual configurations with every non-visual input identical. Compare candidate evidence where available, orders/deals, direction, signal time, fills, SL/TP, exits, volume, trade/summary CSV rows, and final balance/equity. Expect zero trading differences.
2. Run the identical headless configuration twice. Compare zone IDs, signal times, orders/deals, fills, SL/TP, final CSV content, summary values, and balance/equity. Ignore run-id filename differences only.
3. Inspect Journal closed-bar diagnostics at the three alignment times above; inspect H4 trend/ADX and H1 known-from zone timing; inspect M15 selected confirmation timestamps.
4. Run the verified news fixture and confirm its three stated server-time outcomes.
5. Cross-check every finalized E2 CSV row against MT5 Deals, including E2-2 TP net/R and any E2-4 SL baseline. Confirm any forced-close record is unresolved, excluded, and visible in reconciliation difference.
6. In Visual Mode, use the native selector on the same E2-attached chart and verify H4/H1/M15 layers; repeat with visualization disabled and confirm parity.
7. Exercise continuous overlap, non-overlap reset, later re-entry, session/news rejection, failed plan/execution, and existing-position duplicate behavior in the Journal.

## Final mechanical-integrity conclusion

**MECHANICALLY VERIFIED.** The source audit and accepted manual Tester regressions close Sprint 6.3. The visualization is accepted with the documented MT5 timeframe limitation. This audit makes no profitability or edge-positive claim.
