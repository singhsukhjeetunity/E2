# Range Breakout Reporting

Sprint 3.3 completes the authoritative reporting lifecycle for `RANGE_BREAKOUT`:

`candidate -> plan -> execution -> registered entry metadata -> tick management -> authoritative MT5 exit deals -> finalized trade -> shared trade CSV -> RANGE_BREAKOUT summary`

Setup identity is propagated explicitly and never inferred from direction, management, target geometry, or comments. The shared trade CSV remains physically unified and every row carries `setup_type`, allowing TC, RMR, and RB to be filtered independently.

## Entry metadata

The entry record freezes candidate, plan, range, challenged-zone, target-zone and attempt identity; breakout, retest, confirmation and entry timestamps; causal target creation time; planned and actual price geometry; structural and submitted stops; native target; volume and execution-time monetary risk; order/deal/position identity; and the available RB breakout measurements. These values are captured at execution and are not reconstructed at close.

## Authoritative result accounting

Exit price, reason, profit, commission, swap and fees come from MT5 deals. `realized_profit` is their sum and `realized_r` divides that sum by the immutable execution-time risk calculated from actual fill, original submitted SL and executed volume. A moved trailing stop never redefines original R.

Exit classification remains conservative: `ORIGINAL_SL`, `FIXED_2R_TP`, `ZONE_TARGET_TP`, `TRAILING_SL`, or `OTHER`. Ambiguous exits remain `OTHER`.

## Validation

`RB_REPORT_VERIFY` reconciles the RB candidate-to-finalized lifecycle and financial invariants. `RB_REPORT_VERIFY_2` checks chronology, explicit identity, duplicate rows, structural-stop validity, broker adjustment, and required RB IDs. The setup-filtered backtest summary emits an independent `Setup=RANGE_BREAKOUT` row with common economic, directional, management, holding, session and exit metrics.
