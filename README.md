# E2-Ultron

Five standalone MT5 trading systems, one account-wide PortfolioGuard, and one
shared live closed-trade CSV per account. **Source release: compile in MetaEditor.**

## Components

| Component | Market | Signal timeframe | Source version | Entry file |
|---|---|---|---|---|
| Gold Session Fade | XAUUSD | M5 | 4.3 | `strategies/GoldSessionFade/XAU_Session_Fade.mq5` |
| Compression Breakout | USDJPY | M30, built from M1 | 0.12 | `strategies/CompressionBreakout/Compression_Breakout_Long.mq5` |
| Gotobi | EURJPY | Scheduled UTC entry; M1 chart | 1.17 | `strategies/EURJPYGotobi/EURJPY_Gotobi.mq5` |
| Opening Range Long | USTEC / Nasdaq CFD | M5 | 0.10 | `strategies/NQOpeningRange/NQ_Opening_Range.mq5` |
| BTC Momentum Pullback | Chart symbol (researched on BTCUSD) | Broker H4 regime / H1 entries | 0.14 | `strategies/BTCMomentumPullback/BTCUSD_Momentum_Pullback.mq5` |
| PortfolioGuard + live journal | Entire MT5 account | One instance on any chart | 1.01 | `strategies/PortfolioGuard/E2_PortfolioGuard.mq5` |

All five trading systems are long-only. EMA Pullback is not part of this release.
Ultron adds reporting to the existing guard. The BTC v0.14 update removes only
the BTC/USD currency-metadata attachment restriction. Gotobi v1.17 adds durable
entry reservations and a single-instance lock to prevent duplicate submissions.
Signal/exit/sizing rules, shared execution headers, risk defaults and allocations are unchanged.

## Install or upgrade

- [Installation, upgrade, configuration and rollback](docs/INSTALLATION.md)
- [E2-Ultron release notes](docs/releases/E2-Ultron.md)
- [Shared live journal schema and recovery](strategies/PortfolioGuard/README.md)
- [BTC rules and optional entry/exit switches](strategies/BTCMomentumPullback/README.md)

For an existing Ultron installation, copy the complete **EURJPYGotobi** folder
and recompile Gotobi to get the v1.17 duplicate-entry fix, preserving its inputs.
Keep one Gotobi instance per account/symbol/magic. Update BTC separately if its
v0.14 symbol fix is needed. If upgrading from before Ultron, also replace/recompile
PortfolioGuard to add the shared journal. Other trading EX5s can remain installed.
For a new installation, copy the entire `strategies/` tree under
`MQL5/Experts/E2/` and compile the six entry files above. All relative includes
must retain their folder structure.

Do not replace saved account settings with generic source defaults. Risk, magic
numbers, historical broker-clock profiles, filters, weekend exits and daily-entry
switches must match the configuration being traded or backtested. In particular:

- BTC's selected base + pullback / 2% stop / weekend-flat / one-trade-per-day
  configuration differs from its generic defaults. Load your saved preset.
- ORB's code permits two entries per New York day. A portfolio analysis that
  retains only the first trade does not impose that limit in the EA.
- Fixed cash risk is available in all five EAs. A fixed-balance prop-account plan
  requires fixed cash sizing; balance-percent mode changes cash sizing as balance moves.

## PortfolioGuard

Every trading EA checks `E2PGCanEnter()` before live/demo entries. The guard must
run in the **same MT5 terminal/account**. Missing, stale, unseeded or daily-locked
guard state blocks new entries. Strategy exits remain independent.

The guard maintains a reference account equity at the configured broker-server
daily reset. Its equity floor is either reference minus a fixed cash limit, or
reference times one minus the chosen daily-loss percentage. A breach latches a
daily lock. With `InpCloseAllOnLimit=true`, it also cancels pending orders and
attempts to close **all account positions**, including manual/copied trades.

This equity monitor does **not** reserve aggregate stop-loss exposure or enforce
an allocation budget before simultaneous entries. Set each EA's cash risk to your
allocation separately. No release installation changes your planned daily cap.
Reset time/reference settings must match the actual account, rather than a presumed
firm rule. Do not delete daily reference/lock globals during an upgrade.

## One live journal

`InpLiveJournalEnabled=true` enables the guard-owned journal by default. Match its
five magic mappings to the running EAs. It reads broker history directly and does
not depend on the individual EA CSV exporters.

The Experts log prints the exact stable account-specific filename under:

`Common/Files/E2/Portfolio/E2_<encoded-server>_<login>_Trades.csv`

The file contains one row per fully closed E2 position, combining partial fills
and closes. It includes strategy, prices, costs, net cash P&L and available R.
Normal close updates occur on timer reconciliation, throttled to five seconds;
periodic reconciliation also catches missed events and later cost corrections.
Restarting does not create another trade CSV or append duplicate rows.

The schema is `E2_PORTFOLIO_JOURNAL_V1`; timestamps are explicitly
`BROKER_SERVER`, not UTC. Live entry risk snapshots persist in `_risk.dat`.
Historical trades without a snapshot retain cash P&L with risk/R blank. Keep that
sidecar with the journal. Do not combine this schema blindly with UTC backtest files.

After verifying the shared file, optionally disable the five per-EA live exports
through their existing inputs. Re-enable them for backtests as needed. The shared
journal is disabled in Strategy Tester; standalone backtest exports and guard
bypass behavior are unchanged.

## Verification and limits

The release workflow runs portable strategy, lifecycle, reporting, clock and guard
checks before publishing the source package and SHA-256 checksum. The journal tests
exercise production reporting code against simulated broker/file APIs, including
fees, partial fills, restarts, missing history, storage failures and writer isolation.

Portable checks are **not** native MQL compilation or a broker execution guarantee.
Compile changed entries in MetaEditor and verify operation in the target terminal.
The guard and reporter share an EA event loop. Slow history/disk can delay processing.
Server-side SLs remain important during outages; market closure, slippage or rejected
closes can prevent an exact equity cutoff. Reporting faults do not change guard
globals or place trades. See the installation guide for validation and rollback.
