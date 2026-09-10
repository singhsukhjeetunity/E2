#property strict
#property version "4.1"
#property description "E2 mechanical trading strategy with explicit broker-time handling."

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
#include "include\\strategy\\E2XauSessionFadeEngine.mqh"
#include "include\\strategy\\E2XauSessionFadeTradePlanner.mqh"

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
E2XauSessionFadeEngine g_xau_engine;
E2PositionRecovery g_position_recovery;
E2XauSessionFadeTradePlanner g_xau_planner;

bool g_initialized=false;
datetime g_last_observed_m5_bar=0;
int g_strategy_candidates=0;
int g_trade_requests=0,g_new_positions_registered=0,g_recovered_positions_registered=0;
E2ExecutionVerification g_execution_verify;
E2RVerification g_r_verify;

#include "include\\execution\\E2EntryLifecycle.mqh"

string E2ActiveStrategyName(void)
  {
   return("XAU_SESSION_FADE");
  }

bool E2SymbolAllowedForStrategy(void)
  {
   string base=SymbolInfoString(_Symbol,SYMBOL_CURRENCY_BASE);
   string profit=SymbolInfoString(_Symbol,SYMBOL_CURRENCY_PROFIT);
   string s=_Symbol;StringToUpper(s);
   return((base=="XAU"&&profit=="USD")||(StringFind(s,"XAU")>=0&&StringFind(s,"USD")>=0));
  }

void E2EnforceWeekendFlat(void)
  {
   datetime now=TimeCurrent();if(!g_weekend_flat.IsBlockedAt(now))return;ulong ticket=0,position_id=0;if(!g_position_guard.FindOpenE2Position(_Symbol,ticket,position_id))return;if(!g_weekend_flat.ShouldAttemptClose(ticket,now))return;
   g_logger.Info("ticket="+StringFormat("%I64u",ticket)+", positionId="+StringFormat("%I64u",position_id)+", symbol="+_Symbol+".","WEEKEND_FLAT_CLOSE_REQUEST");E2PositionCloseResult result;if(!g_order_executor.CloseOwnedPosition(_Symbol,ticket,position_id,result)){g_logger.Error("ticket="+StringFormat("%I64u",ticket)+", positionId="+StringFormat("%I64u",position_id)+", retcode="+IntegerToString((int)result.retcode)+", description="+result.description+".","WEEKEND_FLAT_CLOSE_FAILED");return;}
   g_trade_reporter.MarkExitReason(position_id,"WEEKEND_FLAT");double profit=0.0;if(result.deal_ticket>0&&HistoryDealSelect(result.deal_ticket)){if(result.close_price<=0.0)result.close_price=HistoryDealGetDouble(result.deal_ticket,DEAL_PRICE);profit=HistoryDealGetDouble(result.deal_ticket,DEAL_PROFIT)+HistoryDealGetDouble(result.deal_ticket,DEAL_COMMISSION)+HistoryDealGetDouble(result.deal_ticket,DEAL_SWAP)+HistoryDealGetDouble(result.deal_ticket,DEAL_FEE);}g_logger.Info("ticket="+StringFormat("%I64u",ticket)+", positionId="+StringFormat("%I64u",position_id)+", deal="+StringFormat("%I64u",result.deal_ticket)+", closePrice="+DoubleToString(result.close_price,_Digits)+", realizedPnL="+DoubleToString(profit,2)+".","WEEKEND_FLAT_CLOSE_SUCCESS");g_trade_reporter.Reconcile();g_position_recovery.Reconcile(g_trade_reporter.IsFinalizedPosition(position_id));
  }

void E2EmitVerification(void)
  {
   if(!g_configuration.core_verification_enabled)return;
   E2PlanVerification plan=g_xau_planner.Verification();
   const int trade_requests=g_trade_requests;
   const int execution_attempts=g_execution_verify.attempts;
   const int execution_successes=g_execution_verify.successes;
   const int ownership_violations=0;
   const int unknown_positions=g_trade_reporter.UnknownE2Positions(_Symbol);
   g_trade_reporter.Verify(g_strategy_candidates,g_trade_requests,g_execution_verify.attempts,g_execution_verify.successes,g_new_positions_registered);
   g_position_recovery.AuditDayEntries();
   g_backtest_summary.CoreVerify(g_initialized,g_strategy_candidates,trade_requests,execution_attempts,execution_successes,g_new_positions_registered,g_trade_reporter.FinalizedCount(),g_trade_reporter.DuplicateExecutionIds(),g_trade_reporter.DuplicateFinalizedTrades(),g_trade_reporter.CausalityViolations(),ownership_violations,unknown_positions);
   E2SignalVerification signal=g_xau_engine.SignalVerification();
   g_backtest_summary.SignalVerify("XAU_SF_SIGNAL_VERIFY",signal);
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
   if(_Period!=PERIOD_M5){g_logger.Error(E2ActiveStrategyName()+" requires M5.","Initialization");return(INIT_PARAMETERS_INCORRECT);}
   g_environment.Initialize();
   if(!g_symbol_info.Initialize(_Symbol,g_logger)){g_logger.Error("Symbol initialization failed.","Initialization");return(INIT_FAILED);}
   if(!g_account_info.Initialize(g_logger)){g_logger.Error("Account initialization failed.","Initialization");return(INIT_FAILED);}
   E2AccountSpecification account=g_account_info.Specification();
   if(!g_environment.IsTester()&&g_configuration.trading_enabled&&account.trade_mode==ACCOUNT_TRADE_MODE_REAL&&!g_configuration.confirm_real_account_trading)
     {
      g_logger.Error("REAL_ACCOUNT_CONFIRMATION_REQUIRED: set InpConfirmRealAccountTrading=true only after verifying symbol, risk, broker UTC offset, and spread settings.","Initialization");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(!g_environment.IsTester()&&g_configuration.trading_enabled&&g_configuration.risk_mode==E2_RISK_FIXED_CASH)
      g_logger.Warning("Fixed-cash risk is enabled. Verify InpFixedCashRisk before live/prop deployment.","Initialization");
   g_market_data.Initialize(g_logger);
   g_position_sizer.Initialize(g_configuration,g_symbol_info,g_account_info,g_logger);
   g_position_guard.Initialize(g_configuration,g_logger);
   g_execution_safety.Initialize(g_configuration,g_logger);
   g_weekend_flat.Initialize(g_configuration,_Symbol,g_logger);
   g_order_executor.Initialize(g_configuration,g_symbol_info,g_account_info,g_position_guard,g_execution_safety,g_weekend_flat,g_broker_time,g_logger);
   if(!E2SymbolAllowedForStrategy()){g_logger.Error("Selected strategy is not allowed on this symbol.","Initialization");return(INIT_PARAMETERS_INCORRECT);}
   if(g_configuration.broker_time_profile!="")
     {
      if(!g_broker_time.Initialize(g_configuration.broker_time_profile,AccountInfoString(ACCOUNT_SERVER),g_environment.IsTester(),g_logger)||!g_broker_time.ValidateNow(TimeCurrent()))return(INIT_PARAMETERS_INCORRECT);
     }
   else if(g_configuration.xau_time_basis==E2_XAU_TIME_SERVER)
     {
      if(!g_broker_time.InitializeServerTimeProfile(AccountInfoString(ACCOUNT_SERVER),g_logger)||!g_broker_time.ValidateNow(TimeCurrent()))return(INIT_PARAMETERS_INCORRECT);
     }
   else if(g_configuration.use_manual_broker_utc_offset)
     {
      if(!g_broker_time.InitializeManualFixedOffsetProfile(AccountInfoString(ACCOUNT_SERVER),g_configuration.broker_utc_offset_seconds,g_logger)||!g_broker_time.ValidateNow(TimeCurrent()))return(INIT_PARAMETERS_INCORRECT);
     }
   else
     {
      g_logger.Error("PROFILE_OR_MANUAL_OFFSET_REQUIRED: UTC XAU timing needs InpBrokerTimeProfile or InpUseManualBrokerUtcOffset=true.","BROKER_TIME");
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_configuration.time_policy_digest=g_broker_time.Digest();
   if(!E2LoadEntryIntent()){Print("[E2][ERROR] Invalid pending-entry journal; inspect before trading.");return(INIT_FAILED);}
   if(!g_trade_reporter.Initialize(g_configuration,_Symbol,g_logger))return(INIT_FAILED);
   g_reporter_ready=true;
   g_backtest_summary.Initialize(g_logger);
   E2PositionMetadata recovered;bool has_recovered=false;if(!g_position_recovery.Initialize(g_configuration,_Symbol,g_environment.IsTester(),g_broker_time,g_logger,recovered,has_recovered,g_entry_pending))return(INIT_FAILED);if(has_recovered){if(!g_trade_reporter.Register(recovered,true)){g_logger.Error("Recovered position could not be registered.","Recovery");return(INIT_FAILED);}g_recovered_positions_registered++;g_r_verify.recovered_positions_validated++;if(g_configuration.one_trade_per_day)g_position_recovery.ReconstructDayLock(recovered.entry_deal,recovered.entry_time);}
   g_xau_planner.Initialize(g_configuration,g_symbol_info,g_position_sizer,g_position_guard,g_position_recovery,g_weekend_flat,g_logger);
   E2EnforceWeekendFlat();
   if(!g_xau_engine.Initialize(_Symbol,g_configuration,g_broker_time,g_weekend_flat,g_logger)){g_logger.Error("XAU session-fade reconstruction failed.","Initialization");return(INIT_FAILED);}
   MqlRates latest;if(g_market_data.GetClosedBar(_Symbol,PERIOD_M5,0,latest)){g_last_observed_m5_bar=latest.time;g_logger.Info("Completed M5 market data is ready; latestClosedBar="+TimeToString(latest.time,TIME_DATE|TIME_MINUTES)+".","MarketData");}else g_logger.Warning("Completed M5 market data is not ready at initialization; the inert core will retry on ticks.","MarketData");
   if(!EventSetTimer(1)){Print("[E2][ERROR] Could not start entry reconciliation timer.");return(INIT_FAILED);}
   g_initialized=true;
   g_logger.Info("Initialized in "+g_environment.Name()+". "+E2ActiveStrategyName()+" planning, execution, fixed-R protection, lifecycle reporting, and recovery are active.","Core");
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   if(!g_initialized)return;
   E2ReconcileEntry();
   g_trade_reporter.Reconcile();g_position_recovery.Reconcile(g_trade_reporter.IsFinalizedPosition(g_position_recovery.ActivePositionId()));
   E2EnforceWeekendFlat();
   if(g_entry_pending)return;
   g_trade_reporter.ObserveBar(iTime(_Symbol,PERIOD_M5,1));
   E2Candidate candidates[];if(!g_xau_engine.Evaluate(candidates,g_position_recovery))return;
   E2SignalVerification verification=g_xau_engine.SignalVerification();
   g_strategy_candidates=(int)verification.total_candidates;
   for(int i=0;i<ArraySize(candidates);i++)
     {
      g_trade_reporter.BeginCandidate(candidates[i]);E2OrderRequest request;E2PlanningAudit audit;bool planned=g_xau_planner.Build(candidates[i],request,audit);g_trade_reporter.RecordPlanning(candidates[i].candidate_id,audit);if(!planned)continue;g_trade_requests++;
      g_execution_verify.attempts++;E2ExecutionResult result;
      if(!E2BeginEntry(candidates[i],request))continue;
      bool accepted=g_order_executor.Execute(request,g_entry_comment,result);
      g_entry_result=result;
      if(!accepted)
        {
         g_execution_verify.failures++;g_trade_reporter.RecordExecutionFailure(candidates[i].candidate_id,result);
         // Timeout/connection/no-result may still have executed. Never retry or erase their intent.
         uint rc=result.retcode;
         bool refused=(rc==TRADE_RETCODE_REQUOTE||rc==TRADE_RETCODE_REJECT||rc==TRADE_RETCODE_INVALID||
            rc==TRADE_RETCODE_INVALID_VOLUME||rc==TRADE_RETCODE_INVALID_PRICE||rc==TRADE_RETCODE_INVALID_STOPS||
            rc==TRADE_RETCODE_TRADE_DISABLED||rc==TRADE_RETCODE_MARKET_CLOSED||rc==TRADE_RETCODE_NO_MONEY||
            rc==TRADE_RETCODE_PRICE_CHANGED||rc==TRADE_RETCODE_PRICE_OFF||rc==TRADE_RETCODE_INVALID_FILL||
            rc==TRADE_RETCODE_TOO_MANY_REQUESTS||rc==TRADE_RETCODE_CLIENT_DISABLES_AT||rc==TRADE_RETCODE_SERVER_DISABLES_AT);
         bool uncertain=result.submitted&&(!refused||result.order_ticket>0||result.deal_ticket>0);
         if(!uncertain){E2ClearEntryIntent();continue;}
        }
      else g_execution_verify.successes++;
      if(!E2WriteEntryIntent())E2EntryAlert("Order result could not be persisted; original intent retained");
      E2ReconcileEntry();
      break;
     }
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_reporter_ready){g_trade_reporter.Close();E2EmitVerification();g_reporter_ready=false;}
   g_xau_engine.Shutdown();
   g_initialized=false;
  }

void OnTimer()
  {
   if(!g_initialized)return;
   E2ReconcileEntry();
   g_trade_reporter.Reconcile();
   g_position_recovery.Reconcile(g_trade_reporter.IsFinalizedPosition(g_position_recovery.ActivePositionId()));
   E2EnforceWeekendFlat();
  }

void OnTradeTransaction(const MqlTradeTransaction &transaction,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(!g_initialized||!g_entry_pending)return;
   // Keep callbacks short; the timer also handles missing/out-of-order notifications.
   if(transaction.type==TRADE_TRANSACTION_DEAL_ADD||transaction.type==TRADE_TRANSACTION_HISTORY_ADD)
      {g_entry_retry_ms=0;E2ReconcileEntry();}
  }
