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
#include "include\\strategy\\E2OBREngine.mqh"
#include "include\\strategy\\E2OBRTradePlanner.mqh"

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
E2OBREngine g_obr_engine;
E2OBRRecovery g_obr_recovery;
E2OBRTradePlanner g_obr_planner;

bool g_initialized=false;
int g_strategy_candidates=0;
int g_trade_requests=0;
int g_execution_attempts=0;
int g_execution_successes=0;
int g_ownership_violations=0;
bool g_or_recovery_recorded=false;

string E2WeekdayConfiguration(void){string value="";if(g_configuration.obr_trade_monday)value="MON";if(g_configuration.obr_trade_tuesday)value+=(value==""?"":",")+"TUE";if(g_configuration.obr_trade_wednesday)value+=(value==""?"":",")+"WED";if(g_configuration.obr_trade_thursday)value+=(value==""?"":",")+"THU";if(g_configuration.obr_trade_friday)value+=(value==""?"":",")+"FRI";return(value==""?"NONE":value);}
string E2SessionConfiguration(void){return(g_configuration.obr_session==E2_OBR_SESSION_NEW_YORK?"selectedSession=NEW_YORK, sessionTimezone=America/New_York, OR=09:30-10:30":"selectedSession=LONDON, sessionTimezone=Europe/London, OR=08:00-09:00");}
string E2SessionWeekday(const string day){if(StringLen(day)!=8)return("INVALID");datetime value=StringToTime(StringSubstr(day,0,4)+"."+StringSubstr(day,4,2)+"."+StringSubstr(day,6,2));MqlDateTime p;TimeToStruct(value,p);string names[]={"SUN","MON","TUE","WED","THU","FRI","SAT"};return(names[p.day_of_week]);}

bool E2OwnedPositionState(const ulong position_id,double &stop_loss)
  {
   stop_loss=0.0;for(int i=0;i<PositionsTotal();i++){ulong ticket=PositionGetTicket(i);if(ticket>0&&(ulong)PositionGetInteger(POSITION_MAGIC)==g_configuration.expert_magic_number&&PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==position_id){stop_loss=PositionGetDouble(POSITION_SL);return(true);}}return(false);
  }

void E2MetadataToReport(const E2OBRPositionMetadata &m,E2ReportEntryData &entry)
  {
   ZeroMemory(entry);entry.symbol=m.symbol;entry.setup_id="OBR";entry.signal_id=m.candidate_id;entry.execution_id=m.execution_id;entry.session=g_obr_engine.SessionNameValue();entry.london_day=m.london_day;entry.session_weekday=E2SessionWeekday(m.london_day);entry.direction=m.direction;entry.signal_time=m.breakout_time;entry.signal_known_from=m.breakout_time+PeriodSeconds(PERIOD_M15);entry.intended_entry_time=entry.signal_known_from;entry.request_time=m.entry_time;entry.entry_time=m.entry_time;entry.or_high=m.or_high;entry.or_low=m.or_low;entry.or_size=m.or_high-m.or_low;entry.frozen_atr=m.frozen_atr;entry.frozen_adx=m.frozen_adx;entry.or_atr=(m.frozen_atr>0.0?entry.or_size/m.frozen_atr:0.0);entry.requested_entry_price=m.fill_price;entry.executable_quote=m.fill_price;entry.fill_price=m.fill_price;entry.structural_stop_price=m.structural_stop;entry.submitted_stop_price=m.submitted_stop;entry.take_profit_price=m.target_price;entry.target_r=g_configuration.obr_target_r;entry.original_r_price=m.original_r_price;entry.risk_mode=(g_configuration.risk_mode==E2_RISK_FIXED_CASH?"FIXED_CASH":"BALANCE_PERCENT");entry.requested_risk_cash=m.requested_risk_cash;entry.actual_risk_cash=m.actual_risk_cash;entry.volume=m.volume;entry.order_ticket=m.order_ticket;entry.entry_deal=m.entry_deal;
  }

void E2ExecuteOBRCandidate(const E2OBRCandidate &candidate)
  {
   E2OrderRequest request;E2OBRPlanContext context;if(!g_obr_planner.Build(candidate,request,context))return;g_trade_requests++;
   if(!g_obr_planner.BeginExecution(request))return;g_execution_attempts++;
   E2ExecutionResult result;const string comment=(g_configuration.obr_session==E2_OBR_SESSION_NEW_YORK?"E2OBRNY|":"E2OBR|")+candidate.london_day+"|"+(candidate.direction==E2_DIRECTION_LONG?"L":"S");if(!g_order_executor.Execute(request,comment,result)){g_obr_planner.RecordFailure(result.status);return;}
   g_execution_successes++;g_obr_planner.RecordSuccess(candidate.london_day);
   if(result.deal_ticket==0||!HistoryDealSelect(result.deal_ticket)){HistorySelect(TimeCurrent()-86400,TimeCurrent());if(result.deal_ticket==0||!HistoryDealSelect(result.deal_ticket)){g_obr_planner.RecordUnresolved();return;}}
   const ulong position_id=(ulong)HistoryDealGetInteger(result.deal_ticket,DEAL_POSITION_ID);const double fill=HistoryDealGetDouble(result.deal_ticket,DEAL_PRICE);const datetime entry_time=(datetime)HistoryDealGetInteger(result.deal_ticket,DEAL_TIME);double submitted=request.submitted_stop_price;double live_stop=0.0;if(E2OwnedPositionState(position_id,live_stop)&&live_stop>0.0)submitted=live_stop;else if(result.order_ticket>0&&HistoryOrderSelect(result.order_ticket)){double accepted=HistoryOrderGetDouble(result.order_ticket,ORDER_SL);if(accepted>0.0)submitted=accepted;}
   const double original_r=(candidate.direction==E2_DIRECTION_LONG?fill-submitted:submitted-fill);if(position_id==0||fill<=0.0||submitted<=0.0||original_r<=0.0){g_obr_planner.RecordUnresolved();return;}
   const double raw_target=(candidate.direction==E2_DIRECTION_LONG?fill+g_configuration.obr_target_r*original_r:fill-g_configuration.obr_target_r*original_r);const double target=g_symbol_info.NormalizePrice(raw_target);uint protect_retcode=0;string protect_description="";bool protected_ok=g_order_executor.AttachProtection(candidate.symbol,position_id,submitted,target,protect_retcode,protect_description);if(!protected_ok)protected_ok=g_order_executor.AttachProtection(candidate.symbol,position_id,submitted,target,protect_retcode,protect_description);if(!protected_ok){g_obr_planner.RecordProtectionFailure();g_logger.Error("TP attachment failed for position="+StringFormat("%I64u",position_id)+", retcode="+IntegerToString((int)protect_retcode)+", description="+protect_description+". Protective SL remains authoritative.","OBRExecution");}
   double actual_risk=0.0;const double executed_volume=(result.executed_volume>0.0?result.executed_volume:request.volume);if(!g_position_sizer.CalculateActualRisk(candidate.symbol,candidate.direction,executed_volume,fill,submitted,actual_risk)){g_obr_planner.RecordRegistrationFailure();return;}g_position_sizer.RecordOriginalRiskCash(actual_risk);
   E2OBRPositionMetadata metadata;ZeroMemory(metadata);metadata.valid=true;metadata.position_id=position_id;metadata.order_ticket=result.order_ticket;metadata.entry_deal=result.deal_ticket;metadata.candidate_id=candidate.candidate_id;metadata.execution_id=request.execution_id;metadata.london_day=candidate.london_day;metadata.symbol=candidate.symbol;metadata.direction=candidate.direction;metadata.breakout_time=candidate.breakout_candle_time;metadata.entry_time=entry_time;metadata.or_high=candidate.or_high;metadata.or_low=candidate.or_low;metadata.frozen_atr=candidate.atr;metadata.frozen_adx=candidate.adx;metadata.fill_price=fill;metadata.structural_stop=context.structural_stop;metadata.submitted_stop=submitted;metadata.original_r_price=original_r;metadata.target_price=target;metadata.requested_risk_cash=context.requested_risk_cash;metadata.actual_risk_cash=actual_risk;metadata.volume=executed_volume;
   if(!g_obr_recovery.Save(metadata))g_obr_planner.RecordRegistrationFailure();E2ReportEntryData entry;E2MetadataToReport(metadata,entry);entry.or_start=candidate.or_start;entry.or_end=candidate.or_end;entry.or_known_from=candidate.or_known_from;entry.breakout_close=candidate.breakout_close;entry.or_size=candidate.or_size;entry.or_atr=candidate.or_size_atr_ratio;entry.breakout_gap=candidate.breakout_distance;entry.breakout_gap_atr=candidate.breakout_distance_atr_ratio;entry.intended_entry_time=context.intended_entry_time;entry.quote_time=context.request_time;entry.request_time=request.request_time;entry.requested_entry_price=request.requested_entry_price;entry.executable_quote=context.quote_price;if(!g_trade_reporter.CaptureEntry(entry))g_obr_planner.RecordRegistrationFailure();g_visualizer.DrawOBRExecution(metadata);
  }

void E2EmitVerification(void)
  {
   if(!g_configuration.core_verification_enabled)return;
   const int unknown_positions=g_trade_reporter.UnknownE2Positions(_Symbol);
   const E2OBRVerification obr=g_obr_engine.Verification();g_strategy_candidates=(int)obr.total_candidates;
   const E2OBRPlanVerification plan=g_obr_planner.PlanVerification();const E2OBRExecutionVerification execution=g_obr_planner.ExecutionVerification();const E2OBRRecoveryVerification recovery=g_obr_recovery.Verification();
   g_backtest_summary.CoreVerify(g_initialized,g_strategy_candidates,g_trade_requests,g_execution_attempts,g_execution_successes,g_trade_reporter.RegisteredCount(),g_trade_reporter.FinalizedCount(),g_trade_reporter.DuplicateExecutionIds()+(int)execution.duplicate_execution_attempts,g_trade_reporter.DuplicateFinalizedTrades(),g_trade_reporter.CausalityViolations()+(int)obr.causality_violations+(int)plan.plan_causality_violations,g_ownership_violations+(int)recovery.duplicate_day_entry_violations,unknown_positions);
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
   if(!g_obr_engine.Initialize(_Symbol,g_configuration,g_market_data,g_logger)){g_logger.Error("OBR indicator initialization failed.","Initialization");return(INIT_FAILED);}
   g_obr_recovery.Initialize(_Symbol,g_configuration,g_logger);g_obr_planner.Initialize(_Symbol,g_configuration,g_symbol_info,g_position_sizer,g_position_guard,g_obr_recovery,g_logger);g_obr_recovery.DayConsumed(g_obr_engine.SessionDayAtServerTime(TimeCurrent()));
   E2OBRPositionMetadata recovered;if(g_obr_recovery.Load(recovered)){E2ReportEntryData recovered_entry;E2MetadataToReport(recovered,recovered_entry);if(!g_trade_reporter.CaptureEntry(recovered_entry))g_obr_planner.RecordRegistrationFailure();g_position_sizer.RecordOriginalRiskCash(recovered.actual_risk_cash);g_visualizer.DrawOBRExecution(recovered);g_trade_reporter.Reconcile();g_obr_recovery.ClearIfNoOpenPosition();}else if(g_position_guard.HasOpenE2Position(_Symbol)){g_logger.Error("An owned position is open but no recovery metadata exists for the selected OBR session. Keep InpOBRSession unchanged for the full position lifecycle.","Initialization");return(INIT_FAILED);}
   g_initialized=true;
   const string risk_mode=(g_configuration.risk_mode==E2_RISK_FIXED_CASH?"FIXED_CASH":"BALANCE_PERCENT");const double risk_value=(g_configuration.risk_mode==E2_RISK_FIXED_CASH?g_configuration.fixed_cash_risk:g_configuration.balance_risk_percent);g_logger.Info("symbol="+_Symbol+", timeframe=M15, strategy=OBR, tradingEnabled="+IntegerToString((int)g_configuration.trading_enabled)+", riskMode="+risk_mode+", riskValue="+DoubleToString(risk_value,2)+", accountBalance="+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)+", accountEquity="+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2)+", magicNumber="+StringFormat("%I64u",g_configuration.expert_magic_number)+", "+E2SessionConfiguration()+", ADX="+IntegerToString(g_configuration.obr_adx_length)+"/"+DoubleToString(g_configuration.obr_minimum_adx,2)+", ATR="+IntegerToString(g_configuration.obr_atr_length)+", minimumRangeATR="+DoubleToString(g_configuration.obr_minimum_range_atr,2)+", maximumGapATR="+DoubleToString(g_configuration.obr_maximum_breakout_gap_atr,2)+", stopBufferATR="+DoubleToString(g_configuration.obr_stop_buffer_atr,2)+", targetR="+DoubleToString(g_configuration.obr_target_r,2)+", newsEnabled="+IntegerToString((int)g_configuration.news_filter_enabled)+", csvEnabled="+IntegerToString((int)g_configuration.csv_export_enabled)+".","E2_PRODUCTION_CONFIG");g_logger.Info(g_obr_engine.ProductionTimeDiagnostic(TimeCurrent())+".","E2_PRODUCTION_TIME");
   g_logger.Info("weekdayTrading="+E2WeekdayConfiguration()+".","E2_PRODUCTION_CONFIG");g_logger.Info("Initialized in "+g_environment.Name()+". Strategy layer=OBR_BASELINE; next-M15 execution and fixed broker SL/2R TP enabled.","Core");
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   E2OBRCandidate candidates[];
   if(!g_obr_engine.Evaluate(candidates))return;
   E2OBRSuppressedSignal suppressed[];g_obr_engine.CopySuppressedSignals(suppressed);for(int s=0;s<ArraySize(suppressed);s++)g_obr_planner.AuditWeekdaySuppression(suppressed[s]);
   const E2OBRVerification verification=g_obr_engine.Verification();g_strategy_candidates=(int)verification.total_candidates;
   g_visualizer.UpdateOBR(g_obr_engine.CurrentRange(),candidates);
   if(!g_or_recovery_recorded){E2OBROpeningRange range=g_obr_engine.CurrentRange();const int minute=g_obr_engine.SessionMinuteAtServerTime(TimeCurrent());const int session_end=(g_configuration.obr_session==E2_OBR_SESSION_NEW_YORK?630:540);if(range.complete){g_obr_recovery.RecordORRecovery(true);g_or_recovery_recorded=true;}else if(minute>=session_end){g_obr_recovery.RecordORRecovery(false);g_or_recovery_recorded=true;}}
   for(int i=0;i<ArraySize(candidates);i++)E2ExecuteOBRCandidate(candidates[i]);
   g_trade_reporter.Reconcile();g_obr_recovery.ClearIfNoOpenPosition();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD&&trans.deal>0)g_trade_reporter.OnDeal(trans.deal);
  }

void OnDeinit(const int reason)
  {
   g_trade_reporter.Reconcile();
   const E2OBRVerification obr_verify=g_obr_engine.Verification();const E2OBRTimeVerification time_verify=g_obr_engine.TimeVerification();const E2OBRPlanVerification plan_verify=g_obr_planner.PlanVerification();const E2OBRExecutionVerification exec_verify=g_obr_planner.ExecutionVerification();g_backtest_summary.OBRVerify(obr_verify);g_backtest_summary.OBRTimeVerify(time_verify);g_backtest_summary.OBRPlanVerify(plan_verify);g_backtest_summary.OBRExecVerify(exec_verify);g_backtest_summary.OBRRecoveryVerify(g_obr_recovery.Verification());g_backtest_summary.RiskVerify(g_position_sizer.Verification());
   E2OBRReconcileVerification reconcile=g_trade_reporter.ReconcileVerification(obr_verify.total_candidates,plan_verify.candidates_received,plan_verify.valid_execution_requests,exec_verify.execution_attempts,exec_verify.successful_entries,exec_verify.day_locks_created);reconcile.trade_csv_status=(g_configuration.csv_export_enabled?"CSV_ENABLED":"CSV_DISABLED");reconcile.trade_csv_row_mismatch=(g_configuration.csv_export_enabled&&reconcile.trade_csv_rows!=reconcile.finalized_trade_count?1:0);const E2OBRFinancialVerification financial=g_trade_reporter.FinancialVerification();g_backtest_summary.ReconcileVerify(reconcile);g_backtest_summary.FinancialVerify(financial);g_backtest_summary.RVerify(g_trade_reporter.RVerification());g_backtest_summary.DayVerify(g_trade_reporter.DayVerification(exec_verify.day_locks_created));g_backtest_summary.EntryTimeVerify(g_obr_planner.EntryTimeVerification());g_backtest_summary.EntryGapVerify(g_obr_planner.EntryGapVerification());g_logger.Info("candidates="+IntegerToString((int)obr_verify.total_candidates)+", longCandidates="+IntegerToString((int)obr_verify.long_candidates)+", shortCandidates="+IntegerToString((int)obr_verify.short_candidates)+", validRequests="+IntegerToString((int)plan_verify.valid_execution_requests)+", decisionCsvStatus="+(g_configuration.csv_export_enabled?"CSV_ENABLED":"CSV_DISABLED")+", decisionAuditRows="+IntegerToString((int)g_obr_planner.AuditRows())+", successfulEntries="+IntegerToString((int)exec_verify.successful_entries)+", finalizedTrades="+IntegerToString(g_trade_reporter.FinalizedCount())+", netR="+DoubleToString(financial.net_r,6)+".","OBR_RUN_FINGERPRINT");
   g_backtest_summary.OBRSessionVerify(g_obr_engine.SessionVerification());g_backtest_summary.OBRWeekdayVerify(g_obr_engine.WeekdayVerification());g_logger.Info(E2SessionConfiguration()+", weekdayTrading="+E2WeekdayConfiguration()+".","OBR_RUN_FINGERPRINT");E2EmitVerification();
   g_obr_engine.Shutdown();
   g_visualizer.Cleanup();
   g_trade_reporter.Close();
   g_obr_planner.CloseAudit();
   g_initialized=false;
  }
