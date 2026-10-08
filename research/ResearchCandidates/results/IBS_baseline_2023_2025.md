# US500 Daily IBS: first baseline review

Reviewed 2026-10-08. User assessment: does not look strong enough. Status: weak observed baseline / data-quality failure; no promotion, no parameter optimisation. The user has not yet explicitly requested remote removal.

Sources: uploaded US500_Test_5053221205_1672531200_106_0 Settings.csv, Trades_T.csv and Equity_E.csv. Files are unchanged. Analysis was read-only with pandas; no native MT5 rerun was performed here.

## Settings and coverage

Research EA v1.12, US500, cash risk 1000 (overrides 1% risk input), 100000 starting balance. Standard signal rules: high 10, range 25, band 1, IBS <0.30, stop 3 ATR, target off. Holding cap 5 calendar days, Friday flatten on, entry expiry 180 minutes. Broker clock configured UTC+2 with US DST (enum 2), not the earlier EuroFX European DST profile. Historical correctness of this broker-clock setting has not been independently verified.

Equity starts 2022-12-31 22:00 UTC and ends 2025-12-30 21:59:59 UTC. 978779 sampled rows. 75 trades, all FINALIZED, no missing profit/R/risk and no integrity flags.

## Observed results

- Net cash profit +3371.69; +3.37169% account return across the segment.
- Net R +3.40109628; average +0.04534795R/trade.
- Win rate 53.3333%; profit factor (R) 1.24350227.
- Sampled equity peak-to-trough drawdown 4.70797%; closed-trade drawdown 4.49407876R.
- Average winner +0.43421269R; average loser -0.39906889R.

| Entry year | Trades | Net R | PF (R) |
|---|---:|---:|---:|
| 2023 | 34 | +2.95971994 | 1.83881650 |
| 2024 | 25 | +1.17848598 | 1.18521317 |
| 2025 | 16 | -0.73710964 | 0.81916306 |

Net trade P&L reconciles to final-minus-initial balance within floating-point tolerance. Commission and fees are zero; gross profit 3860.34 and swap -488.65 produce net 3371.69. Whether zero commission matches the intended CFD pricing is unverified. Largest winner contributes +2.93436077R; excluding that trade leaves +0.46673551R as a concentration diagnostic, not an adjusted strategy backtest.

## Data-quality problem

The equity export jumps from 2025-07-16 07:44:30 UTC to 2025-09-09 11:39:00 UTC (1323.91 hours). Trade 142 opened 2025-07-15 22:00 UTC and closed 2025-09-09 11:39 UTC after 1333.65 hours, approximately 55.6 days, despite the 5-calendar-day holding cap. It contributes +1.82771731R (approximately +1.83R). This is consistent with a lack of processed ticks/export interruption; the CSV alone cannot establish the root cause. Runtime timed exits require ticks. Obtain the tester HTML report and Journal around the gap before attributing it to a specific data problem or EA defect.

Another trade runs from 2024-04-15 22:00 UTC to 2024-04-21 22:00 UTC (144 hours). Its 5-day deadline falls on Saturday and the Sunday reopening can account for delayed execution; do not classify this alone as a logic defect.

The prolonged gap makes the 2025 and total results unsuitable as a clean robustness/OOS conclusion. Do not present simply subtracting the gap trade as a repaired result; missing-period signals, exposure and exits require a valid rerun. Current observed returns are too modest to justify promotion or tuning the strategy to rescue the curve. A decision to stop pursuing it can be made as a research-priority decision without claiming the entire published IBS family lacks an edge.
