// Portable MQL calendar shim: compile the exact calendar functions from the EA.
#include <cassert>
#include <cstdint>
#include <ctime>
#include <iostream>
using datetime=std::int64_t;
struct MqlDateTime {int year=0,mon=0,day=0,hour=0,min=0,sec=0,day_of_week=0,day_of_year=0;};
void TimeToStruct(datetime t,MqlDateTime &d) {
   time_t value=(time_t)t;tm x={};gmtime_r(&value,&x);
   d.year=x.tm_year+1900;d.mon=x.tm_mon+1;d.day=x.tm_mday;
   d.hour=x.tm_hour;d.min=x.tm_min;d.sec=x.tm_sec;
   d.day_of_week=x.tm_wday;d.day_of_year=x.tm_yday;
}
datetime StructToTime(const MqlDateTime &d) {
   tm x={};x.tm_year=d.year-1900;x.tm_mon=d.mon-1;x.tm_mday=d.day;
   x.tm_hour=d.hour;x.tm_min=d.min;x.tm_sec=d.sec;
   return (datetime)timegm(&x);
}
int InpBrokerDST=0,InpServerUTCOffsetWinterHours=0,InpServerUTCOffsetSummerHours=0;
#include "nq_calendar.mqh"
datetime T(int y,int m,int day,int hour,int minute=0) {
   MqlDateTime d={};d.year=y;d.mon=m;d.day=day;d.hour=hour;d.min=minute;
   return StructToTime(d);
}
int main() {
   assert(NthSunday(2026,3,2)==8);
   assert(NthSunday(2026,11,1)==1);
   assert(LastSunday(2026,3)==29);
   assert(LastSunday(2026,10)==25);
   assert(!IsUSDST(T(2026,3,8,6,59)));
   assert(IsUSDST(T(2026,3,8,7)));
   assert(IsUSDST(T(2026,11,1,5,59)));
   assert(!IsUSDST(T(2026,11,1,6)));
   assert(IsUSDST(T(2006,4,2,7)));
   assert(!IsUSDST(T(2006,10,29,6)));
   assert(!IsEUDST(T(2026,3,29,0,59)));
   assert(IsEUDST(T(2026,3,29,1)));
   assert(IsEUDST(T(2026,10,25,0,59)));
   assert(!IsEUDST(T(2026,10,25,1)));
   assert(MinuteOfDay(UTCToNY(T(2026,1,5,14,30)))==570);
   assert(MinuteOfDay(UTCToNY(T(2026,7,6,13,30)))==570);
   assert(DayKey(UTCToNY(T(2026,7,6,13,30)))==20260706);
   assert(!IsNYWeekday(T(2026,7,5,12)));
   assert(IsNYWeekday(T(2026,7,6,12)));
   InpBrokerDST=1;InpServerUTCOffsetWinterHours=2;InpServerUTCOffsetSummerHours=3;
   assert(ServerToUTC(T(2026,1,5,16,30))==T(2026,1,5,14,30));
   assert(ServerToUTC(T(2026,7,6,16,30))==T(2026,7,6,13,30));
   assert(MinuteOfDay(ServerToNY(T(2026,7,6,16,30)))==570);
   InpBrokerDST=0;InpServerUTCOffsetWinterHours=0;
   assert(MinuteOfDay(ServerToNY(T(2026,1,5,14,30)))==570);
   std::cout<<"NQ calendar / DST checks passed\n";
}
