# Trend Continuation V2

Sprint 1.5 is **IMPLEMENTED — NOT VERIFIED**. `E2TrendContinuationEngine` is a research-only consumer of H4 Regime V2, H1 Zone V2, and M15 Confirmation V2. It has no path to the legacy strategy, setup tracker, planner, execution, reporting, or account state.

For LONG it requires eligible non-overextended H4 UPTREND, then a completed H1 close at or above `resistance.upper + 0.10 * H1 ATR`. The source resistance remains immutable; strategy state treats its frozen interval as potential support. A later M15 overlap after an above-side approach starts one continuous retest visit. Only `BULLISH_MOMENTUM` may confirm it. SHORT is symmetric from support through a close at or below `support.lower - 0.10 * H1 ATR`, flipped potential resistance, below-side retest, and `BEARISH_MOMENTUM`.

Pending records invalidate if the directional H4 regime is lost or becomes ineligible/overextended, or if the flipped interval is crossed by more than `0.10 * H1 ATR` on a completed H1 close. Candidate emission consumes the current research attempt; it never creates an order. State is keyed by deterministic Zone V2 ID and direction. Current implementation is bounded by the 240-H1-bar source history and reconstructs active source context on each new M15 evaluation; full historical candidate persistence is intentionally deferred to a later reporting/router sprint.

`InpVisualShowTrendContinuationV2=true` adds passed-only M15 `TC+`/`TC-` audit markers with candidate, breakout, retest, confirmation, and attempt tooltip metadata. Debug logs only meaningful breakout, retest, invalidation, and confirmation transitions.
