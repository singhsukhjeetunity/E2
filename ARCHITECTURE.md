# E2 Strategy-Free Core Architecture

Sprint 2 adds the observational ADXBB M5 indicator and signal engine. It creates deterministic candidates and an optional indicator-validation export, but no planner, recovery schema, sizing request, execution request, order, or production strategy CSV exists.

## Retained modules

- `core`: environment, symbol/account metadata, generic direction types, and configuration.
- `analysis`: causal closed-candle access through explicit `ENUM_TIMEFRAMES`; M5 is explicitly used by the composition root.
- `risk`: MT5-native monetary risk and volume normalization.
- `execution`: strategy-neutral order request, position ownership, quote/spread/market/margin safety, and market executor.
- `reporting`: Journal logging, generic CSV mechanics, inert reporter boundary, and core/risk verification.

`E2.mq5` validates M5 and passes only completed M5 bars to `E2ADXBBEngine`. The engine performs custom Pine-style DMI/ADX, ATR, and population-standard-deviation Bollinger calculations and emits observational candidates. The generic executor remains available but has no caller capable of generating an order request.

There is no strategy-specific recovery during Sprint 1 because the core cannot open positions. Existing owned positions are detected and warned about but are not managed or modified. Future ADXBB recovery will be introduced only in its authorized sprint.

## Removed architecture

The active tree contains no opening-range strategy, market-session/timezone/DST conversion, weekday eligibility, news runtime/exporter, custom chart visualization, strategy preset, or strategy CSV production. Historical releases remain available through Git history.

## Invariants

- M5 chart validation and explicit `PERIOD_M5` market-data requests.
- Closed-bar shift zero maps to platform shift one; forming candles are excluded.
- One E2-owned position per symbol remains the generic ownership rule.
- Risk sizing and execution economics remain strategy-independent.
- Sprint 2 may produce signal candidates while trade requests, execution attempts, registrations, and finalizations remain zero.
