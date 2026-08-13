# E2 Roadmap

## Completed through Sprint 6.1

- Foundation and modular MQL5 architecture
- Closed-bar multi-timeframe market data; H4 trend/range + ADX; H1 zones; M15 confirmations
- Setup lifecycle, London/New York filtering, deterministic trade planning, native position sizing, and MT5-native execution
- Spread-boundary precision correction and existing-position short-circuit
- Finalized E2 trade reporting, including unresolved-trade exclusion
- **Sprint 6.1 — Backtest Statistics & Summary: verified**

Sprint 4.6 historical news filtering is runtime verified.

## Sprint 6.2 / 6.2.1 / 6.2.2 / 6.2.3 — MT5 Visual Backtest Overlay: accepted with MT5 limitation

The audit-only native chart-object layer is implemented and accepted. Sprint 6.2.1 uses native timeframe visibility for H4 context, H1 zone/setup, and M15 confirmation/execution views. Sprint 6.2.2 adds Strategy Audit, All Trades, and Single Trade modes. Sprint 6.2.3 identifies the E2-attached audit chart and its layers with a non-interactive instruction label. The accepted MT5 limitation is that visual audits may require separate H4/H1/M15 Tester runs; E2 does not programmatically change the attached chart period because that can reinitialize the EA. Visualization remains observational and cannot affect decisions.

## Sprint 6.3 — Visual + Mechanical Integrity Audit: VERIFIED

The integrity audit is recorded in [INTEGRITY_AUDIT.md](INTEGRITY_AUDIT.md). It found no established source-level mechanical defect and confirms closed-bar access, native execution/reporting, and visualization isolation. The required manual checks were accepted, closing the mechanically verified engine phase. This does not establish a trading edge.

## Then

1. Sprint 7.1 — Large-Sample Baseline Backtesting
2. Sprint 7.2 — Edge Decomposition / Diagnostics
3. Sprint 7.3 — Parameter Robustness / Sensitivity
4. Sprint 7.4 — Out-of-Sample / Walk-Forward Validation
5. Sprint 7.5 — Multi-Period / Multi-Pair / Regime Validation
6. Sprint 8.x — Forward/demo/live readiness

## v1.0.0 baseline

E2 v1.0.0 freezes the mechanically verified backtesting and execution engine before Sprint 7 begins. Sprint 7 strategy research, parameter experiments, and future market/strategy modules must proceed in later branches and versions so results remain traceable to this baseline.

No large-sample edge, robustness, out-of-sample, or forward/live-readiness conclusion is currently justified.
