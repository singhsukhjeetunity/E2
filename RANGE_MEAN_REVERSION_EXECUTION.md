# Range Mean-Reversion Execution

Range Mean-Reversion uses the shared E2 plan, fixed-base sizing, native execution, position management, and authoritative deal-reporting infrastructure. Strategy identity remains `RANGE_MEAN_REVERSION` throughout.

## Entry event and revalidation

The candidate is known at its completed confirmation candle close. Its only entry window is the M15 bar whose open equals `confirmationKnownFrom`; current quote, not confirmation close, is the planned and executable entry reference. Planning rejects a stale window, non-RANGE H4 state, invalid or different current range ID, inactive challenged source zone, or inactive opposing target zone.

The shared position guard, London/New York session filter, news filter, quote age/spread checks, symbol trade mode, broker constraints, fixed-initial-balance sizing, margin/order validation, and native executor remain authoritative.

## Structural geometry

The existing H1 structural buffer input is reused:

```text
buffer = InpResearchH1ZoneInvalidationAtr * candidate frozen H1 ATR

LONG stop  = challenged support lower edge - buffer
SHORT stop = challenged resistance upper edge + buffer
```

Broker stop distance may conservatively widen the submitted stop. The stop is never derived from the M15 candle alone.

The target is the near edge of the opposite frozen range zone:

```text
LONG target  = opposing resistance lower edge
SHORT target = opposing support upper edge
```

Planning and execution both require:

```text
availableR = abs(target - current entry) / abs(current entry - stop) >= 2.0
```

## Management and persistence

Every RMR plan uses `ZONE_TARGET_TRAILING`; the opposing-boundary TP remains native while `E2V2PositionManager` applies the existing immutable-original-R milestone schedule. No management formula is duplicated.

Compatibility-sensitive position comments remain `E2V2Z|...`. Setup identity is persisted separately in the existing `E2V2M.<magic>.<position>.*` terminal-global namespace as `SETUP`, alongside entry, original stop/R, branch, and milestone. Existing TC positions without `SETUP` recover as TC.

## Identity, ownership, and reporting

Plan identity is deterministic:

```text
RMRP_<candidateId>_<entryWindowTime>
```

The common symbol position guard arbitrates both setups. RMR is orchestrated before TC only for an exact shared entry-window timestamp, matching lexical setup priority (`RANGE_MEAN_REVERSION` before `TREND_CONTINUATION`); otherwise chronological candidate availability decides naturally.

Trade rows retain setup, range, candidate, plan, source/target zones, attempt, boundary visit, confirmation, planned/actual entry, original stop/R, TP, management branch, and MT5-authoritative result. Backtest summaries are filtered into independent setup rows.

