# E2 Architecture

## 1. System purpose

E2 is a deterministic MQL5 research Expert Advisor. The active implementation supports Trend Continuation from causal multi-timeframe observations through native MT5 execution, position management, and authoritative deal reporting. Mechanical correctness does not imply a profitable edge or live readiness.

### v2.0.1 configuration ownership

The MT5 input surface is organized by ownership: strategy selection, shared market model, TC, RMR, RB, shared filters, risk, execution/broker safety, position management, and reporting/diagnostics. Declaration order and group labels are presentation concerns only; `E2LoadConfiguration()` and the existing `E2Config` fields remain the runtime boundary. The complete consumer trace is maintained in [INPUT_REFERENCE.md](INPUT_REFERENCE.md).

Strategy-edge parameters are those that change regime, zone, range, breakout, retest, confirmation, or planning calculations. Operational parameters control shared filtering, risk, execution, management, reporting, or visualization. A shared upstream parameter may legitimately affect multiple strategies; exclusive inputs must not be read by another strategy's calculation.

The recoverable v1.0 implementation exists at tag `v1.0.0`; it is not part of the active runtime tree.

## 2. Supported setup types

`E2StrategyType` is the shared setup identity carried into planning, executed-position metadata, and reporting.

- `TREND_CONTINUATION`: implemented and routable.
- `RANGE_MEAN_REVERSION`: reserved identity and configuration selection only; no setup engine exists.
- `RANGE_BREAKOUT`: reserved identity and configuration selection only; no setup engine exists.

A future setup becomes active by implementing a setup engine that emits the canonical candidate metadata and by adding an explicit planner route. No range fallback or stub execution exists.

## 3. Timeframe hierarchy

- H4 owns structural regime, EMA/ADX/ATR context, affirmative containment-based RANGE classification, and anti-extension eligibility.
- H1 owns persistent support/resistance zones and their lifecycle.
- M15 owns Trend Continuation retest/confirmation progression and the designated next-candle entry window.

Every decision uses completed candles. Pivot time and known-from time are distinct, and downstream stages may not observe an event before its known-from timestamp.

## 4. Canonical runtime pipeline

```text
MT5 rates/ticks
  -> E2MarketData
  -> E2H4RegimeEngine
  -> E2H1ZoneEngine
  -> E2TrendContinuationEngine
       -> E2M15ConfirmationEngine
  -> E2TrendContinuationCandidate
  -> E2V2TradePlanEngine
       -> session/news/exposure checks
       -> stop, opposing-zone target, management branch, fixed-base risk
  -> E2V2TradePlan
  -> E2V2ExecutionEngine
       -> execution-time quote/geometry/risk refresh
       -> E2OrderRequest
  -> E2OrderExecutor
  -> E2V2PositionMetadata
  -> E2V2PositionManager
  -> E2TradeReporter / E2BacktestSummary
```

`E2.mq5` owns initialization, completed-source-bar scheduling, module wiring, tick dispatch, transaction dispatch, and bounded tester summaries. Strategy formulas live in their owning modules.

## 5. Module responsibilities

| Stage | Owner | Responsibility |
|---|---|---|
| Configuration | `include/core/E2Config.mqh` | Single input definition, load, and validation |
| Market data | `include/analysis/E2MarketData.mqh` | Synchronized causal closed-bar access |
| H4 regime | `E2H4RegimeEngine.mqh` | Structure, EMA/ATR/ADX, trend eligibility, and affirmative H4 range evidence |
| H1 zones | `E2H1ZoneEngine.mqh` | Persistent IDs, creation, invalidation, indexes, anti-resurrection |
| H1 range boundaries | `E2H1RangeBoundaryEngine.mqh` | Read-only H4-RANGE/H1-zone pairing, frozen lifecycle, and verification |
| Setup state | `E2TrendContinuationEngine.mqh` | Breakout, retest, attempt ownership, confirmation, deduplication |
| Range mean-reversion state | `E2RangeMeanReversionEngine.mqh` | Outer-region approach, boundary visits, rearm, rejection routing, candidate deduplication |
| M15 confirmation | `E2M15ConfirmationEngine.mqh` | Sole owner of completed-candle momentum/rejection measurement, ordered rejection failures, causality, and result reuse |
| Planning | `include/strategy/E2V2TradePlanEngine.mqh` | Entry-window revalidation, filters, stop, target, risk, management route |
| Risk | `include/risk/E2PositionSizer.mqh` | Fixed-initial-balance monetary risk and broker-normalized volume |
| Native request | `include/risk/E2OrderRequest.mqh` | Minimal broker-facing order geometry |
| Execution | `E2V2ExecutionEngine.mqh`, `E2OrderExecutor.mqh` | One-shot adapter and native MT5 submission |
| Ownership/safety | `E2PositionGuard.mqh`, `E2ExecutionSafety.mqh` | Existing exposure, quote, spread, deviation, and cooldown checks |
| Management | `E2V2PositionManager.mqh` | Branch-exclusive tick management and restart recovery |
| Reporting | `E2TradeReporter.mqh`, `E2BacktestSummary.mqh` | Registered-position results and aggregate statistics |
| Visualization | `E2Visualizer.mqh` | Downstream-only causal audit overlays |

## 6. State ownership

The H1 zone engine is the sole writer of zone lifecycle state. The H1 range-boundary engine is a read-only consumer that owns only its frozen selected-pair lifecycle. The Trend Continuation and Range Mean-Reversion engines independently own their setup-specific attempt and candidate state. The shared planner owns plan acceptance or rejection and applies explicit setup geometry before common filters/risk. The execution engine owns one-shot submission identity and initial executed-position metadata. The position manager alone modifies post-entry stops. Reporting consumes registered entries and MT5 deals but cannot affect decisions.

Read-only snapshots cross module boundaries. No reporting or visualization state is read by strategy code.

## 7. Canonical data transitions

Candidate: `E2TrendContinuationCandidate`, owned by the setup engine. It freezes setup type, direction, source-zone/attempt identity, causal timestamps, confirmation, and decision-time H4 context.

Trade Plan: `E2V2TradePlan`, owned by the planner. It adds the entry window, structural stop, opposing-zone target, available R, fixed-base sizing, management branch, and deterministic rejection status.

Executed Position: `E2V2PositionMetadata`, owned initially by execution and consumed by management. It records authoritative fill, original protective stop/R, position identity, strategy/plan/candidate/zone identity, target, and branch.

Closed Trade Result: `E2ReportedTrade`, owned by reporting. It combines the registered V2 entry metadata with authoritative MT5 exit deals and monetary components.

`E2OrderRequest` is deliberately not another strategic plan. It is the minimal native-executor boundary produced after execution-time recalculation.

## 8. Persistence model

Position ownership requires the configured magic number and the stable `E2V2F|` or `E2V2Z|` comment prefix. Original entry, original stop/R, branch, and milestone are stored in terminal globals keyed by `E2V2M.<magic>.<position-id>.*`.

These V2-prefixed strings are intentionally retained because changing them would break restart recovery and compatibility with positions opened by the immediately preceding baseline. Stable H1 zone IDs and plan/candidate identity formats are also retained.

## 9. Reporting architecture

Only positions registered by successful E2 execution enter `E2TradeReporter`; unrelated magic-number deals cannot create report records. Rows carry `strategy_type`, candidate/plan IDs, source and target zone IDs, and management branch so future setup engines remain independently filterable and backtestable.

MT5 deals are authoritative for fills, exits, commissions, swaps, fees, and profit. Open or unresolved records are never fabricated as closed results.

Trend Continuation reporting preserves breakout, retest, confirmation, entry, execution, management, and exit identity end to end. Setup-filtered summary rows prevent cross-setup aggregation; future range setups must receive equivalent independent rows. The complete CSV, R-accounting, exit-classification, and invariant contract is documented in [TREND_CONTINUATION_REPORTING.md](TREND_CONTINUATION_REPORTING.md).

## 10. Diagnostics

Operational lifecycle, error, broker-rejection, execution, and management-modification messages remain permanent. The gated verification summary retains causality, zone persistence, duplicate suppression, planning/rejection, risk/execution, management, and V2-only reporting counters. Detailed candidate and engine diagnostics are emitted only when the existing verification or verbose diagnostic controls enable them.

Startup-only closed-bar/specification dumps and the separate startup CSV were removed because they duplicated module validation and authoritative reporting without protecting runtime invariants.

## 11. No-look-ahead guarantees

H4, H1, and M15 orchestration advances only when the corresponding completed source bar changes. Confirmed pivots retain explicit known-from times. Breakouts, retests, confirmations, candidates, and entry windows enforce causal timestamp order. Execution may refresh current quote, broker stop geometry, volume, and realized initial risk; it may not change setup direction, source zone, opposing target, or strategy thresholds.

## 12. Extension point

A setup engine emits setup-specific candidate state carrying `E2StrategyType` and must receive an explicit planner route before it can trade. Range Mean-Reversion has its own route into the shared filters, sizing, execution, zone-target management, persistence, reporting, and setup-filtered summary. It does not mutate H4 regime, H1 range, or H1 zone state and cannot fall through the Trend Continuation geometry route.

RANGE is not inferred from trend absence alone. After unchanged UPTREND/DOWNTREND predicates fail, the engine requires completed-candle ADX and normalized 20-H4 containment evidence; otherwise the regime remains transition/unclassified. H4 containment high/low remain classification measurements. A separate completed-H1 event layer selects frozen support/resistance midpoint references for future range research without adding strategy routing. See [H4_RANGE_REGIME.md](H4_RANGE_REGIME.md) and [H1_RANGE_BOUNDARIES.md](H1_RANGE_BOUNDARIES.md).

Range Mean-Reversion consumes that frozen context once per completed M15 bar. Its outer-region approach, actual source-zone challenge, rearm, rejection, identity, collision, and causal contracts are defined in [RANGE_MEAN_REVERSION.md](RANGE_MEAN_REVERSION.md).

Momentum and rejection are separate paths inside the shared confirmation owner. Trend Continuation consumes momentum; Range Mean-Reversion requests one directional rejection and carries the returned measurements unchanged. See [M15_CONFIRMATION.md](M15_CONFIRMATION.md).

RMR execution revalidates the same frozen range at the next M15 open, uses its challenged far edge plus the existing H1 structural buffer for SL, the opposing frozen zone near edge for TP, minimum 2R, and the existing zone-target milestone manager. See [RANGE_MEAN_REVERSION_EXECUTION.md](RANGE_MEAN_REVERSION_EXECUTION.md).
# Sprint 2.6 reporting

Range Mean-Reversion reporting is transaction-driven and setup-isolated. See `RANGE_MEAN_REVERSION_REPORTING.md` for the candidate-to-deal identity chain, immutable original-R accounting, and TC/RMR/global management diagnostic ownership.
# Sprint 3.1 Range Breakout

`E2RangeBreakoutEngine` consumes cached H4 regime, the authoritative frozen H1 range, and the shared M15 momentum engine. It owns independent long/short acceptance state and emits research candidates only; no planner or execution dependency exists.

The H1 handoff supplies the pre-update range snapshot for acceptance before the post-event range result is observed. Accepted state owns frozen source geometry and survives expected source-range invalidation without mutating or resurrecting upstream state.
## Sprint 3.2 Range Breakout integration

Range Breakout now has an explicit strategy route from its frozen candidate into the shared planner and execution engine. The route reuses active persistent H1 zones, shared filters, sizing, native order validation, position metadata, and the tick-driven position manager. RB identity remains separate through `RBP_` plan/execution IDs and per-strategy diagnostics. Current exact-time ownership order is RMR, then RB, then TC under the shared one-position-per-symbol guard. RB final reporting remains outside Sprint 3.2.

## Sprint 3.3 reporting integration

The common reporter now finalizes RB positions from persisted entry metadata and authoritative MT5 deals. Its physical CSV remains shared, while explicit setup identity and setup-filtered summaries keep TC, RMR, and RB analytically independent. Reporting remains transaction-driven and does not reconstruct historical strategy state.

## Sprint 4.1 integration hardening

All valid same-window plans now meet at a shared deterministic ownership queue before native execution. Causal known-from, explicit setup precedence, and plan ID determine order; the common position guard determines the single owner. Integrated diagnostics reconcile namespaces, metadata, the shared manager, reporting, economics, causality, and execution-to-report lifecycle without changing any setup formula.
# Sprint 4.2 risk routing

E2 resolves position risk centrally: fixed cash is non-compounding, while balance-percent mode reads current account balance immediately before sizing. Strategy planners may estimate volume, but native execution re-resolves the same request.
