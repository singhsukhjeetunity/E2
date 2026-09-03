#property strict
#property version "4.0"
#property description "E2 London Range Breakout with explicit broker-time profiles."

#include "include\\core\\E2Config.mqh"
#include "include\\time\\E2BrokerTimeAdapter.mqh"
#include "include\\core\\E2Environment.mqh"
#include "include\\core\\E2SymbolInfo.mqh"
#include "include\\core\\E2AccountInfo.mqh"
#include "include\\analysis\\E2MarketData.mqh"
#include "include\\risk\\E2PositionSizer.mqh"
#include "include\\risk\\E2OrderRequest.mqh"
#include "include\\execution\\E2PositionGuard.mqh"
#include "include\\execution\\E2ExecutionSafety.mqh"
#include "include\\execution\\E2WeekendFlat.mqh"
#include "include\\execution\\E2OrderExecutor.mqh"
#include "include\\reporting\\E2Logger.mqh"
#include "include\\reporting\\E2TradeReporter.mqh"
#include "include\\reporting\\E2BacktestSummary.mqh"
#include "include\\strategy\\E2LondonBreakoutEngine.mqh"
#include "include\\strategy\\E2LondonTradePlanner.mqh"

E2Config g_configuration;
E2BrokerTimeAdapter g_broker_time;
bool g_reporter_ready=false;
E2Environment g_environment;
E2Logger g_logger;
E2SymbolInfo g_symbol_info;
E2AccountInfo g_account_info;
E2MarketData g_market_data;
E2PositionSizer g_position_sizer;
E2PositionGuard g_position_guard;
E2ExecutionSafety g_execution_safety;
E2WeekendFlat g_weekend_flat;
E2OrderExecutor g_order_executor;
E2TradeReporter g_trade_reporter;
E2BacktestSummary g_backtest_summary;
E2LondonBreakoutEngine g_london_engine;
E2PositionRecovery g_position_recovery;
E2LondonTradePlanner g_london_planner;

bool g_initialized=false;
datetime g_last_observed_m5_bar=0;
int g_strategy_candidates=0;
int g_trade_requests=0,g_new_positions_registered=0,g_recovered_positions_registered=0;
E2ExecutionVerification g_execution_verify;
E2RVerification g_r_verify;

void E2EnforceWeekendFlat(void)
  {
   datetime now=TimeCurrent();if(!g_weekend_flat.IsBlockedAt(now))return;ulong ticket=0,position_id=0;if(!g_position_guard.FindOpenE2Position(_Symbol,ticket,position_id))return;if(!g_weekend_flat.ShouldAttemptClose(ticket,now))return;
   g_logger.Info("ticket="+StringFormat("%I64u",ticket)+", positionId="+StringFormat("%I64u",position_id)+", symbol="+_Symbol+".","WEEKEND_FLAT_CLOSE_REQUEST");E2PositionCloseResult result;if(!g_order_executor.CloseOwnedPosition(_Symbol,ticket,position_id,result)){g_logger.Error("ticket="+StringFormat("%I64u",ticket)+", positionId="+StringFormat("%I64u",position_id)+", retcode="+IntegerToString((int)result.retcode)+", description="+result.description+".","WEEKEND_FLAT_CLOSE_FAILED");return;}
   g_trade_reporter.MarkExitReason(position_id,"WEEKEND_FLAT");double profit=0.0;if(result.deal_ticket>0&&HistoryDealSelect(result.deal_ticket)){if(result.close_price<=0.0)result.close_price=HistoryDealGetDouble(result.deal_ticket,DEAL_PRICE);profit=HistoryDealGetDouble(result.deal_ticket,DEAL_PROFIT)+HistoryDealGetDouble(result.deal_ticket,DEAL_COMMISSION)+HistoryDealGetDouble(result.deal_ticket,DEAL_SWAP)+HistoryDealGetDouble(result.deal_ticket,DEAL_FEE);}g_logger.Info("ticket="+StringFormat("%I64u",ticket)+", positionId="+StringFormat("%I64u",position_id)+", deal="+StringFormat("%I64u",result.deal_ticket)+", closePrice="+DoubleToString(result.close_price,_Digits)+", realizedPnL="+DoubleToString(profit,2)+".","WEEKEND_FLAT_CLOSE_SUCCESS");g_trade_reporter.Reconcile();g_position_recovery.Reconcile(g_trade_reporter.IsFinalizedPosition(position_id));
  }

void E2EmitVerification(void)
  {
   if(!g_configuration.core_verification_enabled)return;
   const E2PlanVerification plan=g_london_planner.Verification();
   const int trade_requests=g_trade_requests;
   const int execution_attempts=g_execution_verify.attempts;
   const int execution_successes=g_execution_verify.successes;
   const int ownership_violations=0;
   const int unknown_positions=g_trade_reporter.UnknownE2Positions(_Symbol);
   g_trade_reporter.Verify(g_strategy_candidates,g_trade_requests,g_execution_verify.attempts,g_execution_verify.successes,g_new_positions_registered);
   g_position_recovery.AuditDayEntries();
   g_backtest_summary.CoreVerify(g_initialized,g_strategy_candidates,trade_requests,execution_attempts,execution_successes,g_new_positions_registered,g_trade_reporter.FinalizedCount(),g_trade_reporter.DuplicateExecutionIds(),g_trade_reporter.DuplicateFinalizedTrades(),g_trade_reporter.CausalityViolations(),ownership_violations,unknown_positions);
   g_backtest_summary.LondonSignalVerify(g_london_engine.SignalVerification());
   g_backtest_summary.RiskVerify(g_position_sizer.Verification());
   g_backtest_summary.PlanVerify(plan);g_backtest_summary.ExecVerify(g_execution_verify);g_backtest_summary.RVerify(g_r_verify);g_backtest_summary.DayVerify(g_position_recovery.DayVerification());g_backtest_summary.DayAudit(g_position_recovery.DayVerification());g_backtest_summary.DayRecoveryDiag(g_position_recovery.DayRecoveryDiagnostics());g_backtest_summary.RecoveryVerify(g_position_recovery.Verification());g_backtest_summary.RecoveryDiag(g_position_recovery.Diagnostics());g_backtest_summary.RecoveryDiagFields(g_position_recovery.Diagnostics());g_backtest_summary.RecoveryDiagComparisons(g_position_recovery.Diagnostics());
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
   if(_Period!=PERIOD_M5){g_logger.Error("London Range Breakout requires M5.","Initialization");return(INIT_PARAMETERS_INCORRECT);}
   g_environment.Initialize();
   if(!g_symbol_info.Initialize(_Symbol,g_logger)){g_logger.Error("Symbol initialization failed.","Initialization");return(INIT_FAILED);}
   if(!g_account_info.Initialize(g_logger)){g_logger.Error("Account initialization failed.","Initialization");return(INIT_FAILED);}
   g_market_data.Initialize(g_logger);
   g_position_sizer.Initialize(g_configuration,g_symbol_info,g_account_info,g_logger);
   g_position_guard.Initialize(g_configuration,g_logger);
   g_execution_safety.Initialize(g_configuration,g_logger);
   g_weekend_flat.Initialize(g_configuration,_Symbol,g_logger);
   g_order_executor.Initialize(g_configuration,g_symbol_info,g_account_info,g_position_guard,g_execution_safety,g_weekend_flat,g_broker_time,g_logger);
   if(SymbolInfoString(_Symbol,SYMBOL_CURRENCY_BASE)!="EUR"||SymbolInfoString(_Symbol,SYMBOL_CURRENCY_PROFIT)!="USD"){g_logger.Error("This baseline is EURUSD only (broker suffixes allowed).","Initialization");return(INIT_PARAMETERS_INCORRECT);}
   if(!g_broker_time.Initialize(g_configuration.broker_time_profile,AccountInfoString(ACCOUNT_SERVER),g_environment.IsTester(),g_logger)||!g_broker_time.ValidateNow(TimeCurrent()))return(INIT_PARAMETERS_INCORRECT);
   g_configuration.time_policy_digest=g_broker_time.Digest();
   if(!g_trade_reporter.Initialize(g_configuration,_Symbol,g_logger))return(INIT_FAILED);
   g_reporter_ready=true;
   g_backtest_summary.Initialize(g_logger);
   E2PositionMetadata recovered;bool has_recovered=false;if(!g_position_recovery.Initialize(g_configuration,_Symbol,g_environment.IsTester(),g_broker_time,g_logger,recovered,has_recovered))return(INIT_FAILED);if(has_recovered){if(!g_trade_reporter.Register(recovered,true)){g_logger.Error("Recovered position could not be registered.","Recovery");return(INIT_FAILED);}g_recovered_positions_registered++;g_r_verify.recovered_positions_validated++;if(g_configuration.one_trade_per_day)g_position_recovery.ReconstructDayLock(recovered.entry_deal,recovered.entry_time);}
   g_london_planner.Initialize(g_configuration,g_symbol_info,g_position_sizer,g_position_guard,g_position_recovery,g_weekend_flat,g_broker_time,g_logger);E2EnforceWeekendFlat();
   if(!g_london_engine.Initialize(_Symbol,g_configuration,g_broker_time,g_weekend_flat,g_logger)){g_logger.Error("London range reconstruction failed.","Initialization");return(INIT_FAILED);}
   MqlRates latest;if(g_market_data.GetClosedBar(_Symbol,PERIOD_M5,0,latest)){g_last_observed_m5_bar=latest.time;g_logger.Info("Completed M5 market data is ready; latestClosedBar="+TimeToString(latest.time,TIME_DATE|TIME_MINUTES)+".","MarketData");}else g_logger.Warning("Completed M5 market data is not ready at initialization; the inert core will retry on ticks.","MarketData");
   g_initialized=true;
   g_logger.Info("Initialized in "+g_environment.Name()+". London breakout planning, execution, fixed-R protection, lifecycle reporting, and recovery are active.","Core");
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   if(!g_initialized)return;
   g_trade_reporter.Reconcile();g_position_recovery.Reconcile(g_trade_reporter.IsFinalizedPosition(g_position_recovery.ActivePositionId()));
   E2EnforceWeekendFlat();
   g_trade_reporter.ObserveBar(iTime(_Symbol,PERIOD_M5,1));
   E2Candidate candidates[];if(!g_london_engine.Evaluate(candidates,g_position_recovery))return;
   const E2SignalVerification verification=g_london_engine.SignalVerification();g_strategy_candidates=(int)verification.total_candidates;
   for(int i=0;i<ArraySize(candidates);i++)
     {
      g_trade_reporter.BeginCandidate(candidates[i]);E2OrderRequest request;E2PlanningAudit audit;bool planned=g_london_planner.Build(candidates[i],request,audit);g_trade_reporter.RecordPlanning(candidates[i].candidate_id,audit);if(!planned)continue;g_trade_requests++;
      g_execution_verify.attempts++;E2ExecutionResult result;
      if(!g_order_executor.Execute(request,"E2LRB|"+StringSubstr(candidates[i].candidate_id,0,20),result)){g_execution_verify.failures++;g_trade_reporter.RecordExecutionFailure(candidates[i].candidate_id,result);continue;}
      g_execution_verify.successes++;if(result.deal_ticket==0||!HistoryDealSelect(result.deal_ticket)){g_execution_verify.unresolved_entry_deals++;g_logger.Error("Successful execution has no authoritative entry deal.","Execution");continue;}
      E2PositionMetadata m;ZeroMemory(m);m.candidate_id=candidates[i].candidate_id;m.execution_id=request.execution_id;m.symbol=request.symbol;m.direction=request.direction;m.signal_time=request.signal_time;m.entry_time=(datetime)HistoryDealGetInteger(result.deal_ticket,DEAL_TIME);m.entry_deal=result.deal_ticket;m.position_id=(ulong)HistoryDealGetInteger(result.deal_ticket,DEAL_POSITION_ID);for(int p=0;p<PositionsTotal();p++){ulong ticket=PositionGetTicket(p);if(ticket>0&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==m.position_id){m.position_ticket=ticket;break;}}m.volume=HistoryDealGetDouble(result.deal_ticket,DEAL_VOLUME);m.fill_price=HistoryDealGetDouble(result.deal_ticket,DEAL_PRICE);m.submitted_stop=request.submitted_stop_price;m.original_r=MathAbs(m.fill_price-m.submitted_stop);m.target_r=g_configuration.target_r;m.requested_risk_cash=request.requested_risk_cash;
      m.london_day=candidates[i].london_day;m.range_start_london=candidates[i].range_start_london;m.range_end_london=candidates[i].range_end_london;m.range_high=candidates[i].range_high;m.range_low=candidates[i].range_low;m.signal_close=candidates[i].signal_close;m.breakout_distance=candidates[i].breakout_distance;m.time_policy_digest=g_configuration.time_policy_digest;
      if(m.original_r<=0.0){g_r_verify.invalid_r_geometry++;continue;}double raw_target=(m.direction==E2_DIRECTION_LONG?m.fill_price+m.original_r*m.target_r:m.fill_price-m.original_r*m.target_r);m.target_price=g_symbol_info.NormalizePrice(raw_target);
      if((m.direction==E2_DIRECTION_LONG&&m.target_price<=m.fill_price)||(m.direction==E2_DIRECTION_SHORT&&m.target_price>=m.fill_price)){g_r_verify.invalid_r_geometry++;continue;}
      if(!g_position_sizer.CalculateActualRisk(m.symbol,m.direction,m.volume,m.fill_price,m.submitted_stop,m.actual_risk_cash)){g_logger.Error("Actual entry risk could not be calculated.","Risk");continue;}g_position_sizer.RecordOriginalRiskCash(m.actual_risk_cash);
      if(!g_position_recovery.Save(m)){g_logger.Error("Filled position recovery state could not be persisted.","Recovery");continue;}if(!g_trade_reporter.Register(m)){g_logger.Error("Filled position registration failed.","Reporting");continue;}g_new_positions_registered++;g_r_verify.new_positions_registered++;g_position_recovery.RecordLock();
      uint rc=0;string desc;if(!g_order_executor.AttachProtection(m.symbol,m.position_id,m.submitted_stop,m.target_price,rc,desc)&&!g_order_executor.AttachProtection(m.symbol,m.position_id,m.submitted_stop,m.target_price,rc,desc)){g_execution_verify.protection_failures++;g_logger.Error("TP attachment failed after retry; position remains SL-protected and registered: "+desc,"Protection");}else g_r_verify.targets_attached++;
      g_trade_reporter.RecordExecuted(candidates[i].candidate_id,result,m);
     }
  }

void OnDeinit(const int reason)
  {
   if(g_reporter_ready){g_trade_reporter.Close();E2EmitVerification();g_reporter_ready=false;}
   g_london_engine.Shutdown();
   g_initialized=false;
  }
