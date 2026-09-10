# E2 4.1 — entry confirmation repair

The order now carries both SL and a provisional TP calculated from the planned entry. After the broker confirms all fills, the EA calculates the final fixed-R TP from the weighted actual fill and original SL, then verifies protection, saves recovery state and registers the trade. This can cause small differences from old backtests when slippage or an immediate exit occurs before TP adjustment.

The pending intent is saved before submission in the terminal's local Files folder, scoped by account, magic and symbol with server/time-policy validation. Delayed deals are reconciled on trade events and a one-second timer. Only reconciliation/protection is retried; the entry order is never resent. An unresolved or ambiguous result blocks new entries and prints `ENTRY_PENDING` even with routine logging disabled. A broker rejecting the TP correction leaves the initial broker-side TP in place while correction is retried. No software can guarantee a broker accepts a modification.

## Test before updating the eval

1. Wait for the currently open eval trade to close. Version 4.1 cannot reconstruct the missing intent from the old version's failed registration; do not replace the running EA during that trade.
2. Download main. Copy `E2.mq5` and the complete `include` folder to a separate demo/test installation. Compile with MetaEditor; require zero errors.
3. Rerun your original XAUUSD M5 backtest with the same inputs. Confirm trade counts/results and inspect any changed trade, accounting for the new initial TP.
4. On demo, confirm each order has SL and TP immediately. Look for `ENTRY_CONFIRMED` with the actual fill, original SL and final target. For a buy, final TP is fill + 1.5 × (fill − SL), rounded to the symbol's price tick.
5. Test delayed confirmation, repeated trade events and a rejected protection modification on demo. The EA must block further entries and reconcile without resending an order.
6. Restart after a fully confirmed demo fill and verify recovery. Test a restart during pending confirmation in a controlled demo environment; it must resume the saved intent and never send a second order.

Offline validation: the production reconciliation header is compiled against a deterministic C++ broker fake in `tests/entry_lifecycle.cpp`. It covers delayed deals, partial fills, duplicate callbacks, protection/persistence failures, unrelated deals, restart recovery and an exit before confirmation. This does not compile the complete MQL EA or replace MetaEditor/live demo testing.

Reference: [MetaQuotes transaction ordering](https://www.mql5.com/en/docs/event_handlers/ontradetransaction) explicitly says event arrival order is not guaranteed. Journal timestamps establish a timing mismatch but do not prove whether the original deal ticket was zero or its history lookup failed.
