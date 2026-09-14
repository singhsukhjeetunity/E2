# Separate Nasdaq research EAs

| EA | Strategy | Stop | Exit |
|---|---|---|---|
| `Nasdaq_NR4_Short.mq5` | H1 NR4 short breakout | ATR14 × 1 | Session close; no TP |
| `Nasdaq_EMA_Pullback_Long.mq5` | M30 EMA20/50 long pullback | ATR14 × 3 | 0.5R TP or session close |

These are **Strategy Tester only**. There is no combined EA or strategy-mode input.
Each executable uses the shared `NasdaqResearchEngine.mqh`, signal and clock headers.
Shared code is not a controller: each EA runs independently and exports its own ledger.

## Get and compile

From your existing Git checkout:

```powershell
git fetch origin
git switch research/nasdaq-nr4-ema
git pull --ff-only
```

1. In your laptop testing terminal, choose File → Open Data Folder.
2. Copy the whole `research/NasdaqPair` folder into `MQL5/Experts/NasdaqPair`.
3. Remove the obsolete `E2_NasdaqPair.mq5` and `E2_NasdaqPair.ex5` from that **testing folder** if present. Copying a folder does not delete old files.
4. Open each new `.mq5` file in MetaEditor and press F7. Keep the three `.mqh` files alongside them. Require zero compile errors.
5. In Strategy Tester, select one EA and your broker's Nasdaq-100 symbol, such as USTEC.
6. Use Every tick based on real ticks, no optimization, and the same dates, feed, costs, deposit and risk settings for both tests. M1 chart period is fine: the code internally rebuilds H1/M30 bars.
7. Run each EA separately and retain both tester reports and exports.

## Inputs

Set the broker's **historical** clock policy explicitly. The offset field is the winter offset in seconds for a seasonal policy. Current UTC offset alone does not establish past DST behaviour. The user's MetaQuotes-Demo historical policy remains unverified; do not assume the prior `7200/EU` selection was correct.

The indicator seed defaults to 2022-01-01. If using later history, explicitly set a seed that exists and allow at least 100 completed timeframe bars to warm up. Results using different seeds or coverage are not full-period parity tests.

Fixed cash risk defaults to 1,000 per trade. Spread cap defaults to 4 **index price units**, deviation to 0.5, entry delay to 5 seconds. The earlier supplied run used a spread cap of 10; reproduce its inputs explicitly if comparing. Existing saved `.set` files should be checked rather than loaded blindly.

## Frozen logic

NR4: the preceding H1 bar has the smallest range of the preceding four bars (ties allowed), and the newly completed bar closes below that bar's low.

EMA: current EMA20 exceeds EMA50, preceding close is at/below preceding EMA20, and newly completed close crosses above current EMA20.

Both use completed UTC-aligned bars rebuilt from observed M1. ATR uses Wilder smoothing with first-TR seed; EMA uses first-close seed. Current and preceding signal bars must be complete/contiguous. At least 95% of expected M1 bars since 09:30 New York must be observed.

Entry window: 10:00–15:29 New York, or before 12:30 on half days. Intended session exit: first tick at/after 15:55, or 12:55 on half days. Calendar coverage: 2022–2026. One position per strategy; no same-minute reentry after exit. No entry/exit thresholds changed in this split.

## Exports and combining later

Find files in the terminal's Common Files directory, under `E2/Research/Nasdaq`:
- `*_NR4_T.csv` or `*_EMA_T.csv`: that EA's trade ledger.
- Matching `*_E.csv`: sampled equity. The inactive strategy columns remain zero for schema compatibility.
- Matching `*_S.csv` and `*_settings.txt`: diagnostics and settings.

Keep original CSVs rather than Excel-rounded timestamps. Import trade ledgers into separate Backtest datasets in the journal; do not duplicate imports. To combine outside MT5, align the two equity/PnL histories to the same clock and apply explicit cash allocations. Do not add starting deposits or drawdown figures. Separate exports cannot simulate shared margin, account-wide limits or shared equity-based sizing.

`analyze_run.py` analyzes one run, not a portfolio of separate runs. It also supports old combined ledgers for comparison. Example:

```powershell
python .\research\NasdaqPair\analyze_run.py "FULL_PATH_TO_NR4_T.csv" --equity "FULL_PATH_TO_E.csv" --start 2022-07-07 --end 2026-01-01
```

Supply the actual tester interval; end is exclusive. Any combined-labelled fields from an individual run describe that run only, not both EAs.

## Known issue deliberately deferred

The previous combined test contained positions held across weekends. This split **does not fix** missed session exits, missing overdue-exit integrity flags, or the server-time timestamp used by CLOSE_PENDING diagnostics. Those need a separate investigation. A successful compilation or unit test does not validate those results or authorize deployment. The analyzer rejects weekend settlements; do not bypass that rejection to claim validation.

## Gold EA rename

At the repository root, `E2.mq5` is now `XAU_Session_Fade.mq5`, with identical source contents and the same `include` folder, inputs, magic number and report labels. Compiling creates `XAU_Session_Fade.ex5`. Existing `E2.ex5` copies on a VPS are not automatically renamed or removed. Do not attach both to the same account. This research-branch rename does not update your running main-branch installation.
