# Trend Pullback Strategy v1

The Trend Pullback strategy is the Version 1 E2 strategy. It uses closed-candle, multi-timeframe analysis to seek pullbacks into H1 support/resistance zones in the established H4 direction, with M15 confirmation.

# Trend / Range Filter

Timeframe: H4

Bullish:

- Higher Highs + Higher Lows

Bearish:

- Lower Highs + Lower Lows

Range:

- No valid directional HH/HL or LH/LL structure
- ADX is used as an additional objective trend-strength/range filter

Only trade in the direction of the H4 trend.

No trades when the H4 market is classified as ranging.

# Support / Resistance

Timeframe: H1

Significant zones are based on:

- Multiple price reactions/touches
- Minimum touches must be configurable
- Nearby reactions should be merged into a zone using configurable tolerance
- Broken support can become resistance
- Broken resistance can become support
- Zone width/tolerance must be configurable

# Entry Confirmation

Timeframe: M15

A valid trade requires price to pull back into an appropriate H1 zone.

Entry can be confirmed by any enabled confirmation:

- Bullish/Bearish Engulfing
- Pin Bar
- Momentum Candle
- Break of Previous Candle

Confirmation types must be independently configurable so their performance can later be tested separately.

# Entry

Enter after the valid M15 confirmation candle has closed.

# Stop Loss

For long trades:

- Below the relevant support zone

For short trades:

- Above the relevant resistance zone

Use a configurable buffer beyond the zone.

# Take Profit

Fixed target: 2R

Must be configurable for research.

# Risk

Risk per trade: 1% of account equity/balance according to the final risk specification.

Risk percentage must be configurable.

# Sessions

Only allow new trades during:

- London session
- New York session

Session times must be configurable and handled consistently with broker/server time.

# News

No new trades:

- 60 minutes before high-impact news
- 60 minutes after high-impact news

News buffer must be configurable.

The news system must be replaceable/pluggable because historical and live economic-calendar sources may differ.

# Important Strategy Design Rule

The Trend Pullback strategy is only the first E2 strategy.

E2 must allow this strategy to be replaced later without rebuilding:

- MT5 integration
- Trade execution
- Risk management
- Logging
- Reporting
- Backtesting compatibility
