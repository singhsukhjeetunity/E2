#property strict
#property version "0.10"
#property description "E2 System 6 research: two-day extreme reversal. Unpublished filters/exits are explicit assumptions."
#include "..\\shared\\PortfolioGate.mqh"
#include "..\\shared\\SessionClock.mqh"
#include "ReversalCore.mqh"

input group "=== E2 EURUSD TWO-DAY REVERSAL ==="
input ulong InpMagic=420606;
input bool InpExportCsv=true;
input group "=== RISK MANAGEMENT ==="
enum E2RiskMode { E2_RISK_FIXED_CASH=0,E2_RISK_BALANCE_PERCENT=1 };
input E2RiskMode InpRiskMode=E2_RISK_FIXED_CASH;
input double InpFixedCashRisk=1000.0;
input double InpBalanceRiskPercent=1.0;
input group "=== RESEARCH FILTERS (NOT PUBLISHED PARAMETERS) ==="
input bool InpUseMomentumFilter=true;
input int InpMomentumSessions=10;
input double InpMaxAbsMomentumPercent=1.0;
input bool InpUseEfficiencyFilter=true;
input int InpEfficiencySessions=10;
input double InpMaxEfficiencyRatio=0.35;
input bool InpSkipSundayDailyBars=true;
input group "=== RESEARCH EXITS (NOT PUBLISHED PARAMETERS) ==="
input int InpATRSessionPeriod=14;
input double InpStopATRMultiple=1.5;
input double InpTargetR=1.5;
input int InpMaxHoldingSessions=2;
input bool InpOneTradePerSession=true;
input group "=== EXECUTION SAFETY ==="
input double InpMaxSpreadPips=2.0; // 0 disables the spread cap
input int InpDeviationBrokerPoints=20;
input double InpMarginBuffer=0.15;
input group "=== BROKER CLOCK PROFILE ==="
input bool InpBrokerClockVerified=false;
input NPClockMode InpBrokerClockMode=NP_CLOCK_UNSET;
input int InpServerUTCOffsetWinterHours=0;
input int InpServerUTCOffsetSummerHours=0;

E2RSnapshot g_snapshot;
datetime g_session=0,g_lastCloseAttempt=0,g_lastGuardBar=0;
double g_previousBid=0;
bool g_snapshotReady=false,g_running=false;
string g_statePrefix="";
ulong g_recoveredIds[];

datetime ServerToUTC(const datetime server) {
   datetime utc=0;
   if(!NPProfileToUtc(server,InpBrokerClockMode,InpServerUTCOffsetWinterHours*3600,
      InpServerUTCOffsetSummerHours*3600,utc))return 0;
   return utc;
}
bool EligibleSession(const datetime time) {
   MqlDateTime d;TimeToStruct(time,d);
   return d.day_of_week!=6&&(!InpSkipSundayDailyBars||d.day_of_week!=0);
}
double PipSize() {return _Point*((_Digits==3||_Digits==5)?10:1);}
double TickRound(const double price) {
   double size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(size<=0)return 0;
   return NormalizeDouble(MathRound(price/size)*size,_Digits);
}
bool BuildSnapshot() {
   int needed=InpATRSessionPeriod+1;
   if(InpUseMomentumFilter)needed=MathMax(needed,InpMomentumSessions+1);
   if(InpUseEfficiencyFilter)needed=MathMax(needed,InpEfficiencySessions+1);
   MqlRates daily[];ArraySetAsSeries(daily,false);
   int n=CopyRates(_Symbol,PERIOD_D1,1,needed*2+10,daily);
   E2RDailySeries series;series.count=0;
   for(int i=n-1;i>=0&&series.count<needed;i--) {
      if(!EligibleSession(daily[i].time))continue;
      int j=series.count++;
      series.bars[j].high=daily[i].high;series.bars[j].low=daily[i].low;series.bars[j].close=daily[i].close;
   }
   return E2RBuildSnapshot(series,InpATRSessionPeriod,InpMomentumSessions,InpEfficiencySessions,
      InpUseMomentumFilter,InpMaxAbsMomentumPercent,InpUseEfficiencyFilter,InpMaxEfficiencyRatio,g_snapshot);
}

#include "ReversalReport.mqh"

bool SymbolOccupied() {
   for(int i=PositionsTotal()-1;i>=0;i--)if(PositionGetTicket(i)>0&&PositionGetString(POSITION_SYMBOL)==_Symbol)return true;
   for(int i=OrdersTotal()-1;i>=0;i--)if(OrderGetTicket(i)>0&&OrderGetString(ORDER_SYMBOL)==_Symbol)return true;
   return false;
}
ENUM_ORDER_TYPE_FILLING FillPolicy() {
   long mode=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((mode&SYMBOL_FILLING_IOC)!=0)return ORDER_FILLING_IOC;
   if((mode&SYMBOL_FILLING_FOK)!=0)return ORDER_FILLING_FOK;
   return ORDER_FILLING_RETURN;
}
bool EntrySince(const datetime since) {
   if(!HistorySelect(since,TimeCurrent()+1))return true; // unavailable history blocks entries
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0||HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol||
         (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic)continue;
      long edge=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(edge==DEAL_ENTRY_IN||edge==DEAL_ENTRY_INOUT)return true;
   }
   return false;
}
bool StateWrite(const string field,const double value) {
   if(GlobalVariableSet(g_statePrefix+field,value)==0)return false;
   GlobalVariablesFlush();return true;
}
bool SubmissionBlocked() {
   // Pending submissions survive live restarts and do not unlock at a daily rollover.
   double pending=GlobalVariableGet(g_statePrefix+"PENDING");
   datetime submitted=(datetime)GlobalVariableGet(g_statePrefix+"SUBMITTED");
   if(pending>0) {
      // A confirmed entry is the only automatic resolution of ambiguous execution.
      if(submitted>0&&HistorySelect(submitted,TimeCurrent()+1)) {
         bool confirmed=false;
         for(int i=0;i<HistoryDealsTotal();i++) {
            ulong d=HistoryDealGetTicket(i);
            if(d>0&&HistoryDealGetString(d,DEAL_SYMBOL)==_Symbol&&
               (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)==InpMagic&&
               HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN){confirmed=true;break;}
         }
         if(confirmed)StateWrite("PENDING",0);
         else return true;
      } else return true;
   }
   if(submitted>0&&TimeCurrent()-submitted<5)return true; // allow the position/deal cache to settle
   if(InpOneTradePerSession&&(submitted>=g_session||EntrySince(g_session)))return true;
   return false;
}
int CompletedHoldingSessions(const datetime opened) {
   MqlRates daily[];ArraySetAsSeries(daily,false);
   // Include the broker D1 session containing the entry, and exclude the forming one.
   int shift=iBarShift(_Symbol,PERIOD_D1,opened,false);
   if(shift<0)return -1;
   if(shift==0)return 0;
   int count=CopyRates(_Symbol,PERIOD_D1,1,shift,daily);
   if(count!=shift)return -1;
   int sessions=0;
   for(int i=0;i<count;i++)if(EligibleSession(daily[i].time))sessions++;
   return sessions;
}
bool ClosePosition(const ulong ticket,const long kind,const double volume,const string reason) {
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick)||tick.bid<=0||tick.ask<=0)return false;
   MqlTradeRequest req={};MqlTradeResult res={};
   req.action=TRADE_ACTION_DEAL;req.symbol=_Symbol;req.position=ticket;req.magic=InpMagic;
   req.volume=volume;req.type=kind==POSITION_TYPE_BUY?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
   req.price=kind==POSITION_TYPE_BUY?tick.bid:tick.ask;req.deviation=InpDeviationBrokerPoints;
   req.type_filling=FillPolicy();req.comment="E2 2DR exit";
   if(!StateWrite("EXIT_PENDING",(double)ticket))return false;
   bool sent=OrderSend(req,res);
   RSignal(TimeCurrent(),"EXIT_REQUEST",reason+" ticket="+StringFormat("%I64u",ticket)+" retcode="+IntegerToString(res.retcode));
   if(res.retcode!=TRADE_RETCODE_TIMEOUT&&res.retcode!=TRADE_RETCODE_PLACED)
      StateWrite("EXIT_PENDING",0);
   return sent&&(res.retcode==TRADE_RETCODE_DONE||res.retcode==TRADE_RETCODE_DONE_PARTIAL);
}
void ManageExits() {
   ulong pending=(ulong)GlobalVariableGet(g_statePrefix+"EXIT_PENDING");
   if(pending>0&&!PositionSelectByTicket(pending))StateWrite("EXIT_PENDING",0);
   if(TimeCurrent()-g_lastCloseAttempt<5)return;
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0||PositionGetString(POSITION_SYMBOL)!=_Symbol||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic)continue;
      long kind=PositionGetInteger(POSITION_TYPE);
      double sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      int sessions=CompletedHoldingSessions(opened);
      string reason=sl<=0||tp<=0?"MISSING_PROTECTION":(sessions>=InpMaxHoldingSessions?"MAX_SESSIONS":"");
      if(reason==""||GlobalVariableGet(g_statePrefix+"EXIT_PENDING")>0)continue;
      g_lastCloseAttempt=TimeCurrent();
      ClosePosition(ticket,kind,PositionGetDouble(POSITION_VOLUME),reason);
   }
}
double SizeForStop(const ENUM_ORDER_TYPE side,const double entry,const double stop) {
   double budget=InpRiskMode==E2_RISK_FIXED_CASH?InpFixedCashRisk:AccountInfoDouble(ACCOUNT_BALANCE)*InpBalanceRiskPercent/100;
   double loss=0,margin=0;
   if(budget<=0||!OrderCalcProfit(side,_Symbol,1,entry,stop,loss)||loss>=0||
      !OrderCalcMargin(side,_Symbol,1,entry,margin)||margin<=0)return 0;
   double raw=MathMin(budget/(-loss),AccountInfoDouble(ACCOUNT_MARGIN_FREE)/(margin*(1+InpMarginBuffer)));
   return NormalizeDouble(E2RVolumeFloor(raw,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),
      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)),8);
}
void AttemptEntry(const int direction,const MqlTick &tick) {
   if(direction==0||!g_snapshot.allowed||SymbolOccupied()||SubmissionBlocked())return;
   if(InpMaxSpreadPips>0&&(tick.ask-tick.bid)/PipSize()>InpMaxSpreadPips)return;
   ENUM_ORDER_TYPE side=direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double entry=direction>0?tick.ask:tick.bid;
   double distance=g_snapshot.atr*InpStopATRMultiple;
   double stop=TickRound(entry-direction*distance);
   double target=TickRound(entry+direction*distance*InpTargetR);
   double stops=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   // Broker stop distance is measured from the closing quote, not the requested entry.
   if(stop<=0||target<=0||(direction>0&&(stop>=tick.bid||target<=tick.bid||tick.bid-stop<stops||target-tick.bid<stops))||
      (direction<0&&(stop<=tick.ask||target>=tick.ask||stop-tick.ask<stops||tick.ask-target<stops)))return;
   double volume=SizeForStop(side,entry,stop);if(volume<=0)return;
   MqlTradeRequest req={};MqlTradeResult res={};MqlTradeCheckResult check={};
   req.action=TRADE_ACTION_DEAL;req.symbol=_Symbol;req.magic=InpMagic;req.type=side;
   req.volume=volume;req.price=entry;req.sl=stop;req.tp=target;
   req.deviation=InpDeviationBrokerPoints;req.type_filling=FillPolicy();req.comment="E2 2DR research";
   if(!OrderCheck(req,check)||(check.retcode!=0&&check.retcode!=TRADE_RETCODE_DONE)) {
      RSignal(TimeCurrent(),"ORDER_CHECK_BLOCK",check.comment);return;
   }
   if(!E2PGCanEnter()) {
      datetime bar=iTime(_Symbol,PERIOD_M5,0);
      if(bar!=g_lastGuardBar){g_lastGuardBar=bar;RSignal(TimeCurrent(),"PORTFOLIO_GUARD_BLOCK","Guard missing or daily lock");}
      return;
   }
   // Write the durable intent BEFORE sending; a crash/timeout must not duplicate the order.
   if(!GlobalVariableSetOnCondition(g_statePrefix+"PENDING",1,0))return;
   GlobalVariablesFlush();
   // Re-check after acquiring the shared intent: another chart may have submitted
   // between the initial check and this acquisition.
   datetime last=(datetime)GlobalVariableGet(g_statePrefix+"SUBMITTED");
   if(last>0&&(TimeCurrent()-last<5||(InpOneTradePerSession&&last>=g_session))) {
      StateWrite("PENDING",0);return;
   }
   if(!StateWrite("SUBMITTED",(double)TimeCurrent()))return;
   bool sent=OrderSend(req,res);
   bool accepted=sent&&(res.retcode==TRADE_RETCODE_DONE||res.retcode==TRADE_RETCODE_DONE_PARTIAL);
   bool unknown=res.retcode==TRADE_RETCODE_TIMEOUT||res.retcode==TRADE_RETCODE_PLACED||res.retcode==TRADE_RETCODE_CONNECTION;
   if(accepted)StateWrite("PENDING",0);
   else if(!unknown){StateWrite("PENDING",0);StateWrite("SUBMITTED",0);}
   RSignal(TimeCurrent(),"ENTRY_REQUEST",StringFormat("side=%d volume=%.8f price=%.8f sl=%.8f tp=%.8f retcode=%u",direction,volume,entry,stop,target,res.retcode));
   PrintFormat("[2DR] entry side=%d sent=%d retcode=%u volume=%.2f",direction,(int)sent,res.retcode,volume);
}
void Run(const bool allow_entries) {
   if(g_running)return;g_running=true;
   // Exits remain independent of entry filters, history readiness, clock and portfolio gate.
   ManageExits();
   datetime session=iTime(_Symbol,PERIOD_D1,0);
   MqlTick tick;
   bool have_tick=SymbolInfoTick(_Symbol,tick)&&tick.bid>0&&tick.ask>=tick.bid;
   if(session>0&&session!=g_session){g_session=session;g_snapshotReady=false;g_previousBid=0;}
   if(!g_snapshotReady&&session>0) {
      g_snapshotReady=BuildSnapshot();
      if(g_snapshotReady) {
         g_previousBid=0;
         RSignal(TimeCurrent(),"DAILY_FILTER",StringFormat("allowed=%d high=%.8f low=%.8f atr=%.8f momentum_pct=%.6f efficiency=%.6f",
         (int)g_snapshot.allowed,g_snapshot.high,g_snapshot.low,g_snapshot.atr,g_snapshot.momentum_percent,g_snapshot.efficiency));
      }
   }
   if(allow_entries&&have_tick) {
      int direction=g_snapshotReady?E2RTouchSide(g_previousBid,tick.bid,g_snapshot.low,g_snapshot.high):0;
      g_previousBid=tick.bid;
      if(InpBrokerClockVerified&&ServerToUTC(TimeCurrent())>0&&EligibleSession(session)&&g_snapshotReady)
         AttemptEntry(direction,tick);
   }
   REquity(TimeCurrent());g_running=false;
}
bool ValidInputs() {
   return InpMagic>0&&(int)InpRiskMode>=0&&(int)InpRiskMode<=1&&
      MathIsValidNumber(InpFixedCashRisk)&&InpFixedCashRisk>0&&
      MathIsValidNumber(InpBalanceRiskPercent)&&InpBalanceRiskPercent>0&&InpBalanceRiskPercent<=100&&
      InpATRSessionPeriod>=1&&InpATRSessionPeriod<=256&&InpMomentumSessions>=1&&InpMomentumSessions<=256&&
      InpEfficiencySessions>=1&&InpEfficiencySessions<=256&&
      MathIsValidNumber(InpMaxAbsMomentumPercent)&&InpMaxAbsMomentumPercent>=0&&
      MathIsValidNumber(InpMaxEfficiencyRatio)&&InpMaxEfficiencyRatio>=0&&InpMaxEfficiencyRatio<=1&&
      MathIsValidNumber(InpStopATRMultiple)&&InpStopATRMultiple>0&&
      MathIsValidNumber(InpTargetR)&&InpTargetR>0&&InpMaxHoldingSessions>=1&&InpMaxHoldingSessions<=250&&
      MathIsValidNumber(InpMaxSpreadPips)&&InpMaxSpreadPips>=0&&InpDeviationBrokerPoints>=0&&
      MathIsValidNumber(InpMarginBuffer)&&InpMarginBuffer>=0&&
      (int)InpBrokerClockMode>=0&&(int)InpBrokerClockMode<=3&&
      InpServerUTCOffsetWinterHours>=-12&&InpServerUTCOffsetWinterHours<=14&&
      InpServerUTCOffsetSummerHours>=-12&&InpServerUTCOffsetSummerHours<=14&&
      (!InpBrokerClockVerified||InpBrokerClockMode!=NP_CLOCK_UNSET);
}
int OnInit() {
   if(!ValidInputs())return INIT_PARAMETERS_INCORRECT;
   // Symbol suffixes are supported; prevent accidental attachment to a different currency pair.
   if(SymbolInfoString(_Symbol,SYMBOL_CURRENCY_BASE)!="EUR"||SymbolInfoString(_Symbol,SYMBOL_CURRENCY_PROFIT)!="USD") {
      Print("[2DR] This research EA requires an EURUSD symbol.");return INIT_PARAMETERS_INCORRECT;
   }
   g_statePrefix="E2R_"+StringFormat("%08X",RHash(AccountInfoString(ACCOUNT_SERVER)+"|"+_Symbol+"|"+StringFormat("%I64u",InpMagic)))+
      "_"+StringFormat("%I64d",AccountInfoInteger(ACCOUNT_LOGIN))+"_";
   if(MQLInfoInteger(MQL_TESTER))g_statePrefix="E2RT_"+StringFormat("%I64u",GetMicrosecondCount())+"_";
   string fields[]={"SUBMITTED","PENDING","EXIT_PENDING"};
   for(int i=0;i<ArraySize(fields);i++)if(!GlobalVariableCheck(g_statePrefix+fields[i])&&!StateWrite(fields[i],0))return INIT_FAILED;
   // Remember pre-existing positions so their eventual exits appear in this run's trade CSV.
   for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&
      (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic) {
      int n=ArraySize(g_recoveredIds);ArrayResize(g_recoveredIds,n+1);
      g_recoveredIds[n]=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   }
   if(!ROpenReports()){RCloseReports();return INIT_FAILED;}
   if(!EventSetTimer(5)){RCloseReports();return INIT_FAILED;}
   Print("[2DR] Research assumptions: broker D1 sessions, ATR stop, R target, low-momentum/low-efficiency filters. Published performance is not replicated.");
   if(!InpBrokerClockVerified)Print("[2DR] New entries disabled until broker clock is verified.");
   if(GlobalVariableGet(g_statePrefix+"PENDING")>0||GlobalVariableGet(g_statePrefix+"EXIT_PENDING")>0)
      Print("[2DR] Recovered unresolved order submission: reconcile broker history before clearing state.");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){EventKillTimer();RCloseReports();}
void OnTick(){Run(true);}
void OnTimer(){Run(false);}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result) {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD||trans.deal==0||!HistoryDealSelect(trans.deal)||
      HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol)return;
   RExportTrades(); // includes manual/guard exits by position identifier, even with a different deal magic
}
