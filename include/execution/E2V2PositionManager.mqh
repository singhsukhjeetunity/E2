#ifndef E2_EXECUTION_E2V2POSITIONMANAGER_MQH
#define E2_EXECUTION_E2V2POSITIONMANAGER_MQH

#include <Trade\Trade.mqh>
#include "..\strategy\E2V2TradePlanEngine.mqh"

struct E2V2ManagementDiagnostics
  {int fixed_2r_positions_observed,trailing_positions_managed,positions_managed;ulong management_checks;int milestone_2_reached,higher_milestones_reached,sl_modify_attempts,sl_modify_success,sl_modify_failures,broker_constraint_deferrals,duplicate_modify_suppressed,stop_regression_violations,invalid_original_r,recovered_positions;};
struct E2RMRManagementDiagnostics
  {int positions_managed;ulong management_checks;int milestone_2_reached,higher_milestones_reached,sl_modify_attempts,sl_modify_success,sl_modify_failures,broker_constraint_deferrals,stop_regression_violations,invalid_original_r,recovered_positions;};
struct E2V2ManagedState
  {ulong position_id,ticket;string symbol;E2TradeDirection direction;E2StrategyType strategy_type;double entry,original_sl,original_r;E2V2ManagementBranch branch;int maximum_milestone;bool counted;};

class E2V2PositionManager
  {
private:
   ulong m_magic;datetime m_initialized_at;E2Logger *m_logger;CTrade m_trade;E2V2ManagedState m_states[];E2V2ManagementDiagnostics m_diagnostics;E2RMRManagementDiagnostics m_rmr_diagnostics;
   string Key(const ulong position_id,const string field)const{return("E2V2M."+StringFormat("%I64u",m_magic)+"."+StringFormat("%I64u",position_id)+"."+field);}
   bool Has(const ulong position_id,const string field)const{return(GlobalVariableCheck(Key(position_id,field)));}
   double Get(const ulong position_id,const string field)const{return(GlobalVariableGet(Key(position_id,field)));}
   void Set(const ulong position_id,const string field,const double value)const{GlobalVariableSet(Key(position_id,field),value);}
   void DeleteState(const ulong position_id)const{GlobalVariableDel(Key(position_id,"ENTRY"));GlobalVariableDel(Key(position_id,"ORIGSL"));GlobalVariableDel(Key(position_id,"R"));GlobalVariableDel(Key(position_id,"BRANCH"));GlobalVariableDel(Key(position_id,"MILESTONE"));GlobalVariableDel(Key(position_id,"SETUP"));}
   int Find(const ulong position_id)const{for(int i=0;i<ArraySize(m_states);i++)if(m_states[i].position_id==position_id)return(i);return(-1);}
   bool OwnedPositionSelected()const
     {if((ulong)PositionGetInteger(POSITION_MAGIC)!=m_magic)return(false);const string comment=PositionGetString(POSITION_COMMENT);return(StringFind(comment,"E2V2",0)==0);}
   double FloorPrice(const double value,const E2SymbolSpecification &spec)const{return(NormalizeDouble(MathFloor(value/spec.tick_size+1e-10)*spec.tick_size,spec.digits));}
   double CeilPrice(const double value,const E2SymbolSpecification &spec)const{return(NormalizeDouble(MathCeil(value/spec.tick_size-1e-10)*spec.tick_size,spec.digits));}
   bool LoadSelected(E2V2ManagedState &state,bool &recovered)
     {
      recovered=false;state.position_id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);state.ticket=(ulong)PositionGetInteger(POSITION_TICKET);state.symbol=PositionGetString(POSITION_SYMBOL);state.direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?E2_DIRECTION_BUY:E2_DIRECTION_SELL);const double open=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL);const string comment=PositionGetString(POSITION_COMMENT);
      if(state.position_id==0||open<=0.0)return(false);const bool persisted=Has(state.position_id,"ENTRY")&&Has(state.position_id,"ORIGSL")&&Has(state.position_id,"R")&&Has(state.position_id,"BRANCH")&&Has(state.position_id,"MILESTONE");
      if(persisted){state.entry=Get(state.position_id,"ENTRY");state.original_sl=Get(state.position_id,"ORIGSL");state.original_r=Get(state.position_id,"R");state.branch=(E2V2ManagementBranch)(int)Get(state.position_id,"BRANCH");state.maximum_milestone=(int)Get(state.position_id,"MILESTONE");state.strategy_type=(Has(state.position_id,"SETUP")?(E2StrategyType)(int)Get(state.position_id,"SETUP"):E2_STRATEGY_TREND_CONTINUATION);recovered=((datetime)PositionGetInteger(POSITION_TIME)<m_initialized_at);}
      else
        {const bool marked_fixed=(StringFind(comment,"E2V2F|",0)==0),marked_trailing=(StringFind(comment,"E2V2Z|",0)==0);if((!marked_fixed&&!marked_trailing)||sl<=0.0||(state.direction==E2_DIRECTION_BUY&&sl>=open)||(state.direction==E2_DIRECTION_SELL&&sl<=open))return(false);state.entry=open;state.original_sl=sl;state.original_r=MathAbs(open-sl);state.branch=(marked_trailing?E2_V2_MANAGEMENT_ZONE_TARGET_TRAILING:E2_V2_MANAGEMENT_FIXED_2R);state.strategy_type=E2_STRATEGY_TREND_CONTINUATION;state.maximum_milestone=1;Set(state.position_id,"ENTRY",state.entry);Set(state.position_id,"ORIGSL",state.original_sl);Set(state.position_id,"R",state.original_r);Set(state.position_id,"BRANCH",(double)state.branch);Set(state.position_id,"MILESTONE",1.0);Set(state.position_id,"SETUP",(double)state.strategy_type);recovered=true;}
      if(state.original_r<=0.0||state.entry<=0.0||(state.direction==E2_DIRECTION_BUY&&state.original_sl>=state.entry)||(state.direction==E2_DIRECTION_SELL&&state.original_sl<=state.entry))return(false);if(state.maximum_milestone<1)state.maximum_milestone=1;return(true);
     }
   void ObserveSelected()
     {
      if(!OwnedPositionSelected())return;const ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);int at=Find(id);if(at<0){E2V2ManagedState state;ZeroMemory(state);bool recovered=false;if(!LoadSelected(state,recovered)){m_diagnostics.invalid_original_r++;if(state.strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.invalid_original_r++;return;}at=ArraySize(m_states);ArrayResize(m_states,at+1);m_states[at]=state;if(recovered){m_diagnostics.recovered_positions++;if(state.strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.recovered_positions++;}}
      m_states[at].ticket=(ulong)PositionGetInteger(POSITION_TICKET);if(!m_states[at].counted){m_states[at].counted=true;m_diagnostics.positions_managed++;if(m_states[at].strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.positions_managed++;if(m_states[at].branch==E2_V2_MANAGEMENT_FIXED_2R)m_diagnostics.fixed_2r_positions_observed++;else if(m_states[at].branch==E2_V2_MANAGEMENT_ZONE_TARGET_TRAILING)m_diagnostics.trailing_positions_managed++;}
      if(m_states[at].branch!=E2_V2_MANAGEMENT_ZONE_TARGET_TRAILING)return;ManageSelected(m_states[at]);
     }
   void ManageSelected(E2V2ManagedState &state)
     {
      m_diagnostics.management_checks++;if(state.strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.management_checks++;MqlTick tick;if(!SymbolInfoTick(state.symbol,tick)||tick.bid<=0.0||tick.ask<tick.bid)return;const double favorable=(state.direction==E2_DIRECTION_BUY?tick.bid-state.entry:state.entry-tick.ask)/state.original_r;const int observed=(int)MathFloor(favorable+1e-10);
      if(observed>state.maximum_milestone){if(state.maximum_milestone<2&&observed>=2){m_diagnostics.milestone_2_reached++;if(state.strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.milestone_2_reached++;}const int higher_start=MathMax(state.maximum_milestone+1,3);if(observed>=higher_start){m_diagnostics.higher_milestones_reached+=observed-higher_start+1;if(state.strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.higher_milestones_reached+=observed-higher_start+1;}state.maximum_milestone=observed;Set(state.position_id,"MILESTONE",(double)observed);}if(state.maximum_milestone<2)return;
      E2SymbolSpecification spec;spec.symbol=state.symbol;spec.digits=(int)SymbolInfoInteger(state.symbol,SYMBOL_DIGITS);spec.point=SymbolInfoDouble(state.symbol,SYMBOL_POINT);spec.tick_size=SymbolInfoDouble(state.symbol,SYMBOL_TRADE_TICK_SIZE);if(spec.point<=0.0||spec.tick_size<=0.0){m_diagnostics.broker_constraint_deferrals++;if(state.strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.broker_constraint_deferrals++;return;}const int locked_r=state.maximum_milestone-1;const double theoretical=(state.direction==E2_DIRECTION_BUY?state.entry+locked_r*state.original_r:state.entry-locked_r*state.original_r);const double desired=(state.direction==E2_DIRECTION_BUY?FloorPrice(theoretical,spec):CeilPrice(theoretical,spec));const double existing=PositionGetDouble(POSITION_SL);
      if((state.direction==E2_DIRECTION_BUY&&desired<=existing+spec.tick_size*0.1)||(state.direction==E2_DIRECTION_SELL&&desired>=existing-spec.tick_size*0.1)){const double existing_locked=(state.direction==E2_DIRECTION_BUY?existing-state.entry:state.entry-existing)/state.original_r;if(existing_locked>locked_r+0.25){m_diagnostics.stop_regression_violations++;if(state.strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.stop_regression_violations++;}else m_diagnostics.duplicate_modify_suppressed++;return;}
      const double market=(state.direction==E2_DIRECTION_BUY?tick.bid:tick.ask);const double minimum=MathMax((double)SymbolInfoInteger(state.symbol,SYMBOL_TRADE_STOPS_LEVEL),(double)SymbolInfoInteger(state.symbol,SYMBOL_TRADE_FREEZE_LEVEL))*spec.point;if((state.direction==E2_DIRECTION_BUY&&desired>market-minimum+1e-12)||(state.direction==E2_DIRECTION_SELL&&desired<market+minimum-1e-12)){m_diagnostics.broker_constraint_deferrals++;if(state.strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.broker_constraint_deferrals++;return;}
      const double tp=PositionGetDouble(POSITION_TP);m_diagnostics.sl_modify_attempts++;if(state.strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.sl_modify_attempts++;m_trade.SetExpertMagicNumber(m_magic);const bool modified=m_trade.PositionModify(state.ticket,desired,tp);const uint retcode=m_trade.ResultRetcode();if(!modified||(retcode!=TRADE_RETCODE_DONE&&retcode!=TRADE_RETCODE_NO_CHANGES)){m_diagnostics.sl_modify_failures++;if(state.strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.sl_modify_failures++;return;}if(retcode==TRADE_RETCODE_NO_CHANGES){m_diagnostics.duplicate_modify_suppressed++;return;}m_diagnostics.sl_modify_success++;if(state.strategy_type==E2_STRATEGY_RANGE_MEAN_REVERSION)m_rmr_diagnostics.sl_modify_success++;if(m_logger!=NULL)m_logger.Info("ticket="+StringFormat("%I64u",state.ticket)+", setup="+E2StrategyTypeName(state.strategy_type)+", direction="+(state.direction==E2_DIRECTION_BUY?"LONG":"SHORT")+", entry="+DoubleToString(state.entry,spec.digits)+", originalSL="+DoubleToString(state.original_sl,spec.digits)+", R="+DoubleToString(state.original_r,spec.digits)+", milestone="+IntegerToString(state.maximum_milestone)+", lockedR="+IntegerToString(locked_r)+", desiredSL="+DoubleToString(theoretical,spec.digits)+", appliedSL="+DoubleToString(desired,spec.digits)+".","TCV2_MANAGE");
     }
   bool Live(const ulong position_id)const{for(int i=0;i<PositionsTotal();i++){const ulong ticket=PositionGetTicket(i);if(ticket>0&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==position_id)return(true);}return(false);}
   void CleanupOrphanedGlobals(){const string prefix="E2V2M."+StringFormat("%I64u",m_magic)+".";for(int i=GlobalVariablesTotal()-1;i>=0;i--){const string name=GlobalVariableName(i);if(StringFind(name,prefix,0)!=0||StringFind(name,".ENTRY",StringLen(prefix))<0)continue;const int end=StringFind(name,".",StringLen(prefix));if(end<0)continue;const ulong id=(ulong)StringToInteger(StringSubstr(name,StringLen(prefix),end-StringLen(prefix)));if(id>0&&!Live(id))DeleteState(id);}}
   void CleanupClosed(){for(int i=ArraySize(m_states)-1;i>=0;i--)if(!Live(m_states[i].position_id)){DeleteState(m_states[i].position_id);for(int j=i+1;j<ArraySize(m_states);j++)m_states[j-1]=m_states[j];ArrayResize(m_states,ArraySize(m_states)-1);}}
public:
   E2V2PositionManager(void):m_magic(0),m_initialized_at(0),m_logger(NULL){ZeroMemory(m_diagnostics);ZeroMemory(m_rmr_diagnostics);}
   void Initialize(const E2Config &config,E2Logger &logger){m_magic=config.expert_magic_number;m_initialized_at=TimeCurrent();m_logger=&logger;m_trade.SetAsyncMode(false);m_trade.SetExpertMagicNumber(m_magic);ArrayResize(m_states,0);ZeroMemory(m_diagnostics);ZeroMemory(m_rmr_diagnostics);CleanupOrphanedGlobals();Check();}
   void Check(){for(int i=0;i<PositionsTotal();i++){const ulong ticket=PositionGetTicket(i);if(ticket>0)ObserveSelected();}CleanupClosed();}
   E2V2ManagementDiagnostics Diagnostics()const{return(m_diagnostics);}
   // The manager remains shared; this view isolates TC diagnostics from the
   // separately accumulated RMR bucket without duplicating management logic.
   E2V2ManagementDiagnostics TCDiagnostics()const
     {
      E2V2ManagementDiagnostics value=m_diagnostics;
      value.positions_managed-=m_rmr_diagnostics.positions_managed;
      value.trailing_positions_managed-=m_rmr_diagnostics.positions_managed;
      value.management_checks-=m_rmr_diagnostics.management_checks;
      value.milestone_2_reached-=m_rmr_diagnostics.milestone_2_reached;
      value.higher_milestones_reached-=m_rmr_diagnostics.higher_milestones_reached;
      value.sl_modify_attempts-=m_rmr_diagnostics.sl_modify_attempts;
      value.sl_modify_success-=m_rmr_diagnostics.sl_modify_success;
      value.sl_modify_failures-=m_rmr_diagnostics.sl_modify_failures;
      value.broker_constraint_deferrals-=m_rmr_diagnostics.broker_constraint_deferrals;
      value.stop_regression_violations-=m_rmr_diagnostics.stop_regression_violations;
      value.invalid_original_r-=m_rmr_diagnostics.invalid_original_r;
      value.recovered_positions-=m_rmr_diagnostics.recovered_positions;
      return(value);
     }
   E2RMRManagementDiagnostics RMRDiagnostics()const{return(m_rmr_diagnostics);}
  };

#endif
