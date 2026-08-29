# E2 OBR Forward/Demo Test Guide

## Session selection

Record `InpOBRSession` before each run. London is 08:00–09:00 Europe/London; New York is 09:30–10:30 America/New_York. Confirm startup diagnostics map the chosen local OR through UTC into the broker clock, and confirm weekday suppression/day locking use that same local calendar. Do not change the session while an E2-owned position remains open.

This guide prepares E2 OBR for controlled demo testing. It is not authorization to trade real capital.

## Installation and startup

1. Copy the E2 source tree under the terminal's `MQL5/Experts/E2` directory and compile `E2.mq5` in MetaEditor. Require zero errors and warnings.
2. Open the intended broker's EURUSD M15 chart.
3. Load `presets/E2_OBR_FORWARD_DEMO.set`. Verify every displayed value; MT5 risk-mode value `0` means `FIXED_CASH`.
   Confirm `weekdayTrading=MON,TUE,WED,THU,FRI` unless the forward-test protocol deliberately excludes specific Europe/London weekdays.
4. Compare broker server time with independently known UTC in both standard and summer seasons. Replace the preset's +2/+3 values if the broker differs.
5. Confirm `[E2_PRODUCTION_TIME]` maps London 08:00–09:00 to the expected server interval. Do not proceed if it does not.
6. Set risk deliberately. The preset's $1,000 fixed cash value reproduces the engineering baseline and may be inappropriate for the demo account. Alternatively choose balance-percent mode and set its percentage.
7. Leave the news filter disabled for the canonical OBR baseline. The current OBR execution route does not consult the retained CSV news service; enabling it must not be interpreted as live or active OBR news protection.
8. Assign a magic number unique to this EA/account/symbol deployment.
9. Enable MT5 Algo Trading, attach E2, and allow live trading only after reviewing the inputs.
10. Require one `[E2_PRODUCTION_CONFIG]` and one `[E2_PRODUCTION_TIME]` line, successful initialization, correct balance/equity/risk, and no configuration, market-data, recovery, CSV, or news errors.
11. Keep MT5 or the VPS continuously connected. Debug mode is not required.

## Ongoing checks

12. Review normal journal errors and the optional decision/trade CSVs in `TerminalInfoString(TERMINAL_COMMONDATA_PATH)/Files`.
13. Verify the first candidate and first trade using the procedure below.
14. Confirm the market order initially has the broker-valid protective SL and that the fixed 2R TP is attached immediately after fill.
15. Confirm calculated volume and actual initial cash risk are conservative relative to requested risk.
16. Confirm no second successful entry occurs for the symbol during the same Europe/London day.
    Confirm any disabled weekday still builds its OR but produces only `DISABLED_WEEKDAY` suppression records and no candidate or trade.
17. Confirm finalized trade reporting reconciles with MT5 deal history.
18. Perform both restart tests before calling demo operation stable.

## Mandatory first-trade audit

Capture the trade CSV row, decision row, MT5 order/deals, and relevant M15 candles. Verify OR high/low from exactly the London 08:00, 08:15, 08:30 and 08:45 bars; breakout close, ATR(14), ADX(14), OR/ATR and breakout gap/ATR; candidate known-from and immediate-next-M15 request; side-specific Ask/Bid and entry gap; actual fill and slippage; structural and submitted SL; volume, requested and actual initial cash risk; Original R as fill-to-submitted-SL; and TP as fill ± 2R within one tick. Confirm the London-day lock after the fill.

## Restart tests

Open position: restart after a successful entry while it remains open. Require recovered candidate/day, actual fill, initial SL, immutable Original R and TP; then verify single finalization and realized R.

Closed same day: restart after the trade closes but before the London day ends, on a day with a later valid candidate. Require deal-history day-lock recovery and no second entry.

Do not claim either passed unless journal and deal evidence were retained.

## Do not go live with real capital until

- extended demo/forward testing has shown stable clock mapping, execution, protection, sizing, reporting and restart recovery;
- the first-trade audit has passed;
- broker offsets have been verified across DST changes;
- operational monitoring and loss limits outside the strategy are understood; and
- the chosen cash or percentage risk is appropriate for the actual account.
