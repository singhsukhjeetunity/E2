# ADXBB Indicator-Equivalence Validation

Sprint 2 implements custom Pine-style calculations and a validation-only CSV. It does not claim TradingView parity until rows from the same M5 OHLC feed are compared.

## Implemented mathematics

- True range: `max(high-low, abs(high-prevClose), abs(low-prevClose))`; the first processed bar uses `high-low`.
- Directional movement: +DM uses a strictly dominant positive up move; -DM uses a strictly dominant positive down move; otherwise zero.
- RMA: the first valid value is the SMA of the first `length` samples. Later values use `(previous * (length-1) + sample) / length`.
- DI: +DM, -DM, and TR are independently RMA-smoothed over `InpADXBB_DI_Length`.
- DX: `100 * abs(DI+ - DI-) / (DI+ + DI-)`; a zero denominator produces deterministic zero DX.
- ADX: RMA of valid DX values over `InpADXBB_ADX_Length`.
- ATR: independent RMA of TR over `InpADXBB_ATR_Length`.
- Bollinger basis: arithmetic mean of the last `InpADXBB_BB_Length` closes.
- Bollinger variance: population variance, `sum((close-basis)^2) / N`, never `N-1`.

With DI=7 and ADX=7, DI/DX first become valid after the seventh processed bar and ADX after seven valid DX samples (the thirteenth processed bar). ATR(14) first becomes valid on bar 14 and BB(20) on bar 20. Because all fields are required, the first signal-eligible state is bar 20, assuming valid continuous input samples.

## Validation export

Set `InpCsvExportEnabled=true`. Sprint 2 writes:

`E2_ADXBB_<symbol>_M5_INDICATOR_VALIDATION.csv`

under the terminal Common Files directory. It is explicitly a validation artifact, not the future production SIGNALS CSV. Columns are:

`timestamp,open,high,low,close,di_plus,di_minus,adx,bb_basis,bb_upper,bb_lower,atr,di_valid,adx_valid,bb_valid,atr_valid,is_ranging,long_signal,short_signal`

Warm-up rows are exported with blank unavailable values and explicit validity flags, allowing the first valid DI, ADX, BB, and ATR samples to be audited directly.

## TradingView comparison procedure

1. Use identical symbol/feed, M5 timeframe, timezone-independent bar-open timestamps, and a deterministic historical period with sufficient prior warm-up.
2. Export Pine values for the exact columns above at maximum practical precision.
3. Join rows by M5 bar-open timestamp; reject missing or duplicate timestamps before numeric comparison.
4. Compare OHLC first. Feed differences invalidate indicator conclusions for affected rows.
5. Compare DI+, DI-, ADX, basis, bands, and ATR. Record maximum absolute and relative difference per column.
6. Explicitly inspect the first valid DI, DX/ADX, ATR, and BB rows and at least ten known 20-bar Bollinger windows. Independently recalculate `sqrt(sum((x-mean)^2)/20)` to prove population variance.
7. Compare `is_ranging`, `long_signal`, and `short_signal` exactly. Numerical tolerance must not change the strict strategy operators.

Suggested diagnostic tolerance is `1e-10` absolute for indicator arithmetic when both platforms receive identical double inputs, plus a symbol-tick-aware tolerance for price outputs. Acceptance requires zero signal-decision mismatches except a separately documented boundary case where raw platform values differ within the numeric tolerance. Parameters must never be adjusted to force parity.
