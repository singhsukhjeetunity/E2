# E2 — standalone EA + trading journal

The **EA trades independently in MT5**. The **journal imports CSVs and explains results**.

This branch, `feature/standalone-journal`, starts from the standalone `main` EA. It contains no external controller, synthetic strategies, broker runner, approval system or MT5 Python dependency. The old controller branch is retained separately as history; do not launch its services alongside this journal.

## Start here

Read [JOURNAL_GUIDE.md](JOURNAL_GUIDE.md). The dashboard keeps the dark E2 design and includes:

- Account and strategy performance, yearly/monthly results, closed-trade P&L curves and drawdown.
- Editable grade allocations, risk references and strategy notes (planning only).
- Automatic E2 CSV recognition, preview, duplicate protection and conflict blocking.
- Optional account-specific folder reading; no order or terminal access.
- Manual closed trades, payouts, fees, balance transfers, backup and restore.

**Your existing EA does not need to be replaced to use the journal.** Its current CSV reports already work. This branch does not modify the EA or its trading rules. The separately published SL/TP repair on `main` still needs MT5 compilation and broker acceptance testing; see [TESTING.md](TESTING.md).

## Developer checks

Python 3.10+ standard library only. No pip packages are needed to run from source.

```text
python -m unittest discover -s tests -p "test_journal.py" -v
node --check journal/app.js
python -m journal.app --no-browser
```

The Windows workflow packages a double-click executable and tests the packaged application with a temporary journal. Windows binaries are published only if the checks pass. User data and uploaded CSVs are never committed to Git.
