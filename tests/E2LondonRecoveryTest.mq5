// TEST ONLY: synthetic clock and injected candidates, never strategy performance evidence.
// Compile-time reuse of the production entry points and their actual global components.
#define OnInit ProductionOnInit
#define OnTick ProductionOnTick
#define OnDeinit ProductionOnDeinit
#include "..\\E2.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit

int checks=0,failures=0,opened=0,restarts=0,test_finalized=0;
bool range_a=false,range_b=false,attempted[4],finished[4];
datetime last_bar=0;
E2TradeReporter restarted_report;
int test_atr=INVALID_HANDLE;
int midnight_checks=0;
void Check(bool ok,string label)
{
   checks++;Print("[LRB_INTEGRATION_CHECK] ",label,"=",(ok?"PASS":"FAIL"));
   if(!ok)failures++;
}
bool ResetRecovery(E2PositionMetadata &m,bool &found)
{
   // Initialize is precisely the production OnInit recovery path. It zeros all
   // recovery/day state; its only authorities are the saved file and MT5 history.
   return g_position_recovery.Initialize(g_configuration,_Symbol,true,g_broker_time,g_logger,m,found);
}
void ResetRange(string scenario)
{
   E2Candidate ignored[];g_london_engine.Evaluate(ignored,g_position_recovery);
   string before=g_london_engine.RangeState();
   g_london_engine.Shutdown();
   Check(g_london_engine.Initialize(_Symbol,g_configuration,g_broker_time,g_weekend_flat,g_logger),scenario+"_history_rebuild");
   Check(before==g_london_engine.RangeState(),scenario+"_identical_range_state");
   Print("[LRB_RANGE_RESTART] scenario=",scenario,", before=",before,", after=",g_london_engine.RangeState());
   E2Candidate out[];
   Check(!g_london_engine.Evaluate(out,g_position_recovery)&&ArraySize(out)==0,scenario+"_no_replayed_signal");
   restarts++;
}
E2Candidate Candidate(E2TradeDirection direction,string id)
{
   E2Candidate c;ZeroMemory(c);MqlTick tick;SymbolInfoTick(_Symbol,tick);
   c.symbol=_Symbol;c.timeframe="M5";c.direction=direction;c.candidate_id="SYNTHETIC_ONLY|"+id;
   c.signal_bar_time=iTime(_Symbol,PERIOD_M5,1);c.signal_known_time=c.signal_bar_time+300;
   c.execution_window_start=c.signal_known_time;c.execution_window_end=c.signal_known_time+300;
   datetime local;g_broker_time.London(c.signal_bar_time,local);c.london_day=E2CalendarDay(local);
   c.range_start_london=E2LocalMidnight(local);c.range_end_london=c.range_start_london+8*3600;
   // Wide artificial range protects the controlled position until recovery/close.
   c.range_low=NormalizeDouble(tick.bid-0.02000,_Digits);c.range_high=NormalizeDouble(tick.ask+0.02000,_Digits);
   c.risk_distance=c.range_high-c.range_low;c.signal_close=(direction==E2_DIRECTION_LONG?c.range_high+0.0001:c.range_low-0.0001);
   c.breakout_distance=0.0001;
   return c;
}
void OpenAndRecover(E2TradeDirection direction,string id)
{
   E2Candidate c=Candidate(direction,id);E2OrderRequest request;E2PlanningAudit audit;
   g_trade_reporter.BeginCandidate(c);
   bool planned=g_london_planner.Build(c,request,audit);g_trade_reporter.RecordPlanning(c.candidate_id,audit);
   Check(planned,id+"_production_plan");if(!planned)return;
   Check(audit.raw_sl==(direction==E2_DIRECTION_LONG?c.range_low:c.range_high),id+"_opposite_range_SL");
   Check(request.request_time>=c.signal_known_time&&request.request_time>c.signal_bar_time,id+"_next_bar_request");
   MqlTick quote;SymbolInfoTick(_Symbol,quote);
   Check(request.requested_entry_price==(direction==E2_DIRECTION_LONG?quote.ask:quote.bid),id+"_Ask_Bid_entry");
   E2Config sizing_config=g_configuration;E2PositionSizer sizing;E2PositionSizingResult sizing_result;
   sizing_config.fixed_cash_risk=0.000001;sizing.Initialize(sizing_config,g_symbol_info,g_account_info,g_logger);
   Check(!sizing.CalculateRequestedRisk(_Symbol,direction,request.requested_entry_price,request.submitted_stop_price,sizing_result)&&sizing_result.status==E2_SIZING_VOLUME_BELOW_MINIMUM,id+"_below_min_volume_rejected");
   sizing_config.fixed_cash_risk=1e12;sizing.Initialize(sizing_config,g_symbol_info,g_account_info,g_logger);
   Check(!sizing.CalculateRequestedRisk(_Symbol,direction,request.requested_entry_price,request.submitted_stop_price,sizing_result)&&sizing_result.status==E2_SIZING_VOLUME_ABOVE_MAXIMUM,id+"_above_max_volume_rejected");
   E2ExecutionSafety safety;E2ExecutionSafetyResult safety_result;
   E2Config safety_config=g_configuration;safety_config.max_spread_pips=0.000001;safety.Initialize(safety_config,g_logger);
   Check(!safety.CanExecute(request,g_symbol_info.Specification(),safety_result)&&safety_result.status==E2_SAFETY_SPREAD_TOO_HIGH,id+"_spread_rejection");
   safety_config=g_configuration;safety_config.trading_enabled=false;safety.Initialize(safety_config,g_logger);
   Check(!safety.CanExecute(request,g_symbol_info.Specification(),safety_result)&&safety_result.status==E2_SAFETY_TRADING_DISABLED,id+"_disabled_entry_rejection");
   E2Candidate expired=c;expired.candidate_id+="_EXPIRED";expired.execution_window_end=TimeCurrent();
   E2OrderRequest rejected;E2PlanningAudit rejected_audit;
   Check(!g_london_planner.Build(expired,rejected,rejected_audit)&&rejected_audit.reason=="EXECUTION_WINDOW_EXPIRED",id+"_stale_signal_rejected");
   expired=c;expired.candidate_id+="_FUTURE";expired.execution_window_start=TimeCurrent()+300;
   Check(!g_london_planner.Build(expired,rejected,rejected_audit)&&rejected_audit.reason=="EXECUTION_WINDOW_EXPIRED",id+"_intrabar_early_request_rejected");
   E2LondonTradePlanner mode_planner;E2Config mode_config=g_configuration;mode_config.stop_mode=ATR;
   mode_planner.Initialize(mode_config,g_symbol_info,g_position_sizer,g_position_guard,g_position_recovery,g_weekend_flat,g_broker_time,g_logger);
   double atr_value[];int shift=iBarShift(_Symbol,PERIOD_M5,c.signal_bar_time,true);
   bool atr_ready=(shift>=1&&CopyBuffer(test_atr,0,shift,1,atr_value)==1);
   Check(atr_ready&&mode_config.atr_length==14&&mode_config.atr_multiplier==1.0,id+"_ATR_closed_bar_available");
   if(atr_ready)
   {
      E2Candidate atr_candidate=c;atr_candidate.candidate_id+="_ATR_IMPLEMENTATION_ONLY";atr_candidate.risk_distance=atr_value[0]*mode_config.atr_multiplier;
      Check(mode_planner.Build(atr_candidate,rejected,rejected_audit)&&MathAbs(rejected_audit.raw_sl-(request.requested_entry_price+(direction==E2_DIRECTION_LONG?-1:1)*atr_candidate.risk_distance))<1e-12,id+"_ATR_planner_geometry_no_order");
   }
   E2Candidate near_stop=c;near_stop.candidate_id+="_STOP_LEVEL_TEST";
   near_stop.range_low=quote.ask-_Point;near_stop.range_high=quote.bid+_Point;
   mode_config=g_configuration;mode_planner.Initialize(mode_config,g_symbol_info,g_position_sizer,g_position_guard,g_position_recovery,g_weekend_flat,g_broker_time,g_logger);
   bool adjusted=mode_planner.Build(near_stop,rejected,rejected_audit);
   double minimum=MathMax((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
   Check(adjusted&&(direction==E2_DIRECTION_LONG?rejected.submitted_stop_price<=quote.bid-minimum:rejected.submitted_stop_price>=quote.ask+minimum),id+"_stop_level_adjustment_no_order");
   E2ExecutionResult result;
   bool sent=g_order_executor.Execute(request,"E2_SYNTHETIC_TEST",result);
   Check(sent,id+"_production_execution");if(!sent)return;
   Check(HistoryDealSelect(result.deal_ticket),id+"_authoritative_fill");
   E2PositionMetadata m;ZeroMemory(m);m.candidate_id=c.candidate_id;m.execution_id=request.execution_id;
   m.symbol=_Symbol;m.direction=direction;m.signal_time=c.signal_bar_time;
   m.entry_deal=result.deal_ticket;m.entry_time=(datetime)HistoryDealGetInteger(m.entry_deal,DEAL_TIME);
   m.position_id=(ulong)HistoryDealGetInteger(m.entry_deal,DEAL_POSITION_ID);
   ulong position_id;g_position_guard.FindOpenE2Position(_Symbol,m.position_ticket,position_id);
   m.fill_price=HistoryDealGetDouble(m.entry_deal,DEAL_PRICE);m.volume=HistoryDealGetDouble(m.entry_deal,DEAL_VOLUME);
   m.submitted_stop=request.submitted_stop_price;m.original_r=MathAbs(m.fill_price-m.submitted_stop);m.target_r=g_configuration.target_r;
   m.target_price=g_symbol_info.NormalizePrice(m.fill_price+(direction==E2_DIRECTION_LONG?1:-1)*m.original_r*m.target_r);
   m.requested_risk_cash=request.requested_risk_cash;
   Check(g_position_sizer.CalculateActualRisk(_Symbol,direction,m.volume,m.fill_price,m.submitted_stop,m.actual_risk_cash),id+"_actual_cash_risk");
   m.london_day=c.london_day;m.range_start_london=c.range_start_london;m.range_end_london=c.range_end_london;
   m.range_high=c.range_high;m.range_low=c.range_low;m.signal_close=c.signal_close;m.breakout_distance=c.breakout_distance;m.time_policy_digest=g_broker_time.Digest();
   Check(g_position_recovery.Save(m),id+"_production_persist");
   Check(g_trade_reporter.Register(m),id+"_register");g_position_recovery.RecordLock();
   uint rc;string description;
   Check(g_order_executor.AttachProtection(_Symbol,m.position_id,m.submitted_stop,m.target_price,rc,description),id+"_production_protection");
   g_trade_reporter.RecordExecuted(c.candidate_id,result,m);opened++;
   Print("[LRB_TIMING_TEST] synthetic=1, signal_bar_time=",TimeToString(c.signal_bar_time,TIME_DATE|TIME_SECONDS),", signal_known_time=",TimeToString(c.signal_known_time,TIME_DATE|TIME_SECONDS),", planning_time=",TimeToString(audit.planning_time,TIME_DATE|TIME_SECONDS),", request_time=",TimeToString(request.request_time,TIME_DATE|TIME_SECONDS),", fill_time=",TimeToString(m.entry_time,TIME_DATE|TIME_SECONDS));
   Check(m.entry_time>=c.signal_known_time,id+"_causal_fill");
   Check(g_position_recovery.DayConsumed(TimeCurrent()),id+"_lock_before_reset");
   // Assertions retain a copy ONLY in the harness. Production Initialize cannot read it.
   E2PositionMetadata recovered;bool found=false;
   Check(ResetRecovery(recovered,found)&&found,id+"_open_recovered");restarts++;
   // Production persistence uses 16 decimal places. Compare R at that precision,
   // not bitwise IEEE identity after a decimal text round-trip.
   Check(MathAbs(recovered.original_r-m.original_r)<1e-15&&recovered.submitted_stop==m.submitted_stop&&recovered.target_price==m.target_price,id+"_immutable_protection_metadata");
   Print("[LRB_R_ROUNDTRIP] before=",DoubleToString(m.original_r,16),", after=",DoubleToString(recovered.original_r,16),", absoluteDelta=",StringFormat("%.18g",MathAbs(recovered.original_r-m.original_r)));
   E2Config report_config=g_configuration;report_config.csv_export_enabled=false;
   restarted_report.Initialize(report_config,_Symbol,g_logger);Check(restarted_report.Register(recovered,true),id+"_fresh_reporter_recovered_registration");
   Check(recovered.candidate_id==m.candidate_id&&recovered.position_ticket==m.position_ticket&&recovered.direction==m.direction&&recovered.volume==m.volume&&recovered.fill_price==m.fill_price&&recovered.time_policy_digest==m.time_policy_digest,id+"_identity_fill_volume");
   PositionSelectByTicket(m.position_ticket);
   Check(PositionGetDouble(POSITION_SL)==m.submitted_stop&&PositionGetDouble(POSITION_TP)==m.target_price,id+"_live_protection_unchanged");
   Check(g_position_guard.CountOpenE2Positions(_Symbol)==1,id+"_no_duplicate_position");
   Check(g_position_recovery.ReconstructDayLock(0,0),id+"_history_lock_after_reset");
   E2DayVerification day=g_position_recovery.DayVerification();
   Check(day.today_owned_entry_deals_found>=1&&day.daily_lock_recovered==1&&day.daily_lock_failure_reason=="NONE",id+"_current_second_entry_in_history");
   g_london_planner.Initialize(g_configuration,g_symbol_info,g_position_sizer,g_position_guard,g_position_recovery,g_weekend_flat,g_broker_time,g_logger);
   c.candidate_id+="_LATER";Check(!g_london_planner.Build(c,request,audit)&&audit.reason=="DAY_CONSUMED",id+"_later_candidate_suppressed");
   E2Config foreign=g_configuration;foreign.expert_magic_number++;
   E2PositionGuard foreign_guard;foreign_guard.Initialize(foreign,g_logger);
   Check(!foreign_guard.HasOpenE2Position(_Symbol),id+"_foreign_magic_not_owned");
   E2OrderExecutor foreign_executor;E2PositionCloseResult forbidden;
   foreign_executor.Initialize(foreign,g_symbol_info,g_account_info,foreign_guard,g_execution_safety,g_weekend_flat,g_broker_time,g_logger);
   Check(!foreign_executor.CloseOwnedPosition(_Symbol,m.position_ticket,m.position_id,forbidden)&&PositionSelectByTicket(m.position_ticket),id+"_foreign_magic_cannot_close");
   E2PositionGuardResult guard_result;
   request.symbol=_Symbol;request.direction=direction;Check(!g_position_guard.CanOpen(request,guard_result),id+"_owned_position_guard");
   ResetRange(id+"_E");
}
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   Print("[LRB_INTEGRATION] SYNTHETIC CLOCK / INJECTED CANDIDATES; NOT A HISTORICAL STRATEGY BASELINE");
   E2LoadConfiguration(g_configuration);g_configuration.expert_magic_number=9900202;g_configuration.fixed_cash_risk=100;
   g_configuration.csv_export_enabled=true;g_logger.Initialize(true,false);
   if(!g_broker_time.Initialize("E2\\Tests\\LondonSprint1\\fixed.profile","E2_TEST_ONLY",true,g_logger))return INIT_FAILED;
   g_configuration.time_policy_digest=g_broker_time.Digest();
   if(!g_symbol_info.Initialize(_Symbol,g_logger)||!g_account_info.Initialize(g_logger))return INIT_FAILED;
   g_position_sizer.Initialize(g_configuration,g_symbol_info,g_account_info,g_logger);
   g_position_guard.Initialize(g_configuration,g_logger);g_execution_safety.Initialize(g_configuration,g_logger);
   g_weekend_flat.Initialize(g_configuration,_Symbol,g_logger);
   g_order_executor.Initialize(g_configuration,g_symbol_info,g_account_info,g_position_guard,g_execution_safety,g_weekend_flat,g_broker_time,g_logger);
   g_trade_reporter.Initialize(g_configuration,_Symbol,g_logger);
   E2PositionMetadata m;bool found;if(!ResetRecovery(m,found)||found)return INIT_FAILED;
   g_london_planner.Initialize(g_configuration,g_symbol_info,g_position_sizer,g_position_guard,g_position_recovery,g_weekend_flat,g_broker_time,g_logger);
   if(!g_london_engine.Initialize(_Symbol,g_configuration,g_broker_time,g_weekend_flat,g_logger))return INIT_FAILED;
   test_atr=iATR(_Symbol,PERIOD_M5,14);if(test_atr==INVALID_HANDLE)return INIT_FAILED;
   return INIT_SUCCEEDED;
}
void OnTick()
{
   datetime now=TimeCurrent(),bar=iTime(_Symbol,PERIOD_M5,0);if(bar==last_bar)return;last_bar=bar;
   MqlDateTime dt;TimeToStruct(now,dt);
   if(dt.day>=3&&dt.day<=5&&dt.hour==0&&dt.min==5)
   {
      // Separate synthetic +02 broker clock: yesterday's actual entry is still
      // today in London after server midnight. No future history is selected.
      E2BrokerTimeAdapter shifted_time;E2PositionRecovery shifted_recovery;E2PositionMetadata m;bool found;
      Check(shifted_time.Initialize("E2\\Tests\\LondonSprint1\\transitions.profile","E2_TEST_ONLY",true,g_logger),"midnight_shifted_profile");
      Check(shifted_recovery.Initialize(g_configuration,_Symbol,true,shifted_time,g_logger,m,found)&&!found,"midnight_history_only_restart");
      Check(shifted_recovery.DayConsumed(now)&&!g_position_recovery.DayConsumed(now),"actual_deal_lock_uses_London_not_server_date");midnight_checks++;
   }
   if(!range_a&&dt.hour==2){range_a=true;ResetRange("A_DURING_RANGE");}
   if(!range_b&&dt.hour==8&&dt.min==0){range_b=true;ResetRange("B_AFTER_RANGE");}
   int index=dt.day-2;
   if(index>=0&&index<4&&dt.hour==8&&dt.min==5&&!attempted[index])
   {attempted[index]=true;ResetRange("C_BEFORE_REQUEST");OpenAndRecover(index%2==0?E2_DIRECTION_LONG:E2_DIRECTION_SHORT,IntegerToString(index));}
   if(index>=0&&index<4&&opened>0&&!finished[index]&&((dt.day_of_week!=5&&dt.hour==9)||g_weekend_flat.IsBlockedAt(now)))
   {
      finished[index]=true;ulong ticket,id;
      if(g_position_guard.FindOpenE2Position(_Symbol,ticket,id))
      {
         if(dt.day_of_week==5)
         {
            g_weekend_flat.Initialize(g_configuration,_Symbol,g_logger);E2PositionMetadata m;bool found;
            Check(ResetRecovery(m,found)&&found,"F_CUTOFF_OPEN_RECOVERED");restarts++;
            Check(g_weekend_flat.IsBlockedAt(now),"F_CUTOFF_RECONSTRUCTED");E2EnforceWeekendFlat();
            E2Candidate blocked=Candidate(E2_DIRECTION_LONG,"WEEKEND_REJECT");E2OrderRequest rejected;E2PlanningAudit audit;
            Check(!g_london_planner.Build(blocked,rejected,audit)&&audit.reason=="WEEKEND_CUTOFF","F_WEEKEND_ENTRY_REJECTED");
         }
         else{E2PositionCloseResult result;Check(g_order_executor.CloseOwnedPosition(_Symbol,ticket,id,result),"controlled_test_close");}
         g_trade_reporter.Reconcile();Check(g_trade_reporter.IsFinalizedPosition(id),"recovered_trade_finalized");
         restarted_report.Reconcile();restarted_report.Verify(0,0,0,0,0);
         E2ReconcileVerification rr=restarted_report.ReconcileVerification();
         Check(rr.reconciliation_violations==0,"fresh_recovered_reporter_reconciliation");
         g_position_recovery.Reconcile(g_trade_reporter.IsFinalizedPosition(id));test_finalized++;
         E2PositionMetadata m;bool found;Check(ResetRecovery(m,found)&&!found,"D_CLOSED_POSITION_RESTART");
         Check(g_position_recovery.DayConsumed(now),"D_CLOSED_TRADE_HISTORY_LOCK");restarts++;
      }
   }
}
void OnDeinit(const int reason)
{
   g_trade_reporter.Close();g_london_engine.Shutdown();
   if(test_atr!=INVALID_HANDLE)IndicatorRelease(test_atr);
   Check(range_a&&range_b&&opened==4&&test_finalized==4&&midnight_checks==3,"all_scenarios_exercised");
   g_position_recovery.AuditDayEntries();E2DayVerification day=g_position_recovery.DayVerification();
   Check(day.max_entries_per_symbol_day==1&&day.duplicate_day_entry_violations==0&&day.day_mapping_violations==0,"one_entry_per_London_day_audit");
   E2ReconcileVerification r=g_trade_reporter.ReconcileVerification();
   Check(r.reconciliation_violations==0,"reporter_reconciliation");
   Print("[LRB_INTEGRATION_VERIFY] synthetic=1, checks=",checks,", failures=",failures,", simulatedRestarts=",restarts,", positionsOpened=",opened,", recoveredTradesFinalized=",test_finalized,", authoritativeBaseline=0");
}
double OnTester(){return (double)failures;}
