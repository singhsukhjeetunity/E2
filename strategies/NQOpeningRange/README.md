# System 5: NQ opening range

Copy the complete `strategies` tree into `MQL5/Experts/E2/` and compile `NQ_Opening_Range.mq5` in MetaEditor. The EA remains a research system; its entry switch defaults to off.

Set the risk mode and amount, maximum spread in Nasdaq index price units, and a historically verified broker clock profile. Set **Broker clock verified** only after confirming winter and summer offsets and DST rules against the broker's M5 history. Then enable entries for a tester run.

The published strategy rules are fixed in source: 09:30–11:00 New York opening range, 15:25 last entry, 15:30 short exit, 100 index point stop, 200 index point target, two entries per New York day, and five sessions maximum for longs. Changing risk or spread inputs does not change these rules.

With CSV export enabled, each run writes `Trades_T.csv`, `Signals_S.csv`, `Equity_E.csv`, and `Settings.txt` under the terminal's Common Files `E2/NQOpeningRange` folder. Filenames include symbol, tester/demo/live mode, account, and a unique run ID. Trades use actual broker deal prices and volumes; net profit includes gross profit, commission, swap, and fees. Initial cash risk uses each entry fill and its submitted stop through `OrderCalcProfit`. A missing historical stop or unavailable risk calculation leaves risk blank and sets an integrity flag. Open trades have no final P&L and are skipped by the journal. Live reports cover trades entered during that EA run; attach before the intended reporting period. `Equity_E.csv` is the strategy's run cash change, including floating P&L, with R blank when concurrent fills make a single denominator ambiguous.

Import the `Trades_T.csv` file into the E2 journal. For a Backtest account, keep runs separate because the journal uses the run ID to distinguish reused tester position IDs. Native Strategy Tester validation is still required for broker-specific fills, history availability, DST boundaries, and exit behavior.
