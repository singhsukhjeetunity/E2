# System 5 research: Nasdaq 90-minute opening-range breakout

**Research branch only. Not merged into main. Do not deploy on a funded/evaluation account.**

Source entry: \`strategies/NQOpeningRange/NQ_Opening_Range.mq5\`. MT5 EA with standalone M5 data, risk sizing, tick-based breakout execution, broker-time translation, daily entry counting, protective SL/TP, and short / fifth-session long exits.

## Baseline (from external published strategy)

- NQ opening range: 09:30–11:00 New York time (18 complete M5 bars).
- Entries: above range high / below range low from 11:00 until **before** 15:25 NY; max two entries per NY day, one open position on the symbol at a time.
- Fixed stop 100 **index price units**, fixed target 200 index units (nominal 2R).
- Shorts exit at 15:30 NY; longs exit at 15:30 NY on their fifth weekday session if not stopped/targeted first.
- Defaults: cash risk 1000 in account currency, or balance-percent risk selectable, with 15% margin buffer. **Entries are disabled by default.**

### Important deviations / limitations

1. Original corrected Python simulator detects intrabar breakout from 5-minute high/low and assumes a stop-fill at the range boundary (or a gap-open). This EA enters at the **first tradable tick observed beyond the range** using a market order; no guaranteed stop price. Results will differ.
2. The simulator counts actual CME sessions. This EA counts **weekdays** for fifth-session expiry; exchange holidays/early closes are not implemented. This can extend or shorten holds around holidays. Shorts and fifth-session longs require an available tick/connected terminal near the close.
3. The original backtest uses futures and $20/contract round-trip modeled costs. MT5 CFD pricing, contract value, spreads, swaps and commissions are broker-specific; **do not reuse the author's performance figures**.
4. The source's CME trading-day mapping, intrabar exit sequencing and full multi-year data reconciliation are not yet reproduced in MT5. Protective broker SL/TP manages overnight risk while the terminal is connected or disconnected (subject to broker execution).
5. No portfolio-wide daily risk limiter, account-level DD guard or journal CSV integration is provided in this research-only version. Existing E2 systems are unchanged.
6. Time conversion uses explicit historical broker UTC offsets (winter/summer) and EU/US DST rules, with New York DST handled automatically (US rules 1987–2006 and 2007+). Before 1987 historical DST rules are not modeled. DST repeated hours can be ambiguous.
7. If an entry request returns a **placed/unconfirmed** response, it is blocked for the rest of that day rather than blindly resent. An ambiguous exit response blocks further closes until the position disappears. Confirm orders manually in the Experts tab; do not restart to bypass broker uncertainty.
8. The EA checks open orders/positions on the symbol, and will not open if another EA has a position on the same symbol. This is deliberate on netting accounts.
9. If minimum broker volume exceeds the selected risk budget, the EA skips the trade instead of increasing risk.

## MT5 tester procedure

1. Copy the entire \`strategies/NQOpeningRange\` folder into \`MQL5/Experts/E2/NQOpeningRange/\`, then compile \`NQ_Opening_Range.mq5\` in MetaEditor.
2. Use a **USTEC/NAS100** or NQ-like symbol with adequate M5/tick history. Confirm its quote is in Nasdaq **index units** (not ticks or pips).
3. Select \`Every tick based on real ticks\`, choose M5, and test with a clean symbol/account (no other EAs on that symbol).
4. Verify broker historical server UTC offsets, DST schedule, and set \`InpBrokerClockVerified=true\`. Set \`InpEnableEntries=true\` **for tester only**. Do not infer the broker offset from the computer timezone.
5. Confirm range values and ET session timestamps in Experts (\`InpVerbose=true\`), stops, TP, volume and exit timing. Compare against the reference Python model before judging performance.
6. Do not optimize until the baseline reproduces sufficiently closely. Preserve 2026 as the untouched E2 out-of-sample period.

## Research provenance

Rule specification: https://github.com/giovannibrusco/nq-intraday-breakout
Bias audit: https://github.com/giovannibrusco/nq-intraday-breakout/blob/main/docs/bias-audit.md

This is an independent MQL5 implementation of the public rule description, not a translation of the Python source. The source author's reported backtests have **not** been replicated or validated in MT5.
