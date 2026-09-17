# E2-trio — three independent strategies and trading journal

| Folder | Contents |
|---|---|
| `strategies/GoldSessionFade/` | `XAU_Session_Fade.mq5` and its implementation |
| `strategies/EMAPullback/` | `EMA_Pullback_Long.mq5`, signal engine, session clock and restart recovery |
| `strategies/CompressionBreakout/` | `Compression_Breakout_Long.mq5`, third independent strategy |
| `strategies/shared/` | Shared report-folder utilities |
| `journal/` | Local CSV trading journal |
| `tools/` | EMA run analysis |
| `tests/` | Portable regression tests |
| `docs/` | Setup, settings, export and test guides |

NR4 and its EA have been removed. The old triple-moving-average strategy is not included in this revision. Historical branches and commits are retained.

E2-trio includes Gold Session Fade, EMA Pullback and Compression Breakout as separate EAs.

## Selected defaults

| Strategy | Finalized baseline |
|---|---|
| Gold Session Fade | M5, 12:00–12:30 UTC, ATR14 × 8 stop, 1.5R target, one trade per day |
| EMA Pullback | M30, EMA20/50, ATR14 × 3 stop, 0.5R target, one trade per New York day, spread cap 10 price units |
| Compression Breakout | M30, 20-bar channel, ATR14 compression below 0.8 × 100-bar ATR average, 3 ATR stop, 2R target, daily toggle off |

All three strategies are included in this source release. EMA's daily limit was verified by the user; demo forward testing is next. Set account cash risk and verified broker-clock inputs before attachment. Existing MT5 presets override source defaults. See the [reference](docs/STRATEGY_REFERENCE.md) for the selected allocation and optional settings.

## Selected portfolio allocation

The selected risk split is **20:40:40 — Gold Session Fade / EMA Pullback / Compression Breakout**.

| Strategy | Share of risk budget | Risk per trade at 2% total | Fixed cash risk on a 100,000 account |
|---|---:|---:|---:|
| Gold Session Fade | 20% | 0.4% | 400 |
| EMA Pullback | 40% | 0.8% | 800 |
| Compression Breakout | 40% | 0.8% | 800 |
| Total nominal allocation | 100% | 2.0% | 2,000 |

These are shares of planned trade risk, not capital deposits or a daily loss limit. For another starting balance, use 0.004 / 0.008 / 0.008 times that balance. Set each EA's cash-risk input manually; source defaults and existing presets are not changed by this documentation. Fixed cash risk does not compound automatically. The three EAs do not enforce a shared portfolio loss cap.

The selection is based on the earlier portfolio simulations. Their 99th-percentile drawdown is an estimate, not a guaranteed ceiling; they exclude floating drawdown and used the earlier EMA export without the daily limit. Firm-specific loss rules and withdrawals require separate assessment.

## Install and test

Copy the **whole `strategies` folder** into `MQL5/Experts/E2/`, keeping its subfolders. Open and compile the desired `.mq5` entry in MetaEditor. Copying only an entry file will omit its dependencies. Remove obsolete source/compiled EA copies from your test installation to avoid selecting the wrong version.

Gold uses M5. EMA and compression build M30 bars from M1 history and use the same trading logic in the tester, demo and real accounts. All three accept the selected symbol; their original session rules still apply.

- [Strategy baseline and demo reference](docs/STRATEGY_REFERENCE.md)
- [Gold checks and known limitation](docs/GOLD_TESTING.md)
- [EMA setup and verification](docs/EMA_TESTING.md)
- [Compression breakout settings and testing](docs/COMPRESSION_TESTING.md)
- [CSV folder layout and migration](docs/CSV_EXPORTS.md)
- [Trading journal guide](docs/JOURNAL_GUIDE.md)

Launch the journal with `Open-E2-Journal.pyw`. The journal imports CSVs and visualizes performance; it does not place orders. Combine independent tests externally with explicit risk allocations and matching report clocks.

## Developer checks

```sh
python tests/run_compression.py
python -m unittest discover -s tests -p 'test_*.py' -v
g++ -std=c++17 -Wall -Wextra -Werror tests/ema_core.cpp -o /tmp/ema-core
/tmp/ema-core
g++ -std=c++17 tests/entry_lifecycle.cpp -o /tmp/entry-lifecycle
/tmp/entry-lifecycle
g++ -std=c++17 -Wall -Wextra -Werror tests/report_folders.cpp -o /tmp/report-folders
/tmp/report-folders
```

Additional EMA runtime checks: `python tests/run_ema_runtime.py`, `python tests/run_ema_warmup.py`, `python tests/run_ema_entry.py`.

These checks do not compile MQL5 or replace an MT5 regression backtest. Gold's previously observed holiday/weekend holds remain unresolved by this repository cleanup.
