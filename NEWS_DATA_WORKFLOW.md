# E2 Historical News Data Workflow

## Purpose and boundary

`E2NewsExporter.mq5` prepares deterministic historical Economic Calendar data for E2 Strategy Tester runs. It is a standalone script: it does not run inside `E2.mq5`, poll live news, or alter any trading decision.

The canonical source is [utilities/E2NewsExporter.mq5](utilities/E2NewsExporter.mq5). Install or copy it to `MQL5\Scripts\E2\E2NewsExporter.mq5` so it appears under **Navigator > Scripts > E2**.

## Authoritative E2 CSV contract

The exporter writes the same comma-delimited `FILE_COMMON`, `FILE_ANSI` format read by `include/filters/E2NewsFilter.mqh`:

```text
record_type,event_time_utc,currency,impact,event_name,coverage_start_utc,coverage_end_utc
META,,,,,YYYY.MM.DD HH:MI,YYYY.MM.DD HH:MI
EVENT,YYYY.MM.DD HH:MI,USD,HIGH,Event title,,
```

The contract has exactly seven fields per row, one exact header, and exactly one `META` coverage row. Event timestamps and coverage endpoints are inclusive UTC minutes. Importance is exactly `LOW`, `MEDIUM`, or `HIGH`. The default filename is `E2_news_events.csv`.

The current schema has no country column, optional fields, or separate event-ID column. E2 treats `(event_time_utc, currency, impact, event_name)` as its duplicate identity and suppresses later identical rows. A malformed header, row, timestamp, currency, importance value, coverage range, or extra field invalidates the whole dataset rather than partially loading it.

## Timezone contract

Native MT5 Economic Calendar calls accept and return trade-server time. The E2 CSV requires UTC, while a Strategy Tester source time is converted to UTC by subtracting `InpBrokerUtcOffsetHours`.

The exporter therefore requires `InpCalendarServerUtcOffsetHours` in the range `-14..14` and applies:

```text
calendar query time = requested UTC + calendar-server offset
CSV event UTC       = calendar event time - calendar-server offset
```

Set `InpCalendarServerUtcOffsetHours` to the fixed UTC offset represented by the calendar server data, and use the same fixed value for E2's `InpBrokerUtcOffsetHours` when the tested price series uses that server clock. Do not subtract an offset from the CSV manually; it is already UTC.

The exporter currently defaults to `2`, matching the active E2 2024 research/test preset. This is a visible convenience default, not automatic timezone detection. Verify it against the intended broker dataset before every production export.

This project and E2 currently expose fixed-hour offsets, not a historical timezone/DST rule. A broker whose server offset changes during the requested period cannot be represented exactly by one setting. Split the export/test into constant-offset periods or obtain a verified fixed-offset history. Treat an uncertain offset as a data-quality blocker because a wrong value shifts the news windows.

`InpStartDateUtc` and `InpEndDateUtc` are minute-floored, inclusive UTC endpoints. The native query is widened through the next minute and every returned event is filtered back to the exact inclusive UTC interval. `end < start` fails before any output file is touched.

## Identity, ordering, and text safety

The native value ID and event ID form the exporter identity together with event time. Exact repeats of that identity are suppressed. Because the frozen E2 schema has no ID column, the exporter preserves both native IDs in the event-name field:

```text
Title [MT5_EVENT_ID=123;MT5_VALUE_ID=456]
```

This prevents two materially distinct native records from collapsing under E2's existing composite duplicate rule. It is a compatibility encoding, not a new CSV column. Do not remove the suffix in a spreadsheet.

Rows are sorted by UTC event time, currency, native value ID, native event ID, then title. The same calendar snapshot and inputs therefore produce the same logical ordering and record count.

The existing reader uses ANSI CSV and reads each field only to the next comma or line ending. It has no quoted-field escape contract, so a raw comma, quote, CR/LF, or non-ASCII title character cannot be passed through safely. This is a frozen-parser compatibility limitation; v2.0.2 does not change the reader.

The exporter therefore converts commas, double quotes, backslashes, control characters, and non-ASCII title characters to literal ASCII `\uXXXX` sequences before `FileWrite`. It never relies on quoted CSV fields. The exported title can be an escaped representation of the calendar display title, while retaining deterministic content and exactly seven parseable fields. Stable native-ID suffixes use only safe ASCII.

Only events with an exact `CALENDAR_TIMEMODE_DATETIME` timestamp are emitted. Date-only, no-time, tentative, missing-title, unknown-importance, and otherwise invalid records are counted in `invalidEventsSkipped`.

## Operator procedure

1. Open MT5 while connected to the intended broker/server and confirm Economic Calendar data is available in the terminal.
2. In **Navigator > Scripts > E2**, open `E2NewsExporter`. Do not run it in Strategy Tester.
3. Set `InpStartDateUtc` and `InpEndDateUtc` for the required inclusive UTC coverage.
4. Set `InpCalendarServerUtcOffsetHours` to the verified fixed difference `server time - UTC`.
5. Enable each required currency. EUR and USD are enabled by default; the exporter is not restricted to EURUSD.
6. Enable the required importance levels. High is enabled by default; low and medium are off.
7. Leave `InpOutputFileName=E2_news_events.csv` unless the E2 input will be changed to the same filename. Leave `InpOverwriteExisting=true` for a deterministic full replacement.
8. Run the script and inspect the **Experts** log, not only the terminal Journal. The Journal normally shows script loaded/removed lifecycle messages; MQL `Print` diagnostics appear in the Experts log. Require `[E2_NEWS_EXPORT_START]`, `[E2_NEWS_EXPORT_PATH]`, one `[E2_NEWS_CALENDAR]` line per selected currency, `[E2_NEWS_EXPORT]`, `[E2_NEWS_SCHEMA_VERIFY]`, and exactly one `[E2_NEWS_EXPORT_DONE] status=SUCCESS`. Success also requires `validationErrors=0`, every schema violation counter zero, and `eventsExported > 0`.
9. Locate the printed `outputFile`. It resolves to `TerminalInfoString(TERMINAL_COMMONDATA_PATH)\Files\E2_news_events.csv`.
10. Run E2 in Strategy Tester with `InpNewsFilterEnabled=true`, `InpNewsDataFile=E2_news_events.csv`, the verified `InpBrokerUtcOffsetHours`, and the intended news buffers/impact policy. Ensure the dataset coverage includes the full tested interval.

If `InpOverwriteExisting=false` and the common file already exists, the script fails before fetching or writing and preserves the existing file.

## EURUSD 2024 example

Use:

```text
InpStartDateUtc                 = 2024.01.01 00:00
InpEndDateUtc                   = 2024.12.31 23:59
InpCalendarServerUtcOffsetHours = 2 (current research preset; verify server-minus-UTC offset)
InpIncludeEUR                   = true
InpIncludeUSD                   = true
InpIncludeGBP/JPY/CHF/CAD/AUD/NZD = false
InpIncludeHighImpact            = true
InpIncludeMediumImpact          = false (or true only if required by the research policy)
InpIncludeLowImpact             = false
InpOutputFileName               = E2_news_events.csv
InpOverwriteExisting            = true
```

Require `[E2_NEWS_EXPORT_DONE] status=SUCCESS`, `eventsExported > 0`, `validationErrors=0`, and zero counters in `[E2_NEWS_SCHEMA_VERIFY]` before using the file.

## Exporter diagnostics

`[E2_NEWS_EXPORT_START]` is the mandatory first line from `OnStart`. It reports the requested dates, selected currencies and impacts, output filename, overwrite flag, and server UTC offset. If it is absent from the Experts log, the installed executable did not enter this script's `OnStart`.

`[E2_NEWS_EXPORT_PATH]` reports `commonDataPath`, `relativeFile`, and the absolute `effectiveFile` before any output write. `[E2_NEWS_CALENDAR]` reports each currency's server-time query interval, returned count, and `GetLastError()` value.

`[E2_NEWS_EXPORT]` reports `start`, `end`, `currencies`, `importanceMask`, `eventsFetched`, `currencyMatched`, `importanceMatched`, `eventsExported`, `duplicatesSuppressed`, `invalidEventsSkipped`, `outputFile`, `validationErrors`, `firstEventTime`, and `lastEventTime`.

`[E2_NEWS_SCHEMA_VERIFY]` reports `expectedColumns`, `rowsValidated`, `invalidColumnCount`, `invalidTimestampCount`, `invalidCurrencyCount`, `invalidImportanceCount`, `duplicateIdentityCount`, `sortViolations`, `rowCountMismatch`, and `metaErrors`.

Every rejected execution prints `[E2_NEWS_EXPORT_ERROR] reason=...` with relevant calendar/file details. Every execution emits exactly one final `[E2_NEWS_EXPORT_DONE]`: `status=SUCCESS` after a nonempty validated export, or `status=FAIL reason=...` on any rejected or failed path.

After writing, the script reopens the common file in the same CSV/ANSI mode as E2. It verifies the exact header and field count, single matching `META` coverage row, strict timestamps, selected currencies and importance values, E2 composite identity uniqueness, written ordering/content, and row count. A validation error produces `status=FAILED` rather than success.

## Manual acceptance checklist

These tests require a connected MT5 terminal with native calendar history; compilation alone does not execute them.

1. **EURUSD, 2024, high only:** use the example above and require `eventsExported > 0` with all validation counters zero.
2. **EUR and USD, one month:** export one complete calendar month; preserve the file and log. Repeat with the same calendar snapshot and settings, then compare row count and ordered content.
3. **No currencies:** disable all eight currencies. Require `status=FAILED, reason=NoCurrenciesSelected` and confirm no file was created or changed.
4. **Invalid range:** set end earlier than start. Require `status=FAILED, reason=InvalidUtcDateRange` and confirm no file was changed.
5. **Repeatability:** run an identical valid export twice with overwrite enabled. Require identical event ordering/count and zero duplicate/sort violations.
6. **Overwrite protection:** first create a valid file, set `InpOverwriteExisting=false`, and rerun. Require `status=FAILED, reason=OutputExistsAndOverwriteDisabled`; confirm the existing file is byte-for-byte unchanged.

## Forward/live boundary

This utility solves deterministic backtest data preparation only. A future forward/live implementation may adapt the native MT5 Economic Calendar to the existing E2 news-filter interface. v2.0.2 intentionally does not add live polling or calendar calls to the trading EA.
