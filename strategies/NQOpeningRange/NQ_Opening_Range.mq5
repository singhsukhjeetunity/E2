#property strict
#include "..\\shared\\PortfolioGate.mqh"
#property version "0.10"
#property description "E2 research EA: NQ 90-minute opening-range long breakout. NOT live validated."

// Independent research EA. Never attach alongside a second copy using the same magic.
const double InpStopIndexPoints=100.0,InpTargetIndexPoints=200.0;
const int InpMaxEntriesPerNYDay=2,InpMaxLongSessions=5;
const int InpRangeStartNYMinute=570,InpRangeEndNYMinute=660;
const int InpLastEntryNYMinute=925,InpSessionCloseNYMinute=930;
const int NQRangeATRDays=14;
const double InpMarginBuffer=0.15;
const ulong InpMagic=420605;
const int InpDeviationBrokerPoints=50;
const bool InpVerbose=false;
input group "=== E2 NASDAQ OPENING RANGE ==="
const bool InpEnableEntries=true; // No redundant user-facing entry switch; verified clock still required
input bool InpExportCsv=true;            // Export journal CSV reports
input group "=== RISK MANAGEMENT ==="
enum E2RiskMode { E2_RISK_FIXED_CASH=0,E2_RISK_BALANCE_PERCENT=1 }; 
input E2RiskMode InpRiskMode=E2_RISK_FIXED_CASH; // Same risk-mode UI as Gold
input double InpFixedCashRisk=1000.0;
input double InpBalanceRiskPercent=1.0;
input group "=== STRATEGY FILTERS ==="
input bool InpUseRangeWidthFilter=true;       // Require opening range / prior D1 ATR within bounds
input double InpMinRangeATR=0.25;           // Minimum range as a fraction of 14-day ATR
input double InpMaxRangeATR=1.50;           // Maximum range as a fraction of 14-day ATR
input bool InpRequireClosedM5Breakout=true; // Previous completed M5 close must exceed range high
input group "=== EXECUTION SAFETY ==="
input double InpMaxSpreadIndexPoints=10.0; // 0=disabled
input group "=== BROKER CLOCK PROFILE ==="
input bool InpBrokerClockVerified=false;
input int InpServerUTCOffsetWinterHours=0;
input int InpServerUTCOffsetSummerHours=0;
input int InpBrokerDST=0;               // 0=none, 1=EU, 2=US; use historical broker rules

int g_day=0;
double g_rangeHigh=0,g_rangeLow=0;
bool g_rangeReady=false;
bool g_rangeAllowed=false;
double g_rangeAtr=0,g_rangeAtrRatio=0;
datetime g_lastAttemptBar=0;
datetime g_lastBlockedBar=0;
datetime g_lastLog=0;
bool g_ambiguousEntry=false;
bool g_ambiguousExit=false;

// Calendar operations use naive UTC or New York civil-time values; no terminal-local clock.
datetime DayStart(const datetime t) { MqlDateTime x; TimeToStruct(t,x); x.hour=0;x.min=0;x.sec=0;return StructToTime(x); }
int DayKey(const datetime t) { MqlDateTime x; TimeToStruct(t,x); return x.year*10000+x.mon*100+x.day; }
int MinuteOfDay(const datetime t) { MqlDateTime x; TimeToStruct(t,x); return x.hour*60+x.min; }
int NthSunday(const int year,const int month,const int n) {
   MqlDateTime d={};d.year=year;d.mon=month;d.day=1;
   datetime first=StructToTime(d);TimeToStruct(first,d);
   return 1+(7-d.day_of_week)%7+7*(n-1);
}
int LastSunday(const int year,const int month) {
   MqlDateTime d={};d.year=year;d.mon=month+1;d.day=1;
   if(d.mon==13){d.mon=1;d.year++;}
   datetime last=StructToTime(d)-86400;TimeToStruct(last,d);
   return d.day-d.day_of_week;
}
datetime USStartUTC(const int y) {
   MqlDateTime d={};d.year=y;d.mon=3;d.day=NthSunday(y,3,2);d.hour=7;
   return StructToTime(d); // 02:00 New York standard = 07:00 UTC
}
datetime USEndUTC(const int y) {
   MqlDateTime d={};d.year=y;d.mon=11;d.day=NthSunday(y,11,1);d.hour=6;
   return StructToTime(d); // 02:00 New York daylight = 06:00 UTC
}
bool IsUSDST(const datetime utc) {
   MqlDateTime d;TimeToStruct(utc,d);
   if(d.year<2007) { // US rules 1987-2006: first Sunday Apr, last Sunday Oct
      if(d.year<1987)return false; // pre-1987 research requires explicit calendar extension
      MqlDateTime a={};a.year=d.year;a.mon=4;a.day=NthSunday(d.year,4,1);a.hour=7;
      MqlDateTime b={};b.year=d.year;b.mon=10;b.day=LastSunday(d.year,10);b.hour=6;
      return utc>=StructToTime(a)&&utc<StructToTime(b);
   }
   return utc>=USStartUTC(d.year)&&utc<USEndUTC(d.year);
}
bool IsEUDST(const datetime utc) {
   MqlDateTime d;TimeToStruct(utc,d);
   MqlDateTime a={};a.year=d.year;a.mon=3;a.day=LastSunday(d.year,3);a.hour=1;
   MqlDateTime b={};b.year=d.year;b.mon=10;b.day=LastSunday(d.year,10);b.hour=1;
   return utc>=StructToTime(a)&&utc<StructToTime(b);
}
int ServerOffsetHours(const datetime utc) {
   bool summer=(InpBrokerDST==1?IsEUDST(utc):(InpBrokerDST==2?IsUSDST(utc):false));
   return summer?InpServerUTCOffsetSummerHours:InpServerUTCOffsetWinterHours;
}
datetime ServerToUTC(const datetime server) {
   // Iterate around DST boundary; ambiguous repeated broker hour remains a limitation.
   datetime guess=server-InpServerUTCOffsetWinterHours*3600;
   for(int i=0;i<3;i++)guess=server-ServerOffsetHours(guess)*3600;
   return guess;
}
datetime UTCToNY(const datetime utc) { return utc+(IsUSDST(utc)?-4:-5)*3600; }
datetime ServerToNY(const datetime server) {return UTCToNY(ServerToUTC(server));}
bool IsNYWeekday(const datetime ny) {MqlDateTime x;TimeToStruct(ny,x);return x.day_of_week>=1&&x.day_of_week<=5;}
double TickRound(const double price) {
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0)tick=_Point;
   return NormalizeDouble(MathRound(price/tick)*tick,_Digits);
}
#include "NQReport.mqh"
bool OwnPosition(ulong &ticket,long &kind,double &volume,datetime &opened) {
   ticket=0;kind=-1;volume=0;opened=0;
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong t=PositionGetTicket(i);
      if(t==0||PositionGetString(POSITION_SYMBOL)!=_Symbol)continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic)continue;
      ticket=t;kind=PositionGetInteger(POSITION_TYPE);
      volume=PositionGetDouble(POSITION_VOLUME);
      opened=(datetime)PositionGetInteger(POSITION_TIME);
      return true;
   }
   return false;
}
bool SymbolOccupied() {
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong t=PositionGetTicket(i);
      if(t!=0&&PositionGetString(POSITION_SYMBOL)==_Symbol)return true;
   }
   for(int i=OrdersTotal()-1;i>=0;i--) {
      ulong t=OrderGetTicket(i);
      if(t!=0&&OrderGetString(ORDER_SYMBOL)==_Symbol)return true;
   }
   return false;
}
int TodayEntryCount(const int nyKey) {
   // Unique position IDs prevent partial fills counting as separate entries.
   if(!HistorySelect(TimeCurrent()-10*86400,TimeCurrent()+60))return -1;
   ulong ids[];int count=0;
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0||HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol)continue;
      if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic)continue;
      long e=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_IN&&e!=DEAL_ENTRY_INOUT)continue;
      if(DayKey(ServerToNY((datetime)HistoryDealGetInteger(deal,DEAL_TIME)))!=nyKey)continue;
      ulong id=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      bool seen=false;
      for(int j=0;j<count;j++)if(ids[j]==id){seen=true;break;}
      if(!seen){ArrayResize(ids,count+1);ids[count++]=id;}
   }
   return count;
}
bool BuildRange(const int nyKey) {
   MqlRates bars[];
   ArraySetAsSeries(bars,true);
   int n=CopyRates(_Symbol,PERIOD_M5,0,320,bars);
   if(n<=0)return false;
   bool found[18];for(int j=0;j<18;j++)found[j]=false;
   int count=0;double hi=-DBL_MAX,lo=DBL_MAX;
   for(int i=0;i<n;i++) {
      datetime ny=ServerToNY(bars[i].time);
      if(DayKey(ny)!=nyKey)continue;
      int minute=MinuteOfDay(ny);
      if(minute<InpRangeStartNYMinute||minute>=InpRangeEndNYMinute)continue;
      if((minute-InpRangeStartNYMinute)%5!=0)continue;
      int slot=(minute-InpRangeStartNYMinute)/5;
      if(slot<0||slot>=18||found[slot])continue;
      found[slot]=true;count++;
      hi=MathMax(hi,bars[i].high);lo=MathMin(lo,bars[i].low);
   }
   if(count!=18||hi<=lo)return false;
   g_rangeHigh=TickRound(hi);g_rangeLow=TickRound(lo);
   if(g_rangeHigh<=g_rangeLow)return false;
   g_rangeAllowed=true;g_rangeAtr=0;g_rangeAtrRatio=0;
   if(InpUseRangeWidthFilter) {
      // CopyRates returns oldest-to-newest in physical array order. Shift 1 excludes today's forming D1 bar.
      MqlRates daily[];
      if(CopyRates(_Symbol,PERIOD_D1,1,NQRangeATRDays+1,daily)!=NQRangeATRDays+1)return false;
      double total=0;
      for(int i=1;i<=NQRangeATRDays;i++) {
         double previous=daily[i-1].close;
         double tr=MathMax(daily[i].high-daily[i].low,
            MathMax(MathAbs(daily[i].high-previous),MathAbs(daily[i].low-previous)));
         if(tr<=0)return false;
         total+=tr;
      }
      g_rangeAtr=total/NQRangeATRDays;
      if(g_rangeAtr<=0)return false;
      g_rangeAtrRatio=(g_rangeHigh-g_rangeLow)/g_rangeAtr;
      g_rangeAllowed=g_rangeAtrRatio>=InpMinRangeATR&&g_rangeAtrRatio<=InpMaxRangeATR;
   }
   return true;
}
bool CompletedM5Breakout(const datetime currentBar,double &closedPrice) {
   closedPrice=0;
   MqlRates previous[];
   if(CopyRates(_Symbol,PERIOD_M5,1,1,previous)!=1)return false;
   datetime ny=ServerToNY(previous[0].time);
   if(previous[0].time+300!=currentBar||DayKey(ny)!=g_day||
      MinuteOfDay(ny)<InpRangeEndNYMinute)return false;
   closedPrice=previous[0].close;
   return closedPrice>g_rangeHigh;
}
int WeekdaySessions(const datetime startNY,const datetime nowNY) {
   datetime d=DayStart(startNY),end=DayStart(nowNY);
   if(end<d)return 0;
   int sessions=0;
   for(int i=0;i<45&&d<=end;i++,d+=86400)if(IsNYWeekday(d))sessions++;
   return sessions;
}
ENUM_ORDER_TYPE_FILLING FillPolicy() {
   long mode=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((mode&SYMBOL_FILLING_IOC)!=0)return ORDER_FILLING_IOC;
   if((mode&SYMBOL_FILLING_FOK)!=0)return ORDER_FILLING_FOK;
   return ORDER_FILLING_RETURN;
}
bool SendClose(const ulong ticket,const long kind,const double volume) {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)||tick.bid<=0||tick.ask<=0)return false;
   MqlTradeRequest req={};MqlTradeResult res={};
   req.action=TRADE_ACTION_DEAL;req.symbol=_Symbol;req.position=ticket;
   req.magic=InpMagic;req.volume=volume;
   req.type=(kind==POSITION_TYPE_BUY?ORDER_TYPE_SELL:ORDER_TYPE_BUY);
   req.price=(kind==POSITION_TYPE_BUY?tick.bid:tick.ask);
   req.deviation=InpDeviationBrokerPoints;req.type_filling=FillPolicy();
   ResetLastError();
   bool sent=OrderSend(req,res);
   NQSignal(TimeCurrent(),"EXIT_REQUEST",StringFormat("ticket=%I64u volume=%.8f retcode=%u",ticket,volume,res.retcode));
   if(InpVerbose||!sent||res.retcode!=TRADE_RETCODE_DONE)
      PrintFormat("[NQORB] close ticket=%I64u sent=%d retcode=%u error=%d",ticket,(int)sent,res.retcode,GetLastError());
   if(sent&&(res.retcode==TRADE_RETCODE_DONE||res.retcode==TRADE_RETCODE_DONE_PARTIAL))return true;
   if(res.retcode==TRADE_RETCODE_TIMEOUT||(sent&&res.retcode==TRADE_RETCODE_PLACED))g_ambiguousExit=true;
   return false;
}
void ManageExits(const datetime ny) {
   ulong ticket;long kind;double volume;datetime opened;
   if(!OwnPosition(ticket,kind,volume,opened)) {g_ambiguousExit=false;return;}
   if(g_ambiguousExit)return; // do not duplicate an unconfirmed close
   datetime entryNY=ServerToNY(opened);
   bool pastDay=DayKey(ny)>DayKey(entryNY);
   int sessions=WeekdaySessions(entryNY,ny);
   // Recover a missed session-close exit immediately on the next tradable tick.
   if(kind==POSITION_TYPE_SELL) {
      if(pastDay||MinuteOfDay(ny)>=InpSessionCloseNYMinute)SendClose(ticket,kind,volume);
   } else if(sessions>InpMaxLongSessions||
             (sessions==InpMaxLongSessions&&MinuteOfDay(ny)>=InpSessionCloseNYMinute))
      SendClose(ticket,kind,volume);
}
double SizeForStop(const ENUM_ORDER_TYPE side,const double entry,const double stop) {
   double budget=(InpRiskMode==0?InpFixedCashRisk:AccountInfoDouble(ACCOUNT_BALANCE)*InpBalanceRiskPercent/100.0);
   if(budget<=0)return 0;
   double loss=0;
   if(!OrderCalcProfit(side,_Symbol,1.0,entry,stop,loss)||loss>=0) {
      Print("[NQORB] risk sizing blocked: invalid OrderCalcProfit");
      return 0;
   }
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minvol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxvol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(step<=0||minvol<=0||maxvol<minvol)return 0;
   double raw=MathMin(maxvol,budget/(-loss));
   double margin=0;
   if(!OrderCalcMargin(side,_Symbol,1.0,entry,margin)||margin<=0)return 0;
   raw=MathMin(raw,AccountInfoDouble(ACCOUNT_MARGIN_FREE)/(margin*(1.0+InpMarginBuffer)));
   double vol=MathFloor((raw+1e-9)/step)*step;
   vol=NormalizeDouble(vol,8);
   if(vol<minvol)return 0;
   return MathMin(vol,maxvol);
}
void AttemptEntry(const datetime ny) {
   if(!InpEnableEntries||!InpBrokerClockVerified||g_ambiguousEntry)return;
   int minute=MinuteOfDay(ny);
   if(!IsNYWeekday(ny)||minute<InpRangeEndNYMinute||minute>=InpLastEntryNYMinute)return;
   if(!g_rangeReady||!g_rangeAllowed)return;
   if(SymbolOccupied())return;
   int used=TodayEntryCount(g_day);
   if(used<0||used>=InpMaxEntriesPerNYDay)return;
   datetime bar=iTime(_Symbol,PERIOD_M5,0);
   if(bar==0||bar==g_lastAttemptBar)return; // at most one submission per bar
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)||tick.bid<=0||tick.ask<=0)return;
   if(InpMaxSpreadIndexPoints>0&&tick.ask-tick.bid>InpMaxSpreadIndexPoints)return;
   // Only an upside break can open a position. Market fills can differ from the range boundary.
   if(tick.ask<=g_rangeHigh)return;
   if(InpRequireClosedM5Breakout) {
      double closedPrice=0;
      if(!CompletedM5Breakout(bar,closedPrice)) {
         if(g_lastBlockedBar!=bar) {
            g_lastBlockedBar=bar;
            NQSignal(TimeCurrent(),"BREAKOUT_UNCONFIRMED",StringFormat("bar=%s previous_close=%.8f range_high=%.8f",
               TimeToString(bar,TIME_DATE|TIME_MINUTES),closedPrice,g_rangeHigh));
         }
         return;
      }
   }
   const ENUM_ORDER_TYPE side=ORDER_TYPE_BUY;
   double entry=tick.ask;
   double stop=TickRound(entry-InpStopIndexPoints);
   double target=TickRound(entry+InpTargetIndexPoints);
   double minStop=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(MathAbs(entry-stop)<minStop||MathAbs(entry-target)<minStop)return;
   double vol=SizeForStop(side,entry,stop);
   if(vol<=0)return;
   MqlTradeRequest req={};MqlTradeResult res={};
   req.action=TRADE_ACTION_DEAL;req.symbol=_Symbol;req.magic=InpMagic;
   req.type=side;req.volume=vol;req.price=entry;req.sl=stop;req.tp=target;
   req.deviation=InpDeviationBrokerPoints;req.type_filling=FillPolicy();
   req.comment="E2 NQ ORB research";
   if(!E2PGCanEnter()) {
      NQSignal(TimeCurrent(),"PORTFOLIO_GUARD_BLOCK","Guard missing or daily lock");
      return;
   }
   g_lastAttemptBar=bar;
   ResetLastError();
   bool sent=OrderSend(req,res);
   NQSignal(TimeCurrent(),"ENTRY_REQUEST",StringFormat("side=BUY volume=%.8f requested_price=%.8f sl=%.8f tp=%.8f retcode=%u",vol,entry,stop,target,res.retcode));
   PrintFormat("[NQORB] entry side=BUY vol=%.2f range=%.2f/%.2f SL=%.2f TP=%.2f sent=%d retcode=%u err=%d",
      vol,g_rangeLow,g_rangeHigh,stop,target,(int)sent,res.retcode,GetLastError());
   if(res.retcode==TRADE_RETCODE_TIMEOUT||(sent&&res.retcode==TRADE_RETCODE_PLACED))g_ambiguousEntry=true;
}
void Run() {
   datetime server=TimeCurrent();
   if(server<=0)return;
   datetime ny=ServerToNY(server);
   int key=DayKey(ny);
   if(key!=g_day) {
      g_day=key;g_rangeReady=false;g_rangeAllowed=false;g_rangeHigh=0;g_rangeLow=0;
      g_rangeAtr=0;g_rangeAtrRatio=0;g_lastAttemptBar=0;g_lastBlockedBar=0;
      g_ambiguousEntry=false;
   }
   // Timed exits also require a verified clock. Protective broker SL/TP remain active.
   if(InpBrokerClockVerified)ManageExits(ny);
   if(MinuteOfDay(ny)>=InpRangeEndNYMinute&&!g_rangeReady) {
      g_rangeReady=BuildRange(key);
      if(g_rangeReady)NQSignal(server,"RANGE_FILTER",StringFormat("allowed=%d width=%.8f prior_d1_atr=%.8f ratio=%.6f min=%.6f max=%.6f",
         (int)g_rangeAllowed,g_rangeHigh-g_rangeLow,g_rangeAtr,g_rangeAtrRatio,InpMinRangeATR,InpMaxRangeATR));
   }
   AttemptEntry(ny);
   if(InpVerbose&&server-g_lastLog>=300) {
      g_lastLog=server;
      PrintFormat("[NQORB] NY=%s range_ready=%d range=[%.2f,%.2f] entries=%d clock_verified=%d",
         TimeToString(ny,TIME_DATE|TIME_MINUTES),(int)g_rangeReady,g_rangeLow,g_rangeHigh,
         TodayEntryCount(key),(int)InpBrokerClockVerified);
   }
   NQEquity(server);
}
int OnInit() {
   if(_Period!=PERIOD_M5)Print("[NQORB] Attach to M5 for visual inspection; signal calculation uses M5 history regardless.");
   if(InpRangeStartNYMinute!=570||InpRangeEndNYMinute!=660||InpLastEntryNYMinute!=925||
      InpSessionCloseNYMinute!=930)Print("[NQORB] WARNING: changed published time windows.");
   if(InpRangeEndNYMinute-InpRangeStartNYMinute!=90||
      InpRangeStartNYMinute%5!=0||InpRangeEndNYMinute%5!=0||
      InpStopIndexPoints<=0||InpTargetIndexPoints<=0||
      InpMaxEntriesPerNYDay<1||InpMaxLongSessions<1||
      (int)InpRiskMode<0||(int)InpRiskMode>1||InpFixedCashRisk<=0||InpBalanceRiskPercent<=0||
      InpMinRangeATR<0||InpMaxRangeATR<=0||InpMaxRangeATR<InpMinRangeATR||
      InpBrokerDST<0||InpBrokerDST>2||InpMarginBuffer<0||
      InpServerUTCOffsetWinterHours< -12||InpServerUTCOffsetWinterHours>14||
      InpServerUTCOffsetSummerHours< -12||InpServerUTCOffsetSummerHours>14) return INIT_PARAMETERS_INCORRECT;
   if(InpEnableEntries&&!InpBrokerClockVerified) {
      Print("[NQORB] Entries disabled: verify broker clock and set InpBrokerClockVerified=true");
   }
   if(!NQOpenReports()){Print("[NQORB] CSV reporting initialization failed; entries blocked.");return INIT_FAILED;}
   EventSetTimer(30);
   Print("[NQORB] Research EA initialized. Entry switch=",InpEnableEntries,
         " broker clock verified=",InpBrokerClockVerified,
         ". Native MT5 compilation/backtest required.");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) {EventKillTimer();NQCloseReports();}
void OnTick() {Run();}
void OnTimer() {Run();}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result) {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD||trans.deal==0)return;
   if(!HistoryDealSelect(trans.deal))return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol)return;
   if((ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)==InpMagic)
      NQSignal((datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME),"DEAL_FILL",
         "deal="+StringFormat("%I64u",trans.deal)+" position="+StringFormat("%I64u",(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID))+
         " volume="+DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_VOLUME),8)+" price="+DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_PRICE),8));
   NQExportTrades();
}
