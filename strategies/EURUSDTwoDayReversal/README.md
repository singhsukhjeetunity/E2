# System 6 — EURUSD two-day extreme reversal (research v0.10)

Entry: `EURUSD_Two_Day_Reversal.mq5`. This is a standalone research EA on
`research/eurusd-two-day-reversal`, not a change to the four retained systems.

## Source and limits

[Unger Academy, June 2026 Euro FX reversal](https://ungeracademy.com/blog/trading-strategies-strategy-of-the-month-june-2026)
describes short entries at the highest high of the previous two sessions, long
entries at the lowest low, and daily Momentum and Efficiency Ratio filters.
The reported futures results are **not this EA's results**. The source does not
disclose filter periods/thresholds, full exits, intrabar conventions or the
complete session definition. This implementation is an explicit research
interpretation. No expectancy, win rate or portfolio benefit has been established.

## Exact implementation

- Read only completed broker D1 bars (shift 1 onward). Saturday bars are excluded;
  Sunday bars are excluded by default. Levels are the maximum high and minimum
  low of the newest **two eligible completed sessions**, not two calendar days.
- Broker D1 sessions are used directly. A UTC profile converts report timestamps;
  it **does not normalize D1 OHLC** between brokers or recreate CME futures
  sessions. Verify D1 rollover and Sunday conventions before comparing results.
- A **fresh Bid crossing** to/below the low opens long at Ask. A fresh Bid
  crossing to/above the high opens short at Bid. Equality counts as a touch.
  No bar-close reversal confirmation is added. A gap crossing executes at the
  available quote, not retrospectively at the level.
- Initialization, restart, newly available history and daily rollover seed a
  quote first; they do not chase a level already breached. Returning into the
  range and crossing out again can produce a new signal.
- Filter data and entry levels are frozen for the current broker D1 bar.
- At most one own position and no new entry while **any** position or pending
  order occupies the symbol. Default one trade per broker D1 session. Successful
  submissions and historical entry deals consume that session; partial fills
  cannot create additional daily entries.

### Assumed defaults (all editable; not source parameters)

| Setting | Default / exact definition |
|---|---|
| Momentum | 10 sessions; `100 × (latest completed close / close 10 sessions earlier − 1)` |
| Momentum filter | Absolute momentum ≤ 1.0% |
| Efficiency Ratio | 10 sessions; absolute net close change / sum of absolute successive close changes; zero for a flat path |
| Efficiency filter | ER ≤ 0.35 |
| ATR | Simple mean of 14 completed-session true ranges; includes gaps; **not Wilder smoothing** |
| SL | 1.5 × ATR from requested entry; rounded to broker tick size |
| TP | 1.5 × requested ATR stop distance from requested entry |
| Time exit | First available quote after 2 eligible D1 sessions have completed, counting the entry session |
| Daily entry limit | On |
| Spread cap | 2.0 EURUSD pips; 0 disables |
| Risk | Fixed cash 1,000 account currency, or editable percentage of balance (default 1%) |
| Magic | 420606 |
| Margin buffer | 15% |

For example, a Thursday entry counts Thursday and Friday as two completed
sessions and closes on the next available quote after Friday's D1 bar ends.
Time exits are retried after definite broker rejections and partial closes;
broker SL/TP remain active. Missing SL or TP triggers an emergency close attempt.
An unknown/timeout close remains blocked until its ticket disappears; review
the log and broker history if it remains unresolved. Do not remove its protection.

Both filter gates select quiet/non-directional conditions symmetrically. This
is an assumption: the source does not state its exact filter direction. Disabling
the two filters provides a transparent unfiltered baseline; it is not known to
be profitable.

## Execution and recovery

Position volume is floored to the broker step, never raised to minimum lot size.
`OrderCalcProfit` sizes the actual requested SL risk and `OrderCalcMargin` checks
available margin. Spread and stop-distance checks use executable quotes.
SL and TP are included in the entry request. Slippage, gaps and trading costs
can make realized loss exceed the requested risk. ATR/TP settings are not tuned.

The existing PortfolioGuard blocks live/demo **entries**. Tester bypass follows
the existing shared gate. Exit management runs independently of entry filters,
clock verification and guard availability, on ticks and a five-second timer.
Only ticks can trigger entries.

Submission intent is stored in account/server/symbol/magic-scoped terminal global
variables **before** sending. An atomic pending lock reduces duplicate submissions
across charts. Unknown entry execution remains blocked across restarts and daily
rollover until an authoritative entry deal appears. Never delete the `E2R_...`
state merely to bypass an unresolved order; reconcile broker history first. Use
one instance per symbol/magic. Tester runs use isolated state keys.

## Installation and testing

1. Copy the entire repository `strategies/` tree into `MQL5/Experts/E2/` (preserve
   the shared dependency folder). Compile this EA with F7 in MetaEditor.
2. Select EURUSD (broker suffixes allowed), M5 for visual inspection and
   **Every tick based on real ticks**. Logic uses D1 history regardless of chart
   timeframe. Open-price-only modes cannot reproduce intraday touches.
3. Verify the historical broker UTC/DST profile; set `InpBrokerClockVerified=true`
   and choose its clock mode. Unverified clocks prevent entries. Existing presets
   override source defaults; verify every research parameter and risk amount.
4. Begin with 2016–2025, compare the unfiltered baseline and a small predetermined
   filter sensitivity grid. Keep any genuinely untouched future segment separate.
   Do not call already inspected 2026 data out-of-sample.
5. Inspect entries against the previous two eligible completed D1 sessions, both
   sides, Sunday exclusions, first ticks, SL/TP, holding exits and daily limits.
   Validate restarts, manual/guard exits, spread blocks and rejected orders on demo.
6. Compare futures-sourced research with broker CFD/spot costs and session data;
   include commission, swap and slippage. Synchronize its trade/equity history with
   the four retained systems before proposing any allocation within the existing
   2.5% budget.

CSV files are in MT5 Common Files `E2/EURUSDTwoDayReversal/`: trades, signals,
equity and full configuration/hash. Trade records use authoritative entry deal
prices and order SL/TP; net results include commission, swap and fees. Manual or
PortfolioGuard exits are aggregated by position identifier. Recovered positions
are included. Missing initial risk leaves R blank with an integrity flag.
Equity CSV is strategy cash P&L, not whole-account equity; equity R is blank.
If a clock is unset or ambiguous, UTC fields are blank rather than fabricated.

## Developer validation

`python tests/run_two_day_reversal.py` runs the actual signal math and translated
EA runtime against deterministic MT5 API mocks. Tests cover both sides, warmup,
regime filters, volume flooring, SL/TP, daily entry limits, restart/timeout state,
guard blocks, independent exits and timer isolation. Repository dependency and
export checks also apply. These tests **do not replace native MetaEditor
compilation, a real-tick MT5 backtest, or live execution validation**.
