# E2 Core Configuration and Verification

Sprint 1 is a no-strategy build. No configuration can enable trading because no strategy request producer exists. `InpTradingEnabled` only gates the retained executor for future use.

## Configuration categories

- Risk: FIXED_CASH or BALANCE_PERCENT and its selected value.
- Execution safety: magic, master gate, spread, entry deviation, quote age and cooldown.
- News infrastructure: disabled by default, broker UTC conversion, buffers, impact selection and CSV filename.
- Reporting/diagnostics: logging, debug, core verification, CSV and generic visual controls.

When news filtering is enabled, configure a broker UTC offset from -14 through 14 and supply a valid `FILE_COMMON` dataset following [NEWS_DATA_WORKFLOW.md](NEWS_DATA_WORKFLOW.md). Exporter behavior is unchanged.

## Manual Strategy Tester checklist

1. Compile `E2.mq5` with zero errors and zero warnings.
2. Run a basic EURUSD test with default inputs.
3. Capture the initialization line containing `Strategy layer=NONE`.
4. Capture `[E2_INPUT_VERIFY]` and confirm `totalExposedInputs=21, deadInputs=0, duplicateInputs=0, invalidMappings=0`.
5. Capture `[E2_CORE_VERIFY]` and confirm `initialized=1`, with zero candidates, requests, attempts, successes, registrations, finalized trades, duplicates, causality violations, ownership violations and unknown positions.
6. Confirm the Tester Results/Deals tabs contain no E2 strategy order or deal.
7. Confirm there are no runtime errors on initialization or deinitialization.

No old v2.x trading fingerprint is expected: those strategies were intentionally deleted.
