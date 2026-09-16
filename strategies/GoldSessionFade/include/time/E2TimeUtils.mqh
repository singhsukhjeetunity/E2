#ifndef E2_TIME_UTILS_MQH
#define E2_TIME_UTILS_MQH

const datetime E2_TIME_FROM=820454400,E2_TIME_UNTIL=2145916800;

int E2CalendarDay(const datetime value){MqlDateTime p;if(!TimeToStruct(value,p))return(0);return(p.year*10000+p.mon*100+p.day);}
int E2DayOfWeek(const datetime value){MqlDateTime p;if(!TimeToStruct(value,p))return(-1);return(p.day_of_week);}
int E2MinuteOfDay(const datetime value){MqlDateTime p;if(!TimeToStruct(value,p))return(-1);return(p.hour*60+p.min);}
datetime E2LocalMidnight(const datetime value){MqlDateTime p;if(!TimeToStruct(value,p))return(0);p.hour=0;p.min=0;p.sec=0;return(StructToTime(p));}

// US local-clock rules for the adapter's 1996-2037 supported date range.
// Transition instants are UTC: 02:00 standard in spring, 02:00 daylight in fall.
datetime E2NewYorkTime(const datetime utc)
  {
   MqlDateTime p;TimeToStruct(utc,p);
   int year=p.year;bool modern=year>=2007;
   p.mon=modern?3:4;p.day=1;p.hour=7;p.min=0;p.sec=0;
   datetime first=StructToTime(p);
   p.day=1+(7-E2DayOfWeek(first))%7+(modern?7:0);
   datetime begins=StructToTime(p);
   p.mon=modern?11:10;p.day=1;p.hour=6;
   first=StructToTime(p);
   p.day=modern?1+(7-E2DayOfWeek(first))%7:31-(E2DayOfWeek(first)+30)%7;
   datetime ends=StructToTime(p);
   return(utc+((utc>=begins&&utc<ends)?-14400:-18000));
  }

#endif
