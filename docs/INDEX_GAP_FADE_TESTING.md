# US-index overnight gap fade — research protocol

This fourth EA is an **unselected research candidate**. Do not include it in the
live 20:40:40 E2 allocation until its untouched out-of-sample and walk-forward
results pass review.

## Exact strategy definition

- Instrument: test NAS100/USTEC, US30 and SPX500 separately; never combine their
  parameter searches.
- Clock: US Eastern cash session, DST-aware.
- Cash open: first M1 open at 09:30 New York.
- Prior close: last M1 close of the preceding completed US cash session. Early
  closes are supported.
- ATR: Wilder ATR over the last 14 completed 09:30-to-cash-close sessions. The
  current day is never included.
- Setup: absolute gap / ATR is within the inclusive minimum and maximum inputs.
- Confirmation: aggregate 09:30–09:34. A gap up requires a red candle; a gap
  down requires a green candle. A doji does not qualify.
- Entry: first tradable quote at 09:35, within `InpEntryWindowSeconds`.
- Standard exit: stop = `InpStopATR × ATR`; target is the identical distance
  around the authoritative fill. Open positions are flattened at 15:55 ET.
- Risk: selectable with `InpRiskMode`. `GF_RISK_EQUITY_PERCENT` risks
  `InpRiskPercent` of current equity (default 0.5%); `GF_RISK_FIXED_CASH` risks
  `InpFixedCashRisk` in account currency (default 500). Lot-step rounding can
  make actual initial risk slightly lower than requested.
- Frequency: at most one filled entry per New York date, symbol and magic.

Broker bid/ask spread is paid naturally. Market-entry and stop slippage use the
actual broker/tester fills. For research, use **Every tick based on real ticks**;
do not use 1-minute OHLC. Real ticks resolve intrabar order. In a separate
bar-only replication, a minute touching both levels must be scored as a stop.

## Event file (mandatory by default)

Copy a completed, independently verified file to:

`Terminal Common Files/E2/IndexOvernightGapFade/US_HIGH_IMPACT_DATES.csv`

CSV format is `date,event`, with ISO dates and event labels `FOMC`, `CPI`, or
`NFP`. The example beside the EA is illustrative only and deliberately
incomplete. With the event filter enabled, a missing, empty or malformed file
stops initialization instead of silently trading event days. Freeze one event
file before running the in-sample and out-of-sample tests.

## 60/40 and walk-forward process

1. Choose the full date interval before viewing results and split it
   chronologically: first 60% development, last 40% untouched test.
2. On the 60% segment only, optimize:
   - minimum gap ATR: 0.15 to 0.35;
   - maximum gap ATR: 1.0 to 2.0;
   - stop ATR: 0.20 to 0.50.
3. Prefer a stable plateau across neighboring settings, not the best single
   cell. Freeze one setting per instrument.
4. Run the frozen setting once on the final 40%. Do not retune after seeing it.
5. Run anchored or rolling walk-forward windows inside the original 60%
   development segment. Report every window, including failed ones.
6. Re-run the same qualifying sample with `GF_RANDOM_DIRECTION_1R` across at
   least 1,000 distinct seeds and with `GF_FADE_HOLD_TO_CLOSE`. The production
   hypothesis should beat the random distribution after costs and should add
   value beyond merely holding the directional fade to 15:55.

Report trade count, win rate, expectancy in net R, profit factor, maximum
closed and floating drawdown, yearly results, long/short split, gap-size bins,
and sensitivity to doubled spread/slippage. Reject any result that depends on
one instrument, one year, or a narrow parameter cell.

## Compile and attach

Copy the whole `strategies` directory into `MQL5/Experts/E2/`, compile
`Index_Overnight_Gap_Fade.mq5`, and attach it to the broker's index symbol on
M1. Set the historical broker-clock profile explicitly. The EA uses M1 cash
session data internally and does not trust the CFD broker's D1 candle.
