#ifndef RC_CLOCK_MQH
#define RC_CLOCK_MQH
enum RCClock { RC_FIXED=0, RC_EU=1, RC_US=2 };
datetime RCDate(const int year,const int month,const int day,const int hour=0,const int minute=0) {
   MqlDateTime t={};t.year=year;t.mon=month;t.day=day;t.hour=hour;t.min=minute;return StructToTime(t);
}
datetime RCDay(const datetime t){return t-t%86400;}
int RCDayKey(const datetime wall) {
   MqlDateTime t;TimeToStruct(wall,t);return t.year*10000+t.mon*100+t.day;
}
int RCSunday(const int year,const int month,const int nth) {
   MqlDateTime t;TimeToStruct(RCDate(year,month,1),t);return 1+(7-t.day_of_week)%7+(nth-1)*7;
}
int RCLastSunday(const int year,const int month) {
   datetime next=month==12?RCDate(year+1,1,1):RCDate(year,month+1,1);
   MqlDateTime t;TimeToStruct(next-86400,t);return t.day-t.day_of_week;
}
bool RCDST(const datetime utc,const RCClock mode) {
   if(mode==RC_FIXED)return false;
   MqlDateTime t;TimeToStruct(utc,t);
   static int cached_year=0;
   static datetime us_start=0,us_end=0,eu_start=0,eu_end=0;
   if(cached_year!=t.year) {
      cached_year=t.year;
      us_start=RCDate(t.year,3,RCSunday(t.year,3,2),7);
      us_end=RCDate(t.year,11,RCSunday(t.year,11,1),6);
      eu_start=RCDate(t.year,3,RCLastSunday(t.year,3),1);
      eu_end=RCDate(t.year,10,RCLastSunday(t.year,10),1);
   }
   if(mode==RC_US)return utc>=us_start&&utc<us_end;
   if(mode==RC_EU)return utc>=eu_start&&utc<eu_end;
   return false;
}
int RCOffset(const datetime utc,const RCClock mode,const int winter_minutes) {
   return winter_minutes*60+(RCDST(utc,mode)?3600:0);
}
datetime RCWall(const datetime utc,const RCClock mode,const int winter_minutes) {
   return utc+RCOffset(utc,mode,winter_minutes);
}
bool RCUtc(const datetime wall,const RCClock mode,const int winter_minutes,datetime &utc) {
   datetime a=wall-winter_minutes*60;
   if(mode==RC_FIXED){utc=a;return true;}
   datetime b=a-3600;
   bool va=!RCDST(a,mode),vb=RCDST(b,mode);
   if(va==vb)return false; // Fail closed in nonexistent or repeated wall-clock hour.
   utc=va?a:b;return true;
}
bool RCWeekday(const datetime wall) {
   MqlDateTime t;TimeToStruct(wall,t);return t.day_of_week>=1&&t.day_of_week<=5;
}
bool RCListed(const string dates,const datetime wall) {
   return StringFind("|"+dates+"|","|"+IntegerToString(RCDayKey(wall))+"|")>=0;
}
// Local Japanese payment date. Weekend dates roll back to the preceding Friday.
bool RCGotobi(const datetime japanese_day) {
   datetime day=RCDay(japanese_day);
   if(!RCWeekday(day))return false;
   for(int ahead=0;ahead<=2;ahead++) {
      datetime candidate=day+ahead*86400;MqlDateTime t;TimeToStruct(candidate,t);
      if(ahead>0&&RCWeekday(candidate))continue;
      if(t.day==5||t.day==10||t.day==15||t.day==20||t.day==25||t.day==30)return true;
   }
   return false;
}
#endif
