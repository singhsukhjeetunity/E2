# E2 Strategy State

## Current state: OBR end-to-end execution

E2 constructs the London M15 opening range, emits the unchanged Sprint 2 candidates and may execute a candidate only during its immediately following M15 window. Entry uses side-specific Ask/Bid, frozen candidate ATR, a structural OR stop, broker-valid submitted SL and generic monetary risk sizing.

The former Trend Continuation, Range Mean Reversion and Range Breakout system has been removed from the active source tree. It is available through Git history only.

## Trade lifecycle

After the actual fill, Original R is frozen from fill to submitted SL and the EA immediately attaches a 2R target. SL and TP remain fixed: there is no trailing, breakeven, partial close or discretionary management. Only a successful fill consumes the per-symbol London day; rejected and failed attempts do not.

Restart recovery combines authoritative entry-deal history for the day lock with persisted metadata for an open position. Full rules are maintained in [OBR_STRATEGY.md](OBR_STRATEGY.md).
