# E2-Ultron

Five-system E2 source release with **PortfolioGuard v1.01** and one consolidated
live closed-trade CSV per MT5 account.

## Added

- A guard-owned journal covering Gold, Compression, Gotobi, ORB and BTC, with a
  stable account/server-specific filename under `Common/Files/E2/Portfolio/`.
- One row per fully closed position, aggregating partial fills/closes and
  including manual/guard exits, commissions, swap, fees and net cash P&L.
- Live entry-risk snapshots persisted across restart; net R is provided when
  every entry fill has an authoritative saved risk estimate. Older trades
  without a snapshot keep cash P&L and leave risk/R blank.
- Duplicate-free reconciliation, periodic cost/history refresh, staged file
  replacement, writer isolation and preservation of previously published rows
  when broker history is temporarily incomplete.
- Installation/upgrade, input mapping, timestamp, troubleshooting and rollback
  documentation, plus automated release packaging and SHA-256 checksums.

## Preserved

The five trading systems and their shared execution headers are unchanged from
pre-journal main `57e808d7a36ca05a40b38f6bef60940d76f0f28b`. The guard's daily
reference, floor, lock, reset, heartbeat and account-wide forced-close functions
are unchanged. This release does not alter strategy thresholds, defaults, trade
frequency, risk allocations or historical data.

The shared journal is disabled in Strategy Tester. Existing standalone strategy
CSV exporters and tester guard bypass remain unchanged.

## Included versions

Gold 4.3 · Compression 0.12 · Gotobi 1.16 · ORB 0.10 · BTC 0.13 · PortfolioGuard 1.01.

## Upgrade

Download **E2-Ultron-source.zip** and verify it with **SHA256SUMS.txt**. The ZIP
includes the MT5 folder tree, documentation and `MANIFEST.json` with component
versions, release commit and installed-source hashes. No compiled EX5 is included.

Existing five-system users need to replace/recompile **PortfolioGuard only**,
with `PortfolioJournal.mqh` beside it and shared headers available. Preserve all
saved daily-loss/reset inputs, strategy presets, recovery files and guard globals.
Match journal magic mappings to the actual running EAs. Do not reset a daily lock.
After verifying the shared journal, optionally disable individual EA live exports.

Fresh installations compile all six entry files and require account-specific
risk/clock settings. BTC's selected 2% base + pullback/weekend-flat/one-trade-per-day
settings differ from generic defaults; load your saved preset. ORB still permits
two entries per New York day in code. No live allocation is installed automatically.

Full instructions: [installation and rollback](https://github.com/singhsukhjeetunity/E2/blob/main/docs/INSTALLATION.md)
and [live journal details](https://github.com/singhsukhjeetunity/E2/blob/main/strategies/PortfolioGuard/README.md).

## Verification and limits

Publication requires the portable strategy, lifecycle, clock, guard and journal
checks to pass. Journal scenarios cover all five labels, partial executions,
cost/R reconciliation, restarts, delayed risk capture, incomplete history,
storage failures, netting conflicts and writer/account isolation. Native
MetaEditor compilation and target-terminal checks remain necessary.

`E2_PORTFOLIO_JOURNAL_V1` timestamps are explicitly **broker server time**. The
CSV is an E2 closed-trade journal, not a complete account statement or floating
equity history. Keep `_risk.dat` with it. Reporting runs after guard checks on the
same event loop; slow history/disk can still delay timer processing. The guard
does not reserve aggregate entry-stop exposure or guarantee an exact loss cutoff.
