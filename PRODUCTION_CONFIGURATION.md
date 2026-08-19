# E2 Production Configuration

## Risk mode

`FIXED_CASH` is the baseline default. `InpFixedCashRisk=1000.0` reproduces the prior validated $100,000-test risk, which was calculated as one percent of the initial balance.

`BALANCE_PERCENT` resolves its requested cash risk at execution from the current MT5 account `BALANCE`; it does not use equity or an initial-test snapshot. Set `InpBalanceRiskPercent` to the desired positive percentage.

All Trend Continuation, Range Mean-Reversion, and Range Breakout orders use the same position-sizing path. A non-positive or non-finite selected risk value prevents initialization.

## Release checklist

1. Select exactly the intended strategy and its valid management branch.
2. Verify the risk mode and selected positive input.
3. Run a tester pass and inspect `[RISK_MODE_VERIFY]`: request counters must match the selected mode, and invalid counters must be zero.
4. Confirm entry report rows show requested and original risk cash consistent with the selected mode.
5. Re-run baseline tests before changing any frozen research inputs.
