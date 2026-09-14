# E2 — independent strategies and trading journal

| Entry file | Purpose |
|---|---|
| `XAU_Session_Fade.mq5` | Existing gold session-fade EA; filename changed only |
| `research/NasdaqPair/Nasdaq_NR4_Short.mq5` | Standalone NR4 research EA; tester only |
| `research/NasdaqPair/Nasdaq_EMA_Pullback_Long.mq5` | Standalone EMA pullback research EA; tester only |

The Nasdaq EAs share utility code but execute separately. No combined EA or external controller is included. Combine exports outside MT5 when evaluating the portfolio.

- [Nasdaq setup, exports and known limitations](research/NasdaqPair/TESTING.md)
- [Gold regression checks](TESTING.md)
- [Trading journal guide](JOURNAL_GUIDE.md)

The journal imports CSVs and visualizes performance; it does not place orders. Main and your running VPS installation are not changed by this research branch. Nasdaq session-exit defects remain under investigation; these research EAs are not deployment-ready.

Developer checks:

```text
python -m unittest discover -s tests -p "test_journal.py" -v
python -m unittest discover -s research/NasdaqPair/tests -p "test_*.py" -v
```

All three strategies accept the selected symbol. See [STRATEGY_REFERENCE.txt](STRATEGY_REFERENCE.txt) for original markets, baseline settings, units and remaining test requirements.
