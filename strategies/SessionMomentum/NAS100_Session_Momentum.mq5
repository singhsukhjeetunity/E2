#property strict
#property version "0.10"
#property description "E2 research: NY opening M5 close versus EMA12, both directions, EMA trailing stop."
#include <Trade/Trade.mqh>
#include "..\\shared\\PortfolioGate.mqh"
#include "SessionCore.mqh"

input group "=== SESSION MOMENTUM ==="
input bool InpCloseAtSessionEnd=true;
input int InpSessionCloseNYHour=16;
input int InpSessionCloseNYMinute=0;
input bool InpExportCsv=true; // Per-run research reports; live consolidated journal is guard-owned.
input group "=== RISK MANAGEMENT ==="
enum SMRiskMode { SM_FIXED_CASH=0,SM_BALANCE_PERCENT=1 };
input SMRiskMode InpRiskMode=SM_FIXED_CASH;
input double InpFixedCashRisk=1000.0; // Account currency, before costs/slippage.
input double InpBalanceRiskPercent=1.0;
input group "=== EXECUTION SAFETY ==="
input ulong InpMagic=420611;
input double InpMaxSpreadIndexPoints=10.0; // Price units, 0 disables.
input ulong InpDeviationBrokerPoints=50;
input group "=== BROKER CLOCK PROFILE ==="
input bool InpBrokerClockVerified=false;
input NPClockMode InpBrokerClock=NP_US_SEASONAL;
input double InpServerUTCOffsetWinterHours=2.0;
input double InpServerUTCOffsetSummerHours=3.0;

CTrade sm_trade;
int sm_ema=INVALID_HANDLE;
datetime sm_last_close_try=0,sm_last_modify_try=0,sm_cached_bar=0,sm_block_log=0;
double sm_cached_ema=0;
bool SMUtc(const datetime server,datetime &utc) {
   return NPProfileToUtc(server,InpBrokerClock,(int)MathRound(InpServerUTCOffsetWinterHours*3600),
      (int)MathRound(InpServerUTCOffsetSummerHours*3600),utc);
}
datetime ServerToUTC(const datetime server) {datetime utc=0;SMUtc(server,utc);return utc;}
#include "EntryState.mqh"
#include "SessionReport.mqh"

void SMBlock(const string reason) {
   if(sm_block_log==0||TimeCurrent()-sm_block_log>=60){Print("[SM] ENTRY_BLOCK ",reason);sm_block_log=TimeCurrent();}
}
bool SMClosed(MqlRates &bar,double &ema) {
   if(sm_ema==INVALID_HANDLE||BarsCalculated(sm_ema)<120)return false;
   MqlRates bars[];double values[];
   if(CopyRates(_Symbol,PERIOD_M5,1,1,bars)!=1||CopyBuffer(sm_ema,0,1,1,values)!=1)return false;
   if(bars[0].time!=iTime(_Symbol,PERIOD_M5,1)||bars[0].time+300>TimeCurrent()||
      !MathIsValidNumber(values[0])||values[0]<=0||values[0]==EMPTY_VALUE)return false;
   bar=bars[0];ema=values[0];return true;
}
bool SMHasOwn() {
   for(int i=PositionsTotal()-1;i>=0;i--)if(PositionGetTicket(i)>0&&
      PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic)return true;
   return false;
}
bool SMOccupied() {
   bool hedging=AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   for(int i=PositionsTotal()-1;i>=0;i--)if(PositionGetTicket(i)>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&
      (!hedging||(ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic))return true;
   for(int i=OrdersTotal()-1;i>=0;i--)if(OrderGetTicket(i)>0&&OrderGetString(ORDER_SYMBOL)==_Symbol&&
      (!hedging||(ulong)OrderGetInteger(ORDER_MAGIC)==InpMagic))return true;
   return false;
}
bool SMEnteredToday(const int day) {
   if(!HistorySelect(TimeCurrent()-3*86400,TimeCurrent()+1))return true;
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong d=HistoryDealGetTicket(i);
      if(d==0||HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol||
         (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic)continue;
      long edge=HistoryDealGetInteger(d,DEAL_ENTRY),type=HistoryDealGetInteger(d,DEAL_TYPE);
      if((edge!=DEAL_ENTRY_IN&&edge!=DEAL_ENTRY_INOUT)||(type!=DEAL_TYPE_BUY&&type!=DEAL_TYPE_SELL))continue;
      datetime utc=0;
      if(!SMUtc((datetime)HistoryDealGetInteger(d,DEAL_TIME),utc))return true;
      if(NPDay(NPNy(utc))==day)return true;
   }
   return false;
}
double SMLots(const int direction,const double entry,const double stop) {
   double budget=InpRiskMode==SM_FIXED_CASH?InpFixedCashRisk:AccountInfoDouble(ACCOUNT_BALANCE)*InpBalanceRiskPercent/100;
   ENUM_ORDER_TYPE side=direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double loss=0,margin=0;
   if(!MathIsValidNumber(budget)||budget<=0||!OrderCalcProfit(side,_Symbol,1,entry,stop,loss)||
      !MathIsValidNumber(loss)||loss>=0||!OrderCalcMargin(side,_Symbol,1,entry,margin)||margin<=0)return 0;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),minvol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxvol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(step<=0||minvol<=0||maxvol<minvol)return 0;
   double cap=MathMin(maxvol,MathMin(budget/(-loss),AccountInfoDouble(ACCOUNT_MARGIN_FREE)*0.85/margin));
   double lots=NormalizeDouble(MathFloor((cap+1e-10)/step)*step,8);
   double actual=0,required=0;
   if(lots<minvol||lots>maxvol||!OrderCalcProfit(side,_Symbol,lots,entry,stop,actual)||
      !MathIsValidNumber(actual)||actual>=0||-actual>budget+0.01||
      !OrderCalcMargin(side,_Symbol,lots,entry,required)||required>AccountInfoDouble(ACCOUNT_MARGIN_FREE)*0.85)return 0;
   return lots;
}
bool SMTradeOK(const bool sent) {
   uint code=sm_trade.ResultRetcode();
   return sent&&(code==TRADE_RETCODE_DONE||code==TRADE_RETCODE_DONE_PARTIAL);
}
void SMClose(const ulong ticket,const string why) {
   if(sm_last_close_try!=0&&TimeCurrent()-sm_last_close_try<5)return;
   sm_last_close_try=TimeCurrent();
   bool sent=sm_trade.PositionClose(ticket,InpDeviationBrokerPoints);
   SMSignal(TimeCurrent(),"EXIT_REQUEST",why+" ticket="+IntegerToString((long)ticket)+
      " retcode="+IntegerToString((long)sm_trade.ResultRetcode()));
   if(!SMTradeOK(sent))Print("[SM] Exit not confirmed; will reconcile position and retry: ",sm_trade.ResultRetcode());
}
void SMManage(const bool clock_ok) {
   if(!SMHasOwn())return;
   MqlRates bar;double ema=0;
   if(SMClosed(bar,ema)){sm_cached_bar=bar.time;sm_cached_ema=ema;}
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick)||tick.bid<=0||tick.ask<tick.bid)return;
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0||PositionGetString(POSITION_SYMBOL)!=_Symbol||(ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic)continue;
      long kind=PositionGetInteger(POSITION_TYPE);int direction=kind==POSITION_TYPE_BUY?1:-1;
      double old=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
      if(old<=0){SMClose(ticket,"MISSING_PROTECTIVE_STOP");continue;}
      if(InpCloseAtSessionEnd&&clock_ok) {
         datetime opened=0,now=0;
         if(SMUtc((datetime)PositionGetInteger(POSITION_TIME),opened)&&SMUtc(TimeCurrent(),now)&&
            now>=SMDeadline(opened,InpSessionCloseNYHour*60+InpSessionCloseNYMinute)) {
            SMClose(ticket,"NY_SESSION_END");continue;
         }
      }
      // Never trail from a forming or stale pre-gap candle. Existing broker SL stays active.
      if(sm_cached_bar<=0||TimeCurrent()-sm_cached_bar>=600)continue;
      double next=SMStop(direction,sm_cached_ema,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Digits);
      if(!SMTightens(direction,old,next))continue;
      double reference=direction>0?tick.bid:tick.ask;
      if((direction>0&&reference<=next)||(direction<0&&reference>=next)){SMClose(ticket,"EMA_PASSED_MARKET");continue;}
      double minimum=MathMax((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
         (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
      if(MathAbs(reference-next)<minimum)continue;
      if(sm_last_modify_try>0&&TimeCurrent()-sm_last_modify_try<1)continue;
      sm_last_modify_try=TimeCurrent();
      if(!SMTradeOK(sm_trade.PositionModify(ticket,next,tp)))
         Print("[SM] EMA stop modification not confirmed: ",sm_trade.ResultRetcode());
   }
}
void SMAttempt(const datetime utc) {
   if(!InpBrokerClockVerified||!sm_state_ready)return;
   int second=(int)(NPNy(utc)%86400);
   if(second<575*60||second>=576*60)return; // No late/mid-session catch-up entry.
   MqlRates bar;double ema=0;datetime bar_utc=0;
   if(!SMClosed(bar,ema)||!SMUtc(bar.time,bar_utc)||!SMWindow(utc,bar_utc))return;
   int day=NPDay(NPNy(utc)),direction=SMDirection(bar.close,ema);
   if(direction==0||SMOccupied()||SMEnteredToday(day))return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)||tick.bid<=0||tick.ask<tick.bid||
      tick.time<TimeCurrent()-15||tick.time>TimeCurrent()+1)return;
   if(InpMaxSpreadIndexPoints>0&&tick.ask-tick.bid>InpMaxSpreadIndexPoints){SMBlock("Spread");return;}
   double stop=SMStop(direction,ema,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Digits);
   double reference=direction>0?tick.bid:tick.ask;
   double minimum=MathMax((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
      (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
   if(stop<=0||(direction>0?reference-stop:stop-reference)<=0||
      MathAbs(reference-stop)<minimum){SMBlock("EMA is not a valid protective stop");return;}
   double lots=SMLots(direction,direction>0?tick.ask:tick.bid,stop);
   if(lots<=0){SMBlock("Risk/volume/margin");return;}
   if(!E2PGCanEnter()){SMBlock("PortfolioGuard");return;}
   // All checks precede durable reservation; any order submission consumes today.
   if(!SMReserve(day))return;
   bool sent=direction>0?sm_trade.Buy(lots,_Symbol,0,stop,0,"E2 Session Momentum"):
      sm_trade.Sell(lots,_Symbol,0,stop,0,"E2 Session Momentum");
   SMResult(sm_trade.ResultRetcode(),sm_trade.ResultOrder());
   SMSignal(TimeCurrent(),"ENTRY_REQUEST","side="+IntegerToString(direction)+" volume="+DoubleToString(lots,8)+
      " ema="+DoubleToString(ema,8)+" sl="+DoubleToString(stop,8)+
      " retcode="+IntegerToString((long)sm_trade.ResultRetcode()));
   Print("[SM] Submission side=",direction," lots=",lots," stop=",stop," retcode=",sm_trade.ResultRetcode(),
      " confirmed=",SMTradeOK(sent)," state=",sm_state.status);
}
void SMRun(const bool allow_entry) {
   datetime utc=0;bool clock_ok=InpBrokerClockVerified&&SMUtc(TimeCurrent(),utc);
   SMManage(clock_ok); // Never gated by entry state, export health or PortfolioGuard permission.
   SMReconcile();
   if(allow_entry&&clock_ok)SMAttempt(utc);
   SMEquity(TimeCurrent());
}
int OnInit() {
   if(InpMagic==0||(int)InpRiskMode<0||(int)InpRiskMode>1||
      !MathIsValidNumber(InpFixedCashRisk)||InpFixedCashRisk<=0||
      !MathIsValidNumber(InpBalanceRiskPercent)||InpBalanceRiskPercent<=0||
      !MathIsValidNumber(InpMaxSpreadIndexPoints)||InpMaxSpreadIndexPoints<0||
      (int)InpBrokerClock<1||(int)InpBrokerClock>3||
      !MathIsValidNumber(InpServerUTCOffsetWinterHours)||!MathIsValidNumber(InpServerUTCOffsetSummerHours)||
      InpServerUTCOffsetWinterHours< -12||InpServerUTCOffsetWinterHours>14||
      InpServerUTCOffsetSummerHours< -12||InpServerUTCOffsetSummerHours>14||
      InpSessionCloseNYHour<0||InpSessionCloseNYHour>23||InpSessionCloseNYMinute<0||InpSessionCloseNYMinute>59||
      (InpCloseAtSessionEnd&&InpSessionCloseNYHour*60+InpSessionCloseNYMinute<=575))return INIT_PARAMETERS_INCORRECT;
   sm_trade.SetExpertMagicNumber(InpMagic);sm_trade.SetDeviationInPoints(InpDeviationBrokerPoints);
   sm_trade.SetAsyncMode(false);
   if(!sm_trade.SetTypeFillingBySymbol(_Symbol))return INIT_FAILED;
   sm_ema=iMA(_Symbol,PERIOD_M5,12,0,MODE_EMA,PRICE_CLOSE);
   if(sm_ema==INVALID_HANDLE)return INIT_FAILED;
   if(!SMStateInit()){IndicatorRelease(sm_ema);sm_ema=INVALID_HANDLE;return INIT_FAILED;}
   if(!SMOpenReports()){SMCloseReports();SMStateClose();IndicatorRelease(sm_ema);sm_ema=INVALID_HANDLE;return INIT_FAILED;}
   if(!EventSetTimer(1)){SMCloseReports();SMStateClose();IndicatorRelease(sm_ema);sm_ema=INVALID_HANDLE;return INIT_FAILED;}
   Print("[SM] Session Momentum v0.10 initialized. Symbol=",_Symbol,
      " EMA=12 M5 NY=09:30-09:35; close_at_session_end=",InpCloseAtSessionEnd,
      " clock_verified=",InpBrokerClockVerified," magic=",InpMagic);
   if(!InpBrokerClockVerified)Print("[SM] Verify the historical broker clock profile before enabling entries.");
   return INIT_SUCCEEDED;
}
void OnTick(){SMRun(true);}
void OnTimer(){SMRun(false);} // Timer manages existing trades; it never opens a stale signal.
void OnDeinit(const int reason) {
   EventKillTimer();SMCloseReports();SMStateClose();
   if(sm_ema!=INVALID_HANDLE){IndicatorRelease(sm_ema);sm_ema=INVALID_HANDLE;}
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result) {
   SMReconcile(true);
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD)SMExportTrades();
}
double OnTester(){SMExportTrades();return 0;}
