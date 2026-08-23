# E2 Core Configuration and Verification

Sprint 3 can place OBR trades when both `InpOBREnabled` and `InpTradingEnabled` are true. Validate on a demo/tester environment before any production use.

## Configuration categories

- Risk: FIXED_CASH or BALANCE_PERCENT and its selected value.
- Execution safety: magic, master gate, spread, entry deviation, quote age and cooldown.
- News infrastructure: disabled by default, broker UTC conversion, buffers, impact selection and CSV filename.
- Reporting/diagnostics: logging, debug, core verification, CSV and generic visual controls.
- OBR: enablement, M15 ADX/ATR/filter thresholds, stop buffer, target multiple and explicit broker standard/summer UTC conversion.

The canonical timeframe and 08:00-09:00 Europe/London range are not optimizable inputs. Verify the broker offsets before every historical dataset. London DST is last Sunday in March 01:00 UTC through last Sunday in October 01:00 UTC.

When news filtering is enabled, configure a broker UTC offset from -14 through 14 and supply a valid `FILE_COMMON` dataset following [NEWS_DATA_WORKFLOW.md](NEWS_DATA_WORKFLOW.md). Exporter behavior is unchanged.

## Manual Strategy Tester checklist

1. Compile `E2.mq5` with zero errors and zero warnings.
2. Run a basic EURUSD test with default inputs.
3. Capture `[E2_INPUT_VERIFY]` and confirm `totalExposedInputs=32, deadInputs=0, duplicateInputs=0, invalidMappings=0`.
4. Re-run the Sprint 2 baseline period and confirm `[OBR_VERIFY].totalCandidates` remains the accepted candidate count (316 for the locked baseline dataset).
5. Confirm every valid plan uses the candidate's immediate next M15 window and current Ask/Bid entry gap is at most 0.5 frozen ATR; deliberately start late and confirm expiry without an order.
6. For long and short fills, verify structural SL, outward broker-valid submitted SL, volume risk, actual fill, immutable Original R and fixed normalized 2R TP in logs/CSV/deals.
7. Force spread, stale-quote, margin and broker rejection scenarios. Confirm no failed attempt consumes the London day and no deterministic request executes twice.
8. Restart once with an open OBR position and once after a same-day closed OBR trade. Confirm metadata recovery, unchanged Original R/SL/TP, and day lock recovery without a duplicate trade.
9. Confirm `[OBR_PLAN_VERIFY]`, `[OBR_EXEC_VERIFY]`, `[OBR_RECOVERY_VERIFY]`, `[E2_RISK_VERIFY]` and `[E2_CORE_VERIFY]` show zero duplicate, causality, ownership and recovery violations.
10. Confirm there is no SL/TP movement, breakeven, partial close or trailing behavior and no runtime errors on initialization/deinitialization.

The full determinism, TradingView parity, DST, restart and control-run procedures are in [OBR_VALIDATION.md](OBR_VALIDATION.md). Do not mark those controls passed from compilation alone.

No old v2.x trading fingerprint is expected: those strategies were intentionally deleted.
