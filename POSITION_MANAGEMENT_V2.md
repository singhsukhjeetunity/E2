# V2 Position Management

Sprint 1.8 manages only E2-owned Trend Continuation V2 positions and routes explicitly by the management branch fixed at execution.

## Branch behavior

`FIXED_2R` positions retain their native protective SL and +2R TP. They are observed for ownership diagnostics but receive no dynamic stop modification.

`ZONE_TARGET_TRAILING` positions retain the opposing-zone TP selected by planning/execution. Their immutable R is the distance between authoritative fill/open price and original submitted protective stop. Tick-level management uses BID for a LONG and ASK for a SHORT.

For maximum favorable R `f`, the reached milestone is `floor(f)`. At milestones of 2 or higher, locked R is `milestone - 1`: +2R locks +1R, +3R locks +2R, and so on. A gap goes directly to the highest completed milestone. The highest reached milestone is retained even if placement is temporarily deferred or price retraces.

## Stops and broker constraints

LONG milestone stops are floored to the tick grid; SHORT stops are ceiled. This conservative normalization never claims more locked profit than the theoretical integer-R level. Stops/freeze distance is checked against the executable close side before submission. If the exact normalized level is not currently legal, no substitute level is used and the desired milestone remains pending for a later tick. Existing TP is preserved on every `PositionModify` request. Monotonic comparison suppresses duplicate or backward requests.

## Ownership and recovery

Management requires the configured E2 magic number and an `E2V2` position comment. Successful Sprint 1.7 registration persists entry, original SL, original R, branch, and maximum milestone in terminal global variables keyed by magic number plus authoritative MT5 position identifier. New order comments also include `E2V2F` or `E2V2Z` for branch recovery if persistence is interrupted before registration.

On initialization, live owned positions reload the persisted immutable values. A marked position can be reconstructed only while its current SL is still the original protective stop; a profitable moved stop without persistence is rejected rather than used to invent a new R. Closed-position state and orphaned globals are removed safely.

`TCV2_MANAGE_VERIFY` provides branch, milestone, modification, constraint, regression, invalid-R, and recovery counts. Successful modifications alone emit `TCV2_MANAGE` event logs.
