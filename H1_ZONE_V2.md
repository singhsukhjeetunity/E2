# H1 Zone Engine V2

Sprint 1.3 is **IMPLEMENTED — NOT VERIFIED**. `E2H1ZoneEngine` is a parallel research component only. The existing `E2ZoneAnalyzer`, setup tracker, strategy analyzer, planning, execution, reporting, and v1.0 zone visualization remain the active trading path.

## Causal construction

The engine reads a bounded `InpZoneLookbackBars` (default 240) of completed H1 candles and rebuilds state deterministically whenever a new H1 candle closes. It uses the same strict strength-3 pivot semantics as H4 Regime V2: a pivot must be strictly more extreme than each of the three H1 candles on both sides; equal highs/lows are not pivots. A pivot at index `p` becomes known when candle `p + 3` closes. Its `known_from_time` is therefore that candle's open time plus one H1 period.

H1 ATR uses a causal Wilder ATR with `InpResearchH1AtrPeriod` (default 14). A pivot freezes its qualification ATR at its known-from decision point. A low touch qualifies only after a completed H1 high reaches `pivot_low + 1.00 * frozen_ATR`; a high touch qualifies only after a completed H1 low reaches `pivot_high - 1.00 * frozen_ATR`. The departure timestamp is the close availability time of the first qualifying candle. A pivot is usable only after both pivot confirmation and departure qualification.

Two fully-qualified low pivots create SUPPORT; two fully-qualified high pivots create RESISTANCE. The engine requires `abs(pivot_index_2 - pivot_index_1) >= InpResearchH1MinimumTouchSeparationBars`; the default exact boundary is therefore three completed H1 bar indexes, with no off-by-one interpretation. Their prices must differ by no more than `InpResearchH1ZonePivotClusteringAtr * ATR_at_second_pivot_known_from` (default `0.50 * ATR`). Zone creation time is `max(second_pivot_known_from, second_departure_confirmed_time)`.

Boundaries freeze at creation: `lower = min(P1, P2)` and `upper = max(P1, P2)`. No fixed-pip tolerance or ATR padding is carried from the v1.0 zone engine. The stable ID is source-based: `H1ZV2_<symbol>_<S|R>_<pivot1_time>_<pivot2_time>_<creation_time>`.

## Lifecycle, merging, and interaction foundation

The exposed lifecycle is `ACTIVE` then prospectively `INVALIDATED`. A support invalidates only when `close < lower - 0.10 * current_H1_ATR`; a resistance invalidates only when `close > upper + 0.10 * current_H1_ATR`. The comparison is strict, so exactly 0.10 ATR beyond does not invalidate. The record preserves invalidation time, close, ATR, ATR distance, and reason.

Sprint 1.3 intentionally applies the deterministic **no-merge** policy: independently created overlapping zones remain separate records. This preserves each source pair and frozen historical boundary without introducing a policy that later strategy work could silently consume. Consequently `merged_from_ids` is deterministically empty and no merge event exists in this sprint. A future consumer sprint must define a strategy-specific merge policy before enabling merge behavior.

For future reuse, H1-only interaction state tracks overlap visits, attempt number, armed/consumed placeholders, departure-after-attempt, and rearm eligibility. A completed H1 candle overlaps when its `[low, high]` intersects `[lower, upper]`. After a visit, rearm becomes eligible only after a completed H1 candle is fully at least `0.50 * current_H1_ATR` above the upper edge or below the lower edge; a later overlap starts the next visit. M15 confirmation and actual setup consumption are deliberately deferred.

## Audit and limits

With Visual Mode, `InpVisualShowH1ZoneV2=true`, and an H1 chart, `E2VIS_H1ZV2_` objects show frozen zone rectangles, compact type labels, source pivot markers, and invalidation markers. Tooltips expose source pivot/known-from/departure times and state. The visualizer only consumes records and never feeds the engine or trading path.

Debug logging is bounded to new-H1 CREATED and INVALIDATED events. There is no per-tick or per-candle zone log. Manual causal timestamp, threshold-boundary, visual, and v1.0 regression validation remains required before Sprint 1.4.
