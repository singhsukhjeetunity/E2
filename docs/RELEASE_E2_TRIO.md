# E2-trio

Three independent MetaTrader 5 EAs:

- Gold Session Fade: XAUUSD reference, M5, fixed UTC range, ATR14 x 8 stop, 1.5R target, one trade per day.
- EMA Pullback: USTEC reference, internal M30, EMA20/50, ATR14 x 3 stop, 0.5R target, one trade per New York day.
- Compression Breakout: USDJPY reference, internal M30, 20-bar breakout after ATR compression, ATR14 x 3 stop, 2R target. One-trade-per-UTC-day toggle included and off by default. Exits at the earlier of eight hours, 16:45 New York or the broker-session safeguard.

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

This documentation refresh completes the three-strategy reference, setup and CSV guides. EA source, input defaults, tests, journal application and workflows are unchanged.

Strategy settings are unchanged by this release. Copy the entire strategies directory into MQL5/Experts/E2 and compile the desired entry files in MetaEditor. This is a source release; compiled EX5 files are not included. Configure cash risk and verified broker-clock settings for each installation. Saved MT5 presets override source defaults.

Portable strategy, execution, recovery, clock and journal checks run before publication. These checks do not replace MetaEditor compilation or broker-specific testing. Demo forward testing remains the next operating stage.

Known limitations: gold holiday/weekend holds remain documented; earlier portfolio Monte Carlo excludes floating drawdown and uses the earlier EMA export without the daily limit. EMA's exchange calendar covers 2022-2026. The EAs do not enforce a shared portfolio loss limit.
