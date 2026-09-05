# MetaQuotes-Demo EURUSD research time profile

Status: generated and structurally validated; cross-platform transition validation blocked.

Profile: `tests/profiles/metaquotes_demo_eurusd_us_dst_2020_2026_research.profile`

MT5 Common Files input path:
`E2\Tests\LondonSprint1\metaquotes_demo_eurusd_us_dst_2020_2026_research.profile`

The terminal/tester reports the exact server string `MetaQuotes-Demo`. The profile encodes the supplied research hypothesis: UTC+2 in winter, UTC+3 in summer, with explicit U.S. DST transitions at 07:00 UTC on the second Sunday in March and 06:00 UTC on the first Sunday in November. It does not use the UK or EU broker-DST calendar.

`test_only=1` is the current profile-schema representation of `AUTHORITATIVE=false`. The source reference explicitly states that the hypothesis is community-observed and is not broker-certified.

## UTC transition table

| Year | UTC+2 -> UTC+3 | Epoch | UTC+3 -> UTC+2 | Epoch |
|---:|---|---:|---|---:|
| 2020 | 2020-03-08 07:00:00Z | 1583650800 | 2020-11-01 06:00:00Z | 1604210400 |
| 2021 | 2021-03-14 07:00:00Z | 1615705200 | 2021-11-07 06:00:00Z | 1636264800 |
| 2022 | 2022-03-13 07:00:00Z | 1647154800 | 2022-11-06 06:00:00Z | 1667714400 |
| 2023 | 2023-03-12 07:00:00Z | 1678604400 | 2023-11-05 06:00:00Z | 1699164000 |
| 2024 | 2024-03-10 07:00:00Z | 1710054000 | 2024-11-03 06:00:00Z | 1730613600 |
| 2025 | 2025-03-09 07:00:00Z | 1741503600 | 2025-11-02 06:00:00Z | 1762063200 |
| 2026 | 2026-03-08 07:00:00Z | 1772953200 | 2026-11-01 06:00:00Z | 1793512800 |

Coverage is `[2020-01-01 00:00:00Z, 2027-01-01 00:00:00Z)`. Initial offset is 7200 seconds.

Production adapter digest:
`6D84C43A8534EBC3E4994F88499EAEE4DA86322722F939889D4FA61E5F461E7F`

## Validation

The production parser loaded all 14 transitions, verified exact server identity and emitted `AUTHORITATIVE=false`. Direct tests pass for the 2024 spring pre-boundary, post-boundary and nonexistent server hour, plus autumn pre-boundary, duplicated server hour rejection and post-boundary.

Final no-order block:
`[LRB_SELFTEST] checks=1790, failures=0, testOnly=1, ordersSubmitted=0`

An initial timestamp-generation attempt exposed five autumn epochs one hour late because a local Toronto conversion contaminated the display/input conversion. The boundary test caught the error before any research run. All epochs above were regenerated explicitly in UTC; the installed Common Files copy is byte-identical to the corrected repository profile.

## Cross-platform gate

The supplied summer reference is preserved as context: July-August 2026, assumed UTC+3, 32 MT5 trades, 32 TradingView trades, 31 common dates, 31/31 matching directions and 30/31 exact entry-time matches. That evidence was not regenerated in this task.

No TradingView/OANDA export covering the required four-week March or November transition windows is currently present. Only MT5 July report files were found. Consequently:

- March comparison: not run / no counterpart data.
- November comparison: not run / no counterpart data.
- Systematic one-hour discrepancy: not measurable.
- Run A and Run B: deliberately not run.
- The profile must not yet be accepted as empirically cross-validated multi-year timing metadata.

Required next inputs are TradingView/OANDA trade exports for two weeks before through two weeks after at least one March U.S. transition and one November U.S. transition, generated with identical strategy settings. Once supplied, compare London date, range, signal time/direction, entry time and count before starting either full baseline.
