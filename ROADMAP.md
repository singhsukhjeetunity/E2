# Sprint 0 — Foundation

## 0.0 Documentation

Goal:
Create authoritative architecture, strategy, roadmap, and contribution rules.

Deliverables:

- `ARCHITECTURE.md`
- `STRATEGY.md`
- `ROADMAP.md`
- `CONTRIBUTING.md`

Exit criteria:
All documentation exists and contains no implementation code.

## 0.1 Project Structure

Goal:
Create the modular MQL5 folder/module structure around the currently compiling EA.

Deliverables:

- Modular folders and module boundaries aligned with `ARCHITECTURE.md`
- Existing EA preserved as the behavior baseline

Exit criteria:

- No behavioral changes.
- The EA compiles cleanly after the structure is introduced.

## 0.2 Configuration / Inputs

Goal:
Centralize configurable E2 inputs and strategy parameters.

Deliverables:

- Central configuration/input organization
- Configurable generic and strategy-specific parameters

Exit criteria:

- Inputs are centrally discoverable and documented in code.
- No unexplained hardcoded research parameters remain in affected modules.

## 0.3 Logging / Export Infrastructure

Goal:
Create logging and CSV export foundations.

Deliverables:

- Strategy-independent logging foundation
- CSV export foundation suitable for backtest and live records

Exit criteria:

- Logging and export foundations compile cleanly.
- No trading logic is added by this sprint alone.

## 0.4 Baseline Strategy Tester Validation

Goal:
Verify the modular baseline compiles and runs correctly in MT5 Strategy Tester before trading logic is added.

Deliverables:

- Strategy Tester baseline validation record
- Manual MT5 test instructions or results as applicable

Exit criteria:

- The modular baseline compiles cleanly.
- It runs correctly in MT5 Strategy Tester before trading logic is added.

# Sprint 1 — Analysis

## 1.1 Multi-Timeframe Access

Goal:
Provide H4 / H1 / M15 access with strict closed-candle synchronization and no look-ahead bias.

Deliverables:

- Multi-timeframe market-data access layer
- Closed-candle synchronization safeguards

Exit criteria:

- H4, H1, and M15 data are available to downstream modules.
- Future-candle leakage is explicitly prevented.

## 1.2 Market Structure + ADX Trend/Range

Goal:
Detect H4 structure and classify Bullish / Bearish / Range.

Deliverables:

- H4 HH/HL and LH/LL structure detection
- ADX-assisted trend/range classification

Exit criteria:

- Classification returns Bullish, Bearish, or Range from confirmed H4 data.
- Range classification prevents directional trade eligibility.

## 1.3 Support / Resistance Zones

Goal:
Detect H1 multi-touch zones and support/resistance role reversals.

Deliverables:

- Configurable multi-touch H1 zone detection
- Zone merging, tolerance, width, and role-reversal handling

Exit criteria:

- Detected zones satisfy configured touch and tolerance rules.
- Broken support/resistance role reversals are represented.

## 1.4 Confirmation Engine

Goal:
Implement configurable M15 confirmation detectors.

Deliverables:

- Engulfing, pin bar, momentum candle, and previous-candle-break detectors
- Independent enablement/configuration for each confirmation type

Exit criteria:

- Each detector evaluates confirmed M15 candles.
- Enabled confirmations can be tested independently.

## 1.5 Session Filter

Goal:
Implement London / New York trading-window logic.

Deliverables:

- Configurable session definitions
- Consistent broker/server-time handling

Exit criteria:

- New-trade eligibility is correctly limited to configured London and New York windows.

## 1.6 News Filter

Goal:
Implement high-impact-news exclusion with configurable buffer and replaceable data source.

Deliverables:

- Pluggable news-source interface
- Configurable high-impact news exclusion window

Exit criteria:

- New trades are excluded for the configured buffer around high-impact news.
- Historical and live sources can be substituted without changing strategy logic.

# Sprint 2 — Strategy

## 2.1 Strategy Interface

Goal:
Define a strategy contract independent of execution and risk.

Deliverables:

- Replaceable strategy interface/contract
- Trade-intent representation that does not place orders or size positions

Exit criteria:

- Strategy code depends on analysis and filters, not broker execution or generic sizing.
- Another strategy can implement the contract without changing generic infrastructure.

## 2.2 Trend Pullback Strategy

Goal:
Combine analysis results into BUY / SELL / NO TRADE signals.

Deliverables:

- Version 1 Trend Pullback strategy implementation
- H4-direction, H1-zone, M15-confirmation signal composition

Exit criteria:

- Signals obey the documented trend, zone, and confirmation rules.
- The strategy outputs intent only and remains independent of execution and risk.

# Sprint 3 — Risk & Execution

## 3.1 Position Sizing

Goal:
Implement 1% configurable account risk.

Deliverables:

- Strategy-independent position-sizing service
- Configurable risk percentage

Exit criteria:

- Position size is calculated from the final risk specification using account equity/balance as specified.
- The default research target is configurable 1% risk per trade.

## 3.2 SL / TP Calculation

Goal:
Implement zone-based stop plus configurable buffer and configurable R target.

Deliverables:

- Long and short zone-based stop calculation
- Configurable stop buffer and reward-to-risk target

Exit criteria:

- Long stops are below support and short stops above resistance, including the configured buffer.
- The target defaults to configurable 2R.

## 3.3 Trade Execution

Goal:
Use MT5-native execution facilities.

Deliverables:

- Strategy-independent order execution service
- MT5-native order/deal integration

Exit criteria:

- Execution receives approved risk-aware trade instructions without strategy-specific conditions.
- Broker responses are handled and reported.

## 3.4 Trade Safety

Goal:
Prevent duplicate/conflicting entries and enforce execution rules.

Deliverables:

- Duplicate/conflicting-entry protections
- Execution-rule enforcement

Exit criteria:

- Conflicting or duplicate entries are rejected before placement.
- Safety decisions are logged.

# Sprint 4 — Backtest Validation

## 4.1 MT5 Strategy Tester Integration

Goal:
Validate full strategy through Strategy Tester.

Deliverables:

- Strategy Tester validation procedure and results
- Full-system tester integration

Exit criteria:

- The full strategy runs through MT5 Strategy Tester using the production strategy implementation.

## 4.2 Trade Logging

Goal:
Record every trade and its decision context.

Deliverables:

- Strategy-independent detailed trade records
- Decision-context logging

Exit criteria:

- Each trade record contains sufficient context for later review.

## 4.3 CSV Export

Goal:
Export backtest/live trade data for Excel analysis.

Deliverables:

- CSV exporter for detailed trade data
- Consistent backtest and live export schema

Exit criteria:

- Trade data exports to CSV for Excel analysis.
- The schema is usable in both backtest and live operation.

## 4.4 Bias / Simulation Validation

Goal:
Verify no look-ahead bias and consistent live/backtest strategy behavior.

Deliverables:

- Look-ahead-bias review
- Live/backtest parity validation results

Exit criteria:

- No historical decision accesses unavailable future information.
- The same strategy behavior is validated for backtest and live operation.

# Sprint 5 — Live Readiness

## 5.1 Demo Forward Testing

Goal:
Run E2 on demo.

Deliverables:

- Demo deployment and forward-test record
- Operational observations

Exit criteria:

- E2 operates on a demo MT5 account through the defined test period.

## 5.2 Restart / Recovery

Goal:
Correctly recover state after MT5, VPS, or EA restart.

Deliverables:

- Restart/recovery behavior
- Recovery validation procedure

Exit criteria:

- E2 recovers required state safely after MT5, VPS, or EA restart.

## 5.3 Broker / Prop Compatibility

Goal:
Handle symbol naming, contract specifications, server time, spread, commissions, and account restrictions where needed.

Deliverables:

- Compatibility handling for relevant broker/prop differences
- Validation notes for tested environments

Exit criteria:

- Relevant symbol, contract, time, cost, and account constraints are handled where needed.

## 5.4 Safety Controls

Goal:
Add operational safeguards for live/funded use.

Deliverables:

- Live/funded operational safeguards
- Safety-control validation

Exit criteria:

- Configured safeguards protect live/funded operation and are testable.

# Version 1.0 Exit Criteria

E2 must:

- Compile cleanly in current MetaEditor
- Backtest through MT5 Strategy Tester
- Use the same strategy implementation for backtest and live operation
- Detect H4 trend/range
- Detect H1 support/resistance zones
- Detect M15 confirmations
- Filter sessions
- Filter high-impact news
- Risk configurable 1% per trade
- Place SL beyond zone
- Target configurable 2R
- Execute and manage trades
- Export detailed trade data to CSV
- Operate on demo and funded/live MT5 accounts
- Allow future strategies to be swapped without rebuilding generic infrastructure

# Post-v1 Ideas

Only after Version 1.0 exit criteria are met, future work may consider additional strategies or research tooling through the same modular interfaces.
