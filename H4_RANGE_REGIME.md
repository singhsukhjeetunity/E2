# H4 Range Regime

The H4 regime engine is the sole owner of market-regime classification. Trend predicates retain precedence and their verified formulas.

For the latest completed H4 candle, after both trend predicates fail:

```text
rangeHigh = highest high of the latest 20 completed H4 candles
rangeLow = lowest low of the same candles
rangeWidth = rangeHigh - rangeLow
normalizedRangeWidth = rangeWidth / completed-candle ATR(14)

RANGE when:
    completed-candle ADX(14) <= 20
    and normalizedRangeWidth <= 6.0
otherwise:
    TRANSITION_UNCLASSIFIED (neutral)
```

The thresholds are centralized inputs and initial research values, not optimized claims.

`known_from_time` is the close time of the latest included H4 candle. The forming H4 candle is never read. The output exposes measurement validity, containment lookback, high, low, width, normalized width, ADX, and ATR.

The containment high and low are evidence used only to classify the H4 regime. They are not executable support/resistance boundaries and cannot create plans or trades. A later Range Mean Reversion sprint must select H1 boundaries independently from the persistent H1 zone architecture.

Trend Continuation continues to accept only UPTREND or DOWNTREND. Range Mean Reversion and Range Breakout have no routing or trading implementation.
