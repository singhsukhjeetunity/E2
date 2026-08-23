# E2 Status

## E2 OBR transition — Sprint 1 stripped core

- Generic E2 runtime, market-data, risk, execution-safety, order, ownership, news, logging, CSV and reporting foundations remain.
- The legacy TC/RMR/RB strategy system and its H4/H1/M15 market-model dependencies have been removed.
- No active strategy exists.
- The EA intentionally produces zero candidates, requests, execution attempts and trades.
- The OBR specification remains frozen in [OBR_STRATEGY.md](OBR_STRATEGY.md).
- OBR is not implemented; implementation begins in the next sprint after open rule decisions are resolved.

## Verification target

`[E2_CORE_VERIFY]` must report successful initialization and zeros for all strategy activity, duplicates, causality/ownership violations and unknown positions in a clean test.

`[E2_INPUT_VERIFY]` must report 21 exposed inputs with zero dead inputs, duplicates and invalid mappings.

Historical v2.x implementation and release status are retained in Git history rather than the active current-state documentation.
