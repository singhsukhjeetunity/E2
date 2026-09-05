# E2 London Range Breakout Deployment

Attach only to EURUSD M5 (EUR/USD currency identity permits broker suffixes).
Live attachment uses validated automatic current-offset observation; no broker profile is required. Strategy Tester requires a verified historical profile unless the operator deliberately selects the labelled, non-authoritative assumed fixed-offset research input. Do not substitute synthetic fixtures or assumed-offset output for authoritative history results.

The strategy uses London-local range/session boundaries. Live timestamps use the adapter's observed current offset and observed runtime transitions; tester timestamps use an explicit profile or labelled assumption, then pinned Europe/London data.
Weekend-flat protection remains broker-session based and independent of the London alpha window.

Signals use completed M5 closes. Entry is attempted only in the immediately following M5 bar, never at the historical close.
SL and sizing use the existing broker adjustment and risk framework; targets use actual fill and immutable Original R.
OneTradePerDay now means one successful entry per London date, reconstructed from owned deal history.

Reports use LRB_REPORT_V1 and the existing paired SIGNALS/TRADES file framework. The old ADXBB/REGIME report schemas are historical, not the active London schema.
See LONDON_RANGE_BREAKOUT.md for deployment, recovery compatibility, report fields and validation limitations.

Authoritative multi-year backtesting remains blocked pending a verified history-source broker-time profile.
