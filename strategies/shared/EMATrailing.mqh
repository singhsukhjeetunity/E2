#ifndef E2_EMA_TRAILING_MQH
#define E2_EMA_TRAILING_MQH
#include "TrailingMethod.mqh"
// Optional overlay. Initial sizing/brackets, profit targets and strategy exits remain authoritative.
input group "=== OPTIONAL TRAILING STOP ==="
input bool InpUseEMATrailingStop=false; // Enable the selected EMA or ATR trailing method.
input int InpTrailingEMAPeriod=12;
input ENUM_TIMEFRAMES InpTrailingTimeframe=PERIOD_M5; // PERIOD_CURRENT uses the attached chart.
int e2trail_handle=INVALID_HANDLE;
ENUM_TIMEFRAMES e2trail_frame=PERIOD_M5;
ulong e2trail_magic=0;
struct E2TrailAttempt { ulong ticket; datetime modify,close; double desired; };
E2TrailAttempt e2trail_attempts[];
// Implemented by each host EA using its existing ticket-based close/recovery path.
bool E2TrailClose(const ulong ticket);
string E2TrailDigest() {
   if(!InpUseEMATrailingStop)return ""; // Preserve baseline config hashes when disabled.
   return (InpTrailingMethod==E2_TRAIL_EMA?"|ema_trailing=1|trail_period="+IntegerToString(InpTrailingEMAPeriod):
      "|atr_trailing=1"+E2TrailMethodDigest())+
      "|trail_timeframe="+IntegerToString((int)(InpTrailingTimeframe==PERIOD_CURRENT?_Period:InpTrailingTimeframe));
}
bool E2TrailStopOK(const int direction,const double initial,const double current,const double tolerance) {
   if(!MathIsValidNumber(initial)||!MathIsValidNumber(current)||initial<=0||current<=0)return false;
   if(!InpUseEMATrailingStop)return MathAbs(current-initial)<=tolerance;
   return direction>0?current>=initial-tolerance:current<=initial+tolerance;
}
bool E2TrailTightens(const int direction,const double old_stop,const double next) {
   return next>0&&(direction>0?next>old_stop:next<old_stop);
}
bool E2TrailInit(const ulong magic) {
   ArrayResize(e2trail_attempts,0);e2trail_magic=magic;e2trail_handle=INVALID_HANDLE;
   if(!InpUseEMATrailingStop)return true;
   e2trail_frame=InpTrailingTimeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:InpTrailingTimeframe;
   if(magic==0||!E2TrailMethodValid()||PeriodSeconds(e2trail_frame)<=0)return false;
   if(InpTrailingMethod==E2_TRAIL_EMA&&(InpTrailingEMAPeriod<1||InpTrailingEMAPeriod>1000))return false;
   e2trail_handle=InpTrailingMethod==E2_TRAIL_ATR?iATR(_Symbol,e2trail_frame,InpTrailingATRPeriod):
      iMA(_Symbol,e2trail_frame,InpTrailingEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(e2trail_handle==INVALID_HANDLE)return false;
   Print("[E2_TRAIL] enabled",E2TrailDigest(),"; completed bars; tighten only; original target/exits retained");
   return true;
}
void E2TrailShutdown() {
   if(e2trail_handle!=INVALID_HANDLE){IndicatorRelease(e2trail_handle);e2trail_handle=INVALID_HANDLE;}
   ArrayResize(e2trail_attempts,0);
}
int E2TrailAttemptIndex(const ulong ticket) {
   for(int i=0;i<ArraySize(e2trail_attempts);i++)if(e2trail_attempts[i].ticket==ticket)return i;
   int n=ArraySize(e2trail_attempts);ArrayResize(e2trail_attempts,n+1);ZeroMemory(e2trail_attempts[n]);
   e2trail_attempts[n].ticket=ticket;return n;
}
void E2TrailPrune() {
   int n=0;
   for(int i=0;i<ArraySize(e2trail_attempts);i++)
      if(PositionSelectByTicket(e2trail_attempts[i].ticket))e2trail_attempts[n++]=e2trail_attempts[i];
   ArrayResize(e2trail_attempts,n);
}
void E2TrailRun() {
   if(!InpUseEMATrailingStop||e2trail_handle==INVALID_HANDLE)return;
   E2TrailPrune();
   bool owned=false;
   for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&
      (ulong)PositionGetInteger(POSITION_MAGIC)==e2trail_magic){owned=true;break;}
   if(!owned)return;
   int seconds=PeriodSeconds(e2trail_frame);
   int period=InpTrailingMethod==E2_TRAIL_ATR?InpTrailingATRPeriod:InpTrailingEMAPeriod;
   if(seconds<=0||BarsCalculated(e2trail_handle)<period+1)return;
   MqlRates bars[];double values[];
   if(CopyRates(_Symbol,e2trail_frame,1,1,bars)!=1||CopyBuffer(e2trail_handle,0,1,1,values)!=1)return;
   datetime now=TimeCurrent();
   if(bars[0].time!=iTime(_Symbol,e2trail_frame,1)||bars[0].time+seconds>now||
      now-bars[0].time>=2*seconds||!MathIsValidNumber(values[0])||values[0]<=0||values[0]==EMPTY_VALUE)return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)||!MathIsValidNumber(tick.bid)||!MathIsValidNumber(tick.ask)||
      tick.bid<=0||tick.ask<tick.bid||tick.time<now-15||tick.time>now+1)return;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(!MathIsValidNumber(step)||step<=0)return;
   double minimum=MathMax((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
      (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0||PositionGetString(POSITION_SYMBOL)!=_Symbol||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=e2trail_magic)continue;
      int direction=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
      double old=PositionGetDouble(POSITION_SL);
      double level=E2TrailLevel(direction,values[0],bars[0].close,values[0]);
      if(level<=0)continue;
      double next=NormalizeDouble((direction>0?MathFloor(level/step):MathCeil(level/step))*step,_Digits);
      int slot=E2TrailAttemptIndex(ticket);
      // Remember the tightest observed trailing level even when a modify was rejected/frozen.
      // A later lower/higher level must not turn a retry into a loosening request.
      if(e2trail_attempts[slot].desired>0)next=direction>0?MathMax(next,e2trail_attempts[slot].desired):
         MathMin(next,e2trail_attempts[slot].desired);
      if(old>0&&!E2TrailTightens(direction,old,next))continue;
      e2trail_attempts[slot].desired=next;
      double reference=direction>0?tick.bid:tick.ask;
      if(old<=0||(direction>0?reference<=next:reference>=next)) {
         if(e2trail_attempts[slot].close>0&&now-e2trail_attempts[slot].close<5)continue;
         e2trail_attempts[slot].close=now;
         bool closed=E2TrailClose(ticket);
         Print("[E2_TRAIL] close ticket=",ticket," stop=",next," confirmed=",closed);
         continue;
      }
      if(MathAbs(reference-next)<minimum)continue; // Keep broker stop; retry without loosening.
      if(e2trail_attempts[slot].modify>0&&now-e2trail_attempts[slot].modify<1)continue;
      e2trail_attempts[slot].modify=now;
      // Recheck ownership/ratchet after reading indicators; never touch another EA's position.
      if(!PositionSelectByTicket(ticket)||PositionGetString(POSITION_SYMBOL)!=_Symbol||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=e2trail_magic||
         !E2TrailTightens(direction,PositionGetDouble(POSITION_SL),next))continue;
      MqlTradeRequest req={};MqlTradeResult res={};
      req.action=TRADE_ACTION_SLTP;req.position=ticket;req.symbol=_Symbol;req.magic=e2trail_magic;
      req.sl=next;req.tp=PositionGetDouble(POSITION_TP); // Original TP is retained, including no TP.
      bool sent=OrderSend(req,res);
      if(!sent||(res.retcode!=TRADE_RETCODE_DONE&&res.retcode!=TRADE_RETCODE_DONE_PARTIAL))
         Print("[E2_TRAIL] modify retry ticket=",ticket," retcode=",res.retcode);
   }
}
#endif
