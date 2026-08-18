# E2 Strategy

E2 v1.1.0-alpha executes the Trend Continuation V2 research strategy only. The v1.0 trend-pullback strategy has been removed from the active branch; its recovery artifact remains the immutable `v1.0.0` tag.

## Active decision pipeline

- `E2H4RegimeEngine` produces closed-H4 directional regime and anti-extension state.
- `E2H1ZoneEngine` maintains persistent causal support/resistance zones.
- `E2M15ConfirmationEngine` evaluates completed-M15 momentum and rejection evidence.
- `E2TrendContinuationEngine` owns breakout, retest, attempt, confirmation, and candidate identity.
- `E2V2TradePlanEngine` revalidates the next-M15 entry window, session, news, exposure, target, risk, and management configuration.
- `E2V2ExecutionEngine` performs one-shot native execution and registers fill-based position metadata.
- `E2V2PositionManager` manages only registered E2 V2 positions.

Range Mean-Reversion can produce raw candidates and, when enabled, route them independently through planning, execution, zone-target management, and reporting. Range Breakout remains unimplemented and cannot produce candidates.

When H4 is affirmatively RANGE, a separate read-only H1 research layer may freeze the widest valid active SUPPORT/RESISTANCE midpoint pair contained by the H4 evidence envelope. This context is not a setup and has no planner or execution route. Its deterministic selection and prospective invalidation contract is documented in [H1_RANGE_BOUNDARIES.md](H1_RANGE_BOUNDARIES.md).

Range Mean-Reversion uses the frozen context's outer 20%, requires a completed-M15 approach from the interior followed by actual source-zone interaction, and reuses only the existing directional rejection formula. At the next M15 open, its explicit planner branch revalidates the range and shared filters, places SL beyond the challenged zone with the existing H1 buffer, targets the opposite frozen zone near edge, requires at least 2R, and uses `ZONE_TARGET_TRAILING`.

The confirmation subsystem keeps momentum and rejection isolated: Trend Continuation uses its unchanged momentum contract, while Range Mean-Reversion uses strict directional recovery plus inclusive wick/body and wick/range thresholds. Invalid or noncausal candles cannot pass. See [M15_CONFIRMATION.md](M15_CONFIRMATION.md).

The shared H4 engine can classify RANGE using affirmative completed-candle evidence: neither verified trend predicate may pass, ADX(14) must be at most 20, and the latest 20 completed H4 highs/lows must span no more than 6.0 ATR(14). Failure of both trend and range evidence remains neutral/unclassified. These H4 measurements are regime evidence only; they are not H1 trade boundaries.

## Trade construction

The structural stop and opposing-zone target are selected by the V2 planner without look-ahead. Risk is sized from the fixed initial Tester balance using the configured risk percentage.

Management is deterministic:

- `FIXED_2R`: native protective SL plus fixed +2R TP; no dynamic stop management.
- `ZONE_TARGET_TRAILING`: opposing H1 zone near edge is the target, with no fixed +2R TP. At every completed milestone `n >= 2`, the intended locked profit is `n - 1R`, based permanently on actual fill to original protective stop.

Exactly one management branch must be enabled for executable trading. Both or neither is an invalid management configuration.

## Safety and causality

All strategy observations use completed bars and explicit known-from timestamps. Execution refreshes market-dependent geometry but cannot change candidate identity, source zone, opposing target, direction, or strategy thresholds. Reporting and visualization are downstream-only consumers.

Session/news filtering, quote/spread/deviation controls, position ownership, one-position protection, native broker validation, authoritative deal reporting, restart recovery, monotonic stop changes, and broker stop/freeze constraints remain shared infrastructure.

Detailed specifications are in [H4_REGIME_V2.md](H4_REGIME_V2.md), [H4_RANGE_REGIME.md](H4_RANGE_REGIME.md), [H1_ZONE_V2.md](H1_ZONE_V2.md), [H1_RANGE_BOUNDARIES.md](H1_RANGE_BOUNDARIES.md), [M15_CONFIRMATION.md](M15_CONFIRMATION.md), [M15_CONFIRMATION_V2.md](M15_CONFIRMATION_V2.md), [TREND_CONTINUATION_V2.md](TREND_CONTINUATION_V2.md), [RANGE_MEAN_REVERSION.md](RANGE_MEAN_REVERSION.md), [RANGE_MEAN_REVERSION_EXECUTION.md](RANGE_MEAN_REVERSION_EXECUTION.md), [TREND_CONTINUATION_PLAN_V2.md](TREND_CONTINUATION_PLAN_V2.md), [EXECUTION_V2.md](EXECUTION_V2.md), and [POSITION_MANAGEMENT_V2.md](POSITION_MANAGEMENT_V2.md).
# Sprint 2.6 reporting boundary

Sprint 2.6 changes reporting and diagnostics only. Range Mean-Reversion entry, rejection, stop, opposing-boundary target, minimum 2R, sizing, and zone-target trailing semantics remain frozen.
