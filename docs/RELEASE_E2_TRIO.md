# E2-trio

Three independent MetaTrader 5 EAs:

- Gold Session Fade: XAUUSD reference, M5, fixed UTC range, ATR14 x 8 stop, 1.5R target, one trade per day.
- EMA Pullback: USTEC reference, internal M30, EMA20/50, ATR14 x 3 stop, 0.5R target, one trade per New York day.
- Compression Breakout: USDJPY reference, internal M30, 20-bar breakout after ATR compression, ATR14 x 3 stop, 2R target. One-trade-per-UTC-day toggle included and off by default. Exits at the earlier of eight hours, 16:45 New York or the broker-session safeguard.

Strategy settings are unchanged by this release. Copy the entire strategies directory into MQL5/Experts/E2 and compile the desired entry files in MetaEditor. This is a source release; compiled EX5 files are not included. Configure cash risk and verified broker-clock settings for each installation. Saved MT5 presets override source defaults.

Portable strategy, execution, recovery, clock and journal checks run before publication. These checks do not replace MetaEditor compilation or broker-specific testing. Demo forward testing remains the next operating stage.

Known limitations: gold holiday/weekend holds remain documented; earlier portfolio Monte Carlo excludes floating drawdown and uses the earlier EMA export without the daily limit. EMA's exchange calendar covers 2022-2026. The EAs do not enforce a shared portfolio loss limit.
