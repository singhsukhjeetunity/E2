#ifndef E2_CORE_E2CONFIG_MQH
#define E2_CORE_E2CONFIG_MQH

enum E2RiskMode { E2_RISK_FIXED_CASH=0,E2_RISK_BALANCE_PERCENT=1 };

// Frozen HYBRID_V1_Q50 production methodology.
const int E2_ADXBB_DI_LENGTH=7;
const int E2_ADXBB_ADX_LENGTH=7;
const double E2_ADXBB_ADX_THRESHOLD=20.0;
const int E2_ADXBB_BB_LENGTH=20;
const double E2_ADXBB_BB_STDDEV=2.0;
const double E2_ADXBB_BB_BUFFER_PIPS=1.0;
const bool E2_ADXBB_REQUIRE_BB_REENTRY_CONFIRMATION=false;
const bool E2_ADXBB_INVERT_TRADE_DIRECTION=false;
const bool E2_ADXBB_HYBRID_REGIME_ENABLED=true;
const int E2_ADXBB_ATR_LENGTH=14;
const double E2_ADXBB_ATR_MULTIPLIER=2.0;
const double E2_ADXBB_TARGET_R=1.5;
const bool E2_ONE_TRADE_PER_DAY=true;
const int E2_ADXBB_REGIME_PERCENTILE_LOOKBACK=250;
const double E2_ADXBB_HYBRID_MATURITY_THRESHOLD_ATR=0.50;
const double E2_ADXBB_HYBRID_QUALITY_Q50=0.50;
const double E2_ADXBB_HYBRID_QUALITY_Q75=0.75;

// Internal diagnostics/research defaults. Engineering can change these in source.
const bool E2_DEBUG_MODE=false;
const bool E2_CORE_VERIFICATION_ENABLED=true;
const bool E2_ADXBB_REGIME_RESEARCH_ENABLED=false;

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

struct E2Config
  {
   int adxbb_di_length,adxbb_adx_length;
   double adxbb_adx_threshold;
   int adxbb_bb_length;
   double adxbb_bb_stddev,adxbb_bb_buffer_pips;
   bool adxbb_require_bb_reentry_confirmation,adxbb_invert_trade_direction,adxbb_hybrid_regime_enabled;
   int adxbb_atr_length;
   double adxbb_atr_multiplier,adxbb_target_r;
   bool one_trade_per_day;
   E2RiskMode risk_mode;
   double fixed_cash_risk,balance_risk_percent;
   ulong expert_magic_number;
   bool trading_enabled;
   double max_spread_pips,max_entry_deviation_pips;
   int max_quote_age_seconds,minimum_seconds_between_executions;
   bool weekend_flat_enabled;
   int weekend_flat_minutes_before_session_close;
   bool debug_mode,core_verification_enabled,logging_enabled,csv_export_enabled,adxbb_regime_research_enabled;
   int adxbb_regime_percentile_lookback;
  };

void E2LoadConfiguration(E2Config &c)
  {
   c.adxbb_di_length=E2_ADXBB_DI_LENGTH;c.adxbb_adx_length=E2_ADXBB_ADX_LENGTH;c.adxbb_adx_threshold=E2_ADXBB_ADX_THRESHOLD;c.adxbb_bb_length=E2_ADXBB_BB_LENGTH;c.adxbb_bb_stddev=E2_ADXBB_BB_STDDEV;c.adxbb_bb_buffer_pips=E2_ADXBB_BB_BUFFER_PIPS;c.adxbb_require_bb_reentry_confirmation=E2_ADXBB_REQUIRE_BB_REENTRY_CONFIRMATION;c.adxbb_invert_trade_direction=E2_ADXBB_INVERT_TRADE_DIRECTION;c.adxbb_hybrid_regime_enabled=E2_ADXBB_HYBRID_REGIME_ENABLED;c.adxbb_atr_length=E2_ADXBB_ATR_LENGTH;c.adxbb_atr_multiplier=E2_ADXBB_ATR_MULTIPLIER;c.adxbb_target_r=E2_ADXBB_TARGET_R;c.one_trade_per_day=E2_ONE_TRADE_PER_DAY;
   c.risk_mode=InpRiskMode;c.fixed_cash_risk=InpFixedCashRisk;c.balance_risk_percent=InpBalanceRiskPercent;
   c.expert_magic_number=InpExpertMagicNumber;c.trading_enabled=InpTradingEnabled;c.max_spread_pips=InpMaxSpreadPips;c.max_entry_deviation_pips=InpMaxEntryDeviationPips;c.max_quote_age_seconds=InpMaxQuoteAgeSeconds;c.minimum_seconds_between_executions=InpMinimumSecondsBetweenExecutions;c.weekend_flat_enabled=InpWeekendFlatEnabled;c.weekend_flat_minutes_before_session_close=InpWeekendFlatMinutesBeforeSessionClose;
   c.debug_mode=E2_DEBUG_MODE;c.core_verification_enabled=E2_CORE_VERIFICATION_ENABLED;c.logging_enabled=InpLoggingEnabled;c.csv_export_enabled=InpCsvExportEnabled;c.adxbb_regime_research_enabled=E2_ADXBB_REGIME_RESEARCH_ENABLED;c.adxbb_regime_percentile_lookback=E2_ADXBB_REGIME_PERCENTILE_LOOKBACK;
  }

bool E2ValidateConfiguration(const E2Config &c,string &reason)
  {
   reason="";
   if(c.adxbb_di_length<1||c.adxbb_adx_length<1||c.adxbb_bb_length<2||c.adxbb_atr_length<1||!MathIsValidNumber(c.adxbb_adx_threshold)||c.adxbb_adx_threshold<0.0||!MathIsValidNumber(c.adxbb_bb_stddev)||c.adxbb_bb_stddev<=0.0||!MathIsValidNumber(c.adxbb_bb_buffer_pips)||c.adxbb_bb_buffer_pips<0.0||!MathIsValidNumber(c.adxbb_atr_multiplier)||c.adxbb_atr_multiplier<=0.0||!MathIsValidNumber(c.adxbb_target_r)||c.adxbb_target_r<=0.0){reason="ADXBB indicator/target values are invalid.";return(false);}
   if(c.risk_mode!=E2_RISK_FIXED_CASH&&c.risk_mode!=E2_RISK_BALANCE_PERCENT){reason="Risk mode is invalid.";return(false);}
   if(c.risk_mode==E2_RISK_FIXED_CASH&&(!MathIsValidNumber(c.fixed_cash_risk)||c.fixed_cash_risk<=0.0)){reason="Fixed cash risk must be positive.";return(false);}
   if(c.risk_mode==E2_RISK_BALANCE_PERCENT&&(!MathIsValidNumber(c.balance_risk_percent)||c.balance_risk_percent<=0.0)){reason="Balance risk percent must be positive.";return(false);}
   if(c.expert_magic_number==0){reason="Expert magic number must be non-zero.";return(false);}
   if(!MathIsValidNumber(c.max_spread_pips)||c.max_spread_pips<0.0||!MathIsValidNumber(c.max_entry_deviation_pips)||c.max_entry_deviation_pips<0.0||c.max_quote_age_seconds<0||c.minimum_seconds_between_executions<0){reason="Execution safety values cannot be negative.";return(false);}
   if(c.weekend_flat_minutes_before_session_close<0||c.weekend_flat_minutes_before_session_close>1440){reason="Weekend-flat safety margin must be between 0 and 1440 minutes.";return(false);}
   if(c.adxbb_regime_percentile_lookback<20){reason="ADXBB regime percentile lookback must be at least 20.";return(false);}
   return(true);
  }

int E2ExposedInputCount(void){return(13);}
int E2DeadInputCount(void){return(0);}
int E2DuplicateInputCount(void){return(0);}
int E2InvalidInputMappingCount(void){return(0);}

#endif
