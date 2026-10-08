#ifndef RC_RUNTIME_MQH
#define RC_RUNTIME_MQH
#include <Trade/Trade.mqh>
#include "Core.mqh"
#include "Clock.mqh"
input group "Execution and ownership"
input ulong InpMagic=RC_DEFAULT_MAGIC;
input double InpRiskPercent=0.25;
input double InpCashRisk=0; // >0 overrides percent; account currency.
input double InpMaxSpreadPoints=RC_DEFAULT_SPREAD;
input ulong InpDeviationPoints=10;
input bool InpOneEntryPerDay=true;
input bool InpAllowFridayEntries=true;
input group "Verified broker clock (never use TimeGMT in tester)"
input bool InpBrokerClockVerified=false;
input RCClock InpBrokerDST=RC_EU;
input int InpBrokerWinterUTCMinutes=120;
input group "Reference sessions, independent of broker D1 bars"
input RCClock InpSessionDST=RC_DEFAULT_DST;
input int InpSessionWinterUTCMinutes=RC_DEFAULT_OFFSET;
input int InpSessionOpenMinute=RC_DEFAULT_OPEN;
input int InpSessionCloseMinute=RC_DEFAULT_CLOSE;
input string InpClosedDates=""; // YYYYMMDD|YYYYMMDD in reference-session dates.
input string InpEarlyCloseDates="";
input int InpEarlyCloseMinute=780;
input int InpHistoryDays=90;
input double InpMinimumMinuteCoverage=0.80;
input group "Research risk overlay"
input int InpATRPeriod=14;
input double InpStopATR=3.0;
input double InpTargetR=0; // 0 disables fixed target; strategy exits still apply.
input int InpMaximumHoldingDays=5;
input bool InpFridayFlat=true;
input int InpFridayFlatUTCMinute=1200; // 20:00 UTC: override for broker hours.
input int InpEntryGraceSeconds=60;

CTrade rc_trade;
RCBar rc_days[];
int rc_count=0,rc_cache_key=0;
bool rc_ready=false;
datetime rc_last_minute=0,rc_last_close_attempt=0;
double rc_last_bid=0;
bool RCValidate();
void RCProcess(const datetime utc);
datetime RCStrategyDeadline(const datetime opened_utc);

datetime RCNow() {
   datetime utc=0;
   if(!RCUtc(TimeCurrent(),InpBrokerDST,InpBrokerWinterUTCMinutes,utc))return 0;
   return utc;
}
datetime RCServer(const datetime utc) {
   return RCWall(utc,InpBrokerDST,InpBrokerWinterUTCMinutes);
}
datetime RCSessionWall(const datetime utc) {
   return RCWall(utc,InpSessionDST,InpSessionWinterUTCMinutes);
}
int RCCloseMinute(const datetime day) {
   return RCListed(InpEarlyCloseDates,day)?InpEarlyCloseMinute:InpSessionCloseMinute;
}
datetime RCBoundary(const datetime wall_day,const int minute) {
   datetime utc=0;
   if(!RCUtc(RCDay(wall_day)+minute*60,InpSessionDST,InpSessionWinterUTCMinutes,utc))return 0;
   return utc;
}
bool RCSessionAllowed(const datetime day) {
   return RCWeekday(day)&&!RCListed(InpClosedDates,day);
}
bool RCInSession(const datetime utc) {
   datetime wall=RCSessionWall(utc);int minute=(int)(wall%86400)/60;
   return RCSessionAllowed(wall)&&minute>=InpSessionOpenMinute&&minute<RCCloseMinute(wall);
}
datetime RCSessionDeadline(const datetime utc) {
   datetime wall=RCSessionWall(utc);
   return RCBoundary(wall,RCCloseMinute(wall));
}
bool RCIsOwn() {
   return PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic;
}
bool RCHasOwn() {
   for(int i=PositionsTotal()-1;i>=0;i--)if(PositionGetTicket(i)>0&&RCIsOwn())return true;
   return false;
}
bool RCAnySymbolPosition() {
   for(int i=PositionsTotal()-1;i>=0;i--)if(PositionGetTicket(i)>0&&PositionGetString(POSITION_SYMBOL)==_Symbol)return true;
   return false;
}
bool RCTradeOK(const bool sent) {
   uint code=rc_trade.ResultRetcode();
   return sent&&(code==TRADE_RETCODE_DONE||code==TRADE_RETCODE_DONE_PARTIAL);
}
void RCCloseOwn() {
   // Ticket based on hedging accounts: never close another strategy's position.
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong ticket=PositionGetTicket(i);if(ticket==0||!RCIsOwn())continue;
      if(!RCTradeOK(rc_trade.PositionClose(ticket,InpDeviationPoints)))
         Print("Research exit retry required: ",ticket," ",rc_trade.ResultRetcodeDescription());
   }
}
datetime RCOverlayDeadline(const datetime opened_utc) {
   datetime deadline=RCStrategyDeadline(opened_utc);
   if(InpMaximumHoldingDays>0) {
      datetime cap=opened_utc+InpMaximumHoldingDays*86400;
      if(deadline==0||cap<deadline)deadline=cap;
   }
   if(InpFridayFlat) {
      MqlDateTime d;TimeToStruct(opened_utc,d);
      int ahead=(5-d.day_of_week+7)%7;
      datetime friday=RCDay(opened_utc)+ahead*86400+InpFridayFlatUTCMinute*60;
      if(friday<opened_utc)friday=opened_utc;
      if(deadline==0||friday<deadline)deadline=friday;
   }
   return deadline;
}
void RCManage(const datetime utc) {
   bool close=false;
   for(int i=PositionsTotal()-1;i>=0;i--) {
      if(PositionGetTicket(i)==0||!RCIsOwn())continue;
      datetime opened=0;
      if(!RCUtc((datetime)PositionGetInteger(POSITION_TIME),InpBrokerDST,InpBrokerWinterUTCMinutes,opened))continue;
      datetime deadline=RCOverlayDeadline(opened);
      if(PositionGetDouble(POSITION_SL)<=0||(deadline>0&&utc>=deadline))close=true;
   }
   if(close&&utc-rc_last_close_attempt>=5){rc_last_close_attempt=utc;RCCloseOwn();}
}
bool RCEnteredSince(const datetime since_utc) {
   if(!HistorySelect(RCServer(since_utc),TimeCurrent()))return true; // Fail closed.
   for(int i=HistoryDealsTotal()-1;i>=0;i--) {
      ulong ticket=HistoryDealGetTicket(i);
      if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol||(ulong)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=InpMagic)continue;
      ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket,DEAL_ENTRY);
      ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket,DEAL_TYPE);
      if((entry==DEAL_ENTRY_IN||entry==DEAL_ENTRY_INOUT)&&(type==DEAL_TYPE_BUY||type==DEAL_TYPE_SELL))return true;
   }
   return false;
}
bool RCEnter(const int direction,const double distance,const double target_r,const datetime utc,
             const datetime unique_since=0) {
   if(direction==0||distance<=0||RCHasOwn())return false;
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING&&RCAnySymbolPosition())return false;
   MqlDateTime d;TimeToStruct(utc,d);
   if(!RCWeekday(utc)||(InpFridayFlat&&d.day_of_week==5&&(int)(utc%86400)/60>=InpFridayFlatUTCMinute))return false;
   if(!InpAllowFridayEntries&&d.day_of_week==5)return false;
   datetime session_start=RCBoundary(RCSessionWall(utc),0);
   if(unique_since>0&&RCEnteredSince(unique_since))return false;
   if(InpOneEntryPerDay&&RCEnteredSince(session_start))return false;
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick)||tick.ask<=0||tick.bid<=0)return false;
   if((tick.ask-tick.bid)/_Point>InpMaxSpreadPoints)return false;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(step<=0)return false;
   double entry=direction>0?tick.ask:tick.bid;
   double stop=direction>0?MathFloor((entry-distance)/step)*step:MathCeil((entry+distance)/step)*step;
   double target=0;
   if(target_r>0)target=direction>0?MathCeil((entry+target_r*MathAbs(entry-stop))/step)*step:
                                 MathFloor((entry-target_r*MathAbs(entry-stop))/step)*step;
   stop=NormalizeDouble(stop,_Digits);target=NormalizeDouble(target,_Digits);
   double minimum=MathMax((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                          (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
   double reference=direction>0?tick.bid:tick.ask;
   if(stop<=0||(direction>0?reference-stop:stop-reference)<minimum)return false;
   if(target>0&&(direction>0?target-reference:reference-target)<minimum)return false;
   double profit=0;
   ENUM_ORDER_TYPE side=direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   if(!OrderCalcProfit(side,_Symbol,1.0,entry,stop,profit)||profit>=0)return false;
   double budget=InpCashRisk>0?InpCashRisk:AccountInfoDouble(ACCOUNT_EQUITY)*InpRiskPercent/100;
   double lots=RCVolume(budget,-profit,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
                        SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
   if(lots<=0)return false;
   double margin=0;if(!OrderCalcMargin(side,_Symbol,lots,entry,margin)||margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))return false;
   bool sent=direction>0?rc_trade.Buy(lots,_Symbol,0,stop,target,RC_NAME):rc_trade.Sell(lots,_Symbol,0,stop,target,RC_NAME);
   if(!RCTradeOK(sent)){Print("Research entry rejected: ",rc_trade.ResultRetcodeDescription());return false;}
   Print(RC_NAME," entry ",direction," lots=",lots," SL=",stop," TP=",target," risk_budget=",budget);
   RCManage(utc);return true;
}
bool RCRefreshDays(const datetime utc) {
   datetime wall=RCSessionWall(utc);
   int key=RCDayKey(wall)*2+((int)(wall%86400)/60>=RCCloseMinute(wall)?1:0);
   if(rc_cache_key==key&&rc_ready)return true;
   rc_ready=false;
   MqlRates rates[];
   datetime end=iTime(_Symbol,PERIOD_M1,0)-1;
   if(end<=0)return false;
   int n=CopyRates(_Symbol,PERIOD_M1,RCServer(utc-InpHistoryDays*86400),end,rates);
   if(n<=0)return false;
   ArraySetAsSeries(rates,false);ArrayResize(rc_days,0);rc_count=0;
   RCBar bar={};datetime day=0;
   for(int i=0;i<=n;i++) {
      datetime u=0,w=0,current=0;
      if(i<n) {
         if(!RCUtc(rates[i].time,InpBrokerDST,InpBrokerWinterUTCMinutes,u))continue;
         w=RCSessionWall(u);current=RCDay(w);
      }
      if(day!=0&&(i==n||current!=day)) {
         datetime start=RCBoundary(day,InpSessionOpenMinute),finish=RCBoundary(day,RCCloseMinute(day));
         int expected=RCCloseMinute(day)-InpSessionOpenMinute;
         if(bar.minutes>0&&finish<=utc&&bar.start<=start+300&&bar.minutes>=expected*InpMinimumMinuteCoverage) {
            ArrayResize(rc_days,rc_count+1);rc_days[rc_count++]=bar;
         }
         ZeroMemory(bar);day=0;
      }
      if(i==n)break;
      int minute=(int)(w%86400)/60;
      if(!RCSessionAllowed(w)||minute<InpSessionOpenMinute||minute>=RCCloseMinute(w))continue;
      if(day==0){day=current;bar.start=u;bar.open=rates[i].open;bar.high=rates[i].high;bar.low=rates[i].low;}
      bar.high=MathMax(bar.high,rates[i].high);bar.low=MathMin(bar.low,rates[i].low);bar.close=rates[i].close;bar.minutes++;
   }
   if(rc_count<InpATRPeriod+1)return false;
   // Missing a recent session must not silently turn an older day into yesterday.
   datetime expected=RCDay(wall);
   if(RCBoundary(expected,RCCloseMinute(expected))>utc)expected-=86400;
   int skipped=0;
   while(!RCSessionAllowed(expected)&&skipped<14){expected-=86400;skipped++;}
   if(RCDay(RCSessionWall(rc_days[rc_count-1].start))!=expected)return false;
   rc_ready=true;rc_cache_key=key;return true;
}
bool RCMinuteEvent(const datetime utc) {
   datetime minute=RCDay(utc)+(utc%86400)/60*60;
   if(minute==rc_last_minute)return false;
   rc_last_minute=minute;return true;
}
bool RCRecentBars(const ENUM_TIMEFRAMES frame,const int count,RCBar &bars[]) {
   MqlRates rates[];int n=CopyRates(_Symbol,frame,1,count,rates);
   if(n!=count)return false;
   ArraySetAsSeries(rates,false);ArrayResize(bars,count);
   for(int i=0;i<count;i++) {
      datetime utc=0;if(!RCUtc(rates[i].time,InpBrokerDST,InpBrokerWinterUTCMinutes,utc))return false;
      bars[i].start=utc;bars[i].open=rates[i].open;bars[i].high=rates[i].high;
      bars[i].low=rates[i].low;bars[i].close=rates[i].close;bars[i].minutes=PeriodSeconds(frame)/60;
   }
   return true;
}
int OnInit() {
   if(!InpBrokerClockVerified){Print("Set a verified historical broker UTC/DST profile before running research EA.");return INIT_PARAMETERS_INCORRECT;}
   if(InpMagic==0||InpRiskPercent<=0||InpCashRisk<0||InpMaxSpreadPoints<=0||InpATRPeriod<1||InpATRPeriod>100||
      InpStopATR<=0||InpTargetR<0||InpSessionOpenMinute<0||InpSessionCloseMinute>1440||
      InpSessionOpenMinute>=InpSessionCloseMinute||InpEarlyCloseMinute<=InpSessionOpenMinute||
      InpEarlyCloseMinute>InpSessionCloseMinute||InpHistoryDays<30||InpHistoryDays>365||
      InpMinimumMinuteCoverage<=0||InpMinimumMinuteCoverage>1||InpMaximumHoldingDays<0||
      InpFridayFlatUTCMinute<0||InpFridayFlatUTCMinute>=1440||InpEntryGraceSeconds<1||
      InpBrokerWinterUTCMinutes< -720||InpBrokerWinterUTCMinutes>840||
      InpSessionWinterUTCMinutes< -720||InpSessionWinterUTCMinutes>840||!RCValidate())return INIT_PARAMETERS_INCORRECT;
   rc_trade.SetExpertMagicNumber(InpMagic);rc_trade.SetDeviationInPoints(InpDeviationPoints);
   rc_trade.SetAsyncMode(false);rc_trade.SetTypeFillingBySymbol(_Symbol);
   Print(RC_NAME," RESEARCH ONLY: source gaps and risk overlays documented in ResearchCandidates/README.md");
   return INIT_SUCCEEDED;
}
void OnTick() {
   datetime utc=RCNow();if(utc==0)return;
   RCManage(utc);RCProcess(utc);
   MqlTick tick;if(SymbolInfoTick(_Symbol,tick))rc_last_bid=tick.bid;
}
#endif
