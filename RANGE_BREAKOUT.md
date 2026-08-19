# Range Breakout — Candidate Generation

Sprint 3.1 implements candidate generation only:

`H4 RANGE -> frozen H1 range -> strong H1 breakout -> acceptance -> M15 retest -> M15 momentum -> RB candidate`

Sprint 3.1 stopped at candidate generation; Sprint 3.2 adds the planner, execution route, risk calculation, metadata registration, and shared position management while final RB reporting remains deferred.

## H1 acceptance

Only completed H1 candles are evaluated. The actionable time is the H1 open plus one hour. A long close must be at or above the frozen resistance upper edge plus `0.10 ×` the authoritative completed-H1 ATR. A short close must be at or below the frozen support lower edge minus the same distance. Equality qualifies with deterministic floating-point tolerance.

The breakout candle must point in the breakout direction, have a body at least `1.25 ×` the median body of the previous 20 completed H1 candles excluding itself, body/range of at least `0.60`, and close within the breakout-side 20% of its range. Zero-range and insufficient-history candles fail defensively.

## State and timing

Each range direction independently owns `IDLE`, `BREAKOUT_ACCEPTED`, `RETEST_ACTIVE`, and `CONSUMED_WAIT_REARM`. A valid H1 acceptance increments that range/direction attempt once. Retest noise never increments it.

Only completed M15 candles whose known-from time is strictly later than breakout known-from participate. Intersection of the frozen challenged band from the outside activates the retest. A completed retest candle may also confirm momentum in the same evaluation: the engine records the retest first, then permits emission because both facts are known at the same candle close. Confirmation uses the shared authoritative M15 momentum engine, not RMR rejection.

Acceptance uses the frozen range snapshot that existed immediately before the completed H1 event updated persistent zones and range lifecycle. The breakout may naturally invalidate that source range afterward; this neither resurrects the range nor erases the accepted strategy-local context.

Expiry counts actual completed H1 events. Acceptance is age 0, the next completed H1 candle is age 1, age 12 remains eligible, and expiry occurs before processing age 13. Weekend and market gaps consume no phantom bars. Depth invalidation uses the frozen challenged band with the current completed-H1 ATR: long closes below resistance lower edge minus `0.10 ATR`, and short closes above support upper edge plus `0.10 ATR`, invalidate.

H4 RANGE is an origin requirement at acceptance. A later H4 transition does not retroactively erase an accepted breakout; it continues until depth failure, expiry, consumption, or rearm/reset.

After consumption, long rearms only after a completed H1 close at or below the former resistance lower edge minus `0.50 ATR`; short uses a close at or above former support upper edge plus `0.50 ATR`. RB owns this lifecycle independently of TC and RMR.

## Identity and collisions

Candidate identity is `RB_<symbol>_<rangeId>_<direction>_<attempt>_<confirmationKnownFrom>` and never uses an array index. At most one candidate is emitted per confirmation timestamp. Ownership is resolved by closest challenged edge, then earlier breakout known-from, earlier retest known-from, lexical range ID, and lexical candidate/source identity. Non-winning valid state remains available for a later confirmation.

`[RB_VERIFY]` and `[RB_H1_BREAKOUT_VERIFY]` provide bounded lifecycle, threshold, collision, and causality counters. Passed candidates optionally render as `RB+` or `RB-` with frozen H1 and M15 measurements.
## Sprint 3.2 planning and execution

Sprint 3.2 adds planning and native execution for the mechanically frozen Range Breakout candidates. See `RANGE_BREAKOUT_EXECUTION.md` for entry timing, structural-stop construction, causal target selection, 2R eligibility, strategy-aware identity, persistence, and shared management. Candidate detection, retest, momentum confirmation, and the 2024 raw fingerprint of 24 accepted breakouts, 15 retests, and 8 candidates (6 LONG / 2 SHORT) remain unchanged.

## Sprint 3.3 reporting

Range Breakout now completes the authoritative deal-driven reporting lifecycle and emits setup-filtered CSV trades, `RB_REPORT_VERIFY`, `RB_REPORT_VERIFY_2`, and an independent `Setup=RANGE_BREAKOUT` summary. See `RANGE_BREAKOUT_REPORTING.md`. Candidate, planning, execution, risk, and management semantics remain unchanged.
