# System 5: NQ opening range

Copy the complete `strategies` tree into `MQL5/Experts/E2/` and compile `NQ_Opening_Range.mq5` in MetaEditor. The EA remains a research system; its entry switch defaults to off.

Set the risk mode and amount, maximum spread in Nasdaq index price units, and a historically verified broker clock profile. Set **Broker clock verified** only after confirming winter and summer offsets and DST rules against the broker's M5 history. Then enable entries for a tester run.

This research variant opens **longs only** when the ask breaks above the 09:30–11:00 New York opening range. It makes no new short entries. The 15:25 last-entry time, 100 index point stop, 200 index point target, two entries per New York day, and five-session maximum long hold remain fixed in source. The EA still knows how to close a short left by an older build; a sell order used to close a long is not a new short entry. Changing risk or spread inputs does not change these rules.

The **Opening range filters** dashboard group has two controls, both enabled by default:

- **Range width filter:** opening-range high minus low must be between 0.25 and 1.50 times the average true range of the previous 14 completed broker D1 bars. The minimum and maximum ratios are editable; the 14-day period is fixed. The EA blocks entries if the required D1 history is unavailable. These bounds are starting research values, not optimized settings.
- **Completed M5 breakout:** the previous fully closed M5 bar, from the same New York day and after 11:00, must close strictly above the range high. The current ask must also remain above the high. A breakout cannot enter before the 11:00–11:05 bar closes.

The Signals report records each day's range-width decision and once-per-bar unconfirmed breakouts. Turn each filter off separately for controlled comparison runs. Changing either filter or its thresholds changes the configuration hash.

With CSV export enabled, each run writes `Trades_T.csv`, `Signals_S.csv`, `Equity_E.csv`, and `Settings.txt` under the terminal's Common Files `E2/NQOpeningRange` folder. Filenames include symbol, tester/demo/live mode, account, and a unique run ID. Trades use actual broker deal prices and volumes; net profit includes gross profit, commission, swap, and fees. Initial cash risk uses each entry fill and its submitted stop through `OrderCalcProfit`. A missing historical stop or unavailable risk calculation leaves risk blank and sets an integrity flag. Open trades have no final P&L and are skipped by the journal. Live reports cover trades entered during that EA run; attach before the intended reporting period. `Equity_E.csv` is the strategy's run cash change, including floating P&L, with R blank when concurrent fills make a single denominator ambiguous.

Import the `Trades_T.csv` file into the E2 journal. For a Backtest account, keep runs separate because the journal uses the run ID to distinguish reused tester position IDs. Native Strategy Tester validation is still required for broker-specific fills, history availability, DST boundaries, and exit behavior.

This filtered configuration has a new config hash. Earlier reports remain separate research results; rerun the tester to measure this version. The long-only and filter ideas came from reviewing earlier samples, so those samples are not independent validation of the changes.
