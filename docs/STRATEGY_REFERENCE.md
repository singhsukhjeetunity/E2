# E2 · Strategy baseline

**Gold Session Fade + EMA Pullback + Compression Breakout**  
Release: **E2-trio**

> **Status: strategy selection complete; defaults finalized.**
>
> Gold retains the fixed-UTC baseline. Sukh verified the EMA one-trade-per-day option and selected it as the default. Demo forward testing remains the next operating stage.

## At a glance

| | Gold Session Fade | EMA Pullback | Compression Breakout |
|---|---|---|---|
| Reference market | XAUUSD | Nasdaq-100 CFD: USTEC | USDJPY |
| Timeframe | M5 required | Internal M30 from completed M1 bars | Internal M30 from completed M1 bars |
| Signal | Failed breakdown of the fixed UTC session range | EMA20/50 trend and EMA20 pullback recovery | 20-bar high breakout after ATR compression |
| Stop | 8 × ATR14 | 3 × ATR14 | 3 × ATR14 |
| Profit target | 1.5R | 0.5R | 2R |
| One trade per day | On | On, New York date | Off; optional UTC-date toggle |
| Risk-budget share | 20% | 40% | 40% |
| EA | [XAU_Session_Fade.mq5](../strategies/GoldSessionFade/XAU_Session_Fade.mq5) | [EMA_Pullback_Long.mq5](../strategies/EMAPullback/EMA_Pullback_Long.mq5) | [Compression_Breakout_Long.mq5](../strategies/CompressionBreakout/Compression_Breakout_Long.mq5) |

**Decision:** retain EMA20/50, the 3.0 ATR stop, the 0.5R target and the existing session exit, with one trade per New York day enabled. The 1.25R target and alternative EMA/stop settings were research comparisons; they are not the retained baseline. Gold settings are unchanged.

All three EAs use the selected chart/tester symbol. Changing the symbol does not change the strategy's session rules or establish that the strategy works on that market.

## EMA Pullback · retained settings

| Setting | Baseline | MT5 input |
|---|---|---|
| Fast EMA | **20** | `InpEMAFast` |
| Slow EMA | **50** | `InpEMASlow` |
| ATR period | **14** | `InpATRLength` |
| Stop distance | **3.0 × ATR** | `InpEMAStopATR` |
| Target | **0.5R** | `InpEMATargetR` |
| One trade per New York day | **On**, verified by Sukh; can be disabled | `InpOneTradePerDay` |
| Maximum entry delay | 5 seconds | `InpMaxEntryDelaySeconds` |
| Broker-close buffer | 5 minutes | `InpBrokerCloseBufferMinutes` |
| Maximum deviation | 0.5 price units | `InpMaxDeviationPriceUnits` |
| USTEC research spread cap | **10 price units** | `InpMaxSpreadPriceUnits` |
| Cash risk | Set for the demo account; code default is 1,000 account-currency units | `InpEMACashRisk` |
| Magic number | 2026091402; use a distinct number per separate instance | `InpEMAMagic` |
| CSV export | Enabled | `InpExportCsv` |

Spread and deviation are **raw price units**, not pips. For example, a cap of 4 on EURUSD does not mean four pips. The spread cap of 10 was explicitly supplied for a recent USTEC research run; save each run's settings to verify comparability. The compiled EMA spread cap is now 10; saved MT5 presets can override defaults.

### Entry and exit rules

Long only. On completed M30 candles:

1. EMA20 is above EMA50.
2. The previous candle closed at or below its EMA20.
3. The signal candle closes above its EMA20.
4. Enter on the first eligible tick of the next M30 bar, within the entry-delay limit and subject to the session/execution checks.

The strategy allows one active or pending trade for its instance. With `InpOneTradePerDay=true`, any filled entry on the same New York date blocks further entries for that symbol and magic, even after closure or an EA restart. Partial fills count as one trade; exits and rejected orders do not consume the allowance. Unavailable history blocks entry until it can be checked. Sukh verified the enabled option. Earlier reported Monte Carlo results used the older exports and have not been recalculated here. Stop and target distances are based on the actual fill. An open trade exits at SL, TP or the applicable session deadline.

| Session rule | Normal US trading day | US half-day |
|---|---|---|
| Entry window, New York time | 10:00 to **before 15:30** | 10:00 to **before 12:30** |
| Scheduled exit, New York time | **15:55** | **12:55** |
| Earlier broker closure | Use broker session end minus 5 minutes if earlier | Same rule |

The cash-session exit is retained. It does not imply that the broker's CFD stops trading at the US cash close. Entries are blocked after the applicable cutoff. Failed closes are retried; an exit more than 60 seconds overdue invalidates the run and stops new entries.

### Clock and history

- Verify `InpBrokerClock` and `InpBrokerWinterUtcOffsetSeconds` against the demo broker. There is no universal server-time offset.
- The supplied research settings used EU seasonal time (`3`) and a winter offset of `7200` seconds (UTC+2). These are research-feed settings, not automatic settings for another broker.
- EMA reports use UTC. The US session/calendar applies on every selected instrument.
- Automatic warm-up requires **31,440 completed M1 bars** at this baseline. There is no indicator-seed input. `WARMUP_WAIT` means more history is needed; `WARMUP_READY` confirms processing is complete. The signal already present at attachment is skipped.
- The implemented exchange calendar covers **2022–2026**. Extend and verify it before testing or operating in 2027.

Tester, demo and real accounts use the same EMA trading rules. Different broker feeds, costs and contract specifications can still change the results.

## Gold Session Fade · unchanged reference

| Setting | Baseline |
|---|---|
| Instrument / timeframe | XAUUSD / M5 |
| Reference range | 12:00–12:30 UTC |
| ATR / stop / target | ATR14 / 8 × ATR / 1.5R |
| Regime lookback / minimum efficiency | 36 bars / 0.30 |
| One trade per day | Enabled |
| Friday entry block | From 20:00 strategy time |
| Weekend flat | Enabled, 30 minutes before broker session close |
| Default risk | Fixed cash: 1,000 account-currency units; optional balance risk: 1% |
| Default spread / deviation | 40 pips / 2 pips |
| Magic number | 2026001 |
| Reports | Enable CSV export |

Gold's pip convention is 10 quote points for 3/5-digit symbols, otherwise one quote point. Verify its broker-time profile or manual UTC offset; the existing server-time mode is also available.

**Known limitation:** five holiday/weekend-held gold trades remain in the earlier portfolio research. Their exit handling is not resolved by selecting this baseline. See [Gold testing notes](GOLD_TESTING.md).

### Optional New York session clock

`InpXauTimeBasis` now offers `E2_XAU_TIME_NEW_YORK` alongside the existing UTC and server modes. UTC remains the default. In New York mode the **range hours, Friday entry cutoff and strategy day** all use New York local time, adjusting for US daylight saving. Broker timestamps are still converted using the verified broker-time adapter first; this option does not correct an incorrect broker offset.

| Input | Retained fixed-UTC baseline | New York timing experiment |
|---|---|---|
| `InpXauTimeBasis` | `E2_XAU_TIME_UTC` | `E2_XAU_TIME_NEW_YORK` |
| `InpXauRangeStartHour` / minute | 12 / 0 | **8 / 0** |
| `InpXauRangeEndHour` / minute | 12 / 30 | **8 / 30** |
| UTC range produced | 12:00–12:30 all year | 13:00–13:30 winter; 12:00–12:30 summer |

Switching the mode does **not** rewrite the numeric hour inputs: leaving 12 selected means noon New York time. The Friday block hour also needs an explicit choice: 16 New York corresponds to 20 UTC in summer and 21 UTC in winter; leaving 20 means 20:00 New York. Use `-1` only if deliberately disabling that entry cutoff. Weekend-flat still follows the broker session schedule.

Select the clock/settings before a fresh backtest or while flat, with no unresolved recovery state. The configuration hash distinguishes time modes. Rule dates and range timestamps in exports use the selected clock; fill/exit timestamps retain their existing broker-time convention. The run configuration log identifies `TIME_BASIS=NEW_YORK`.

This is an optional experiment, not a replacement baseline. Keep all other inputs and data fixed, and record any Friday-cutoff change separately when comparing results.

## Compression Breakout · retained settings

The new independent EA is `strategies/CompressionBreakout/Compression_Breakout_Long.mq5`. Original symbol: USDJPY. M30, long only, 20-bar channel, ATR14 compression below 0.8 of its previous 100-value mean, 3 ATR stop, 2R target. Entries 06:00–20:00 UTC weekdays; exit after eight hours or 16:45 New York, whichever comes first, with an earlier broker-session safeguard.

`InpOneTradePerDay` defaults to **false** to preserve the research screen; enable it for one filled entry per UTC date. Cash risk defaults to 1000 account-currency units and magic to 2026091703. Use the [selected portfolio allocation](#selected-portfolio-allocation) below. See [the full setup and test guide](COMPRESSION_TESTING.md).

| Setting | Baseline |
|---|---|
| Channel / compression history | 20 bars / 100 prior ATR values |
| Compression threshold | Previous ATR < 0.8 × previous 100-value ATR mean |
| ATR / stop / target | ATR14 / 3 × ATR / 2R |
| Entry window | 06:00 inclusive to 20:00 exclusive UTC, weekdays |
| Time exit | Earlier of eight hours and 16:45 New York; earlier broker-session safeguard |
| One trade per UTC day | Off |
| USDJPY spread / deviation | 0.03 / 0.005 raw price units |
| Entry delay / broker-close buffer | 5 seconds / 5 minutes |
| Automatic warm-up | 18,000 completed M1 bars at baseline |
| Reports | UTC timestamps; verify historical broker offset independently |

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

The earlier 35:65 Gold/EMA allocation and 1.226% two-strategy sizing are superseded historical comparisons, not the E2-trio operating allocation.

## Demo forward test

1. Compile the current EAs and use the retained strategy settings above. Verify the broker clock, trading sessions, spread units and chosen demo cash risk.
2. Record the starting balance, EA build, settings and start date. Save each EMA and compression run's `_Settings.txt` alongside its exports.
3. Let the strategies run without retuning. Review warm-up, entry timing, SL/TP placement, session exits and restart recovery.
4. Collect trades, signals and available equity exports. Review floating drawdown and gold holiday/weekend behavior before finalizing the portfolio.

All three strategies have **one simple folder each**, relative to MT5 Common Files:

| Strategy | Report folder |
|---|---|
| Gold | `E2/GoldSessionFade/` |
| EMA | `E2/EMAPullback/` |
| Compression | `E2/CompressionBreakout/` |

Use matching time zones and explicit risk allocations when combining exports. Distinct magic numbers identify independent instances; they do not remove same-symbol netting conflicts.

---

[EMA setup and recovery](EMA_TESTING.md) · [Gold checks](GOLD_TESTING.md) · [Compression setup](COMPRESSION_TESTING.md) · [CSV guide](CSV_EXPORTS.md) · [Trading journal](JOURNAL_GUIDE.md)

