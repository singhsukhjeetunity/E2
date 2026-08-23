# E2 Strategy State

## Current state: OBR signal discovery only

E2 constructs the London M15 opening range and may emit OBR candidates. It produces no trade requests, execution attempts, registered positions or trades.

The former Trend Continuation, Range Mean Reversion and Range Breakout system has been removed from the active source tree. It is available through Git history only.

## Future direction

E2 OBR is under construction. Sprint 2 implements completed-candle signal discovery only. Its rules and remaining execution decisions are maintained in [OBR_STRATEGY.md](OBR_STRATEGY.md).

No retained generic service is itself a strategy. In particular, market data, news eligibility, risk sizing, execution safety, order submission and deal reporting cannot generate a trade without a future strategy producing a valid request.
