# Install E2 EURJPY Gotobi v1.16

Current v1.16 source is included in `E2-four-live-recovery-source.zip`; follow [the recovery upgrade guide](LIVE_RECOVERY_UPDATE.md) for that package. The standalone v1.15 archive below remains an earlier Gotobi-only release.

This release adds Gotobi as a separate fourth EA. It does not replace the three existing EAs or change their risk inputs. Default Gotobi settings: 50-pip stop, 200-pip safety TP, entry 15:55 UTC, fix exit 00:55 UTC, Friday flatten 20:00 UTC, editable risk mode like Gold Fade: Fixed cash or Balance percent. Cash mode is the default; generic inputs 1000 account-currency units and 1% must be set for your account. Source installation requires MetaEditor compilation; no compiled EX5 is supplied.

## Laptop / VPS setup

1. Download and extract `E2-Gotobi-v1.15-source.zip` from the GitHub release. In the MT5 terminal you actually use to trade, choose **File → Open Data Folder**. Copy the extracted `MQL5` folder's contents into that terminal's `MQL5` folder, retaining the subfolders. This installs only Gotobi and its preset.
2. Open `MQL5/Experts/E2/EURJPYGotobi/EURJPY_Gotobi.mq5` in MetaEditor and press **F7**. Confirm zero compilation errors, then refresh MT5's Navigator. The `include` folder must stay alongside the entry file.
3. Open a **EURJPY M1** chart (use your broker's EURJPY suffix if present). Attach `EURJPY_Gotobi`. Load `MQL5/Presets/E2/EURJPYGotobi_50p_configurable.set` through the Inputs tab. Do not load the old fixed-1000 research preset.
4. Verify `InpBrokerWinterUTCOffsetHours` and `InpBrokerDST` against this trading server's year-round clock, then set `InpBrokerClockVerified=true`. DST enum: 0=fixed offset, 1=EU, 2=US. UTC+2 winter is 2 hours; these preset values are placeholders, not a verified broker profile. Comparing server time with UTC today alone does not establish the DST rule. The same verified profile on the existing E2 EAs can be reused if they run on this same server.
5. Confirm `InpStopPips=50`, `InpEntryUTCMinute=955`, `InpMagic=420603`. Choose **Risk Mode**: `E2_RISK_FIXED_CASH` (0) uses **Fixed Risk (account currency)** / `InpFixedCashRisk`; `E2_RISK_BALANCE_PERCENT` (1) uses **Balance Risk (%)** / `InpBalanceRiskPercent`. Enter your account allocation. The inactive amount is ignored. The preset’s 1000 / 1% are generic defaults, not the Monte Carlo allocation. Allow algorithmic trading in the EA properties and enable terminal **Algo Trading**. Keep MT5 connected on the VPS for entries and timed exits.
6. In **Experts**, confirm the installed Gotobi version (v1.16 for the recovery package), the risk_mode, fixed_cash_risk and balance_risk_percent you selected. Verify the printed broker-clock values and CSV location. A broker-clock verification error means initialization was refused. No immediate entry is expected unless it is an eligible date at the entry minute.

Existing MT5 chart inputs and saved presets override source defaults. Install just one instance per account for EURJPY with this magic; do not attach duplicates. Magic 420603 is distinct from the existing trio. On netting accounts another strategy on EURJPY prevents Gotobi entry. The three existing EAs' charts/settings can remain as installed.

## Schedule and reports

Buy before Japanese payment dates 5/10/15/20/25/30. Weekend payment dates roll back to Friday; Sunday entries are skipped. Japanese bank holidays are manually excluded with `InpExcludedJapaneseDates=YYYYMMDD|YYYYMMDD`; there is no automatic holiday calendar or rescheduling. The supplied empty exclusions preserve the tested rules. Entry grace is 60 seconds. Timed exits need tradable ticks and connection; missed entry windows are not caught up later. Broker-side SL and safety TP are sent with the entry order.

CSV files are in **Terminal Common Data Folder → Files → E2 → EURJPYGotobi**. Use `_Trades_T.csv` directly for independent trade and portfolio analysis; the E2 journal UI has been retired. `_Equity_E.csv` and `_Settings.csv` accompany it. Live equity samples reflect the whole account; the trade ledger contains only owned Gotobi positions. After restart, recovered earlier trades may have blank initial risk/R when the original conversion snapshot is unavailable; P&L remains recoverable.

## Risk interpretation and release checks

The earlier 0.23% equity-risk result is standalone Gotobi sizing guidance targeting approximately 10% DD99 over ten years under recent-history plus illustrative extra-cost stress. It is not a guarantee or a combined E2 portfolio drawdown target. Adding it to existing allocations adds exposure; no common portfolio loss cap is enforced. See `strategies/EURJPYGotobi/robustness/MONTE_CARLO_50.md`. The EA now uses balance for percentage mode, like Gold; it does not force the modeled equity-risk allocation. Balance and equity differ when positions are open. Fixed cash does not compound and does not inherit the percentage Monte Carlo estimate. Recent cost-stressed profitability is thin. No untouched-2026 or live validation is claimed by this packaging step.

Portable actual-EA and CSV/layout checks are run before publication. They are not native MQL5 compilation or a broker fill test; complete the MetaEditor check on installation.
