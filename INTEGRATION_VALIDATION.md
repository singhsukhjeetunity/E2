# Three-Strategy Integration Validation

Sprint 4.1 validates E2 as one system with Trend Continuation, Range Mean Reversion, and Range Breakout enabled together. Strategy formulas remain frozen.

## Deterministic ownership

Valid plans are queued at the shared execution boundary for the current event window. Before native execution they are ordered by:

1. earlier candidate `confirmation_known_from`;
2. setup precedence `RANGE_BREAKOUT`, `RANGE_MEAN_REVERSION`, `TREND_CONTINUATION`;
3. lexical plan ID.

The first successful execution owns the one-position-per-symbol slot. Remaining plans still pass through the shared execution guard and are explicitly rejected when that slot is occupied. Ownership therefore does not depend on the order of strategy calls in `E2.mq5`.

## Identity and reconciliation

Plan/execution namespaces remain `V2P_`, `RMRP_`, and `RBP_`. Registered metadata retains one explicit setup plus candidate and plan identity. A single shared manager is reconciled against TC, RMR, and RB diagnostic views. The deal-driven reporter emits setup-filtered rows and summaries, while global reconciliation compares registered executions, finalized records, monetary results, R results, and duplicate identities.

## Validation procedure

Run the seven toggle combinations documented in Sprint 4.1. For the all-enabled 2024 EURUSD test, repeat the identical test three times and compare every `RUN_FINGERPRINT` field plus trade, candidate, and plan IDs. All namespace, ownership, identity, manager, reporting, execution/report, and causality violation counters must remain zero. Restart recovery requires a controlled manual reload while an E2 position is open; confirm setup, original entry/SL/R, management branch, and milestone persistence without duplicate registration or management.

## Runtime architecture

H4 and H1 analysis remain event-bound, all setup engines remain on their existing H1/M15 events, planning occurs only for emitted candidates, queued execution is flushed once per orchestration pass, management remains tick-driven for owned positions, and reporting remains transaction/deal-driven.

## RB causality aggregation

`E2RangeBreakoutVerification.causality_violations` is a legacy combined counter: it includes both genuine H1 known-from failures and expected M15 observations suppressed because their known-from is not later than the frozen breakout known-from. The latter are causal guard successes, not violations. `GLOBAL_CAUSALITY_VERIFY.rbViolations` therefore uses the authoritative mirrored H1 violation counter; planner and report chronology remain represented in their own aggregate fields. `GLOBAL_RB_CAUSALITY_AUDIT` exposes the legacy total, genuine H1 component, expected M15 guard suppressions, and expected source-range invalidation lifecycle counters.
