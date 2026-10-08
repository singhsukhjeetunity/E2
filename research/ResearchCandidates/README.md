# Independent E2 research candidates

These are **research implementations, not validated system 4 or replicas of the reported backtests**. The original E2 files, allocation, journal and deployment are untouched. Nothing in this directory auto-attaches an EA or changes the live portfolio.

## Install

Copy this entire directory to `MQL5/Experts/E2/ResearchCandidates/`. Compile each `.mq5` in MetaEditor, retaining the `include` directory. These EAs require only the MT5 standard `Trade/Trade.mqh` library and their new local headers. Attach to the intended symbol; execution uses that chart's symbol and explicit strategy timeframes regardless of chart timeframe. Use distinct magic numbers for every simultaneous instance. **Do not attach two instances of the same EA/magic to the same symbol.**

| EA | Intended market | Default magic | Reference session | Signal data |
|---|---|---:|---|---|
| `EURJPY_Gotobi.mq5` | EURJPY | 420603 | Entry 15:55 UTC, exit following 00:55 UTC | Japanese date and execution ticks |
| `SP500_Failed_Breakout.mq5` | US500 / ES | 420604 | 09:30–16:00 New York | Previous reference session and completed M15 bars |
| `DAX_Gap_Reversal.mq5` | DE40 / DAX | 420605 | 08:00–22:00 Berlin | Previous reference session and completed M30 bars |

Broker/futures/ETF/CFD prices, spreads and session definitions differ. A published futures or SPY return is **not** a backtest of these EAs on a CFD feed.

## Simplified inputs (current build v1.12)

Settings are grouped and labeled in plain language: strategy parameters, risk/execution, historical feed clock, exits, CSV reports and calendar exceptions. Reference-session clocks, ATR period (14), 90-day lookback, 80% minute coverage, 60-second intraday entry grace and 10-point deviation are fixed implementation constants. Default signal rules are unchanged. IBS additionally exposes its post-close entry-expiry window (default 180 minutes); leave it fixed during initial testing. Only daily IBS exposes maximum holding days; the others use their existing session/fix deadline. Friday flattening remains adjustable on/off, at fixed 20:00 UTC. Review and re-save old `.set` files: removed custom parameters no longer override these fixed defaults.

## Automatic CSV exports

`InpExportCsv=true` by default. Each local test/demo/live run creates unique filenames and prints their absolute location in the Journal:

```text
Terminal/Common/Files/E2/ResearchCandidates/<magic>/
    <symbol>_<mode>_<account>_<unique-run>_Trades_T.csv
    <symbol>_<mode>_<account>_<unique-run>_Equity_E.csv
    <symbol>_<mode>_<account>_<unique-run>_Settings.csv
```

In MT5 choose **File → Open Data Folder**, go up to `Terminal`, then open `Common/Files/E2/ResearchCandidates/`. The Journal's absolute path is authoritative for other installation layouts. Use local tester agents; remote/cloud reports are not guaranteed to appear locally.

- **Trades:** E2 journal columns, one row per owned position, weighted partial-fill prices, UTC entry/exit time, direction, SL/TP, initial cash risk, gross profit, commission, swap, deal fees, net profit and net R. Ownership comes from entries, so manual/broker exits with a different magic are included. Foreign positions are excluded; merged/reversed positions are invalid. Partial exits stay `OPEN` until fully settled. Account-level commission adjustments without a position ID cannot be assigned to a trade.
- **Equity:** account balance, equity and free margin on the first tick, approximately once per minute, and at completion/shutdown. Live equity includes all strategies on the account; this sampling does not capture every intraminute extreme.
- **Settings:** complete strategy/clock/risk/execution configuration, including fixed constants.

On live/demo runs, trade history is rebuilt after transactions (at most once a minute) and at shutdown. During backtests, the ledger is finalized at tester completion/shutdown instead of repeatedly rebuilding the entire deal history. Export errors are logged; initial file creation failures block startup when export is enabled. Repeated runs preserve earlier reports. After an interrupted process, the next run recovers owned position history into its own report.

Initial cash risk is captured per actual entry fill/SL with account-currency conversion at entry. Entries predating a live restart retain historical P&L but have blank risk/R and `INITIAL_RISK_UNAVAILABLE`: their in-memory entry conversion snapshot is gone. Missing SL/risk likewise yields blanks. A normal uninterrupted backtest captures its entries. UTC text timestamps are canonical; millisecond columns preserve broker deal timestamps. The E2 column layout is reused, but support for research strategy names depends on the dashboard importer.

## Clock and data setup

Set `InpBrokerWinterUTCMinutes` and `InpBrokerDST` to the **historical feed's** verified clock; then set `InpBrokerClockVerified=true`. Defaults of UTC+2 with European DST are placeholders, not a detected broker profile. Fixed UTC, modern European DST and modern US DST profiles are supported. These DST rules are intended for post-2007 data. Ambiguous or nonexistent broker timestamps are rejected. The EA never infers tester time from `TimeGMT()`.

Reference-session clocks are separate: New York defaults to UTC−5 with US DST, Berlin to UTC+1 with European DST. Daily sessions are reconstructed from closed M1 bars, not broker D1 candles. Sessions must open and close within one reference calendar day; overnight sessions are not supported. Standard M15/M30 bars are used for intraday confirmation. Reference-session definitions are fixed per strategy in the simplified build.

Download enough M1 history for the fixed 90-day lookback, including both warm-up and test dates; MT5's history limit must accommodate it. A daily bar requires at least 80% of expected minute coverage and its first minute within five minutes of the planned open. Missing latest sessions block entry rather than using an older day as yesterday. Sparse-tick instruments may require an explicitly reviewed coverage setting.

Fill `InpClosedDates` with reference-session holiday dates as `YYYYMMDD|YYYYMMDD`. Fill `InpEarlyCloseDates` similarly, with `InpEarlyCloseMinute=780` for 13:00 New York, for example. **There is no embedded exchange holiday calendar.** Unlisted holidays/half-days can block subsequent signals because history looks incomplete. Gotobi additionally accepts `InpExcludedJapaneseDates`; Japanese bank holidays are excluded manually, not shifted automatically.

## Source rules versus implementation choices

### 1. EuroFX extreme reversal — eliminated; EA removed

**Eliminated on user instruction after the negative 2023–2025 baseline. The EA was removed from this branch; the baseline record is retained under `results/`. Historical description follows for provenance.**

Source: [Unger Academy, June 2026 winning strategy](https://ungeracademy.com/blog/trading-strategies-strategy-of-the-month-june-2026).

Published: fade the prior two sessions' highest high / lowest low; filter using daily Momentum and Efficiency Ratio. The source does not disclose filter direction, lookbacks, thresholds, complete exits or sessions in the public article.

**Our explicit hypothesis:** fade an inside-to-outside bid crossing of those levels when daily ER(10) ≤ 0.35 and absolute 5-session close momentum ≤ 1.5 daily ATR. Momentum is scaled by the simple mean of 14 daily true ranges. Stop is 3 daily ATR; exit at reference-session end; optional fixed-R target defaults off. All filter settings are inputs. No entry is chased if the EA starts outside the prior range. These defaults are invented research choices, not Giovanni's recovered parameters.

### 2. US-index daily IBS — eliminated; EA removed

**Eliminated and removed on user instruction after its weak observed baseline. The unresolved prolonged data/export gap is documented in `results/IBS_baseline_2023_2025.md`. Historical description follows for provenance.**

Source: [Quantified Strategies, February 2026 public rules](https://www.linkedin.com/pulse/5-mean-reversion-algorithmic-trading-strategies-beginners-q3ibf), strategy 1.

Published: buy if close < 10-session highest high − 25-session mean high–low range and IBS < 0.30. IBS = (close−low)/(high−low). Sell when close exceeds the previous session's high. The current completed session is included in the high/range windows. Zero-range bars have IBS 0.5.

**Execution difference (IBS v1.11 onward):** this EA observes the complete closing M1 bar, then waits for the first eligible tick within a scheduled broker trading session, up to `InpEntryExpiryMinutes` after the reference-session close (default 180; permitted 1–360). Quotes alone do not authorize an order. Rejected orders retain the signal and retry at most once per 60 seconds. Entry is marked processed only on successful execution; deal history prevents duplicate entry after restart/early exit. Signal expiry prevents chasing it the following morning or after a weekend. The signal is reconstructed from the latest completed reference-session bar after restart. A missing/unavailable trade schedule fails closed. The actual later fill determines SL placement, volume sizing and cash risk; there is no assumed closing-price fill. This is a delayed-entry CFD research variant, not a replica of published same-close performance. The supplied US500 specification has trading 00:00–22:59 Mon–Thu and 00:00–22:55 Fri while quote hours continue: a 23:00 broker-time close signal therefore usually waits until midnight. Weekly session metadata cannot predict holiday-specific closures; broker rejections remain authoritative. Delayed strength exits are recovered from completed sessions after the position's opening time. A 3 daily ATR stop, five-calendar-day holding cap and Friday flattening are added risk overlays; none should inherit the published return statistics.

### 3. EURJPY Gotobi

Source: [YuRa EURJPY transmission test](https://yuratrading.com/results/gotobi-eurjpy).

Published timing used here: enter 15:55 UTC on the day before the fix, exit 00:55 UTC (09:55 Japan) on dates 5/10/15/20/25/30. Weekend payment dates roll to the preceding Friday. Default hard stop 60 pips, safety target 200 pips, maximum spread 3 pips. No rollover to a nonexistent 30th day. No martingale or averaging.

Entry must occur within the configured 60-second grace window. An unavailable Sunday entry before a Monday fix is skipped, rather than replaced with a different time. Holidays are manual exclusions. Use `InpPipSize` if the symbol's pip convention differs from the default 10 points for three/five digits. Unused ATR/target inputs are hidden for this EA; only its pip stop/target settings are shown. The spread cap now comes from the common broker-point input (30 points = 3 pips on standard three-digit EURJPY). Ownership, margin and the common spread cap still apply. Paper/session-clock evidence does not imply the author's backtest or this implementation is independently audited live performance.

### 4. S&P 500 failed breakout

Source: [Unger Academy, intraday reversal system](https://ungeracademy.com/blog/s-and-p-500-strategies-intraday-reversal-multiday-pattern-with-performance).

Published: M15 close below yesterday's low followed by a close back above it for a long; reversal logic, session-end flattening, and an alternative limit-order engine selected in different phases.

**Our implementation:** only the consecutive close/reclaim engine, symmetrically applied to yesterday's high for shorts. Both bars must be completed and from the current reference session; the second bar must be immediately adjacent. Default stop 3 ATR of completed M15 bars; optional fixed-R target off. The undisclosed selector/limit-order engine is not implemented, so the published equity curve is not attributable to this EA.

### 5. DAX true-gap reversal

Source: [Unger Academy, DAX opening-gap system](https://ungeracademy.com/blog/high-volatility-on-the-dax-real-performance-of-2-strategies-gap-trend-following).

Published: opening above the previous session high sets a short bias, confirmed by breaking the previous M30 bar's low. Opening below the previous session low sets a long bias, confirmed by breaking the previous M30 bar's high. Reconstruct the old 08:00–22:00 Berlin reference session even when the feed trades longer hours.

**Our implementation choices:** allow confirmed entries during the first 180 session minutes, starting only after the first M30 bar closes; stop 3 completed-M30 ATR, optional fixed-R target off, and session-end exit. Entry requires a tick crossing, not a late catch-up entry beyond the level. These window/exit/risk rules were not disclosed by the source.

## Risk and ownership

- Default trade risk is 0.25% of current equity. Positive `InpCashRisk` overrides percent in account currency. Configure each EA independently; there is **no shared E2 portfolio risk cap**. Spread limits are broker points: default 30 for FX and 300 for indices. Review them against the actual symbol's point size and typical spread; these are not calibrated cost assumptions.
- Every market order includes an SL in the original request. Stops/targets align to tick size. Orders below broker minimum volume are skipped; sizing never rounds up to force a minimum lot. Risk uses `OrderCalcProfit`; commission, slippage and gaps can make realized loss exceed the budget.
- Default one entry per reference date uses broker deal history, surviving restart. Unique signal/fix history checks also operate when that toggle is off. One owned open position per EA/symbol; no pending orders, grids or averaging. Simultaneous duplicate instances are unsupported.
- Hedging accounts use ticket-based exits and matching magic/symbol ownership. On netting accounts entry is blocked whenever any position already exists on the symbol. Separate strategies on the same symbol should use hedging accounts; ownership cannot prevent a later external netting order from merging positions.
- Missing SL and overdue positions trigger close attempts on subsequent ticks. Default Friday flattening is 20:00 UTC and maximum holding is five calendar days. Friday flattening is fixed at 20:00 UTC in the simplified build and requires tradable ticks then. **No ticks / a closed market / a disconnected terminal means the EA cannot guarantee a timed exit.** Intraday session deadlines and Gotobi fix exits are reconstructed from the broker position timestamp after restart.
- Defaults are testing starting points, not selected allocations. Added stops, targets, time exits or Friday filters change the sourced strategy. Do not add any candidate to the active portfolio until its own cost-aware MT5/OOS and combined portfolio tests pass.

## Backtest performance (v1.12)

- The session loader reads the 90-day warm-up once, retains completed sessions and appends new completed sessions from subsequent minute data. Missing/incomplete sessions remain fail-closed and retry at the existing minute cadence; retries no longer rescan the entire warm-up. Old sessions are trimmed to the original rolling history horizon.
- Annual US/EU DST transition boundaries are cached rather than recomputed for every minute/tick conversion.
- Tester equity rows keep the same one-minute sample cadence, but use buffered writes instead of a forced disk flush on every sample. Finalization forces a flush/close. Live/demo flushing remains unchanged. Abrupt tester/process termination can leave the latest buffered rows unavailable.
- Backtest trade ledgers are rebuilt on completion/shutdown rather than after each transaction. Trade risk is still captured on each entry transaction. Live/demo ledger refresh remains unchanged. An interrupted backtest is not a finalized report.

A portable differential check compares incremental versus forced full-window session reconstruction across 155 calendar days, including year/DST changes and a missing holiday. Completed OHLC/coverage/readiness match exactly. It copies 52650 M1 rows versus 2464560 for full rebuilds (approximately 47 times fewer rows). This measures algorithmic work, not native MT5 elapsed time or a guaranteed speed multiplier. Trading inputs, entry/exit rules, risk sizing and equity sample intervals are unchanged. Native MT5 compilation, elapsed time and old/new trade-ledger equivalence still require a local tester run.

Keep real ticks for acceptance tests, disable visual mode, and allow initial tick-history downloads to finish. Do not switch to a cheaper tick model and treat the resulting fills/drawdown as equivalent merely to make a test faster.

## Verification

```sh
python research/ResearchCandidates/tests/run_checks.py
```

The portable harness compiles each complete EA through a deterministic C++ API shim, preserving production signal, clock and runtime code with syntax-only array/input adaptations. It tests DST boundaries, ambiguous clocks, Gotobi weekend dates, signal rules, min-lot risk rejection, spread gating, netting conflicts, owned exits, restart/deal-history limits and closed-session data loading. It **does not compile MQL5 or simulate real broker fills**.

MetaEditor/MT5 are not available in the development environment: native `.ex5` compilation, real-tick backtests, commission/swap validation, simultaneous-instance behavior and out-of-sample performance remain to be verified in MT5. Use “Every tick based on real ticks”, verified broker clocks and matching costs. No profit estimates or portfolio allocations have been generated for this implementation.
