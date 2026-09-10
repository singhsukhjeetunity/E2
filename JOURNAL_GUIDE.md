# E2 Journal — short setup guide

## 1. Open it without a terminal

### Packaged Windows app (no Python or Git)

1. Open the repository's **Actions → Windows Journal** workflow.
2. Choose a successful run for `feature/standalone-journal`.
3. Download the **E2-Journal-Windows** artifact at the bottom; GitHub may require sign-in.
4. Extract the ZIP to a normal folder, such as `Documents\E2-Journal`.
5. Double-click **E2-Journal.exe**. Your browser opens the dark dashboard.

The executable is unsigned. Do not bypass an organisation's security restrictions; review your local policy if Windows blocks it. A failed or running workflow does not provide a tested executable.

### Source alternative (Python already installed)

1. On GitHub select branch **feature/standalone-journal → Code → Download ZIP**.
2. Extract the ZIP completely, outside the MT5 Experts folder.
3. Double-click **Open-E2-Journal.pyw**. If needed, choose **Open with → Python**; use Python 3.10 or newer.

No PowerShell commands, broker password, controller token, pip installation or Git setup are required for everyday use. Nothing has to be attached to an MT5 chart. You can use it on your laptop or VPS. It only listens on `127.0.0.1:8766`, so it is not exposed to the internet.

To reopen a running journal, double-click again or visit `http://127.0.0.1:8766/`. To stop it, use **Close journal app** in the dashboard. Closing the browser alone leaves folder reading running. Windows restart stops the app; double-click again afterwards.

## 2. Create an account

Go to **Accounts & allocations → Add or edit an account / dataset**.

- Name it clearly: broker + account login, or the exact backtest run.
- Select Eval, Funded, Personal, Demo or Backtest; enter the reporting currency.
- Starting balance means the balance **immediately before the imported history**, not today's balance.
- Record the report clock, e.g. “Broker server time, seasonal offset”. Dates are not converted automatically.
- Set daily allowance and Grade A/B/C percentages if useful. These are fully editable planning notes. Total can be below 100%; the remainder is reserve.

**One dataset per account; one separate Backtest dataset per test run.** Older E2 exports have no account login or currency field, so the app cannot infer these safely. Do not put eval, demo and backtest trades together. Type, currency and clock label are fixed after creation to protect imported records.

## 3. Import existing E2 CSVs

1. Select the correct account at the top.
2. Open **Import centre** and select `_T.csv` (trades), `_S.csv` (signals), or both.
3. Click **Preview imports**, review the detected rows, then **Confirm import**.
4. Review **Overview**, **Strategies** and **Trade journal**.

No renaming or column mapping is necessary. UTF-8, common Windows ANSI and BOM-marked UTF-16 exports are supported, with commas, semicolons or tabs. File limit: 24 MB and 100,000 rows.

- Re-uploading or renaming the same CSV does not duplicate trades.
- A conflicting trade ID blocks that file; it never silently overwrites history.
- Each file commits atomically. If one file fails in a multi-file import, earlier successful files remain saved and appear in Import history.
- Separate backtest runs cannot be added to the same dataset.
- Signals never count as trades. Open/non-final trade rows are excluded.
- Integrity flags are retained and shown; review them before relying on the results.
- Old `XAU_SF_REPORT_V1`, `LRB_REPORT_V1` and `ADXBB_REPORT_V1` reports work. Raw HistData price CSVs and generic broker deal exports are not compatible trade reports.

## 4. Get new reports from the EA

At a **safe planned restart**, enable `InpCsvExportEnabled`. Do not remove or restart the EA solely for this journal while an unresolved/open position is being investigated.

Current E2 writes reports when the EA shuts down or the tester finishes—not continuously after every trade. In MT5, use **File → Open Data Folder**, navigate up to the shared `Terminal\Common\Files\E2\Reports` folder. Usually:

```text
C:\Users\<Windows user>\AppData\Roaming\MetaQuotes\Terminal\Common\Files\E2\Reports
```

The `_T.csv` contains finalized trades from that EA session, including registered recoveries. It is not a full automatic broker-history export. Import all relevant session reports and check coverage.

### Optional automatic reading

In **Import centre → Automatically read a reports folder**, enter the absolute path to a folder containing **only that account's exports**. Leave pattern `E2_*_T.csv` for trades, or use `E2_*.csv` for trades and signals. Enable it once.

The app scans every 15 seconds and reads a file only after its size and modified time are unchanged across two scans. New or changed exports import automatically; duplicates are skipped. Results and failures appear in Import history / folder status. It does not alter the source files.

**The MT5 Common Files reports folder can mix multiple accounts and backtests.** If it is mixed, copy the right reports into an account-specific folder or upload manually. Filename symbol/config alone cannot reliably identify an account. The watcher does not make the EA generate missing exports or connect to MT5.

## 5. Daily workflow

**Import → Overview → Strategies → record notes/cash flows → backup.**

- Grade a strategy and record reference risk in Strategies. Apply actual risk or on/off changes manually in MT5.
- Record payouts and fees as external cash flows. They do not change trading P&L or reconstructed account balance.
- Record deposits/withdrawals when the broker balance changes. If a payout also reduces that balance, record both the payout and a withdrawal.
- Download a complete backup after important imports. Restore replaces the journal, first creates a safety backup, and pauses all watched folders for review.
- On Windows, data is stored separately at `%LOCALAPPDATA%\E2Journal\journal.sqlite3`. Keep it when replacing app files. Startup errors go to `journal.log` in the same folder.

## Metric limits

- Win rate: net-positive closed trades / all closed trades, including breakeven trades in the denominator.
- Expectancy: average `net_profit / actual_initial_cash_risk`; unknown risk is excluded and coverage shown. Never inferred from SL or TP.
- Profit factor: positive net results / absolute negative net results. No-loss samples are labelled, not given a fabricated finite ratio.
- Drawdown: cumulative closed-trade P&L from zero; exits sharing a timestamp are combined. This **cannot measure floating equity drawdown or certify prop-firm rule compliance**.
- R drawdown is hidden if any selected trade lacks valid initial risk. Streaks sort by exit time, with a stable trade-ID tie-break.
- Year/month counts use exit dates in the supplied reporting clock. Partial years are not extrapolated.
- Portfolio cash summaries exclude Demo/Backtest datasets and keep different currencies separate. No FX conversion or live balance feed is implied.

## CSV contract for another strategy

Download the blank template in Import centre. One row per fully closed position:

| Field | Meaning |
|---|---|
| schema_version | `E2_JOURNAL_V1` |
| trade_id | Stable unique broker position ID, not a changing export row number |
| strategy / config_hash | Strategy name and version/parameter-set identifier |
| symbol / direction | Broker symbol; LONG/SHORT or BUY/SELL |
| fill_time / exit_time | `YYYY-MM-DD HH:MM:SS`, consistent report clock |
| net_profit | Account-currency net result after all costs |
| actual_initial_cash_risk | Risk fixed at entry; blank if unknown |
| trade_status | `FINALIZED` |
| run_id | Required unique run label for Backtest datasets |

Do not append open trades with invented outcomes. For a broker export that lists individual deals, aggregate and reconcile the position first; the app deliberately does not guess.

## Validation performed

Automated checks cover imports, duplicate/conflict handling, financial metrics, unknown risk, account/run isolation, editable allocations, cash flows, stable folder reading, backup/restore and local HTTP access restrictions. Actual historical E2 exports are used locally to check adapter compatibility; private trade data is not included in the repository.

Windows packaging and offline smoke tests run in GitHub Actions. MT5 compilation and live broker acceptance of the separate EA protection fix remain separate from journal testing. No trading is needed to test the journal.
