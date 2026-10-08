# Candidate elimination and promotion mandate

User instruction, 2026-10-08: assess the five research candidates sequentially, starting with EuroFX Extreme Reversal. Look for a real edge without overfitting; eliminate unwanted candidates. Only survivors should eventually move from research/ResearchCandidates into strategies. Existing production strategies remain untouched.

## Order

1. EuroFX Extreme Reversal (EURUSD) — ELIMINATED; EA removed on user instruction
2. US Index Daily IBS — ELIMINATED; EA removed on user instruction
3. EURJPY Gotobi — RETAINED for later optimisation; not yet promoted
4. S&P 500 Failed Breakout — REJECTED from shortlist; source file retained pending explicit removal
5. DAX Gap Reversal — REJECTED from shortlist; source retained pending explicit removal

## Evaluation rules

- Start with the documented default rules and realistic broker costs. Verify native compilation, historical feed clock, data coverage, execution and CSV integrity before judging performance.
- Use the existing E2 historical feed where available. First assess 2022–2025; keep 2026 reserved for a final out-of-sample check after freezing the candidate rules. Do not tune to the holdout.
- Review net expectancy, trade count, profit factor, yearly/subperiod stability, concentration of profits, drawdown and sensitivity to worse costs.
- Use a small, documented set of nearby parameter checks to assess stability, not a broad search for the best equity curve. Reject narrow parameter peaks or repeated rule changes that rescue a failing candidate. If a genuine implementation error is found, correct and document it before rerunning.
- Do not attribute a publisher's statistics to these research reconstructions. No candidate is currently validated.
- For survivors, check actual return correlation and contribution to the three-system E2 portfolio; evaluate combined drawdown and Monte Carlo before promotion. A new market or mechanism alone does not establish diversification.
- Record each verdict and evidence before moving on. Do not delete failed research records automatically.
- Move only validated survivors to strategies on a dedicated branch once the sequential evaluation is complete; adapt packaging/tests without altering production strategy behavior. Promotion does not authorize live attachment, changing portfolio allocations or merging to main.

## Current state

EuroFX Extreme Reversal: eliminated on user instruction after its 2023–2025 baseline returned -2.62R, PF 0.86, 43.2% winners. Removed the EA from the remote research branch; retained the result record. Tester-model concerns remain unresolved, so this rejects the implementation from the shortlist without claiming the entire source family lacks an edge. No further optimisation or time-range expansion.

US Index Daily IBS: eliminated on user instruction after weak observed 2023–2025 results (+3.40R, PF 1.24, sampled equity DD 4.71%) and a prolonged data/export gap. EA removed from the remote research branch; result record retained. No further tuning. The gap remains unresolved, so this is a shortlist decision, not a clean verdict on the whole IBS strategy family.

EURJPY Gotobi: user retained it after reviewing run 1451606400_140_0 (2016–2025), with 709 finalized trades, +49.82R, PF 1.40 and 57.8% winners. Sampled equity drawdown 5.63% at cash risk 1000 on starting balance 100000. Trade P&L reconciles to balance; zero commission and empty Japanese holiday exclusions remain to validate. Keep it in research and defer all optimisation until the remaining two candidates have been screened. No promotion or live deployment yet.

S&P 500 Failed Breakout: user rejected it and requested steps for the final candidate. Uploaded trade ledger run 1672531200_234_0 contains 346 finalized trades, -11.76698572R, PF 0.91423011 and 41.62% winners. This quick ledger check is not a full data/clock/cost audit. No optimisation or promotion. No remote deletion requested on this turn.

DAX Gap Reversal: user rejected it. Uploaded v1.10 run 1672531200_106_0 contains 159 finalized trades, -36.66451140R, PF 0.64673608, 33.33% winners and negative results in all three years. Cash P&L reconciles to balance. A July–September 2025 export/data gap remains unresolved, so no clean full-period performance claim is made. No rescue optimisation or promotion. No remote deletion requested on this turn.

Initial five-candidate screen is complete. Only EURJPY Gotobi is retained for further research. Next phase: validate its feed clock, continuity, costs and Japanese calendar, then assess a small predeclared robustness set and E2 portfolio contribution before any move into strategies. Do not broadly tune rejected candidates.
