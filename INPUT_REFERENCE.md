# E2 ADXBB Sprint 3 Input Reference

Sprint 3 exposes 22 inputs: nine ADXBB inputs and 13 generic inputs. Every input is mapped once and consumed.

| Input | Default | Purpose |
|---|---:|---|
| `InpADXBB_DI_Length` | `7` | RMA length for directional movement and true range used by DI. |
| `InpADXBB_ADX_Length` | `7` | RMA smoothing length for DX into ADX. |
| `InpADXBB_ADX_Threshold` | `20.0` | Strict ranging test: ADX must be less than this value. |
| `InpADXBB_BB_Length` | `20` | Close-price SMA/population-standard-deviation window. |
| `InpADXBB_BB_StdDev` | `2.0` | Bollinger standard-deviation multiplier. |
| `InpADXBB_ATR_Length` | `14` | Pine-style TR RMA length. |
| `InpADXBB_ATR_Multiplier` | `1.0` | Candidate risk-distance multiplier. |
| `InpADXBB_TargetR` | `1.1` | Frozen future target multiple; stored configuration only because execution is absent. |
| `InpOneTradePerDay` | `false` | When true, permits only one successful entry per symbol and broker/server calendar day. |
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
| `InpCsvExportEnabled` | `false` | Enables the Sprint 2 indicator-equivalence validation CSV; no production strategy CSV exists. |

Expected `[E2_INPUT_VERIFY]`: `totalExposedInputs=22, deadInputs=0, duplicateInputs=0, invalidMappings=0`.
