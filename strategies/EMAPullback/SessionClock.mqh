#ifndef NASDAQ_PAIR_CLOCK_MQH
#define NASDAQ_PAIR_CLOCK_MQH
enum NPClockMode { NP_CLOCK_UNSET=0, NP_FIXED_UTC_OFFSET=1, NP_US_SEASONAL=2, NP_EU_SEASONAL=3 };
datetime NPDate(const int y,const int m,const int d,const int h=0,const int minute=0) {
   MqlDateTime t={};t.year=y;t.mon=m;t.day=d;t.hour=h;t.min=minute;
   return StructToTime(t);
}
int NPSunday(const int y,const int m,const int nth) {
   MqlDateTime t;TimeToStruct(NPDate(y,m,1),t);
   return 1+(7-t.day_of_week)%7+(nth-1)*7;
}
int NPLastSunday(const int y,const int m) {
   datetime next=(m==12?NPDate(y+1,1,1):NPDate(y,m+1,1));
   MqlDateTime t;TimeToStruct(next-86400,t);return t.day-t.day_of_week;
}
bool NPUSDst(const datetime utc) {
   MqlDateTime t;TimeToStruct(utc,t);
   return utc>=NPDate(t.year,3,NPSunday(t.year,3,2),7) &&
          utc<NPDate(t.year,11,NPSunday(t.year,11,1),6);
}
bool NPEUDst(const datetime utc) {
   MqlDateTime t;TimeToStruct(utc,t);
   return utc>=NPDate(t.year,3,NPLastSunday(t.year,3),1) &&
          utc<NPDate(t.year,10,NPLastSunday(t.year,10),1);
}
int NPBrokerOffset(const datetime utc,const NPClockMode mode,const int winter) {
   return winter+((mode==NP_US_SEASONAL&&NPUSDst(utc))||
                  (mode==NP_EU_SEASONAL&&NPEUDst(utc))?3600:0);
}
bool NPToUtc(const datetime server,const NPClockMode mode,const int winter,datetime &utc) {
   if(mode==NP_CLOCK_UNSET)return false;
   datetime a=server-winter;
   if(mode==NP_FIXED_UTC_OFFSET){utc=a;return true;}
   datetime b=a-3600;
   bool va=NPBrokerOffset(a,mode,winter)==winter;
   bool vb=NPBrokerOffset(b,mode,winter)==winter+3600;
   if(va==vb)return false; // Ambiguous repeated hour or nonexistent wall time.
   utc=va?a:b;return true;
}
datetime NPToServer(const datetime utc,const NPClockMode mode,const int winter) {
   return utc+NPBrokerOffset(utc,mode,winter);
}
datetime NPNy(const datetime utc) {return utc+(NPUSDst(utc)?-14400:-18000);}
int NPDay(const datetime wall) {
   MqlDateTime t;TimeToStruct(wall,t);return t.year*10000+t.mon*100+t.day;
}
datetime NPNyToUtc(const datetime wall) {
   datetime a=wall+18000,b=wall+14400;
   return NPUSDst(b)?b:a; // Called only for unambiguous daytime session boundaries.
}
bool NPContains(const string dates,const int day) {
   return StringFind(dates,"|"+IntegerToString(day)+"|")>=0;
}
int NPCloseMinute(const datetime utc) {
   MqlDateTime t;TimeToStruct(NPNy(utc),t);
   if(t.year<2022||t.year>2026)return -1; // Published calendar coverage; no future years guessed.
   if(t.day_of_week==0||t.day_of_week==6)return 0;
   string closed="|20220117|20220221|20220415|20220530|20220620|20220704|20220905|20221124|20221226|"
      "20230102|20230116|20230220|20230407|20230529|20230619|20230704|20230904|20231123|20231225|"
      "20240101|20240115|20240219|20240329|20240527|20240619|20240704|20240902|20241128|20241225|"
      "20250101|20250109|20250120|20250217|20250418|20250526|20250619|20250704|20250901|20251127|20251225|"
      "20260101|20260119|20260216|20260403|20260525|20260619|20260703|20260907|20261126|20261225|";
   int day=t.year*10000+t.mon*100+t.day;
   if(NPContains(closed,day))return 0;
   string half="|20221125|20230703|20231124|20240703|20241129|20241224|20250703|20251128|20251224|20261127|20261224|";
   return NPContains(half,day)?780:960;
}
datetime NPDeadline(const datetime utc) {
   datetime wall=NPNy(utc);MqlDateTime t;TimeToStruct(wall,t);
   int close=NPCloseMinute(utc);
   if(close<=0)return utc;
   return NPNyToUtc(NPDate(t.year,t.mon,t.day)+(close-5)*60);
}
// End wall time may be midnight or cross midnight. Ignore API date fields.
datetime NPSessionEnd(const datetime day,const datetime from,const datetime to) {
   int a=(int)(from%86400),b=(int)(to%86400);
   return day+b+(b<=a?86400:0);
}
datetime NPEarlierExit(const datetime planned,const datetime broker_end,const int buffer) {
   datetime cutoff=broker_end-buffer*60;
   return cutoff<planned?cutoff:planned;
}
bool NPExitOverdue(const datetime now,const datetime deadline) {return now>deadline+60;}
bool NPRetryClose(const datetime now,const datetime last) {return last==0||now-last>=5;}
#endif
