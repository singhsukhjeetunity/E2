#property strict
#property version "3.0"
#property description "E2 strategy-agnostic core. No trading strategy is implemented."

#include "include\\core\\E2Config.mqh"
#include "include\\core\\E2Environment.mqh"
#include "include\\core\\E2SymbolInfo.mqh"
#include "include\\core\\E2AccountInfo.mqh"
#include "include\\analysis\\E2MarketData.mqh"
#include "include\\filters\\E2NewsFilter.mqh"
#include "include\\risk\\E2PositionSizer.mqh"
#include "include\\risk\\E2OrderRequest.mqh"
#include "include\\execution\\E2PositionGuard.mqh"
#include "include\\execution\\E2ExecutionSafety.mqh"
#include "include\\execution\\E2OrderExecutor.mqh"
#include "include\\reporting\\E2Logger.mqh"
#include "include\\reporting\\E2TradeReporter.mqh"
#include "include\\reporting\\E2BacktestSummary.mqh"
#include "include\\visualization\\E2Visualizer.mqh"

E2Config g_configuration;
E2Environment g_environment;
E2Logger g_logger;
E2SymbolInfo g_symbol_info;
E2AccountInfo g_account_info;
E2MarketData g_market_data;
E2NewsFilter g_news_filter;
E2PositionSizer g_position_sizer;
E2PositionGuard g_position_guard;
E2ExecutionSafety g_execution_safety;
E2OrderExecutor g_order_executor;
E2TradeReporter g_trade_reporter;
E2BacktestSummary g_backtest_summary;
E2Visualizer g_visualizer;

bool g_initialized=false;
int g_strategy_candidates=0;
int g_trade_requests=0;
int g_execution_attempts=0;
int g_execution_successes=0;
int g_ownership_violations=0;

void E2EmitVerification(void)
  {
   if(!g_configuration.core_verification_enabled)return;
   const int unknown_positions=g_trade_reporter.UnknownE2Positions(_Symbol);
   g_backtest_summary.CoreVerify(g_initialized,g_strategy_candidates,g_trade_requests,g_execution_attempts,g_execution_successes,g_trade_reporter.RegisteredCount(),g_trade_reporter.FinalizedCount(),g_trade_reporter.DuplicateExecutionIds(),g_trade_reporter.DuplicateFinalizedTrades(),g_trade_reporter.CausalityViolations(),g_ownership_violations,unknown_positions);
   g_logger.Info("totalExposedInputs="+IntegerToString(E2ExposedInputCount())+", deadInputs="+IntegerToString(E2DeadInputCount())+", duplicateInputs="+IntegerToString(E2DuplicateInputCount())+", invalidMappings="+IntegerToString(E2InvalidInputMappingCount())+".","E2_INPUT_VERIFY");
  }

int OnInit()
  {
   E2LoadConfiguration(g_configuration);
   g_logger.Initialize(g_configuration.logging_enabled,g_configuration.debug_mode);
   string reason;
   if(!E2ValidateConfiguration(g_configuration,reason)){g_logger.Error(reason,"Initialization");return(INIT_PARAMETERS_INCORRECT);}
   g_environment.Initialize();
   if(!g_symbol_info.Initialize(_Symbol,g_logger)){g_logger.Error("Symbol initialization failed.","Initialization");return(INIT_FAILED);}
   if(!g_account_info.Initialize(g_logger)){g_logger.Error("Account initialization failed.","Initialization");return(INIT_FAILED);}
   g_market_data.Initialize(g_logger);
   g_news_filter.Initialize(g_configuration,g_logger);
   g_position_sizer.Initialize(g_configuration,g_symbol_info,g_account_info,g_logger);
   g_position_guard.Initialize(g_configuration,g_logger);
   g_execution_safety.Initialize(g_configuration,g_logger);
   g_order_executor.Initialize(g_configuration,g_symbol_info,g_account_info,g_position_guard,g_execution_safety,g_logger);
   if(!g_trade_reporter.Initialize(g_configuration.csv_export_enabled,g_configuration.expert_magic_number,_Symbol,g_logger))return(INIT_FAILED);
   g_backtest_summary.Initialize(g_logger);
   g_visualizer.Initialize(g_configuration,g_logger);
   g_initialized=true;
   g_logger.Info("Initialized in "+g_environment.Name()+". Strategy layer=NONE; no candidate, request, or execution route exists.","Core");
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   // Sprint 1 intentionally has no strategy layer. Generic services remain
   // initialized, but no candidate, request, or execution can be produced.
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD&&trans.deal>0)g_trade_reporter.OnDeal(trans.deal);
  }

void OnDeinit(const int reason)
  {
   g_trade_reporter.Reconcile();
   E2EmitVerification();
   g_visualizer.Cleanup();
   g_trade_reporter.Close();
   g_initialized=false;
  }
