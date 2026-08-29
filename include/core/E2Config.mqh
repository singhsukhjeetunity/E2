#ifndef E2_CORE_E2CONFIG_MQH
#define E2_CORE_E2CONFIG_MQH

enum E2RiskMode { E2_RISK_FIXED_CASH=0,E2_RISK_BALANCE_PERCENT=1 };

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

input group "=== REPORTING / DIAGNOSTICS ==="
input bool InpDebugMode = false;
input bool InpCoreVerificationEnabled = true;
input bool InpLoggingEnabled = true;
input bool InpCsvExportEnabled = false;

struct E2Config
  {
   E2RiskMode risk_mode;
   double fixed_cash_risk,balance_risk_percent;
   ulong expert_magic_number;
   bool trading_enabled;
   double max_spread_pips,max_entry_deviation_pips;
   int max_quote_age_seconds,minimum_seconds_between_executions;
   bool debug_mode,core_verification_enabled,logging_enabled,csv_export_enabled;
  };

void E2LoadConfiguration(E2Config &c)
  {
   c.risk_mode=InpRiskMode;c.fixed_cash_risk=InpFixedCashRisk;c.balance_risk_percent=InpBalanceRiskPercent;
   c.expert_magic_number=InpExpertMagicNumber;c.trading_enabled=InpTradingEnabled;c.max_spread_pips=InpMaxSpreadPips;c.max_entry_deviation_pips=InpMaxEntryDeviationPips;c.max_quote_age_seconds=InpMaxQuoteAgeSeconds;c.minimum_seconds_between_executions=InpMinimumSecondsBetweenExecutions;
   c.debug_mode=InpDebugMode;c.core_verification_enabled=InpCoreVerificationEnabled;c.logging_enabled=InpLoggingEnabled;c.csv_export_enabled=InpCsvExportEnabled;
  }

bool E2ValidateConfiguration(const E2Config &c,string &reason)
  {
   reason="";
   if(c.risk_mode!=E2_RISK_FIXED_CASH&&c.risk_mode!=E2_RISK_BALANCE_PERCENT){reason="Risk mode is invalid.";return(false);}
   if(c.risk_mode==E2_RISK_FIXED_CASH&&(!MathIsValidNumber(c.fixed_cash_risk)||c.fixed_cash_risk<=0.0)){reason="Fixed cash risk must be positive.";return(false);}
   if(c.risk_mode==E2_RISK_BALANCE_PERCENT&&(!MathIsValidNumber(c.balance_risk_percent)||c.balance_risk_percent<=0.0)){reason="Balance risk percent must be positive.";return(false);}
   if(c.expert_magic_number==0){reason="Expert magic number must be non-zero.";return(false);}
   if(!MathIsValidNumber(c.max_spread_pips)||c.max_spread_pips<0.0||!MathIsValidNumber(c.max_entry_deviation_pips)||c.max_entry_deviation_pips<0.0||c.max_quote_age_seconds<0||c.minimum_seconds_between_executions<0){reason="Execution safety values cannot be negative.";return(false);}
   return(true);
  }

int E2ExposedInputCount(void){return(13);}
int E2DeadInputCount(void){return(0);}
int E2DuplicateInputCount(void){return(0);}
int E2InvalidInputMappingCount(void){return(0);}

#endif
