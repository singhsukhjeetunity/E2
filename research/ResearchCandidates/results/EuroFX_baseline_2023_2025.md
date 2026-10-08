# EuroFX Extreme Reversal: first baseline review

Reviewed 2026-10-08. Verdict: FAIL BASELINE / execution-model validation pending. No promotion; no parameter search authorized by these results. This verdict concerns the implemented research hypothesis, not the undisclosed publisher's original system.

Sources: user-uploaded run EURUSD_Test_5053221205_1672531200_155_0, Settings.csv, Trades_T.csv and Equity_E.csv. Original uploads are unchanged. CSVs were analyzed directly with pandas; no MT5 test was run in this environment.

## Configuration and coverage

EA v1.10, EURUSD, magic 420601. Fixed cash risk 1000 overrides risk-percent input 1.0; actual sized risk 972.84–999.96 (mean 988.63). Initial account balance 100000. Other signal/exit settings match the default baseline: 2-session extremes, momentum 5, ER 10 <= 0.35, absolute momentum <= 1.5 ATR, ATR stop 3, target off, session 00:00–22:00 UTC, one entry/day and Friday flatten 20:00 UTC. Feed clock configured UTC+2 with European DST and user verification enabled; historical correctness is not independently established by the CSV.

Equity spans 2022-12-31 22:00 UTC to 2025-12-30 21:59:59 UTC (approximately broker dates 2023–2025). It does not provide the intended 2022 trading year. Equity samples: 1109788. Trades: 273, all FINALIZED, no integrity flags, no missing profit/risk/R, no duplicate trade IDs or negative holding durations.

## Results

| Measure | Result |
|---|---:|
| Net profit | -2584.80 |
| Account return | -2.5848% |
| Total net R | -2.62401447 |
| Mean net R/trade | -0.00961177 |
| Winners | 43.2234% |
| Profit factor (R) | 0.85722039 |
| Profit factor (cash) | 0.85771707 |
| Average winner | +0.13350899R |
| Average loser | -0.11856823R |
| Sampled account equity peak-to-trough DD | 4.60249% |
| Closed-trade R drawdown | 4.44403123R |

| Entry year | Trades | Net R | PF (R) |
|---|---:|---:|---:|
| 2023 | 88 | -0.33577440 | 0.94487809 |
| 2024 | 81 | +0.61090882 | 1.12023555 |
| 2025 | 104 | -2.89914889 | 0.59765644 |

Longs: 130 trades, -0.77566748R. Shorts: 143 trades, -1.84834699R. Both directions negative. Mean holding time 13.02 hours. One year-end trade was held 30.99 hours; lack of tradable holiday ticks can delay a timed exit and should be checked in the Journal.

## Reconciliation and costs

Trade net profit sum matches final balance minus starting balance to floating-point precision. Net = gross + commission + swap + fee for every trade. Exported R matches profit / initial cash risk within rounding tolerance. Commission and deal fee are both zero; swap totals -130.11. Gross profit before swap is still negative (-2454.69). Spread and slippage are reflected in fill outcomes but cannot be independently validated from these exports.

Illustrative extra commission of 7 account-currency units per round-trip lot, not an asserted broker charge: total -3.53185113R, PF 0.81309466. Cost stress makes the negative baseline worse.

## Validation gap and next action

242/273 entries occur at second 40, another 22 at second 20. This is consistent with generated tick timing but is not proof of tester mode. The settings CSV does not record tester tick model, real-tick share, exact requested date range or historical data quality. MetaQuotes documents fallback to generated ticks if real ticks are absent/inconsistent: https://www.mql5.com/en/docs/runtime/testing and https://www.mql5.com/en/book/automation/tester/tester_ticks .

Obtain tester HTML report and relevant Journal lines. If this was OHLC/generated ticks, rerun unchanged rules on verified real ticks with intended costs and 2022–2025 coverage, with sufficient warm-up. Do not use 2026 or tune filters/stops to rescue this result. If execution/data checks confirm this baseline, eliminate this implementation and proceed to US Index Daily IBS. A negative estimate is evidence of baseline failure, not a statistical proof that every member of the strategy family has no edge.
