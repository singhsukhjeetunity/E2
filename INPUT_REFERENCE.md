# E2 OBR Input Reference

E2 OBR v1.2.0 exposes 38 inputs. Every declaration is copied once into `E2Config`, validated where applicable, and consumed. There are no compatibility-only inputs.

The canonical controlled-demo values are provided in [E2_OBR_FORWARD_DEMO.set](presets/E2_OBR_FORWARD_DEMO.set). Its `$1,000` fixed-risk value reproduces the engineering baseline and must be reviewed for the target account.

| Input | Default | Category | Consumer and purpose |
|---|---:|---|---|
| `InpOBREnabled` | `true` | OBR | Enables completed-M15 OBR market-model evaluation. |
| `InpOBRSession` | `LONDON` (`0`) | OBR | Selects either the 08:00–09:00 Europe/London OR or the 09:30–10:30 America/New_York OR. It does not alter broker clock conversion. |
| `InpOBRAdxLength` | `14` | OBR | M15 `iADX` DI/ADX length. |
| `InpOBRMinimumAdx` | `20.0` | OBR | Inclusive candidate trend-strength threshold. |
| `InpOBRAtrLength` | `14` | OBR | M15 Wilder ATR length. |
| `InpOBRMinimumRangeAtr` | `0.5` | OBR | Minimum frozen OR size divided by breakout-bar ATR. |
| `InpOBRMaximumBreakoutGapAtr` | `0.5` | OBR | Maximum breakout-close distance divided by breakout-bar ATR. |
| `InpOBRStopBufferAtr` | `0.10` | OBR execution | Structural stop buffer beyond the opposite OR boundary, using frozen breakout ATR. |
| `InpOBRTargetR` | `2.0` | OBR execution | Fixed target multiple of fill-to-submitted-SL Original R. |
| `InpOBRTradeMonday` | `true` | OBR weekday | Allows otherwise-valid candidates on Europe/London Mondays. |
| `InpOBRTradeTuesday` | `true` | OBR weekday | Allows otherwise-valid candidates on Europe/London Tuesdays. |
| `InpOBRTradeWednesday` | `true` | OBR weekday | Allows otherwise-valid candidates on Europe/London Wednesdays. |
| `InpOBRTradeThursday` | `true` | OBR weekday | Allows otherwise-valid candidates on Europe/London Thursdays. |
| `InpOBRTradeFriday` | `true` | OBR weekday | Allows otherwise-valid candidates on Europe/London Fridays. |
| `InpOBRServerUtcOffsetStandardHours` | `2` | OBR time | Broker server standard-time offset used to convert bar opens to UTC. |
| `InpOBRServerUtcOffsetSummerHours` | `3` | OBR time | Broker server summer-time offset. |
| `InpOBRServerUsesEuropeanDst` | `true` | OBR time | Applies summer offset during the Europe/London last-Sunday DST interval. |
| `InpRiskMode` | `E2_RISK_FIXED_CASH` | Risk | Position sizer selects fixed cash or current balance percent. |
| `InpFixedCashRisk` | `1000.0` | Risk | Position sizer requested cash risk in fixed mode. |
| `InpBalanceRiskPercent` | `1.0` | Risk | Position sizer requested balance percentage. |
| `InpExpertMagicNumber` | `2026001` | Execution | Guard, executor and reporter ownership namespace. |
| `InpTradingEnabled` | `true` | Execution | Execution safety/executor master gate. |
| `InpMaxSpreadPips` | `3.0` | Execution | Execution-safety maximum spread; zero disables. |
| `InpMaxEntryDeviationPips` | `2.0` | Execution | Executor deviation from requested entry; future strategy semantics remain to be locked. |
| `InpMaxQuoteAgeSeconds` | `10` | Execution | Execution-safety quote freshness; zero disables. |
| `InpMinimumSecondsBetweenExecutions` | `5` | Execution | Generic successful-execution cooldown. |
| `InpNewsFilterEnabled` | `false` | News | Retained news filter master switch; OBR baseline currently disabled. |
| `InpBrokerUtcOffsetHours` | `999` | News | Broker-time to UTC conversion; sentinel accepted only while filter is disabled. |
| `InpHighImpactBufferBeforeMins` | `30` | News | News blackout lead time. |
| `InpHighImpactBufferAfterMins` | `30` | News | News blackout lag time. |
| `InpNewsHighImpactOnly` | `true` | News | Restricts blocking events to high impact. |
| `InpNewsDataFile` | `"E2_news_events.csv"` | News | `FILE_COMMON` deterministic event dataset. |
| `InpDebugMode` | `false` | Diagnostics | Enables logger debug output. |
| `InpCoreVerificationEnabled` | `true` | Diagnostics | Emits core and input verification blocks. |
| `InpLoggingEnabled` | `true` | Diagnostics | Enables journal logger. |
| `InpCsvExportEnabled` | `false` | Reporting | Enables generic trade CSV foundation. |
| `InpVisualModeEnabled` | `true` | Visual | Enables generic tester visual lifecycle. |
| `InpVisualCleanupOnDeinit` | `true` | Visual | Removes E2-owned chart objects at deinitialization. |

Static verification target: total `37`, dead `0`, duplicates `0`, invalid mappings `0`.
