// Exercise the production Gold clock and range class with deterministic UTC dates.
#include <cassert>
#include <ctime>
#include <algorithm>
#include <iostream>
using datetime=long long;
struct MqlDateTime{int year=0,mon=0,day=0,hour=0,min=0,sec=0,day_of_week=0;};
datetime StructToTime(const MqlDateTime &m){std::tm t{};t.tm_year=m.year-1900;t.tm_mon=m.mon-1;t.tm_mday=m.day;t.tm_hour=m.hour;t.tm_min=m.min;t.tm_sec=m.sec;return timegm(&t);}
bool TimeToStruct(datetime x,MqlDateTime &m){std::time_t v=x;auto t=*std::gmtime(&v);m={t.tm_year+1900,t.tm_mon+1,t.tm_mday,t.tm_hour,t.tm_min,t.tm_sec,t.tm_wday};return true;}
datetime date(int y,int m,int d,int h=0,int minute=0){return StructToTime({y,m,d,h,minute,0,0});}
double MathMax(double a,double b){return std::max(a,b);}double MathMin(double a,double b){return std::min(a,b);}
struct E2Config{int xau_range_start=480,xau_range_end=510;};
#include "../strategies/GoldSessionFade/include/time/E2TimeUtils.mqh"
#include "gold_range.mqh"
int main(){
 assert(E2NewYorkTime(date(2026,1,15,13))==date(2026,1,15,8));
 assert(E2NewYorkTime(date(2026,7,15,12))==date(2026,7,15,8));
 auto spring=date(2026,3,8,7),fall=date(2026,11,1,6);
 assert(E2NewYorkTime(spring-1)==spring-1-18000);assert(E2NewYorkTime(spring)==spring-14400);
 assert(E2NewYorkTime(fall-1)==fall-1-14400);assert(E2NewYorkTime(fall)==fall-18000);
 // Historical US rules before 2007 and weeks when US/Europe differ.
 assert(E2NewYorkTime(date(2006,3,20,13))==date(2006,3,20,8));
 assert(E2NewYorkTime(date(2006,4,2,7))==date(2006,4,2,3));
 assert(E2NewYorkTime(date(2006,10,29,6))==date(2006,10,29,1));
 assert(E2NewYorkTime(date(2026,3,16,12))==date(2026,3,16,8));
 assert(E2NewYorkTime(date(2026,10,28,12))==date(2026,10,28,8));
 assert(E2CalendarDay(E2NewYorkTime(date(2026,1,15,4)))==20260114);
 assert(E2CalendarDay(E2NewYorkTime(date(2026,1,15,5)))==20260115);
 for(int month:{1,7}){
  E2Config c;E2XauSessionRange range;range.Initialize(c);int utc_hour=month==1?13:12;
  auto begin=date(2026,month,15,utc_hour);
  for(int i=0;i<6;i++)range.Observe(E2NewYorkTime(begin+i*300),110+i,100-i);
  assert(range.Valid()&&range.Frozen()&&range.Low()==95&&range.High()==115);
  assert(range.Signal(E2NewYorkTime(begin+1800),94));
  // Fixed UTC baseline still uses exactly the UTC input window.
  c.xau_range_start=720;c.xau_range_end=750;range.Initialize(c);
  for(int i=0;i<6;i++)range.Observe(date(2026,month,15,12)+i*300,110,100);
  assert(range.Valid()&&range.Signal(date(2026,month,15,12,30),99));
 }
 std::cout<<"Gold NY DST boundaries, historical rules, day rollover and range tests passed\n";
}
