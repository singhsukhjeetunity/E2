# V2 Native Execution

Sprint 1.7 connects finalized Trend Continuation V2 plans to the existing native MT5 order layer. The execution adapter consumes plan decisions; it never reconstructs regime, zones, confirmation, breakout, retest, target selection, or management selection.

## One-shot boundary

Every valid plan receives the deterministic identity `V2P_<candidateId>` and is recorded as attempted before execution eligibility is evaluated. With trading disabled, the plan is counted as execution-disabled and no request is sent. With trading enabled, it terminates after exactly one success or failure. There is no retry on a later tick or candle.

## Quote and geometry

The adapter obtains a fresh ASK for LONG or BID for SHORT. It retains the plan's structural stop and target-zone identity, applies outward tick/broker stop normalization, and recalculates risk distance and available R. The same target near edge must still provide at least 2R; no replacement target is selected.

Fixed-2R TP is recalculated from the refreshed entry and submitted stop, with outward tick normalization. Zone-target TP uses the plan's selected target reference with conservative tick normalization. Fixed-initial-balance volume is recalculated through `OrderCalcProfit` and broker volume-step normalization.

## Native submission and identity

`E2OrderExecutor` remains the order authority for final position protection, quote/spread/session safety, margin preflight, filling mode, magic number, synchronous market submission, and retcode validation. A compact `E2V2|<confirmationKnownFrom>|<attempt>` comment accompanies the request. `OrderSend` success alone is insufficient; only accepted authoritative retcodes produce an execution success.

After a successful deal, `E2V2PositionMetadata` records position/order/deal identity, strategy and setup identity, actual fill, structural/submitted stop, fixed and actual initial risk, management branch, target reference, TP, and `INITIAL` management state. The entry deal is also passed to the existing authoritative trade reporter. No trailing or later management behavior is implemented here.

Tester-end `V2_EXEC_VERIFY` reconciles valid plans with disabled, successful, and failed terminal outcomes and reports duplicate attempts, metadata registration, causality, quote/fill differences, and actual-risk statistics.
