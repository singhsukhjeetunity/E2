# E2 Architecture

E2 (Emotionless Edge) is a modular MQL5 Expert Advisor. `E2.mq5` orchestrates the active implementation; strategy, risk, execution, and reporting are separate components.

## Decision and execution pipeline

```text
Closed M15 candle
  -> E2MarketData synchronized closed-bar access
  -> E2TrendAnalyzer (H4 structure + ADX)
  -> E2ZoneAnalyzer / E2SetupTracker (H1 zones and visits)
  -> E2ConfirmationAnalyzer (M15 confirmation)
  -> E2StrategyAnalyzer (LONG / SHORT candidate)
  -> E2SessionFilter
  -> E2NewsFilter
  -> E2PositionManager existing-position short-circuit
  -> E2TradePlanner + E2PositionSizer
  -> E2ExecutionSafety + E2PositionGuard
  -> E2OrderExecutor native MT5 order execution
  -> E2SetupTracker.Consume only after confirmed execution
  -> E2TradeReporter authoritative MT5 deal reporting
  -> E2BacktestSummary at Strategy Tester shutdown
```

`E2RunStrategySignalDiagnostic()` in `E2.mq5` evaluates only when a new closed M15 bar is available. `E2MarketData` supplies historical values as of the evaluation time, which is the no-look-ahead boundary.

## Components

| Area | Primary implementation |
|---|---|
| Configuration | `include/core/E2Config.mqh` |
| Market data and analysis | `include/analysis/E2MarketData.mqh`, `E2TrendAnalyzer.mqh`, `E2ZoneAnalyzer.mqh`, `E2ConfirmationAnalyzer.mqh` |
| Strategy/setup lifecycle | `include/strategy/E2StrategyAnalyzer.mqh`, `E2SetupTracker.mqh` |
| Filters | `include/filters/E2SessionFilter.mqh`, `E2NewsFilter.mqh` |
| Risk/planning | `include/risk/E2PositionSizer.mqh`, `E2TradePlanner.mqh` |
| Execution | `include/execution/E2OrderExecutor.mqh`, `E2PositionGuard.mqh`, `E2PositionManager.mqh`, `E2ExecutionSafety.mqh` |
| Reporting | `include/reporting/E2TradeReporter.mqh`, `E2BacktestSummary.mqh`, `E2CsvExporter.mqh`, `E2Logger.mqh` |
| Visualization | `include/visualization/E2Visualizer.mqh` (audit-only MT5 Visual Mode objects) |

Strategy analysis does not place orders or size positions. Execution does not add strategy conditions. Reporting is observational and cannot place, modify, or close a trade.

## v1.1.0-alpha research framework

E2 v1.0.0 is the permanent mechanically verified baseline. The active development line is **E2 v1.1.0-alpha**. Sprint 1.1 adds only the shared framework in `include/strategy/E2ResearchTypes.mqh`; it does not route, calculate, or trade a new strategy.

The canonical types are `E2StrategyType` (`NONE`, `TREND_CONTINUATION`, `RANGE_MEAN_REVERSION`, `RANGE_BREAKOUT`), `E2ManagementMode` (`NONE`, `FIXED_2R`, `ZONE_TARGET_TRAILING`), `E2RegimeType` (`UNKNOWN`, `UPTREND`, `DOWNTREND`, `RANGE`, `TRANSITION_UNCLASSIFIED`), `E2TacticalBreakoutState`, and `E2BoundaryResponse`. Their string conversions and the resettable `E2ResearchMetadata` contract are defined once in that module for future strategy/state producers, reporting, and visualization.

The intended one-way flow is:

```text
market / strategy / state logic
  -> immutable decision-time E2ResearchMetadata
  -> reporting and visualization consumers
```

Sprint 1.1 stores three independent strategy toggles and two management toggles in `E2Config`, but does not consume them in the existing v1.0 pipeline. Later router work must fail configuration explicitly if incompatible management modes would both become behaviorally active; applying that validation now would incorrectly change baseline behavior.

The inert baseline research inputs cover H4 EMA(20/50), EMA slope lookback 5, ATR(14), structure/extension thresholds (0.10/1.50 ATR); range thresholds (0.50, 3.00, 0.10, 0.25 ATR and 0.20 outer fraction); H1 clustering/touch/departure/breakout/retest/rearm values; and M15 median-body/momentum/rejection values. Existing news buffers are reused because their 30-minute before/after semantics already match. Existing M15 momentum inputs are preserved because they use an average-body current-strategy meaning rather than the future median-body research meaning.

The current session filter already converts the explicit per-run broker UTC offset into London/New York local time and applies DST rules. Its remaining architectural limitation is that the historical server offset is a manually configured fixed value for a run; a later session/time-source sprint owns any change. The current sizer uses percentage of current equity. A later risk sprint may add fixed-initial-Tester-balance 1R/no-compounding behavior as a distinct compatible mode; Sprint 1.1 does not alter sizing.

## Sprint 1.2 H4 Regime Engine V2

`E2H4RegimeEngine` reconstructs a closed-H4-only `E2H4RegimeResult` in parallel with the permanent legacy trend analyzer. It uses Sprint 1.1 H4/range fields, canonical regime types, causal strength-3 swings, internal deterministic EMA/ATR/ADX calculations, structural breaks, frozen two-swing range boundaries, and prospective range invalidation. The legacy `E2StrategyAnalyzer` does not read this result in Sprint 1.2. Detailed causal timing, range construction, precedence, and seeding limitations are in [H4_REGIME_V2.md](H4_REGIME_V2.md).

Sprint 1.2 verification support adds an H4-only, read-only `E2VIS_H4RV2_*` overlay. It receives `const E2H4RegimeResult` snapshots after engine evaluation and is never read by the engine, strategy, or execution layers. Its H4 audit hierarchy keeps only the current H1/H2/L1/L2 structure prominent; detailed causal metadata is available through object tooltips while superseded history is deliberately subdued.

## Sprint 1.3 H1 Zone Engine V2

`E2H1ZoneEngine` reconstructs causal, ATR-relative H1 support/resistance research records from completed H1 data only. It is parallel to `E2ZoneAnalyzer`: no Zone V2 output is read by the strategy, setup tracker, planner, execution, reporting, or legacy zone visualizer. The engine exposes frozen source-pair boundaries, causal pivot/known-from/departure timestamps, prospective invalidation, and H1 rearm foundation state. Its one-way `E2VIS_H1ZV2_*` H1 overlay is an audit consumer only. Exact semantics and the deliberate Sprint 1.3 no-merge policy are in [H1_ZONE_V2.md](H1_ZONE_V2.md).

## Backtesting and reporting

MT5 Strategy Tester is authoritative for price/tick simulation, orders, fills, SL/TP, balance, equity, and its native Results/Graph/statistics. E2 has no custom or shadow P&L/equity simulator.

`E2TradeReporter` captures decision-time metadata at confirmed execution and links records through MT5 `DEAL_POSITION_ID`; order, deal, and position identifiers are not assumed interchangeable. Exit deals are handled by `OnTradeTransaction`, reconciled once at deinitialization, aggregated for partial exits, and de-duplicated by deal ticket. Only an authoritative closed position with complete exit-deal data produces a finalized row. Open/unresolved records, including an unavailable Tester forced-close, are explicitly excluded rather than fabricated.

With `InpCsvExportEnabled=true`, CSV files use the MT5 common files location:

- `E2_trades_<symbol>_<run-id>.csv`: one finalized E2 strategy trade per row and strategy metadata.
- `E2_summary_<symbol>_<run-id>.csv`: one Strategy Tester run-level research summary. It shares the reporter run ID.
- `E2_startup.csv`: CSV infrastructure startup record.

The Journal provides lifecycle, successful trade-result, warning/error, and one tester `[RESULT]` line. MT5’s native Tester report remains the authority for account-level results.

Detailed metric definitions, schemas, verification status, and limitations are in [STATUS.md](STATUS.md).

`E2Visualizer` is a one-way consumer of runtime analysis, execution, and reporter outputs. It uses `E2VIS_`-prefixed native chart objects only in Strategy Tester Visual Mode; it is not read by strategy, risk, execution, or reporting code. Sprint 6.2.1 separates objects with `OBJPROP_TIMEFRAMES`: H4 trend panel/regime markers, H1 zones, M15 selected confirmations, and H1+M15 trade objects. Sprint 6.2.2 adds three read-only audit modes: Strategy Audit (broad analysis), All Trades (executed-trade context only), and Single Trade (one authoritative position identity). Sprint 6.2.3 makes that one E2-attached chart the audit surface and adds a non-interactive audit-view instruction. MT5's native timeframe selector on that chart is the supported switching mechanism: H4 answers WHY, H1 WHERE, and M15 WHEN. MT5 Tester does not provide reliably controllable simultaneous E2 chart instances; calling `ChartSetSymbolPeriod` during a run would reinitialize the attached EA and is intentionally avoided. Separate Tester chart tabs are not synchronized E2 audit charts.

## Architecture rules

- Preserve the same production strategy implementation in Tester, demo, and live environments.
- Keep strategy, generic risk, native execution, and reporting modular.
- Preserve closed-bar/no-look-ahead evaluation.
- New features must not bypass `E2PositionGuard` or consume a setup before execution succeeds.
- Future visualization is audit-only and must never influence decisions.
