# E2 Trend Pullback Strategy

E2’s current strategy seeks M15-confirmed pullbacks into H1 support/resistance in the H4 directional context. It is an implemented research strategy, not evidence of an edge or a production-readiness claim.

## Strategy rules

- **H4 context:** `E2TrendAnalyzer` classifies confirmed structure as bullish, bearish, or range, with optional ADX strength filtering. Range and unknown context produce no signal.
- **H1 zones:** `E2ZoneAnalyzer` forms configurable multi-touch support/resistance zones, merges nearby reactions, and represents role reversal. `E2SetupTracker` records zone visits and arms eligible setups.
- **M15 confirmation:** a closed candle may qualify through any enabled engulfing, pin-bar, momentum, or previous-candle-break detector. A directional conflict rejects the candidate.
- **Direction:** bullish H4 context plus actionable support interaction and bullish confirmation produces LONG; bearish context plus resistance interaction and bearish confirmation produces SHORT.
- **Sessions:** only configured London and/or New York windows permit new entries. Overlap remains a distinct metadata classification.
- **News:** enabled historical-news filtering blocks relevant configured-impact events during inclusive configured before/after blackout windows.

## Trade construction

- LONG stop loss is below the selected support zone; SHORT stop loss is above resistance. `InpStopLossZoneBufferPips` supplies the configurable zone buffer.
- The target is the configured fixed reward-to-risk target (`InpRewardRiskTarget`; default 2.0).
- `E2PositionSizer` uses native symbol trade-calculation facilities and the configured percentage risk base (default equity) to normalize volume.

## Implementation and safety rules

These are safeguards, not a claim about market edge:

- Evaluation uses confirmed/closed bars only.
- `E2PositionManager` short-circuits candidates while an E2 position is open for the symbol.
- `E2PositionGuard` rejects duplicate/conflicting positions; `E2ExecutionSafety` enforces quote age, spread, deviation, and execution cooldown controls.
- `E2OrderExecutor` sends native MT5 orders with native SL/TP.
- A setup is consumed only after execution confirms success. A session/news/safety rejection occurs before `Consume()`, so an armed visit can remain available where its lifecycle permits.

## Research parameters

All active inputs are centralized in `include/core/E2Config.mqh`, including timeframes, swing/lookback/tolerance values, ADX settings, confirmation enablement, risk percentage, target R:R, session hours/UTC offset, news buffers, and spread/execution limits. These are research controls, not fitted claims.

Historical news uses a FILE_COMMON CSV with UTC timestamps and a per-run broker UTC offset. Its runtime verification remains outstanding; see [STATUS.md](STATUS.md).
