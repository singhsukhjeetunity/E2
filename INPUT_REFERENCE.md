# E2 Sprint 1 Input Reference

The strategy-agnostic core exposes 21 inputs. Every declaration is copied once into `E2Config`, validated where applicable, and consumed by an active generic service. There are no compatibility-only inputs.

| Input | Default | Category | Consumer and purpose |
|---|---:|---|---|
| `InpRiskMode` | `E2_RISK_FIXED_CASH` | Risk | Position sizer selects fixed cash or current balance percent. |
| `InpFixedCashRisk` | `1000.0` | Risk | Position sizer requested cash risk in fixed mode. |
| `InpBalanceRiskPercent` | `1.0` | Risk | Position sizer requested balance percentage. |
| `InpExpertMagicNumber` | `2026001` | Execution | Guard, executor and reporter ownership namespace. |
| `InpTradingEnabled` | `true` | Execution | Execution safety/executor master gate; no strategy caller exists. |
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

Static verification: total `21`, dead `0`, duplicates `0`, invalid mappings `0`.
