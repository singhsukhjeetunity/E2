# Gotobi robustness: 50-pip stop, 15:55 UTC

Reviewed 2026-10-08. Source uploaded run 1451606400_172_0, compared with original 60-pip run 1451606400_140_0. Both settings report v1.12, cash risk 1000, broker UTC+2/EU DST, entry minute 955, fix minute 55, safety TP 200, empty Japanese exclusions. This comparison changes stop 60 to 50 pips. Tester tick model and pricing accuracy remain unverified from CSVs alone.

| Measure | 60-pip baseline | 50-pip test |
|---|---:|---:|
| Trades 2016–2025 | 709 | 709 |
| Net R | 49.81971179 | 62.35559800 |
| Expectancy R/trade | 0.07026758 | 0.08794866 |
| PF in R | 1.39551483 | 1.42187311 |
| Win rate | 57.8279% | 57.5458% |
| Sampled equity DD | 5.63454% | 5.79702% |
| Closed-trade DD in R | 6.90346202 | 8.15982888 |
| Net cash P&L | 49710.42 | 62207.46 |

| Entry-year segment | Trades each | Baseline R | 50-pip R |
|---|---:|---:|---:|
| 2016–2020 | 353 | 18.52393426 | 26.37989541 |
| 2021–2023 | 214 | 27.72903552 | 32.19254475 |
| 2024–2025 | 142 | 3.56674201 | 3.78315784 |

2024 changes from +1.76926084R to -0.15878748R; 2025 changes from +1.79748117R to +3.94194532R. Recent-period PF changes from 1.10388914 to 1.09233580, so the higher historical net R does not establish a stronger recent edge.

All trades finalized, no integrity flags; ledger net profit reconciles to ending-minus-starting balance to floating-point precision. Commission and fee zero in both; swap -349.03 baseline, -413.81 test. Maximum observed equity-sample gap 78.00556 hours in both, maximum holding 78.15 hours. Holiday/cost/clock and real-tick validation remain outstanding.

Decision: keep 50 pips as a contender, not a chosen replacement. At fixed cash risk, a tighter stop also increases position size; more cumulative R does not independently demonstrate a stronger signal. Closed-trade drawdown increases even though percentage drawdown is similar. Follow the original small robustness set; next run is 70-pip stop, unchanged 15:55 UTC entry and all other settings. No broad optimiser search and no use of 2026 for parameter selection.
