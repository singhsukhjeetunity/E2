# E2 London Range Breakout Deployment

Attach only to EURUSD M5 (EUR/USD currency identity permits broker suffixes).
A verified broker-time profile must be configured before attachment or backtesting.
Do not substitute the synthetic fixtures for a real broker/history policy.

The strategy uses London-local range/session boundaries. Broker timestamps are converted through an explicit UTC-offset schedule, then pinned Europe/London data.
Weekend-flat protection remains broker-session based and independent of the London alpha window.

Signals use completed M5 closes. Entry is attempted only in the immediately following M5 bar, never at the historical close.
SL and sizing use the existing broker adjustment and risk framework; targets use actual fill and immutable Original R.
OneTradePerDay now means one successful entry per London date, reconstructed from owned deal history.

Reports use LRB_REPORT_V1 and the existing paired SIGNALS/TRADES file framework. The old ADXBB/REGIME report schemas are historical, not the active London schema.
See LONDON_RANGE_BREAKOUT.md for deployment, recovery compatibility, report fields and validation limitations.

Authoritative multi-year backtesting remains blocked pending a verified history-source broker-time profile.
