# PortfolioGuard live trade journal — v1.01

PortfolioGuard can maintain **one stable closed-trade CSV for all five E2
systems on this MT5 account**. The five trading EAs do not need code changes.
The guard's daily reference, lock, heartbeat, reset and emergency-close rules
are unchanged. This is an optional reporter, not another trading controller.

## Install

1. Keep a backup of the current guard EX5 and its input settings. Copy
   `strategies/PortfolioGuard/` and `strategies/shared/` into the same existing
   `MQL5/Experts/E2/strategies/` tree, preserving relative paths.
2. Compile **only `E2_PortfolioGuard.mq5`** in MetaEditor (F7). Portable tests
   do not establish native MQL compilation. Keep the existing five trading EAs
   and their compiled files unchanged.
3. Replace the existing guard on its chart, retaining the same daily loss/reset
   inputs. Keep exactly one guard per account/terminal. Existing daily lock and
   reference state recover under the original rules; never delete them to install.
4. `InpLiveJournalEnabled=true` is the default. Match the five `InpJournal...Magic`
   inputs to the actual EA magic numbers. A zero magic disables that mapping;
   nonzero mappings must be distinct. Symbols, including broker suffixes, come
   from the broker deals rather than hardcoded instrument names.
5. The Experts log prints the account-specific path. Open MT5 **File → Open
   Shared Data Folder → Files → E2 → Portfolio**. The main file is:

   `E2_<encoded broker server>_<account login>_Trades.csv`

6. Once the shared journal is working, you can optionally stop the per-EA live
   files through existing inputs: Gold `InpCsvExportEnabled=false`; the other
   four `InpExportCsv=false`. The shared journal reads broker history and needs
   none of those files. Re-enable those inputs for backtests when desired.

Attaching a new input set can reinitialize a trading EA; preserve its other
settings. Installation does not change allocations or install a new EA on any
remote terminal automatically.

## What is exported

- Fully closed E2 positions, one row per broker position identifier, sorted by
  final close time. Partial entry fills and partial closes reconcile into that
  row. Open/partially closed positions are excluded until completely closed.
- The strategy is identified from **entry magic**, not close magic. Manual,
  PortfolioGuard and other external closes of an E2-owned position are included.
- Weighted entry/exit prices, entry volume, original deal SL/TP, gross P&L,
  commissions, swap, fees, net P&L and available initial cash risk/net R.
- Account login, broker server, magic, position ID and a stable trade ID.
- `fill_time`, `exit_time`, `entry_msc`, `exit_msc` are **broker server time**,
  explicitly marked `time_basis=BROKER_SERVER`. They are not silently treated
  as UTC. Broker history is used directly; no additional clock profile is needed.

The dedicated schema is `E2_PORTFOLIO_JOURNAL_V1`. Do not assume this file has
the same columns/time basis as each EA's standalone backtest export.

Deposits, withdrawals, unrelated/manual-origin positions and account-level fees
without a position identifier are excluded. Position-associated costs are
included, even if posted after closing. This is an E2 trade journal, not a full
broker statement. Reversed or mixed-owner netting positions are labeled
`INVALID` / `MIXED_OR_REVERSED_POSITION`, with cash P&L retained and R blank.

## Risk snapshots and backfill

While running, the guard calculates each new entry fill's initial stop cash
risk using actual fill price, volume, the entry deal's SL and `OrderCalcProfit`.
It retries briefly if deal history/conversion is not immediately ready. Risk is
saved per deal in the account-specific `_risk.dat` sidecar, so later FX conversion
changes or restarting MT5 do not rewrite the entry-time risk estimate.

`OrderCalcProfit` risk excludes commissions and gap/slippage beyond the stop;
net P&L includes position-associated costs. No requested cash budget is substituted
for a missing snapshot. A trade is given R only when **every** entry fill has a
valid saved snapshot and position ownership/direction are clean.

On first installation, available account history is backfilled automatically.
Historical trades, entries while the guard was offline, or entries without an
available initial SL/conversion retain their real net cash P&L, but have
`INITIAL_RISK_UNAVAILABLE`, blank risk/R, and `risk_basis=UNAVAILABLE`.
They are not retrospectively valued using today's FX rates. Trades captured
live use `risk_basis=LIVE_ENTRY_SNAPSHOT`.

Keep `_risk.dat` with the CSV; it is internal bookkeeping, not another trade
export. The `.lock` file prevents competing writers in other MT5 terminals
sharing Common Files. A lock is an open file handle and releases on shutdown.

## Updates, restarts and failures

- The existing guard executes **first** on every timer. Journal work follows.
  Entry callbacks only capture an individual risk estimate and mark data dirty;
  no full account-history scan or disk export runs inside the callback.
- Normal new-close updates happen on the next timer reconciliation, throttled
  to at most once every **five seconds**. Default periodic reconciliation is
  **60 seconds** (`InpJournalRefreshSeconds`, range 5–3600), catching missed events
  and later position-associated cost corrections.
- Rebuild from available broker history, stage a temporary file, flush/close it,
  then replace the stable CSV. Repeated events/restarts do not append duplicates.
  Saved closed IDs prevent temporarily incomplete history from replacing an
  already-published journal with a shorter one, including after restart.
- A disconnected account, unavailable history, locked output, failed write or
  failed replacement causes a logged retry. If Excel locks the CSV, close it to
  allow updates. A malformed pre-existing CSV/risk cache disables the reporter
  for that initialization and preserves the files for investigation.
- Reporting faults never change guard globals, place orders or disable existing
  exits. The original guard continues operating. Reporting uses the same EA
  event loop, however, so very large history downloads/slow disk can delay timer
  processing; it is not a separate background thread.
- The shared journal is **disabled in Strategy Tester**, regardless of its input.
  The five original strategy exporters and backtest behavior remain unchanged.

## Verification

`python tests/run_portfolio_journal.py` compiles the actual reporting module
(MQL input/array declarations translated) with deterministic broker/file mocks
and address/undefined-behavior sanitizers. Coverage includes all five strategies,
partial fills/closes, manual exits, cash/R costs, repeated notifications, restart
and stale-history recovery, delayed risk capture, locked/failed storage, netting
conflicts, account/writer isolation and tester bypass. Native MetaEditor compilation
and demo-terminal filesystem/trade-event checks remain required.

MetaQuotes references: [entry deal SL and costs](https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties),
[trade callbacks](https://www.mql5.com/en/docs/event_handlers/ontradetransaction),
[staged file replacement](https://www.mql5.com/en/docs/files/filemove).
