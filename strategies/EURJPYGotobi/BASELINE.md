# EURJPY Gotobi: retained baseline

User decision, 2026-10-08: retain this candidate and assess S&P 500 Failed Breakout followed by DAX Gap Reversal before optimising Gotobi. It remains in research; no production promotion or live attachment.

Source: uploaded EURJPY_Test_5053221205_1451606400_140_0 Settings, Trades and Equity CSVs. Read-only analysis; source files are unchanged.

EA v1.12, fixed cash risk 1000, initial balance 100000, 60-pip stop, 200-pip safety TP, default 15:55 UTC entry and following 00:55 UTC exit, spread cap 30 broker points, Japanese holiday exclusions empty. Broker clock configured UTC+2 with European DST; historical accuracy remains to verify. Test dates are approximately 2016–2025, rather than the earlier three-year segment.

709 trades, all FINALIZED with populated risk/R and no integrity flags. Net cash profit 49710.42 reconciles to ending balance 149710.42 minus starting balance 100000. Total +49.81971179R, expectancy +0.07026758R/trade, profit factor in R 1.39551483, win rate 57.8279%. Sampled equity maximum drawdown approximately 5.63454%. Commission and fee both zero; swap totals -349.03. Do not assume zero commission matches intended execution without checking symbol/account costs.

| Entry year | Trades | Net R |
|---|---:|---:|
| 2016 | 72 | +10.35489510 |
| 2017 | 70 | +3.63939312 |
| 2018 | 70 | -1.29367030 |
| 2019 | 70 | +4.24903389 |
| 2020 | 71 | +1.57428245 |
| 2021 | 71 | +5.81923128 |
| 2022 | 73 | +15.26774122 |
| 2023 | 70 | +6.64206302 |
| 2024 | 70 | +1.76926084 |
| 2025 | 72 | +1.79748117 |

2023–2025 subtotal +10.20880503R over 212 trades; 2024 and 2025 show smaller gains than 2023. Longest observed trade duration 78.15 hours, consistent with potential holiday/market closure timing rather than the 55-day outlier in the earlier IBS file. Timer exits require available ticks and tradable markets. Calendar exclusions, tick model/quality, continuity, realistic transaction costs and historical clock still require validation before acceptance. No Monte Carlo or E2 correlation result is established.
