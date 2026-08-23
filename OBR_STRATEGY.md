# E2 OBR Canonical Strategy Specification

Status: Sprint 2 signal-model lock. Candidate discovery is implemented; execution remains disconnected.

## Sprint 2 decisions locked

- Decision timeframe: M15.
- Trading day and opening-range clock: Europe/London civil time with statutory GMT/BST transitions.
- Opening range: exactly the completed 08:00, 08:15, 08:30 and 08:45 London M15 bars; 09:00 is first eligible breakout bar.
- Eligibility continues through the London calendar day with no intraday cutoff.
- ADX(14), ATR(14), range qualification and gap qualification are evaluated anew on each completed breakout-eligible bar, including that bar.
- Failed ADX, range-size or breakout-gap checks do not consume the day. Multiple unique candidates are permitted; only a future successful trade consumes the day.
- Baseline news filtering is disabled for OBR candidates. Spread is an execution-only check.
- Future structural stop: long `OR Low - 0.10 * frozen breakout ATR`; short `OR High + 0.10 * frozen breakout ATR`. Sprint 2 does not calculate executable geometry.

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

Whether a delayed fill still counts as the next-candle entry, and when a pending plan expires, require decisions before implementation.

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

If broker constraints require changing the submitted protective SL, monetary position sizing uses the submitted SL, while strategy reporting retains the unmodified structural level and explicitly records the adjustment. The 2R strategy target is defined from actual fill and structural Original R; whether broker normalization of the submitted SL should also alter the submitted TP is not specified and requires a decision.

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

The following are deliberately not inferred: whether a valid but failed execution is retryable, whether an overextended breakout blocks later candles, whether a rejected plan consumes anything, and whether a later qualifying close can create a new candidate. Those cases require explicit decisions.

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

## OBR RULE DECISIONS REQUIRED

The following cannot be determined objectively for E2 from the supplied Pine source or current repository. Pine behavior is recorded where it is objective; no E2 choice is made here.

1. **Broker timestamp schedule.** Confirm the configured standard/summer server UTC offsets and whether the broker follows the European transition schedule for every tested historical period.
2. **Indicator parity evidence.** M15 `iATR(14)` and `iADX(14)` use MT5 Wilder indicators and include the completed breakout candle. Complete numerical TradingView comparison before execution is authorized.
11. **Candidate lifetime.** Define whether a valid candidate is executable only at the immediately following candle open and exactly when it expires.
12. **Execution failure.** Define retry/no-retry behavior for market closed, stale quote, excessive deviation, broker rejection, invalid volume, margin, trade-context, or other failure.
13. **Daily-limit event.** The canonical minimum is one successful entry. Confirm whether an attempted signal, accepted candidate, submitted request, partial fill, or recovered existing position also consumes the day.
14. **Simultaneous long/short handling.** Unlikely with a valid positive range on one close, but define deterministic precedence for malformed/edge data and multiple-symbol operation.
16. **Entry deviation/slippage policy.** Define acceptable distance from nominal next-candle open, whether the plan is recalculated from the actual fill, and when excessive movement cancels the opportunity.
19. **Broker-adjusted stop and TP.** Define stop-normalization direction, maximum acceptable adjustment, target basis after adjustment, and reject behavior if the structural stop violates broker constraints.
20. **Volume normalization.** Lock round-down/reject/minimum-volume behavior when exact requested cash risk is unavailable.
21. **Gap at entry.** The 0.5 ATR guard tests the breakout close, not the next open/fill. Decide whether an additional entry-fill gap/geometry guard exists.
22. **Multi-symbol scope.** Define whether the one-trade limit is per symbol, per EA instance, or global to the E2 magic/account/day.
23. **Restart/recovery.** Define persisted/reconstructed OR, candidate, and consumed-day state, including restart during the OR window or between signal close and next open.
24. **Missing bars/data.** Define whether an incomplete OR, indicator warm-up failure, market closure, or history gap invalidates the entire day.
25. **Price basis.** Pine OHLC is a chart series; MT5 execution uses bid/ask. Lock the chart/bid/mid basis for OR and indicators while retaining actual side-specific fill for execution.
