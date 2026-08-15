# M15 Confirmation Engine V2

Sprint 1.4 is **IMPLEMENTED — NOT VERIFIED**. `E2M15ConfirmationEngine` is an independent, read-only research detector. It does not create trades, select strategies, arm/consume setups, or alter the v1.0 confirmation path.

## Time and benchmark contract

The engine evaluates the most recent completed M15 candle only. Its `candle_time` is the candle open timestamp and `known_from_time = candle_time + 15 minutes`; no result is known at candle open. The preceding `InpResearchM15BodyMedianLookback` completed candles (default 20), excluding the candidate, supply body values `abs(close-open)`. They are insertion-sorted ascending; for an even sample the median is the arithmetic mean of values 10 and 11 (one-based). Insufficient history fails deterministically. A median less than or equal to zero makes body-multiplier qualification fail.

Zero-range candles fail all range-dependent confirmation tests safely.

## Momentum formulas

For bullish momentum, all conditions are required: `close > open`; `body >= 1.25 * median`; `body/range >= 0.60`; normalized close location `(close-low)/range >= 0.80`; `close > previous.high`; and `close > supplied_zone.upper`. Bearish momentum is the exact inverse: `close < open`; the same inclusive body and range thresholds; normalized close location `<= 0.20`; `close < previous.low`; and `close < supplied_zone.lower`.

`>=` applies to multiplier/body-range/close-location thresholds. Previous-candle and zone-edge breaks are strict `>`/`<`, as specified.

## Range rejection formulas

Bullish range rejection requires a valid supplied SUPPORT zone, M15 `[low,high]` intersection with that zone, `close > zone.upper`, `close > open`, lower wick `min(open,close)-low >= 1.50 * body`, and lower-wick/range `>= 0.40`. Bearish range rejection is the exact inverse for a valid RESISTANCE zone, using `close < zone.lower`, `close < open`, and upper wick `high-max(open,close)`.

## Zone contract and audit

The engine accepts immutable `E2M15ZoneContext` values: Zone V2 ID, role, frozen lower/upper edges, creation time, state, and invalidation time. It never discovers or mutates zones. A context must have been created by the candidate's known-from time and must be active then (or invalidate only later).

Each evaluation returns four detailed snapshots—bullish/bearish momentum and bullish/bearish range rejection—with raw OHLC, median/body/range/close-location/wick measurements and individual pass flags. `InpVisualShowM15ConfirmationV2=true` shows only passed `E2VIS_M15CV2_` markers on an M15 Visual Mode chart (`MOM+`, `MOM-`, `REJ+`, `REJ-`); tooltips contain all audit measurements and flags. Debug mode logs passes and selected direction/zone-valid threshold failures, bounded by the once-per-new-M15 orchestration.

The currently supplied contexts are active H1 Zone V2 records. This is infrastructure, not strategy selection: future sprints decide which zone is strategically relevant. Manual threshold, visual, and v1.0-regression tests remain required.
