#ifndef E2_GAP_FADE_CLOCK_MQH
#define E2_GAP_FADE_CLOCK_MQH
#include "..\\EMAPullback\\SessionClock.mqh"

datetime GFNyBoundaryUtc(const int day,const int hour,const int minute) {
   int y=day/10000,m=(day/100)%100,d=day%100;
   return NPNyToUtc(NPDate(y,m,d,hour,minute));
}
int GFPreviousCalendarDay(const int day) {
   datetime wall=NPDate(day/10000,(day/100)%100,day%100)-86400;
   MqlDateTime t;TimeToStruct(wall,t);return t.year*10000+t.mon*100+t.day;
}
#endif
