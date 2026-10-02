# US-index closing momentum — research protocol

This EA is an unselected research candidate. It is not part of the live E2
20:40:40 allocation and must not receive portfolio risk until the untouched
out-of-sample and walk-forward verdict is complete.

## Exact causal definition

- Test SPX500, NAS100/USTEC and US30 separately. Do not pool instruments or
  choose an instrument after inspecting its final holdout result.
- All session boundaries use DST-aware New York time.
- Prior close is the final M1 close of the immediately preceding cash session,
  including an early-close session.
- The 10:00 decision price is the close of the 09:59 M1 bar. The directional
  signal is the sign of `10:00 price / prior cash close - 1`.
- The optional high-volatility filter requires the absolute current signal
  return to be strictly above the median absolute signal return of the prior
  20 completed sessions. The current day is excluded.
- Entry is the first executable quote at 15:30 ET, within
  `InpEntryWindowSeconds`. Exactly zero return produces no trade.
- Stop distance is `InpStopWindowFraction` times the mean absolute price move
  from the 15:30 M1 open to cash close over the prior 20 eligible full sessions.
  Early-close days are excluded from this window statistic because they have no
  15:30–16:00 window.
- Standard target equals the stop distance around the authoritative fill (1:1).
- If neither level is hit, the EA closes on the first executable quote at 16:00
  ET. This is the close of the 15:55–16:00 five-minute bar.
- At most one filled entry is allowed per New York date, symbol and magic.
- Default risk is 0.5% of current equity. Fixed cash risk is also available for
  reproducible research through `InpRiskMode` and `InpFixedCashRisk`.

Bid/ask spread and market slippage are represented by actual tester/broker
fills. Commission, fees and swap are included in net results. Run MT5 with
**Every tick based on real ticks**. A separate M1-only replication must score a
bar touching both stop and target as a stop; do not use MT5's 1-minute OHLC
mode as the authoritative result.

## Experiment modes

Use the same qualifying dates, volatility-filter choice, sizing and costs:

- `MF_SIGNAL_1R`: published directional signal with fixed 1R target.
- `MF_RANDOM_DIRECTION_1R`: deterministic random direction; run at least 1,000
  seeds and compare the signal result to the full random distribution.
- `MF_ALWAYS_LONG_1R`: always long on the same otherwise-eligible dates.
- `MF_SIGNAL_HOLD_CLOSE`: directional signal with no protective stop or target,
  sized from the same nominal stop distance and held to the 16:00 exit.

## Development, holdout and walk-forward

1. Freeze the full date range first and split it chronologically: first 60% for
   development, final 40% untouched.
2. On the 60% segment only, compare the volatility filter off versus on and
   tune `InpStopWindowFraction` from 0.50 to 1.00. Prefer a broad stable region,
   not the best isolated value.
3. Freeze one configuration per instrument and run it once on the final 40%.
   Do not retune after seeing the holdout.
4. Walk forward chronologically: tune on a rolling three-year window and test
   the selected configuration on the immediately following year. Advance one
   year and repeat. Include every test year, including losing ones.
5. Run all three baselines on matching dates. Report differences with confidence
   intervals or bootstrap distributions, not just point estimates.
6. State the verdict plainly: whether the directional edge remains positive
   after all costs and on untouched/walk-forward data. A good in-sample result
   with a failed holdout is a rejection, not a candidate for more tuning.

Report gross and net profit, gross and net expectancy in R, win rate, profit
factor, trade count, closed and floating drawdown, yearly results, long/short
split, volatility-filter strata and sensitivity to doubled costs.

## CSV exports

With `InpExportCsv=true`, files are written to MT5 Common Files under
`E2/IndexClosingMomentum/`:

- `*_Signals_S.csv`: decisions, filter rejections, entries, exits and execution
  failures with causal inputs and UTC timestamps.
- `*_Trades_T.csv`: E2 Journal V1 trade ledger with actual fills, protection,
  risk, net profit, net R and exit reason.
- `*_Research_R.csv`: per-trade gross profit, explicit trading costs, net profit,
  gross R and net R for the required gross-versus-net comparison.
- `*_Settings.txt`: canonical configuration for exact run identification.

## Compile and test

Copy the complete `strategies` directory into `MQL5/Experts/E2/`, compile
`Index_Closing_Momentum.mq5`, and attach it to the broker's index symbol on M1.
Set the historical broker-clock profile explicitly. The EA builds all cash
session observations from M1 and never uses the broker's CFD D1 candle.
