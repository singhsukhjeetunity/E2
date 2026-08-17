# Trend Continuation Reporting

## Lifecycle identity

Every successful Trend Continuation trade retains one immutable identity chain:

```text
E2TrendContinuationCandidate
  -> E2V2TradePlan
  -> E2V2ExecutionResult / E2V2PositionMetadata
  -> E2ReportEntryData
  -> E2ReportedTrade
```

The chain carries setup type, candidate and plan IDs, stable source/target-zone IDs, attempt number, direction, breakout/retest/confirmation timestamps and known-from timestamps, planned and actual entry, original stop/R, target, management branch, and MT5 position/order/deal identity.

Reporting never reconstructs setup state from comments, direction, or management branch. Compatibility-critical comments and terminal-global keys remain management recovery mechanisms, not reporting identity.

## Finalized trade CSV

`E2_trades_<symbol>_<run-id>.csv` writes exactly one row for each registered position after authoritative MT5 exit data is available.

Columns:

`trade_id, symbol, setup_type, candidate_id, plan_id, direction, source_zone_id, target_zone_id, zone_role, attempt_number, breakout_candle, breakout_known_from, retest_time, retest_known_from, confirmation_candle, confirmation_known_from, entry_time, close_time, session, entry_h4_adx, management_branch, planned_entry, actual_entry, original_sl, original_r_price, planned_tp, zone_target, stop_pips, planned_rr, volume, equity_at_entry, target_risk_cash, original_risk_cash, original_risk_pct, position_id, order_ticket, entry_deal_ticket, close_price, mt5_exit_reason, exit_classification, outcome, gross_profit, commission, swap, fees, realized_profit, realized_r, holding_minutes`.

Only positions captured after successful E2 execution enter the reporter. Manual or foreign deals cannot create rows.

## Realized R

`original_r_price = abs(actual_entry - original_sl)`.

`original_risk_cash` is calculated at execution from the actual fill, original protective stop, normalized volume, and MT5 `OrderCalcProfit`. It is immutable even if the position manager later advances the stop.

`realized_profit = gross_profit + commission + swap + fees`.

`realized_r = realized_profit / original_risk_cash`.

Costs are therefore included explicitly. Results are not rounded or forced to integer R values; slippage, commission, swap, and execution behavior remain visible.

## Exit classifications

Classification is downstream-only:

- `FIXED_2R_TP`: MT5 TP exit on a Fixed 2R position.
- `ZONE_TARGET_TP`: MT5 TP exit on a Zone Target/Trailing position.
- `ORIGINAL_SL`: fixed-branch SL, or trailing-branch SL whose exit remains conservatively within broker tick tolerance of the original stop.
- `TRAILING_SL`: trailing-branch SL distinguishable from the original stop.
- `OTHER`: classification is not deterministic.

The raw MT5 deal reason is retained separately.

## Trend Continuation summary

The summary CSV and `RESULT` line are explicitly filtered to `setup_type=TREND_CONTINUATION`. They report the funnel—candidates, entry windows, valid plans, execution attempts, executed trades, and finalized trades—plus wins, losses, breakeven, win rate, Net R, Average R, profit factor, maximum R drawdown, net profit, direction breakdowns, and management-branch trade/R/profit breakdowns.

A future setup must receive its own setup-filtered summary row rather than being combined with Trend Continuation.

## Verification

`TC_REPORT_VERIFY` compares candidate, planner, execution, finalized, unresolved, duplicate, foreign-deal, setup-contamination, original-R, and realized-R invariants. It is bounded and emitted only with the existing tester verification summary.
