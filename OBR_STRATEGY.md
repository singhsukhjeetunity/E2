# E2 OBR Canonical Strategy Specification

Status: Sprint 0 specification lock. OBR is not implemented. This document defines the research baseline and records decisions that must be made before implementation.

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

### Not yet fixed for E2

The E2 implementation timeframe, the authoritative opening-range timezone, trading-day boundary, and DST rule are configuration decisions. They must be decided before implementation. E2 must not silently substitute H4, H1, M15, broker time, local PC time, or UTC. The eventual implementation must expose or centrally define one authoritative decision timeframe used consistently for OR bars, ADX(14), ATR(14), breakout confirmation, and next-candle execution unless a later specification explicitly locks separate timeframes.

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

- strategy-intended structural stop: `OR Low`;
- Original R price distance: `actual fill - OR Low`;
- baseline target: `actual fill + 2 * Original R price distance`.

Short:

- strategy-intended structural stop: `OR High`;
- Original R price distance: `OR High - actual fill`;
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

1. **Decision/chart timeframe.** Pine uses the chart timeframe for OR construction, ADX, ATR, breakout, and evaluation. Which MT5 timeframe will E2 use?
2. **Opening-range timezone.** Pine uses the symbol's exchange timezone. Which named timezone or fixed offset is authoritative in E2?
3. **Trading-day definition.** Pine resets on the chart symbol's daily-bar boundary. Define the E2 day boundary and its relationship to the OR timezone and broker server day.
4. **DST behavior.** If a named market timezone is used, define DST source/rules; if a fixed UTC or broker offset is used, explicitly accept that behavior.
5. **Session boundary bars.** Define inclusion when a candle straddles 08:00 or 09:00, or require a timeframe that divides both boundaries.
6. **Indicator sampling.** Confirm that ADX/ATR come from the breakout candle's completed sample and lock Pine/MT5 smoothing and warm-up parity.
7. **Post-09:00 eligibility span.** Pine permits a breakout at any later chart bar that day. Confirm whether E2 does the same.
8. **End-of-day cutoff.** Pine has no separate entry cutoff before its daily reset. Define whether E2 needs one and what happens to a candidate at cutoff/day rollover.
9. **First-breakout versus later-breakout policy.** Pine can accept a later qualifying candle after an earlier non-qualifying or overextended candle because only an entry sets `tradedToday`. Confirm E2 behavior.
10. **Overextended breakout consumption.** Pine rejects that bar without consuming the day. Confirm whether later candles may qualify, including candles that close back within the 0.5 ATR guard while still outside the range.
11. **Candidate lifetime.** Define whether a valid candidate is executable only at the immediately following candle open and exactly when it expires.
12. **Execution failure.** Define retry/no-retry behavior for market closed, stale quote, excessive deviation, broker rejection, invalid volume, margin, trade-context, or other failure.
13. **Daily-limit event.** The canonical minimum is one successful entry. Confirm whether an attempted signal, accepted candidate, submitted request, partial fill, or recovered existing position also consumes the day.
14. **Simultaneous long/short handling.** Unlikely with a valid positive range on one close, but define deterministic precedence for malformed/edge data and multiple-symbol operation.
15. **Spread filter.** The Pine baseline has none. Decide whether E2's existing maximum-spread gate applies to OBR and, if so, whether rejection is retryable.
16. **Entry deviation/slippage policy.** Define acceptable distance from nominal next-candle open, whether the plan is recalculated from the actual fill, and when excessive movement cancels the opportunity.
17. **News filter.** Pine has none. Decide whether E2's generic news filter applies, at which timestamp/currencies, and whether a block consumes or merely defers the opportunity.
18. **Session filter interaction.** Existing London/New York filters are not the OR definition. Decide whether any separate post-range entry-session filter exists.
19. **Broker-adjusted stop and TP.** Define stop-normalization direction, maximum acceptable adjustment, target basis after adjustment, and reject behavior if the structural stop violates broker constraints.
20. **Volume normalization.** Lock round-down/reject/minimum-volume behavior when exact requested cash risk is unavailable.
21. **Gap at entry.** The 0.5 ATR guard tests the breakout close, not the next open/fill. Decide whether an additional entry-fill gap/geometry guard exists.
22. **Multi-symbol scope.** Define whether the one-trade limit is per symbol, per EA instance, or global to the E2 magic/account/day.
23. **Restart/recovery.** Define persisted/reconstructed OR, candidate, and consumed-day state, including restart during the OR window or between signal close and next open.
24. **Missing bars/data.** Define whether an incomplete OR, indicator warm-up failure, market closure, or history gap invalidates the entire day.
25. **Price basis.** Pine OHLC is a chart series; MT5 execution uses bid/ask. Lock the chart/bid/mid basis for OR and indicators while retaining actual side-specific fill for execution.
