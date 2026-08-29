# E2 ADXBB Production Reporting

Schema version `ADXBB_REPORT_V1` produces two comma-separated, quoted, MT5-safe text datasets under the terminal Common Files directory at `E2\Reports`.

## Identity and filenames

Files follow `E2_ADXBB_<SYMBOL>_M5_<MODE>_<PERIOD>_<RUN_ID>_{SIGNALS|TRADES}.csv`. Mode is derived as `TESTER`, `DEMO`, `LIVE`, or `UNKNOWN`. Live/demo periods are `CONTINUOUS`; tester filenames use the effective first/last M5 timestamps observed by E2 because MT5 does not expose authoritative configured tester bounds to the EA.

`RUN_ID` is `YYYYMMDD-HHMMSS_<CONFIG_HASH>`. The eight-character uppercase hexadecimal configuration hash is 32-bit FNV-1a over a canonical pipe-separated string containing strategy/build identity, symbol, M5, all eight numeric ADXBB parameters, `OneTradePerDay`, risk mode and both risk values, magic, trading enabled, and all four execution-safety settings. Timestamps and counters are excluded.

Each EA initialization creates a new run ID. A recovered trade keeps deterministic candidate, execution, deal, and position identities; its `trade_id` is `ADXBB|<position_identifier>`. Thus a restart cannot synthesize another entry identity. The prior interrupted file remains a record of that invocation, while authoritative finalization belongs to the recovering invocation. Rows are buffered by deterministic identity and written once on orderly run close, avoiding duplicate candidate updates, transaction callbacks, partial exits, or repeated reconciliation.

## SIGNALS

There is one row per actual ADXBB candidate, never per candle. The stable schema includes run identity; candidate/strategy/symbol/timeframe/direction; immutable signal time and OHLC/DI/ADX/Bollinger/ATR snapshot; execution window; deterministic status/reason; planning quote, spread and stop adjustment; requested risk and volume; request/execution IDs; entry order/deal/position IDs; fill, Original R, target R and TP; final trade state; and recovery involvement.

Statuses are `EXECUTED`, `EXECUTION_FAILED`, `EXPIRED`, `POSITION_REJECTED`, `DAY_REJECTED`, `SIZING_REJECTED`, `SAFETY_REJECTED`, or `OTHER_REJECTED`. The reason retains the exact planner, sizing, or executor reason.

## TRADES

There is one row per successful, fully finalized entry. It contains run/trade identity, the linked immutable signal snapshot, planning quote and stop details, requested risk and calculated volume, authoritative entry identifiers/fill/volume/cash risk, immutable Original R and submitted TP, recovery counts, authoritative exit time/price/reason/deal count, financial components, realized R, status, and integrity flags.

All economics are aggregated from every MT5 deal carrying the position identifier. `gross_profit`, `commission`, `swap`, and `fee` preserve MT5 signs. `net_profit = gross_profit + commission + swap + fee`. Exit reason comes from the latest authoritative exit deal's `DEAL_REASON`. Financial `realized_r = net_profit / actual_initial_cash_risk`; the denominator is calculated from actual fill, submitted initial SL, filled volume, and MT5 symbol economics.

CSV errors increment reconciliation `writeFailures` and log deterministic errors. Reporting never changes candidate, sizing, order, SL, TP, recovery, or position decisions. The separate indicator-equivalence CSV remains a development artifact and is not mixed into production datasets.
