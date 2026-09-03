# E2 London Range Breakout Inputs

The active strategy is LONDON_RANGE_BREAKOUT. There are 27 inputs: 13 existing operational/risk controls, 13 strategy controls, and one broker-time profile selector.

## Strategy

| Input | Default |
|---|---|
| InpRangeStartHourLondon / InpRangeStartMinuteLondon | 0 / 0 |
| InpRangeEndHourLondon / InpRangeEndMinuteLondon | 8 / 0 |
| InpBreakoutStartHourLondon / InpBreakoutStartMinuteLondon | 8 / 0 |
| InpBreakoutEndHourLondon / InpBreakoutEndMinuteLondon | 12 / 0 |
| InpStopMode | OPPOSITE_RANGE (alternative: ATR) |
| InpATRLength | 14 |
| InpATRMultiplier | 1.0 |
| InpTargetR | 1.5 |
| InpOneTradePerDay | true |

Hours 0..23; minutes 0..59 on M5 boundaries. Same-day ordering:
rangeStart < rangeEnd <= breakoutStart < breakoutEnd.
ATR length 1..1000; ATR multiplier and TargetR finite and positive.
No silent clamping. Overnight custom range windows are not supported in Sprint 1.

## Broker time

InpBrokerTimeProfile defaults to an empty string. A verified profile in MT5 Common Files is required; empty, inconsistent, mismatched or uncovered profiles fail initialization. No broker policy is inferred.
See LONDON_RANGE_BREAKOUT.md for the exact profile format and coverage limits.

## Preserved operational controls

InpTradingEnabled=true; InpExpertMagicNumber=2026001; InpLoggingEnabled=true;
InpCsvExportEnabled=false; InpRiskMode=E2_RISK_FIXED_CASH;
InpFixedCashRisk=1000.0; InpBalanceRiskPercent=1.0;
InpMaxSpreadPips=3.0; InpMaxEntryDeviationPips=2.0;
InpMaxQuoteAgeSeconds=10; InpMinimumSecondsBetweenExecutions=5;
InpWeekendFlatEnabled=true; InpWeekendFlatMinutesBeforeSessionClose=30.

No BB/ADX/DI/EMA/hybrid/inversion research input remains active.
