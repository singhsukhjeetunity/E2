#ifndef E2_CORE_E2CONFIG_MQH
#define E2_CORE_E2CONFIG_MQH

enum E2RiskMode { E2_RISK_FIXED_CASH=0,E2_RISK_BALANCE_PERCENT=1 };
enum E2OBRSession { E2_OBR_SESSION_LONDON=0,E2_OBR_SESSION_NEW_YORK=1 };

input group "=== OBR STRATEGY ==="
input bool InpOBREnabled = true;
input E2OBRSession InpOBRSession = E2_OBR_SESSION_LONDON;
input int InpOBRAdxLength = 14;
input double InpOBRMinimumAdx = 20.0;
input int InpOBRAtrLength = 14;
input double InpOBRMinimumRangeAtr = 0.5;
input double InpOBRMaximumBreakoutGapAtr = 0.5;
input int InpOBRServerUtcOffsetStandardHours = 2;
input int InpOBRServerUtcOffsetSummerHours = 3;
input bool InpOBRServerUsesEuropeanDst = true;
input double InpOBRStopBufferAtr = 0.10;
input double InpOBRTargetR = 2.0;
input bool InpOBRTradeMonday = true;
input bool InpOBRTradeTuesday = true;
input bool InpOBRTradeWednesday = true;
input bool InpOBRTradeThursday = true;
input bool InpOBRTradeFriday = true;
input group "=== RISK ==="
input E2RiskMode InpRiskMode = E2_RISK_FIXED_CASH;
input double InpFixedCashRisk = 1000.0;
input double InpBalanceRiskPercent = 1.0;
input group "=== EXECUTION / BROKER SAFETY ==="
input ulong InpExpertMagicNumber = 2026001;
input bool InpTradingEnabled = true;
input double InpMaxSpreadPips = 3.0;
input double InpMaxEntryDeviationPips = 2.0;
input int InpMaxQuoteAgeSeconds = 10;
input int InpMinimumSecondsBetweenExecutions = 5;
input group "=== NEWS INFRASTRUCTURE ==="
input bool InpNewsFilterEnabled = false;
input int InpBrokerUtcOffsetHours = 999;
input int InpHighImpactBufferBeforeMins = 30;
input int InpHighImpactBufferAfterMins = 30;
input bool InpNewsHighImpactOnly = true;
input string InpNewsDataFile = "E2_news_events.csv";
input group "=== REPORTING / DIAGNOSTICS ==="
input bool InpDebugMode = false;
input bool InpCoreVerificationEnabled = true;
input bool InpLoggingEnabled = true;
input bool InpCsvExportEnabled = false;
input bool InpVisualModeEnabled = true;
input bool InpVisualCleanupOnDeinit = true;

struct E2Config
  {
   bool obr_enabled;E2OBRSession obr_session;int obr_adx_length;double obr_minimum_adx;int obr_atr_length;double obr_minimum_range_atr,obr_maximum_breakout_gap_atr;int obr_server_utc_offset_standard_hours,obr_server_utc_offset_summer_hours;bool obr_server_uses_european_dst;double obr_stop_buffer_atr,obr_target_r;bool obr_trade_monday,obr_trade_tuesday,obr_trade_wednesday,obr_trade_thursday,obr_trade_friday;
   E2RiskMode risk_mode; double fixed_cash_risk,balance_risk_percent;
   ulong expert_magic_number; bool trading_enabled; double max_spread_pips,max_entry_deviation_pips; int max_quote_age_seconds,minimum_seconds_between_executions;
   bool news_filter_enabled; int broker_utc_offset_hours,high_impact_buffer_before_minutes,high_impact_buffer_after_minutes; bool news_high_impact_only; string news_data_file;
   bool debug_mode,core_verification_enabled,logging_enabled,csv_export_enabled,visual_mode_enabled,visual_cleanup_on_deinit;
  };

void E2LoadConfiguration(E2Config &c)
  {
   c.obr_enabled=InpOBREnabled;c.obr_session=InpOBRSession;c.obr_adx_length=InpOBRAdxLength;c.obr_minimum_adx=InpOBRMinimumAdx;c.obr_atr_length=InpOBRAtrLength;c.obr_minimum_range_atr=InpOBRMinimumRangeAtr;c.obr_maximum_breakout_gap_atr=InpOBRMaximumBreakoutGapAtr;c.obr_server_utc_offset_standard_hours=InpOBRServerUtcOffsetStandardHours;c.obr_server_utc_offset_summer_hours=InpOBRServerUtcOffsetSummerHours;c.obr_server_uses_european_dst=InpOBRServerUsesEuropeanDst;c.obr_stop_buffer_atr=InpOBRStopBufferAtr;c.obr_target_r=InpOBRTargetR;c.obr_trade_monday=InpOBRTradeMonday;c.obr_trade_tuesday=InpOBRTradeTuesday;c.obr_trade_wednesday=InpOBRTradeWednesday;c.obr_trade_thursday=InpOBRTradeThursday;c.obr_trade_friday=InpOBRTradeFriday;
   c.risk_mode=InpRiskMode;c.fixed_cash_risk=InpFixedCashRisk;c.balance_risk_percent=InpBalanceRiskPercent;
   c.expert_magic_number=InpExpertMagicNumber;c.trading_enabled=InpTradingEnabled;c.max_spread_pips=InpMaxSpreadPips;c.max_entry_deviation_pips=InpMaxEntryDeviationPips;c.max_quote_age_seconds=InpMaxQuoteAgeSeconds;c.minimum_seconds_between_executions=InpMinimumSecondsBetweenExecutions;
   c.news_filter_enabled=InpNewsFilterEnabled;c.broker_utc_offset_hours=InpBrokerUtcOffsetHours;c.high_impact_buffer_before_minutes=InpHighImpactBufferBeforeMins;c.high_impact_buffer_after_minutes=InpHighImpactBufferAfterMins;c.news_high_impact_only=InpNewsHighImpactOnly;c.news_data_file=InpNewsDataFile;
   c.debug_mode=InpDebugMode;c.core_verification_enabled=InpCoreVerificationEnabled;c.logging_enabled=InpLoggingEnabled;c.csv_export_enabled=InpCsvExportEnabled;c.visual_mode_enabled=InpVisualModeEnabled;c.visual_cleanup_on_deinit=InpVisualCleanupOnDeinit;
  }

bool E2ValidateConfiguration(const E2Config &c,string &reason)
  {
   reason="";
   if((c.obr_session!=E2_OBR_SESSION_LONDON&&c.obr_session!=E2_OBR_SESSION_NEW_YORK)||c.obr_adx_length<1||c.obr_atr_length<1||!MathIsValidNumber(c.obr_minimum_adx)||c.obr_minimum_adx<0.0||!MathIsValidNumber(c.obr_minimum_range_atr)||c.obr_minimum_range_atr<0.0||!MathIsValidNumber(c.obr_maximum_breakout_gap_atr)||c.obr_maximum_breakout_gap_atr<0.0||!MathIsValidNumber(c.obr_stop_buffer_atr)||c.obr_stop_buffer_atr<0.0||!MathIsValidNumber(c.obr_target_r)||c.obr_target_r<=0.0){reason="OBR session/indicator/filter/trade values are invalid.";return(false);}
   if(c.obr_server_utc_offset_standard_hours < -14||c.obr_server_utc_offset_standard_hours > 14||c.obr_server_utc_offset_summer_hours < -14||c.obr_server_utc_offset_summer_hours > 14){reason="OBR server UTC offsets must be from -14 through 14.";return(false);}
   if(c.risk_mode!=E2_RISK_FIXED_CASH&&c.risk_mode!=E2_RISK_BALANCE_PERCENT){reason="Risk mode is invalid.";return(false);}
   if(c.risk_mode==E2_RISK_FIXED_CASH&&(!MathIsValidNumber(c.fixed_cash_risk)||c.fixed_cash_risk<=0.0)){reason="Fixed cash risk must be positive.";return(false);}
   if(c.risk_mode==E2_RISK_BALANCE_PERCENT&&(!MathIsValidNumber(c.balance_risk_percent)||c.balance_risk_percent<=0.0)){reason="Balance risk percent must be positive.";return(false);}
   if(c.max_spread_pips<0.0||c.max_entry_deviation_pips<0.0||c.max_quote_age_seconds<0||c.minimum_seconds_between_executions<0){reason="Execution safety values cannot be negative.";return(false);}
   if(c.high_impact_buffer_before_minutes<0||c.high_impact_buffer_after_minutes<0){reason="News buffers cannot be negative.";return(false);}
   if(c.news_filter_enabled&&(c.broker_utc_offset_hours < -14||c.broker_utc_offset_hours > 14)){reason="A broker UTC offset from -14 through 14 is required when news filtering is enabled.";return(false);}
   if(c.news_data_file==""){reason="News data filename cannot be empty.";return(false);}
   return(true);
  }

int E2ExposedInputCount(void){return(38);}
int E2DeadInputCount(void){return(0);}
int E2DuplicateInputCount(void){return(0);}
int E2InvalidInputMappingCount(void){return(0);}
#endif
