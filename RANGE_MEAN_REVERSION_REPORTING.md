# Range Mean-Reversion Reporting

Sprint 2.6 finalizes the mechanical reporting chain:

`candidate_id -> plan_id -> order/deal -> position_id -> MT5 exit deals -> trade_id -> setup summary`

RMR candidates and plans use their deterministic `RMR_` and `RMRP_` namespaces. Final trade identity is the MT5 position identifier prefixed with `E2-`; it is never derived from an array index. Newly executed positions persist their explicit setup identity with the immutable filled entry, original protective stop, original R distance, management branch, and milestone.

## Accounting

Original R price is `abs(actual filled entry - submitted original protective SL)`. Original risk cash is calculated at execution from the actual fill, submitted protective stop, and executed volume using MT5 symbol conversion. It is not recalculated after a stop move.

Final realized profit is the sum of MT5 gross profit, commission, swap, and fees across the entry and exit deals. Realized R is that economic result divided by original risk cash; it is not rounded to an integer target result.

## Classification

Outcome is determined only from realized profit: positive is WIN, negative is LOSS, and the configured monetary tolerance around zero is BREAKEVEN. Exit classification reconciles MT5 deal reason with the original SL, native TP, management branch, and close price. A zone-target TP is `ZONE_TARGET_TP`; an SL away from the original stop under zone trailing is `TRAILING_SL`.

## Isolation and validation

TC and RMR finalized trades are filtered independently for result rows, chronological MaxDDR, profit factor, direction, management branch, and unresolved ownership. `[TCV2_MANAGE_VERIFY]` is TC-only, `[RMR_MANAGE_VERIFY]` is RMR-only, and `[V2_MANAGE_VERIFY]` is the shared total. Reporting remains transaction-driven; history reconciliation and summary aggregation occur at shutdown rather than per tick.

The frozen 2024 EURUSD RMR fingerprint is mechanical validation only: 10 candidates, 2 plans, 2 executions, 2 finalized losses, -2.02R, PF 0.0000, and 2.02R maximum drawdown. It is not evidence of profitability or edge.
