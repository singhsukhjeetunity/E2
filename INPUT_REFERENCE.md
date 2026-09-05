# E2 London Range Breakout Inputs

The active strategy is LONDON_RANGE_BREAKOUT. There are 33 inputs: 13 existing operational/risk controls, 18 strategy/research controls, and two broker-time controls.

## Strategy

| Input | Default |
|---|---|
| InpRangeStartHourLondon / InpRangeStartMinuteLondon | 0 / 0 |
| InpRangeEndHourLondon / InpRangeEndMinuteLondon | 8 / 0 |
| InpBreakoutStartHourLondon / InpBreakoutStartMinuteLondon | 8 / 0 |
| InpBreakoutEndHourLondon / InpBreakoutEndMinuteLondon | 12 / 0 |
| InpTradeDirection | BOTH (LONG_ONLY / SHORT_ONLY) |
| InpRangeWidthFilterEnabled | false |
| InpRangeWidthFilterMode | ATR_NORMALIZED (alternative: PIPS) |
| InpMinRangeWidth / InpMaxRangeWidth | 0.0 / 999999.0 |
| InpStopMode | OPPOSITE_RANGE (alternative: ATR) |
| InpATRLength | 14 |
| InpATRMultiplier | 1.0 |
| InpTargetR | 1.5 |
| InpOneTradePerDay | true |

Hours 0..23; minutes 0..59 on M5 boundaries. Same-day ordering:
rangeStart < rangeEnd <= breakoutStart < breakoutEnd.
ATR length 1..1000; ATR multiplier and TargetR finite and positive.
Range-width bounds are half-open and must satisfy `0 <= minimum < maximum`.
No silent clamping. Overnight custom range windows are not supported in Sprint 1.

## Broker time

Live mode auto-detects the current server-minus-UTC offset from contemporaneous terminal/server and GMT clocks. `InpBrokerTimeProfile` is ignored live. Invalid live clock observations block new entries while recovery reconciliation and weekend-flat stay active.

Strategy Tester uses the built-in non-authoritative MetaQuotes-Demo EURUSD research profile when both tester-time inputs are left at their disabled defaults. Other servers/symbols still require an explicit profile or assumed offset. `InpTesterAssumedFixedUTCOffsetHours=99` means disabled. Setting it to a whole hour from -14 through +14, with the profile left empty, explicitly enables NON-AUTHORITATIVE research mode. Supplying both is rejected. The assumed offset is never used live.
See LONDON_RANGE_BREAKOUT.md for the exact profile format and coverage limits.

## Preserved operational controls

InpTradingEnabled=true; InpExpertMagicNumber=2026001; InpLoggingEnabled=true;
InpCsvExportEnabled=false; InpRiskMode=E2_RISK_FIXED_CASH;
InpFixedCashRisk=1000.0; InpBalanceRiskPercent=1.0;
InpMaxSpreadPips=3.0; InpMaxEntryDeviationPips=2.0;
InpMaxQuoteAgeSeconds=10; InpMinimumSecondsBetweenExecutions=5;
InpWeekendFlatEnabled=true; InpWeekendFlatMinutesBeforeSessionClose=30.

No BB/ADX/DI/EMA/hybrid/inversion research input remains active.
