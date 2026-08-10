# Project Objective

E2 ("Emotionless Edge") is a modular MT5-native trading system that supports:

- Historical backtesting through MT5 Strategy Tester
- Demo forward testing
- Live/funded-account execution
- Replaceable trading strategies
- Centralized risk management
- Trade logging and CSV export

The system is designed so that backtesting and live trading use the same strategy implementation. Strategies must be replaceable without rebuilding the execution, risk, reporting, or MT5 integration layers.

# High-Level Architecture

```text
E2.mq5
    |
    +-- Analysis
    |     +-- Trend / Range
    |     +-- Support & Resistance
    |     +-- Confirmations
    |
    +-- Filters
    |     +-- Sessions
    |     +-- News
    |
    +-- Strategies
    |     +-- Replaceable strategy modules
    |
    +-- Risk
    |
    +-- Execution
    |
    +-- Reporting / Logging
```

`E2.mq5` coordinates these layers. Analysis provides market facts, filters decide whether trading is permitted, strategies produce trade intent, risk converts approved intent into risk-aware trade parameters, execution interacts with MT5, and reporting records results and decision context.

# Architectural Rules

- `E2.mq5` should act primarily as the application coordinator.
- Market analysis must be separated from strategy decision logic.
- Strategy modules must not directly place broker orders.
- Strategy modules must not calculate generic position sizing.
- Execution must not contain strategy-specific conditions.
- Risk management must be strategy-independent.
- Reporting/logging must be strategy-independent.
- Backtesting and live trading must execute the same strategy code.
- Strategy-specific parameters must be configurable.
- Generic infrastructure must remain reusable when strategies change.
- Avoid circular dependencies.
- Prefer small focused modules over large monolithic files.

# MT5 Foundation

E2 should use current built-in MQL5 / MetaTrader 5 capabilities where practical, including the MQL5 Standard Library and MT5 Strategy Tester, instead of recreating generic platform infrastructure unnecessarily.
