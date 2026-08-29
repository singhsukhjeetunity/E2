# E2 Status

## ADXBB Sprint 5 — release-candidate hardening in progress

Sprint completion: Sprint 0 complete; Sprint 1 complete; Sprint 2 complete; Sprint 3 complete; Sprint 4 complete. Sprint 5 validation is not yet complete.

E2 now contains a completed-M5 observational ADXBB signal engine using custom Pine-style DMI/ADX and ATR RMA calculations plus population-standard-deviation Bollinger Bands. Candidates freeze the full indicator snapshot, ATR risk distance, and immediate-next-M5 execution window. Consecutive qualifying candles remain independent.

Retained foundations are explicit M5 completed-candle access, environment and symbol/account metadata, MT5-native monetary sizing, generic order requests, execution safety/executor, magic-number ownership, logging, CSV mechanics, minimal reporting, and generic input/core/risk verification.

Sprint 3 added immediate-next-M5 planning, outward-only SL normalization, MT5-native monetary sizing, generic execution, authoritative fill capture, immutable Original R, fixed-R TP attachment, one-position-per-symbol enforcement, optional successful-fill daily locking, lifecycle reporting, and fail-safe restart recovery.

Sprint 4 adds final production SIGNALS and TRADES datasets, deterministic run/configuration identity, candidate outcome taxonomy, MT5 deal-history financial aggregation, financial realized R, restart-safe deterministic row identities, and reconciliation/financial verification. Reporting remains observational and is enabled by the existing `InpCsvExportEnabled` input.

Sprint 5 release preparation adds compact paired report filenames with pairwise collision avoidance while retaining the full run ID and full configuration hash inside every row and diagnostic block. Production semantics and both frozen Sprint 4 schemas are unchanged. Sprint 5 remains in progress until the required Strategy Tester regression, CSV reconciliation, financial verification, restart regression, and collision-generation evidence all pass; no release tag has been created.

The frozen historical strategy and its documentation remain available through Git history/releases. No new tag or release is created by Sprint 1.
