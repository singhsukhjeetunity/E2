#ifndef E2_CORE_E2CONFIG_MQH
#define E2_CORE_E2CONFIG_MQH
enum E2RiskMode { E2_RISK_FIXED_CASH=0,E2_RISK_BALANCE_PERCENT=1 };
enum E2StopMode { OPPOSITE_RANGE=0, ATR=1 };
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


input group "=== LONDON RANGE BREAKOUT ==="
input int InpRangeStartHourLondon=0;
input int InpRangeStartMinuteLondon=0;
input int InpRangeEndHourLondon=8;
input int InpRangeEndMinuteLondon=0;
input int InpBreakoutStartHourLondon=8;
input int InpBreakoutStartMinuteLondon=0;
input int InpBreakoutEndHourLondon=12;
input int InpBreakoutEndMinuteLondon=0;
input E2StopMode InpStopMode=OPPOSITE_RANGE;
input int InpATRLength=14;
input double InpATRMultiplier=1.0;
input double InpTargetR=1.5;
input bool InpOneTradePerDay=true;
input group "=== BROKER TIME ADAPTER ==="
input string InpBrokerTimeProfile=""; // Required verified deployment profile in Common Files

struct E2Config
{
   int range_start,range_end,breakout_start,breakout_end,atr_length;
   E2StopMode stop_mode;
   double atr_multiplier,target_r;
   bool one_trade_per_day;
   string broker_time_profile,time_policy_digest;
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
   c.range_start=InpRangeStartHourLondon*60+InpRangeStartMinuteLondon;
   c.range_end=InpRangeEndHourLondon*60+InpRangeEndMinuteLondon;
   c.breakout_start=InpBreakoutStartHourLondon*60+InpBreakoutStartMinuteLondon;
   c.breakout_end=InpBreakoutEndHourLondon*60+InpBreakoutEndMinuteLondon;
   c.stop_mode=InpStopMode;c.atr_length=InpATRLength;c.atr_multiplier=InpATRMultiplier;
   c.target_r=InpTargetR;c.one_trade_per_day=InpOneTradePerDay;c.broker_time_profile=InpBrokerTimeProfile;
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
   if(!E2ValidClock(InpRangeStartHourLondon,InpRangeStartMinuteLondon)||
      !E2ValidClock(InpRangeEndHourLondon,InpRangeEndMinuteLondon)||
      !E2ValidClock(InpBreakoutStartHourLondon,InpBreakoutStartMinuteLondon)||
      !E2ValidClock(InpBreakoutEndHourLondon,InpBreakoutEndMinuteLondon))
      {reason="London session clocks must be valid and aligned to M5.";return(false);}
   if(c.range_start>=c.range_end||c.range_end>c.breakout_start||c.breakout_start>=c.breakout_end)
      {reason="Require same-day rangeStart < rangeEnd <= breakoutStart < breakoutEnd.";return(false);}
   if(c.stop_mode!=OPPOSITE_RANGE&&c.stop_mode!=ATR){reason="Invalid stop mode.";return(false);}
   if(c.atr_length<1||c.atr_length>1000||!MathIsValidNumber(c.atr_multiplier)||c.atr_multiplier<=0||
      !MathIsValidNumber(c.target_r)||c.target_r<=0){reason="ATR length 1..1000 and positive ATR multiplier/Target R required.";return(false);}
   if(c.risk_mode!=E2_RISK_FIXED_CASH&&c.risk_mode!=E2_RISK_BALANCE_PERCENT){reason="Risk mode is invalid.";return(false);}
   if(c.risk_mode==E2_RISK_FIXED_CASH&&(!MathIsValidNumber(c.fixed_cash_risk)||c.fixed_cash_risk<=0.0)){reason="Fixed cash risk must be positive.";return(false);}
   if(c.risk_mode==E2_RISK_BALANCE_PERCENT&&(!MathIsValidNumber(c.balance_risk_percent)||c.balance_risk_percent<=0.0)){reason="Balance risk percent must be positive.";return(false);}
   if(c.expert_magic_number==0){reason="Expert magic number must be non-zero.";return(false);}
   if(!MathIsValidNumber(c.max_spread_pips)||c.max_spread_pips<0.0||!MathIsValidNumber(c.max_entry_deviation_pips)||c.max_entry_deviation_pips<0.0||c.max_quote_age_seconds<0||c.minimum_seconds_between_executions<0){reason="Execution safety values cannot be negative.";return(false);}
   if(c.weekend_flat_minutes_before_session_close<0||c.weekend_flat_minutes_before_session_close>1440){reason="Weekend-flat safety margin must be between 0 and 1440 minutes.";return(false);}

   return(true);
}
int E2ExposedInputCount(void){return(27);}
int E2DeadInputCount(void){return(0);}
int E2DuplicateInputCount(void){return(0);}
int E2InvalidInputMappingCount(void){return(0);}
#endif
