# NAS100 Session Momentum — research candidate v0.11

Standalone E2 candidate, not an approved replacement or live allocation.
Existing five systems are retained. No performance claim is made.

## Rules

- Use the attached NAS100 CFD symbol (NAS100/USTEC broker suffixes are accepted).
  Internal signal timeframe is M5 regardless of chart timeframe.
- Continuous broker M5 close-price EMA, period 12; it does not reset at the open.
  Require at least 120 calculated bars. Native MT5 iMA supplies the EMA.
- Only the completed 09:30–09:35 New York candle sets direction: close ABOVE its
  EMA buys; BELOW sells; equality skips. Candle color and EMA crossing are irrelevant.
- Submit on a fresh symbol tick in 09:35:00–09:35:59 New York. There is no later
  catch-up, reversal, second signal or second submission that day. A definitive
  rejected order also consumes the day's sole submission attempt.
- Initial broker SL is that completed candle's EMA, rounded outward to tick size.
  No fixed target. If this SL is not on the protective side of the live quote or
  violates broker stop/freeze distances, do not submit.
- InpTrailingMethod chooses E2_TRAIL_EMA (default EMA12) or E2_TRAIL_ATR.
  ATR uses the completed M5 close minus ATR x multiplier for buys, plus for sells;
  InpTrailingATRPeriod=14 and InpTrailingATRMultiplier=2.0 are the defaults.
  Initial stop and entry signal stay EMA12 in both modes. Long stops only rise; short
  stops only fall. Never loosen an existing stop. Retry unsuccessful modifications.
  If the tighter trailing stop has already passed the executable market quote, request
  a market close. If a modification is temporarily too close for the broker, keep
  the existing broker SL and retry; a missing protective SL triggers a close.
- InpCloseAtSessionEnd defaults ON. InpSessionCloseNYHour/Minute default 16:00.
  Known exchange early closes cap this to the earlier cash-session close.
  OFF keeps positions until the trailing stop/guard/manual exit. Existing exposure
  prevents a new opening entry. A missed timed close is recovered when ticks resume.
- Full Nasdaq holidays/weekends are excluded by the existing E2 session calendar.
  Calendar exceptions beyond that maintained list are not discovered automatically.

## Risk and account protection

InpRiskMode defaults to SM_FIXED_CASH, InpFixedCashRisk=1000 in ACCOUNT currency.
Optional balance-percent mode is available. This is a research default, not an
instruction to allocate $1,000 on a live account. Load your intended cash risk.
Sizing uses OrderCalcProfit from the executable quote to rounded EMA stop, floors
volume to broker step, never rounds up to minimum volume, and leaves 15% free-margin
headroom. Margin or volume limits can reduce risk. Costs, gaps, slippage and changing
currency conversion can make realized risk/loss differ from the requested amount.
There is no stop-distance cap or lot-size optimization hidden in the signal.

Live/demo entries require a healthy, unlocked PortfolioGuard through the unchanged
shared PortfolioGate. Ordinary single-EA Strategy Tester bypasses the second-EA gate.
Trailing, session exits and missing-stop recovery are independent of entry permission.

Default magic is 420611. Never reuse an existing system's magic. Owned positions
are filtered by symbol/magic and modified/closed by ticket. Netting accounts block
entry when any position/order already occupies the symbol. Another EA must not
subsequently merge into a net position; hedging is preferred when comparing ORB
and this candidate on the same symbol.

The entry reservation is persisted BEFORE Buy/Sell under Common/Files/E2/
SessionMomentumEntry, keyed by server/login/symbol/magic, with checksum and staged
replacement. Keep those state files. A lifetime exclusive file handle rejects
another same-key instance sharing Common Files. Pending/uncertain submissions
never expire at restart or midnight. Broker fill or terminal zero-fill evidence
resolves them; corrupt/unreadable state blocks entry while exits keep running.
Do not delete state/change magic to bypass a pending submission. Reconcile with
the broker first. Separate VPSs/copiers cannot share this lock: use one execution
source for this strategy/account. Tester state is fresh and in memory only.

## Install and backtest

1. Use this research branch, preserving the full strategies/ tree. Compile
   strategies/SessionMomentum/NAS100_Session_Momentum.mq5 in MetaEditor (F7).
   Native MetaEditor compilation and a real-tick MT5 backtest are required.
2. Select the broker's Nasdaq CFD on M5, Every tick based on real ticks, and an
   account currency/leverage matching the intended account.
3. Verify the historical broker clock. InpBrokerClock supports fixed offset,
   US seasonal or EU seasonal. Offset inputs are HOURS (fractions allowed).
   Defaults are US seasonal winter +2 / summer +3; this is only a starting profile.
   Set InpBrokerClockVerified=true only after checking the broker's timestamps.
   New York DST is calculated separately; EU/US mismatch weeks are handled.
4. Choose cash risk, spread limit (index price units), and session-close ON/OFF, plus EMA or ATR trailing.
   Run both close settings with identical data/costs before judging the candidate.
5. Check sample buys/sells visually: 09:30 candle, 09:35 fill, EMA12 initial SL,
   ratchet, one daily attempt and session-close timestamp.
6. Leave existing systems installed. This is a research comparison; no automatic
   portfolio replacement or merge into main has been made.

## Reporting and PortfolioGuard

InpExportCsv defaults true for backtests and writes run-specific trade, equity,
signal and settings files under Common/Files/E2/SessionMomentum. The research CSV
uses the existing E2_JOURNAL_V1 schema, supports LONG/SHORT and no TP, and includes
actual closed P&L/costs. Its risk calculation uses entry-deal initial SL with current
conversion: useful in tester research, not an authoritative historic live conversion.
Missing/partial aggregate risk leaves R blank. UTC exports require verified clock inputs.

For the consolidated LIVE CSV, compile PortfolioGuard v1.02 from this branch and
preserve all current daily-loss/reset inputs and recovery globals. Risk functions
are unchanged; only the additional journal magic mapping is added.
InpJournalSessionMomentumMagic defaults 420611; match any custom EA magic, or use 0
to exclude the candidate. Existing five mappings remain unchanged. Its strategy
label is NAS100_SESSION_MOMENTUM. Live initial-risk snapshots, costs, manual closes,
both directions and zero TP use the existing journal machinery. Per-run EA exports
can be disabled for live use after verifying the shared journal.
This research branch is not a new E2-Ultron release.

## Validation

Portable tests compile the production EA/headers against deterministic MT5 API
shims and check signal/window/DST, both directions, sizing, trailing, exits, guard,
duplicate/restart/storage behavior and zero-TP exports. Journal tests cover the
new mapping in both directions. This does not replace native MT5 compilation,
broker execution testing or historical performance evaluation.

## Other E2 systems: optional trailing experiments

The same branch adds an optional EMA/ATR trailing overlay to the five existing trading
systems, default OFF. [Settings and backtest steps](../../docs/EMA_TRAILING_BACKTESTS.md).
This candidate uses the same method selector and ATR settings, with its built-in
EMA12 signal/initial stop and M5 trailing timeframe. Trailing is always active here.
