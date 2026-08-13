# E2 Roadmap

## Completed through Sprint 6.1

- Foundation and modular MQL5 architecture
- Closed-bar multi-timeframe market data; H4 trend/range + ADX; H1 zones; M15 confirmations
- Setup lifecycle, London/New York filtering, deterministic trade planning, native position sizing, and MT5-native execution
- Spread-boundary precision correction and existing-position short-circuit
- Finalized E2 trade reporting, including unresolved-trade exclusion
- **Sprint 6.1 — Backtest Statistics & Summary: verified**

Sprint 4.6 historical news filtering is implemented and compiles cleanly, but remains manually runtime-unverified.

## Sprint 6.2 / 6.2.1 / 6.2.2 / 6.2.3 — MT5 Visual Backtest Overlay: implemented, manual verification pending

The audit-only native chart-object layer is implemented. Sprint 6.2.1 uses native timeframe visibility for clean H4 context, H1 zone/setup, and M15 confirmation/execution views on the Tester chart. Sprint 6.2.2 adds Strategy Audit, All Trades, and Single Trade modes with a compact trade audit panel and execution-only context in practical review modes. Sprint 6.2.3 identifies the single E2-attached audit chart and its H4/H1/M15 layers with a non-interactive instruction label; safe switching uses MT5's native chart timeframe selector after pausing/completing the test because runtime chart-period changes reinitialize the EA. Separate Tester chart tabs are not synchronized E2 audit charts. It must consume existing E2 state and never affect decisions. Manual visual and enabled-vs-disabled regression verification remains required.

## Then

1. Sprint 6.3 — Visual + Mechanical Integrity Audit
2. Sprint 7.1 — Large-Sample Baseline Backtesting
3. Sprint 7.2 — Edge Decomposition / Diagnostics
4. Sprint 7.3 — Parameter Robustness / Sensitivity
5. Sprint 7.4 — Out-of-Sample / Walk-Forward Validation
6. Sprint 7.5 — Multi-Period / Multi-Pair / Regime Validation
7. Sprint 8.x — Forward/demo/live readiness

No large-sample edge, robustness, out-of-sample, or forward/live-readiness conclusion is currently justified.
