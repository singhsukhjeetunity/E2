#ifndef E2_CORE_E2CONFIG_MQH
#define E2_CORE_E2CONFIG_MQH
enum E2RiskMode { E2_RISK_FIXED_CASH=0,E2_RISK_BALANCE_PERCENT=1 };
enum E2XauTimeBasis { E2_XAU_TIME_SERVER=0,E2_XAU_TIME_UTC=1 };
input group "=== E2 PRODUCTION ==="
input bool InpTradingEnabled = true;             // Enable Trading
input ulong InpExpertMagicNumber = 2026001;      // Expert Magic Number
input bool InpLoggingEnabled = true;             // Enable Journal Logging
input bool InpCsvExportEnabled = false;           // Export SIGNALS / TRADES CSV

input group "=== RISK MANAGEMENT ==="
input E2RiskMode InpRiskMode = E2_RISK_FIXED_CASH; // Risk Mode
input double InpFixedCashRisk = 1000.0;             // Fixed Risk (account currency)
input double InpBalanceRiskPercent = 1.0;            // Balance Risk (%)

input group "=== EXECUTION SAFETY ==="
input double InpMaxSpreadPips = 3.0;                 // Maximum Spread (pips)
input double InpMaxEntryDeviationPips = 2.0;         // Maximum Entry Deviation (pips)
input int InpMaxQuoteAgeSeconds = 10;                 // Maximum Quote Age (seconds)
input int InpMinimumSecondsBetweenExecutions = 5;    // Minimum Execution Interval (seconds)
input bool InpWeekendFlatEnabled = true;              // Enable Weekend Flat Protection
input int InpWeekendFlatMinutesBeforeSessionClose = 30; // Minutes Before Friday Session Close

input bool InpOneTradePerDay=true;

input group "=== XAU SESSION FADE ==="
input E2XauTimeBasis InpXauTimeBasis=E2_XAU_TIME_UTC;
input int InpXauRangeStartHour=8;
input int InpXauRangeStartMinute=0;
input int InpXauRangeEndHour=8;
input int InpXauRangeEndMinute=30;
input int InpXauATRLength=14;
input double InpXauATRMultiplier=8.0;
input double InpXauTargetR=1.5;
input int InpXauTrendLookbackBars=36;
input double InpXauTrendEfficiencyMin=0.30;

input group "=== BROKER TIME ADAPTER ==="
input string InpBrokerTimeProfile=""; // Required verified deployment profile in Common Files
input bool InpUseManualBrokerUtcOffset=false;
input int InpBrokerUtcOffsetSeconds=0;

struct E2Config
{
   int xau_range_start,xau_range_end,xau_atr_length,xau_trend_lookback_bars;
   double xau_atr_multiplier,xau_target_r,xau_trend_efficiency_min;
   E2XauTimeBasis xau_time_basis;
   bool one_trade_per_day;
   string broker_time_profile,time_policy_digest;
   bool use_manual_broker_utc_offset;
   int broker_utc_offset_seconds;
   E2RiskMode risk_mode;
   double fixed_cash_risk,balance_risk_percent;
   ulong expert_magic_number;
   bool trading_enabled;
   double max_spread_pips,max_entry_deviation_pips;
   int max_quote_age_seconds,minimum_seconds_between_executions;
   bool weekend_flat_enabled;
   int weekend_flat_minutes_before_session_close;
   bool debug_mode,core_verification_enabled,logging_enabled,csv_export_enabled;
};
bool E2ValidClock(const int h,const int m){return(h>=0&&h<=23&&m>=0&&m<=59&&m%5==0);}
void E2LoadConfiguration(E2Config &c)
{
   ZeroMemory(c);
   c.one_trade_per_day=InpOneTradePerDay;c.broker_time_profile=InpBrokerTimeProfile;
   c.xau_range_start=InpXauRangeStartHour*60+InpXauRangeStartMinute;
   c.xau_range_end=InpXauRangeEndHour*60+InpXauRangeEndMinute;
   c.xau_atr_length=InpXauATRLength;c.xau_atr_multiplier=InpXauATRMultiplier;c.xau_target_r=InpXauTargetR;
   c.xau_trend_lookback_bars=InpXauTrendLookbackBars;c.xau_trend_efficiency_min=InpXauTrendEfficiencyMin;
   c.xau_time_basis=InpXauTimeBasis;
   c.use_manual_broker_utc_offset=InpUseManualBrokerUtcOffset;
   c.broker_utc_offset_seconds=InpBrokerUtcOffsetSeconds;
   c.risk_mode=InpRiskMode;c.fixed_cash_risk=InpFixedCashRisk;c.balance_risk_percent=InpBalanceRiskPercent;
   c.expert_magic_number=InpExpertMagicNumber;c.trading_enabled=InpTradingEnabled;
   c.max_spread_pips=InpMaxSpreadPips;c.max_entry_deviation_pips=InpMaxEntryDeviationPips;
   c.max_quote_age_seconds=InpMaxQuoteAgeSeconds;c.minimum_seconds_between_executions=InpMinimumSecondsBetweenExecutions;
   c.weekend_flat_enabled=InpWeekendFlatEnabled;c.weekend_flat_minutes_before_session_close=InpWeekendFlatMinutesBeforeSessionClose;
   c.core_verification_enabled=true;c.logging_enabled=InpLoggingEnabled;c.csv_export_enabled=InpCsvExportEnabled;
}
bool E2ValidateConfiguration(const E2Config &c,string &reason)
{
   reason="";
   if(!E2ValidClock(InpXauRangeStartHour,InpXauRangeStartMinute)||!E2ValidClock(InpXauRangeEndHour,InpXauRangeEndMinute)||
      c.xau_range_start>=c.xau_range_end){reason="XAU range clocks must be valid, same-day, and aligned to M5.";return(false);}
   if(c.xau_time_basis!=E2_XAU_TIME_SERVER&&c.xau_time_basis!=E2_XAU_TIME_UTC)
      {reason="Invalid XAU time basis.";return(false);}
   if(c.xau_atr_length<1||c.xau_atr_length>1000||!MathIsValidNumber(c.xau_atr_multiplier)||c.xau_atr_multiplier<=0||
      !MathIsValidNumber(c.xau_target_r)||c.xau_target_r<=0){reason="XAU ATR length 1..1000 and positive ATR multiplier/Target R required.";return(false);}
   if(c.xau_trend_lookback_bars<2||c.xau_trend_lookback_bars>1000||
      !MathIsValidNumber(c.xau_trend_efficiency_min)||c.xau_trend_efficiency_min<0.0||c.xau_trend_efficiency_min>1.0)
      {reason="XAU trend lookback must be 2..1000 and efficiency threshold 0..1.";return(false);}
   if(c.risk_mode!=E2_RISK_FIXED_CASH&&c.risk_mode!=E2_RISK_BALANCE_PERCENT){reason="Risk mode is invalid.";return(false);}
   if(c.risk_mode==E2_RISK_FIXED_CASH&&(!MathIsValidNumber(c.fixed_cash_risk)||c.fixed_cash_risk<=0.0)){reason="Fixed cash risk must be positive.";return(false);}
   if(c.risk_mode==E2_RISK_BALANCE_PERCENT&&(!MathIsValidNumber(c.balance_risk_percent)||c.balance_risk_percent<=0.0)){reason="Balance risk percent must be positive.";return(false);}
   if(c.expert_magic_number==0){reason="Expert magic number must be non-zero.";return(false);}
   if(!MathIsValidNumber(c.max_spread_pips)||c.max_spread_pips<0.0||!MathIsValidNumber(c.max_entry_deviation_pips)||c.max_entry_deviation_pips<0.0||c.max_quote_age_seconds<0||c.minimum_seconds_between_executions<0){reason="Execution safety values cannot be negative.";return(false);}
   if(c.weekend_flat_minutes_before_session_close<0||c.weekend_flat_minutes_before_session_close>1440){reason="Weekend-flat safety margin must be between 0 and 1440 minutes.";return(false);}
   if(c.use_manual_broker_utc_offset&&(c.broker_utc_offset_seconds<-50400||c.broker_utc_offset_seconds>50400||c.broker_utc_offset_seconds%60!=0))
      {reason="Manual broker UTC offset must be between -50400 and 50400 seconds, aligned to minutes.";return(false);}

   return(true);
}
int E2ExposedInputCount(void){return(27);}
int E2DeadInputCount(void){return(0);}
int E2DuplicateInputCount(void){return(0);}
int E2InvalidInputMappingCount(void){return(0);}
#endif
