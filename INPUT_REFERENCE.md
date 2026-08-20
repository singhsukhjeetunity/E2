# E2 v2.0.1 Input Reference

This inventory traces the 84 externally configurable MT5 inputs from `E2Config.mqh` through `E2LoadConfiguration()` to their runtime consumers. Ownership reflects actual v2.0.0 wiring, not the input name. No input was renamed and no default was changed in v2.0.1.

`GLOBAL` below means operational or compatibility configuration rather than strategy edge. `SHARED_*` means the value can alter the named strategies' calculations. Strategy activation controls are owned by their respective strategy but live together in the MT5 strategy-selection group.

## Complete inventory

| Input | Default | Type | Ownership | Used By | Stage | Effect |
|---|---:|---|---|---|---|---|
| `InpEnableTrendContinuation` | `true` | `bool` | TC | `E2TrendContinuationEngine::Initialize/Evaluate`, `E2V2TradePlanEngine::RouteTrendContinuation` | BREAKOUT / PLANNING | Enables TC candidate and plan routing. |
| `InpEnableRangeMeanReversion` | `false` | `bool` | RMR | `E2RangeMeanReversionEngine::Initialize/Evaluate`, `E2V2TradePlanEngine::RouteRangeMeanReversion` | RANGE / PLANNING | Enables RMR candidate and plan routing. |
| `InpEnableRangeBreakout` | `false` | `bool` | RB | `E2RangeBreakoutEngine::ProcessPreEventH1/EvaluateM15`, `E2V2TradePlanEngine::RouteRangeBreakout` | BREAKOUT / PLANNING | Enables RB acceptance, candidate, and plan routing. |
| `InpTrendTimeframe` | `PERIOD_H4` | `ENUM_TIMEFRAMES` | SHARED_ALL | `E2MarketData::Initialize/TrendTimeframe`, `E2H4RegimeEngine::Evaluate`, `E2BacktestSummary` | REGIME / REPORTING | Selects the bar series used by the shared H4 regime engine; scheduling remains baseline-fixed. |
| `InpZoneTimeframe` | `PERIOD_H1` | `ENUM_TIMEFRAMES` | GLOBAL | `E2MarketData::Initialize/ZoneTimeframe`, `E2BacktestSummary` | REPORTING | Stored and reported; H1 strategy modules currently use hard-coded `PERIOD_H1`. |
| `InpConfirmationTimeframe` | `PERIOD_M15` | `ENUM_TIMEFRAMES` | GLOBAL | `E2MarketData::Initialize/ConfirmationTimeframe`, `E2BacktestSummary` | REPORTING | Stored and reported; confirmation and strategy modules currently use hard-coded `PERIOD_M15`. |
| `InpSwingSensitivity` | `3` | `int` | SHARED_ALL | `E2H4RegimeEngine::Initialize/Evaluate` | REGIME | Changes closed bars required on each side of an H4 pivot. |
| `InpTrendStructureLookbackBars` | `80` | `int` | SHARED_ALL | `E2H4RegimeEngine::Initialize/Evaluate`, `E2BacktestSummary` | REGIME / REPORTING | Requests H4 structure history; baseline engine enforces `max(value,300)`. |
| `InpAdxEnabled` | `true` | `bool` | GLOBAL | `E2BacktestSummary` | REPORTING | Reported only; it does not enable or disable the baseline ADX calculation. |
| `InpAdxPeriod` | `14` | `int` | SHARED_ALL | `E2H4RegimeEngine::Initialize/Indicators`, `E2BacktestSummary` | REGIME | Changes shared H4 ADX smoothing and readiness. |
| `InpAdxMinimumThreshold` | `20.0` | `double` | SHARED_ALL | `E2H4RegimeEngine::Initialize/Evaluate`, `E2BacktestSummary` | REGIME | Changes minimum ADX for trend classification, which also changes when range classification is considered. |
| `InpResearchH4EmaFastPeriod` | `20` | `int` | SHARED_ALL | `E2H4RegimeEngine::Initialize/Indicators/Evaluate` | REGIME | Changes the fast H4 EMA used in trend classification and extension distance. |
| `InpResearchH4EmaSlowPeriod` | `50` | `int` | SHARED_ALL | `E2H4RegimeEngine::Initialize/Indicators/Evaluate` | REGIME | Changes the slow H4 EMA used in trend direction. |
| `InpResearchH4EmaSlopeLookback` | `5` | `int` | SHARED_ALL | `E2H4RegimeEngine::Initialize/Evaluate` | REGIME | Changes the slow-EMA slope comparison interval. |
| `InpResearchH4AtrPeriod` | `14` | `int` | SHARED_ALL | `E2H4RegimeEngine::Initialize/Indicators/Evaluate` | REGIME | Changes H4 ATR normalization used by trend and range classification. |
| `InpResearchH4StructuralBreakoutDistanceAtr` | `0.10` | `double` | SHARED_ALL | `E2H4RegimeEngine::Initialize/Evaluate` | REGIME / BREAKOUT | Changes ATR distance required for an H4 structural break. |
| `InpH4RangeAdxMaximum` | `20.0` | `double` | SHARED_RMR_RB | `E2H4RegimeEngine::Initialize/Evaluate` | REGIME / RANGE | Changes the maximum ADX allowed for H4 range classification. |
| `InpH4RangeContainmentLookback` | `20` | `int` | SHARED_RMR_RB | `E2H4RegimeEngine::Initialize/Evaluate` | REGIME / RANGE | Changes the H4 window used to measure range containment and width. |
| `InpH4RangeMaximumWidthAtr` | `6.0` | `double` | SHARED_RMR_RB | `E2H4RegimeEngine::Initialize/Evaluate` | REGIME / RANGE | Changes maximum normalized H4 range width. |
| `InpRangeBoundaryContainmentToleranceAtr` | `0.25` | `double` | SHARED_RMR_RB | `E2H1RangeBoundaryEngine::Initialize/Evaluate` | RANGE | Changes allowed H1 boundary displacement outside the H4 range. |
| `InpRangeBoundaryMinimumHeightAtr` | `3.0` | `double` | SHARED_RMR_RB | `E2H1RangeBoundaryEngine::Initialize/Evaluate` | RANGE | Changes minimum support/resistance pair height in H1 ATR units. |
| `InpResearchRangeBoundaryInvalidationAtr` | `0.25` | `double` | SHARED_RMR_RB | `E2H1RangeBoundaryEngine::Initialize/Evaluate` | RANGE | Changes H1 close distance that invalidates an active range boundary. |
| `InpZoneLookbackBars` | `240` | `int` | SHARED_ALL | `E2H1ZoneEngine::Initialize/Evaluate`, `E2BacktestSummary` | ZONE | Changes closed H1 history used to discover shared zones. |
| `InpResearchH1AtrPeriod` | `14` | `int` | SHARED_ALL | `E2H1ZoneEngine::Initialize/Atr`, `E2TrendContinuationEngine::Initialize/Atr` | ZONE / BREAKOUT / PLANNING | Changes H1 ATR used by zones, TC breakout state, range normalization, and structural-stop inputs. |
| `InpResearchH1ZonePivotClusteringAtr` | `0.50` | `double` | SHARED_ALL | `E2H1ZoneEngine::Initialize/Discover` | ZONE | Changes maximum ATR-normalized distance between pivots forming a zone. |
| `InpResearchH1MinimumTouchSeparationBars` | `3` | `int` | SHARED_ALL | `E2H1ZoneEngine::Initialize/Discover` | ZONE | Changes minimum bar separation between zone-forming pivots. |
| `InpResearchH1MinimumPostTouchDepartureAtr` | `1.00` | `double` | SHARED_ALL | `E2H1ZoneEngine::Initialize/QualifyDeparture` | ZONE | Changes required post-pivot departure distance. |
| `InpResearchH1ZoneInvalidationAtr` | `0.10` | `double` | SHARED_ALL | `E2H1ZoneEngine::ApplyPersistentInvalidation`, `E2TrendContinuationEngine`, `E2V2TradePlanEngine` | ZONE / BREAKOUT / PLANNING | Changes shared zone invalidation and the baseline structural-stop buffer used by TC/RMR. |
| `InpResearchH1BreakoutDistanceAtr` | `0.10` | `double` | SHARED_TC_RB | `E2TrendContinuationEngine::Evaluate`, `E2RangeBreakoutEngine::CheckAcceptance` | BREAKOUT | Changes close distance beyond a zone/range edge for TC and RB. |
| `InpResearchH1ZoneRearmDistanceAtr` | `0.50` | `double` | SHARED_ALL | `E2H1ZoneEngine::Discover`, `E2RangeMeanReversionEngine::Evaluate`, `E2RangeBreakoutEngine::AgeOrInvalidate` | ZONE / RANGE / RETEST | Changes zone-attempt, RMR, and RB rearm distance. |
| `InpResearchM15BodyMedianLookback` | `20` | `int` | SHARED_ALL | `E2M15ConfirmationEngine::PrepareCandleMeasurement/MedianPrecedingBodies` | CONFIRMATION | Changes M15 history request and prior-body median; affects momentum and initial rejection data availability. |
| `InpResearchM15MomentumBodyMultiplier` | `1.25` | `double` | SHARED_TC_RB | `E2M15ConfirmationEngine::EvaluateMomentum` | CONFIRMATION | Changes TC/RB M15 body size required relative to the prior median. |
| `InpResearchM15MomentumBodyRangeMinimum` | `0.60` | `double` | SHARED_TC_RB | `E2M15ConfirmationEngine::EvaluateMomentum` | CONFIRMATION | Changes minimum body-to-range ratio for TC/RB momentum. |
| `InpResearchM15MomentumClosingLocationFraction` | `0.20` | `double` | SHARED_TC_RB | `E2M15ConfirmationEngine::EvaluateMomentum` | CONFIRMATION | Changes maximum distance of a momentum close from the directional candle extreme. |
| `InpResearchH4TrendExtensionLimitAtr` | `1.50` | `double` | TC | `E2H4RegimeEngine::Evaluate`, consumed by TC eligibility/planning | REGIME / PLANNING | Changes the H4 ATR extension at which a trend is marked overextended for TC. |
| `InpResearchRangeOuterEntryRegionFraction` | `0.20` | `double` | RMR | `E2RangeMeanReversionEngine::Initialize/Evaluate` | RANGE / RETEST | Changes the outer range region used to arm and detect RMR boundary visits. |
| `InpResearchM15RejectionWickBodyMinimum` | `1.50` | `double` | RMR | `E2M15ConfirmationEngine::EvaluateRejection` | CONFIRMATION | Changes minimum rejection-wick/body ratio for RMR. |
| `InpResearchM15RejectionWickRangeMinimum` | `0.40` | `double` | RMR | `E2M15ConfirmationEngine::EvaluateRejection` | CONFIRMATION | Changes minimum rejection-wick/range ratio for RMR. |
| `InpResearchH1BreakoutBodyLookback` | `20` | `int` | RB | `E2RangeBreakoutEngine::Median/ProcessPreEventH1` | BREAKOUT | Changes prior H1 body sample used by RB strong-body acceptance. |
| `InpResearchH1BreakoutBodyMultiplier` | `1.25` | `double` | RB | `E2RangeBreakoutEngine::CheckAcceptance` | BREAKOUT | Changes RB H1 body size required relative to the prior median. |
| `InpResearchH1BreakoutBodyRangeMinimum` | `0.60` | `double` | RB | `E2RangeBreakoutEngine::CheckAcceptance` | BREAKOUT | Changes minimum RB H1 body-to-range ratio. |
| `InpResearchH1BreakoutClosingLocationFraction` | `0.20` | `double` | RB | `E2RangeBreakoutEngine::CheckAcceptance` | BREAKOUT | Changes allowed RB H1 close distance from the directional extreme. |
| `InpResearchH1BreakoutRetestExpiryBars` | `12` | `int` | RB | `E2RangeBreakoutEngine::AgeOrInvalidate` | RETEST | Changes H1 bars before an accepted RB breakout expires. |
| `InpResearchH1BreakoutInvalidationDepthAtr` | `0.10` | `double` | RB | `E2RangeBreakoutEngine::AgeOrInvalidate`, `E2V2TradePlanEngine::RouteRangeBreakout` | BREAKOUT / PLANNING | Changes RB depth invalidation and structural-stop buffer. |
| `InpMaxSpreadPips` | `3.0` | `double` | SHARED_ALL | `E2V2TradePlanEngine` routes, `E2ExecutionSafety`, `E2BacktestSummary` | PLANNING / EXECUTION / REPORTING | Rejects opportunities/orders above the common spread ceiling; zero disables. |
| `InpEnableLondonSession` | `true` | `bool` | SHARED_ALL | `E2SessionFilter::Evaluate`, `E2BacktestSummary` | PLANNING / REPORTING | Allows entries during the configured London session. |
| `InpEnableNewYorkSession` | `true` | `bool` | SHARED_ALL | `E2SessionFilter::Evaluate`, `E2BacktestSummary` | PLANNING / REPORTING | Allows entries during the configured New York session. |
| `InpBrokerUtcOffsetHours` | `999` | `int` | SHARED_ALL | `E2SessionFilter`, `E2NewsFilter`, `E2BacktestSummary` | PLANNING / REPORTING | Converts broker time for shared session/news evaluation; sentinel `999` remains baseline-invalid for session eligibility. |
| `InpLondonSessionStartHour` | `8` | `int` | SHARED_ALL | `E2SessionFilter::Evaluate`, `E2BacktestSummary` | PLANNING / REPORTING | Sets inclusive London local start hour. |
| `InpLondonSessionEndHour` | `17` | `int` | SHARED_ALL | `E2SessionFilter::Evaluate`, `E2BacktestSummary` | PLANNING / REPORTING | Sets exclusive London local end hour. |
| `InpNewYorkSessionStartHour` | `8` | `int` | SHARED_ALL | `E2SessionFilter::Evaluate`, `E2BacktestSummary` | PLANNING / REPORTING | Sets inclusive New York local start hour. |
| `InpNewYorkSessionEndHour` | `17` | `int` | SHARED_ALL | `E2SessionFilter::Evaluate`, `E2BacktestSummary` | PLANNING / REPORTING | Sets exclusive New York local end hour. |
| `InpNewsFilterEnabled` | `true` | `bool` | SHARED_ALL | `E2NewsFilter::Initialize/Evaluate`, `E2V2TradePlanEngine`, `E2BacktestSummary` | PLANNING / REPORTING | Enables shared historical-news exclusion. |
| `InpHighImpactBufferBeforeMins` | `30` | `int` | SHARED_ALL | `E2NewsFilter::Evaluate`, `E2BacktestSummary` | PLANNING / REPORTING | Changes blocked minutes before a qualifying news event. |
| `InpHighImpactBufferAfterMins` | `30` | `int` | SHARED_ALL | `E2NewsFilter::Evaluate`, `E2BacktestSummary` | PLANNING / REPORTING | Changes blocked minutes after a qualifying news event. |
| `InpNewsHighImpactOnly` | `true` | `bool` | SHARED_ALL | `E2NewsFilter::Evaluate`, `E2BacktestSummary` | PLANNING / REPORTING | Restricts blocking to high-impact events when true. |
| `InpNewsDataFile` | `"E2_news_events.csv"` | `string` | SHARED_ALL | `E2NewsFilter::Initialize/Load` | PLANNING | Selects the common historical-news CSV. |
| `InpRiskMode` | `E2_RISK_FIXED_CASH` | `E2RiskMode` | RISK | `E2PositionSizer::Initialize/CalculateRequestedRisk`, diagnostics | RISK | Selects fixed-cash or current-balance-percent risk. |
| `InpFixedCashRisk` | `1000.0` | `double` | RISK | `E2PositionSizer::Initialize/CalculateRequestedRisk` | RISK | Sets requested cash risk in fixed-cash mode. |
| `InpBalanceRiskPercent` | `1.0` | `double` | RISK | `E2PositionSizer::Initialize/CalculateRequestedRisk`, compatibility summary mapping | RISK / REPORTING | Sets percentage of current MT5 balance requested in balance-percent mode. |
| `InpExpertMagicNumber` | `2026001` | `ulong` | EXECUTION | `E2PositionGuard`, `E2OrderExecutor`, `E2V2ExecutionEngine`, `E2V2PositionManager`, `E2.mq5`, reports | EXECUTION / MANAGEMENT / REPORTING | Changes E2 order/position ownership namespace. |
| `InpTradingEnabled` | `true` | `bool` | EXECUTION | `E2OrderExecutor`, `E2ExecutionSafety`, `E2V2ExecutionEngine` | EXECUTION | Master-gates native order execution. |
| `InpMaxEntryDeviationPips` | `2.0` | `double` | EXECUTION | `E2OrderExecutor::Execute` | EXECUTION | Rejects orders whose executable price deviates too far from the request. |
| `InpMaxQuoteAgeSeconds` | `10` | `int` | EXECUTION | `E2V2TradePlanEngine` routes, `E2ExecutionSafety` | PLANNING / EXECUTION | Rejects stale quotes; zero disables the age check. |
| `InpMinimumSecondsBetweenExecutions` | `5` | `int` | EXECUTION | `E2ExecutionSafety` | EXECUTION | Sets shared cooldown after a successful execution. |
| `InpEnableFixed2RManagement` | `true` | `bool` | MANAGEMENT | `E2V2TradePlanEngine` management routing | PLANNING / MANAGEMENT | Selects the fixed native 2R branch when it is the sole enabled management branch. |
| `InpEnableZoneTargetTrailingManagement` | `false` | `bool` | MANAGEMENT | `E2V2TradePlanEngine` management routing | PLANNING / MANAGEMENT | Selects zone target plus milestone trailing when it is the sole enabled branch. |
| `InpDebugMode` | `false` | `bool` | REPORTING | `E2.mq5` logger initialization | REPORTING | Enables debug-level logging. |
| `InpResearchVerificationSummary` | `true` | `bool` | REPORTING | `E2.mq5` tester diagnostics | REPORTING | Enables bounded tester verification summaries, including input verification. |
| `InpResearchVerboseDiagnostics` | `false` | `bool` | REPORTING | Analysis engines and planner logging gates | REPORTING | Enables verbose research diagnostics without changing decision formulas. |
| `InpLoggingEnabled` | `true` | `bool` | REPORTING | `E2.mq5` logger initialization | REPORTING | Enables E2 journal logging. |
| `InpCsvExportEnabled` | `false` | `bool` | REPORTING | `E2TradeReporter`, `E2BacktestSummary` initialization | REPORTING | Enables trade and summary CSV export. |
| `InpVisualModeEnabled` | `true` | `bool` | REPORTING | `E2.mq5`, `E2Visualizer` | REPORTING | Enables tester visual-audit processing. |
| `InpVisualShowConfirmations` | `true` | `bool` | REPORTING | `E2Visualizer` | REPORTING | Shows confirmation objects in the visual audit. |
| `InpVisualShowTrades` | `true` | `bool` | REPORTING | `E2Visualizer` | REPORTING | Shows trade objects in the visual audit. |
| `InpVisualShowH4RegimeV2` | `true` | `bool` | REPORTING | `E2Visualizer` | REPORTING | Shows H4 regime audit objects. |
| `InpVisualShowH1ZoneV2` | `true` | `bool` | REPORTING | `E2Visualizer` | REPORTING | Shows H1 zone audit objects. |
| `InpVisualShowH1RangeBoundaries` | `true` | `bool` | REPORTING | `E2Visualizer` | REPORTING | Shows range-boundary audit objects. |
| `InpVisualShowM15ConfirmationV2` | `true` | `bool` | REPORTING | `E2.mq5::E2RunM15ConfirmationV2`, `E2Visualizer` | REPORTING | Enables standalone M15 confirmation visualization. |
| `InpVisualShowTrendContinuationV2` | `true` | `bool` | REPORTING | `E2Visualizer` | REPORTING | Shows TC candidate audit objects. |
| `InpVisualShowRangeMeanReversionV2` | `true` | `bool` | REPORTING | `E2Visualizer` | REPORTING | Shows RMR candidate audit objects. |
| `InpVisualAuditMode` | `E2_VISUAL_ALL_TRADES` | `E2VisualAuditMode` | REPORTING | `E2Visualizer` | REPORTING | Selects strategy, all-trades, or single-trade visual audit filtering. |
| `InpVisualFocusTradeId` | `0` | `ulong` | REPORTING | `E2Visualizer` | REPORTING | Selects the position identity for single-trade visual audit mode. |
| `InpVisualCleanupOnDeinit` | `true` | `bool` | REPORTING | `E2Visualizer::Shutdown` | REPORTING | Controls removal of E2 visual objects at deinitialization. |

## Configuration-flow audit

Every external input is declared once and copied once by `E2LoadConfiguration()` into `E2Config`. No duplicate external names and no wholly unconsumed declarations were found. The audit found these frozen baseline defects/ambiguities, which v2.0.1 deliberately does not repair:

- `InpAdxEnabled` is copied and reported but never read by `E2H4RegimeEngine`; ADX remains active regardless of the toggle.
- `InpZoneTimeframe` is copied/stored/reported, but H1 zone/range/breakout modules use hard-coded `PERIOD_H1`.
- `InpConfirmationTimeframe` is copied/stored/reported, but TC/RMR/RB confirmation paths use hard-coded `PERIOD_M15`.
- `InpTrendStructureLookbackBars=80` reaches `E2H4RegimeEngine`, which applies the pre-existing `MathMax(value,300)` floor. Values below 300 are shadowed by that floor.
- `InpBalanceRiskPercent` also populates internal compatibility field `risk_percent` for the legacy backtest-summary column. Position sizing itself reads the authoritative risk-mode fields.
- `InpMaxSpreadPips` is intentionally checked at planning and execution safety; this is one exposed input with two defensive consumers, not a duplicate input.

## If researching TREND_CONTINUATION

### A. TC-exclusive inputs

- `InpEnableTrendContinuation`
- `InpResearchH4TrendExtensionLimitAtr`

### B. Shared inputs that can affect TC

- Shared H4 trend/regime inputs: `InpTrendTimeframe`, `InpSwingSensitivity`, `InpTrendStructureLookbackBars`, `InpAdxPeriod`, `InpAdxMinimumThreshold`, the H4 EMA inputs, `InpResearchH4AtrPeriod`, and `InpResearchH4StructuralBreakoutDistanceAtr`.
- Shared H1 zone inputs: `InpZoneLookbackBars`, `InpResearchH1AtrPeriod`, clustering, touch separation, post-touch departure, invalidation, and rearm distance.
- TC/RB shared breakout and momentum inputs: `InpResearchH1BreakoutDistanceAtr`, M15 body median, momentum body multiplier, body/range minimum, and closing-location fraction.
- Shared filters, risk, execution, and management inputs can change whether and how an otherwise-valid TC opportunity is executed.
- Enabling RMR or RB can affect integrated TC executions through the shared one-position ownership rule, even though their exclusive edge parameters are not read by TC formulas.

### C. Inputs that do not directly affect TC calculations

- RMR-exclusive outer-region and rejection-wick inputs.
- RB-exclusive H1 strong-body, expiry, and depth-invalidation inputs.
- H4 range-only and H1 range-boundary inputs (`SHARED_RMR_RB`).
- Reporting and visualization inputs do not change TC trading decisions.

## If researching RANGE_MEAN_REVERSION

### A. RMR-exclusive inputs

- `InpEnableRangeMeanReversion`
- `InpResearchRangeOuterEntryRegionFraction`
- `InpResearchM15RejectionWickBodyMinimum`
- `InpResearchM15RejectionWickRangeMinimum`

### B. Shared inputs that can affect RMR

- All shared H4 regime inputs, including the range ADX/containment/width inputs.
- Shared H1 zone construction/lifecycle inputs and all H1 range-boundary inputs.
- `InpResearchM15BodyMedianLookback` can change the M15 history request/readiness shared with rejection evaluation.
- Shared session, news, spread, risk, execution, and applicable management configuration.
- Enabling TC or RB can affect integrated RMR executions through shared position ownership.

### C. Inputs that do not directly affect RMR calculations

- TC extension limit.
- TC/RB breakout-distance and momentum-threshold inputs.
- RB-exclusive H1 strong-body, expiry, and depth-invalidation inputs.
- Reporting and visualization inputs do not change RMR trading decisions.

## If researching RANGE_BREAKOUT

### A. RB-exclusive inputs

- `InpEnableRangeBreakout`
- `InpResearchH1BreakoutBodyLookback`
- `InpResearchH1BreakoutBodyMultiplier`
- `InpResearchH1BreakoutBodyRangeMinimum`
- `InpResearchH1BreakoutClosingLocationFraction`
- `InpResearchH1BreakoutRetestExpiryBars`
- `InpResearchH1BreakoutInvalidationDepthAtr`

### B. Shared inputs that can affect RB

- All shared H4 regime inputs, including the range ADX/containment/width inputs.
- Shared H1 zone construction/lifecycle inputs and all H1 range-boundary inputs.
- TC/RB shared breakout distance and M15 momentum inputs.
- Shared session, news, spread, risk, execution, and zone-target management configuration.
- Enabling TC or RMR can affect integrated RB executions through shared position ownership.

### C. Inputs that do not directly affect RB calculations

- TC extension limit.
- RMR outer-region and rejection-wick inputs.
- Reporting and visualization inputs do not change RB trading decisions.

## Verification diagnostics

At tester initialization with verification summaries enabled, `[INPUT_CONFIG_VERIFY]` reports strategy toggles, risk mode, and total/ownership counts. `[INPUT_CONFIG_VERIFY_2]` reports duplicate/dead/shadowed/mapping audit counts and an FNV-style deterministic fingerprint over all 84 configured input values. `[INPUT_ISOLATION_VERIFY]` reports direct cross-reads of exclusive configuration; all six cross-strategy counters are expected to remain zero.

Current static counts are:

- total exposed inputs: 84
- global/operational/compatibility inputs: 30
- TC-exclusive inputs, including activation: 2
- RMR-exclusive inputs, including activation: 4
- RB-exclusive inputs, including activation: 7
- shared strategy inputs, including shared trade filters: 41
- duplicate exposed inputs: 0
- wholly unconsumed exposed inputs: 0
- behavior-dead compatibility inputs: 3
- shadowed inputs: 1
- ownership conflicts: 0
- known invalid/misleading configuration mappings: 3
