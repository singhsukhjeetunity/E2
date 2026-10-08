# Gotobi robustness: 60-pip stop, 15:40 UTC

Reviewed 2026-10-08. Source uploaded run 1451606400_226_0. Settings confirm v1.13, entry minute 940, stop 60 pips, cash risk 1000, exit minute 55, safety target 200, broker UTC+2/EU DST, Japanese exclusions empty. Other baseline inputs unchanged.

| Measure | 15:55 baseline | 15:40 test |
|---|---:|---:|
| Trades | 709 | 709 |
| Total net R | 49.81971179 | 47.20567604 |
| Mean R/trade | 0.07026758 | 0.06658064 |
| PF (R) | 1.39551483 | 1.36933605 |
| Win rate | 57.8279% | 59.0973% |
| Closed-trade drawdown R | 6.90346202 | 6.37956207 |
| Sampled equity drawdown | 5.63454% | 6.49148% |

| Entry-year segment | Baseline R | 15:40 R |
|---|---:|---:|
| 2016–2020 | 18.52393426 | 20.72603849 |
| 2021–2023 | 27.72903552 | 23.15831597 |
| 2024–2025 | 3.56674201 | 3.32132158 |

2024 +3.57579899R; 2025 -0.25447741R. Net cash P&L 47110.89 reconciles to ending 147110.89 minus initial 100000 to floating-point precision. All finalized, no missing profit/risk/R and no integrity flags. Commission and fee zero, swap -350.32. Maximum sampled gap 78.00556 hours, as in earlier runs. Calendar, historical clocks, actual costs and tick-model validation remain outstanding.

Decision: 15:40 does not offer a clear improvement over the 15:55 baseline: lower cumulative return/PF and higher sampled floating-equity drawdown, despite slightly better closed-trade drawdown and win rate. All predefined segments remain positive, supporting timing-neighborhood stability rather than a unique peak. Do not select new parameters yet. Next and last planned run: 60-pip stop, 16:10 UTC (InpEntryUTCMinute=970), same dates and all other settings. Do not extend the grid or use 2026 for tuning.
