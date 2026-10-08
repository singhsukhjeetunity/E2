# Gotobi: completed five-run robustness screen

Reviewed 2026-10-08. The five runs were predefined: original 60-pip/15:55 baseline, stops 50/70 at 15:55, times 15:40/16:10 at the baseline 60-pip stop. No combined stop/time sweep. All use fixed cash risk 1000, fix exit 00:55 UTC, safety TP 200 pips, and the same 2016–2025 segment. That history has already been observed and is not untouched out-of-sample data.

## Final timing run

Uploaded EURJPY_Test_5053221205_1451606400_45_0 settings confirm v1.13, entry minute 970, stop 60, unchanged cash risk/exit/TP/spread/clock/calendar inputs. 709 finalized trades, no missing profit/risk/R and no integrity flags. Net cash P&L 47245.47 reconciles to ending balance 147245.47 minus initial 100000. Total net R 47.36486388; expectancy 0.06680517R/trade; R PF 1.39461999; win rate 57.1227%; closed-trade DD 6.11090585R. Sampled equity DD 5.04387917%. Commission and fee zero, swap -352.35. Largest sampled time gap 78.00556 hours, consistent with previous runs. Broker clock and actual tick model/quality still need independent verification.

| Entry-year segment | Trades | 16:10 net R | PF (R) |
|---|---:|---:|---:|
| 2016–2020 | 353 | 24.91080732 | 1.45254160 |
| 2021–2023 | 214 | 20.49418246 | 1.63877567 |
| 2024–2025 | 142 | 1.95987410 | 1.05957691 |

2024 +0.41182939R; 2025 +1.54804471R.

## All five runs

| Stop / entry UTC | Total net R | PF (R) | Sampled equity DD | Closed DD R | 2024–2025 R |
|---|---:|---:|---:|---:|---:|
| 50 / 15:55 | 62.35559800 | 1.42187311 | 5.79702% | 8.15982888 | 3.78315784 |
| 60 / 15:55 baseline | 49.81971179 | 1.39551483 | 5.63454% | 6.90346202 | 3.56674201 |
| 70 / 15:55 | 45.81180291 | 1.43654319 | 5.38697% | 5.45275007 | 3.89639334 |
| 60 / 15:40 | 47.20567604 | 1.36933605 | 6.49148% | 6.37956207 | 3.32132158 |
| 60 / 16:10 | 47.36486388 | 1.39461999 | 5.04388% | 6.11090585 | 1.95987410 |

All five are positive in all three predefined segments. This supports local historical parameter stability, not a statistical proof of robustness, independence or future profitability. Recent performance is much weaker. Stop changes also change position sizing; sampled percentage equity DD is not interchangeable with fixed-risk R DD or Monte Carlo tail drawdown.

## Illustrative cost stress, not an asserted broker charge

All supplied runs show zero commission. For a diagnostic only, deduct 7 USD per round-trip lot from each trade's existing net cash result, then divide by its recorded entry risk. This preserves existing fills and is not a full slippage/spread rerun.

| Stop / entry UTC | 2024–2025 R with hypothetical extra $7/lot |
|---|---:|
| 50 / 15:55 | +0.7902 |
| 60 / 15:55 baseline | +1.0721 |
| 70 / 15:55 | +1.7581 |
| 60 / 15:40 | +0.8266 |
| 60 / 16:10 | -0.5350 |

Actual pricing depends on intended account/symbol; do not assume these hypothetical costs are the broker's fees. The recent margins require verification before acceptance.

## Decision and next phase

No compelling reason to change the source-based 15:55 entry. Keep 60-pip/15:55 as the unchanged validation reference; retain 70-pip/15:55 as a lower-drawdown alternative for pre-holdout portfolio evaluation. Do not select merely the highest-profit 50-pip run, combine the best-looking stop/time, add new grid points or use 2026 for tuning. No production defaults changed by this report.

Before locking one configuration: verify broker historical UTC/DST profile, real-tick quality/continuity, actual commission/spread/slippage/financing and Japanese bank-holiday handling; perform calendar/cost validation; evaluate E2 correlation and combined drawdown on already-observed history. Freeze a single chosen configuration and acceptance criteria before the final 2026 holdout, then forward-test. No live deployment or alteration of the production trio's allocation is authorized by this screen.

## Sources

Read-only uploaded settings, trades and equity for runs 1451606400_140_0 (baseline), 1451606400_172_0 (50), 1451606400_33_0 (70), 1451606400_226_0 (15:40), and 1451606400_45_0 (16:10). Original uploads unchanged. Detailed earlier run reports are retained in this directory.
