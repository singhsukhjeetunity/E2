# H1 Range Boundaries

Sprint 2.2 adds a read-only H1 boundary-selection layer for future range research. It consumes the authoritative H4 regime snapshot and persistent H1 zone records; it does not mutate either upstream engine and cannot create candidates, plans, orders, or reports.

## Eligibility and selection

Selection runs only on a newly completed H1 context while H4 is affirmatively `RANGE`. A candidate pair consists of an active SUPPORT zone below an active RESISTANCE zone. Each reference is the midpoint of its source zone:

```text
lowerReference = (support.lower + support.upper) / 2
upperReference = (resistance.lower + resistance.upper) / 2
rangeHeightATR = (upperReference - lowerReference) / completed H1 ATR(14)
```

The upper reference must be strictly greater than the lower reference. Both references must be contained by the H4 evidence envelope with `0.25 * H1 ATR` tolerance, and height must be at least `3.0 H1 ATR`.

The deterministic winner is the pair with the greatest ATR-normalized height. Ties select the earlier `max(lower creation, upper creation)`, then lexical lower-zone ID, then lexical upper-zone ID.

## Identity and causality

The stable identity contains symbol, both source-zone IDs, and known-from time. Known-from is the maximum of the H4 regime known-from time, both source-zone creation times, and the current completed-H1 availability time. Forming bars are never read.

## Frozen lifecycle

On creation, source-zone bands, midpoint references, center, height, H4 evidence, ATR, identity, and timestamps are frozen. The pair remains active until the first completed-H1 evaluation where any of these occurs:

- H4 is no longer `RANGE`.
- Either source zone is no longer active.
- H1 closes strictly more than `0.25 * H1 ATR` below the support zone's far edge.
- H1 closes strictly more than `0.25 * H1 ATR` above the resistance zone's far edge.

An exact `0.25 ATR` excursion remains valid. Invalidation ends the evaluation; a replacement may be selected only on a later completed H1 evaluation.

## Evidence versus boundaries

The H4 high/low are broad containment evidence for regime classification. The selected H1 zone midpoints are the future strategy boundary references. Neither layer is presently executable range-strategy logic.

## Verification and visualization

`H1_RANGE_VERIFY` reports context supply, pair-gate counts, lifecycle invalidations, active end state, identity/mutation/causality invariants, range-height statistics, and maximum candidate-pair load. `InpVisualShowH1RangeBoundaries` optionally draws frozen lower, upper, and center references on H1 only. Visualization is downstream-only.

