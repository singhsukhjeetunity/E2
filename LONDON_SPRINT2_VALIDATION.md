# London Range Breakout — Sprint 2 validation

Date: 2026-09-03. Status: **synthetic validation passed; authoritative historical baselines blocked**.

No verified historical broker-time profile has been supplied for the requested data source. No Run A or Run B was performed. No parameter optimization, filter addition, commit, push, tag or release was performed.

## Evidence and limits

MetaTrader/MetaEditor build 6157. The integration harness ran 2024-01-02 through 2024-01-06 using M5 open-price event scheduling (`Model=2`). The terminal identified its quote source as **MetaQuotes-Demo**, not FivePercentOnline-Real. Quotes were used only as a container for controlled infrastructure tests. The harness explicitly injects artificial candidates and uses a synthetic clock. Its trades are NOT natural LRB signals, historical strategy samples, or evidence of profitability.

The production EA is not attached or enabled by these tests. Both harnesses reject non-tester initialization. The integration harness uses test magic 9900202 and $100 requested cash risk; these are test fixtures, not changes to production defaults. ATR and near-stop cases build requests only; they submit no additional trades.

Final runtime blocks:

```text
[LRB_SELFTEST] checks=1768, failures=0, testOnly=1, ordersSubmitted=0
[LRB_INTEGRATION_VERIFY] synthetic=1, checks=196, failures=0, simulatedRestarts=19, positionsOpened=4, recoveredTradesFinalized=4, authoritativeBaseline=0
[LRB_STATIC_VERIFY] activeFiles=23, oldAlphaIncludes=0, inputs=27, signalColumns=39, tradeColumns=54, brokerGuessing=0, weekendGates=PASS, diffCheck=PASS
[LRB_CSV_VERIFY] checks=118, failures=0, signalRows=4, tradeRows=4, synthetic=true
London independent reference: 84 transitions, 168 before/at-boundary comparisons, 0 mismatches against tzdata 2026.3.
```

The JSON CSV verifier prints an empty `failures` array when successful. The compact block above renders that as a count.

Final integration log time: 12:59:42 on 2026-09-03. No-order test log time: 12:50:27.

Journal:
`C:\Users\singh\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\logs\20260903.log`

## 1. Logic validation

- Completed-bar guards remain in engine initialization and evaluation; ATR requires a closed-bar shift >= 1. No intrabar alpha path was introduced.
- Range includes 00:00 through 07:55 London M5 opens, freezes after the 07:55 candle completes, and excludes the 08:00 candle.
- Strict close-above/high LONG and close-below/low SHORT tests pass; equality, wick-only, pre-window and 12:00-or-later candle opens do not qualify.
- Six winter/summer/UK-transition-adjacent dates, each with all 96 possible reconstruction split points, validate replay equivalence, extrema and immutable frozen state. Missing range history remains invalid and cannot signal.
- Actual production engine initialization/reconstruction is also tested against completed tester M5 history, not solely a second implementation of range logic.
- Static include traversal finds no active ADXBB/BB/ADX/EMA/Hybrid strategy modules. Historical files remain on disk but are not compiled into the current EA.
- Production planner LONG/SHORT opposite-range SL, Ask/Bid entry, closed-bar ATR(14) x 1.0 planning, and stop-level adjustments pass.
- TP uses 1.5 times actual-fill Original R, normalized to the symbol price grid. Thus an exact arithmetic target can differ by up to half a price tick after normalization.

Observed timing (first controlled trade):

```text
signal_bar_time=2024.01.02 08:00:00
signal_known_time=2024.01.02 08:05:00
planning_time=2024.01.02 08:05:00
request_time=2024.01.02 08:05:00
fill_time=2024.01.02 08:05:00
```

The other three controlled trades have the same 08:00 -> 08:05 separation on January 3, 4 and 5. Expired and premature requests are rejected.

## 2. Infrastructure regression

Runtime checks exercise the production sizer, planner, executor, position guard, recovery and reporter:

- Below-minimum and above-maximum volume requests reject; valid requested risk is sized to executable volume.
- Excess spread and disabled trading reject. Ask/Bid and authoritative deal fill agree.
- Open owned positions block another entry. A foreign-magic guard does not claim the position; a foreign-magic executor cannot close it.
- Recovered live SL/TP remain unchanged. Both direction examples pass.
- Weekend cutoff rejects an entry and closes the owned Friday position through the unchanged production `E2EnforceWeekendFlat` path.
- Deal-based finalization succeeds for all four recovered positions; three deliberately controlled test closes are `EXPERT`, the Friday close is `WEEKEND_FLAT`.
- Fresh recovered-only reporter instances reconcile cleanly after losing the original in-memory signal rows.
- End-of-run audit finds maximum one owned entry position per London day and zero duplicate-day/mapping violations.

The underlying risk sizer, execution safety, position guard and weekend-flat files have no diff from the retained implementation. Tests are not proof of real-tick slippage, partial fills, disconnections, broker-side rejection behavior, every account mode, or actual manual/foreign-EA coexistence. Those are not claimed as executed scenarios here.

## 3. Restart/state reconstruction

These are **simulated component/process-state reinitializations, not literal terminal restarts**. The harness invokes the exact production recovery `Initialize` called by `OnInit`, and the exact production range `Initialize`. It also resets planner candidate memory and creates fresh reporting instances. Test assertions retain comparison copies, but production recovery cannot access them.

| Scenario | Evidence |
| --- | --- |
| A: during range | At Jan 2 02:00, both fingerprints are `20240102|24|120|1.1045100000000001|1.1035400000000000|0|1`. No replayed candidate. |
| B: after range | At Jan 2 08:00, both fingerprints are `20240102|96|480|1.1045100000000001|1.1016300000000001|1|1`. No replayed candidate. |
| C: before execution | At 08:05 each day, reconstruction is identical and produces no startup replay. The engine discards pre-attachment completed signals. There is no persisted pending-candidate queue; candidate generation/planning/execution normally run synchronously in one OnTick. A literal process kill between those statements was not performed. The harness injects its independent test candidate AFTER reconstruction, not by resurrecting a lost candidate. |
| D: after today's closed trade | Recovery returns no open position, but actual history restores DAY_CONSUMED on all four days. |
| E: open position | Four entries are recovered from the actual saved record plus actual MT5 position/deal history. Ticket, identity, direction, fill, volume, SL, TP, R and profile digest agree; count stays one. A subsequent candidate is rejected as DAY_CONSUMED. |
| F: weekend cutoff | Jan 5 23:30: production recovery rediscovers the open position, newly initialized weekend protection recognizes cutoff, owned ticket 8 is closed with deal 9 and WEEKEND_FLAT; a new candidate is rejected. |

Fingerprint fields are day, eligible bar count, next minute, high, low, frozen, valid. The 19 counter includes range and recovery reinitializations; it is NOT 19 independent operating-system process restarts.

Additional actual-history test: at January 3, 4 and 5 00:05 server time, a separate synthetic +02 adapter still reconstructs the preceding entry's London-day lock, while the synthetic UTC adapter correctly sees a new London day. All three pass using only already-existing deals, with no future history.

### What survives

- MT5 positions: ticket/identifier, ownership, fill, volume and live SL/TP, held by the tester's simulated trade server.
- Actual MT5 deal history: authoritative entry and exit deals, held by the tester.
- Production recovery record: `E2_ADXBB_STATE_9900202_EURUSD.csv` in the **tester agent's local MQL5\Files sandbox**, NOT Common Files. Legacy filename is unchanged; payload schema is E2LRB1. It contains the existing persisted trade identity, entry, submitted SL, Original R, target, cash risk and London range/profile fields. It is cleared by normal production reconciliation after finalization.
- M5 price history and explicit configuration/profile files. Range state is rebuilt from completed M5 history; daily locks are rebuilt from deals, not the recovery CSV.

Expected local recovery location for this agent:
`C:\Users\singh\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\MQL5\Files\E2_ADXBB_STATE_9900202_EURUSD.csv`

No production recovery-persistence format or trading semantics were changed. The 16-decimal text serialization of Original R introduces a binary round-trip delta of `6.93889390390722838e-18` in these fixtures. Before and after both print `0.0200300000000000`. Comparisons use a declared 1e-15 tolerance; bit-for-bit double equality is **not** claimed. Actual SL/TP prices compare exactly and are not modified by recovery.

## 4. Broker-time validation

Only synthetic profiles, all `test_only=1`, `expected_server=E2_TEST_ONLY`, coverage `[2023-01-01,2025-01-01)`:

- `fixed.profile`: synthetic UTC+00 identity clock.
- `transitions.profile`: synthetic +02/+03 transitions on the UK dates.
- `different_dst.profile`: synthetic broker transitions on March 10 and November 3, different from UK's March 31 and October 27 dates in 2024.
- `unordered.profile`: intentionally invalid transition order, rejected.

Fixtures installed under:
`C:\Users\singh\AppData\Roaming\MetaQuotes\Terminal\Common\Files\E2\Tests\LondonSprint1\`

Verified: winter/summer composition, UK spring and autumn boundary instants, broker/UK differing transition dates, inclusive coverage start, exclusive coverage end, uncovered time rejection, spring gap rejection, autumn ambiguous-time rejection, wrong server rejection, missing profile rejection, and test profile rejection in non-tester mode.

Main synthetic digest:
`103DF1783D0A9C37824FF6EB2A9EDA84DE7B70F4379F6F8A15D220C051F59E6F`

London data remains pinned IANA 2025b, supported 1996 through 2037. An independent tzdata 2026.3 comparison found no offset mismatches at all 168 transition boundaries. This does NOT verify any broker's historical offset policy.

## 5. Reporting validation

Schemas unchanged: SIGNALS 39 columns, TRADES 54 columns, LRB_REPORT_V1. Config hash `FE2CD588` for the controlled test setup; 25 behavioral hash fields unchanged.

Final pair:
`C:\Users\singh\AppData\Roaming\MetaQuotes\Terminal\Common\Files\E2\Reports\E2_EURUSD_0102_FE2C_4_S.csv`
`C:\Users\singh\AppData\Roaming\MetaQuotes\Terminal\Common\Files\E2\Reports\E2_EURUSD_0102_FE2C_4_T.csv`

All 118 read-only CSV checks pass: schema widths/version, hash, linking IDs, London date under the explicitly synthetic clock, range extrema/width, direction, signal time/close/distance, timing separation, fills, SL, Original R, tick-rounded TP, net arithmetic, realized R and clean integrity flags. The final pair is value-identical to the preceding already-audited pair. No existing report was overwritten; production filename collision handling selected suffix 4.

The SIGNALS/TRADES pair is the continuous observer's record of the injected fixtures. The independent fresh-restart reporter was tested in memory without inventing pre-restart signal rows. Missing pre-restart planning quotes/timestamps are not reconstructed or claimed. Range correctness is tested separately against the engine; injected CSV range prices are deliberately artificial.

Example financial check: actual cash risk 80.12, first controlled trade net -1.72, reported R -0.021468 = net / actual initial cash risk rounded to six decimals. Requested risk was 100; executable volume-step rounding explains the lower actual risk. These figures are bookkeeping fixtures, not performance statistics.

## 6–12. Authoritative profile and raw baselines

**BLOCKED. No verified historical profile used or installed by this task.**

Run A 08–12, Run B 08–16, totals, annual statistics, LONG/SHORT performance, hour distributions and incremental 12–16 contribution are all **not run / unavailable**. Synthetic test outcomes must not substitute for any requested baseline statistic.

Next prerequisite: verified coverage and UTC transition schedule matching the actual historical EURUSD source, plus selection of that same source in the tester. The current integration terminal identifies MetaQuotes-Demo; it must not be assumed to be the requested FivePercentOnline-Real history. Only then run the two requested real-tick variants from 2020 through the reliable endpoint with identical non-window settings and the production fixed-cash convention.

## 13. Genuine defects corrected

1. **Empty holiday interval caused INIT_FAILED.** Jan 2 initialization asked for the preceding two calendar days, which contained no bars. CopyRates returned -1 and the engine treated it as unavailable history. The fix accepts an empty interval only when a separate closed-bar history query succeeds and proves the last closed bar predates that interval. Other history failures still fail closed; incomplete-day signal suppression is unchanged.
2. **Recovered trades falsely counted as orphans.** Fresh reporter initialization has no pre-restart signal rows. Its verifier counted the legitimate recovered trade as an orphan. The check now exempts explicitly recovered registrations, while retaining orphan detection for non-recovered trades. Reproduced four failures before the fix, zero afterward.
3. **Blank normal exit reasons.** Zeroed MQL string state was treated as a nonempty exit override. The reconciler now tests StringLen rather than comparing that state to an empty literal. Normal closes now derive EXPERT from actual exit deals; explicit WEEKEND_FLAT overrides remain preserved. CSV evidence confirms all four exit reasons populated.

No alpha changes, filters, stop/target variants for performance testing, or configuration default changes were made.

## 14–15. Compile and static results

E2.mq5: **0 errors, 0 warnings** (7179 ms).
E2LondonSelfTest.mq5: **0 errors, 0 warnings** (1707 ms).
E2LondonRecoveryTest.mq5: **0 errors, 0 warnings** (5356 ms).
`git diff --check`: **PASS**. Git's LF/CRLF conversion notices are separate from compiler diagnostics.

Sprint 2 production edits: `include/strategy/E2LondonBreakoutEngine.mqh` (empty-interval defect plus read-only state fingerprint), `include/reporting/E2TradeReporter.mqh` (two reporting defects).

Test/document edits: `tests/E2LondonSelfTest.mq5`, `tests/E2LondonRecoveryTest.mq5`, `tests/london_recovery.ini`, `tests/profiles/different_dst.profile`, `tests/profiles/unordered.profile`, `tests/check_london_csv.mjs`, this report. Existing Sprint 1 and earlier working-tree changes were preserved.

## 16. Is the raw strategy worth further investigation?

**Not determined.** Infrastructure test success establishes neither expectancy nor an edge. Complete the verified-profile A/B baseline before deciding whether further strategy research is warranted. Overall Sprint 2 remains incomplete at that explicitly blocked historical stage.

## Reproduction

Compile the two harnesses with MetaEditor. Install the four exact labelled test fixtures in the Common Files fixture directory without overwriting unrelated files. Use `tests/london_selftest.ini` and `tests/london_recovery.ini` for the no-order and controlled-order tests respectively. Never substitute these profiles for a production/history profile.

For the read-only CSV audit, pipe JSON containing PowerShell `Import-Csv` arrays named `signals` and `trades` into `tests/check_london_csv.mjs` with Node. The verifier is intentionally for this four-trade synthetic fixture, not a baseline analyzer or optimizer.
