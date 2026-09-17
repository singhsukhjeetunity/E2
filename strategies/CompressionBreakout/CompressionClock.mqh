#ifndef COMPRESSION_CLOCK_MQH
#define COMPRESSION_CLOCK_MQH
// Reuse broker/UTC and New York DST conversion; no US equity holiday filter.
#include "..\\EMAPullback\\SessionClock.mqh"
bool CBEntryWindow(const datetime utc) {
   MqlDateTime t;TimeToStruct(utc,t);
   return t.day_of_week>=1 && t.day_of_week<=5 && t.hour>=6 && t.hour<20;
}
datetime CBDeadline(const datetime entry) {
   MqlDateTime t;TimeToStruct(NPNy(entry),t);
   datetime session=NPNyToUtc(NPDate(t.year,t.mon,t.day,16,45));
   datetime duration=entry+8*3600;
   return session<duration?session:duration;
}
#endif
