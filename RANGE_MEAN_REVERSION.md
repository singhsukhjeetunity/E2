# Range Mean-Reversion

Sprint 2.3 implements candidate-state research only. The dedicated engine consumes cached H4 regime state, the current frozen H1 range context, completed M15 candles, and the existing rejection-confirmation engine. It cannot create plans, orders, positions, trades, targets, or management decisions.

## Eligibility and outer regions

State may exist only while H4 is `RANGE` and the H1 range context is valid. For frozen references `lower`, `upper`, and `height = upper - lower`:

```text
lowerOuterThreshold = lower + height * 0.20
upperOuterThreshold = upper - height * 0.20
```

A lower attempt requires a prior completed-M15 close above the lower threshold. A later completed candle must close at or below that threshold and intersect the frozen lower SUPPORT band. The upper side is symmetric: a prior close below the upper threshold, followed by a later close at or above it that intersects the frozen RESISTANCE band. Startup inside an outer region cannot manufacture an attempt.

## Attempt lifecycle and rearm

Each range ID owns independent LONG and SHORT state:

```text
IDLE -> ARMED_FROM_INTERIOR -> BOUNDARY_ACTIVE
     -> CONSUMED_WAIT_REARM -> ARMED_FROM_INTERIOR
```

Attempt number increments only when an armed side begins a new source-zone interaction. A consumed or unconfirmed active visit cannot begin another attempt until completed-M15 close moves at least `0.50 * current H1 ATR` above the lower zone's upper edge for LONG, or below the upper zone's lower edge for SHORT. The engine does not mutate H1 zone state.

H4 regime loss or H1 range loss terminates both sides immediately. State is never carried to another range ID.

## Confirmation and candidate identity

The lower side routes its immutable SUPPORT band through the confirmation engine's directional bullish-rejection API. The upper side routes its RESISTANCE band through the symmetric bearish API. Momentum confirmation is not used. The authoritative formulas, strict recovery, inclusive wick thresholds, failure order, and input validation are documented in [M15_CONFIRMATION.md](M15_CONFIRMATION.md).

Candidate known-from is the completed confirmation candle's open plus 15 minutes and cannot precede the H4 regime, H1 range, or boundary-visit known-from timestamps. Identity is deterministic:

```text
RMR_<symbol>_<rangeId>_<direction>_<attempt>_<confirmationKnownFrom>
```

If both sides qualify at one timestamp, one winner is chosen by stronger wick/range ratio, then smaller confirmation-close distance to the challenged reference, then lexical source-zone ID. At most one RMR candidate is emitted per timestamp.

The emitted candidate embeds the authoritative confirmation result, including candle OHLC, zone geometry, body, full range, lower/upper/relevant wick, ratios, individual gates, failure classification, and known-from time. RMR does not recompute these measurements.

## Planning and execution

`InpEnableRangeMeanReversion` controls the raw candidate stream. Each candidate may now enter the shared planner at its next M15-open window. The planner revalidates H4 RANGE, the same active frozen range and source zones, shared filters, structural stop, opposing-boundary target, minimum 2R, and fixed-base risk before using native E2 execution. Full geometry, management, persistence, ownership, and reporting semantics are in [RANGE_MEAN_REVERSION_EXECUTION.md](RANGE_MEAN_REVERSION_EXECUTION.md).

Range Breakout remains inert.
