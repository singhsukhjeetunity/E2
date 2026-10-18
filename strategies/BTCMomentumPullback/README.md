# BTCUSD H4 momentum / H1 pullback-breakout — research v0.13

Standalone EA: `BTCUSD_Momentum_Pullback.mq5`, included in E2-Ultron alongside
the other four E2 systems. Historical backtests are not proof of future/live
performance. The published reference's results do not apply to this adaptation.

## Source and adaptation

The public reference is [denniskid2520/btcusdt-research-archive](https://github.com/denniskid2520/btcusdt-research-archive).
Its `src/research/strategy_c_v2_execution_layer.py`,
`src/execution/paper_runner_v2.py`, and `src/data/strategy_c_v2_features.py`
describe a long-only H4 RSI regime and H1 base/pullback/breakout entries.
We inspected these files; no upstream Python code is included or executed here.

The reference reports 69.3% wins with dual stops and a time exit, after a large
parameter search. Those numbers do NOT apply to this EA. The repository also
contains differing RSI implementations: its features helper uses Wilder
smoothing while its paper runner uses simple recent averages. This EA explicitly
uses MT5's native Wilder RSI. Completed-bar timestamps are aligned causally:
a new H4 regime is known only after that H4 bar closes.

The research mandate here is a hard protective stop and a fixed 1R target.
The source's 1.25% close-based alpha stop is therefore replaced with a **broker
intrabar stop at 1.25% of requested entry**, and an equal price-distance TP.
There is no second catastrophe stop, trailing stop, breakeven or partial target.
The original 24-hour exit is **disabled by default**. These are substantive
changes requiring new backtests, not a reproduction of the reported system.

## Exact rules

- Long only on BTC base currency / USD profit currency. Broker suffixes are
  supported via symbol properties. BTCUSDT is not accepted by this USD CFD EA.
- Native broker **H4 Wilder RSI(20) > 70** defines an active zone. Equality is off.
  A zone begins at the CLOSE time of the first completed H4 bar above 70 after
  an inactive bar, and ends when the completed H4 RSI falls to/below 70.
- Broker H4/H1 bars are used. Clock settings convert CSV timestamps to UTC;
  they do not transform OHLC into Binance UTC sessions. Different broker H4
  boundaries can generate different signals. Validate the actual feed.
- Signals are evaluated on completed **H1** bars, independent of chart timeframe.
  Enter at the first available quote in the next H1 bar, within a 60-second grace.
  The confirmation bar must finish at that H1 boundary. No historical-price fill.
- Optional base entry (default on): enter when the H1 boundary coincides with
  the newly confirmed H4 zone start and no own entry exists in that zone.
  Attaching later does not backfill this base entry.
- Pullback: the completed H1 close is at least **0.75% below the maximum H1
  close observed since activation**, including the H1 bar at activation.
- Breakout: the completed H1 close is at least **0.25% above the maximum high
  of up to eight prior H1 bars in that zone**. The signal bar high is excluded.
- Default hybrid allows either, prioritizing pullback if both qualify. Separate
  pullback-only and breakout-only modes permit comparison without changing exits.
- Up to **six entries per zone**, counted from unique owned position identifiers
  in broker deal history. Partial fills count as one position.
- Two-hour cooldown after the latest owned position exit in that zone, including
  manual/PortfolioGuard exits. A still-open position blocks all further entries.
- Any position or pending order on the symbol blocks entries (including other EAs).
- Changing RSI zones does not close an existing trade. Its SL/TP remain active.
- Attach/restart seeds the forming H1 bar. Old signals are not replayed. Zone
  levels and entry budget are reconstructed from completed bars and broker deals.
  If the active zone begins before the 1,024-bar H4 history limit, entries are
  blocked rather than resetting the budget. Missing indicator/history data retry
  only within the grace window. Entry gates consume a processed signal even if
  spread, occupancy, guard or margin blocks execution.

## Default inputs

| Input | Default |
|---|---|
| `InpRSIPeriod` / `InpRSIThreshold` | 20 / 70 |
| `InpEntryMode` | `BTC_HYBRID` |
| `InpBaseEntry` | true |
| `InpOneTradePerDay` | false; when enabled, one filled entry per UTC calendar date |
| `InpPullbackPercent` / `InpBreakoutPercent` | 0.75 / 0.25 (percent, not fractions) |
| `InpBreakoutLookback` | 8 H1 bars |
| `InpMaxEntriesPerZone` | 6 |
| `InpCooldownHours` | 2 |
| `InpEntryGraceSeconds` | 60 |
| `InpStopPercent` | 1.25 |
| Take profit | fixed 1R; no editable reward multiple |
| `InpMaxHoldingHours` | 0 (SL/TP only) |
| `InpWeekendFlat` | false; enable to close and block entries over the weekend |
| `InpFridayFlatHour` / `InpFridayFlatMinute` | 20 / 0, broker server time |
| `InpRiskMode` / `InpFixedCashRisk` | fixed cash / 1,000 account currency |
| `InpBalanceRiskPercent` | 1.0, used only in percentage mode |
| `InpRiskTolerancePercent` | 2.0; permitted initial stop risk is 98–100% of the requested amount |
| `InpMaxSpreadPercent` | 0.05% of Bid; 0 disables |
| `InpMaxQuoteAgeSeconds` | 10 |
| `InpMarginBuffer` | 0.15 |
| `InpDeviationBrokerPoints` | 100 broker points |
| `InpMagic` | 420609 |
| `InpExportCsv` | true |
| `InpBrokerClockVerified` | false until verified |

Risk is sized using `OrderCalcProfit` at the submitted stop and floored to the
broker's volume step. Volume limits, coarse lot steps and insufficient margin
must not silently reduce intended risk: the EA skips any order whose calculated
initial stop risk is outside the tolerance (default $980–$1,000 for a $1,000
request). It checks margin at the actual requested volume instead of shrinking
the volume to fit margin. Never raise a below-minimum size to the minimum lot.
`SYMBOL_SPEC`, `RISK_SIZE` and `RISK_SIZE_BLOCK` in Signals show contract/lot
specifications, intended/calculated risk, and the reason for a skip. Invalid custom
symbol limits cannot be corrected by the EA: copy a valid broker BTCUSD template
and verify min/max/step, contract size, calculation mode and margin specifications
in MT5. Do not override broker restrictions merely to force a trade.
TP uses the rounded SL distance. Actual fill slippage,
price gaps, swaps and commissions can produce outcomes other than exactly ±1R.
A positive `InpMaxHoldingHours` also creates variable-R time exits and must be
labelled as a separate experiment. Broker SL/TP, manual exits and PortfolioGuard
are authoritative; the EA does not adjust protection after entry.

## Optional one trade per day

Set `InpOneTradePerDay=true` to allow at most one filled entry per **UTC calendar
date**, for this symbol and magic. Broker entry-deal history is authoritative:
restarting, changing RSI zones, or closing a trade manually or at SL/TP does not
reset the limit. Partial entry fills still consume only that date's entry slot.
Rejected orders without a fill do not consume the daily slot, although the existing
H1 signal-consumption rule still applies. A trade carried overnight consumes its
entry date, not its exit date; symbol occupancy still blocks concurrent entries.
The next UTC date unlocks the daily gate, subject to every other entry check.

The option defaults off. Missing history or an unverified/ambiguous UTC clock
blocks entries when enabled; exits remain independent. `DAILY_TRADE_BLOCK` logs
the reason, and the option is included in Settings and configuration hashes.

## Optional weekend flat

Set `InpWeekendFlat=true` to close this EA's positions at market from Friday
`InpFridayFlatHour:InpFridayFlatMinute` through Sunday inclusive. New entries
are blocked throughout that window and resume Monday 00:00 **broker server time**.
These times follow the server clock, including its DST changes; they are not UTC.
The option defaults off to preserve the previous trading behavior. Keep stop and
entry inputs unchanged when testing it; market exits can produce fractional R.

Ticks and the five-second timer both manage the exit, independently of the
regime, history, verified UTC profile and PortfolioGuard. Definitively rejected
closes retry at most once every five seconds; ambiguous submissions retain the
existing pending-exit protection. Signals from blocked hours are not replayed.
If Friday's close was missed, a position opened before that cutoff remains due
for closing on Monday's next available quote, including after an EA restart.
`EXIT_REQUEST` logs `WEEKEND_FLAT` and the broker retcode; all weekend inputs are
included in the configuration hash. Only this symbol/magic's positions are closed.

Choose a cutoff **before the actual Friday trading-session close** with a buffer.
The EA cannot force a fill while the market is closed, disconnected or without
usable quotes, nor guarantee that a position is flat if a close is rejected.
Verify the custom symbol's sessions against its price history: this option does
not repair the observed mismatch between weekend quotes and SL/TP execution.

## Execution and restart protections

PortfolioGuard is required for live/demo entries and bypassed only in MT5's
standalone tester. Its absence never disables exits. Ticks create entries;
five-second timers only manage protection/time/weekend exits and reporting.
Uncertain entry/exit submissions remain blocked until broker history or position
state resolves them, including connection errors. Durable account/server/symbol/
magic-scoped terminal globals protect duplicate submissions and signal replay.
Use one instance per symbol/magic. Do not delete `E2B_...` globals to bypass an
unresolved order. Tester globals are isolated per run.

## Backtest

1. Copy `strategies/BTCMomentumPullback` and `strategies/shared` into
   `MQL5/Experts/E2/strategies/`, preserving the relative directory structure.
   Open `BTCUSD_Momentum_Pullback.mq5` in MetaEditor and compile with F7.
2. MT5 Strategy Tester: your **BTCUSD**, **H1**, **Every tick based on real ticks**,
   optimization disabled, deposit 100,000, fixed cash risk 1,000.
3. Use **2017-01-01 through 2025-12-31**, or the earliest available reliable BTCUSD
   real-tick history. Report any missing years. Include 2018 and 2022 bear markets.
   Keep any genuinely untouched later segment separate.
4. Verify the broker's historical UTC/DST profile; set `InpBrokerClockMode`, both
   UTC offsets, and `InpBrokerClockVerified=true` only after verification.
5. Begin with default hybrid, stop 1.25%, and hold hours 0. No threshold optimization.
   If isolating entries, change only `InpEntryMode` and label base-entry status.
6. Verify the broker spread/commission/swap model. Futures funding is not CFD swap.
   Inspect actual filled TP/SL and history integrity before interpreting win rate.
7. Send Trades, Equity, Signals and Settings from MT5 Common Files:
   `Files/E2/BTCMomentumPullback/`.

The journal uses E2_JOURNAL_V1, authoritative entry deals and initial order
protection, includes commissions/swaps/fees and different-magic manual/guard exits.
Equity is this strategy's cash P&L, not account equity; R is blank on equity rows.
Missing initial risk is flagged and never silently replaced with intended risk.
Full configuration hashes include all trading inputs; signal logs identify zones,
RSI values and base/pullback/breakout entries.

## Developer verification

`python tests/run_btc_momentum.py` compiles the actual pure signal helpers and a
translated EA runtime against simulated MT5 APIs. It tests causal H4/H1 alignment,
entry modes, strict threshold, stale/missing data, 1R protection, risk flooring,
zone budget with partial fills, manual-exit cooldown, signal replay, guard checks,
uncertain order recovery, independent exits and CSV fee/R reconciliation.
It does not compile MQL5 or demonstrate performance. Native MetaEditor compilation,
real-tick MT5 backtesting and execution checks remain required.
