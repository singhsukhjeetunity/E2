# E2 EURJPY Gotobi v1.15

Fourth independent EA, packaged on user instruction after selecting 50-pip / 15:55 UTC. [Installation and preset](../../docs/GOTOBI_INSTALL.md). Risk controls now match Gold Fade: `InpRiskMode`, `InpFixedCashRisk` and `InpBalanceRiskPercent`. Fixed cash is the default mode; amounts are editable, with generic defaults 1000 account-currency units / 1%. These are not selected account allocations. Entry/exit rules are unchanged. The production trio's code and allocation are unchanged. Earlier results and parameter screens remain in `BASELINE.md` and `robustness/` as historical evidence.

## Installation

Copy the entire folder, including `include/`, into `MQL5/Experts/E2/EURJPYGotobi/`. Compile `EURJPY_Gotobi.mq5` with MetaEditor; attach to EURJPY M1. Load `presets/EURJPYGotobi_50p_configurable.set`, verify the trading server's UTC/DST profile, and set `InpBrokerClockVerified=true`. Existing chart inputs and presets override new source defaults. No compiled EX5 is included. The preset's clock profile is a placeholder.

## Fixed setup

| Input / rule | Selected value |
|---|---|
| Stop / safety TP | 50 / 200 pips |
| Entry UTC minute | 955 = 15:55 |
| Following-day fix exit | 00:55 UTC |
| Risk | Editable Fixed cash / Balance percent selector; cash mode default |
| Spread cap | 30 broker points (3 pips on standard 3-digit EURJPY) |
| Magic | 420603 |
| Friday flatten | 20:00 UTC |
| CSV export | On |

Buy on the day before eligible Japanese payment dates 5/10/15/20/25/30. Weekend dates roll to the preceding Friday; nonexistent 30ths and Sunday entries are skipped. Manual Japanese holiday exclusions: `InpExcludedJapaneseDates=YYYYMMDD|YYYYMMDD`; no automatic calendar/rescheduling. Entry grace is 60 seconds. One owned position and one entry per day; entry uniqueness is recovered from deal history. No grid or martingale. Netting accounts reject entry when another position occupies EURJPY. Timed exits require tradable ticks and a connected terminal. Protective SL and safety TP accompany the initial order.

## CSV and journal

Automatic CSV output: `Terminal/Common/Files/E2/EURJPYGotobi/`, printed in Experts. Unique filenames include symbol, mode, account and run ID. `_Trades_T.csv` is compatible with the E2 Journal and includes owned trades, partial fills/exits, manual/broker closes, commission/swap/fees and actual-entry risk/R when available. `_Equity_E.csv` samples account-wide equity approximately once per minute; `_Settings.csv` records settings. Tester equity writes are buffered. Unexpected termination may leave buffered output incomplete. After a live restart, older entries can have blank risk/R with `INITIAL_RISK_UNAVAILABLE`; current FX conversions are not substituted for historical entry risk.

## Evidence and checks

[50-pip Monte Carlo sizing](robustness/MONTE_CARLO_50.md) documents the standalone ten-year 0.23% allocation and three-year alternative. [Completed screen](robustness/SUMMARY.md) retains the five predefined runs. Zero commission in the source reports, weak recent margins and manual holidays remain limitations. Native compilation, broker-specific execution and combined E2 drawdown are not established by packaging. Preserve 2026 as the final holdout; no new optimization was performed.

```sh
python tests/gotobi/run_checks.py
python -m unittest discover -s tests -p 'test_*.py'
```

The portable API shim exercises the actual source's signals, ownership, sizing, exports/recovery, clocks and exits. It is not an MQL5 compiler.
