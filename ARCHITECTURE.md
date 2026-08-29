# E2 ADXBB Production Architecture

E2 connects the validated ADXBB M5 candidate engine to an isolated trade planner, the retained generic sizing/execution core, production reporting, and strategy-specific restart recovery.

## Retained modules

- `core`: environment, symbol/account metadata, generic direction types, and configuration.
- `analysis`: causal closed-candle access through explicit `ENUM_TIMEFRAMES`; M5 is explicitly used by the composition root.
- `risk`: MT5-native monetary risk and volume normalization.
- `execution`: strategy-neutral order request, position ownership, quote/spread/market/margin safety, and market executor.
- `reporting`: Journal verification plus 49-column SIGNALS and 62-column finalized-TRADES datasets. Reports use compact collision-safe paired filenames under Common Files `E2\Reports`; full run/configuration identities remain inside the rows.

`E2.mq5` validates M5 and passes completed bars to `E2ADXBBEngine`. Each candidate is consumed once by `E2ADXBBTradePlanner`, which admits only its immediate next-M5 window and creates a strategy-neutral `E2OrderRequest`. The generic executor submits SL-protected market orders; the composition root resolves the authoritative deal, freezes Original R, attaches the fixed target, persists metadata, and registers the position.

`E2ADXBBRecovery` persists open-position metadata in Common Files. Startup fails safely when an owned live position has missing, corrupt, or mismatched state. Successful-entry deal history is the authority for the optional broker/server-day lock.

## Removed architecture

The active runtime contains no opening-range strategy, market-session/timezone/DST conversion, weekday eligibility, news runtime/exporter, custom chart visualization, or temporary restart-test harness. Historical releases remain available through Git history and the OBR tags.

## Invariants

- M5 chart validation and explicit `PERIOD_M5` market-data requests.
- Closed-bar shift zero maps to platform shift one; forming candles are excluded.
- One E2-owned position per symbol remains the generic ownership rule.
- Risk sizing and execution economics remain strategy-independent.
- Original R is frozen from authoritative fill and submitted initial SL; TP is a fixed Target-R projection.
- Reporting is observational and cannot change trading eligibility or economics.
