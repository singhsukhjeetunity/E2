# Compression Breakout — research EA

Entry file: `strategies/CompressionBreakout/Compression_Breakout_Long.mq5`.
Original research instrument: **USDJPY**. The EA accepts other symbols; spread/deviation inputs are raw price units and must be appropriate to that instrument. No account-type-specific trading rules.

## Rules and starting settings

| Setting | Default |
|---|---|
| Signal timeframe | M30, constructed from completed M1 candles aligned to UTC |
| Direction | Long only |
| Channel | Highest high of the previous 20 bars |
| ATR | Wilder ATR14, initialized from the first observed true range |
| Compression | Previous ATR < 0.8 × average of the previous 100 ATR values |
| Trigger | Completed close > previous 20-bar high, and preceding close <= its own previous 20-bar high |
| Entry | First eligible quote at the next bar boundary, maximum delay 5 seconds |
| Stop | 3 × ATR including the completed breakout candle |
| Target | 2R, measured from actual fill |
| Entry window | Monday–Friday, 06:00 inclusive to 20:00 exclusive UTC |
| Time exit | Earlier of eight elapsed hours and 16:45 New York (DST aware) |
| Broker-session safeguard | Earlier exit if the active broker session ends sooner; five-minute buffer |
| One trade per day | **Off**, matching the discovery screen |
| Cash risk | 1000 account-currency units per trade; configure for your account |
| Magic | 2026091703 |
| Maximum spread | 0.03 price units (3 pips on standard USDJPY) |
| Maximum deviation | 0.005 price units (0.5 pip on standard USDJPY) |

The ATR average excludes the current breakout bar. Indicator initialization requires 200 observed bars before collecting the ATR-average history. Earlier partial bars contribute observed OHLC, matching the research implementation; the signal bar itself must contain all 30 M1 candles. Gaps are not filled synthetically. Startup automatically loads 18,000 completed M1 candles at default settings, with a larger history request for longer inputs. No seed-date input is required. The initial historical signal is suppressed so attaching the EA does not execute an old setup.

The New York cutoff is an intraday holding rule. There is no US-equity holiday or half-day entry filter and no fixed calendar expiration. The historical broker clock must still be specified correctly.

## Daily toggle

Set `InpOneTradePerDay=true` to allow **one filled entry per UTC calendar date, symbol and magic number**. A partial fill consumes the allowance. Exits, rejected orders, another symbol or another magic do not. The EA queries authoritative broker deal history, so closing a trade or restarting the terminal does not reset the allowance. If that history is unavailable, the enabled toggle blocks entry until history is available.

With the toggle off, later signals can trade after an exit, but there is still only one position at a time and no re-entry in the same minute as an exit. The daily toggle is part of the configuration hash and settings export.

## Install and compare

1. Copy the whole `strategies` directory to `MQL5/Experts/E2/`, preserving subfolders. Compile `Compression_Breakout_Long.mq5` in MetaEditor. It reuses the existing checkpoint codec and clock utilities, so copying its entry file alone is insufficient.
2. Select USDJPY in Strategy Tester, preferably **Every tick based on real ticks**. The chart timeframe does not change the internal M30 signal timeframe.
3. Set `InpBrokerClock` and `InpBrokerWinterUtcOffsetSeconds` from verified broker history: fixed UTC offset, US seasonal or EU seasonal. The offset is seconds, e.g. +2 hours is 7200. Do not infer historical offsets from the computer's local clock. See the broker-clock guidance in `EMA_TESTING.md`.
4. Run the default strategy with the daily toggle **off** first. Then rerun the same dates and all other inputs with it **on**. Keep each run's complete export set.
5. Compare signals, trades, costs, floating equity, deadline misses and the effect of the daily limit. Broker ticks/spreads, available history, lot steps and the broker-session safeguard can differ from the candle research model. Do not expect identical P&L simply because the signal formulas match.
6. Compile and backtest successfully before demo forward testing. MT5 compilation and tick-level parity have not been established by the portable C++ checks.

## Execution and exports

State is saved before order submission. Unconfirmed submissions are never blindly resent. Actual-fill SL/TP and risk are reconciled from broker history. A failed close is retried; a missed deadline is flagged and stops further entries while existing positions remain managed. Each account/server/symbol/magic has a dedicated compression recovery file and instance lock. Netting conflicts are blocked rather than merging independent strategies.

Exports use only `Terminal/Common/Files/E2/CompressionBreakout/`, with no deeper run/account folders:

- `_Trades_T.csv`: settled net P&L, initial cash risk, UTC timestamps and integrity flags.
- `_Signals_S.csv`: diagnostics, skips, confirmed entries and exits.
- `_Equity_E.csv`: sampled floating plus realized equity.
- `_Settings.txt`: exact configuration, symbol and report clock.

All files from one run share a unique prefix. The strategy identifier is `CB_COMPRESSION_M30_LONG`. Recovery files use the separate `E2_CB_STATE_` prefix. Treat restarted report segments as separate runs when analyzing cumulative equity.

## Automated checks

`python3 tests/run_compression.py` checks the production signal code against an independent batch calculation, executes production feed/bootstrap logic, verifies actual entry/daily-limit and recovery functions with deterministic broker APIs, and tests both New York DST regimes and the broker cutoff. CI also checks dependencies and existing journal/strategy regressions. These checks do not replace MetaEditor compilation or broker-tick tests.
