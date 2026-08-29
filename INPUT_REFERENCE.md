# E2 ADXBB Production Input Reference

E2 exposes 11 operator-facing inputs. The validated HYBRID_V1_Q50 strategy methodology is fixed internally to prevent accidental live strategy drift.

## E2 Production

| Input | Default | Purpose |
|---|---:|---|
| `InpTradingEnabled` | `true` | Master execution gate. |
| `InpExpertMagicNumber` | `2026001` | E2 order, position, history, and recovery ownership identity. |
| `InpLoggingEnabled` | `true` | Enables operational Journal logging. |
| `InpCsvExportEnabled` | `false` | Enables paired production SIGNALS/TRADES CSV output. |

## Risk Management

| Input | Default | Purpose |
|---|---:|---|
| `InpRiskMode` | `FIXED_CASH` | Selects fixed-cash or balance-percent sizing. |
| `InpFixedCashRisk` | `1000.0` | Requested account-currency risk in fixed mode. |
| `InpBalanceRiskPercent` | `1.0` | Requested balance percentage in percent mode. |

## Execution Safety

| Input | Default | Purpose |
|---|---:|---|
| `InpMaxSpreadPips` | `3.0` | Maximum accepted spread. |
| `InpMaxEntryDeviationPips` | `2.0` | Maximum planned-to-current entry deviation. |
| `InpMaxQuoteAgeSeconds` | `10` | Maximum quote age. |
| `InpMinimumSecondsBetweenExecutions` | `5` | Cooldown following successful execution. |

## Fixed production methodology

HYBRID_V1_Q50 uses DI 7, ADX 7 with threshold 20, Bollinger 20/2 with a 1-pip buffer, no BB re-entry confirmation, ATR 14 with multiplier 2, target 1.5R, one successful trade per broker day, maturity threshold 0.50 ATR, Q50 quality threshold, and a 250-bar causal percentile lookback. Legacy inversion is fixed off and hybrid mode is fixed on.

Debug mode and REGIME research export are internal development settings and default off. Core verification remains internally enabled.

Expected `[E2_INPUT_VERIFY]`: `totalExposedInputs=11, deadInputs=0, duplicateInputs=0, invalidMappings=0`.
