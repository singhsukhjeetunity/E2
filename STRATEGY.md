# E2 Trend Pullback Strategy

E2’s current strategy seeks M15-confirmed pullbacks into H1 support/resistance in the H4 directional context. It is an implemented research strategy, not evidence of an edge or a production-readiness claim.

## v1.1.0-alpha framework boundary

Sprint 1.1 introduces the future research identities `TREND_CONTINUATION`, `RANGE_MEAN_REVERSION`, and `RANGE_BREAKOUT`, with independent configuration toggles. Only the existing v1.0 trend-pullback implementation remains behaviorally active; Sprint 1.1 does not implement a strategy router, range logic, breakout state, alternative confirmation, or alternative exits.

`FIXED_2R` and `ZONE_TARGET_TRAILING` are framework-only management identities. They are not an instruction to change current exits. Future management routing must reject ambiguous active management configurations rather than silently select one.

Future strategy/state code will record decision-time regime, breakout, boundary, range/zone/attempt, and timestamp metadata in the shared `E2ResearchMetadata` contract before passing it one-way to reporting and visualization. No reporting or visual state may be used by strategy decisions.

Sprint 1.2 supplies a parallel H4 Regime Engine V2 for future research. Its UPTREND/DOWNTREND result is directional structure, not an entry instruction: a separate anti-extension flag can mark the trend temporarily ineligible without changing its regime. The existing trend-pullback rules below remain the only active strategy behavior until a later approved router sprint.

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

## v1.1 H1 Zone V2 research isolation

Sprint 1.3 introduces `E2H1ZoneEngine` solely as a future research-state producer. It is not used by this strategy: current entries continue to use `E2ZoneAnalyzer` and `E2SetupTracker`. Zone V2's ATR-relative pivot qualification, frozen boundaries, invalidation, and rearm state are documented in [H1_ZONE_V2.md](H1_ZONE_V2.md); they make no edge claim and cannot change current signals or trades.

Sprint 1.4 adds the separate `E2M15ConfirmationEngine`. Its median-body momentum and zone-context rejection snapshots are likewise not used by this strategy; the active v1.0 path continues to use `E2ConfirmationAnalyzer`. Details are in [M15_CONFIRMATION_V2.md](M15_CONFIRMATION_V2.md).

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
