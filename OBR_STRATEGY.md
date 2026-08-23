# E2 OBR Canonical Strategy Specification

Status: Sprint 3 end-to-end lock. Sprint 2 candidate semantics are unchanged; planning, execution, recovery and fixed trade management are implemented.

Version 1.1.0 adds one candidate-layer eligibility rule: five Monday–Friday inputs, all enabled by default, select the authoritative Europe/London weekday. OR construction, freezing and daily state continue on disabled days; an otherwise-valid signal is recorded as `DISABLED_WEEKDAY` before candidate construction and does not consume the day.

## Sprint 2 decisions locked

- Decision timeframe: M15.
- Trading day and opening-range clock: Europe/London civil time with statutory GMT/BST transitions.
- Opening range: exactly the completed 08:00, 08:15, 08:30 and 08:45 London M15 bars; 09:00 is first eligible breakout bar.
- Eligibility continues through the London calendar day with no intraday cutoff.
- ADX(14), ATR(14), range qualification and gap qualification are evaluated anew on each completed breakout-eligible bar, including that bar.
- Failed ADX, range-size or breakout-gap checks do not consume the day. Multiple unique candidates are permitted; only a future successful trade consumes the day.
- Baseline news filtering is disabled for OBR candidates. Spread is an execution-only check.
- Structural stop: long `OR Low - 0.10 * frozen breakout ATR`; short `OR High + 0.10 * frozen breakout ATR`. Planning preserves this separately from the broker-valid submitted SL.

## Authority and semantic priority

The supplied TradingView Pine v5 strategy, `Opening Range Breakout + Regime Filter`, is the research baseline. The explicit E2 execution rule below intentionally overrides Pine's close-based entry geometry:

1. A completed breakout candle creates a candidate.
2. The candidate is not executable until the next candle opens.
3. E2 submits at that next open and uses the actual executable MT5 fill.
4. Stop distance, immutable Original R, take profit, and position size are based on that actual fill (and, for monetary sizing, the submitted protective SL).

If the Pine behavior and this document conflict, this document controls E2 OBR. No other existing E2 strategy formula is an OBR requirement.

## Time and data model

### Items fixed by the baseline

- The opening-range clock interval is `08:00` through `09:00`.
- Pine interprets `input.session("0800-0900")` in the exchange timezone of the chart symbol.
- Pine uses the chart timeframe for opening-range construction, breakout confirmation, ADX, ATR, and order evaluation.
- Pine's `time("D")` defines its daily reset from the chart symbol/exchange's daily-bar calendar.
- All E2 signal decisions must use completed candles. A candle's values become eligible only at or after its close/known-from timestamp.

### E2 time basis

E2 uses M15 and the Europe/London calendar. London DST begins at 01:00 UTC on the last Sunday in March and ends at 01:00 UTC on the last Sunday in October. Broker bar timestamps are converted explicitly through configured broker standard/summer UTC offsets; they are never interpreted using the computer timezone or news-file offset.

## Daily state and opening range

For each authoritative trading day:

1. Reset `OR High`, `OR Low`, range readiness, pending candidate state, and successful-entry count at the defined day boundary.
2. During the half-open opening-range interval `[08:00, 09:00)`, update:
   - `OR High = max(highs known within the interval)`
   - `OR Low = min(lows known within the interval)`
3. Do not use a candle unless its contribution is causally available under the locked timeframe/session-boundary policy.
4. At completion of the range window, freeze both boundaries for the rest of that trading day. They may not mutate after freeze.
5. No future candle or reconstructed later information may contribute to a previously known range.

Session-boundary candles require an explicit pre-implementation rule when the selected timeframe does not align exactly with 08:00 and 09:00. Pine includes a chart bar when `time()` says that bar is in-session; exact parity therefore depends on chart timeframe and session alignment.

## Indicators and regime eligibility

Evaluate indicators only from values available at the breakout decision timestamp on the locked decision timeframe.

- ADX length: `14`.
- ADX threshold: `20` inclusive.
- ATR length: `14`.
- Trend qualification: `ADX(14) >= 20`.
- Opening-range size: `OR Size = OR High - OR Low`.
- Range qualification: `OR Size >= 0.5 * ATR(14)`.
- Regime eligibility: both trend and range qualifications pass.

The Pine baseline uses `ta.dmi(14, 14)`, so both DI length and ADX smoothing are 14. E2 must match the locked calculation convention; MT5/Pine indicator parity (smoothing, warm-up, price series, and rounding) must be verified before implementation.

## Breakout and overextension guard

A candidate can exist only after the opening range is frozen and a decision candle is complete.

Long candidate requirements:

- no successful OBR entry has consumed the day;
- regime eligibility passes;
- completed candle close is strictly above `OR High`;
- `breakout close - OR High <= 0.5 * ATR(14)`.

Short candidate requirements:

- no successful OBR entry has consumed the day;
- regime eligibility passes;
- completed candle close is strictly below `OR Low`;
- `OR Low - breakout close <= 0.5 * ATR(14)`.

Intrabar penetration, a touch, or an equal close does not qualify. ATR and ADX samples must be the completed, causally available samples associated with the breakout decision; no future sample may be substituted.

## Entry and causal ordering

A qualifying breakout is known only after the breakout candle completes. Execution is deferred to the next candle open:

`breakout candle time < breakout known-from time <= next candle open/entry decision time <= actual fill time`

At minimum, E2 must enforce `breakout_known_from < entry_time` using the timestamp convention locked for implementation. The intended order is strict: detection from a completed candle first, execution on the next candle second. Actual market execution may differ from the nominal bar open because of bid/ask, spread, latency, slippage, market state, and broker rules; the authoritative entry is the MT5 fill price.

The candidate is executable only while the current M15 bar is exactly its `known_from` bar. A plan seen earlier or later is rejected as non-causal or expired. There is no retry after that window.

Immediately before planning, long uses current Ask and short uses current Bid. Entry distance beyond the breakout boundary must remain at most `0.5 * frozen breakout ATR`. Quote freshness, spread, deviation, ownership, margin and broker checks remain generic execution gates. Any rejection or failed attempt leaves the London day available, but the same deterministic execution request is never submitted twice.

## Structural stop, Original R, target, and reporting

Long:

- strategy-intended structural stop: `OR Low - 0.10 * frozen breakout ATR`;
- Original R price distance: `actual fill - submitted protective SL`;
- baseline target: `actual fill + 2 * Original R price distance`.

Short:

- strategy-intended structural stop: `OR High + 0.10 * frozen breakout ATR`;
- Original R price distance: `submitted protective SL - actual fill`;
- baseline target: `actual fill - 2 * Original R price distance`.

The geometry must be directionally valid and Original R must be positive. Original R becomes immutable after execution. Stop movement, broker adjustment, partial history, restart, or later management must never redefine it.

Reporting must preserve both:

- the strategy-intended structural stop (`OR Low` or `OR High`); and
- the broker-valid protective SL actually submitted/accepted.

If broker constraints require changing the submitted protective SL, it is adjusted outward to a valid tick and minimum distance. Monetary position sizing uses that submitted SL, while reporting retains the unmodified structural level. The market order carries the protective SL and no initial TP. After the authoritative fill, Original R is frozen from fill to submitted SL and a broker-normalized `fill +/- 2 * Original R` TP is attached immediately, with one retry on failure.

Baseline OBR has no trailing stop, breakeven movement, partial exit, zone target, or milestone trailing.

## Risk and volume

The Pine research baseline requests fixed cash risk of `$100` per trade. Sprint 0 does not change E2's existing risk system or its current defaults.

The eventual EA may retain generic `FIXED_CASH` and `BALANCE_PERCENT` modes. Position sizing must use:

- actual executable entry/fill;
- broker-valid submitted protective SL;
- requested cash risk from the selected mode;
- MT5 tick size, tick value/profit-and-loss calculation, contract and symbol economics;
- broker minimum, maximum, and step volume; and
- a normalized valid volume that does not exceed the intended risk under the chosen normalization policy.

The Pine expression `riskCapital / price distance` is not sufficient for MT5 and is not canonical E2 sizing.

## Daily opportunity accounting

The fixed rule is a maximum of one successfully entered OBR trade per authoritative trading day. A confirmed successful entry consumes that day's opportunity.

The limit is per symbol and Europe/London calendar day. Rejected plans and failed execution attempts do not consume it. A successful filled entry does, including after restart. Later Sprint 2 candidates may be considered only while the day remains unconsumed.

## Completed-data and determinism requirements

- Use only closed decision candles for breakout and indicator decisions.
- Use no look-ahead, future range values, future indicator values, or future zones.
- Store decision-time values rather than recomputing them later from revised context.
- Give the OR, candidate, plan, execution, and trade stable identities suitable for duplicate suppression and restart reconciliation.
- Persist or reconstruct state only from information that was objectively available at each historical timestamp.
- Keep candidate-known, plan-created, entry-request, fill, and reporting timestamps distinct.

## Pine to E2 semantic differences

| Topic | Pine baseline | Canonical E2 OBR |
|---|---|---|
| Breakout decision | Completed chart-bar close in normal strategy evaluation | Completed candle only |
| Entry timing | Market order generated from the breakout-close evaluation (TradingView fill behavior depends on strategy settings) | Next candle open / actual executable MT5 fill |
| Entry geometry | Pine source calculates stop distance and target from breakout `close` | Actual fill is the entry anchor |
| Stop distance / Original R | Breakout close to opposite OR boundary | Actual fill to opposite OR boundary |
| Sizing | `$ risk / price distance` | MT5 monetary loss calculation, submitted SL, and normalized broker volume |
| Stop representation | One stop price | Preserve structural stop separately from submitted/accepted SL |
| Daily consumption | `tradedToday` is set when the entry branch executes | Only a successfully entered trade definitely consumes the day; failure/retry policy is unresolved |

## Sprint 3 recovery and verification

Entry-deal history under the configured magic, symbol and `E2OBR|<LondonDay>` comment is authoritative for the consumed-day lock. A small `FILE_COMMON` record preserves open-position candidate identity, fill, structural/submitted stops, immutable Original R, TP, initial risk, volume and tickets. Startup validates and re-registers it; stale state is cleared once no owned position remains.

Tester output separates `[OBR_VERIFY]` candidate parity from `[OBR_PLAN_VERIFY]`, `[OBR_EXEC_VERIFY]`, `[OBR_RECOVERY_VERIFY]` and `[E2_RISK_VERIFY]`. Broker offset history and numerical MT5/TradingView indicator parity remain deployment evidence that must be checked for each dataset, not alternative runtime rules.
