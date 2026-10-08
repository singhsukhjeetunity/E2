# Candidate elimination and promotion mandate

User instruction, 2026-10-08: assess the five research candidates sequentially, starting with EuroFX Extreme Reversal. Look for a real edge without overfitting; eliminate unwanted candidates. Only survivors should eventually move from research/ResearchCandidates into strategies. Existing production strategies remain untouched.

## Order

1. EuroFX Extreme Reversal (EURUSD) — ELIMINATED; EA removed on user instruction
2. US Index Daily IBS
3. EURJPY Gotobi
4. S&P 500 Failed Breakout
5. DAX Gap Reversal

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

US Index Daily IBS: next candidate, awaiting unchanged-baseline MT5 test on the same 2023–2025 segment.
