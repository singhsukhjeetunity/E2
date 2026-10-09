# System 6 — Bund Donchian breakout (research only)

**This is a new, explicitly defined research candidate, NOT a replication of a proprietary published backtest.** Do not infer the published Bund strategy's returns from this implementation. No historical performance is claimed. Not approved for funded or evaluation accounts.

## Exact baseline

- Symbol: **FGBL / Euro-Bund futures** if available, or a broker's Bund CFD with a verified equivalent quote. Different brokers may offer very different contract multipliers, spreads, swap/financing and trading hours.
- Timeframe: **H1**, evaluated on the first tick of a new H1 bar using the previous fully completed bar.
- Long: previous H1 candle **closes strictly above the maximum high of the 20 H1 bars preceding it**.
- Short: previous H1 candle **closes strictly below the minimum low of the 20 H1 bars preceding it**.
- Stop: **2.0 × ATR(14)** on completed H1 bars, measured from actual order entry quote and submitted with the order. No fixed profit target.
- Exit: on a completed H1 close below the preceding **10-bar low** (long) or above preceding **10-bar high** (short), or via the protective stop. The EA does **not** reverse immediately on the exit bar.
- One position per symbol; no entry when *any* symbol position or pending order exists, even if placed by another EA. No portfolio-wide daily drawdown guard.
- No trade on a symbol whose minimum tradable volume exceeds the chosen cash-risk budget; margin buffer 15%. Entry spread filter defaults to **0.10 price units** (verify quote conventions before testing).
- The entry switch defaults **off**. Clock verification is required for entry; winter/summer offset hours and broker DST control CSV UTC timestamps, **not the trading signals**.
- For now, the EA only operates on ticks. Broker SL persists on the broker, but opposite-channel exits require the terminal to be running and receiving ticks. No futures rollover automation, expiry management, exchange holiday handling, exchange-level execution/slippage simulator, or restart-recovery journal is implemented.

## How to backtest in MT5

1. Copy the **entire** `strategies` directory to `MQL5/Experts/E2/`. Open `strategies/BundDonchian/Bund_Donchian_Breakout.mq5` in MetaEditor and compile with **F7**. Resolve any native MQL5 compiler errors before testing. No EX5 binary is supplied.
2. Open **Strategy Tester (Ctrl+R)**, select `Bund_Donchian_Breakout`, broker's **FGBL/Euro-Bund** symbol, **H1**, **Every tick based on real ticks**, and a historical period with reliable contract-roll and tick data. Use 2016–2025 for initial in-sample evaluation, then keep 2026 untouched.
3. Set **InpBrokerClockVerified=true** only after verifying your broker's historical UTC winter/summer offsets and DST. Example: EU winter +2/summer +3 means winter 2, summer 3, DST 1. These values are NOT universal.
4. Set **InpEnableEntries=true** for Strategy Tester, **InpRiskMode=0**, **InpFixedCashRisk=1000** on a $100,000 test account. Keep baseline channels 20/10, ATR14, stop 2 ATR, and spread cap only if it matches the actual Bund quote. For CFDs, check margin and contract sizing with `OrderCalcProfit` output.
5. Run with **optimization disabled**. Inspect the **Journal**, **Results**, and **Graph**. Verify completed-H1 entry timing, stop distances, trade sizes, channel exits, no double entry on a bar, and that positions survive weekends only if the broker permits it.
6. CSV exports appear in terminal **Common Files/E2/BundDonchian/**: `_Trades_T.csv`, `_Signals_S.csv`, `_Equity_E.csv`, `_Settings.txt`. The trade CSV includes actual deal-level P&L, commission, swap, fee, volume and risk when available. This CSV export is **independent of the deleted E2 journal application**.
7. Send the tester report, the trade CSV, and the symbol specification (tick size, tick value, contract size). Evaluate annual R, expectancy, win rate, Monte Carlo 99th-percentile DD and correlation with the four current portfolio systems **before** considering allocation.

## Critical limitations

- **No backtest has been executed or validated in this GitHub change.** Native MetaEditor compilation and real-tick strategy testing are still required.
- The original published Bund Donchian report did not expose all precise entry/exit rules. This 20/10 H1, 2-ATR design is an **independent hypothesis** and its edge is unknown.
- Continuous futures contract rolls, holidays, DST, data completeness, spread and swap/commission assumptions can materially affect outcomes.
- Entries are market orders at the next tick after the H1 close, not assumed fills at a breakout boundary.
- Initial stop and exit logic are independent of the E2 journal application; removing the journal does not remove trade CSV export.
