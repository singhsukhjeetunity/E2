# E2 v1.1.0-alpha — Sprint 1.2 H4 Regime Engine V2

## Scope

`E2H4RegimeEngine` is a parallel, analytical-only component. It is evaluated from completed H4 data and produces `E2H4RegimeResult` for future consumers. Sprint 1.2 does not route its result into the legacy strategy, planning, risk, execution, reporting, or visualization paths.

## Causal data and swings

The engine requests chronological closed H4 bars through `E2MarketData::GetClosedBarsAsOf`. A strength-3 swing pivot at `P` is strict: its high/low must be respectively greater/less than all three bars on both sides. Equal neighbours are not pivots. The swing remains unavailable until the close of `P + 3 H4 bars`; its `pivot_time` stays at `P`, while `known_from_time` is the later confirmation close.

Structural-break tests occur before swings confirmed by the current candle are admitted. Thus a breakout candle cannot break a swing that becomes known only at that same close.

## Indicators

EMA20 and EMA50 seed with the simple average of their first completed-period closes, then use standard recursive EMA updates. ATR(14) is Wilder-smoothed true range. ADX(14) uses deterministic Wilder-smoothed TR/+DM/-DM, a 14-DX seed, then recursive ADX. This bounded deterministic seeding can differ slightly from a terminal indicator seeded from deeper pre-window history; it is deliberately independent of terminal indicator handles.

All H4 values use the Sprint 1.1 research EMA/ATR fields and existing canonical `InpAdxPeriod` / `InpAdxMinimumThreshold` semantics. The reconstruction window is `max(InpTrendStructureLookbackBars, 300)` completed H4 bars, so a restart with that same available history deterministically produces the same result as a continuous run at the same timestamp.

## Breaks and directional regimes

A break uses an already-confirmed latest swing and a later completed close. Exact configured 0.10-ATR distance passes; a smaller distance fails. The result retains broken swing price, breakout timestamp/close/ATR/distance, and direction. A bullish break is invalidated for current trend qualification by a later close below the applicable latest low; bearish is symmetric.

UPTREND requires HH + HL, active bullish break, EMA20 > EMA50, rising EMA50 versus five completed bars ago, and ADX >= threshold. DOWNTREND is exact inverse. Equality does not satisfy directional comparisons. ADX supplies strength only, never direction.

Extension is deliberately separate: `abs(close - EMA20) / ATR <= 1.50` yields `trend_entry_eligible=true`; a larger value yields `trend_overextended=true` and `trend_entry_eligible=false`, while retaining UPTREND/DOWNTREND.

## Frozen range algorithm

At each causal swing-confirmation point, the engine considers exactly the two most-recent confirmed swing highs and two most-recent confirmed swing lows. It confirms a range only when both high/low pair variations are <= 0.50 ATR, high/low-centre separation is >= 3.00 ATR, ADX < threshold, and EMA50 five-bar movement is <= 0.10 ATR.

The confirmation timestamp is the later pair member's `known_from_time`. Centres are pair averages; frozen outer boundaries are `max(high pair)` and `min(low pair)`. Range identity is deterministically derived from its two newest contributing pivot timestamps. Boundaries do not move after confirmation.

An active range is prospectively invalidated only when a later completed close is **more than** 0.25 ATR outside a frozen boundary; exactly 0.25 ATR does not invalidate. A subsequent range needs at least one newly confirmed contributing swing after the prior invalidation.

## Precedence and diagnostics

Directional trend is evaluated first, then valid range, otherwise `TRANSITION_UNCLASSIFIED`. The ADX thresholds (`>= 20` for trend and `< 20` for range) make a simultaneous directional/range classification impossible; the explicit precedence remains deterministic.

`[E2][DEBUG][H4RegimeV2]` is emitted only when the cached H4 result changes, including regime, eligibility, extension, swings, EMA/ADX/ATR, active break, and range ID. It is not emitted per tick.

## Status and limitations

Sprint 1.2 is **IMPLEMENTED — NOT VERIFIED**. No profitability or edge claim is made. Manual H4 timestamp, boundary, visual/headless parity, and legacy-regression checks remain required before Sprint 1.3.

## Verification overlay

When `InpVisualModeEnabled=true`, `InpVisualShowH4RegimeV2=true`, and the attached Strategy Tester chart is H4, the audit-only visualizer consumes the engine result. `E2VIS_H4RV2_*` objects show the exact engine EMA values, compact decision state, the current four structural swings (`H1`, `H2`, `L1`, `L2`), the active structural break, regime/eligibility changes, and frozen range lines.

The swing label is anchored at the source pivot (`P`); a compact `K` marker identifies when that source swing became known. The marker tooltip contains its full type, pivot time, known-from time, and price. Superseded swings retain only subdued markers: they have no persistent metadata labels or known-from lines. Old breaks are likewise dimmed, while the current break remains the visually dominant structural event. Range labels are compact (`R#`) and retain the engine's source-backed start/invalidation boundaries. The overlay is not created on headless/non-H4 charts and has no path back into the regime engine or trading components.
