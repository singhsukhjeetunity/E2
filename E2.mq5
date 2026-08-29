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
#include "include\\strategy\\E2ADXBBEngine.mqh"
#include "include\\strategy\\E2ADXBBTradePlanner.mqh"

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
E2ADXBBEngine g_adxbb_engine;
E2ADXBBRecovery g_adxbb_recovery;
E2ADXBBTradePlanner g_adxbb_planner;

bool g_initialized=false;
datetime g_last_observed_m5_bar=0;
int g_strategy_candidates=0;
int g_trade_requests=0,g_new_positions_registered=0,g_recovered_positions_registered=0;
E2ADXBBExecutionVerification g_execution_verify;
E2ADXBBRVerification g_r_verify;

void E2EmitVerification(void)
  {
   if(!g_configuration.core_verification_enabled)return;
   const E2ADXBBPlanVerification plan=g_adxbb_planner.Verification();
   const int trade_requests=g_trade_requests;
   const int execution_attempts=g_execution_verify.attempts;
   const int execution_successes=g_execution_verify.successes;
   const int ownership_violations=0;
   const int unknown_positions=g_trade_reporter.UnknownE2Positions(_Symbol);
   g_trade_reporter.Verify(g_strategy_candidates,g_trade_requests,g_execution_verify.attempts,g_execution_verify.successes,g_new_positions_registered);
   g_adxbb_recovery.AuditDayEntries();
   g_backtest_summary.CoreVerify(g_initialized,g_strategy_candidates,trade_requests,execution_attempts,execution_successes,g_new_positions_registered,g_trade_reporter.FinalizedCount(),g_trade_reporter.DuplicateExecutionIds(),g_trade_reporter.DuplicateFinalizedTrades(),g_trade_reporter.CausalityViolations(),ownership_violations,unknown_positions);
   g_backtest_summary.ADXBBSignalVerify(g_adxbb_engine.SignalVerification());
   g_backtest_summary.ADXBBIndicatorVerify(g_adxbb_engine.IndicatorVerification());
   g_backtest_summary.RiskVerify(g_position_sizer.Verification());
   g_backtest_summary.PlanVerify(plan);g_backtest_summary.ExecVerify(g_execution_verify);g_backtest_summary.RVerify(g_r_verify);g_backtest_summary.DayVerify(g_adxbb_recovery.DayVerification());g_backtest_summary.DayAudit(g_adxbb_recovery.DayVerification());g_backtest_summary.DayRecoveryDiag(g_adxbb_recovery.DayRecoveryDiagnostics());g_backtest_summary.RecoveryVerify(g_adxbb_recovery.Verification());g_backtest_summary.RecoveryDiag(g_adxbb_recovery.Diagnostics());g_backtest_summary.RecoveryDiagFields(g_adxbb_recovery.Diagnostics());g_backtest_summary.RecoveryDiagComparisons(g_adxbb_recovery.Diagnostics());
   g_backtest_summary.ReconcileVerify(g_trade_reporter.ReconcileVerification());g_backtest_summary.FinancialVerify(g_trade_reporter.FinancialVerification());
   g_logger.Info("totalExposedInputs="+IntegerToString(E2ExposedInputCount())+", deadInputs="+IntegerToString(E2DeadInputCount())+", duplicateInputs="+IntegerToString(E2DuplicateInputCount())+", invalidMappings="+IntegerToString(E2InvalidInputMappingCount())+".","E2_INPUT_VERIFY");
  }

int OnInit()
  {
   E2LoadConfiguration(g_configuration);
   ZeroMemory(g_execution_verify);ZeroMemory(g_r_verify);g_trade_requests=0;g_new_positions_registered=0;g_recovered_positions_registered=0;
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
   if(!g_trade_reporter.Initialize(g_configuration,_Symbol,g_logger))return(INIT_FAILED);
   g_backtest_summary.Initialize(g_logger);
   if(!g_adxbb_engine.Initialize(_Symbol,g_configuration,g_symbol_info.PipSize(),g_trade_reporter.RunId(),g_trade_reporter.ConfigHash(),g_market_data,g_logger)){g_logger.Error("ADXBB signal engine initialization failed.","Initialization");return(INIT_FAILED);}
   E2ADXBBPositionMetadata recovered;bool has_recovered=false;if(!g_adxbb_recovery.Initialize(g_configuration,_Symbol,g_environment.IsTester(),g_logger,recovered,has_recovered))return(INIT_FAILED);if(has_recovered){if(!g_trade_reporter.Register(recovered,true)){g_logger.Error("Recovered position could not be registered.","Recovery");return(INIT_FAILED);}g_recovered_positions_registered++;g_r_verify.recovered_positions_validated++;if(g_configuration.one_trade_per_day)g_adxbb_recovery.ReconstructDayLock(recovered.entry_deal,recovered.entry_time);}
   g_adxbb_planner.Initialize(g_configuration,g_symbol_info,g_position_sizer,g_position_guard,g_adxbb_recovery,g_logger);
   MqlRates latest;if(g_market_data.GetClosedBar(_Symbol,PERIOD_M5,0,latest)){g_last_observed_m5_bar=latest.time;g_logger.Info("Completed M5 market data is ready; latestClosedBar="+TimeToString(latest.time,TIME_DATE|TIME_MINUTES)+".","MarketData");}else g_logger.Warning("Completed M5 market data is not ready at initialization; the inert core will retry on ticks.","MarketData");
   g_initialized=true;
   const string risk_mode=(g_configuration.risk_mode==E2_RISK_FIXED_CASH?"FIXED_CASH":"BALANCE_PERCENT");
   g_logger.Info("symbol="+_Symbol+", timeframe=M5, strategy=ADXBB, bbBufferPips="+DoubleToString(g_configuration.adxbb_bb_buffer_pips,3)+", bbBufferPrice="+DoubleToString(g_configuration.adxbb_bb_buffer_pips*g_symbol_info.PipSize(),_Digits)+", targetR="+DoubleToString(g_configuration.adxbb_target_r,2)+", oneTradePerDay="+IntegerToString((int)g_configuration.one_trade_per_day)+", tradingEnabled="+IntegerToString((int)g_configuration.trading_enabled)+", riskMode="+risk_mode+", magicNumber="+StringFormat("%I64u",g_configuration.expert_magic_number)+".","E2_PRODUCTION_CONFIG");
   g_logger.Info("Initialized in "+g_environment.Name()+". ADXBB planning, execution, fixed-R protection, lifecycle reporting, and recovery are active.","Core");
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   g_trade_reporter.Reconcile();g_adxbb_recovery.Reconcile(g_trade_reporter.IsFinalizedPosition(g_adxbb_recovery.ActivePositionId()));
   g_trade_reporter.ObserveBar(iTime(_Symbol,PERIOD_M5,1));
   E2ADXBBCandidate candidates[];if(!g_adxbb_engine.Evaluate(candidates))return;
   const E2ADXBBSignalVerification verification=g_adxbb_engine.SignalVerification();g_strategy_candidates=(int)verification.total_candidates;
   for(int i=0;i<ArraySize(candidates);i++)
     {
      g_trade_reporter.BeginCandidate(candidates[i]);E2OrderRequest request;E2ADXBBPlanningAudit audit;bool planned=g_adxbb_planner.Build(candidates[i],request,audit);g_trade_reporter.RecordPlanning(candidates[i].candidate_id,audit);if(!planned)continue;g_trade_requests++;
      g_execution_verify.attempts++;E2ExecutionResult result;
      if(!g_order_executor.Execute(request,"E2ADXBB|"+StringSubstr(candidates[i].candidate_id,0,20),result)){g_execution_verify.failures++;g_trade_reporter.RecordExecutionFailure(candidates[i].candidate_id,result);continue;}
      g_execution_verify.successes++;if(result.deal_ticket==0||!HistoryDealSelect(result.deal_ticket)){g_execution_verify.unresolved_entry_deals++;g_logger.Error("Successful execution has no authoritative entry deal.","Execution");continue;}
      E2ADXBBPositionMetadata m;ZeroMemory(m);m.candidate_id=candidates[i].candidate_id;m.execution_id=request.execution_id;m.symbol=request.symbol;m.direction=request.direction;m.signal_time=request.signal_time;m.entry_time=(datetime)HistoryDealGetInteger(result.deal_ticket,DEAL_TIME);m.entry_deal=result.deal_ticket;m.position_id=(ulong)HistoryDealGetInteger(result.deal_ticket,DEAL_POSITION_ID);for(int p=0;p<PositionsTotal();p++){ulong ticket=PositionGetTicket(p);if(ticket>0&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==m.position_id){m.position_ticket=ticket;break;}}m.volume=HistoryDealGetDouble(result.deal_ticket,DEAL_VOLUME);m.fill_price=HistoryDealGetDouble(result.deal_ticket,DEAL_PRICE);m.submitted_stop=request.submitted_stop_price;m.original_r=MathAbs(m.fill_price-m.submitted_stop);m.target_r=g_configuration.adxbb_target_r;m.requested_risk_cash=request.requested_risk_cash;
      if(m.original_r<=0.0){g_r_verify.invalid_r_geometry++;continue;}double raw_target=(m.direction==E2_DIRECTION_LONG?m.fill_price+m.original_r*m.target_r:m.fill_price-m.original_r*m.target_r);m.target_price=g_symbol_info.NormalizePrice(raw_target);
      if((m.direction==E2_DIRECTION_LONG&&m.target_price<=m.fill_price)||(m.direction==E2_DIRECTION_SHORT&&m.target_price>=m.fill_price)){g_r_verify.invalid_r_geometry++;continue;}
      if(!g_position_sizer.CalculateActualRisk(m.symbol,m.direction,m.volume,m.fill_price,m.submitted_stop,m.actual_risk_cash)){g_logger.Error("Actual entry risk could not be calculated.","Risk");continue;}g_position_sizer.RecordOriginalRiskCash(m.actual_risk_cash);
      if(!g_adxbb_recovery.Save(m)){g_logger.Error("Filled position recovery state could not be persisted.","Recovery");continue;}if(!g_trade_reporter.Register(m)){g_logger.Error("Filled position registration failed.","Reporting");continue;}g_new_positions_registered++;g_r_verify.new_positions_registered++;g_adxbb_recovery.RecordLock();
      uint rc=0;string desc;if(!g_order_executor.AttachProtection(m.symbol,m.position_id,m.submitted_stop,m.target_price,rc,desc)&&!g_order_executor.AttachProtection(m.symbol,m.position_id,m.submitted_stop,m.target_price,rc,desc)){g_execution_verify.protection_failures++;g_logger.Error("TP attachment failed after retry; position remains SL-protected and registered: "+desc,"Protection");}else g_r_verify.targets_attached++;
      g_trade_reporter.RecordExecuted(candidates[i].candidate_id,result,m);
     }
  }

void OnDeinit(const int reason)
  {
   g_trade_reporter.Close();
   E2EmitVerification();
   g_adxbb_engine.Shutdown();
   g_initialized=false;
  }
