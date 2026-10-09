#property strict
#property version "0.10"
#property description "E2 research EA: NQ 90-minute cash-session opening-range breakout. NOT live validated."

// Independent research EA. Never attach alongside a second copy using the same magic.
input group "Research rules (Nasdaq index PRICE units)"
input double InpStopIndexPoints=100.0;
input double InpTargetIndexPoints=200.0;
input int InpMaxEntriesPerNYDay=2;
input int InpMaxLongSessions=5;
input int InpRangeStartNYMinute=570;     // 09:30 ET
input int InpRangeEndNYMinute=660;       // 11:00 ET, exclusive range end
input int InpLastEntryNYMinute=925;      // 15:25 ET; 15:30 is the exit
input int InpSessionCloseNYMinute=930;   // 15:30 ET
input group "Risk / execution"
input int InpRiskMode=0;                 // 0=fixed account cash, 1=balance percentage
input double InpFixedCashRisk=1000.0;
input double InpBalanceRiskPercent=1.0;
input double InpMaxSpreadIndexPoints=10.0; // 0=disabled
input double InpMarginBuffer=0.15;      // Require 15% extra free margin
input ulong InpMagic=420605;
input int InpDeviationBrokerPoints=50;
input bool InpEnableEntries=false;      // OFF until research tester configuration is verified
input group "Broker clock: required historical server -> UTC conversion"
input bool InpBrokerClockVerified=false;
input int InpServerUTCOffsetWinterHours=0;
input int InpServerUTCOffsetSummerHours=0;
input int InpBrokerDST=0;               // 0=none, 1=EU, 2=US; use historical broker rules
input group "Diagnostics"
input bool InpVerbose=false;

int g_day=0;
double g_rangeHigh=0,g_rangeLow=0;
bool g_rangeReady=false;
datetime g_lastAttemptBar=0;
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
   return g_rangeHigh>g_rangeLow;
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
   if(InpVerbose||!sent||res.retcode!=TRADE_RETCODE_DONE)
      PrintFormat("[NQORB] close ticket=%I64u sent=%d retcode=%u error=%d",ticket,(int)sent,res.retcode,GetLastError());
   if(sent&&(res.retcode==TRADE_RETCODE_DONE||res.retcode==TRADE_RETCODE_DONE_PARTIAL))return true;
   if(sent&&(res.retcode==TRADE_RETCODE_PLACED||res.retcode==TRADE_RETCODE_TIMEOUT))g_ambiguousExit=true;
   return false;
}
void ManageExits(const datetime ny) {
   ulong ticket;long kind;double volume;datetime opened;
   if(!OwnPosition(ticket,kind,volume,opened)) {g_ambiguousExit=false;return;}
   if(g_ambiguousExit)return; // do not duplicate an unconfirmed close
   if(MinuteOfDay(ny)<InpSessionCloseNYMinute)return;
   if(kind==POSITION_TYPE_SELL||WeekdaySessions(ServerToNY(opened),ny)>=InpMaxLongSessions)
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
   if(!g_rangeReady)return;
   if(SymbolOccupied())return;
   int used=TodayEntryCount(g_day);
   if(used<0||used>=InpMaxEntriesPerNYDay)return;
   datetime bar=iTime(_Symbol,PERIOD_M5,0);
   if(bar==0||bar==g_lastAttemptBar)return; // at most one submission per bar
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)||tick.bid<=0||tick.ask<=0)return;
   if(InpMaxSpreadIndexPoints>0&&tick.ask-tick.bid>InpMaxSpreadIndexPoints)return;
   // Original corrected model: stop-level crossing. Live order uses market tick,
   // so gaps/slippage are real and NOT assumed to fill at the range boundary.
   ENUM_ORDER_TYPE side;
   if(tick.ask>g_rangeHigh)side=ORDER_TYPE_BUY;
   else if(tick.bid<g_rangeLow)side=ORDER_TYPE_SELL;
   else return;
   double entry=(side==ORDER_TYPE_BUY?tick.ask:tick.bid);
   double stop=TickRound(entry+(side==ORDER_TYPE_BUY?-InpStopIndexPoints:InpStopIndexPoints));
   double target=TickRound(entry+(side==ORDER_TYPE_BUY?InpTargetIndexPoints:-InpTargetIndexPoints));
   double minStop=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(MathAbs(entry-stop)<minStop||MathAbs(entry-target)<minStop)return;
   double vol=SizeForStop(side,entry,stop);
   if(vol<=0)return;
   MqlTradeRequest req={};MqlTradeResult res={};
   req.action=TRADE_ACTION_DEAL;req.symbol=_Symbol;req.magic=InpMagic;
   req.type=side;req.volume=vol;req.price=entry;req.sl=stop;req.tp=target;
   req.deviation=InpDeviationBrokerPoints;req.type_filling=FillPolicy();
   req.comment="E2 NQ ORB research";
   g_lastAttemptBar=bar;
   ResetLastError();
   bool sent=OrderSend(req,res);
   PrintFormat("[NQORB] entry side=%s vol=%.2f range=%.2f/%.2f SL=%.2f TP=%.2f sent=%d retcode=%u err=%d",
      side==ORDER_TYPE_BUY?"BUY":"SELL",vol,g_rangeLow,g_rangeHigh,stop,target,(int)sent,res.retcode,GetLastError());
   if(sent&&(res.retcode==TRADE_RETCODE_PLACED||res.retcode==TRADE_RETCODE_TIMEOUT))g_ambiguousEntry=true;
}
void Run() {
   datetime server=TimeCurrent();
   if(server<=0)return;
   datetime ny=ServerToNY(server);
   int key=DayKey(ny);
   if(key!=g_day) {
      g_day=key;g_rangeReady=false;g_rangeHigh=0;g_rangeLow=0;g_lastAttemptBar=0;
      g_ambiguousEntry=false;
   }
   // Timed exits also require a verified clock. Protective broker SL/TP remain active.
   if(InpBrokerClockVerified)ManageExits(ny);
   if(MinuteOfDay(ny)>=InpRangeEndNYMinute&&!g_rangeReady)
      g_rangeReady=BuildRange(key);
   AttemptEntry(ny);
   if(InpVerbose&&server-g_lastLog>=300) {
      g_lastLog=server;
      PrintFormat("[NQORB] NY=%s range_ready=%d range=[%.2f,%.2f] entries=%d clock_verified=%d",
         TimeToString(ny,TIME_DATE|TIME_MINUTES),(int)g_rangeReady,g_rangeLow,g_rangeHigh,
         TodayEntryCount(key),(int)InpBrokerClockVerified);
   }
}
int OnInit() {
   if(_Period!=PERIOD_M5)Print("[NQORB] Attach to M5 for visual inspection; signal calculation uses M5 history regardless.");
   if(InpRangeStartNYMinute!=570||InpRangeEndNYMinute!=660||InpLastEntryNYMinute!=925||
      InpSessionCloseNYMinute!=930)Print("[NQORB] WARNING: changed published time windows.");
   if(InpRangeEndNYMinute-InpRangeStartNYMinute!=90||
      InpRangeStartNYMinute%5!=0||InpRangeEndNYMinute%5!=0||
      InpStopIndexPoints<=0||InpTargetIndexPoints<=0||
      InpMaxEntriesPerNYDay<1||InpMaxLongSessions<1||
      InpRiskMode<0||InpRiskMode>1||InpFixedCashRisk<=0||InpBalanceRiskPercent<=0||
      InpBrokerDST<0||InpBrokerDST>2||InpMarginBuffer<0||
      InpServerUTCOffsetWinterHours< -12||InpServerUTCOffsetWinterHours>14||
      InpServerUTCOffsetSummerHours< -12||InpServerUTCOffsetSummerHours>14) return INIT_PARAMETERS_INCORRECT;
   if(InpEnableEntries&&!InpBrokerClockVerified) {
      Print("[NQORB] Entries disabled: verify broker clock and set InpBrokerClockVerified=true");
   }
   EventSetTimer(30);
   Print("[NQORB] Research EA initialized. Entry switch=",InpEnableEntries,
         " broker clock verified=",InpBrokerClockVerified,
         ". Native MT5 compilation/backtest required.");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) {EventKillTimer();}
void OnTick() {Run();}
void OnTimer() {Run();}
