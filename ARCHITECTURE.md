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

## Backtesting and reporting

MT5 Strategy Tester is authoritative for price/tick simulation, orders, fills, SL/TP, balance, equity, and its native Results/Graph/statistics. E2 has no custom or shadow P&L/equity simulator.

`E2TradeReporter` captures decision-time metadata at confirmed execution and links records through MT5 `DEAL_POSITION_ID`; order, deal, and position identifiers are not assumed interchangeable. Exit deals are handled by `OnTradeTransaction`, reconciled once at deinitialization, aggregated for partial exits, and de-duplicated by deal ticket. Only an authoritative closed position with complete exit-deal data produces a finalized row. Open/unresolved records, including an unavailable Tester forced-close, are explicitly excluded rather than fabricated.

With `InpCsvExportEnabled=true`, CSV files use the MT5 common files location:

- `E2_trades_<symbol>_<run-id>.csv`: one finalized E2 strategy trade per row and strategy metadata.
- `E2_summary_<symbol>_<run-id>.csv`: one Strategy Tester run-level research summary. It shares the reporter run ID.
- `E2_startup.csv`: CSV infrastructure startup record.

The Journal provides lifecycle, successful trade-result, warning/error, and one tester `[RESULT]` line. MT5’s native Tester report remains the authority for account-level results.

Detailed metric definitions, schemas, verification status, and limitations are in [STATUS.md](STATUS.md).

`E2Visualizer` is a one-way consumer of runtime analysis, execution, and reporter outputs. It uses `E2VIS_`-prefixed native chart objects only in Strategy Tester Visual Mode; it is not read by strategy, risk, execution, or reporting code.

## Architecture rules

- Preserve the same production strategy implementation in Tester, demo, and live environments.
- Keep strategy, generic risk, native execution, and reporting modular.
- Preserve closed-bar/no-look-ahead evaluation.
- New features must not bypass `E2PositionGuard` or consume a setup before execution succeeds.
- Future visualization is audit-only and must never influence decisions.
