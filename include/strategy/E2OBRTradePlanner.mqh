#ifndef E2_STRATEGY_E2OBRTRADEPLANNER_MQH
#define E2_STRATEGY_E2OBRTRADEPLANNER_MQH

#include "E2OBRTypes.mqh"
#include "E2OBRRecovery.mqh"
#include "..\\risk\\E2PositionSizer.mqh"
#include "..\\risk\\E2OrderRequest.mqh"
#include "..\\execution\\E2PositionGuard.mqh"
#include "..\\execution\\E2OrderExecutor.mqh"

class E2OBRTradePlanner
  {
private:
   E2Config m_config; string m_symbol,m_request_ids[],m_execution_ids[]; E2SymbolInfo *m_symbol_info; E2PositionSizer *m_sizer; E2PositionGuard *m_guard; E2OBRRecovery *m_recovery; E2Logger *m_logger;
   E2OBRPlanVerification m_plan; E2OBRExecutionVerification m_exec;
   bool Seen(const string &values[],const string id)const{for(int i=0;i<ArraySize(values);i++)if(values[i]==id)return(true);return(false);}
   void Remember(string &values[],const string id){int n=ArraySize(values);ArrayResize(values,n+1);values[n]=id;}
   double NormalizeDown(const double value,const E2SymbolSpecification &s)const{return(NormalizeDouble(MathFloor(value/s.tick_size+1e-10)*s.tick_size,s.digits));}
   double NormalizeUp(const double value,const E2SymbolSpecification &s)const{return(NormalizeDouble(MathCeil(value/s.tick_size-1e-10)*s.tick_size,s.digits));}
public:
   E2OBRTradePlanner(void):m_symbol(""),m_symbol_info(NULL),m_sizer(NULL),m_guard(NULL),m_recovery(NULL),m_logger(NULL){ZeroMemory(m_plan);ZeroMemory(m_exec);}
   void Initialize(const string symbol,const E2Config &config,E2SymbolInfo &symbol_info,E2PositionSizer &sizer,E2PositionGuard &guard,E2OBRRecovery &recovery,E2Logger &logger)
     {m_symbol=symbol;m_config=config;m_symbol_info=&symbol_info;m_sizer=&sizer;m_guard=&guard;m_recovery=&recovery;m_logger=&logger;ArrayResize(m_request_ids,0);ArrayResize(m_execution_ids,0);ZeroMemory(m_plan);ZeroMemory(m_exec);}
   bool Build(const E2OBRCandidate &candidate,E2OrderRequest &request,E2OBRPlanContext &context)
     {
      E2ResetOrderRequest(request);ZeroMemory(context);context.candidate=candidate;m_plan.candidates_received++;const datetime intended=candidate.candidate_known_from;context.intended_entry_time=intended;const datetime current_open=iTime(candidate.symbol,PERIOD_M15,0);const datetime now=TimeCurrent();
      if(current_open!=intended||now<intended||now>=intended+PeriodSeconds(PERIOD_M15)){m_plan.expired_candidates++;return(false);}m_plan.entry_windows_reached++;
      if(candidate.candidate_known_from<=candidate.breakout_candle_time||intended!=candidate.breakout_candle_time+PeriodSeconds(PERIOD_M15)){m_plan.plan_causality_violations++;return(false);}
      if(m_recovery!=NULL&&m_recovery.DayConsumed(candidate.london_day)){m_plan.rejected_day_consumed++;return(false);}
      request.execution_id=candidate.candidate_id+"_ENTRY";if(Seen(m_request_ids,request.execution_id)){m_plan.duplicate_requests++;return(false);}Remember(m_request_ids,request.execution_id);
      if(m_guard==NULL||m_guard.HasOpenE2Position(candidate.symbol)||m_guard.HasPendingE2Order(candidate.symbol)){m_plan.rejected_position_open++;return(false);}
      if(m_symbol_info==NULL||!m_symbol_info.Refresh(candidate.symbol)){m_plan.rejected_other++;return(false);}const E2SymbolSpecification spec=m_symbol_info.Specification();MqlTick tick;if(!SymbolInfoTick(candidate.symbol,tick)||tick.bid<=0.0||tick.ask<=0.0||tick.ask<tick.bid||tick.time<=0||(m_config.max_quote_age_seconds>0&&now-tick.time>m_config.max_quote_age_seconds)){m_plan.rejected_quote++;return(false);}
      const double entry=(candidate.direction==E2_DIRECTION_LONG?tick.ask:tick.bid);context.quote_price=entry;const double entry_gap=(candidate.direction==E2_DIRECTION_LONG?entry-candidate.or_high:candidate.or_low-entry);if(entry_gap>m_config.obr_maximum_breakout_gap_atr*candidate.atr){m_plan.rejected_entry_gap++;return(false);}
      const double structural=(candidate.direction==E2_DIRECTION_LONG?candidate.or_low-m_config.obr_stop_buffer_atr*candidate.atr:candidate.or_high+m_config.obr_stop_buffer_atr*candidate.atr);context.structural_stop=structural;if((candidate.direction==E2_DIRECTION_LONG&&structural>=entry)||(candidate.direction==E2_DIRECTION_SHORT&&structural<=entry)){m_plan.rejected_stop_geometry++;return(false);}
      const double minimum=MathMax((double)SymbolInfoInteger(candidate.symbol,SYMBOL_TRADE_STOPS_LEVEL),(double)SymbolInfoInteger(candidate.symbol,SYMBOL_TRADE_FREEZE_LEVEL))*spec.point;double submitted=structural;if(candidate.direction==E2_DIRECTION_LONG){if(minimum>0.0)submitted=MathMin(submitted,entry-minimum);submitted=NormalizeDown(submitted,spec);}else{if(minimum>0.0)submitted=MathMax(submitted,entry+minimum);submitted=NormalizeUp(submitted,spec);}context.submitted_stop=submitted;if(submitted<=0.0||(candidate.direction==E2_DIRECTION_LONG&&submitted>=entry)||(candidate.direction==E2_DIRECTION_SHORT&&submitted<=entry)){m_plan.rejected_stop_geometry++;return(false);}
      E2PositionSizingResult sizing;if(m_sizer==NULL||!m_sizer.CalculateRequestedRisk(candidate.symbol,candidate.direction,entry,submitted,sizing,true)){m_plan.rejected_sizing++;return(false);}context.requested_risk_cash=sizing.target_risk_money;context.planned_risk_cash=sizing.actual_risk_money;context.volume=sizing.volume;context.request_time=now;
      request.status=E2_ORDER_REQUEST_VALID;request.symbol=candidate.symbol;request.setup_id="OBR";request.signal_id=candidate.candidate_id;request.direction=candidate.direction;request.signal_time=candidate.breakout_candle_time;request.signal_known_from=candidate.candidate_known_from;request.request_time=now;request.requested_entry_price=entry;request.structural_stop_price=structural;request.submitted_stop_price=submitted;request.take_profit_price=0.0;request.requested_risk_cash=sizing.target_risk_money;request.volume=sizing.volume;
      m_plan.valid_execution_requests++;if(candidate.direction==E2_DIRECTION_LONG)m_plan.long_requests++;else m_plan.short_requests++;return(true);
     }
   bool BeginExecution(const E2OrderRequest &request)
     {m_exec.requests_received++;if(Seen(m_execution_ids,request.execution_id)){m_exec.duplicate_execution_attempts++;return(false);}Remember(m_execution_ids,request.execution_id);m_exec.execution_attempts++;if(request.direction==E2_DIRECTION_LONG)m_exec.long_attempts++;else m_exec.short_attempts++;return(true);}
   void RecordFailure(const E2ExecutionStatus status)
     {m_exec.execution_failures++;if(status==E2_EXECUTION_SPREAD_TOO_HIGH)m_plan.rejected_spread++;else if(status==E2_EXECUTION_NO_VALID_QUOTE||status==E2_EXECUTION_MARKET_PRICE_UNAVAILABLE||status==E2_EXECUTION_PRICE_DEVIATION_EXCEEDED)m_plan.rejected_quote++;else if(status==E2_EXECUTION_MARGIN_INSUFFICIENT||status==E2_EXECUTION_INSUFFICIENT_MARGIN)m_plan.rejected_margin++;else if(status==E2_EXECUTION_POSITION_ALREADY_OPEN||status==E2_EXECUTION_PENDING_ORDER_EXISTS||status==E2_EXECUTION_DIRECTION_CONFLICT)m_plan.rejected_position_open++;else m_plan.rejected_other++;}
   void RecordSuccess(const string day){m_exec.execution_successes++;m_exec.successful_entries++;m_exec.day_locks_created++;if(m_recovery!=NULL){m_recovery.RecordSuccessfulEntry(day);}}
   void RecordUnresolved(void){m_exec.unresolved_execution_states++;}void RecordRegistrationFailure(void){m_exec.registration_failures++;}void RecordProtectionFailure(void){m_exec.protection_failures++;}
   E2OBRPlanVerification PlanVerification(void)const{return(m_plan);}E2OBRExecutionVerification ExecutionVerification(void)const{return(m_exec);}
  };
#endif
