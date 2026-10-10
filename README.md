# E2 — four standalone MT5 systems

The four Expert Advisors are Gold Session Fade, Compression Breakout, EURJPY Gotobi and Nasdaq Opening Range (long). Keep the entire `strategies/` tree when installing into `MQL5/Experts/E2/`; each source entry file requires its headers. The `strategies/shared/` folder contains executable dependencies shared by Compression and reporting.

This branch additionally includes [System 6: EURUSD two-day extreme reversal](strategies/EURUSDTwoDayReversal/README.md), a standalone **research EA** with explicit assumptions for the source's undisclosed filters and exits. The four retained systems are unchanged. Published futures results have not been reproduced. See its guide for settings, installation and validation.

**Safety:** This is a research refactor branch. Do not deploy to a funded or live account until every entry compiles in MetaEditor and a trade-by-trade backtest matches the existing deployed versions at identical parameter values, tick data and broker clock settings. CSV exports remain supported without the removed E2 journal application.

Strategy Tester: Ctrl+R, select EA and broker symbol, appropriate timeframe (Gold M5, Gotobi M1, Compression M30, Nasdaq M5), Every tick based on real ticks, set risk and historically verified broker-clock inputs, then inspect Results and Journal.

For identical trading behavior, preserve all original strategy-specific execution controls. The input panels share common headings but not all risk or execution safety controls are equivalent; do not assume matching labels imply matching behavior.

## PortfolioGuard — shared account-wide daily loss limit

Source: `strategies/PortfolioGuard/E2_PortfolioGuard.mq5`. This is **one risk controller**, not a fifth trading strategy. All four trading EAs include `strategies/shared/PortfolioGate.mqh` and call `E2PGCanEnter()` immediately before submitting **entry** orders.

### Installation on one MT5 terminal/account

1. **Back up your current EX5 files and inputs**, especially on evaluation accounts. Keep all four trading EAs and their existing chart settings.
2. Copy the **entire** updated `strategies/` folder into the same terminal's `MQL5/Experts/E2/` tree. Do not install only the guard: all four trading EAs must be recompiled with the shared gate header.
3. Open MetaEditor; compile `E2_PortfolioGuard.mq5` **and all four trading EAs** with F7. Require zero native compilation errors. The GitHub C++ tests do not replace this step.
4. Attach **one** PortfolioGuard instance to any open chart in that terminal/account. All terminal account positions (including manual and copy-traded positions) are included in equity and the emergency flattening mechanism.
5. Configure `InpDailyLossMode` (percent of daily reference equity or fixed account cash), its amount, `InpCloseAllOnLimit` (true=close all positions and cancel all pending orders, false=stop only E2 entries), and the **firm's verified reset time expressed in MT5 broker-server hours and minutes**. The default midnight-server reset is only a placeholder, **not a declaration of The5ers' rule**.
6. First attach during the **first five minutes after the firm reset** to snapshot account equity automatically. If attaching for the first time later in the day, enter the **actual reference equity at today's reset** in `InpFirstDayReferenceEquity`; do not use current equity if the account has moved. Otherwise the guard remains unseeded and all four E2 EAs refuse new live/demo entries until the next reset. A verified reference can be supplied by editing guard inputs and reinitializing. On restart it recovers the previous valid day reference and latched state without rebaselining.
7. Check Experts logs and the guard chart comment for `ACTIVE`, today's reference equity, account equity and floor. With the guard active, all four EAs run their original entry/exit logic **except** that they require a recent guard heartbeat and an unbreached account-equity floor. Removing/stopping PortfolioGuard fails **closed for new E2 entries** but does not stop their exits.
8. On **each separate The5ers or copier receiving MT5 account terminal**, install its **own** guard. The shared state is stored as terminal Global Variables, account/server-scoped. Multiple terminals cannot share one guard.
9. Before production: demo-test simultaneous entries, loss cutoff including floating P&L, temporary disconnection, manual/copied positions and pending orders, order-close rejection, terminal restart, midnight rollover and the reset timezone/DST. Compare trading results with guard unlocked against your original baseline. No branch merge or production deployment before native compilation and broker-specific validation.

### Guard behavior and limits

- Reference: first verified **account equity** at each configured reset. Equity includes closed and open/floating gains and losses, commission/swap impact. Daily floor is **reference − chosen fixed cash amount** or **reference × (1 − daily loss %)**. This is an **account-equity floor**, **not** a high-watermark trailing drawdown rule, and not necessarily the firm's own formula.
- Once equity touches/breaches the floor, a **persistent daily lock** blocks all **E2-generated entries** for that day. A recovery in equity does **not** unlock the account. Automatic unlock occurs only at the next verified daily reset; broker server clock/timezone rules must match the firm.
- Optional `InpCloseAllOnLimit=true`: the guard cancels **ALL pending orders** and repeatedly attempts to close **ALL open positions** belonging to the account, **including trades from copiers or manual positions**. Rejections and closed markets are retried. This does not guarantee exact fills or prevention of prop-firm breaches when gaps, outages, copier re-entry or slippage occur.
- Without `InpCloseAllOnLimit`, it blocks **only E2-generated entries**; it cannot prevent external manual/copy-trading systems from opening new orders. A copier may reopen closed orders after flattening unless configured not to.
- The guard **does not reserve or cap aggregate stop-loss exposure at entry**. Several EAs can open positions together while equity is above the floor and later collectively lose more than the limit before forced closes execute. This is intentionally the simpler daily-equity guard, not a pre-trade capital/risk allocation controller.
- The guard's 1-second terminal timer is best effort. The terminal must be running and connected for monitoring and forced closes; a broker-side SL remains each strategy's critical protection.
- In the ordinary single-EA **Strategy Tester**, E2 trading entries bypass the shared guard by design, so historical standalone strategy tests remain comparable. **This does not test portfolio-wide limit behavior**; run the guard and all four EAs together in a multi-chart demo terminal for integration verification.
- Changing reset parameters mid-day or deleting terminal global variables may invalidate the daily reference. **Never reset the daily lock manually to continue trading.**

### Safety reminder

A firm can calculate daily drawdown differently (prior-day balance vs equity, timezone/DST, commissions, intraday high watermark, positions held over reset). Verify the **exact account's** firm program and use a conservative internal cutoff. PortfolioGuard is **not** broker-side or guaranteed protection.
