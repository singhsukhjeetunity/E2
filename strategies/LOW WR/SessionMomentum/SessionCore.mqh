#ifndef E2_SESSION_MOMENTUM_CORE
#define E2_SESSION_MOMENTUM_CORE
#include "..\\..\\shared\\SessionClock.mqh"
// Signal compares levels, not a crossover; no use of the forming M5 candle.
int SMDirection(const double close,const double ema) {
   if(!MathIsValidNumber(close)||!MathIsValidNumber(ema)||close<=0||ema<=0)return 0;
   return close>ema?1:(close<ema?-1:0);
}
double SMStop(const int direction,const double ema,const double tick,const int digits) {
   if(tick<=0||ema<=0||!MathIsValidNumber(ema))return 0;
   return NormalizeDouble((direction>0?MathFloor(ema/tick):MathCeil(ema/tick))*tick,digits);
}
bool SMTightens(const int direction,const double old_stop,const double next) {
   return next>0&&(old_stop<=0||(direction>0?next>old_stop:next<old_stop));
}
bool SMWindow(const datetime utc,const datetime closed_utc) {
   datetime ny=NPNy(utc),bar=NPNy(closed_utc);MqlDateTime d;TimeToStruct(ny,d);
   int second=(int)(ny%86400);
   return d.day_of_week>=1&&d.day_of_week<=5&&NPCloseMinute(utc)>0&&
      NPDay(ny)==NPDay(bar)&&bar%86400==570*60&&
      second>=575*60&&second<576*60&&utc>=closed_utc+300;
}
datetime SMDeadline(const datetime opened_utc,const int close_minute) {
   datetime ny=NPNy(opened_utc);MqlDateTime d;TimeToStruct(ny,d);
   int calendar=NPCloseMinute(opened_utc);
   int minute=calendar>0?(int)MathMin(close_minute,calendar):close_minute;
   return NPNyToUtc(NPDate(d.year,d.mon,d.day)+minute*60);
}
#endif
