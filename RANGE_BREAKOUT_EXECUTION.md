# Range Breakout Planning and Execution

Sprint 3.2 routes each frozen `RANGE_BREAKOUT` candidate through the shared plan, execution, persistence, and position-management infrastructure. Final RB result reporting remains deferred to Sprint 3.3.

## Lifecycle

`candidate -> entry window -> plan -> target selection -> structural stop -> 2R gate -> execution -> metadata persistence -> shared trailing manager`

- Entry is evaluated only in the M15 window whose open equals `confirmation_known_from`; LONG uses ASK and SHORT uses BID.
- The challenged boundary and breakout ATR come from the frozen candidate. LONG stop is challenged resistance lower edge minus `0.10 * breakout ATR`; SHORT stop is challenged support upper edge plus the same buffer. Broker normalization may conservatively widen the submitted SL without changing the stored structural stop.
- LONG selects the nearest active H1 resistance lower edge above entry. SHORT selects the nearest active H1 support upper edge below entry. A target must exist by plan time. Ties resolve by distance, earlier creation time, then lexical zone ID.
- Plans require `availableR = rewardDistance / riskDistance >= 2.0` and use `ZONE_TARGET_TRAILING` with the selected first-contact edge as native TP.
- Plan identity is `RBP_<candidateId>_<entryWindowTime>`. Execution deduplication uses this RB namespace and retains the TC and RMR namespaces.
- Execution refreshes quotes, broker stop validity, target/R geometry, volume, margin, and market constraints. It never reconstructs breakout, retest, confirmation, or range origin.
- Persisted metadata includes setup, candidate/plan/range/challenged-zone/target-zone identities, attempt, event timestamps, fill, structural and submitted stops, immutable original R, TP, and management branch.
- The shared manager applies the existing milestone trail and separately classifies RB diagnostics.

## Shared ownership and performance

The one-position-per-symbol guard applies across all strategies. Existing same-time orchestration is preserved: RMR is evaluated first, RB second, and TC third, so the first successful owner blocks later routes. Planning runs only when candidates reach their entry window, target selection scans the already-exported active H1 zone set, execution remains event-driven, and management remains tick-driven.

## Verification diagnostics

Tester-end output exposes `RB_PLAN_VERIFY`, `RB_EXEC_VERIFY`, and `RB_MANAGE_VERIFY`. Generic trade observation may retain RB metadata for later reporting, but Sprint 3.2 does not create an RB final summary and RB rows are excluded from TC/RMR contamination counts.
