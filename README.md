# E2 — independent strategies and trading journal

| Folder | Contents |
|---|---|
| `strategies/GoldSessionFade/` | `XAU_Session_Fade.mq5` and its implementation |
| `strategies/EMAPullback/` | `EMA_Pullback_Long.mq5`, signal engine and session clock; Strategy Tester only |
| `strategies/shared/` | Shared report-folder utilities |
| `journal/` | Local CSV trading journal |
| `tools/` | EMA run analysis |
| `tests/` | Portable regression tests |
| `docs/` | Setup, settings, export and test guides |

NR4 and its EA have been removed. The old triple-moving-average strategy is not included in this revision. Historical branches and commits are retained.

## Install and test

Copy the **whole `strategies` folder** into `MQL5/Experts/E2/`, keeping its subfolders. Open and compile the desired `.mq5` entry in MetaEditor. Copying only an entry file will omit its dependencies. Remove obsolete source/compiled EA copies from your test installation to avoid selecting the wrong version.

Gold uses M5. EMA builds M30 bars from M1 history and remains tester-only. Both accept the selected symbol; their original session rules still apply.

- [Original instruments and settings](docs/STRATEGY_REFERENCE.txt)
- [Gold checks and known limitation](docs/GOLD_TESTING.md)
- [EMA setup and verification](docs/EMA_TESTING.md)
- [CSV folder layout and migration](docs/CSV_EXPORTS.md)
- [Trading journal guide](docs/JOURNAL_GUIDE.md)

Launch the journal with `Open-E2-Journal.pyw`. The journal imports CSVs and visualizes performance; it does not place orders. Combine independent tests externally with explicit risk allocations and matching report clocks.

## Developer checks

```sh
python -m unittest discover -s tests -p 'test_*.py' -v
g++ -std=c++17 -Wall -Wextra -Werror tests/ema_core.cpp -o /tmp/ema-core
/tmp/ema-core
g++ -std=c++17 tests/entry_lifecycle.cpp -o /tmp/entry-lifecycle
/tmp/entry-lifecycle
g++ -std=c++17 -Wall -Wextra -Werror tests/report_folders.cpp -o /tmp/report-folders
/tmp/report-folders
```

These checks do not compile MQL5 or replace an MT5 regression backtest. Gold's previously observed holiday/weekend holds remain unresolved by this repository cleanup.
