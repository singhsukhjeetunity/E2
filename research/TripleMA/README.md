# TripleMA research EA

Separate EA in the E2 repository. The existing `E2.mq5` and every shared production header remain unchanged. This version runs **only in MT5 Strategy Tester**; attaching it to a demo or live chart fails initialization before it can submit an order.

## Exact setup (option 2)

At the first available tick of a new candle, use only the two most recently completed candles:

- **Buy:** fast MA was below or equal to medium MA on candle 2, then is above medium MA on candle 1; both fast and medium are strictly above slow MA on candle 1.
- **Sell:** fast MA was above or equal to medium MA on candle 2, then is below medium MA on candle 1; both fast and medium are strictly below slow MA on candle 1.
- Slow-MA alignment is required on the crossover candle, not on the preceding candle. Equality with slow MA fails the filter.
- One attempt per qualifying candle. No late entry when alignment appears several bars after the crossover. No replay of a pre-start crossover or bars missed across a gap.
- Entry uses a market order on the first available new-bar tick, within the configurable delay limit. It is not guaranteed to fill at the candle's exact open price.

| Input | Unoptimised starting default |
|---|---|
| Fast / medium / slow | 10 / 20 / 50 |
| MA calculation | EMA, close prices; selectable SMA/EMA/SMMA/LWMA and price input |
| Timeframe | Selected in Strategy Tester; M5 or higher. Start your review on M15 |
| Directions | Long and short |
| Stop | ATR(14) × 2 using completed candle 1; fixed broker-point distance also available |
| Take profit | Fixed 1R |
| Sizing | Fixed 100 account-currency risk; balance-% mode also available |
| Spread ceiling | 40 broker points, **not pips** |
| Entry deviation | 20 broker points; broker execution mode affects enforcement |
| Entry delay | Up to 10 seconds after the new candle starts |
| Weekend protection | Stop entries and attempt to flatten 30 minutes before broker Friday session close |
| Magic | 2026002, separate from E2's default 2026001 |

Defaults make the EA testable; they are not researched settings or a claim of profitability / 65% wins. Begin with individual backtests, not a large optimisation sweep.

## Execution and risk

- One position/order at a time across the test account, regardless of symbol or magic. This is not an account-wide live concurrency controller; live execution is disabled.
- Hard SL and provisional hard TP are included in the initial request. After authoritative fill reconciliation, TP is corrected once to the configured R from actual fill and the original SL. This is entry-price correction, not active management.
- Accepted, partial or ambiguous sends block further entries while confirmation is outstanding. The EA never retries an entry order to resolve uncertainty.
- Actual entry deals are aggregated by order/position; initial cash risk is calculated with `OrderCalcProfit`. Each fully closed position exports once, with costs from its broker deal history.
- No breakeven, trailing stop, partial profit-taking, time exit or opposite-crossover exit. Weekend flattening is the explicit exception.
- Volume is rounded down through E2's shared symbol/volume helper and rechecked against requested risk. Below-minimum sizing is rejected. Broker stop-distance restrictions can widen the initial SL; sizing uses that widened distance. Excessively close TP is rejected rather than changing the target R.
- Stops are not guaranteed maximum losses: gaps, slippage, commission, swap and fees can make net losses exceed 1R.
- No news filter, custom session filter or UTC-offset input in this first hypothesis. MA signals use the selected broker bars; Friday protection uses the symbol's server-time session schedule. Missing Friday schedule blocks entries and attempts a close.
- Session schedules may not reconstruct historical holidays. Weekend closure requires executable quotes and broker acceptance; inspect failures in the Journal.

## Run the first test

1. Pull branch `research/triple-ma` into the existing E2 repository.
2. Keep the repository folder structure together under your **test** MT5 `MQL5\Experts\E2` folder. Do not replace the EA running on your eval.
3. In MetaEditor open `research\TripleMA\TripleMA.mq5`. Press **F7**. Require zero errors/warnings; send any compiler output back for correction.
4. In MT5 press **Ctrl+R**, choose `E2\research\TripleMA\TripleMA`, then the desired symbol and **M15**.
5. Choose a development date range, sufficient starting balance for the cash risk, and **Every tick based on real ticks** where data is available. Save the test inputs as a `.set` file.
6. Run once with **Visualization** and inspect examples in both directions. The signal CSV includes the five MA values needed to verify the conditions.
7. Review the tester report and `[TripleMA][SUMMARY]` / `[TripleMA][CSV]` lines. Check for rejected signals, unresolved orders and remaining open positions; do not mistake an incomplete run for a clean result.
8. Import `_T.csv` and optionally `_S.csv` into a **new Backtest dataset** in E2 Journal. Each run gets a different run ID; do not combine different runs into one dataset.

Reports: MT5 common-files folder → `E2\Reports\TripleMA\E2_TripleMA_..._T.csv` and `_S.csv`. The `E2_JOURNAL_V1` schema is already supported by the journal. Reports include strategy `TRIPLE_MA`, config hash, run ID, signal identifiers and broker timestamps.

Exports occur on test shutdown and contain fully finalized positions only. If the tester hasn't supplied a closing deal, the position remains open/unresolved in the summary and is excluded from closed-trade metrics. `CLOSED_BEFORE_PROTECTION_VERIFIED` flags an immediate closure before the entry-reconciliation protection check could complete; inspect these cases in the tester log.

CSV export is intentionally disabled for optimisation passes to avoid concurrent common-file writes and excessive output. Rerun an individual pass to obtain auditable reports.

## Validation boundary

The new EA reuses `E2SymbolInfo`, `E2Logger` and `E2CsvExporter`. E2's gold-specific sizing/lifecycle modules are coupled to gold inputs and long-only metadata, so this research adapter uses separate bidirectional order planning and in-test fill reconciliation. It does not alter the live EA to force reuse.

Automated C++ tests exercise the actual shared TripleMA signal/target/risk functions. Python checks validate its CSV contract against the journal importer and guard the tester-only boundary. These are not an MQL compiler or a broker execution test. MetaEditor compilation, visual signal checks and MT5 backtests remain required.

References: [CopyBuffer ordering](https://www.mql5.com/en/docs/series/copybuffer), [OrderSend result semantics](https://www.mql5.com/en/docs/trading/ordersend).
