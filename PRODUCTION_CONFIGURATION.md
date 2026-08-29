# E2 Strategy-Free Core Configuration

Sprint 1 is an inert architecture checkpoint, not a trading release. Attach E2 to an M5 chart or run it in the Strategy Tester on M5. Initialization rejects other chart timeframes.

The core initializes environment detection, M5 closed-candle access, symbol/account metadata, monetary sizing, ownership, execution safety/executor, logging, generic CSV mechanics, and generic reporting verification. It contains no strategy and therefore cannot produce candidates or order requests regardless of `InpTradingEnabled`.

At shutdown, `[E2_CORE_VERIFY]` must report initialized state and zeros for candidates, requests, attempts, successes, registrations, finalizations, duplicates, causality, ownership, and unknown positions in a clean account/test. `[E2_RISK_VERIFY]` must show zero sizing activity. `[E2_INPUT_VERIFY]` must show 13 inputs and zero mapping defects.

No custom chart objects or strategy CSV files are created. `InpCsvExportEnabled` is retained for the future reporting architecture but only initializes the inert reporter boundary in Sprint 1.

ADXBB’s mechanical contract is [ADXBB_STRATEGY.md](ADXBB_STRATEGY.md). The transition/removal design is [ADXBB_ARCHITECTURE_AUDIT.md](ADXBB_ARCHITECTURE_AUDIT.md). ADXBB signals, indicators, daily limiting, execution integration, recovery, and final CSV schemas are later-sprint work.
