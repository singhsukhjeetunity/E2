# E2 Core Architecture

E2 OBR Sprint 3 is an end-to-end M15 strategy. The Sprint 2 market model remains the sole candidate authority; planning, execution and recovery consume its frozen candidates without recalculating them.

## Active dependency graph

`E2.mq5` owns the lifecycle and initializes:

- configuration and validation;
- runtime environment, symbol and account specifications;
- completed-candle/as-of market-data access;
- retained news CSV infrastructure;
- FIXED_CASH/BALANCE_PERCENT sizing;
- position ownership guard and broker execution safety;
- generic market-order submission foundation;
- deal-authoritative trade reporting, logging and CSV utilities;
- zero-strategy tester verification and generic visual cleanup.

`OnTick` evaluates completed-bar candidates, plans only the immediately following M15 window, submits eligible market orders, attaches the fill-based 2R target, reconciles deals and updates visualization. `OnTradeTransaction` remains the deal-authoritative reporting path.

## OBR signal modules

- `E2OBRTypes.mqh`: opening-range, candidate, plan, execution, recovery and immutable position records.
- `E2OBREngine.mqh`: London-time conversion, four-bar OR reconstruction/freeze, M15 ATR/ADX sampling, filters, deterministic candidate identity and duplicate protection.
- `E2OBRTradePlanner.mqh`: next-window expiry, entry-gap validation, structural/broker stop geometry, risk sizing and request/attempt deduplication.
- `E2OBRRecovery.mqh`: London-day deal-history lock and small persisted open-position metadata record.
- `E2TradeReporter.mqh`: passive finalized-trade audit plus independent financial, R, day and chain reconciliation.
- `E2OBRTradePlanner.mqh`: also emits the optional passive candidate decision/rejection audit and entry-time/gap verification.

The engine still emits metadata only. The planner is the only bridge into generic risk and execution services.

## Generic contracts

`E2TradeDirection` is `NONE`, `LONG`, or `SHORT` and contains no strategy vocabulary.

`E2OrderRequest` carries symbol, setup/signal/execution identities, direction, signal/known/request timestamps, requested entry, structural stop, submitted stop, TP, requested cash risk and volume. It has no zone, range, regime, retest, or legacy candidate fields.

`E2ReportEntryData` freezes the request plus actual fill, actual risk and MT5 tickets at registration. `E2TradeReporter` aggregates authoritative MT5 exit deals, including profit, commission, swap and fees, and finalizes a position once without reconstructing strategy state.

## Restart and ownership foundation

Magic number plus symbol identify E2-owned positions and orders. Filled OBR entry deals create the per-symbol/London-day lock. Open-position metadata persists candidate identity, fill, both stop representations, immutable Original R, target, risk and tickets; startup validates it against the owned position and deal history.

## Removed architecture

The active tree contains no TC, RMR, RB, H4 regime, H1 zone/range, M15 confirmation, multi-strategy planner, strategy session filter, V2 execution adapter, or V2 position manager. Git history preserves the former implementation.

The frozen specification and execution lifecycle are in [OBR_STRATEGY.md](OBR_STRATEGY.md).
