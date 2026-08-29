# E2 ADXBB Mechanical Strategy Specification

Status: Sprint 2 signal-engine implementation. Indicator calculations and observational candidates exist; planning and execution do not.

## Identity and timeframe

- Product/engine: E2.
- Strategy identifier: `ADXBB` (ADX regime plus Bollinger Band mean reversion).
- Authoritative strategy timeframe: `PERIOD_M5`.
- Initialization must fail unless `_Period == PERIOD_M5`; every market-data and indicator call must also pass `PERIOD_M5` explicitly so chart state cannot silently select another timeframe.
- Decisions use completed M5 candles only. The current forming candle is never a signal source.

## Inputs proposed for implementation

| Input | Type | Default | Contract |
|---|---|---:|---|
| `InpADXBBEnabled` | bool | true | Enables ADXBB signal evaluation. |
| `InpADXBB_DI_Length` | int | 7 | Wilder smoothing length for +DM, -DM, and true range used by DI. |
| `InpADXBB_ADX_Length` | int | 7 | Wilder/RMA smoothing length applied to DX. |
| `InpADXBB_ADX_Threshold` | double | 20.0 | Ranging condition is strictly `ADX < threshold`. |
| `InpADXBB_BB_Length` | int | 20 | Close-price SMA and population-standard-deviation window. |
| `InpADXBB_BB_StdDev` | double | 2.0 | Standard-deviation multiplier. |
| `InpADXBB_ATR_Length` | int | 14 | Signal-candle ATR length. |
| `InpADXBB_ATR_Multiplier` | double | 1.0 | Frozen ATR distance multiplier. |
| `InpADXBB_TargetR` | double | 1.1 | Future fixed reward multiple; execution is not implemented in Sprint 2. |

`InpOneTradePerDay` is intentionally deferred. No point-value, session, timezone, weekday, opening-range, news, volume, band-distance, minimum-ATR, confirmation, trailing, breakeven, partial-exit, or dynamic-exit strategy input is authorized.

## Indicator contract

For each completed M5 signal candle `t`:

1. Calculate Wilder directional movement:
   - `upMove = high[t] - high[t-1]`.
   - `downMove = low[t-1] - low[t]`.
   - `plusDM = upMove` only when `upMove > downMove && upMove > 0`, otherwise zero.
   - `minusDM = downMove` only when `downMove > upMove && downMove > 0`, otherwise zero.
   - `TR = max(high-low, abs(high-prevClose), abs(low-prevClose))`; Pine's first usable true-range sample falls back to `high-low` when previous close is unavailable.
2. Apply Pine-compatible RMA/Wilder smoothing with alpha `1 / diLength` to `plusDM`, `minusDM`, and `TR`.
3. `DI+ = 100 * smoothedPlusDM / smoothedTR`; `DI- = 100 * smoothedMinusDM / smoothedTR`, with Pine-compatible zero/undefined handling.
4. `DX = 100 * abs(DI+ - DI-) / (DI+ + DI-)`.
5. `ADX = RMA(DX, adxSmoothingLength)`.
6. `bbBasis = SMA(close, bbLength)`.
7. `bbDev = bbMultiplier * populationStdDev(close, bbLength)`. Pine `ta.stdev` defaults to the biased/population convention, dividing by `N`, not `N-1`.
8. `bbUpper = bbBasis + bbDev`; `bbLower = bbBasis - bbDev`.
9. `signalAtr = RMA(TR, atrLength)` using the signal candle's completed value.

DI values are audit fields, not directional filters. Warm-up bars with any undefined required value cannot create a signal.

MT5 built-ins are not presumed numerically equivalent. `iADXWilder` accepts only one period and therefore cannot represent unequal DI and ADX smoothing lengths; even with both defaults equal to seven, seeding and undefined-value behavior must be proven. `iBands`, `iStdDev`, and `iATR` likewise require value-by-value validation. The preferred implementation is a small deterministic calculation layer reproducing the formulas and Pine initialization rules, with built-ins used only after equivalence is demonstrated.

## Signal semantics

A long candidate exists for completed candle `t` exactly when:

`ADX[t] < InpADXBBADXThreshold && close[t] < bbLower[t]`

A short candidate exists exactly when:

`ADX[t] < InpADXBBADXThreshold && close[t] > bbUpper[t]`

All comparisons are strict. Equality is not a signal. Each completed candle is evaluated independently, so consecutive qualifying candles create distinct candidates. Candidate identity should be deterministic: `ADXBB|symbol|M5|signalOpenTime|direction`.

The candidate freezes signal open/close timestamps, direction, close, ADX, DI+, DI-, basis, upper/lower bands, ATR, ATR multiplier, and risk distance. It must not contain OBR/session fields.

## Causal execution lifecycle

1. Candle `t` closes at `t + 5 minutes`; only then may its candidate exist.
2. The sole execution window is the immediately following M5 candle `[t+5, t+10)`.
3. Planning must see the current M5 bar open time equal to the candidate's known-from time. Earlier is non-causal; later is expired. There is no retry on a later candle.
4. Obtain a fresh executable quote: Ask for long, Bid for short. Apply generic quote-age, spread, deviation, market, ownership, margin, volume, and broker checks.
5. Use the frozen risk distance; never recalculate signal ATR at execution.
6. Build and normalize the protective SL, size monetarily from executable quote to submitted SL, submit the market order, obtain the authoritative fill, freeze Original R, and attach the fixed-R target.

Repeated candidates remain independently observable. Generic one-position-per-symbol protection may reject a candidate while another E2 position is open. Such rejection does not defer or queue the candidate.

## ATR, stop, sizing, Original R, and target

`riskDistance = signalAtr * InpADXBBATRMultiplier`.

At the execution opportunity:

- Long intended SL: current executable Ask minus frozen risk distance.
- Short intended SL: current executable Bid plus frozen risk distance.

This intentionally preserves Pine's distance rather than its historical absolute signal-close stop. The submitted SL may only move outward as required by tick normalization and broker stop/freeze distance. Monetary sizing uses the current executable entry reference and actual submitted SL through E2's MT5-native symbol/account economics. Pine `pointValue` sizing is forbidden.

After fill:

`OriginalR = abs(actualFill - submittedInitialSL)`.

Original R is immutable and must survive restart. The target is:

- Long: `actualFill + OriginalR * InpADXBBTargetR`.
- Short: `actualFill - OriginalR * InpADXBBTargetR`.

The target is broker-normalized and attached using the existing protected execution lifecycle. No trailing stop, breakeven, partial exit, band-basis exit, ADX exit, time exit, or dynamic target exists.

## Daily and ownership semantics

The strategy day is the broker/server calendar date of the successful entry deal. This is the smallest deterministic authority because ADXBB has no market session or timezone. Candidate signal date may be stored separately, but the fill date owns daily consumption when a signal crosses midnight.

When `InpOneTradePerDay=false`, there is no daily lock. Multiple sequential successful trades per symbol/day are allowed after earlier positions close. Overlapping/pyramided positions remain disallowed by the generic E2 position guard.

When `InpOneTradePerDay=true`, the first successful entry deal consumes that symbol/server-date. Rejected candidates, expired candidates, failed orders, and unfilled attempts do not consume it. The lock must be reconstructible from entry-deal history and persisted only as necessary for restart consistency.

## Future verification acceptance

- Signal calculations use only completed M5 values and reproduce exported Pine values within declared numeric tolerances.
- Strict-comparison decisions match exactly, including threshold-near samples.
- Every candidate has one unique completed signal candle/direction and one immediate next-M5 window.
- Frozen ATR/risk distance never mutates.
- Submitted SL, volume, fill, immutable Original R, and normalized 1.1R target reconcile.
- Ownership prevents overlap; daily locking follows its toggle and successful-fill semantics.
- Reporting is passive and no OBR, session, weekday, news, or custom visual behavior affects signals.

## Indicator-equivalence validation plan

1. Export one common M5 OHLC dataset and Pine rows containing time, TR, smoothed TR, +DM/-DM, DI+/DI-, DX, ADX, basis, standard deviation, upper/lower bands, and ATR at full available precision.
2. Implement formula-level MT5 diagnostic calculations with explicit warm-up/seeding, not trading logic.
3. Compare at least 500 consecutive post-warm-up bars plus first-valid boundaries, gaps, flat/zero-range bars, and values immediately around ADX/band thresholds.
4. Separately compare MT5 `iADX`, `iADXWilder`, `iATR`, `iBands`, `iMA`, and `iStdDev` outputs to determine whether any built-in is safe.
5. Record maximum absolute/relative/tick differences and signal-decision mismatches. Zero decision mismatches are required on the locked dataset; tolerances may describe floating-point noise but may not alter parameters or comparisons.
6. Repeat across at least two symbols and data feeds. Feed differences must be classified separately from formula differences.

Primary references: TradingView Pine/PineJS documentation for `dmi`, RMA, ATR, true range, SMA and biased standard deviation; MQL5 reference for `iADXWilder`, `iATR`, `iBands`, `iMA`, and `iStdDev`.
