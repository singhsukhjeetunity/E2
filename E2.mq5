#property strict
#property version "4.0"
#property description "E2 strategy-free core prepared for future ADXBB implementation."

#include "include\\core\\E2Config.mqh"
#include "include\\core\\E2Environment.mqh"
#include "include\\core\\E2SymbolInfo.mqh"
#include "include\\core\\E2AccountInfo.mqh"
#include "include\\analysis\\E2MarketData.mqh"
#include "include\\risk\\E2PositionSizer.mqh"
#include "include\\risk\\E2OrderRequest.mqh"
#include "include\\execution\\E2PositionGuard.mqh"
#include "include\\execution\\E2ExecutionSafety.mqh"
#include "include\\execution\\E2OrderExecutor.mqh"
#include "include\\reporting\\E2Logger.mqh"
#include "include\\reporting\\E2TradeReporter.mqh"
#include "include\\reporting\\E2BacktestSummary.mqh"

E2Config g_configuration;
E2Environment g_environment;
E2Logger g_logger;
E2SymbolInfo g_symbol_info;
E2AccountInfo g_account_info;
E2MarketData g_market_data;
E2PositionSizer g_position_sizer;
E2PositionGuard g_position_guard;
E2ExecutionSafety g_execution_safety;
E2OrderExecutor g_order_executor;
E2TradeReporter g_trade_reporter;
E2BacktestSummary g_backtest_summary;

bool g_initialized=false;
datetime g_last_observed_m5_bar=0;

void E2EmitVerification(void)
  {
   if(!g_configuration.core_verification_enabled)return;
   const int strategy_candidates=0;
   const int trade_requests=0;
   const int execution_attempts=0;
   const int execution_successes=0;
   const int ownership_violations=0;
   const int unknown_positions=g_trade_reporter.UnknownE2Positions(_Symbol);
   g_backtest_summary.CoreVerify(g_initialized,strategy_candidates,trade_requests,execution_attempts,execution_successes,g_trade_reporter.RegisteredCount(),g_trade_reporter.FinalizedCount(),g_trade_reporter.DuplicateExecutionIds(),g_trade_reporter.DuplicateFinalizedTrades(),g_trade_reporter.CausalityViolations(),ownership_violations,unknown_positions);
   g_backtest_summary.RiskVerify(g_position_sizer.Verification());
   g_logger.Info("totalExposedInputs="+IntegerToString(E2ExposedInputCount())+", deadInputs="+IntegerToString(E2DeadInputCount())+", duplicateInputs="+IntegerToString(E2DuplicateInputCount())+", invalidMappings="+IntegerToString(E2InvalidInputMappingCount())+".","E2_INPUT_VERIFY");
  }

int OnInit()
  {
   E2LoadConfiguration(g_configuration);
   g_logger.Initialize(g_configuration.logging_enabled,g_configuration.debug_mode);
   string reason;
   if(!E2ValidateConfiguration(g_configuration,reason)){g_logger.Error(reason,"Initialization");return(INIT_PARAMETERS_INCORRECT);}
   if(_Period!=PERIOD_M5){g_logger.Error("E2 strategy-free core must be attached to M5 in preparation for ADXBB.","Initialization");return(INIT_PARAMETERS_INCORRECT);}
   g_environment.Initialize();
   if(!g_symbol_info.Initialize(_Symbol,g_logger)){g_logger.Error("Symbol initialization failed.","Initialization");return(INIT_FAILED);}
   if(!g_account_info.Initialize(g_logger)){g_logger.Error("Account initialization failed.","Initialization");return(INIT_FAILED);}
   g_market_data.Initialize(g_logger);
   g_position_sizer.Initialize(g_configuration,g_symbol_info,g_account_info,g_logger);
   g_position_guard.Initialize(g_configuration,g_logger);
   g_execution_safety.Initialize(g_configuration,g_logger);
   g_order_executor.Initialize(g_configuration,g_symbol_info,g_account_info,g_position_guard,g_execution_safety,g_logger);
   if(!g_trade_reporter.Initialize(g_configuration.csv_export_enabled,g_configuration.expert_magic_number,_Symbol,g_logger))return(INIT_FAILED);
   g_backtest_summary.Initialize(g_logger);
   if(g_position_guard.HasOpenE2Position(_Symbol))g_logger.Warning("An E2-owned position already exists. Sprint 1 has no strategy-specific metadata recovery and will not manage or modify it.","Core");
   MqlRates latest;if(g_market_data.GetClosedBar(_Symbol,PERIOD_M5,0,latest)){g_last_observed_m5_bar=latest.time;g_logger.Info("Completed M5 market data is ready; latestClosedBar="+TimeToString(latest.time,TIME_DATE|TIME_MINUTES)+".","MarketData");}else g_logger.Warning("Completed M5 market data is not ready at initialization; the inert core will retry on ticks.","MarketData");
   g_initialized=true;
   const string risk_mode=(g_configuration.risk_mode==E2_RISK_FIXED_CASH?"FIXED_CASH":"BALANCE_PERCENT");
   g_logger.Info("symbol="+_Symbol+", timeframe=M5, strategy=NONE, tradingEnabled="+IntegerToString((int)g_configuration.trading_enabled)+", riskMode="+risk_mode+", magicNumber="+StringFormat("%I64u",g_configuration.expert_magic_number)+", csvEnabled="+IntegerToString((int)g_configuration.csv_export_enabled)+".","E2_PRODUCTION_CONFIG");
   g_logger.Info("Initialized in "+g_environment.Name()+". Strategy-free core is inert; no candidates, requests, or orders can be generated.","Core");
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   MqlRates latest;if(!g_market_data.GetClosedBar(_Symbol,PERIOD_M5,0,latest))return;
   if(latest.time<=g_last_observed_m5_bar)return;
   g_last_observed_m5_bar=latest.time;
   g_logger.Debug("Observed completed M5 bar at "+TimeToString(latest.time,TIME_DATE|TIME_MINUTES)+"; no strategy is attached.","Core");
  }

void OnDeinit(const int reason)
  {
   E2EmitVerification();
   g_trade_reporter.Close();
   g_initialized=false;
  }
