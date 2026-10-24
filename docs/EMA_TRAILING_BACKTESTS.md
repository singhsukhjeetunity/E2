# Optional EMA trailing backtests — research/session-momentum

Added to Gold, Compression, Gotobi, NQ ORB and BTC Momentum Pullback.
Session Momentum keeps its existing built-in EMA12 trailing rules.

## Inputs in each of the five existing trading EAs

| Input | Default | Meaning |
|---|---|---|
| InpUseEMATrailingStop | false | Enable the optional EMA stop overlay |
| InpTrailingEMAPeriod | 12 | EMA period on completed close prices |
| InpTrailingTimeframe | PERIOD_M5 | Explicit indicator timeframe; PERIOD_CURRENT uses chart timeframe |

OFF preserves original trading behavior and config digests. The new input/EA
versions will appear in settings, but the overlay creates no indicator and sends
no requests while disabled. Test OFF first on the same data/settings/costs as your
saved baseline. Defaults do not enable trailing in any existing system.

ON keeps the strategy's ORIGINAL initial SL, cash sizing and TP. EMA is a ratchet
overlay after entry confirmation: buy stops only rise, sell stops only fall.
It does not replace the initial stop with EMA or change initial cash risk/R.
Existing targets, maximum hold, session/weekend exits and PortfolioGuard remain
active and may close a trade before the trailing stop. This is an additional
trailing exit, not a pure trailing-only target replacement.

The latest completed indicator candle supplies the EMA, never the forming candle.
Stops round outward to broker tick size. Missing/warming/forming/stale history,
invalid quotes or an invalid modification distance preserve the existing broker
SL; modifications are retried. If a tighter EMA has already passed the executable
market quote, close through that EA's existing ticket/lifecycle path. Failed close
attempts are throttled, and existing uncertain-close flags remain authoritative.
A market close may fill away from EMA. No new entries are created by this module.

Ownership is exact chart symbol + EA magic and requests address the position
ticket. The module never edits another EA's trade. Broker SL is the restart ratchet:
it cannot be loosened on reconnect. Gold recovery accepts a tighter live stop
only when enabled, preserving saved initial SL/original R. Compression recovery
does the same and never restores an older, wider stop while trailing is enabled.
Pending-entry protection must finish before Gold/Compression begin trailing.
Do not toggle this research overlay on an already open live position.

## Backtest comparisons

1. Download this branch, retaining the folder structure and shared headers.
2. Compile each chosen EA in MetaEditor with F7 and require no errors.
3. Keep its current symbol, entry/filter/risk/session settings and test dates.
   Use Every tick based on real ticks and the same spread/commission assumptions.
4. Run InpUseEMATrailingStop=false and compare with the saved original baseline.
5. Run true with period 12 and timeframe M5. This matches the EMA family used by
   the Session Momentum candidate, while retaining each old system's initial bracket.
6. If desired, compare a small predeclared set of periods/timeframes. Do not choose
   a different optimum for each year or judge only the best historical combination.
7. Export the trade CSV, settings, and MT5 report for each run. Exit settings are
   included in enabled run config hashes (Gotobi's settings CSV lists its fields).

Keep cash risk and test range fixed between comparisons. Check long and short
behavior where relevant, early stops, entry-bar exits, original TP preservation,
weekend/session exits, net costs, drawdown and trade count. Validate the native MT5
indicator/stop behavior visually. Automated portable tests exercise the shared
production module; they are not MetaEditor compilation or evidence of profitability.

## Files and versions on this branch

Gold 4.4; Compression 0.13; Gotobi 1.18; NQ ORB 0.11; BTC 0.15.
All five depend on strategies/shared/EMATrailing.mqh; copying only one old entry
file without the shared header will not compile. Gotobi also needs its complete
include folder. Gold and Compression need their updated recovery/reporting sources.
The simplest backtest install is the complete strategies/ tree from this branch.

PortfolioGuard does not receive a trailing stop: it is the account controller,
not a trading system. Its existing daily-loss logic is unchanged. The branch's
v1.02 journal still includes the Session Momentum candidate.

This work stays on research/session-momentum. No existing portfolio member has
been removed, main has not been merged, and the E2-Ultron release is not refreshed.
