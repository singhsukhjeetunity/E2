# E2-Ultron installation and upgrade

This is an MT5 **source-only** release. No EX5 binaries are supplied. The release
ZIP contains `MQL5/Experts/E2/strategies/`, documentation and a file-hash manifest.
The repository checkout stores the same strategy sources directly in `strategies/`.

## Existing Ultron installation: Gotobi duplicate-entry fix

Gotobi v1.17 saves an entry reservation **before** submitting an order. A broker
fill consumes that scheduled event even after a restart or manual close. An
uncertain response remains blocked across restarts and day rollover until broker
history proves a fill or a terminal zero-fill cancellation/rejection/expiry.
Explicit broker refusals allow a retry; absence of a cached position is not proof.

Save the existing EX5 and input preset. Copy the complete `EURJPYGotobi/` folder,
including `include/EntryGuard.mqh`, and keep `strategies/shared/` in place. Compile
`EURJPY_Gotobi.mq5` in MetaEditor with no errors. Replace the EA at a planned
maintenance point, preferably when flat, and reload the same risk, magic, clock,
entry and exit settings. Keep just one instance for that account/symbol/magic.
The new reservation supplements the existing position/history checks; it cannot
retroactively reserve an old-version submission still in flight during upgrade.
Other systems and PortfolioGuard do not need replacing for this fix.

Live state is stored under **File → Open Shared Data Folder → Files → E2 →
GotobiEntry**, keyed by broker server, login, symbol and magic. Preserve its
`.state` files during restarts and upgrades. An exclusive file handle rejects a
second same-key Gotobi on charts or terminals sharing that Common Files location.
It cannot coordinate a separate VPS, a trade copier, or EAs with different magic
numbers. Use a single execution source per strategy/account across machines.

`[ENTRY_SUBMISSION]` records the broker order/retcode and reservation status:
1 means unresolved, 2 means consumed. `[ENTRY_BLOCK]` reports unresolved broker
submissions or state/storage faults. Existing timed exits and stop management
continue when entry state is unreadable or unresolved. If an entry remains
blocked, restore storage/history access and reconcile the submitted order with
the broker. **Do not delete state or change magic to bypass it.** If no definitive
broker evidence exists, the reservation intentionally stays blocked and requires
manual investigation before any offline state repair. A duplicate-instance lock
failure rejects initialization; leave the original owning instance active.

Strategy Tester uses in-memory reservation only, with a fresh state for each run;
live recovery files cannot contaminate a backtest. No signal, sizing, stop, target,
session, daily-limit setting or guard permission rule changes in this patch.

## Existing Ultron installation: BTC symbol fix

BTC Momentum Pullback v0.14 removes its BTC/USD currency-metadata attachment check.
It now accepts the attached chart symbol even when the broker uses missing or
nonstandard currency metadata. Save the existing BTC EX5 and inputs, replace
`BTCMomentumPullback/BTCUSD_Momentum_Pullback.mq5`, and compile it in MetaEditor.
Retain its existing headers, or copy the full BTC folder from the release.
Load the saved inputs when replacing the EA on its chart. Its signal, risk, exit,
daily-limit and PortfolioGuard rules are unchanged. No other EA needs replacing
for this patch. The chart timeframe does not override its internal H4/H1 signals.

## Pre-Ultron installation: add the shared journal

1. Save the current PortfolioGuard EX5 and its input preset. Retain the five
   trading EX5s, their presets, broker-clock files, recovery files and existing
   terminal globals. Do not clear state to install a release.
2. Extract `MQL5/Experts/E2/strategies/PortfolioGuard/` into the same folder in
   the terminal's data directory. Preserve `PortfolioJournal.mqh` beside the guard
   entry file. Ensure `strategies/shared/` is also present; its code is unchanged.
3. Open `E2_PortfolioGuard.mq5` in MetaEditor and compile with F7. Require no
   compilation errors. The other trading EAs do not need recompiling for the
   journal itself; update Gotobi and BTC separately as above if needed.
4. Replace the existing guard on its chart and restore its saved inputs. Keep
   one guard instance per terminal/account. Preserve the existing loss mode,
   loss amount, reset time and `InpCloseAllOnLimit` setting. Do not attach a
   second guard to work around an active-instance warning.
5. Confirm `ACTIVE` or the previously latched daily-lock state in the chart/log.
   The daily reference must recover without rebaselining. An existing daily lock
   must remain locked; upgrading does not grant a new daily loss allowance.
6. Leave `InpLiveJournalEnabled=true`. Match each journal magic input below to
   that EA's **actual loaded** magic, including any customized values.
7. The log prints `[E2 PortfolioJournal] Shared live journal:` and its exact path.
   Find the file through **File → Open Shared Data Folder → Files → E2 → Portfolio**.
   Available closed broker history is backfilled; no new trade is needed to see it.
8. Check the next fully closed trade against MT5 account history: identity,
   symbol, total volume, weighted fills, net profit and costs. Confirm only one
   row appears after a guard/terminal restart.
9. Once verified, the existing per-EA live exporters may be disabled: Gold uses
   `InpCsvExportEnabled`; Compression, Gotobi, ORB and BTC use `InpExportCsv`.
   Changing these inputs can reinitialize that EA, so preserve all other inputs
   and follow its existing pending-trade/recovery procedure. The shared journal
   continues independently of these switches.

No step changes allocations, installs into another VPS/account, or restarts the
running terminal automatically. Prefer a planned maintenance point when flat;
replacing the guard briefly removes its active monitoring until it restarts.

## Fresh installation

1. Open MT5 **File → Open Data Folder**. Copy the release's `MQL5/Experts/E2`
   folder there, preserving all subdirectories and includes.
2. Compile these six entries in MetaEditor:

   - `GoldSessionFade/XAU_Session_Fade.mq5`
   - `CompressionBreakout/Compression_Breakout_Long.mq5`
   - `EURJPYGotobi/EURJPY_Gotobi.mq5`
   - `NQOpeningRange/NQ_Opening_Range.mq5`
   - `BTCMomentumPullback/BTCUSD_Momentum_Pullback.mq5`
   - `PortfolioGuard/E2_PortfolioGuard.mq5`

3. Attach each trading EA to its matching broker instrument. Use Gold M5,
   Compression M30, Gotobi M1, ORB M5 and BTC H1 charts. Broker suffixes are
   acceptable where supported by the existing EA's symbol checks.
4. Load the intended strategy presets. Configure fixed cash risk per EA for the
   account's fixed-balance allocation, and verify the historical server UTC/DST
   profile. Only set a clock's verified flag after checking it. Generic defaults
   are not a ready-made live allocation or a substitute for your tested presets.
5. Attach one guard to any chart in the same account/terminal and configure its
   daily loss/reset inputs. Attach within the first five minutes after reset to
   seed automatically, or supply the **actual equity reference at that reset**
   through `InpFirstDayReferenceEquity` on first mid-day installation. If unknown,
   the original guard rules block new E2 entries until a verified reset/reference.
   Do not use current equity as a fictitious start-of-day reference.
6. Configure journal mappings, check guard state and verify the first trade
   and journal row in the target terminal. A separate account/terminal needs its
   own guard; terminal Global Variables are not shared risk state across terminals.

## Journal defaults

| Input | Default | Meaning |
|---|---|---|
| `InpLiveJournalEnabled` | true | Shared live/demo journal; always skipped in tester |
| `InpJournalRefreshSeconds` | 60 | Periodic history/cost refresh; permitted range 5–3600 |
| `InpJournalGoldMagic` | 2026001 | Gold entry ownership |
| `InpJournalCompressionMagic` | 2026091703 | Compression entry ownership |
| `InpJournalGotobiMagic` | 420603 | Gotobi entry ownership |
| `InpJournalORBMagic` | 420605 | ORB entry ownership |
| `InpJournalBTCMagic` | 420609 | BTC entry ownership |

Nonzero mappings must be unique; zero disables a mapping. The journal selects
E2-owned positions using entry magic and includes later manual/guard exits using
position ID. Unrelated/manual-origin positions, deposits and withdrawals are not
included. Copied trades require matching actual copied magic values to be included.

## Saved strategy settings versus source defaults

This release does not change strategy defaults. Reusing the correct `.set` file
matters: recompiling or replacing an EA is not evidence that the intended preset
has been restored. Confirm at least symbol, dates, tick model, clock profile,
cash risk, spread limits, filters, daily limits and exits before comparing runs.

For the selected BTC configuration discussed with this release, the relevant
inputs are `InpEntryMode=BTC_PULLBACK`, `InpBaseEntry=true`, `InpStopPercent=2.0`,
`InpWeekendFlat=true`, Friday cutoff 20:00 broker time, `InpOneTradePerDay=true`,
and `InpMaxHoldingHours=0`. Those are **not all source defaults**. Preserve the
account's existing cash risk and verified clock; no universal live preset is shipped.

ORB currently permits two entries per New York day in code. An analysis that
discards subsequent daily entries does not enforce one-entry behavior in MT5.
Gold's one-trade-per-day switch defaults on; BTC's defaults off.

## Journal files and timestamps

One stable `_Trades.csv` exists per broker server/account under Common Files.
`_risk.dat` is internal entry-risk state and `.lock` is the writer lock. Keep the
risk file when moving/restoring the journal. Back up files while the writer is
stopped to obtain a consistent CSV/cache pair. A `.tmp` file is staging, not the
file to import. Do not edit a live journal/cache to reset trading permissions.

The schema is `E2_PORTFOLIO_JOURNAL_V1` with `time_basis=BROKER_SERVER`. Neither
the formatted timestamps nor millisecond values are silently converted to UTC.
Older entries without a saved risk snapshot export actual net cash P&L, blank
risk/R and `INITIAL_RISK_UNAVAILABLE`. Open/partially closed positions do not yet
appear as completed rows. Mixed/reversed netting positions are marked invalid.
See [the full schema and recovery notes](../strategies/PortfolioGuard/README.md).

## Troubleshooting and rollback

- **No new trades:** read the guard's actual state and the EA's gate/clock logs.
  A journal CSV is not permission to trade. Do not delete a daily lock/reference.
- **No journal:** verify live/demo mode, enabled input, unique magic mappings,
  Common Files access and the `[E2 PortfolioJournal]` log. Tester output is
  intentionally handled by the original standalone exporters.
- **File not updating:** close Excel or other applications holding an exclusive
  lock; check connection/history availability and allow retry. Another terminal
  using the same server/account can hold the shared writer lock.
- **History missing a published position:** restore full broker account history.
  The reporter retains the previous CSV instead of silently dropping rows.
- **Malformed existing CSV/cache:** the reporter disables itself and preserves
  files for investigation; guard risk logic remains independent. Retain a backup
  before any manual file repair.
- **Reporting-only rollback:** set `InpLiveJournalEnabled=false`, keeping guard
  risk inputs identical. Individual EA live exporters can be re-enabled.
- **Guard binary rollback:** restore the backed-up guard EX5 and preset. Preserve
  daily-reference/lock globals and strategy recovery state. Keep journal/cache
  backups for a later reinstall; do not rebaseline the daily budget.

## Validation status

Release checks cover portable source/math/runtime behavior with simulated MT5
APIs. They do not compile MQL5 or prove fills on a particular broker. The release
contains no compiled EX5, native compiler certificate, live-performance claim,
new parameter optimization or risk-allocation recommendation.
