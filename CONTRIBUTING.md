# Mandatory Context

Before modifying E2, always read:

- `ARCHITECTURE.md`
- `ROADMAP.md`
- `STRATEGY.md`
- `CONTRIBUTING.md`

These files are authoritative.

If requirements conflict, stop and ask for clarification.

# Scope Discipline

- Implement only the requested sprint.
- Do not start later sprints.
- Do not perform unrelated refactors.
- Do not redesign architecture without explicit approval.
- Do not add speculative features.

# MQL5 Standards

- Target current MetaTrader 5 / MetaEditor.
- Prefer MT5-native / MQL5 Standard Library facilities where practical.
- Avoid deprecated patterns where possible.
- Code must compile with 0 errors before a sprint is considered complete.
- Warnings should be reviewed and minimized.

# Modularity

- Separate analysis, strategy, risk, execution, and reporting.
- Strategy modules must remain replaceable.
- Do not embed strategy-specific behavior in generic infrastructure.
- Do not duplicate generic functionality across strategies.

# Backtest / Live Parity

This is a critical invariant:

The same strategy implementation must be used by MT5 Strategy Tester and live/demo trading.

Do not create separate backtest-only and live-only strategy implementations.

# Look-Ahead Bias

Historical analysis must never access information that would not have been available at that historical time.

Use only confirmed/closed candles when strategy rules require confirmed candles.

Multi-timeframe synchronization must explicitly prevent future-candle leakage.

# Configuration

- Avoid unexplained hardcoded strategy parameters.
- Expose research/tuning parameters as controlled EA inputs or configuration.
- Do not expose internal invariants unnecessarily.

# Testing / Validation

For every sprint:

- Compile affected MQL5 sources.
- Report error and warning counts.
- Perform the sprint-specific validation.
- Preserve existing working behavior.
- State anything that still requires manual testing in MT5.

# Documentation

Update project documentation only when the sprint materially changes an agreed interface or architecture.

Do not silently rewrite project rules.

# Codex Completion Report

At the end of every implementation sprint report:

1. Files created
2. Files modified
3. Behavior added/changed
4. Validation performed
5. Compile result
6. Remaining risks/technical debt
7. Manual MT5 checks required
