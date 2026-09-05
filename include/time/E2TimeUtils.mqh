#ifndef E2_TIME_UTILS_MQH
#define E2_TIME_UTILS_MQH

const datetime E2_TIME_FROM=820454400,E2_TIME_UNTIL=2145916800;

int E2CalendarDay(const datetime value){MqlDateTime p;if(!TimeToStruct(value,p))return(0);return(p.year*10000+p.mon*100+p.day);}
int E2MinuteOfDay(const datetime value){MqlDateTime p;if(!TimeToStruct(value,p))return(-1);return(p.hour*60+p.min);}
datetime E2LocalMidnight(const datetime value){MqlDateTime p;if(!TimeToStruct(value,p))return(0);p.hour=0;p.min=0;p.sec=0;return(StructToTime(p));}

#endif
