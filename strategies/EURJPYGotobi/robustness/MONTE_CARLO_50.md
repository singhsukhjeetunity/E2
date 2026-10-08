# 50-pip Gotobi Monte Carlo sizing

2026-10-08. User selected 50-pip stop / 15:55 UTC entry. Other settings remain as tested; no production defaults or allocations changed. This supersedes the earlier screen's provisional preference for 60 pips.

## Allocation

Risk is per trade as a percentage of current account equity, standalone Gotobi. It is not an allocation of capital to the strategy or a combined E2 portfolio result.

| Planning horizon | Practical risk per trade | Recent-history plus illustrative cost stress: 99th percentile maximum equity drawdown |
|---|---:|---:|
| 3 years, 213 trades | 0.40% | 9.37% |
| 10 years, 709 trades | 0.23% | 9.86% |

Use 0.23% if the 10% drawdown objective covers a horizon as long as the original backtest. Use 0.40% only for the explicitly shorter three-year planning horizon. No horizon-free drawdown cap exists. On initial equity 100000 these correspond to 230 and 400 of initial planned stop risk, respectively. Set `InpCashRisk=0`, `InpRiskPercent=0.23` (or 0.40 for three years), `InpStopPips=50`, `InpEntryUTCMinute=955`. Fixed cash sizing is different and does not inherit these percentage-risk estimates. Lot rounding, rejected orders and broker execution may affect realized exposure.

## Three-year sensitivity

100000 simulated paths per scenario. Percentages below include risk compounding and sampled intratrade equity excursions.

| Sampling pool / scenario | DD99 at 0.40% | DD99 at 0.50% | DD99 at 0.75% |
|---|---:|---:|---:|
| All 709 trades, mean block 5 | 5.19% | 6.46% | 9.56% |
| Recent 2024–2025, 142 trades, mean block 10 | 8.03% | 9.96% | 14.64% |
| Recent 2024–2025 plus hypothetical $7 per round-trip lot | 9.37% | 11.59% | 16.96% |

Full-history mean block sizes 5, 10 and 20 imply interpolated 10% DD99 risk limits 0.788%, 0.814% and 0.849%. The recent pool implies 0.505%; recent plus cost stress implies 0.428%. Recommend rounding down rather than using the exact simulated boundary. Independent seeds at 0.50% on recent history produced 9.90% and 9.96% DD99, showing sampling variation. This is not an uncertainty interval for the future process.

The recent cost-stressed three-year scenario has about 47% probability of ending below starting equity at 0.40%, and median total return only 0.26%. Small drawdown through sizing does not establish a strong edge. The uploaded results contain zero commission; $7/lot is illustrative, not a verified broker charge, and not a new spread/slippage execution simulation.

## Method and limitations

Source: 709 finalized nonoverlapping trades, 2016–2025, run 1451606400_172_0, with uploaded settings and minute-sampled equity. Cash net profit (including recorded swap) and equity excursions are normalized by each trade's actual initial cash risk. Starting account balance is 100000. Every trade has equity samples, minimum 9; sum of returns 62.35559796R. No future data or strategy-parameter optimization was used.

Stationary circular block bootstrap: choose a random trade; continue to its historical successor unless a geometric restart occurs with probability 1 / mean block length. Blocks preserve some short-range trade clustering, but do not model calendar gaps, changing trade frequency, cross-system dependence or unseen regimes. Circular wrap is an assumption. The recent-history pool is a stress scenario from only 142 trades, not an independent validation sample. Previously observed parameter selection remains a source of bias.

At each simulated trade, risk is proportional to entry equity. Track historical peak equity across trades, each trade's equity maximum/minimum and settlement. For within-trade peak-to-trough movement use a conservative bound: cash drop divided by entry balance rather than the potentially higher intratrade peak. This avoids misordering a minimum before its maximum; therefore it can modestly overstate sampled drawdown. Minute samples can miss tick-level extrema. The extra-cost scenario subtracts $7 times original lots divided by original cash risk from returns and equity lows, with an additional conservative excursion bound. Costs do not capture worse fills, gap losses or financing changes.

DD99 means 99% of these modeled paths have maximum drawdown no greater than the reported value. It does not guarantee a 1% real-world breach probability. Full ten-year historical data have already been observed; no 2026 holdout used. Combined E2 allocation requires synchronized histories of all four strategies and a portfolio drawdown model.

## Reproduce

`monte_carlo_50/` contains original-source SHA256 hashes, 709 normalized sampled trade paths, seeded simulation script and raw numerical results. Requires NumPy; extracting original exports additionally requires pandas. Run:

```bash
python monte_carlo_50/monte_carlo.py --output results.json
python monte_carlo_50/extract_paths.py --trades ORIGINAL_TRADES.csv --equity ORIGINAL_EQUITY.csv --output paths.npz
python monte_carlo_50/monte_carlo.py --paths paths.npz --output results.json
```

Official stationary-bootstrap reference: https://arch.readthedocs.io/en/stable/bootstrap/timeseries-bootstraps.html . Implementation uses NumPy with seeds stored in the script. Research documentation only; not live deployment.

## v1.15 installation update

The user requested the same configurable risk controls as Gold Fade. The EA now has `InpRiskMode` (0=fixed cash, 1=balance percent), `InpFixedCashRisk` and `InpBalanceRiskPercent`, with cash-mode generic defaults. Old `InpCashRisk` / `InpRiskPercent` preset keys no longer apply. The simulation above remains equity-compounding research; balance-percent mode uses balance instead, and fixed cash does not compound. Neither generic input default is a Monte Carlo sizing recommendation. See `docs/GOTOBI_INSTALL.md` for current input instructions.
