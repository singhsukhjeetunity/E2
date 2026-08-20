# E2 Production Configuration

## Risk mode

`FIXED_CASH` is the baseline default. `InpFixedCashRisk=1000.0` reproduces the prior validated $100,000-test risk, which was calculated as one percent of the initial balance.

`BALANCE_PERCENT` resolves its requested cash risk at execution from the current MT5 account `BALANCE`; it does not use equity or an initial-test snapshot. Set `InpBalanceRiskPercent` to the desired positive percentage.

All Trend Continuation, Range Mean-Reversion, and Range Breakout orders use the same position-sizing path. A non-positive or non-finite selected risk value prevents initialization.

## Input ownership

The Expert Properties input panel is ordered for one-strategy-at-a-time research. Strategy-edge inputs are separated from shared filters, risk, execution, position management, and reporting controls. No v2.0.1 input was renamed, so existing `.set` files retain their parameter names. Review [INPUT_REFERENCE.md](INPUT_REFERENCE.md) before changing a shared market-model input.

Known frozen baseline mappings are visible rather than silently repaired: the zone and confirmation timeframe inputs do not replace the H1/M15 constants in strategy modules, `InpAdxEnabled` is reporting-only, and the H4 structure lookback has an existing 300-bar minimum.

## Historical news data

E2 reads `InpNewsDataFile` from the terminal common-files directory. Use the standalone native-calendar exporter and procedure in [NEWS_DATA_WORKFLOW.md](NEWS_DATA_WORKFLOW.md) to create the deterministic CSV before a news-enabled Strategy Tester run. The file contains UTC minutes; configure `InpBrokerUtcOffsetHours` for the tested broker/source clock and do not apply a second offset to the CSV.

The exporter is offline tooling and does not change the EA's session/news exclusion formulas, buffers, impact policy, or trade semantics.

## Release checklist

1. Select exactly the intended strategy and its valid management branch.
2. Verify the risk mode and selected positive input.
3. Run a tester pass and inspect `[RISK_MODE_VERIFY]`: request counters must match the selected mode, and invalid counters must be zero.
4. Confirm entry report rows show requested and original risk cash consistent with the selected mode.
5. Re-run baseline tests before changing any frozen research inputs.

## v2.0.1 release verification

1. Compile `E2.mq5` with 0 errors and 0 warnings and run `git diff --check`.
2. Confirm `[INPUT_CONFIG_VERIFY]` reports 84 total inputs, 30 global/operational/compatibility, 2 TC-exclusive, 4 RMR-exclusive, 7 RB-exclusive, and 41 shared. Confirm `[INPUT_CONFIG_VERIFY_2]` reports zero duplicates, zero wholly unconsumed inputs, three behavior-dead mappings, one shadowed input, and zero ownership conflicts.
3. Confirm `[INPUT_ISOLATION_VERIFY].detectedConfigurationOwnershipViolations=0`.
4. Run the all-enabled EURUSD 2024 fixed-$1,000 baseline and verify TC `85/9/7/7`, RMR `10/2/2/2`, RB `8/4/4/4`, 13 total trades, Net R `13.3268`, Max DD R `2.0217`, and Net Profit `13325.06`.
5. Confirm `GLOBAL_CAUSALITY_VERIFY.totalViolations=0`, maximum one concurrent E2 position per symbol, and all previously-zero namespace, identity, duplicate, reporting, and reconciliation violations remain zero.
6. Run TC-only, RMR-only, and RB-only configurations. Change one exclusive input at a time and confirm the other strategy engines do not read that value. Restore defaults before the integrated comparison.
7. Verify risk-mode routing independently for fixed cash and balance percent without changing the baseline comparison configuration.

Passing compilation and static checks does not constitute runtime regression verification; release remains blocked until the Strategy Tester steps above are executed and recorded.
