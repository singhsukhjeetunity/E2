# E2 Core Architecture

E2 OBR is under construction. Sprint 2 adds a candidate-only M15 signal layer. Generic production services remain, but no path creates an order request.

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

`OnTick` calls only `E2OBREngine::Evaluate` and visualization. The order executor still has no caller. `OnTradeTransaction` forwards deal additions to the generic reporter, and deinitialization reconciles history and emits core/OBR verification.

## OBR signal modules

- `E2OBRTypes.mqh`: opening-range, candidate and verification records.
- `E2OBREngine.mqh`: London-time conversion, four-bar OR reconstruction/freeze, M15 ATR/ADX sampling, filters, deterministic candidate identity and duplicate protection.

The engine emits metadata only. It does not include order requests, risk sizing, execution or position registration.

## Generic contracts

`E2TradeDirection` is `NONE`, `LONG`, or `SHORT` and contains no strategy vocabulary.

`E2OrderRequest` carries symbol, setup/signal/execution identities, direction, signal/known/request timestamps, requested entry, structural stop, submitted stop, TP, requested cash risk and volume. It has no zone, range, regime, retest, or legacy candidate fields.

`E2ReportEntryData` freezes the request plus actual fill, actual risk and MT5 tickets at registration. `E2TradeReporter` aggregates authoritative MT5 exit deals, including profit, commission, swap and fees, and finalizes a position once without reconstructing strategy state.

## Restart and ownership foundation

Magic number plus symbol identify E2-owned positions and orders. The guard prevents duplicate/direction-conflicting ownership. The reporter can reconcile registered positions with exit deals and identifies an E2-owned open position for which the current process has no registration metadata as `unknownE2Positions`. Generic metadata persistence/recovery for future strategy entries is a foundation requirement, not yet a complete persistence implementation.

## Removed architecture

The active tree contains no TC, RMR, RB, H4 regime, H1 zone/range, M15 confirmation, multi-strategy planner, strategy session filter, V2 execution adapter, or V2 position manager. Git history preserves the former implementation.

The frozen specification is [OBR_STRATEGY.md](OBR_STRATEGY.md). Execution begins in a later sprint only after signal parity is accepted.
