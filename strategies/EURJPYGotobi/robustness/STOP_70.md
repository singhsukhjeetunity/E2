# Gotobi robustness: 70-pip stop, 15:55 UTC

Uploaded run 1451606400_33_0, reviewed 2026-10-08. Settings v1.12, cash risk 1000, broker UTC+2/EU DST, entry minute 955, fix minute 55, safety TP 200, Japanese exclusions empty. The stop is 70 pips; no other planned strategy setting changed.

| Measure | 50 pips | 60-pip baseline | 70 pips |
|---|---:|---:|---:|
| Trades | 709 | 709 | 709 |
| Net R | 62.35559800 | 49.81971179 | 45.81180291 |
| PF (R) | 1.42187311 | 1.39551483 | 1.43654319 |
| Win rate | 57.5458% | 57.8279% | 57.9690% |
| Sampled equity DD | 5.79702% | 5.63454% | 5.38697% |
| Closed-trade DD R | 8.15982888 | 6.90346202 | 5.45275007 |

| Entry-year segment | 50-pip R | 60-pip R | 70-pip R |
|---|---:|---:|---:|
| 2016–2020 | 26.37989541 | 18.52393426 | 17.57399743 |
| 2021–2023 | 32.19254475 | 27.72903552 | 24.34141214 |
| 2024–2025 | 3.78315784 | 3.56674201 | 3.89639334 |

70-pip recent segment PF 1.13577463, still modest. 2024 +3.31269526R; 2025 +0.58369808R. Total expectancy +0.06461467R/trade; net cash profit 45693.18 reconciles to ending-minus-starting balance. All 709 trades finalized, no missing risk/R/profit and no integrity flags. Commission/fee zero, swap -307.35. Largest sampled equity gap 78.00556 hours, matching the previous runs; clock/cost/calendar and tester model validation remain outstanding.

Decision: the stop neighborhood is positive across all three predefined segments. 70 is a lower-drawdown contender, not a selected optimum. Changes in stop distance also change position sizing at fixed cash risk; relative return and drawdown are not independent signal discoveries. The recent edge remains substantially weaker than 2021–2023. Finish the two predeclared timing runs at the 60-pip baseline stop: 15:40 UTC (entry input 940), then 16:10 UTC (970), all other inputs unchanged. v1.13 exposes that input without changing its default. No new stop grid, combined optimisation, or use of 2026 for selection.
