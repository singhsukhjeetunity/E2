# E2 live recovery update

Current main versions: EMA 0.25, Compression 0.12, Gold 4.3, Gotobi 1.16. The original live-recovery-v1 ZIP contains the earlier EMA 0.23 / Compression 0.11 builds. For current source download main and compile; see [tester continuation fix](EMA_TESTING.md#v025-late-exits-no-longer-truncate-a-backtest).

## Fixed

- Compression's shared checkpoint decoder rejected its actual strategy name on restart. The decoder now recognizes both families; each EA still validates its own identity, account, symbol, magic and settings.
- EMA and Compression no longer permanently stop on temporary checkpoint/report write failures. Entries pause until storage recovers. An unsaved entry reservation never reaches OrderSend.
- Delayed entry confirmation retains the existing reservation without resending or permanently stopping solely because confirmation is late. Explicit broker refusals and broker-confirmed terminal zero-fill orders release the reservation. Partial fills, unavailable history and ambiguous execution remain blocked.
- A late exit remains managed until closure is confirmed, instead of permanently preventing future entries after reconciliation. Tester deadline failures remain flagged and rejected by the optimisation score, but no longer stop later signals after settlement. Integrity failures are distinct from execution safety stops.
- Gold rebuilds regime observations from completed historical M5 bars on startup, without trading old signals. Its qualifying criteria are unchanged. Confirmed zero-fill rejected/canceled/expired orders no longer leave a permanent pending-entry reservation.
- All four EAs print health messages approximately every five minutes while their event loop runs. EMA/Compression expose hard stop, storage/export pause, warm-up, active intent and last M1 bar; Gold exposes initialization/pending/regime observations; Gotobi exposes UTC, owned position, entry minute and spread cap. These are diagnostics, not a complete broker connectivity monitor.

No risk allocation, signal thresholds, spread caps or entry timing windows were loosened. Valid signal gaps can still last weeks. Source inspection cannot establish the cause of your live inactivity without the terminal logs and loaded inputs.

## Upgrade safely

1. Back up current presets, recovery files and logs. Prefer upgrading while flat. Do not delete recovery files or leave two copies of the same EA running.
2. Extract the complete `MQL5/Experts/E2` tree into your terminal's data folder, preserving subfolders. Open each of the four `.mq5` entries in MetaEditor and compile with F7. This is a source-only release: portable tests do not replace native MetaEditor compilation.
3. Reattach the updated EAs with your existing risk, magic, symbol and verified broker-clock inputs. Do not replace live allocations with the generic Gotobi preset's cash-risk default.
4. Run the established baseline backtests and a demo smoke test before live deployment. Gold's correctly warmed historical regime can change results relative to the old startup bootstrap. Ensure its historical broker-clock coverage and sufficient M5 history are available.
5. Read initialization messages and the five-minute heartbeat. `[IO_PAUSED]` requires restoring filesystem access; `[IO_RESUMED]` confirms checkpoint recovery. `ENTRY_PENDING` means broker evidence is still unresolved: do not reset or resend manually.

## A stopped EMA/Compression from an older version

Old persisted stop flags are not cleared automatically because the original cause may be unsafe. After fixing the cause and verifying there are no outstanding orders, positions or unresolved intents, set `InpResetStoppedWhenFlat=true` for one initialization. A successful reset prints `[STOP_RESET]`; then restore this input to false. `[STOP_RESET_REFUSED]` means reconciliation/ownership/history checks did not establish a safe flat state. Missing, corrupt or mismatched checkpoints still fail initialization rather than being bypassed by this input.

Protection failures, clock failures, ownership conflicts and ambiguous execution are still safety blocks. A strategy should not be forced to trade to prove that it is running.

## Validation

Portable tests cover actual production checkpoint, entry, deadline, regime and clock code against deterministic broker/history fixtures. They exercise storage recovery, no-send-before-durability, definite rejection, timeout reservation, terminal zero-fill/partial-fill evidence, alternate-family checkpoint rejection, batch/streaming parity and historic Gold warm-up without old-signal emission. Native compilation and a connected demo-terminal upgrade test are still required.
