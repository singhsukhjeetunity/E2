# Nasdaq pair — research only

Separate EA: `research/NasdaqPair/E2_NasdaqPair.mq5`. Production E2 is unchanged.
This EA refuses attachment to live **and demo** charts. Use MT5 Strategy Tester.

## Implemented rules

| | NR4 | EMA pullback |
|---|---|---|
| Direction / timeframe | Short / H1 | Long / M30 |
| Signal at completed bar | Previous range is the smallest of the preceding 4 ranges, allowing ties; current close below previous low | EMA20 > EMA50; previous close <= previous EMA20 and current close > current EMA20 |
| Stop | ATR14 x 1 | ATR14 x 3 |
| Target | None, intentionally | 0.5R |
| Session exit | First tick at/after 15:55 New York | Same, if SL/TP has not closed it |
| Half-day exit | 12:55 New York | Same |

Both use next-bar market execution, 10:00–15:29 New York entry window (half days before 12:30).
All timeframe bars are rebuilt from M1 on UTC boundaries. Indicators run across observed bars,
including overnight. ATR uses Wilder alpha 1/14 with first-TR seed; EMA uses first-close seed.
At least 100 bars are required; the signal bar and prior bar must be complete and contiguous.
At least 95% of expected M1 bars since 09:30 must be observed. No missing prices are synthesized.
An eligible signal expires after 5 seconds; no same-minute reentry after an exit.

One position per strategy. BOTH permits independent simultaneous positions and therefore
requires a hedging tester account. It does not implement the old E2 global-position constraint.

## Get and compile

From your existing E2 Git checkout:

```powershell
git fetch origin
git switch --track origin/research/nasdaq-nr4-ema
```

If the branch is already local, use `git switch research/nasdaq-nr4-ema`, then
`git pull --ff-only`. If Git reports local changes, preserve them before switching.

1. In the **laptop testing terminal**, choose File → Open Data Folder.
2. Copy the entire `research/NasdaqPair` folder into `MQL5/Experts/NasdaqPair`.
   Keep its two .mqh files beside the .mq5 file. Do not replace your live E2.
3. Open `E2_NasdaqPair.mq5` in MetaEditor and press F7. It must compile with zero errors.
4. Open MT5 Strategy Tester (Ctrl+R), select this EA and your broker's Nasdaq-100 symbol
   (often NAS100, USTEC or US100; names differ). Do not select gold.
5. Select **Every tick based on real ticks**, no optimization. The chart period may be M1;
   the EA internally constructs its own H1/M30 bars.
6. Test 2022-01-01 through 2025-12-31. Use the same deposit, leverage, costs and feed for all runs.
   A 100,000 test deposit and 1,000 fixed cash risk per strategy are convenient research units,
   not a live risk recommendation. Ensure margin is sufficient.

## Required inputs

- `InpBrokerClock`: explicit historical time policy. UNSET deliberately fails initialization.
- `InpBrokerWinterUtcOffsetSeconds`: **winter** offset in seconds. For a documented
  UTC+2 winter / UTC+3 summer broker, enter 7200 and its actual US or EU DST policy.
  Do not infer the historical policy from today's offset alone.
- `NP_FIXED_UTC_OFFSET`: only for a truly fixed-offset feed. HistData raw timestamps use
  fixed UTC-5; that does **not** imply an MT5 broker uses UTC-5.
- `InpIndicatorSeedUtc`: 2022-01-01 by default. Load the full M1 history from this seed.
  If MT5 only provides later history, the EA fails instead of silently claiming comparable results.
- `InpMode`: NR4_ONLY, EMA_ONLY, then BOTH. BOTH needs a hedging account.
- Risk, spread cap and deviation are editable. Spread/deviation inputs are **index price units**:
  4 means four index points, regardless of the symbol's decimal digits.

Keep frozen strategy defaults for the first comparison. Save settings and the tester report.
The implementation uses broker bid/ask ticks, commissions and contract sizes, so it is not a
guarantee of identical trades or results to the earlier HistData M1 study.

## Review and upload

Run NR4_ONLY, EMA_ONLY and BOTH. The first two isolate implementation issues; use the BOTH
run for actual combined performance. Compare matching strategy fills across all three.
Differences caused by shared margin must be investigated, not hidden.

Look for `[NP][FAILED]`, unconfirmed entries, protection failures, missing history and rejected orders.
NR4 intentionally has SL but **no TP**. EMA must have both; provisional protection is placed with
the entry request and verified against the authoritative fill. A protection failure stops new entries.
An unfinished position forcibly closed at test end is flagged and excluded from valid reporting.

CSV location:
MT5 File → Open Common Data Folder → Files → E2 → Research → Nasdaq.
If that menu is absent, the usual path is
`%APPDATA%/MetaQuotes/Terminal/Common/Files/E2/Research/Nasdaq`.

Upload the matching:
- `*_ALL_T.csv`: combined ledger; separate NR4/EMA copies are also exported.
- `*_E.csv`: approximately minute-sampled equity, including open PnL.
- `*_S.csv` and `*_settings.txt`: diagnostics and configuration.
- MT5 tester report: actual test interval, deposit, commission and modeling information.

Optional local analysis (Python 3.10+):

```powershell
python .\research\NasdaqPair\analyze_pair.py "FULL_PATH_TO_ALL_T.csv" --equity "FULL_PATH_TO_E.csv" --start 2022-01-01 --end 2026-01-01
```

Use the actual tested start and **exclusive** end date. Do not use first/last trade dates.
The JSON report shows yearly and median annual R, win rate, expectancy, losing streak,
closed-equity drawdown, sampled floating drawdown, correlation and overlap.
Closed drawdown aggregates simultaneous settlements. Mixed-result millisecond ties are flagged:
their exact trade-by-trade losing streak can depend on the tie order. Floating drawdown sampled
once per minute can miss intraminute extremes; the Experts log also records tick-observed cash DD.
R is normalized by each trade's actual initial cash risk; it is not account-percent return.

Only the `*_T.csv` files use the journal ledger schema. Do not import both ALL and individual
copies of the same trades. The S/E files are research diagnostics, not journal trade imports.

## Validation status and limits

Shared signal/calendar logic and Python reporting have automated tests in GitHub Actions.
These do **not** compile MQL5 or test broker execution. Check Actions for the current commit's result.
MetaEditor compilation and MT5 execution remain necessary before interpreting any backtest.

The earlier research search examined many variants; 2025 has already been inspected.
Neither 2025 nor these implementations are fresh out-of-sample validation. No robustness or
combined-drawdown result is invented from the old summary totals. Reproduce first; then assess
cost sensitivity and genuinely untouched data. This branch is not a production release.

Calendar: published US cash-market closures and half days, 2022–2026 only, including
the 2025-01-09 closure. Future years are rejected until their calendar is explicitly added.
Sources: [NYSE hours/calendar](https://www.nyse.com/trade/hours-calendars),
[2022–2024 calendar](https://ir.theice.com/press/news-details/2021/NYSE-Group-Announces-2022-2023-and-2024-Holiday-and-Early-Closings-Calendar/default.aspx),
[2023–2025 calendar](https://ir.theice.com/press/news-details/2022/NYSE-Group-Announces-2023-2024-and-2025-Holiday-and-Early-Closings-Calendar/default.aspx),
[Nasdaq special closure](https://www.nasdaqtrader.com/TraderNews.aspx?id=ETA2024-87).
Order lifecycle follows [MQL5 OrderSend](https://www.mql5.com/en/docs/trading/ordersend):
a successful submission alone is not authoritative fill confirmation.
