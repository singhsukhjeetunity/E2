# E2 Strategy-Free Core Input Reference

Sprint 1 exposes 13 generic inputs. Every input is mapped once and consumed by retained infrastructure. ADXBB inputs and `InpOneTradePerDay` do not exist yet.

| Input | Default | Purpose |
|---|---:|---|
| `InpRiskMode` | `FIXED_CASH` | Selects fixed-cash or balance-percent monetary sizing. |
| `InpFixedCashRisk` | `1000.0` | Requested cash risk in fixed mode. No sizing occurs without a strategy request. |
| `InpBalanceRiskPercent` | `1.0` | Requested balance percentage in percent mode. |
| `InpExpertMagicNumber` | `2026001` | E2 order/position ownership identity. |
| `InpTradingEnabled` | `true` | Generic executor master gate; Sprint 1 has no execution caller. |
| `InpMaxSpreadPips` | `3.0` | Maximum spread accepted by execution safety. |
| `InpMaxEntryDeviationPips` | `2.0` | Maximum planned-to-current entry deviation. |
| `InpMaxQuoteAgeSeconds` | `10` | Maximum quote age. |
| `InpMinimumSecondsBetweenExecutions` | `5` | Cooldown after a successful generic execution. |
| `InpDebugMode` | `false` | Enables debug Journal messages. |
| `InpCoreVerificationEnabled` | `true` | Emits generic input/core/risk verification. |
| `InpLoggingEnabled` | `true` | Enables E2 Journal logging. |
| `InpCsvExportEnabled` | `false` | Retained reporting capability flag; no strategy CSV is produced in Sprint 1. |

Expected `[E2_INPUT_VERIFY]`: `totalExposedInputs=13, deadInputs=0, duplicateInputs=0, invalidMappings=0`.
