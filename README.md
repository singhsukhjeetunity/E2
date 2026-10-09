# E2 — four standalone MT5 systems

The four Expert Advisors are Gold Session Fade, Compression Breakout, EURJPY Gotobi and Nasdaq Opening Range (long). Keep the entire `strategies/` tree when installing into `MQL5/Experts/E2/`; each source entry file requires its headers. The `strategies/shared/` folder contains executable dependencies shared by Compression and reporting.

**Safety:** This is a research refactor branch. Do not deploy to a funded or live account until every entry compiles in MetaEditor and a trade-by-trade backtest matches the existing deployed versions at identical parameter values, tick data and broker clock settings. CSV exports remain supported without the removed E2 journal application.

Strategy Tester: Ctrl+R, select EA and broker symbol, appropriate timeframe (Gold M5, Gotobi M1, Compression M30, Nasdaq M5), Every tick based on real ticks, set risk and historically verified broker-clock inputs, then inspect Results and Journal.

For identical trading behavior, preserve all original strategy-specific execution controls. The input panels share common headings but not all risk or execution safety controls are equivalent; do not assume matching labels imply matching behavior.
