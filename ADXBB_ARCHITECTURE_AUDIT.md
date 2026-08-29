# E2 ADXBB Sprint 0 Architecture Audit

Status: documentation-only audit of the current E2 OBR v1.2.0 tree. No recommendation in this document has been implemented.

## Executive disposition

The reusable core is symbol/account metadata, generic M5-capable market-data access, monetary sizing, order-request primitives, position ownership, execution safety/executor, logging, CSV mechanics, environment detection, and portions of financial/R reconciliation. The OBR engine, types, planner, recovery schema, session/timezone system, weekday filter, visual subsystem, preset, and active OBR documents should leave the ADXBB branch. Reporting and recovery must be redesigned rather than renamed because their data contracts currently include OBR types and day/session fields.

The news subsystem is generic in isolation but dormant and unused by the frozen execution route. Retaining it would preserve six dead strategy inputs, a FILE_COMMON dependency, a utility, and documentation without authorization to affect ADXBB. Recommendation: remove it from the streamlined ADXBB runtime and active input surface; Git history preserves it if a future project explicitly restores news filtering.

## File-by-file audit

| File | Current role | Classification | Action | Reason and future role |
|---|---|---|---|---|
| `E2.mq5` | OBR composition root and lifecycle | Mixed, heavily OBR-bound | MODIFY | Recompose generic services plus future ADXBB engine/planner/recovery/reporting; enforce `_Period == PERIOD_M5`; remove all OBR/session/weekday/visual/news calls. |
| `include/core/E2Config.mqh` | All 38 inputs, mapping, validation | Mixed | MODIFY | Replace OBR/visual/news inputs and fields with clean ADXBB inputs; retain validated generic risk/execution/reporting settings. |
| `include/core/E2Environment.mqh` | Tester/forward environment identity | Generic | KEEP | Useful for run identity, diagnostics, and collision-safe reporting. |
| `include/core/E2SymbolInfo.mqh` | Tick, point, pip, volume and price normalization metadata | Generic | KEEP | Required by stops, sizing, and executor. |
| `include/core/E2AccountInfo.mqh` | Account balance/equity/margin metadata | Generic | KEEP | Required by risk and execution. |
| `include/core/E2TradeTypes.mqh` | Long/short direction enum/name | Generic | KEEP | Strategy-neutral trade direction. |
| `include/analysis/E2MarketData.mqh` | Generic rates/closed-bar access by explicit timeframe | Generic | KEEP/MODIFY | Already accepts `ENUM_TIMEFRAMES`; use explicit `PERIOD_M5`. Add only readiness/warm-up support proven necessary by ADXBB. |
| `include/risk/E2PositionSizer.mqh` | MT5-native cash-risk sizing and verification | Generic | KEEP | Correct replacement for Pine point-value sizing; confirm no field names reference OBR. |
| `include/risk/E2OrderRequest.mqh` | Generic normalized order request contract | Generic | KEEP | Suitable for ADXBB candidate-to-execution handoff. |
| `include/execution/E2PositionGuard.mqh` | One owned position/pending order per symbol; account-mode checks | Generic | KEEP | Cleanly supplies non-pyramiding independently of daily locking. |
| `include/execution/E2ExecutionSafety.mqh` | Quote/spread/market/volume/cooldown preflight | Generic | KEEP | Strategy-neutral safety boundary. |
| `include/execution/E2OrderExecutor.mqh` | Synchronous market submission and protection attachment | Generic | KEEP/MODIFY | Core behavior stays; remove any OBR-facing composition only. Preserve fill authority and TP attachment. |
| `include/reporting/E2Logger.mqh` | Journal logger | Generic | KEEP | Primary operational visibility after custom visuals are removed. |
| `include/reporting/E2CsvExporter.mqh` | FILE_COMMON CSV writer/header helper | Generic | KEEP/MODIFY | Retain mechanics; add deterministic run/path policy and explicit append/overwrite handling if required. |
| `include/reporting/E2TradeReporter.mqh` | OBR entry schema, lifecycle capture, trades CSV, reconciliation | Structurally OBR-bound | MODIFY/REPLACE | Rebuild around ADXBB report DTOs and proposed TRADES schema; retain useful deal reconciliation/financial/R algorithms without OBR types. |
| `include/reporting/E2BacktestSummary.mqh` | Core, OBR, risk, financial and run verification logs | Mixed | MODIFY/REPLACE | Keep generic core/risk concepts; replace OBR blocks with the minimal ADXBB suite below. |
| `include/strategy/E2OBRTypes.mqh` | All OBR candidates, range, session, planner, recovery and verification DTOs | OBR-specific | REMOVE | Replace with focused `E2ADXBBTypes.mqh`; do not migrate OR/session fields. |
| `include/strategy/E2OBREngine.mqh` | M15 OR/session/DST/weekday signal engine | OBR-specific | REMOVE | Replace later with M5 ADXBB completed-bar engine. |
| `include/strategy/E2OBRTradePlanner.mqh` | Next-M15 planning, OR stop/gap logic, decision CSV | OBR-specific with reusable concepts | REMOVE/REPLACE | New planner uses immediate next M5, frozen ATR distance, generic ownership/safety, and SIGNALS audit. Do not retain OR gap/stop logic. |
| `include/strategy/E2OBRRecovery.mqh` | OBR state file, session-day locks, history comments | OBR-specific | REMOVE/REPLACE | Introduce minimal generic/ADXBB recovery record described below. |
| `include/visualization/E2Visualizer.mqh` | All custom chart objects | Visual-only | REMOVE | Entire subsystem is explicitly out of scope for future E2. |
| `include/filters/E2NewsFilter.mqh` | Dormant FILE_COMMON event filter | Generic but unused | REMOVE | Avoid dead inputs/runtime/data dependency; do not wire into ADXBB. |
| `utilities/E2NewsExporter.mq5` | Builds news CSV | News-only | REMOVE | No active ADXBB consumer. |
| `presets/E2_OBR_FORWARD_DEMO.set` | OBR release preset | OBR-specific | REMOVE/REPLACE | Future `E2_ADXBB_FORWARD_DEMO.set` only after inputs exist. |
| `ARCHITECTURE.md` | Active OBR architecture | OBR-era mixed | MODIFY | Rewrite to the final ADXBB/core architecture after strip-down. |
| `INPUT_REFERENCE.md` | Current 38-input OBR reference | OBR-era | MODIFY | Replace with final ADXBB/generic input reference. |
| `PRODUCTION_CONFIGURATION.md` | OBR production configuration | OBR-era mixed | MODIFY | Retain generic deployment safety; replace OBR/session material with M5 ADXBB settings. |
| `STATUS.md` | Active feature status | Mixed | MODIFY | Track Sprint 0 now and later ADXBB implementation status. |
| `CONTRIBUTING.md` | Repository contribution guidance | Generic | KEEP/MODIFY | Retain unless OBR names are found during Sprint 1 documentation sweep. |
| `STRATEGY.md` | Historical strategy/spec material | OBR/legacy | REMOVE | Replace active authority with `ADXBB_STRATEGY.md`; Git history retains old material. |
| `OBR_STRATEGY.md` | OBR mechanical authority | OBR-specific | REMOVE |
| `OBR_ARCHITECTURE_AUDIT.md` | Previous OBR audit | OBR-specific | REMOVE |
| `OBR_VALIDATION.md` | OBR validation plan/baseline | OBR-specific | REMOVE |
| `OBR_FORWARD_TEST.md` | OBR forward test guide | OBR-specific | REMOVE |
| `NEWS_DATA_WORKFLOW.md` | News dataset workflow | News-only | REMOVE with news subsystem |
| `ADXBB_STRATEGY.md` | New mechanical contract | ADXBB | KEEP | Future implementation authority. |
| `ADXBB_ARCHITECTURE_AUDIT.md` | This Sprint 0 audit | ADXBB transition | KEEP through migration | Sprint 1 checklist/audit evidence; may later move to history once fulfilled. |

Compiled `.ex5` artifacts are build outputs, not source architecture. Sprint 1 should regenerate them only through an authorized compile and should not treat them as reusable strategy code.

## Dependency and removal hazards

1. `E2.mq5` directly owns every OBR and visual object and translates OBR metadata into reporting. It must be recomposed atomically; merely deleting includes will break initialization, tick processing, transactions, and deinitialization.
2. `E2TradeReporter.mqh` includes `E2OBRTypes.mqh` for financial/R/day/reconciliation result structs. Those generic algorithms must first receive strategy-neutral DTOs/types before OBR types can disappear.
3. `E2BacktestSummary.mqh` consumes nearly every OBR verification struct. Replace the contract, not just log labels.
4. `E2OBRTradePlanner` embeds candidate identity, immediate-next-M15 timing, OR entry-gap revalidation, OR structural stop geometry, daily locking, and decision CSV in one class. Only the timing/duplicate/ownership concepts survive; the class should not be incrementally renamed.
5. `E2OBRRecovery` combines open-position metadata with OR state and session-day lock history. Split the future concepts: compact open-position recovery plus optional server-day fill lock.
6. `E2Config` feeds risk/execution/news/visual/OBR services. Remove fields only after the corresponding initialization and validation paths are removed.
7. The executor and position guard include `E2Config`; preserve the generic fields they consume while shrinking the struct.
8. OBR trade comments (`E2OBR|`, `E2OBRNY|`) drive history recovery. ADXBB needs a new stable `E2ADXBB|candidateId` convention and cannot reuse old comments.
9. The current reporter filenames and run IDs are created at runtime and used for reconciliation counters. Redesign names without changing the rule that only finalized trades increment trade CSV rows.
10. Visual calls occur at initialization, recovery, candidate updates, successful entry, and deinitialization. All must be removed together with the object/include/config fields.

## Complete OBR/session/weekday removal map

Remove the `E2OBRSession` enum; all `InpOBR*` inputs/fields/mappings/validation; `E2SessionConfiguration`, `E2SessionWeekday`; London/NY DST helpers; server-to-session conversion; OR start/end/slot collection/freeze/reconstruction; session day/weekdays; weekday suppression and audit; OR candidate/range/plan/recovery/report DTOs; OBR comments/state filenames; OR diagnostics; OR verification blocks; OBR globals/functions/includes; OBR preset; and active OBR documentation.

No broker→UTC conversion survives for strategy logic. If another generic subsystem later needs UTC, it must own an independently named contract; it must not preserve OBR offsets. ADXBB daily identity is the entry deal's broker/server date.

## Complete visual subsystem removal map

| Area | Current element | Sprint 1 action |
|---|---|---|
| File/class | `include/visualization/E2Visualizer.mqh`, `E2Visualizer` | Delete. |
| Inputs | `InpVisualModeEnabled`, `InpVisualCleanupOnDeinit` | Remove declarations, config fields, mapping, preset entries, validation/count references. |
| Composition | include, `g_visualizer` | Remove. |
| Initialization | `g_visualizer.Initialize(...)` | Remove. |
| OR rendering | `UpdateOBR`, range lines/boxes/candidate markers and object-name state | Remove. |
| Trade rendering | `DrawOBRExecution` on new/recovered entries; entry/SL/TP objects and labels | Remove. |
| Shutdown | `g_visualizer.Cleanup()` and conditional cleanup | Remove. |
| Documentation | visual-mode/cleanup/chart-object instructions and claims | Remove from active docs. |
| Verification/reporting | any visual toggling/passivity controls | Remove; MT5 native trade/history display remains untouched. |

Repository search found no visual dependency inside risk, executor, ownership, or CSV mechanics. This makes full removal low-risk once composition calls are deleted.

## Current 38-input audit

| Input | Current purpose | Class | Action | Replacement/reason |
|---|---|---|---|---|
| `InpOBREnabled` | OBR engine gate | OBR | REMOVE | `InpADXBBEnabled`. |
| `InpOBRSession` | London/NY OR selection | OBR | REMOVE | No session. |
| `InpOBRAdxLength` | OBR ADX period | OBR | REMOVE | Separate DI length and ADX smoothing inputs. |
| `InpOBRMinimumAdx` | OBR inclusive minimum trend | OBR | REMOVE | `InpADXBBADXThreshold`; new rule is strict less-than. |
| `InpOBRAtrLength` | OBR breakout ATR | OBR | REMOVE | `InpADXBBATRLength`. |
| `InpOBRMinimumRangeAtr` | Minimum OR/ATR | OBR | REMOVE | No equivalent. |
| `InpOBRMaximumBreakoutGapAtr` | Breakout/entry gap cap | OBR | REMOVE | No equivalent. |
| `InpOBRServerUtcOffsetStandardHours` | Server→UTC standard offset | OBR session | REMOVE | No session conversion. |
| `InpOBRServerUtcOffsetSummerHours` | Server→UTC summer offset | OBR session | REMOVE | No session conversion. |
| `InpOBRServerUsesEuropeanDst` | Broker European DST switch | OBR session | REMOVE | No session conversion. |
| `InpOBRStopBufferAtr` | OR-boundary ATR stop buffer | OBR | REMOVE | `InpADXBBATRMultiplier` defines stop distance. |
| `InpOBRTargetR` | OBR target multiple | OBR | REMOVE | `InpADXBBTargetR=1.1`. |
| `InpOBRTradeMonday` | London/NY Monday eligibility | OBR weekday | REMOVE | No weekday filter. |
| `InpOBRTradeTuesday` | Tuesday eligibility | OBR weekday | REMOVE | No weekday filter. |
| `InpOBRTradeWednesday` | Wednesday eligibility | OBR weekday | REMOVE | No weekday filter. |
| `InpOBRTradeThursday` | Thursday eligibility | OBR weekday | REMOVE | No weekday filter. |
| `InpOBRTradeFriday` | Friday eligibility | OBR weekday | REMOVE | No weekday filter. |
| `InpRiskMode` | Fixed-cash/balance-percent selection | Generic | KEEP | MT5-native risk architecture. |
| `InpFixedCashRisk` | Requested fixed monetary risk | Generic | KEEP | Baseline validation mode. |
| `InpBalanceRiskPercent` | Requested balance-percent risk | Generic | KEEP | Preserve supported generic mode. |
| `InpExpertMagicNumber` | E2 ownership/history identity | Generic | KEEP | Required for ownership/recovery/reporting. |
| `InpTradingEnabled` | Master execution gate | Generic | KEEP | Safe dry-run/control behavior. |
| `InpMaxSpreadPips` | Maximum spread | Generic execution | KEEP | Strategy-neutral protection. |
| `InpMaxEntryDeviationPips` | Quote deviation cap | Generic execution | KEEP | Strategy-neutral protection. |
| `InpMaxQuoteAgeSeconds` | Quote freshness | Generic execution | KEEP | Strategy-neutral protection. |
| `InpMinimumSecondsBetweenExecutions` | Execution cooldown | Generic execution | KEEP | Retain, but verify it does not accidentally suppress valid sequential M5 trades beyond intended safety. |
| `InpNewsFilterEnabled` | Dormant news gate | Generic but unused | REMOVE | No ADXBB news rule; eliminates dead dependency. |
| `InpBrokerUtcOffsetHours` | News server→UTC | News | REMOVE | Removed with news subsystem. |
| `InpHighImpactBufferBeforeMins` | News block buffer | News | REMOVE | Removed with news subsystem. |
| `InpHighImpactBufferAfterMins` | News block buffer | News | REMOVE | Removed with news subsystem. |
| `InpNewsHighImpactOnly` | News impact selection | News | REMOVE | Removed with news subsystem. |
| `InpNewsDataFile` | News CSV path | News | REMOVE | Removed with news subsystem. |
| `InpDebugMode` | Verbose diagnostics | Generic | KEEP | Useful for parity and execution audit. |
| `InpCoreVerificationEnabled` | Verification emission | Generic | KEEP | Retain generic switch. |
| `InpLoggingEnabled` | Journal logging | Generic | KEEP | Required operational channel. |
| `InpCsvExportEnabled` | CSV reporting gate | Generic | KEEP | Controls future SIGNALS/TRADES outputs. |
| `InpVisualModeEnabled` | Custom chart drawings | Visual | REMOVE | Visual subsystem removed. |
| `InpVisualCleanupOnDeinit` | Object cleanup | Visual | REMOVE | Visual subsystem removed. |

Proposed final surface: ten ADXBB inputs plus thirteen retained generic inputs = 23 exposed inputs, subject to Sprint 1 validation of the generic cooldown and final naming. No compatibility-only dead inputs should remain.

## CSV/reporting redesign

Two CSV types are sufficient:

1. `SIGNALS`: one row for every completed M5 candle that meets the raw long/short signal rule, including subsequent plan/execution disposition. This preserves repeated signals and rejected/expired candidates.
2. `TRADES`: one row per registered position after finalization, reconstructing execution, risk, protection, exit, and P/L.

Recommended filename grammar:

`E2_ADXBB_<SAFE_SYMBOL>_M5_<MODE>_<PERIOD>_<RUN_ID>_SIGNALS.csv`

`E2_ADXBB_<SAFE_SYMBOL>_M5_<MODE>_<PERIOD>_<RUN_ID>_TRADES.csv`

- `MODE`: `TESTER`, `FORWARD`, or `LIVE` from `E2Environment`.
- `PERIOD`: tester requested range when reliably available; otherwise initialization month `YYYY-MM`. Do not rename files at finalization.
- `RUN_ID`: readable `YYYY-MM-DD_HH-mm-ss` plus a short deterministic configuration hash. This prevents parallel/repeated-run collision without opaque epoch-only naming.
- Sanitize broker symbol characters but retain recognizable suffixes.
- Create new files with headers; never append to an unrelated run. Forward/live restarts may use a new run ID while `candidate_id`/`trade_id` and history reconciliation prevent semantic duplication.
- Continue FILE_COMMON only if cross-terminal access is desired; document the exact Common Files path. The current exporter opens write-mode files, so overwrite/append behavior must be explicit in the revised helper.

### Proposed SIGNALS schema

`run_id,strategy,symbol,timeframe,candidate_id,signal_bar_open,signal_known_from,direction,signal_close,adx,di_plus,di_minus,bb_basis,bb_upper,bb_lower,atr,atr_multiplier,risk_distance,execution_window_open,execution_window_close,candidate_status,decision,rejection_reason,decision_time,executable_quote,requested_entry,submitted_sl,requested_cash_risk,planned_volume,execution_id`

Statuses should distinguish `SIGNAL`, `REQUEST`, `REJECTED`, `EXPIRED`, `EXECUTION_FAILED`, and `FILLED`; reasons should be a stable enum vocabulary. A raw signal gets exactly one lifecycle row, preferably finalized/upserted in memory then written once, avoiding multiple ambiguous rows.

### Proposed TRADES schema

`run_id,trade_id,position_id,order_ticket,entry_deal,candidate_id,execution_id,strategy,symbol,timeframe,signal_bar_open,signal_known_from,direction,signal_close,signal_adx,signal_di_plus,signal_di_minus,signal_bb_basis,signal_bb_upper,signal_bb_lower,signal_atr,atr_multiplier,risk_distance,request_time,requested_entry,actual_fill,submitted_initial_sl,original_r_price,risk_mode,requested_cash_risk,actual_initial_cash_risk,volume,target_r,submitted_tp,exit_time,exit_price,exit_reason,gross_profit,commission,swap,fees,net_profit,realized_r,causality_valid,original_r_valid,tp_geometry_valid,reconciliation_valid`

Remove all OR/session/day/weekday/range/gap columns. When daily locking is enabled, the server fill date can be derived or optionally included as `strategy_day`; it is not a session identity.

## Verification redesign

| Current block | Disposition | Future block/concept |
|---|---|---|
| `OBR_VERIFY`, `OBR_TIME_VERIFY`, `OBR_SESSION_VERIFY`, `OBR_WEEKDAY_VERIFY` | REMOVE | `ADXBB_SIGNAL_VERIFY` covers completed M5 evaluation, long/short signals, indicator readiness/parity, strict-condition and duplicate violations. |
| `OBR_PLAN_VERIFY`, `OBR_ENTRY_TIME_VERIFY` | REPLACE | `ADXBB_PLAN_VERIFY` includes candidates received, immediate-next-M5 windows, expired/early/same-bar/late violations, quote/ownership/sizing rejections. |
| `OBR_ENTRY_GAP_VERIFY` | REMOVE | No strategy entry-gap filter. Generic quote deviation remains execution safety. |
| `OBR_EXEC_VERIFY` | GENERALIZE | `ADXBB_EXEC_VERIFY`: requests, attempts, fills, failures, duplicates, registrations/protection failures. |
| `OBR_RECOVERY_VERIFY` | REPLACE | `ADXBB_RECOVERY_VERIFY`: open-position recovery, metadata/schema failures, Original-R/SL/TP mutations, optional day-lock recovery. |
| `OBR_RECONCILE_VERIFY` | GENERALIZE | `ADXBB_RECONCILE_VERIFY`. |
| `OBR_FINANCIAL_VERIFY` | GENERALIZE | `ADXBB_FINANCIAL_VERIFY`; math remains strategy-neutral. |
| `OBR_R_VERIFY` | GENERALIZE | `ADXBB_R_VERIFY`; retain fill/SL Original R and TP geometry checks. |
| `OBR_DAY_VERIFY` | REPLACE | `ADXBB_DAY_VERIFY`, conditional on `InpOneTradePerDay`; server entry-date authority. |
| `OBR_RUN_FINGERPRINT` | REPLACE | `ADXBB_RUN_FINGERPRINT`: raw signals by direction, requests/attempts/fills/finalizations, rejection classes, net R, configuration hash. |
| `E2_INPUT_VERIFY`, `E2_CORE_VERIFY`, `E2_RISK_VERIFY` | KEEP/MODIFY | Keep generic names and update counts/contracts. |

Minimal suite: `ADXBB_SIGNAL_VERIFY`, `ADXBB_PLAN_VERIFY`, `ADXBB_EXEC_VERIFY`, `ADXBB_RECOVERY_VERIFY`, `ADXBB_R_VERIFY`, `ADXBB_DAY_VERIFY`, `ADXBB_RECONCILE_VERIFY`, `ADXBB_FINANCIAL_VERIFY`, `ADXBB_RUN_FINGERPRINT`, plus generic E2 input/core/risk verification.

## Recovery redesign

Replace the OBR state with one versioned `E2_ADXBB_STATE_V1` record per magic/symbol containing: strategy/schema, position ID, order/entry deal, candidate/execution IDs, symbol, direction, signal bar/known-from, frozen signal ATR/risk distance, signal indicator snapshot needed for reporting, fill, submitted initial SL, immutable Original R, target R/TP, requested/actual cash risk, and volume.

On startup, reconcile the record with owned open positions and entry history, validate Original R within half a tick, re-register the trade reporter, and fail safely on an owned position with missing/incompatible state. Delete stale state only after no owned position remains.

For `InpOneTradePerDay=true`, reconstruct consumption from successful ADXBB entry deals whose broker `DEAL_TIME` maps to the current server date; optionally cache the date in memory. The entry comment/schema must identify ADXBB. No OR, range, session, DST, weekday, or session namespace state survives. When the toggle is false, do not create or consult a daily-lock state.

## Indicator-equivalence findings and later validation

- Pine DMI uses separate DI and ADX smoothing lengths; both default to 7 here. MT5 `iADXWilder` exposes one period, so it cannot satisfy the general two-input contract and its seeding must not be assumed identical.
- Pine RMA uses alpha `1/length`. ATR is RMA of true range; Pine true range can fall back to high-low when previous close is unavailable.
- Pine SMA is the arithmetic mean of the last N valid samples.
- Pine `ta.stdev` defaults to biased/population standard deviation. MT5 `iBands`/`iStdDev` documentation identifies parameters and buffers but does not establish Pine-identical divisor, seeding, warm-up, or floating-point behavior.
- MT5 has separate `iADX` and `iADXWilder`; the current OBR code uses `iADX`, which is not acceptable evidence for Pine `ta.dmi` parity.

Follow the formula/export comparison plan in `ADXBB_STRATEGY.md`. No threshold or parameter may be tuned to hide a platform mismatch.

## Documentation end state

Active minimum set after implementation:

- `ADXBB_STRATEGY.md`
- `ADXBB_VALIDATION.md`
- `ARCHITECTURE.md`
- `INPUT_REFERENCE.md`
- `PRODUCTION_CONFIGURATION.md`
- `STATUS.md`
- `CONTRIBUTING.md`

Remove active OBR strategy/audit/validation/forward-test documents, old `STRATEGY.md`, and news workflow when their code is removed. Git history/release tags remain the rollback/archive authority; do not carry obsolete strategy documentation in the active branch.

## Exact Sprint 1 scope

Sprint 1 should be a strip-down to a compiling strategy-agnostic core, not ADXBB implementation:

1. Remove OBR engine/planner/types/recovery, OBR globals/includes/lifecycle paths, OBR input/config fields, preset, comments, diagnostics, and verification.
2. Remove session/timezone/DST/day/weekday machinery completely.
3. Remove the entire custom visual subsystem and both visual inputs/calls/docs.
4. Remove news runtime, inputs, exporter, and workflow documentation per this audit.
5. Decouple generic financial/R/reconciliation reporting types from `E2OBRTypes`; retain a minimal generic reporter shell and CSV writer without introducing the final ADXBB schemas prematurely.
6. Retain and compile environment, symbol/account, market data, trade types, risk, request, ownership, execution safety/executor, logger, generic CSV mechanics, and generic core/risk/input verification.
7. Recompose `E2.mq5` as a non-trading core with zero candidates/requests/attempts/fills and no strategy engine.
8. Rewrite active architecture/config/input/status documentation to describe the stripped core and planned ADXBB work; remove obsolete OBR/news docs and preset.
9. Verify zero errors/warnings, `git diff --check`, no OBR/session/weekday/visual/news source residue, no dead inputs, and unchanged generic risk/execution code except dependency decoupling.

Do not implement DMI, Bollinger, ATR signals, candidates, stops, orders, ADXBB recovery, final CSV schemas, or the daily toggle in Sprint 1 unless a later sprint explicitly changes that boundary.
