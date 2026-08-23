# E2 Status

## E2 OBR — controlled forward/demo baseline

Current feature line: **E2 OBR v1.1.0**. Configurable Monday–Friday Europe/London candidate eligibility is implemented; all five defaults are enabled for v1.0.0 parity. No Git tag or release has been created.

Sprint 4 adds passive lifecycle/rejection CSV audits and independent reconciliation summaries without changing the frozen trading rules. Procedures and the accepted baseline are documented in [OBR_VALIDATION.md](OBR_VALIDATION.md).

Sprint 5 prepares release identity **E2 OBR** for controlled forward/demo testing with a canonical preset, one-time production configuration/time diagnostics, corrected missed-window verification semantics, explicit CSV-disabled status, and [OBR_FORWARD_TEST.md](OBR_FORWARD_TEST.md). Proposed future Git tag: `e2-obr-v1.0.0`; no tag or release has been created.

- Generic E2 runtime, market-data, risk, execution-safety, order, ownership, news, logging, CSV and reporting foundations remain.
- The legacy TC/RMR/RB strategy system and its H4/H1/M15 market-model dependencies have been removed.
- M15 Europe/London opening-range construction, ATR/ADX filters, breakout checks and deterministic candidate generation are implemented.
- Multiple same-day candidates are observable and deduplicated per completed candle/direction.
- Candidates are executable only in the immediate next M15 window and pass a fresh Ask/Bid entry-gap check against frozen ATR.
- Structural and broker-valid stops remain separately auditable; sizing uses the submitted stop.
- Actual fill anchors immutable Original R and the fixed 2R target.
- One successful fill per symbol/London day is enforced across restart; failures do not consume the day.
- The OBR specification remains frozen in [OBR_STRATEGY.md](OBR_STRATEGY.md).
- There is no trailing stop, breakeven, partial exit or TP replacement.

## Verification target

`[E2_CORE_VERIFY]` must report successful initialization and zeros for all strategy activity, duplicates, causality/ownership violations and unknown positions in a clean test.

`[E2_INPUT_VERIFY]` must report 37 exposed inputs with zero dead inputs, duplicates and invalid mappings.

`[OBR_VERIFY]`, `[OBR_TIME_VERIFY]`, `[OBR_PLAN_VERIFY]`, `[OBR_EXEC_VERIFY]`, `[OBR_RECOVERY_VERIFY]` and `[E2_RISK_VERIFY]` report signal, planning, execution, persistence and risk diagnostics.

Historical v2.x implementation and release status are retained in Git history rather than the active current-state documentation.
