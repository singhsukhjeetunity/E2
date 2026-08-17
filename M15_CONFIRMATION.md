# M15 Confirmation

`E2M15ConfirmationEngine` is the sole owner of completed-M15 candle measurement and confirmation formulas. Callers supply immutable zone geometry and requested context; the engine does not fetch H1 zones, H1 ranges, or strategy state.

## Shared candle geometry

```text
body       = abs(close - open)
range      = high - low
lowerWick  = min(open, close) - low
upperWick  = high - max(open, close)
knownFrom  = candle open + 15 minutes
```

OHLC values must be finite, `high >= low`, and open/close must lie within high/low. Zero range cannot pass. Zero body is measured without division and fails directional rejection. Confirmation is rejected if `knownFrom > evaluationTime`.

## Momentum confirmation

Trend Continuation retains the existing momentum path: preceding-body median, body multiplier, body/range, closing location, previous-candle break, and directional zone-edge recovery. Its formulas, thresholds, and routing are unchanged.

## Rejection confirmation

Bullish rejection requires an immutable SUPPORT band and all of:

```text
low <= zoneUpper and high >= zoneLower
close > open
close > zoneUpper
lowerWick >= 1.50 * body
lowerWick / range >= 0.40
```

Bearish rejection requires an immutable RESISTANCE band and all of:

```text
low <= zoneUpper and high >= zoneLower
close < open
close < zoneLower
upperWick >= 1.50 * body
upperWick / range >= 0.40
```

Recovery is strict: closing exactly on the challenged edge fails. Wick thresholds are inclusive under E2's deterministic floating-point tolerance, so exact `1.50` and `0.40` qualify.

Failure classification follows this order:

1. `INVALID_CANDLE`
2. `INVALID_ZONE`
3. `CAUSALITY_VIOLATION`
4. `NO_ZONE_INTERSECTION`
5. `WRONG_DIRECTION`
6. `NO_RECOVERY`
7. `WICK_BODY_TOO_SMALL`
8. `WICK_RANGE_TOO_SMALL`
9. `PASS`

The result exposes validity, direction, failure enum/string, OHLC and timestamps, zone geometry, intersection, body/range/wicks, relevant-wick ratios, and each gate result. Range Mean-Reversion carries this authoritative result without recomputation.

## Reuse and diagnostics

Prepared candle measurements are cached per completed candle. Directional rejection results are reused for the same candle, immutable zone identity/geometry/lifecycle, and direction. `M15_REJECTION_VERIFY` reports evaluation gates, passes, invalid/zero geometry, causality, duplicate suppression, and ratio statistics.

