# London Range Breakout — Sprint 1

## Status and boundaries

Implementation and synthetic component validation only. No verified FivePercentOnline-Real profile is included. No authoritative historical strategy backtest has been performed.
No optimization, trailing stop, breakeven or direction inversion is added. Direction and range-width controls are explicit research inputs and default to the unfiltered BOTH-direction baseline.

## Execution flow

Completed M5 bars -> broker-time adapter -> London-local daily range -> strict close breakout -> London-day history lock -> existing planner/sizing -> existing executor/guards -> actual-fill Original R/TP -> existing recovery and reconciliation.

The pure E2LondonRange module consumes London timestamps only.
Default range is [00:00,08:00); breakout candle openings must fall in [08:00,12:00).
The 07:55 bar completes the range at 08:00; the 08:00 bar never changes the range.
The 11:55 breakout can execute at 12:00 in its next M5 bar. A failed/late attempt is never queued to another bar or Monday.
One-trade-per-day disables further candidate emission after an authoritative owned entry deal; planning independently rechecks history.
Manual/other-magic positions are not treated as E2-owned.

`InpTradeDirection` filters raw breakout direction before planner/daily-lock handling. The optional range-width filter freezes `rangeHigh-rangeLow` in pips and relative to ATR from the completed 07:55–08:00 M5 candle. Its intervals are `[minimum,maximum)`. Rejected days emit no candidate and do not consume the daily lock. The metrics and decision are included in the reconstructed range fingerprint and logged under `RANGE_FROZEN`.

OPPOSITE_RANGE uses the opposite frozen boundary. ATR uses the platform iATR closed-bar value, configured period/multiplier, and current Ask/Bid entry reference.
Both paths use the original broker stop normalization and position sizer. TP uses actual fill and submitted initial SL, not pre-fill estimated risk.

The optional `ATR_NORMALIZED` range-width research metric is versioned as `H1_ATR14_LAST_COMPLETED_BEFORE_RANGE_END_V1`. It divides the frozen London range width by ATR(14) read directly from the final fully completed H1 candle before the London range ends. It does not reuse or alter the M5 ATR used by ATR stop planning.

## Broker-time modes

Live mode is `LIVE_AUTO`. The adapter compares contemporaneous `TimeTradeServer` and `TimeCurrent` with `TimeGMT`, only outside Strategy Tester. The clocks must agree within five seconds, and the inferred server-minus-UTC offset must be plausible, within -14..+14 hours and aligned to 15 minutes. Every tick rechecks it. A valid change is installed as one atomic UTC transition and logged. An invalid observation makes conversions unavailable and blocks new entries; reconciliation and weekend-flat execute before that gate. When valid observations resume, the range engine reconstructs before entries resume.

Tester mode never calls the live-clock path. The normal mode is `TESTER_PROFILE` below. The optional `InpTesterAssumedFixedUTCOffsetHours` uses 99 as disabled; a whole-hour value -14..+14 with an empty profile selects `TESTER_ASSUMED_FIXED_OFFSET`. Its digest starts `NONAUTHORITATIVE_ASSUMED_`, startup logging says `AUTHORITATIVE=false`, and reports carry that digest. It is for exploratory comparisons only.

### Broker-time profile v1

Select a relative Common Files path with InpBrokerTimeProfile.
Required key=value lines (each exactly once):
- schema_version=1
- profile_id=<nonempty deployment identity>
- expected_server=<exact account/history server>
- mode=FIXED_OFFSET or UTC_TRANSITIONS
- valid_from_utc=<integer Unix seconds, inclusive>
- valid_until_utc=<integer Unix seconds, exclusive>
- initial_offset_seconds=<server minus UTC>
- source_reference=<evidence reference>
- test_only=0 or 1

For UTC_TRANSITIONS, add one or more:
transition=<effective UTC Unix seconds>,<new server-minus-UTC offset seconds>

Offsets must be within -14..+14 hours and whole minutes. Transitions must be strictly increasing, inside coverage and change the offset.
FIXED_OFFSET must have no transition records. Unknown/duplicate keys, invalid numbers and server mismatch fail initialization.
Test-only profiles are rejected outside Strategy Tester. The fixtures use the synthetic server E2_TEST_ONLY; they cannot be passed as real-account profiles without an explicit forbidden substitution.

The adapter matches each broker timestamp against the UTC half-open segments.
Zero matches (gap/outside coverage) and multiple matches (overlap) are rejected. There is no guessed overlap choice.
The profile must cover the reconstruction neighborhood as well as execution time. Coverage is checked at initialization and on every conversion.
Future test endpoint coverage cannot be certified from the current tester timestamp; going beyond profile coverage blocks new signals/execution, logs failures and does not extrapolate.
Existing position reconciliation/weekend management runs before the signal gate.

The normalized policy, including its expected server, offsets, transition instants, coverage and test-only marker, is SHA-256 digested.
The digest is included in the existing behavioral configuration hash and startup log. Source prose and filename are not behavioral identity.
All behavioral strategy settings, infrastructure/risk values and time-policy digest are hashed (30 serialized fields including strategy/build/symbol/timeframe identifiers).
No TimeGMT historical inference occurs in Strategy Tester. Live uses only contemporaneous clocks, never broker-name rules or a guessed DST regime. `TimeLocal` is never used.

## Pinned London conversion

E2LondonTime.mqh embeds explicit transition instants derived from IANA tzdb 2025b, Europe/London, for UTC [1996-01-01,2038-01-01).
Source: https://data.iana.org/time-zones/tzdb-2025b/europe
Dates outside this declared interval are rejected, not approximated.
Future entries reflect that pinned release and must be reviewed if UK legislation changes.
Updating timezone data is a versioned behavior change, not a silent runtime download.

## Restart and compatibility

Initialization rebuilds today's range using completed M5 history. A full contiguous range is required; missing/partial range data disables signals for that day rather than fabricating extrema.
Completed bars that predate initialization are never emitted as restart signals. This intentionally avoids replaying an already-known breakout on attachment.
On normal ticks, missed bars rebuild state but only the latest still-executable signal can be emitted.

The generic E2PositionRecovery preserves existing fill/SL/R/TP/volume/identity checks, broker ownership, tester-local isolation and live Common Files persistence.
The legacy E2_ADXBB_STATE_<magic>_<symbol>.csv basename is deliberately retained to find already-open E2 positions after migration.
The reader accepts legacy E2ADXBB2/ADXBB rows; the writer uses E2LRB1/LONDON_RANGE_BREAKOUT (28 fields), adding frozen range/ signal context and the time-policy digest.
Old binaries must not be used to read the new state format. Do not downgrade with an open London trade.
Legacy recovered trades have no fabricated London-range metadata and are labelled LEGACY_RECOVERED.

The daily lock scans actual owned successful entry deals and maps their timestamps to London dates; CSV creation dates and signal dates do not authorize a second entry.
A failed history/time conversion blocks entry. The audit deduplicates partial entry deals by position identifier.

## Reporting

SIGNALS: LRB_REPORT_V1, 39 columns.
TRADES: LRB_REPORT_V1, 54 columns.
General run IDs, paired naming/collision avoidance, trade registration, real P&L/R, exit reasons and reconciliation are preserved.
Obsolete indicator/regime columns are removed, not reused for unrelated values.
Session fields include London day, range start/end, frozen high/low/width, signal direction/time/close and breakout distance.
TRADES retains fill, initial SL, TP, Original R, target R, exits, realized R, integrity and recovery fields; session metadata survives the recovery file.
No REGIME or indicator-validation export is active.

## Inactive historical modules

E2ADXBBEngine.mqh, E2ADXBBTradePlanner.mqh, E2ADXBBTypes.mqh, E2ADXBBRecovery.mqh and research/E2ADXBBRegimeResearch.mqh are retained as historical source only.
They are not included by the current E2 entry point. Old ADXBB documentation describes the prior strategy, not the new baseline.

## Tests

tests/E2LondonSelfTest.mq5 is a no-order component harness. It directly calls production adapter, range and fingerprint code using synthetic fixtures.
tests/london_selftest.ini selects a one-day tester container only; no market-based strategy conclusions are drawn.
Synthetic fixtures live in tests/profiles and are copied without overwriting differing files to Common Files/E2/Tests/LondonSprint1 for the harness.
A full historical breakout lifecycle/restart integration test remains pending verified broker/history policy.

## Recorded Sprint 1 verification

- Production E2 compile: 0 errors, 0 warnings.
- No-order MQL5 harness compile: 0 errors, 0 warnings.
- Correct harness run: 33 checks, 0 failures, 0 orders; ending balance unchanged.
- Pinned London data independently checked at all 84 transition instants and their preceding seconds against bundled tzdata 2026.3: 168 checks, 0 mismatches.
- Active include graph: 23 project files, 0 old-alpha modules.
- Input count 27; SIGNALS 39 columns; TRADES 54 columns.
- Weekend gates remain present in signal expiry, planning, execution and position management.
- git diff --check: PASS (informational line-ending notices only).
- The first harness launch used a malformed INI path and MT5 ran its sample Moving Average EA instead. That simulated run is excluded. The corrected log explicitly identifies Experts/E2/tests/E2LondonSelfTest.ex5 and reports the 33 successful no-order checks.
- No authoritative historical strategy result is claimed. No deployment profile was created for FivePercentOnline-Real.
