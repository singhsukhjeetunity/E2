# E2 OBR Existing Architecture Audit

> Sprint 1 implementation note: the audit's deletion order was followed. The final core exposes 21 rather than the provisional 19 KEEP-only inputs because the new core-verification switch and retained news-time conversion have concrete generic consumers. The V2 execution adapter and V2 position manager were removed rather than kept as compatibility shells; generic order execution, ownership guarding and deal reporting remain in narrower contracts. See current `ARCHITECTURE.md` and `INPUT_REFERENCE.md`.

Status: Sprint 0 static audit only. No source, input, formula, or runtime behavior has been changed.

## Audit method and classification rule

The audit followed `E2.mq5` includes, global objects, initialization, `OnTick`, `OnTradeTransaction`, and deinitialization into every reachable `.mqh`, the news-export utility, and repository documentation. `INPUT_REFERENCE.md` was checked against all 84 declarations and `E2LoadConfiguration()` assignments.

Each meaningful component below has exactly one disposition:

- **KEEP**: strategy-independent and reusable substantially as-is.
- **MODIFY**: useful responsibility remains, but its interface/data/implementation contains old-strategy assumptions.
- **REMOVE**: exists only for TC/RMR/RB or their market model and has no baseline OBR role.

Classification is for the later conversion, not an instruction to act in Sprint 0.

## Runtime architecture map

`E2.mq5` currently owns all modules. Each tick it evaluates H4 regime and H1 zones/range state, runs M15 confirmation plus TC/RMR/RB engines, routes their candidates through one V2 planner, executes through the V2 adapter and generic order layer, manages positions through a V2 manager, then reports and visualizes strategy-specific verification. Deal events flow from `OnTradeTransaction` to the reporter and position manager. Deinitialization reconciles deals, emits the large strategy-specific backtest summary, and cleans visual objects.

The architecture is layered in name but not cleanly at the strategy boundary: `E2Config` includes old research types; the V2 plan includes TC direction and H4/zone/retest fields; V2 execution maps old plans into generic requests; management branches on old strategy/zone behavior; reporter rows and summaries expect old identities; visualizer directly includes five analysis engines.

## Source component disposition

| Component / file | Class | Evidence and required Sprint 1 treatment |
|---|---|---|
| `E2.mq5` | MODIFY | Keep EA lifecycle, configuration load, environment/broker initialization, tick/deal hooks, reporter reconciliation. Remove old includes, globals, schedulers, candidates/plans/execution routing, strategy diagnostics. Stripped core must never create a plan. |
| `include/core/E2Environment.mqh` | KEEP | Generic terminal/tester/runtime validation; no TC/RMR/RB types. |
| `include/core/E2SymbolInfo.mqh` | KEEP | Generic symbol specification, price/pip/volume and broker metadata. |
| `include/core/E2AccountInfo.mqh` | KEEP | Generic account snapshot and margin information. |
| `include/core/E2Config.mqh` | MODIFY | Generic loader/validation/hash is useful, but it imports `E2ResearchTypes`, exposes 84 mixed inputs, stores old market-model/strategy/visual fields, and validates removed formulas. Reduce only in Sprint 1; later add locked OBR configuration. |
| `include/analysis/E2MarketData.mqh` | KEEP | Generic closed-bar/as-of access and history-readiness utilities. Its config timeframe getters may become unnecessary, but the causal retrieval service is reusable without old analysis types. |
| `include/analysis/E2H4RegimeEngine.mqh` | REMOVE | H4 swing/EMA/ADX trend-range classifier is the retired shared market model; OBR needs direct ADX, not H4 regime classification. |
| `include/analysis/E2H1ZoneEngine.mqh` | REMOVE | Persistent pivot-cluster support/resistance zones, invalidation, role gates, departures, lifetimes and diagnostics have no baseline OBR role. |
| `include/analysis/E2H1RangeBoundaryEngine.mqh` | REMOVE | Constructs H1 ranges from H4 regime plus H1 zones for RMR/RB; unrelated to daily opening range. |
| `include/analysis/E2M15ConfirmationEngine.mqh` | REMOVE | Old momentum/rejection and zone-intersection confirmation. OBR requires only a completed close outside frozen OR. |
| `include/analysis/E2TrendContinuationEngine.mqh` | REMOVE | TC breakout/retest state machine and candidate/verification types. |
| `include/analysis/E2RangeMeanReversionEngine.mqh` | REMOVE | RMR boundary visit/rejection/rearm state machine and candidate/verification types. |
| `include/analysis/E2RangeBreakoutEngine.mqh` | REMOVE | Despite its name, this is H1 range breakout/retest/M15 momentum logic, not OBR. |
| `include/strategy/E2ResearchTypes.mqh` | REMOVE | Enums and metadata are exclusively old strategy, H4 regime, zone/boundary, tactical-breakout and old management vocabulary. A future small OBR type file should be new, not a compatibility extension. |
| `include/strategy/E2V2TradePlanEngine.mqh` | REMOVE | Planner is structurally TC/RMR/RB-specific: direct engine includes, TC direction in the shared plan, H4/zone/range/retest fields, opposing-zone targets, multi-strategy routes and verification. Its few generic checks already exist downstream or can be called by a future OBR planner. |
| `include/filters/E2SessionFilter.mqh` | REMOVE | London/New York DST/session eligibility is not the 08:00-09:00 OR clock and would create a hidden extra filter. A future OR clock/day service must have an explicitly locked timezone interface. |
| `include/filters/E2NewsFilter.mqh` | KEEP | Generic deterministic CSV news eligibility by symbol/currency/time. Whether OBR uses it is a rule decision; retaining it does not silently enable it. |
| `include/risk/E2PositionSizer.mqh` | KEEP | Generic FIXED_CASH/BALANCE_PERCENT requested risk, MT5 loss calculation and volume normalization. Future OBR must call the requested-risk path with actual fill/submitted SL, not the TC compatibility helper. |
| `include/risk/E2OrderRequest.mqh` | MODIFY | Generic order carrier concept is useful, but it includes position sizer for direction/status and lacks explicit structural stop versus submitted SL and OBR decision/fill metadata. Decouple shared direction into core/execution types. |
| `include/execution/E2PositionGuard.mqh` | KEEP | Generic magic/symbol ownership, open-position/pending-order/account-mode guard. Daily OBR consumption is separate. |
| `include/execution/E2ExecutionSafety.mqh` | KEEP | Generic quote, spread, trade mode, market, volume, margin, cooldown and trade-context validation. Application of spread/deviation gates to OBR remains a rule decision. |
| `include/execution/E2OrderExecutor.mqh` | MODIFY | Core market execution and broker validation are reusable. It currently prices/revalidates a pre-sized request and reports V2-compatible results; OBR requires fill-authoritative geometry/sizing sequencing or an explicitly safe preflight/execute/reconcile interface. |
| `include/execution/E2V2ExecutionEngine.mqh` | MODIFY | Keep the responsibilities of magic ownership, successful-fill registration, immutable Original R capture, and reporter handoff. Remove the `E2V2TradePlan`, strategy ownership counters, TC/RMR/RB verification, old metadata and management enums; likely rename/rebuild as a generic execution coordinator. |
| `include/execution/E2V2PositionManager.mqh` | MODIFY | Keep generic owned-position discovery/recovery and protective-state supervision where real. Remove zone target/milestone trailing, RMR branches, old plan include, old strategy comments/metadata. Baseline OBR needs no active trailing/breakeven/partial management. |
| `include/reporting/E2Logger.mqh` | KEEP | Generic bounded journal logging. |
| `include/reporting/E2CsvExporter.mqh` | KEEP | Generic CSV file lifecycle and row writer. Schema ownership remains above it. |
| `include/reporting/E2TradeReporter.mqh` | MODIFY | Deal-authoritative reconciliation, magic filtering, duplicate suppression, P/L aggregation and immutable Original-R reporting are reusable. Entry schema and invariant helpers assume range/zone/candidate/plan/management identities; add OR/decision/structural-vs-submitted fields later and remove old setup-specific checks. |
| `include/reporting/E2BacktestSummary.mqh` | MODIFY | Summary/file mechanism is reusable, but configuration columns, setup buckets and verification payload are overwhelmingly old architecture. Sprint 1 should emit generic core zero-activity counters only. |
| `include/visualization/E2Visualizer.mqh` | MODIFY | Generic object lifecycle, trade SL/TP/fill display and cleanup are reusable. Remove direct old-engine includes and all H4/H1/M15/TC/RMR/RB layers. OBR visuals require a future narrow interface; the hard-coded `TCV2` trade label is hidden baggage. |
| `utilities/E2NewsExporter.mq5` | KEEP | Standalone generic economic-calendar-to-CSV utility used by retained news infrastructure; it is not reachable trading logic from `E2.mq5`. Its own utility inputs are outside the EA's 84-input audit. |

## Documentation disposition

| Documentation | Class | Reason |
|---|---|---|
| `OBR_STRATEGY.md` | KEEP | Canonical OBR specification and unresolved decisions. |
| `OBR_ARCHITECTURE_AUDIT.md` | KEEP | Sprint 0 audit and authorized Sprint 1 plan. |
| `NEWS_DATA_WORKFLOW.md` | KEEP | Generic retained news/export workflow. |
| `CONTRIBUTING.md` | KEEP | Repository workflow; no strategy formula ownership found. |
| `ARCHITECTURE.md`, `STRATEGY.md`, `ROADMAP.md`, `STATUS.md`, `INPUT_REFERENCE.md`, `PRODUCTION_CONFIGURATION.md`, `INTEGRITY_AUDIT.md`, `INTEGRATION_VALIDATION.md` | MODIFY | Preserve history now; after source conversion, update current-state claims, diagrams, validation, configuration and input inventory. `STATUS.md` alone receives the required Sprint 0 notice. |
| `EXECUTION_V2.md`, `POSITION_MANAGEMENT_V2.md` | MODIFY | Contain useful historical constraints but describe V2 plan/management contracts. Replace current guidance with generic/OBR contracts after refactor; retain history in Git. |
| `H4_REGIME_V2.md`, `H4_RANGE_REGIME.md`, `H1_ZONE_V2.md`, `H1_RANGE_BOUNDARIES.md`, `M15_CONFIRMATION.md`, `M15_CONFIRMATION_V2.md`, `TREND_CONTINUATION_V2.md`, `TREND_CONTINUATION_PLAN_V2.md`, `TREND_CONTINUATION_REPORTING.md`, `RANGE_MEAN_REVERSION.md`, `RANGE_MEAN_REVERSION_EXECUTION.md`, `RANGE_MEAN_REVERSION_REPORTING.md`, `RANGE_BREAKOUT.md`, `RANGE_BREAKOUT_EXECUTION.md`, `RANGE_BREAKOUT_REPORTING.md` | REMOVE | Obsolete current documentation for components removed in Sprint 1. Git history preserves it; do not delete during Sprint 0. |

## Detailed REMOVE dependency ledger

| Remove component | Includes / data / enums | Runtime call sites | Downstream dependencies that must be cut first |
|---|---|---|---|
| H4 regime | Includes market data; `E2H4BreakDirection`, `E2H4RegimeSwing`, `E2H4RegimeResult`, range verification | `E2RunH4RegimeV2`, OnTick, initialization, visualizer, all strategies/planner, summaries | H1 range, TC/RMR/RB, V2 plan fields, visual H4 layer, summary counters, H4 inputs/docs |
| H1 zones | Includes market data; zone type/state and many persistent/verification structs | `E2RunH1ZoneV2`, OnTick/init, H1 range, M15 confirmation, all strategies/planner, visualizer | H1 range, confirmation, strategy candidates, target selection, plan/report zone fields, visuals, zone inputs/docs |
| H1 range boundaries | Includes H4 regime and H1 zones; context/verification | OnTick/init, RMR/RB/planner/visualizer/summaries | RMR/RB and their plan/report identity, range inputs/docs |
| M15 confirmation | Includes market data and zones; rejection enums, zone context/result/cache | standalone visual evaluation plus TC/RMR/RB init/evaluation | all three strategy candidate types, confirmation fields/counters/visuals, M15 inputs/docs |
| TC engine | Includes H4, zones, confirmation; TC state/direction/candidate/claim/diagnostics | `E2RunTrendContinuationV2`, planner route, visualizer, summaries | V2 plan's direction is TC-typed; execution maps it; reporter/summary setup names; TC inputs/docs |
| RMR engine | Includes range and confirmation; RMR state/direction/candidate/claim | `E2RunRangeMeanReversion`, planner route, visualizer, summaries | RMR plan/execution/management verification and range identities; inputs/docs |
| RB engine | Includes range and confirmation; RB state/direction/candidate/claim | H1 pre-event and M15 evaluation, planner route, visualizer, summaries | RB plan/execution verification, range/zone identities; inputs/docs |
| Research types | Old strategy/management/regime/tactical/boundary/confirmation enums and metadata | Included by config; used throughout analysis, plans, execution, reporting and visuals | Remove old consumers first; relocate only genuinely generic direction/risk types rather than retaining dead enums |
| V2 planner | Directly includes all strategies, session/news, sizer/guard; V2 plan/reason/management plus three verification structs | All three run functions create plans; V2 execution consumes plans; manager includes planner; summaries read verification | Remove routing from `E2.mq5`; decouple execution/manager/reporter; retain generic filters/risk directly for future OBR |
| Session filter | Includes config; London/New York/DST status/result | Planner routes and summary | Remove planner use and seven session inputs/summary columns; do not reuse as OR clock |

### Hidden cross-layer dependencies

- `E2V2TradePlan.direction` is `E2TrendContinuationDirection`, yet RMR and RB plans also flow through it by enum-value compatibility. This is a hidden, unsafe multi-strategy coupling.
- `E2Config.mqh` imports `E2ResearchTypes.mqh`, so deleting research types before shrinking config breaks the core include chain.
- `E2V2PositionManager.mqh` includes the entire planner merely to consume old plan/metadata concepts, pulling strategy engines into management transitively.
- `E2Visualizer.mqh` directly includes H4, zones, range, RMR and RB, so old analysis files cannot be deleted until visualization is narrowed.
- `E2TradeReporter` is generic in deal authority but its row schema/invariants require old `range_id`, `zone_id`, `candidate_id`, `plan_id`, target-zone, confirmation and management fields.
- `E2BacktestSummary` couples retained infrastructure to old config fields and engine verification structs through the large deinitialization payload.
- The TC planner uses `CalculateFixedInitialBalance`, while generic risk modes are implemented in `CalculateRequestedRisk`; retaining the sizer does not mean retaining that compatibility call.
- Structural stop and broker-normalized stop are already distinguishable in reporting, but V2 target/risk geometry is calculated before the authoritative fill. OBR needs explicit post-fill immutable Original R handling.
- Existing restart behavior primarily reconciles open MT5 positions/deals; strategy engines hold in-memory state. OBR daily OR/candidate/consumption recovery will need a deliberate contract.
- `InpZoneTimeframe` and `InpConfirmationTimeframe` are reported but old engines hard-code H1/M15; `InpAdxEnabled` is reporting-only; the H4 lookback has a hidden 300-bar floor. These must not leak into OBR configuration.
- The existing session filter has DST logic for London/New York, but `InpBrokerUtcOffsetHours` is a fixed offset also shared with news conversion. It cannot objectively define the OBR exchange-time session.

## Input audit (84 EA inputs)

Consumer abbreviations: `CFG` configuration load/hash/validation; `H4`, `Z1`, `R1`, `C15`, `TC`, `RMR`, `RB` are the old engines; `PLAN`, `EXEC`, `MGR`, `RPT`, `SUM`, `VIS`, `NEWS`, `SESS`, `RISK`, `GUARD`, `MD` are the corresponding infrastructure modules. Owners and detailed method-level consumers agree with `INPUT_REFERENCE.md`.

| # | Current input | Default | Owner; current consumers | Class | Reason |
|---:|---|---|---|---|---|
| 1 | `InpEnableTrendContinuation` | `true` | TC; TC, PLAN, CFG | REMOVE | Retired strategy toggle. |
| 2 | `InpEnableRangeMeanReversion` | `false` | RMR; RMR, PLAN, CFG | REMOVE | Retired strategy toggle. |
| 3 | `InpEnableRangeBreakout` | `false` | RB; RB, PLAN, CFG | REMOVE | Retired strategy toggle. |
| 4 | `InpTrendTimeframe` | `PERIOD_H4` | shared model; MD, H4, SUM, CFG | REMOVE | H4 regime timeframe; must not masquerade as undecided OBR timeframe. |
| 5 | `InpZoneTimeframe` | `PERIOD_H1` | compatibility; MD, SUM, CFG | REMOVE | Reporting-only old zone timeframe. |
| 6 | `InpConfirmationTimeframe` | `PERIOD_M15` | compatibility; MD, SUM, CFG | MODIFY | Timeframe configuration concept is needed, but name/consumers are old and OBR timeframe is undecided. |
| 7 | `InpSwingSensitivity` | `3` | shared model; H4, Z1, CFG | REMOVE | Pivot formula only. |
| 8 | `InpTrendStructureLookbackBars` | `80` | shared model; H4, SUM, CFG | REMOVE | H4 structure history only. |
| 9 | `InpAdxEnabled` | `true` | compatibility; SUM, CFG | REMOVE | Reporting-only toggle; OBR canonically requires ADX. |
| 10 | `InpAdxPeriod` | `14` | shared model; H4, SUM, CFG | MODIFY | OBR needs ADX 14, but current owner/consumer is removed H4 regime. |
| 11 | `InpAdxMinimumThreshold` | `20.0` | shared model; H4, SUM, CFG | MODIFY | OBR needs threshold 20; re-home in OBR config. |
| 12 | `InpResearchH4EmaFastPeriod` | `20` | H4; H4, CFG | REMOVE | Old regime EMA. |
| 13 | `InpResearchH4EmaSlowPeriod` | `50` | H4; H4, CFG | REMOVE | Old regime EMA. |
| 14 | `InpResearchH4EmaSlopeLookback` | `5` | H4; H4, CFG | REMOVE | Old regime slope. |
| 15 | `InpResearchH4AtrPeriod` | `14` | shared model; H4, CFG | REMOVE | H4 normalization, not OBR ATR configuration. |
| 16 | `InpResearchH4StructuralBreakoutDistanceAtr` | `0.10` | shared model; H4, CFG | REMOVE | Old H4 structural break. |
| 17 | `InpH4RangeAdxMaximum` | `20.0` | RMR/RB; H4, CFG | REMOVE | Old H4 range classifier. |
| 18 | `InpH4RangeContainmentLookback` | `20` | RMR/RB; H4, CFG | REMOVE | Old range classifier. |
| 19 | `InpH4RangeMaximumWidthAtr` | `6.0` | RMR/RB; H4, CFG | REMOVE | Old range classifier. |
| 20 | `InpRangeBoundaryContainmentToleranceAtr` | `0.25` | RMR/RB; R1, CFG | REMOVE | H1 range-boundary formula. |
| 21 | `InpRangeBoundaryMinimumHeightAtr` | `3.0` | RMR/RB; R1, CFG | REMOVE | H1 range-boundary formula. |
| 22 | `InpResearchRangeBoundaryInvalidationAtr` | `0.25` | RMR/RB; R1, CFG | REMOVE | H1 range invalidation. |
| 23 | `InpZoneLookbackBars` | `240` | shared model; Z1, SUM, CFG | REMOVE | Persistent-zone discovery. |
| 24 | `InpResearchH1AtrPeriod` | `14` | shared model; Z1, TC, CFG | REMOVE | Old H1 zone/stop ATR, not OBR ATR. |
| 25 | `InpResearchH1ZonePivotClusteringAtr` | `0.50` | shared model; Z1, CFG | REMOVE | Zone formula. |
| 26 | `InpResearchH1MinimumTouchSeparationBars` | `3` | shared model; Z1, CFG | REMOVE | Zone formula. |
| 27 | `InpResearchH1MinimumPostTouchDepartureAtr` | `1.00` | shared model; Z1, CFG | REMOVE | Zone formula. |
| 28 | `InpResearchH1ZoneInvalidationAtr` | `0.10` | shared model; Z1, TC, PLAN, CFG | REMOVE | Zone invalidation/old stop buffer. |
| 29 | `InpResearchH1BreakoutDistanceAtr` | `0.10` | TC/RB; TC, RB, CFG | REMOVE | Old zone/range breakout distance. |
| 30 | `InpResearchH1ZoneRearmDistanceAtr` | `0.50` | shared model; Z1, RMR, RB, CFG | REMOVE | Old attempt rearm. |
| 31 | `InpResearchM15BodyMedianLookback` | `20` | shared model; C15, CFG | REMOVE | Old momentum/rejection confirmation. |
| 32 | `InpResearchM15MomentumBodyMultiplier` | `1.25` | TC/RB; C15, CFG | REMOVE | Old momentum confirmation. |
| 33 | `InpResearchM15MomentumBodyRangeMinimum` | `0.60` | TC/RB; C15, CFG | REMOVE | Old momentum confirmation. |
| 34 | `InpResearchM15MomentumClosingLocationFraction` | `0.20` | TC/RB; C15, CFG | REMOVE | Old momentum confirmation. |
| 35 | `InpResearchH4TrendExtensionLimitAtr` | `1.50` | TC; H4/TC/PLAN, CFG | REMOVE | TC overextension. |
| 36 | `InpResearchRangeOuterEntryRegionFraction` | `0.20` | RMR; RMR, CFG | REMOVE | RMR entry region. |
| 37 | `InpResearchM15RejectionWickBodyMinimum` | `1.50` | RMR; C15, CFG | REMOVE | RMR rejection. |
| 38 | `InpResearchM15RejectionWickRangeMinimum` | `0.40` | RMR; C15, CFG | REMOVE | RMR rejection. |
| 39 | `InpResearchH1BreakoutBodyLookback` | `20` | RB; RB, CFG | REMOVE | RB strong-body formula. |
| 40 | `InpResearchH1BreakoutBodyMultiplier` | `1.25` | RB; RB, CFG | REMOVE | RB strong-body formula. |
| 41 | `InpResearchH1BreakoutBodyRangeMinimum` | `0.60` | RB; RB, CFG | REMOVE | RB strong-body formula. |
| 42 | `InpResearchH1BreakoutClosingLocationFraction` | `0.20` | RB; RB, CFG | REMOVE | RB close-location formula. |
| 43 | `InpResearchH1BreakoutRetestExpiryBars` | `12` | RB; RB, CFG | REMOVE | RB retest expiry. |
| 44 | `InpResearchH1BreakoutInvalidationDepthAtr` | `0.10` | RB; RB, PLAN, CFG | REMOVE | RB invalidation/stop buffer. |
| 45 | `InpMaxSpreadPips` | `3.0` | shared filter; PLAN, EXEC, SUM, CFG | KEEP | Generic safety gate; whether enabled for OBR is unresolved. |
| 46 | `InpEnableLondonSession` | `true` | shared filter; SESS, SUM, CFG | REMOVE | Old extra entry-session filter. |
| 47 | `InpEnableNewYorkSession` | `true` | shared filter; SESS, SUM, CFG | REMOVE | Old extra entry-session filter. |
| 48 | `InpBrokerUtcOffsetHours` | `999` | shared time conversion; SESS, NEWS, SUM, CFG | MODIFY | News still uses conversion; cannot define OBR timezone/DST as-is. |
| 49 | `InpLondonSessionStartHour` | `8` | shared filter; SESS, SUM, CFG | REMOVE | Old London session. |
| 50 | `InpLondonSessionEndHour` | `17` | shared filter; SESS, SUM, CFG | REMOVE | Old London session. |
| 51 | `InpNewYorkSessionStartHour` | `8` | shared filter; SESS, SUM, CFG | REMOVE | Old New York session. |
| 52 | `InpNewYorkSessionEndHour` | `17` | shared filter; SESS, SUM, CFG | REMOVE | Old New York session. |
| 53 | `InpNewsFilterEnabled` | `true` | news; NEWS, PLAN, SUM, CFG | KEEP | Generic infrastructure; OBR application is unresolved. |
| 54 | `InpHighImpactBufferBeforeMins` | `30` | news; NEWS, SUM, CFG | KEEP | Generic news setting. |
| 55 | `InpHighImpactBufferAfterMins` | `30` | news; NEWS, SUM, CFG | KEEP | Generic news setting. |
| 56 | `InpNewsHighImpactOnly` | `true` | news; NEWS, SUM, CFG | KEEP | Generic news setting. |
| 57 | `InpNewsDataFile` | `"E2_news_events.csv"` | news; NEWS, CFG | KEEP | Generic deterministic news source. |
| 58 | `InpRiskMode` | `E2_RISK_FIXED_CASH` | risk; RISK, CFG | KEEP | Generic FIXED_CASH/BALANCE_PERCENT mode. |
| 59 | `InpFixedCashRisk` | `1000.0` | risk; RISK, CFG | MODIFY | Generic field remains, but current default differs from Pine's $100 baseline; no Sprint 0 change. |
| 60 | `InpBalanceRiskPercent` | `1.0` | risk; RISK, SUM, CFG | KEEP | Generic optional risk mode. |
| 61 | `InpExpertMagicNumber` | `2026001` | execution; GUARD, EXEC, MGR, RPT, EA, CFG | KEEP | Generic ownership namespace. |
| 62 | `InpTradingEnabled` | `true` | execution; EXEC, CFG | KEEP | Generic master switch. |
| 63 | `InpMaxEntryDeviationPips` | `2.0` | execution; order executor, CFG | MODIFY | Generic protection, but next-open/fill recalculation semantics need redesign. |
| 64 | `InpMaxQuoteAgeSeconds` | `10` | execution; PLAN, EXEC, CFG | KEEP | Generic quote safety. |
| 65 | `InpMinimumSecondsBetweenExecutions` | `5` | execution; EXEC, CFG | KEEP | Generic cooldown; daily OBR limit remains separate. |
| 66 | `InpEnableFixed2RManagement` | `true` | management; PLAN, CFG | REMOVE | Old mutually-exclusive management routing; OBR target is intrinsic baseline geometry. |
| 67 | `InpEnableZoneTargetTrailingManagement` | `false` | management; PLAN/MGR, CFG | REMOVE | Explicitly outside baseline OBR. |
| 68 | `InpDebugMode` | `false` | reporting; EA/logger, CFG | KEEP | Generic logging control. |
| 69 | `InpResearchVerificationSummary` | `true` | reporting; EA/SUM, CFG | MODIFY | Verification switch is useful; current counters are old-strategy-specific. |
| 70 | `InpResearchVerboseDiagnostics` | `false` | reporting; engines/PLAN, CFG | MODIFY | Generic verbosity concept; current consumers and name are research-architecture bound. |
| 71 | `InpLoggingEnabled` | `true` | reporting; logger/EA, CFG | KEEP | Generic logging control. |
| 72 | `InpCsvExportEnabled` | `false` | reporting; RPT/SUM, CFG | KEEP | Generic export control. |
| 73 | `InpVisualModeEnabled` | `true` | diagnostics; EA/VIS, CFG | KEEP | Generic visual-audit master switch. |
| 74 | `InpVisualShowConfirmations` | `true` | diagnostics; VIS, CFG | MODIFY | Re-map from M15 confirmation to OBR breakout decision display. |
| 75 | `InpVisualShowTrades` | `true` | diagnostics; VIS, CFG | KEEP | Generic trade display. |
| 76 | `InpVisualShowH4RegimeV2` | `true` | diagnostics; VIS, CFG | REMOVE | Old H4 layer. |
| 77 | `InpVisualShowH1ZoneV2` | `true` | diagnostics; VIS, CFG | REMOVE | Old zone layer. |
| 78 | `InpVisualShowH1RangeBoundaries` | `true` | diagnostics; VIS, CFG | REMOVE | Old H1-range layer. |
| 79 | `InpVisualShowM15ConfirmationV2` | `true` | diagnostics; EA/VIS, CFG | REMOVE | Old momentum/rejection layer. |
| 80 | `InpVisualShowTrendContinuationV2` | `true` | diagnostics; VIS, CFG | REMOVE | TC layer. |
| 81 | `InpVisualShowRangeMeanReversionV2` | `true` | diagnostics; VIS, CFG | REMOVE | RMR layer. RB lacks its own exposed toggle. |
| 82 | `InpVisualAuditMode` | `E2_VISUAL_ALL_TRADES` | diagnostics; VIS, CFG | MODIFY | Filtering concept useful, but strategy-audit enum assumes retired architecture. |
| 83 | `InpVisualFocusTradeId` | `0` | diagnostics; VIS, CFG | KEEP | Generic position focus. |
| 84 | `InpVisualCleanupOnDeinit` | `true` | diagnostics; VIS, CFG | KEEP | Generic object cleanup. |

Input totals: **KEEP 19, MODIFY 10, REMOVE 55 (total 84)**. These are future dispositions only; Sprint 0 changes none.

The eventual OBR surface will also need locked fields not represented correctly today: OR start/end, authoritative timezone/day/DST policy, decision timeframe, ATR period, minimum OR/ATR ratio, maximum breakout-gap/ATR ratio, target R multiple, daily/cutoff/failure policy where configurable, and perhaps explicit OBR enablement. Their existence and configurability must follow rule decisions, not be invented during deletion.

## Target definition: E2 Core after Sprint 1

E2 Core is the smallest strategy-neutral executable shell that:

- starts and deinitializes normally;
- loads and validates only retained core configuration;
- initializes environment, symbol, account and causal market-data services;
- retains requested-risk sizing, broker validation, order/position ownership primitives, logging, CSV/deal reporting, news data infrastructure and appropriate MT5 position/deal recovery;
- exposes stable interfaces on which a later OBR candidate/planner can be built; and
- reports deterministic zero strategy activity.

It contains no TC, RMR, RB, H4 regime classifier, H1 persistent zones/ranges, M15 old confirmation, old candidate, old plan, strategy competition, zone/milestone management, or strategy-generated execution. OBR is also absent.

A stripped-core Strategy Tester run must complete without runtime errors and report exactly:

- `0` strategy candidates;
- `0` plans;
- `0` strategy execution attempts;
- `0` strategy trades.

Retaining execution classes does not authorize calling them without a strategy plan. Existing account positions/deals must not be misreported as new strategy activity; magic/symbol ownership remains authoritative.

## Ordered Sprint 1 deletion/refactor plan (do not execute in Sprint 0)

### Step 1 — Freeze a zero-strategy orchestration seam

- Modify `E2.mq5` and the summary contract so no old engine is evaluated and no planner/executor route is reachable.
- Keep lifecycle, config/core initialization, deal reconciliation, logs/news and generic zero counters.
- Expected compile impact: old globals/includes may still compile but become unused temporarily.
- Verify: build; tester smoke run reports 0/0/0/0; `OnTradeTransaction` remains safe.

### Step 2 — Decouple retained reporting and visualization

- Modify `E2TradeReporter`, `E2BacktestSummary`, and `E2Visualizer` to remove old candidate/range/zone/management verification APIs and direct analysis includes while retaining deal authority, generic trades and cleanup.
- Expected impact: callers in `E2.mq5` must use the reduced interfaces; old engines may no longer call visuals.
- Verify: build, reporter reconciliation test/smoke, CSV headers internally consistent, no old strategy names in live summary/visual paths.

### Step 3 — Decouple execution and management from V2 plans

- Modify/rebuild `E2V2ExecutionEngine` into a generic coordinator or temporarily remove it from the core; reduce `E2V2PositionManager` to genuinely generic recovery/protection or remove inactive strategy management; modify `E2OrderRequest`/`E2OrderExecutor` interfaces as needed.
- Preserve magic ownership, broker validation, structural-versus-submitted stop distinction, actual-fill registration and immutable Original R capabilities.
- Expected impact: removal of `E2V2TradePlanEngine` include from execution/management becomes possible.
- Verify: compile; no execution call from core; focused unit/tester harnesses for risk/order validation where available; zero strategy attempts.

### Step 4 — Remove the V2 planner and session gate

- Delete `include/strategy/E2V2TradePlanEngine.mqh` and `include/filters/E2SessionFilter.mqh`; remove all includes, globals, initialization, route calls, V2 plan/reason/verification structs and London/New York summary fields.
- Keep news, risk, guard and execution safety as independent services.
- Expected impact: any lingering V2 plan or session type is a compile failure that exposes an incomplete decoupling.
- Verify: `rg` finds no `E2V2TradePlan`, `RouteTrendContinuation`, `RouteRangeMeanReversion`, `RouteRangeBreakout`, `E2SessionResult`, or London/New York runtime references.

### Step 5 — Remove TC/RMR/RB producers

- Delete the three strategy engine files and remove their includes, globals, run functions, candidate arrays, verification counters and visualization/report setup buckets.
- Expected impact: planner and visualizer must already be independent; otherwise compile failures identify missed dependencies.
- Verify: build; `rg` finds no strategy class/candidate/state/direction symbols or `TREND_CONTINUATION`, `RANGE_MEAN_REVERSION`, `RANGE_BREAKOUT` in executable source.

### Step 6 — Remove old confirmation and market-model engines leafward

- Delete M15 confirmation, H1 range boundaries, H1 zones and H4 regime engines in that order after their consumers are gone.
- Remove corresponding globals, scheduling state, data arrays, verification/diagnostic types and visual hooks.
- Expected impact: `E2MarketData` remains; no supposedly generic module may include an analysis engine.
- Verify after each deletion: compile and `rg` for its enums/structs/config consumers; then tester zero-activity smoke.

### Step 7 — Remove old research vocabulary

- Delete `E2ResearchTypes.mqh` after config/reporting/execution no longer consume it.
- Relocate only strategy-neutral types (for example a generic buy/sell direction if still needed) into narrowly owned core/risk/execution headers. Do not preserve dead enum values as shims.
- Expected impact: remove `E2Config`'s transitive dependency on retired architecture.
- Verify: compile; no old strategy/regime/tactical/boundary/confirmation/zone-management enum names remain.

### Step 8 — Shrink configuration and the 84-input surface

- Modify `E2Config.mqh`: remove the 55 REMOVE inputs and fields, remove obsolete validation/hash/load code, and simplify the 10 MODIFY items only to the generic-core form justified before OBR implementation.
- Do not add speculative OBR inputs until rule decisions are locked. Preserve 19 KEEP inputs unless later design proves a narrower core contract.
- Expected impact: update summary/config hash and `INPUT_REFERENCE.md`; set files may no longer load old parameters, which is acceptable because Git preserves v2.x.
- Verify: declaration/load/struct/hash/validation one-to-one audit; no dead inputs; defaults of retained inputs unchanged unless separately authorized.

### Step 9 — Remove obsolete strategy documentation and update current docs

- Delete the strategy/model documents classified REMOVE. Update the MODIFY documents to describe stripped E2 Core, its reduced inputs, and zero-strategy behavior. Keep OBR specification/audit and news workflow.
- Expected compile impact: none.
- Verify: repository link/search audit; no current-state documentation claims TC/RMR/RB or OBR is active.

### Step 10 — Full Sprint 1 validation gate

- Build EA and news exporter with zero errors/warnings target.
- Run Strategy Tester stripped-core smoke across representative initialization/deinitialization and restart/reconciliation paths.
- Assert 0 candidates, 0 plans, 0 strategy execution attempts and 0 strategy trades; check no order requests were emitted.
- Run input inventory, include/dead-symbol searches, `git diff --check`, and confirm no accidental OBR implementation.

## Sprint 1 risk register

- Removing planner types too early will break execution, manager, reporter, summary and visualizer transitively.
- Enum ordinal compatibility currently masks the plan-direction coupling; do not translate it into a new generic shim.
- Reporter recovery must not lose authoritative deal reconciliation or immutable Original R when old fields are removed.
- A core that merely disables strategy toggles is insufficient: old engines still execute analysis and carry hidden state; physical dependency removal is the Sprint 1 objective.
- A core with retained executor objects must have no reachable order path; verify attempts, not only filled trades.
- Time conversion for retained news must be separated from the future OR timezone/day service.
- Removing session inputs can alter initialization validation and summary schemas even when no trades occur; sequence config last.
- Visual object cleanup must continue to recognize existing E2 prefixes while strategy-specific drawing is removed.
- Restart/recovery is partly implicit in MT5 deal/position queries and partly absent for strategy state; document the exact retained guarantee before OBR state persistence is designed.
- Current fixed-cash default is `$1000`, whereas the Pine research baseline is `$100`; Sprint 0 deliberately does not change it.
- Broker-adjusted SL, actual fill, Original R and TP sequencing is not fully represented by the old plan-first pipeline and must be resolved before OBR implementation.
