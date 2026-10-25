# EMA or ATR trailing backtests — research/session-momentum

Added to Gold, Compression, Gotobi, NQ ORB and BTC Momentum Pullback.
Session Momentum also exposes the EMA/ATR selector; its default is still EMA12 on M5.

## Inputs in each of the five existing trading EAs

| Input | Default | Meaning |
|---|---|---|
| InpUseEMATrailingStop | false | Enable the selected EMA or ATR overlay (existing input name retained) |
| InpTrailingMethod | E2_TRAIL_EMA | Choose E2_TRAIL_EMA or E2_TRAIL_ATR |
| InpTrailingATRPeriod | 14 | ATR indicator period, used in ATR mode |
| InpTrailingATRMultiplier | 2.0 | Distance in ATR multiples, used in ATR mode |
| InpTrailingEMAPeriod | 12 | EMA period on completed close prices |
| InpTrailingTimeframe | PERIOD_M5 | Explicit indicator timeframe; PERIOD_CURRENT uses chart timeframe |

OFF preserves original trading behavior and config digests. The new input/EA
versions will appear in settings, but the overlay creates no indicator and sends
no requests while disabled. Test OFF first on the same data/settings/costs as your
saved baseline. Defaults do not enable trailing in any existing system.

ON keeps the strategy's ORIGINAL initial SL, cash sizing and TP. Both modes are a ratchet
overlay after entry confirmation: buy stops only rise, sell stops only fall.
They do not replace the initial stop or change initial cash risk/R.
Existing targets, maximum hold, session/weekend exits and PortfolioGuard remain
active and may close a trade before the trailing stop. This is an additional
trailing exit, not a pure trailing-only target replacement.

EMA mode uses the EMA of completed closes. ATR mode uses the completed candle's
close minus ATR x multiplier for buys, and close plus ATR x multiplier for sells.
The ATR comes from native MT5 iATR on InpTrailingTimeframe. This is a close-based
ATR trail, not a rolling-high/low chandelier exit. ATR expansion never widens a
stop. Only the selected indicator is created; its settings must be valid. Both
modes use shift 1, never the forming candle. ATR settings identify enabled run
config hashes; default EMA and disabled-overlay hashes remain unchanged.
Stops round outward to broker tick size. Missing/warming/forming/stale history,
invalid quotes or an invalid modification distance preserve the existing broker
SL; modifications are retried. If a tighter trailing level has already passed the executable
market quote, close through that EA's existing ticket/lifecycle path. Failed close
attempts are throttled, and existing uncertain-close flags remain authoritative.
A market close may fill away from the desired level. No new entries are created by this module.

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
6. Change InpTrailingMethod=E2_TRAIL_ATR, starting with period 14 and multiplier 2.0.
   Keep timeframe, data, costs and risk identical. These are test defaults, not optimized settings.
7. If desired, compare a small predeclared set of periods/timeframes. Do not choose
   a different optimum for each year or judge only the best historical combination.
8. Export the trade CSV, settings, and MT5 report for each run. Exit settings are
   included in enabled run config hashes (Gotobi's settings CSV lists its fields).

Keep cash risk and test range fixed between comparisons. Check long and short
behavior where relevant, early stops, entry-bar exits, original TP preservation,
weekend/session exits, net costs, drawdown and trade count. Validate the native MT5
indicator/stop behavior visually. Automated portable tests exercise the shared
production module; they are not MetaEditor compilation or evidence of profitability.

## Files and versions on this branch

Gold 4.5; Compression 0.14; Gotobi 1.19; NQ ORB 0.12; BTC 0.16; Session Momentum 0.11.
All five depend on strategies/shared/EMATrailing.mqh and TrailingMethod.mqh; copying only one old entry
file without the shared header will not compile. Gotobi also needs its complete
include folder. Gold and Compression need their updated recovery/reporting sources.
The simplest backtest install is the complete strategies/ tree from this branch.

Session Momentum always trails; it has no overlay enable checkbox. Its new selector
uses EMA12 M5 by default, or ATR on M5 with the shared ATR period/multiplier inputs.
Its entry signal and INITIAL stop still use EMA12 even when the TRAILING method is
ATR. The optional New York session close remains independent. It does not receive
the configurable EMA period/timeframe inputs of the five optional overlays.

PortfolioGuard does not receive a trailing stop: it is the account controller,
not a trading system. Its existing daily-loss logic is unchanged. The branch's
v1.02 journal still includes the Session Momentum candidate.

This work stays on research/session-momentum. No existing portfolio member has
been removed, main has not been merged, and the E2-Ultron release is not refreshed.
