#property strict
#property version "0.13"
#property description "BTCUSD H4 momentum / H1 entry RESEARCH adaptation with fixed 1R brackets."
#include "..\\shared\\PortfolioGate.mqh"
#include "..\\shared\\SessionClock.mqh"
#include "MomentumCore.mqh"

input group "=== BTCUSD MOMENTUM RESEARCH ==="
input ulong InpMagic=420609;
input bool InpExportCsv=true;
input group "=== H4 REGIME / COMPLETED H1 ENTRIES ==="
input int InpRSIPeriod=20;
input double InpRSIThreshold=70.0;
enum E2BEntryMode { BTC_PULLBACK=0,BTC_BREAKOUT=1,BTC_HYBRID=2 };
input E2BEntryMode InpEntryMode=BTC_HYBRID;
input bool InpBaseEntry=true;
input bool InpOneTradePerDay=false; // one filled entry per UTC date, symbol and magic
input double InpPullbackPercent=0.75;
input double InpBreakoutPercent=0.25;
input int InpBreakoutLookback=8;
input int InpMaxEntriesPerZone=6;
input int InpCooldownHours=2;
input int InpEntryGraceSeconds=60;
input group "=== FIXED 1R BRACKETS (RESEARCH EXIT ADAPTATION) ==="
input double InpStopPercent=1.25;
input int InpMaxHoldingHours=0; // 0: SL/TP only. Positive value adds a time exit.
input group "=== OPTIONAL WEEKEND FLAT (BROKER SERVER TIME) ==="
input bool InpWeekendFlat=false;
input int InpFridayFlatHour=20;
input int InpFridayFlatMinute=0; // block entries and close from Friday cutoff until Monday 00:00
input group "=== POSITION RISK ==="
enum E2RiskMode { E2_RISK_FIXED_CASH=0,E2_RISK_BALANCE_PERCENT=1 };
input E2RiskMode InpRiskMode=E2_RISK_FIXED_CASH;
input double InpFixedCashRisk=1000.0;
input double InpBalanceRiskPercent=1.0;
input double InpRiskTolerancePercent=2.0; // reject size below 98% of intended stop risk
input group "=== EXECUTION SAFETY ==="
input double InpMaxSpreadPercent=0.05; // percent of Bid; 0 disables
input int InpDeviationBrokerPoints=100;
input int InpMaxQuoteAgeSeconds=10;
input double InpMarginBuffer=0.15;
input group "=== BROKER CLOCK PROFILE ==="
input bool InpBrokerClockVerified=false;
input NPClockMode InpBrokerClockMode=NP_CLOCK_UNSET;
input int InpServerUTCOffsetWinterHours=0;
input int InpServerUTCOffsetSummerHours=0;

int g_rsiHandle=INVALID_HANDLE;
datetime g_lastH1=0,g_lastCloseAttempt=0;
bool g_running=false;
string g_statePrefix="";
ulong g_recoveredIds[];

datetime ServerToUTC(const datetime server) {
   datetime utc=0;
   if(!NPProfileToUtc(server,InpBrokerClockMode,InpServerUTCOffsetWinterHours*3600,
      InpServerUTCOffsetSummerHours*3600,utc))return 0;
   return utc;
}
double TickRound(const double price) {
   double size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(size<=0)return 0;
   return NormalizeDouble(MathRound(price/size)*size,_Digits);
}

#include "MomentumReport.mqh"

bool WeekendFlatWindow(const datetime server) {
   if(!InpWeekendFlat)return false;
   MqlDateTime clock;
   if(server<=0||!TimeToStruct(server,clock))return true; // no new entries with an unknown clock
   return clock.day_of_week==0||clock.day_of_week==6||
      (clock.day_of_week==5&&clock.hour*60+clock.min>=InpFridayFlatHour*60+InpFridayFlatMinute);
}
bool WeekendExitDue(const datetime server,const datetime opened) {
   if(!InpWeekendFlat)return false;
   if(WeekendFlatWindow(server))return true;
   MqlDateTime clock;
   if(!TimeToStruct(server,clock))return true;
   // If Friday's close could not execute, still flatten the carried position
   // on the next available quote, even after a Monday restart.
   datetime cutoff=server-clock.hour*3600-clock.min*60-clock.sec-
      ((clock.day_of_week+2)%7)*86400+InpFridayFlatHour*3600+InpFridayFlatMinute*60;
   if(cutoff>server)cutoff-=7*86400;
   return opened<=cutoff;
}

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
   return false;
}
bool ClosePosition(const ulong ticket,const long kind,const double volume,const string reason) {
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick)||tick.bid<=0||tick.ask<=0)return false;
   MqlTradeRequest req={};MqlTradeResult res={};
   req.action=TRADE_ACTION_DEAL;req.symbol=_Symbol;req.position=ticket;req.magic=InpMagic;
   req.volume=volume;req.type=kind==POSITION_TYPE_BUY?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
   req.price=kind==POSITION_TYPE_BUY?tick.bid:tick.ask;req.deviation=InpDeviationBrokerPoints;
   req.type_filling=FillPolicy();req.comment="E2 BTCMP exit";
   if(!StateWrite("EXIT_PENDING",(double)ticket))return false;
   bool sent=OrderSend(req,res);
   RSignal(TimeCurrent(),"EXIT_REQUEST",reason+" ticket="+StringFormat("%I64u",ticket)+" retcode="+IntegerToString(res.retcode));
   if(res.retcode!=TRADE_RETCODE_TIMEOUT&&res.retcode!=TRADE_RETCODE_PLACED&&res.retcode!=TRADE_RETCODE_CONNECTION)
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
      string reason=sl<=0||tp<=0?"MISSING_PROTECTION":
         (WeekendExitDue(TimeCurrent(),opened)?"WEEKEND_FLAT":
         (InpMaxHoldingHours>0&&TimeCurrent()-opened>=InpMaxHoldingHours*3600?"MAX_HOURS":""));
      if(reason==""||GlobalVariableGet(g_statePrefix+"EXIT_PENDING")>0)continue;
      g_lastCloseAttempt=TimeCurrent();
      ClosePosition(ticket,kind,PositionGetDouble(POSITION_VOLUME),reason);
   }
}
double SizeForStop(const ENUM_ORDER_TYPE side,const double entry,const double stop) {
   double budget=InpRiskMode==E2_RISK_FIXED_CASH?InpFixedCashRisk:AccountInfoDouble(ACCOUNT_BALANCE)*InpBalanceRiskPercent/100;
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double loss=0,margin=0;
   if(!MathIsValidNumber(budget)||budget<=0||!MathIsValidNumber(minimum)||minimum<=0||
      !MathIsValidNumber(maximum)||maximum<minimum||!MathIsValidNumber(step)||step<=0||
      !OrderCalcProfit(side,_Symbol,1,entry,stop,loss)||!MathIsValidNumber(loss)||loss>=0) {
      RSignal(TimeCurrent(),"RISK_SIZE_BLOCK","INVALID_SPEC_OR_PROFIT_CALC");return 0;
   }
   double requested=budget/(-loss);
   double volume=NormalizeDouble(E2BVolumeFloor(requested,step,minimum,maximum),8);
   double estimated=-loss*volume;
   // Lot limits and insufficient margin must not silently change the requested risk.
   if(volume<=0||volume<minimum||volume>maximum||
      !E2BRiskFits(estimated,budget,InpRiskTolerancePercent)) {
      RSignal(TimeCurrent(),"RISK_SIZE_BLOCK",StringFormat(
         "LOT_LIMIT_OR_STEP intended=%.8f required_lots=%.8f permitted_lots=%.8f estimated_risk=%.8f min=%.8f max=%.8f step=%.8f",
         budget,requested,volume,estimated,minimum,maximum,step));return 0;
   }
   double actual_loss=0;
   if(!OrderCalcProfit(side,_Symbol,volume,entry,stop,actual_loss)||
      !E2BRiskFits(-actual_loss,budget,InpRiskTolerancePercent)) {
      RSignal(TimeCurrent(),"RISK_SIZE_BLOCK",StringFormat(
         "ACTUAL_RISK_MISMATCH intended=%.8f calculated=%.8f lots=%.8f",budget,-actual_loss,volume));return 0;
   }
   if(!OrderCalcMargin(side,_Symbol,volume,entry,margin)||!MathIsValidNumber(margin)||margin<0||
      !MathIsValidNumber(AccountInfoDouble(ACCOUNT_MARGIN_FREE))||
      AccountInfoDouble(ACCOUNT_MARGIN_FREE)<margin*(1+InpMarginBuffer)) {
      RSignal(TimeCurrent(),"RISK_SIZE_BLOCK",StringFormat(
         "INSUFFICIENT_MARGIN intended=%.8f lots=%.8f margin=%.8f free_margin=%.8f buffer=%.8f",
         budget,volume,margin,AccountInfoDouble(ACCOUNT_MARGIN_FREE),InpMarginBuffer));return 0;
   }
   RSignal(TimeCurrent(),"RISK_SIZE",StringFormat("intended=%.8f calculated=%.8f lots=%.8f",budget,-actual_loss,volume));
   return volume;
}
// Reconstruct the active zone from completed native H4 RSI values. Broker H4
// alignment is explicit; CSV clocks do not transform bars into Binance UTC bars.
bool ActiveZone(const datetime signal_time,datetime &zone_start,double &rsi_value) {
   zone_start=0;rsi_value=0;
   int available=BarsCalculated(g_rsiHandle);
   if(available<InpRSIPeriod+3)return false;
   int count=(int)MathMin(1024,available-InpRSIPeriod-1);
   double values[];datetime times[];
   ArraySetAsSeries(values,false);ArraySetAsSeries(times,false);
   if(CopyBuffer(g_rsiHandle,0,1,count,values)!=count||CopyTime(_Symbol,PERIOD_H4,1,count,times)!=count)return false;
   // Match independently requested indicator/time arrays and refuse stale history.
   if(times[count-1]!=iTime(_Symbol,PERIOD_H4,1)||times[count-1]+14400>signal_time||
      signal_time-times[count-1]-14400>=14400)return false;
   rsi_value=values[count-1];
   int first=E2BZoneFirst(values,count,InpRSIThreshold);
   if(first==-2)return false; // invalid data or truncated active zone
   if(first>=0)zone_start=times[first]+14400; // first H4 signal is known at its CLOSE
   return true;
}
// History, not local counters, is authoritative after restarts and partial fills.
bool ZoneUsage(const datetime zone_start,int &entries,datetime &last_exit) {
   entries=0;last_exit=0;
   if(!HistorySelect(zone_start,TimeCurrent()+1))return false;
   ulong ids[];
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong d=HistoryDealGetTicket(i);
      if(d==0||HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol||
         (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic||
         HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
      ulong id=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);bool seen=false;
      for(int j=0;j<ArraySize(ids);j++)if(ids[j]==id){seen=true;break;}
      if(!seen){int n=ArraySize(ids);ArrayResize(ids,n+1);ids[n]=id;}
   }
   entries=ArraySize(ids);
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong d=HistoryDealGetTicket(i);if(d==0)continue;
      long edge=HistoryDealGetInteger(d,DEAL_ENTRY);
      if(edge!=DEAL_ENTRY_OUT&&edge!=DEAL_ENTRY_OUT_BY)continue;
      ulong id=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      for(int j=0;j<ArraySize(ids);j++)if(ids[j]==id) {
         datetime t=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
         if(t>last_exit)last_exit=t;break;
      }
   }
   return true;
}
bool DailyEntryAllowed() {
   if(!InpOneTradePerDay)return true;
   datetime now=TimeCurrent(),utc=ServerToUTC(now);
   if(!InpBrokerClockVerified||utc<=0||!HistorySelect(now-2*86400,now+1)) {
      RSignal(now,"DAILY_TRADE_BLOCK","CLOCK_OR_HISTORY_UNAVAILABLE");return false;
   }
   datetime today=utc-utc%86400;
   // Scan a server-time window wide enough to cover UTC midnight and DST shifts.
   // Broker fills survive restarts; partial fills count as the same daily entry.
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0||HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol||
         (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic)continue;
      long edge=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(edge!=DEAL_ENTRY_IN&&edge!=DEAL_ENTRY_INOUT)continue;
      datetime filled=ServerToUTC((datetime)HistoryDealGetInteger(deal,DEAL_TIME));
      if(filled<=0) {RSignal(now,"DAILY_TRADE_BLOCK","ENTRY_CLOCK_UNAVAILABLE");return false;}
      if(filled>=today&&filled<today+86400) {
         RSignal(now,"DAILY_TRADE_BLOCK","FILLED_ENTRY_EXISTS utc_day="+RStamp(today));return false;
      }
   }
   return true;
}
void AttemptEntry(const MqlTick &tick,const datetime zone_start,const string entry_type) {
   if(WeekendFlatWindow(TimeCurrent()))return;
   if(!MathIsValidNumber(tick.bid)||!MathIsValidNumber(tick.ask)||tick.bid<=0||tick.ask<tick.bid)return;
   if(SymbolOccupied()||SubmissionBlocked())return;
   if(!DailyEntryAllowed())return;
   int entries=0;datetime last_exit=0;
   if(!ZoneUsage(zone_start,entries,last_exit)||entries>=InpMaxEntriesPerZone||
      (last_exit>0&&TimeCurrent()-last_exit<InpCooldownHours*3600))return;
   if(tick.time<=0||TimeCurrent()-tick.time<0||TimeCurrent()-tick.time>InpMaxQuoteAgeSeconds)return;
   if(InpMaxSpreadPercent>0&&100*(tick.ask-tick.bid)/tick.bid>InpMaxSpreadPercent)return;
   double entry=tick.ask;
   double stop=TickRound(entry*(1-InpStopPercent/100));
   // Use the rounded stop distance so the submitted price bracket is exactly 1R.
   double target=TickRound(entry+(entry-stop));
   double stops=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(stop<=0||stop>=tick.bid||target<=entry||tick.bid-stop<stops||target-tick.bid<stops)return;
   double volume=SizeForStop(ORDER_TYPE_BUY,entry,stop);if(volume<=0)return;
   MqlTradeRequest req={};MqlTradeResult res={};MqlTradeCheckResult check={};
   req.action=TRADE_ACTION_DEAL;req.symbol=_Symbol;req.magic=InpMagic;req.type=ORDER_TYPE_BUY;
   req.volume=volume;req.price=entry;req.sl=stop;req.tp=target;
   req.deviation=InpDeviationBrokerPoints;req.type_filling=FillPolicy();req.comment="E2 BTCMP research";
   if(!OrderCheck(req,check)||(check.retcode!=0&&check.retcode!=TRADE_RETCODE_DONE)) {
      RSignal(TimeCurrent(),"ORDER_CHECK_BLOCK",check.comment);return;
   }
   if(!E2PGCanEnter()) {RSignal(TimeCurrent(),"PORTFOLIO_GUARD_BLOCK","Guard missing or daily lock");return;}
   if(!GlobalVariableSetOnCondition(g_statePrefix+"PENDING",1,0))return;
   GlobalVariablesFlush();
   datetime last=(datetime)GlobalVariableGet(g_statePrefix+"SUBMITTED");
   if(last>0&&TimeCurrent()-last<5){StateWrite("PENDING",0);return;}
   if(!StateWrite("SUBMITTED",(double)TimeCurrent()))return;
   bool sent=OrderSend(req,res);
   bool accepted=sent&&(res.retcode==TRADE_RETCODE_DONE||res.retcode==TRADE_RETCODE_DONE_PARTIAL);
   bool unknown=res.retcode==TRADE_RETCODE_TIMEOUT||res.retcode==TRADE_RETCODE_PLACED||res.retcode==TRADE_RETCODE_CONNECTION;
   if(accepted)StateWrite("PENDING",0);
   else if(!unknown){StateWrite("PENDING",0);StateWrite("SUBMITTED",0);}
   RSignal(TimeCurrent(),"ENTRY_REQUEST",StringFormat("type=%s zone=%s volume=%.8f price=%.8f sl=%.8f tp=%.8f retcode=%u",
      entry_type,RStamp(ServerToUTC(zone_start)),volume,entry,stop,target,res.retcode));
}
void ProcessEntry(const MqlTick &tick) {
   datetime current=iTime(_Symbol,PERIOD_H1,0);
   if(current<=0)return;
   if(WeekendFlatWindow(TimeCurrent())){g_lastH1=current;return;}
   if(g_lastH1==0){g_lastH1=current;return;} // no replay on attach/restart
   if(current==g_lastH1)return;
   if(current<g_lastH1){g_lastH1=current;return;}
   if(TimeCurrent()<current)return;
   if(TimeCurrent()-current>InpEntryGraceSeconds){g_lastH1=current;return;}
   if(!InpBrokerClockVerified||ServerToUTC(TimeCurrent())<=0)return;
   datetime zone_start=0;double rsi=0;
   if(!ActiveZone(current,zone_start,rsi))return; // retry missing history within grace
   if(zone_start==0){g_lastH1=current;RSignal(TimeCurrent(),"REGIME_OFF",RNumber(rsi));return;}
   MqlRates bars[];ArraySetAsSeries(bars,false);
   int count=CopyRates(_Symbol,PERIOD_H1,zone_start-3600,current-1,bars);
   if(count<=0||bars[count-1].time+3600!=current)return;
   double zone_high=0,previous_high=0;
   for(int i=0;i<count;i++) {
      if(!E2BValidOHLC(bars[i].low,bars[i].high,bars[i].close)||
         bars[i].time<zone_start-3600||bars[i].time>=current)return;
      zone_high=MathMax(zone_high,bars[i].close);
      if(i<count-1&&i>=count-1-InpBreakoutLookback)previous_high=MathMax(previous_high,bars[i].high);
   }
   int entries=0;datetime last_exit=0;
   if(!ZoneUsage(zone_start,entries,last_exit))return;
   // The completed signal is consumed even if the order's gates block it.
   double prior=GlobalVariableGet(g_statePrefix+"SIGNAL");
   if(prior>=(double)current){g_lastH1=current;return;}
   if(!GlobalVariableSetOnCondition(g_statePrefix+"SIGNAL",(double)current,prior))return;
   GlobalVariablesFlush();g_lastH1=current;
   int kind=E2BEntryKind(bars[count-1].close,zone_high,previous_high,
      InpPullbackPercent/100,InpBreakoutPercent/100,(int)InpEntryMode,
      InpBaseEntry&&current==zone_start&&entries==0);
   RSignal(TimeCurrent(),"H1_SIGNAL",StringFormat("rsi=%.6f zone=%s entries=%d close=%.8f zone_high=%.8f prior_high=%.8f kind=%d",
      rsi,RStamp(ServerToUTC(zone_start)),entries,bars[count-1].close,zone_high,previous_high,kind));
   if(kind>0)AttemptEntry(tick,zone_start,kind==1?"BASE":(kind==2?"PULLBACK":"BREAKOUT"));
}
void Run(const bool allow_entries) {
   if(g_running)return;g_running=true;
   // SL/TP and optional exits operate independently of entry history/clock/guard.
   ManageExits();
   MqlTick tick;
   if(allow_entries&&SymbolInfoTick(_Symbol,tick)&&MathIsValidNumber(tick.bid)&&
      MathIsValidNumber(tick.ask)&&tick.bid>0&&tick.ask>=tick.bid)ProcessEntry(tick);
   REquity(TimeCurrent());g_running=false;
}
bool ValidInputs() {
   return InpMagic>0&&(int)InpRiskMode>=0&&(int)InpRiskMode<=1&&
      InpRSIPeriod>=2&&InpRSIPeriod<=256&&MathIsValidNumber(InpRSIThreshold)&&InpRSIThreshold>0&&InpRSIThreshold<100&&
      (int)InpEntryMode>=0&&(int)InpEntryMode<=2&&
      MathIsValidNumber(InpPullbackPercent)&&InpPullbackPercent>0&&InpPullbackPercent<100&&
      MathIsValidNumber(InpBreakoutPercent)&&InpBreakoutPercent>0&&InpBreakoutPercent<100&&
      InpBreakoutLookback>=1&&InpBreakoutLookback<=256&&InpMaxEntriesPerZone>=1&&InpMaxEntriesPerZone<=100&&
      InpCooldownHours>=0&&InpCooldownHours<=720&&InpEntryGraceSeconds>=0&&InpEntryGraceSeconds<=300&&
      MathIsValidNumber(InpStopPercent)&&InpStopPercent>0&&InpStopPercent<100&&
      InpMaxHoldingHours>=0&&InpMaxHoldingHours<=8760&&
      InpFridayFlatHour>=0&&InpFridayFlatHour<=23&&InpFridayFlatMinute>=0&&InpFridayFlatMinute<=59&&
      MathIsValidNumber(InpFixedCashRisk)&&InpFixedCashRisk>0&&
      MathIsValidNumber(InpBalanceRiskPercent)&&InpBalanceRiskPercent>0&&InpBalanceRiskPercent<=100&&
      MathIsValidNumber(InpRiskTolerancePercent)&&InpRiskTolerancePercent>=0&&InpRiskTolerancePercent<=10&&
      MathIsValidNumber(InpMaxSpreadPercent)&&InpMaxSpreadPercent>=0&&InpMaxSpreadPercent<100&&
      InpDeviationBrokerPoints>=0&&InpMaxQuoteAgeSeconds>=1&&InpMaxQuoteAgeSeconds<=300&&
      MathIsValidNumber(InpMarginBuffer)&&InpMarginBuffer>=0&&
      (int)InpBrokerClockMode>=0&&(int)InpBrokerClockMode<=3&&
      InpServerUTCOffsetWinterHours>=-12&&InpServerUTCOffsetWinterHours<=14&&
      InpServerUTCOffsetSummerHours>=-12&&InpServerUTCOffsetSummerHours<=14&&
      (!InpBrokerClockVerified||InpBrokerClockMode!=NP_CLOCK_UNSET);
}
int OnInit() {
   if(!ValidInputs())return INIT_PARAMETERS_INCORRECT;
   // Symbol suffixes are supported; prevent accidental attachment to a different currency pair.
   if(SymbolInfoString(_Symbol,SYMBOL_CURRENCY_BASE)!="BTC"||SymbolInfoString(_Symbol,SYMBOL_CURRENCY_PROFIT)!="USD") {
      Print("[BTCMP] This research EA requires a BTCUSD symbol.");return INIT_PARAMETERS_INCORRECT;
   }
   g_statePrefix="E2B_"+StringFormat("%08X",RHash(AccountInfoString(ACCOUNT_SERVER)+"|"+_Symbol+"|"+StringFormat("%I64u",InpMagic)))+
      "_"+StringFormat("%I64d",AccountInfoInteger(ACCOUNT_LOGIN))+"_";
   if(MQLInfoInteger(MQL_TESTER))g_statePrefix="E2BT_"+StringFormat("%I64u",GetMicrosecondCount())+"_";
   string fields[]={"SUBMITTED","PENDING","EXIT_PENDING","SIGNAL"};
   for(int i=0;i<ArraySize(fields);i++)if(!GlobalVariableCheck(g_statePrefix+fields[i])&&!StateWrite(fields[i],0))return INIT_FAILED;
   // Remember pre-existing positions so their eventual exits appear in this run's trade CSV.
   for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&
      (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic) {
      int n=ArraySize(g_recoveredIds);ArrayResize(g_recoveredIds,n+1);
      g_recoveredIds[n]=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   }
   g_rsiHandle=iRSI(_Symbol,PERIOD_H4,InpRSIPeriod,PRICE_CLOSE);
   if(g_rsiHandle==INVALID_HANDLE)return INIT_FAILED;
   g_lastH1=iTime(_Symbol,PERIOD_H1,0);
   if(!ROpenReports()){RCloseReports();IndicatorRelease(g_rsiHandle);return INIT_FAILED;}
   string specification=StringFormat(
      "contract=%.8f min=%.8f max=%.8f step=%.8f tick_size=%.8f margin_free=%.8f cash_risk=%.8f tolerance_pct=%.8f",
      SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),
      SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),AccountInfoDouble(ACCOUNT_MARGIN_FREE),
      InpFixedCashRisk,InpRiskTolerancePercent);
   RSignal(TimeCurrent(),"SYMBOL_SPEC",specification);
   Print("[BTCMP] Symbol specification: ",specification);
   if(!EventSetTimer(5)){RCloseReports();IndicatorRelease(g_rsiHandle);return INIT_FAILED;}
   Print("[BTCMP] Research adaptation: completed broker H4 Wilder RSI, H1 entries, hard stop / fixed 1R. Published performance is not replicated.");
   if(!InpBrokerClockVerified)Print("[BTCMP] New entries disabled until broker clock is verified.");
   if(GlobalVariableGet(g_statePrefix+"PENDING")>0||GlobalVariableGet(g_statePrefix+"EXIT_PENDING")>0)
      Print("[BTCMP] Recovered unresolved order submission: reconcile broker history before clearing state.");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){EventKillTimer();RCloseReports();if(g_rsiHandle!=INVALID_HANDLE)IndicatorRelease(g_rsiHandle);}
void OnTick(){Run(true);}
void OnTimer(){Run(false);}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result) {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD||trans.deal==0||!HistoryDealSelect(trans.deal)||
      HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol)return;
   RExportTrades(); // includes manual/guard exits by position identifier, even with a different deal magic
}
