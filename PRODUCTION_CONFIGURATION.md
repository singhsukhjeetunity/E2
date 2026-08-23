# E2 Core Configuration and Verification

Sprint 2 is a signal-only build. OBR candidates may exist, but no configuration can enable trading because no request producer exists. `InpTradingEnabled` only gates the retained executor for future use.

## Configuration categories

- Risk: FIXED_CASH or BALANCE_PERCENT and its selected value.
- Execution safety: magic, master gate, spread, entry deviation, quote age and cooldown.
- News infrastructure: disabled by default, broker UTC conversion, buffers, impact selection and CSV filename.
- Reporting/diagnostics: logging, debug, core verification, CSV and generic visual controls.
- OBR: enablement, M15 ADX/ATR/filter thresholds and explicit broker standard/summer UTC conversion.

The canonical timeframe and 08:00-09:00 Europe/London range are not optimizable inputs. Verify the broker offsets before every historical dataset. London DST is last Sunday in March 01:00 UTC through last Sunday in October 01:00 UTC.

When news filtering is enabled, configure a broker UTC offset from -14 through 14 and supply a valid `FILE_COMMON` dataset following [NEWS_DATA_WORKFLOW.md](NEWS_DATA_WORKFLOW.md). Exporter behavior is unchanged.

## Manual Strategy Tester checklist

1. Compile `E2.mq5` with zero errors and zero warnings.
2. Run a basic EURUSD test with default inputs.
3. Capture the initialization line containing `Strategy layer=OBR_SIGNAL_ONLY`.
4. Capture `[E2_INPUT_VERIFY]` and confirm `totalExposedInputs=30, deadInputs=0, duplicateInputs=0, invalidMappings=0`.
5. Confirm `[E2_CORE_VERIFY].strategyCandidates` equals `[OBR_VERIFY].totalCandidates`; requests, attempts, successes, registrations and finalized trades remain zero.
6. Confirm OBR duplicate/causality and time mutation/reset counters are zero; reconstruction failures must be zero where all four OR bars exist.
7. Confirm the Tester Results/Deals tabs contain no E2 strategy order or deal.
8. Enable debug mode for selected candidate/rejection audit rows and compare OHLC, ATR, ADX, OR/ATR and gap/ATR against TradingView.
9. Confirm there are no runtime errors on initialization or deinitialization.

No old v2.x trading fingerprint is expected: those strategies were intentionally deleted.
