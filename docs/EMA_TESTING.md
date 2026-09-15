# EMA pullback — chart and tester setup

Entry: `strategies/EMAPullback/EMA_Pullback_Long.mq5`, version 0.20.
Copy the complete `strategies` folder into `MQL5/Experts/E2`, retaining its subfolders. Compile the entry in MetaEditor.

## Run on a chart

1. Select the intended symbol. The EA internally builds M30 bars from completed M1 data; the chart timeframe does not change its signal rules.
2. Set the verified broker clock policy and winter UTC offset. There is no indicator-seed input.
3. Set cash risk, spread/deviation limits and a unique magic number for this strategy instance. Enable algorithmic trading in MT5 and the EA properties when you want orders placed.
4. Attach the EA. `WARMUP_WAIT` means history is still loading; `WARMUP_READY` means the initial history has been processed. The EA skips the signal already present at attachment, then waits for a new eligible signal.

Demo, eval/funded and personal real accounts use the same signal, risk, protection, execution and recovery logic. Account mode only labels report filenames. Different feeds, spreads, permissions and contract specifications can still produce different fills/results.

## Automatic history warm-up

The EA requests `30 * max(100, 20 * longest indicator period) + 1440` completed M1 bars: **31,440 at default settings**. EMA/ATR lengths are limited to 1,000. It retries when history is unavailable or shorter than required; no entries occur before warm-up. It does not require history back to 2022. Existing tracked positions are reconciled before warm-up and managed by tick/trade events and a one-second timer.

The indicator formulas, M30 aggregation and entry/exit rules remain the same. A finite automatic warm-up replaces the old fixed 2022 seed, so rerun the original backtest before comparing results; numerical identity with old runs is not assumed.

## Restart recovery

A checksummed checkpoint is written through a temporary file before submitting an order, then updated after confirmation, closes and state changes. It preserves the trade ID, pending intent, position identity, original SL/TP and cash risk, exit deadline and last exit minute. Confirmed saved protection is checked/restored against the broker position. Closed-while-offline positions are reconciled from deal history. Ambiguous submissions are never resent.

Runtime files are `E2_EMA_STATE_<scope>.dat`, its temporary file and a lock file. Demo and real terminals share the same Common Files location; the scope includes broker server, account, symbol and magic. An exclusive lock prevents duplicate instances using the same scope. Tester agents use isolated local state, reset at each test start. Operational files are separate from the two simple CSV folders.

Missing/corrupt state with an open matching position, multiple matching positions or changed inputs while a trade/stopped state is retained cause explicit initialization failure. Restore the original inputs/checkpoint and reconcile the account; do not delete state while an order or position is unresolved. A stopped state remains stopped across restarts. Only reset a stopped checkpoint when the account is confirmed flat and the cause is resolved.

On netting accounts, entries are blocked while another position/order occupies the symbol. Different strategies cannot hold independently opposed positions on one netting symbol. Manual/foreign entries merged into a tracked position require manual reconciliation; the EA does not guess ownership.

## Reports and regression checks

Exports remain in `E2/EMAPullback/` with a unique filename prefix per run. Trade reports are updated after settlement and on detach; restored trades retain their original trade IDs. See [CSV layout](CSV_EXPORTS.md).

```sh
python tools/analyze_run.py "<EMA-folder>/<prefix>_Trades_T.csv" --equity "<EMA-folder>/<prefix>_Equity_E.csv" --start 2022-07-01 --end 2026-01-01
```

Use actual tester bounds; the end is exclusive. The analyzer is for one tester run, not mixed chart sessions.

Before deployment, compile in MetaEditor and verify on MT5:

- Original baseline with identical data, inputs and dates; inspect any warm-up-related differences.
- Attachment with available, missing and delayed M1 history.
- Restart with an open trade, pending confirmation and a trade closed while offline; no duplicate order, matching initial risk/protection and deadline.
- Rejected closes/protection changes and same-symbol netting conflicts.
- Identical configuration on demo and real-account settings: no account-type branch in trading rules.

Portable tests exercise the actual checkpoint/storage functions, history aggregation/warm-up and entry submission code against deterministic fake APIs. These do not compile the whole MQL5 EA or replace broker-side tests.

The exchange calendar remains explicitly limited to **2022–2026**. Scheduled exits use the earlier cash-session deadline or broker session end minus the buffer. More than 60 seconds overdue flags the trade and stops new entries; close attempts continue. Failed closes retry every five seconds. End-of-test liquidation remains explicitly flagged.
