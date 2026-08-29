# E2 OBR Sprint 4 Validation

## v1.2.0 session validation

For London regression, select `LONDON` and repeat the identical accepted v1.1.0 environment and parameters; equality under identical conditions is the criterion. For New York, sample the 09:30, 09:45, 10:00 and 10:15 America/New_York bars, verify freeze at 10:30, and confirm no OR-building bar becomes a breakout candidate. Validate periods before, between and after the differing US/UK spring and autumn transitions. With a New York weekday disabled, confirm the OR still builds, otherwise-valid signals are audited as `SUPPRESS / DISABLED_WEEKDAY`, and no candidate/trade is created on that New York local weekday.

`[OBR_SESSION_VERIFY]` must identify the selected session and report zero time/day/weekday mapping, bar-count, OR-boundary/mutation and DST-transition violations. Decision and trade CSVs now include `selected_session`, `session_day`, and `session_weekday`. Runtime controls require the external Strategy Tester environment and must not be inferred from compilation.

## Canonical accepted baseline

The controlling reference is the accepted Sprint 3 EURUSD M15 run: 202 London days, 167 complete ranges, 316 candidates (145 long, 171 short), 95 valid requests, 95 attempts, 95 successful entries, 95 registered/finalized trades, five entry-gap rejections and zero duplicate, causality, ownership, recovery, registration or protection violations.

Configuration: EURUSD M15, identical accepted dates/history/tick model and broker offsets, $100,000 initial balance, FIXED_CASH $1,000, ADX(14) >= 20, ATR(14), OR >= 0.5 ATR, breakout and entry gap <= 0.5 frozen ATR, 0.10 ATR stop buffer and 2R target. Sprint 4 does not change these semantics or optimize them.

## Runtime evidence

Enable CSV export for two passive files in the terminal Common Files directory:

- `E2_trades_<symbol>_<run>.csv`: one finalized-trade lifecycle row, from OR through net P/L and realized R, including integrity flags.
- `E2_OBR_decisions_<symbol>_<run>.csv`: one candidate decision row, including missed-window/day/position/gap/quote/stop/sizing/other reasons and the complete TradingView comparison tuple.

End-of-run journal blocks are `OBR_RECONCILE_VERIFY`, `OBR_FINANCIAL_VERIFY`, `OBR_R_VERIFY`, `OBR_DAY_VERIFY`, `OBR_ENTRY_TIME_VERIFY`, `OBR_ENTRY_GAP_VERIFY`, `E2_RISK_VERIFY`, and `OBR_RUN_FINGERPRINT`, in addition to the Sprint 3 blocks. Monetary reconciliation tolerance is one account-currency cent; R geometry tolerance is one symbol tick. MT5 deal history is monetary authority.

Sprint 5 timing classification: the accepted run's three formerly labelled late violations correspond exactly to `expiredCandidates=3`. They are now `missedWindowCandidates`; only submitted execution requests are checked for `actualLateExecutionViolations`, whose required value is zero. Planner expiry and execution behavior are unchanged.

CSV counters are conditional. `tradeCsvStatus=CSV_DISABLED` and `decisionCsvStatus=CSV_DISABLED` make zero rows observational, not a mismatch. With CSV enabled, finalized-trade rows must equal finalized trades and `tradeCsvRowMismatch` must be zero.

## Determinism procedure

Run the identical baseline twice with a clean tester state. Compare the complete decision and trade CSVs after excluding filenames/run IDs, plus `OBR_RUN_FINGERPRINT`. OR/candidate IDs, decisions, request IDs, trade IDs, directions, timestamps, initial SL, TP, counts and Net R must match. Record any tester-mode monetary field that legitimately differs; do not accept signal or geometry drift.

## TradingView signal-parity procedure

Select at least five accepted longs, five accepted shorts, three ADX rejections, three OR-size rejections if present, three overextensions, and samples around both London DST transitions. Join on London day, direction and breakout time. Compare OR high/low, close, ATR, ADX, OR/ATR, gap/ATR and outcome from the decision CSV. Signal parity is distinct from TradingView execution results. Stop on material divergence and classify feed, boundary, timezone, warm-up, smoothing, iADX/`ta.dmi`, or missing-bar cause; never tune thresholds to force agreement.

## DST procedure

Inspect the days surrounding the last Sunday in March and October for each tested year. Confirm London 08:00 remains OR start while its UTC/server timestamp changes according to London and configured broker schedules. Use `OBR_TIME_VERIFY`; do not assume both schedules transition together.

## Restart controls

Day lock: restart after a successful entry on a day with a later candidate. Require `dayLockRecoveries > 0`, no later entry and `duplicateDayEntryViolations = 0`.

Open position: restart while an OBR trade is open, verify fill, submitted SL, immutable Original R, TP, candidate/day identity, then allow finalization. Require `openPositionRecoveries > 0`, `metadataRecoveryFailures = 0`, and `originalRRecoveryViolations = 0`.

## Other controls

- BALANCE_PERCENT 1%: candidate fingerprint stays 316; requested cash risk follows balance; `riskModeMismatch = 0`.
- Trading disabled: candidate fingerprint stays 316; attempts may reach the executor but successful entries remain zero and are classified as intentional trading-disabled failures.
- Reporting passivity: repeat with CSV, debug, visuals and verification independently toggled. Candidate, plan, execution, SL and TP fingerprints must be unchanged.

## Current verification boundary

Compilation and static checks can be completed in-repository. The accepted Sprint 3 fingerprint above is supplied evidence. Determinism, TradingView samples, DST runtime inspection, restart scenarios, balance-percent, trading-disabled and reporting-passivity controls require the identical external tester environment and must not be reported as passed until run.

## v1.1.0 weekday regression matrix

The all-enabled run must reproduce the permanent v1.0.0 fingerprint: 316 candidates (145 long/171 short), 95 requests/attempts/successes/registrations/finalizations/day locks, five entry-gap rejections and Net R 18.730180 under the identical environment. Additional controls are Monday disabled, Wednesday only, and all days disabled. The last must retain OR processing while producing zero candidates and downstream activity. `[OBR_WEEKDAY_VERIFY]` must always show zero `disabledWeekdayCandidatesCreated` and `weekdayMappingViolations`. Runtime DST/midnight sampling must confirm the same Europe/London day conversion owns both OR identity and weekday.
