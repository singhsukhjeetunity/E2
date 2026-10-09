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
   if(t.year>=2007)return utc>=NPDate(t.year,3,NPSunday(t.year,3,2),7)&&utc<NPDate(t.year,11,NPSunday(t.year,11,1),6);
   datetime start=NPDate(t.year,4,t.year>=1987?NPSunday(t.year,4,1):NPLastSunday(t.year,4),7);
   if(t.year==1974)start=NPDate(1974,1,6,7);
   if(t.year==1975)start=NPDate(1975,2,23,7);
   return utc>=start&&utc<NPDate(t.year,10,NPLastSunday(t.year,10),6);
}
bool NPEUDst(const datetime utc) {
   MqlDateTime t;TimeToStruct(utc,t);
   return utc>=NPDate(t.year,3,NPLastSunday(t.year,3),1) &&
          utc<NPDate(t.year,t.year>=1996?10:9,NPLastSunday(t.year,t.year>=1996?10:9),1);
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
int NPNthWeekday(const int y,const int m,const int weekday,const int nth) {
   MqlDateTime t;TimeToStruct(NPDate(y,m,1),t);
   return 1+(weekday-t.day_of_week+7)%7+(nth-1)*7;
}
datetime NPObserved(const int y,const int m,const int d,const bool saturday_friday=true) {
   datetime date=NPDate(y,m,d);MqlDateTime t;TimeToStruct(date,t);
   if(t.day_of_week==0)return date+86400;
   if(t.day_of_week==6&&saturday_friday)return date-86400;
   return date;
}
datetime NPEaster(const int y) {
   // Gregorian computus; Good Friday is two days earlier.
   int a=y%19,b=y/100,c=y%100,d=b/4,e=b%4,f=(b+8)/25,g=(b-f+1)/3;
   int h=(19*a+b-d-g+15)%30,i=c/4,k=c%4,l=(32+2*e+2*i-h-k)%7;
   int n=(a+11*h+22*l)/451,v=h+l-7*n+114;
   return NPDate(y,v/31,v%31+1);
}
datetime NPLastMonday(const int y,const int m) {
   datetime next=m==12?NPDate(y+1,1,1):NPDate(y,m+1,1);
   MqlDateTime t;TimeToStruct(next-86400,t);
   return next-86400-(datetime)((t.day_of_week+6)%7)*86400;
}
int NPCalendarCloseMinute(const datetime utc) {
   MqlDateTime t;TimeToStruct(NPNy(utc),t);
   if(t.day_of_week==0||t.day_of_week==6)return 0;
   int y=t.year;datetime date=NPDate(y,t.mon,t.day);
   int thanksgiving=NPNthWeekday(y,11,4,4);
   if(date==NPObserved(y,1,1,false)||date==NPEaster(y)-2*86400||
      date==NPObserved(y,7,4)||date==NPObserved(y,12,25)||
      (y>=1998&&date==NPDate(y,1,NPNthWeekday(y,1,1,3)))||
      date==(y>=1971?NPDate(y,2,NPNthWeekday(y,2,1,3)):NPObserved(y,2,22))||
      date==(y>=1971?NPLastMonday(y,5):NPObserved(y,5,30))||
      (y>=2022&&date==NPObserved(y,6,19))||
      date==NPDate(y,9,NPNthWeekday(y,9,1,1))||date==NPDate(y,11,thanksgiving))return 0;
   // Confirmed exceptional full closures in the MT5-era calendar.
   int day=NPDay(date);
   if(NPContains("|19721228|19730125|19770714|19850927|19940427|20010911|20010912|20010913|20010914|20040611|20070102|20121029|20121030|20181205|20250109|",day))return 0;
   if(y<=1980&&y%4==0&&date==NPDate(y,11,NPNthWeekday(y,11,1,1)+1))return 0;
   if(y>=1993&&t.mon==11&&t.day==thanksgiving+1)return 780;
   if(y==1992&&t.mon==11&&t.day==thanksgiving+1)return 840;
   if(y>=1995&&t.mon==7&&t.day==3&&
      (t.day_of_week==1||t.day_of_week==2||t.day_of_week==4||(y>=2013&&t.day_of_week==3)))return 780;
   if(y>=1996&&y<=2012&&t.mon==7&&t.day==5&&t.day_of_week==5)return 780;
   if(y>=1996&&t.mon==12&&t.day==24)return 780;
   if(NPContains("|19741224|19751224|19901224|19911224|19921224|19780206|",day))return 840;
   return y<1974?930:960;
}
int NPCloseMinute(const datetime utc) {
   static int cached_day=-1,cached_close=0;
   int day=NPDay(NPNy(utc));
   if(day!=cached_day){cached_day=day;cached_close=NPCalendarCloseMinute(utc);}
   return cached_close;
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
