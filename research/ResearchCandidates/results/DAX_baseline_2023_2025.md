# DAX Gap Reversal: rejected baseline

User decision, 2026-10-08: the implementation is not worth rescuing. Rejected from shortlist; no parameter optimisation or promotion. No remote removal requested yet. EURJPY Gotobi is the only retained candidate after the initial five-candidate screen.

Sources: uploaded DE40_Test_5053221205_1672531200_106_0 Trades, Equity and Settings CSVs. Read-only pandas analysis; original uploads unchanged.

Settings report EA v1.10 (not latest v1.12), fixed cash risk 1000, initial balance 100000, stop 3 ATR, target off, entry window 180 minutes, Berlin reference session 08:00–22:00 with EU DST and broker UTC+2/EU DST. Historical clock accuracy and tick model remain unverified.

Observed ledger: 159 finalized trades, no integrity flags, -36.66451140R, average -0.23059441R/trade, R profit factor 0.64673608, win rate 33.3333%. Cash net -36639.28 reconciles exactly to balance falling from 100000 to 63360.72. Sampled equity drawdown approximately 37.73055%. Commission and fee zero; gross -35173.69 plus swap -1465.59 produces net -36639.28. These are source-run observations, not validated continuous-history results.

| Entry year | Trades | Net R |
|---|---:|---:|
| 2023 | 52 | -23.89286533 |
| 2024 | 53 | -6.97736798 |
| 2025 | 54 | -5.79427809 |

The equity export jumps from 2025-07-22 21:02:30 UTC to 2025-09-09 11:38 UTC, approximately 48.6 days. Longest trade holds 112.62 hours, inconsistent with ordinary same-session exits and requiring Journal/tick availability checks if pursuing further. CSVs cannot establish root cause. Because performance is strongly negative across all years, the user elected to stop pursuing this reconstruction without repairing/retesting it. This does not establish that every original DAX gap-reversal strategy lacks an edge. Keep evidence and unresolved limitations; do not invent corrected performance by deleting gap-affected trades.
