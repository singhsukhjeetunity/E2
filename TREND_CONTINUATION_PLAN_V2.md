# Trend Continuation V2 Trade Planning

Sprint 1.6 routes each emitted Trend Continuation V2 candidate to exactly one research planning opportunity. It does not submit an MT5 order and does not modify the legacy v1.0 strategy, plan, risk, or execution path.

## One-shot lifecycle

The completed confirmation candle makes the candidate known at the open of the following M15 candle. On the first evaluation in that candle, the planner records the candle open timestamp and evaluation timestamp, reads ASK for LONG or BID for SHORT, and performs all entry-time checks. A rejection expires that candidate permanently; it is never deferred to a later session, news window, quote, or price.

## Revalidation

Planning requires the TC toggle, matching eligible/non-overextended H4 regime, valid candidate and flipped-zone metadata, no open same-magic E2 position, a DST-aware enabled London or New York session, compatible news eligibility, and a current symbol quote satisfying quote-age and spread controls. Research planning remains enabled when native trading is disabled.

## Stop, target, and management

The structural stop uses the flipped entry-zone far edge plus an outward 0.10 multiple of the H1 ATR frozen when confirmation closed. Tick-size normalization is outward; a broker minimum distance may move only the normalized stop farther outward. A structurally wrong-side stop is rejected.

The target search considers active persistent opposing zones in the trade direction. A target must have `creation_time < confirmation_known_from`; the nearest qualifying near edge wins. Available R uses the actual next-M15 ASK/BID entry and normalized initial stop. Less than 2R is rejected.

Exactly one management input must be enabled. Fixed-2R mode plans a 2R target after proving at least 2R of opposing-zone space. Zone-target/trailing mode requires at least 3R and records the opposing near edge as the planned target; trailing execution is intentionally deferred.

## Risk

V2 captures the initial account balance once at initialization and holds its cash-risk base constant for the run. `E2PositionSizer.CalculateFixedInitialBalance` retains native `OrderCalcProfit`, broker min/max/step normalization, and monetary-risk verification without changing the legacy equity-based method.

Tester-end `TCV2_PLAN_VERIFY` reports routing, rejection categories, management branches, direction counts, duplicate/causality guards, and available-R aggregates. Detailed individual plan/rejection logs require verbose research diagnostics.
