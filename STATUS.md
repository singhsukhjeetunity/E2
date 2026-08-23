# E2 Status

## E2 OBR transition — Sprint 2 signal engine

- Generic E2 runtime, market-data, risk, execution-safety, order, ownership, news, logging, CSV and reporting foundations remain.
- The legacy TC/RMR/RB strategy system and its H4/H1/M15 market-model dependencies have been removed.
- M15 Europe/London opening-range construction, ATR/ADX filters, breakout checks and deterministic candidate generation are implemented.
- Multiple same-day candidates are observable and deduplicated per completed candle/direction.
- The EA intentionally produces zero requests, execution attempts and trades.
- The OBR specification remains frozen in [OBR_STRATEGY.md](OBR_STRATEGY.md).
- OBR execution is not implemented and remains disconnected.

## Verification target

`[E2_CORE_VERIFY]` must report successful initialization and zeros for all strategy activity, duplicates, causality/ownership violations and unknown positions in a clean test.

`[E2_INPUT_VERIFY]` must report 30 exposed inputs with zero dead inputs, duplicates and invalid mappings.

`[OBR_VERIFY]` and `[OBR_TIME_VERIFY]` report signal, duplicate, causality, reconstruction and DST/state diagnostics.

Historical v2.x implementation and release status are retained in Git history rather than the active current-state documentation.
