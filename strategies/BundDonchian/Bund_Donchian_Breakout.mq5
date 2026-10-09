#property strict
#property version "0.10"
#property description "E2 System 6 research: Bund Donchian breakout. Not a verified reproduction of published results."
#include <Trade/Trade.mqh>
input group "=== E2 BUND DONCHIAN BREAKOUT ==="
input bool InpEnableEntries=false;       // Enable entries only for a verified research test
input bool InpExportCsv=true;
input ulong InpMagic=420606;
input group "=== RISK MANAGEMENT ==="
input int InpRiskMode=0;                 // 0 fixed account cash; 1 balance percent
input double InpFixedCashRisk=1000.0;
input double InpBalanceRiskPercent=1.0;
input group "=== STRATEGY SETTINGS ==="
input int InpEntryChannelBars=20;        // Prior completed H1 bars
input int InpExitChannelBars=10;         // Opposite channel on completed H1 close
input int InpATRPeriod=14;
input double InpStopATR=2.0;
input group "=== EXECUTION SAFETY ==="
input double InpMaxSpreadPriceUnits=0.10; // Price units; verify against your broker's Bund quote
input group "=== BROKER CLOCK PROFILE ==="
input bool InpBrokerClockVerified=false;
input int InpServerUTCOffsetWinterHours=0;
input int InpServerUTCOffsetSummerHours=0;
input int InpBrokerDST=0;               // 0 fixed, 1 EU, 2 US

const int BDDeviationPoints=30;
const double BDMarginBuffer=0.15;
CTrade bd_trade;
int bd_atr=INVALID_HANDLE;
datetime bd_lastBar=0;
bool bd_busy=false;
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

#include "BundReport.mqh"

bool BDOwnPosition(ulong &ticket,long &type) {
   ticket=0;type=-1;
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong t=PositionGetTicket(i);
      if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&
         (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic) {
         ticket=t;type=PositionGetInteger(POSITION_TYPE);return true;
      }
   }
   return false;
}
bool BDSymbolOccupied() {
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong t=PositionGetTicket(i);
      if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol)return true;
   }
   for(int i=OrdersTotal()-1;i>=0;i--) {
      ulong t=OrderGetTicket(i);
      if(t>0&&OrderGetString(ORDER_SYMBOL)==_Symbol)return true;
   }
   return false;
}
double BDRoundPrice(const double p) {
   double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(step<=0)step=_Point;
   return NormalizeDouble(MathRound(p/step)*step,_Digits);
}
double BDVolume(const ENUM_ORDER_TYPE side,const double entry,const double stop) {
   double budget=InpRiskMode==0?InpFixedCashRisk:AccountInfoDouble(ACCOUNT_BALANCE)*InpBalanceRiskPercent/100.0;
   double pnl=0,margin=0;
   if(budget<=0||!OrderCalcProfit(side,_Symbol,1.0,entry,stop,pnl)||pnl>=0||
      !OrderCalcMargin(side,_Symbol,1.0,entry,margin)||margin<=0)return 0;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(step<=0||min<=0||max<min)return 0;
   double desired=MathMin(max,MathMin(budget/(-pnl),AccountInfoDouble(ACCOUNT_MARGIN_FREE)/(margin*(1+BDMarginBuffer))));
   double vol=NormalizeDouble(MathFloor((desired+1e-9)/step)*step,8);
   return vol>=min?MathMin(vol,max):0;
}
void BDProcessBar() {
   if(!InpBrokerClockVerified)return;
   datetime bar=iTime(_Symbol,PERIOD_H1,0);
   if(bar<=0||bar==bd_lastBar)return;
   MqlRates candles[];
   ArraySetAsSeries(candles,true);
   int need=MathMax(InpEntryChannelBars,InpExitChannelBars)+1;
   if(CopyRates(_Symbol,PERIOD_H1,1,need,candles)!=need)return;
   double atr[];
   ArraySetAsSeries(atr,true);
   if(CopyBuffer(bd_atr,0,1,1,atr)!=1||atr[0]<=0||!MathIsValidNumber(atr[0]))return;
   bd_lastBar=bar; // Mark only after all data is ready; retry if history is temporarily missing.
   double entryHi=-DBL_MAX,entryLo=DBL_MAX,exitHi=-DBL_MAX,exitLo=DBL_MAX;
   for(int i=1;i<=InpEntryChannelBars;i++) {
      entryHi=MathMax(entryHi,candles[i].high);
      entryLo=MathMin(entryLo,candles[i].low);
   }
   for(int i=1;i<=InpExitChannelBars;i++) {
      exitHi=MathMax(exitHi,candles[i].high);
      exitLo=MathMin(exitLo,candles[i].low);
   }
   ulong ticket;long type;
   if(BDOwnPosition(ticket,type)) {
      bool exitLong=type==POSITION_TYPE_BUY&&candles[0].close<exitLo;
      bool exitShort=type==POSITION_TYPE_SELL&&candles[0].close>exitHi;
      if(exitLong||exitShort) {
         bool sent=bd_trade.PositionClose(ticket);
         uint rc=bd_trade.ResultRetcode();
         BDSignal(TimeCurrent(),"CHANNEL_EXIT",StringFormat("ticket=%I64u sent=%d retcode=%u",ticket,(int)sent,rc));
         // Do not open a new position on an exit bar.
      }
      return;
   }
   if(!InpEnableEntries||bd_busy||BDSymbolOccupied())return;
   ENUM_ORDER_TYPE side;
   if(candles[0].close>entryHi)side=ORDER_TYPE_BUY;
   else if(candles[0].close<entryLo)side=ORDER_TYPE_SELL;
   else return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)||tick.bid<=0||tick.ask<=0)return;
   if(InpMaxSpreadPriceUnits>0&&tick.ask-tick.bid>InpMaxSpreadPriceUnits) {
      BDSignal(TimeCurrent(),"SPREAD_BLOCK","spread exceeds configured cap");return;
   }
   double price=side==ORDER_TYPE_BUY?tick.ask:tick.bid;
   double stop=BDRoundPrice(price+(side==ORDER_TYPE_BUY?-1:1)*InpStopATR*atr[0]);
   if(stop<=0)return;
   double minDistance=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(MathAbs(price-stop)<minDistance)return;
   double volume=BDVolume(side,price,stop);
   if(volume<=0) {BDSignal(TimeCurrent(),"RISK_BLOCK","volume below minimum or margin insufficient");return;}
   bd_busy=true; // Fail closed after an ambiguous broker response until restart/reconciliation.
   bool sent=bd_trade.PositionOpen(_Symbol,side,volume,price,stop,0,"E2 Bund Donchian research");
   uint rc=bd_trade.ResultRetcode();
   BDSignal(TimeCurrent(),"ENTRY",StringFormat("side=%d vol=%.8f price=%.5f sl=%.5f sent=%d retcode=%u",
      (int)side,volume,price,stop,(int)sent,rc));
   if(!sent||(rc!=TRADE_RETCODE_DONE&&rc!=TRADE_RETCODE_DONE_PARTIAL)) {
      Print("[BUND] Entry response uncertain/rejected; no further entries until restart. retcode=",rc);
   } else bd_busy=false;
}
int OnInit() {
   if(InpEntryChannelBars<2||InpExitChannelBars<1||InpExitChannelBars>=InpEntryChannelBars||
      InpATRPeriod<2||InpStopATR<=0||InpRiskMode<0||InpRiskMode>1||
      InpFixedCashRisk<=0||InpBalanceRiskPercent<=0||InpMaxSpreadPriceUnits<0||
      InpMagic==0||InpBrokerDST<0||InpBrokerDST>2||
      InpServerUTCOffsetWinterHours< -12||InpServerUTCOffsetWinterHours>14||
      InpServerUTCOffsetSummerHours< -12||InpServerUTCOffsetSummerHours>14)
      return INIT_PARAMETERS_INCORRECT;
   if(!InpBrokerClockVerified)Print("[BUND] Verify broker winter/summer UTC offsets and DST before enabling test.");
   if(_Period!=PERIOD_H1)Print("[BUND] Strategy uses H1 bars regardless of chart timeframe.");
   bd_atr=iATR(_Symbol,PERIOD_H1,InpATRPeriod);
   if(bd_atr==INVALID_HANDLE)return INIT_FAILED;
   bd_trade.SetExpertMagicNumber(InpMagic);
   bd_trade.SetDeviationInPoints(BDDeviationPoints);
   bd_trade.SetAsyncMode(false);
   bd_trade.SetTypeFillingBySymbol(_Symbol);
   if(!BDOpenReports())return INIT_FAILED;
   Print("[BUND] Research Donchian 20/10, ATR14 x 2. Not validated on Bund historical data.");
   return INIT_SUCCEEDED;
}
void OnTick() {
   if(InpExportCsv)BDEquity(TimeCurrent());
   BDProcessBar();
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res) {
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD)BDExportTrades();
}
double OnTester() {BDExportTrades();return 0;}
void OnDeinit(const int reason) {
   BDCloseReports();
   if(bd_atr!=INVALID_HANDLE)IndicatorRelease(bd_atr);
}
