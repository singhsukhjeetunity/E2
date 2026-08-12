#ifndef E2_FILTERS_E2SESSIONFILTER_MQH
#define E2_FILTERS_E2SESSIONFILTER_MQH

#include "..\\core\\E2Config.mqh"

enum E2SessionStatus
  {
   E2_SESSION_VALID_SESSION,
   E2_SESSION_OUTSIDE_ENABLED_SESSIONS,
   E2_SESSION_NO_SESSIONS_ENABLED,
   E2_SESSION_WEEKEND,
   E2_SESSION_TIME_CONVERSION_FAILED,
   E2_SESSION_INVALID_CONFIGURATION
  };

string E2SessionStatusName(const E2SessionStatus status)
  {
   switch(status)
     {
      case E2_SESSION_VALID_SESSION: return("VALID_SESSION");
      case E2_SESSION_OUTSIDE_ENABLED_SESSIONS: return("OUTSIDE_ENABLED_SESSIONS");
      case E2_SESSION_NO_SESSIONS_ENABLED: return("NO_SESSIONS_ENABLED");
      case E2_SESSION_WEEKEND: return("WEEKEND");
      case E2_SESSION_TIME_CONVERSION_FAILED: return("TIME_CONVERSION_FAILED");
      default: return("INVALID_CONFIGURATION");
     }
  }

struct E2SessionResult
  {
   datetime        source_time;
   datetime        utc_time;
   datetime        london_local_time;
   datetime        new_york_local_time;
   bool            london_enabled;
   bool            new_york_enabled;
   bool            in_london;
   bool            in_new_york;
   bool            eligible;
   E2SessionStatus status;
  };

class E2SessionFilter
  {
private:
   E2Config m_configuration;
   bool m_initialized;

   bool IsLeapYear(const int year) const
     {
      return((year%4==0 && year%100!=0) || year%400==0);
     }

   int DaysInMonth(const int year,const int month) const
     {
      const int days[]={31,28,31,30,31,30,31,31,30,31,30,31};
      if(month==2 && IsLeapYear(year)) return(29);
      return(days[month-1]);
     }

   // Sakamoto's Gregorian calendar calculation: Sunday=0 through Saturday=6.
   int DayOfWeek(const int year,const int month,const int day) const
     {
      const int offsets[]={0,3,2,5,0,3,5,1,4,6,2,4};
      int adjusted_year=year;
      if(month<3) adjusted_year--;
      return((adjusted_year+adjusted_year/4-adjusted_year/100+adjusted_year/400+offsets[month-1]+day)%7);
     }

   int LastSunday(const int year,const int month) const
     {
      for(int day=DaysInMonth(year,month);day>=1;day--)
         if(DayOfWeek(year,month,day)==0) return(day);
      return(0);
     }

   int NthSunday(const int year,const int month,const int occurrence) const
     {
      int first_sunday=1+(7-DayOfWeek(year,month,1))%7;
      return(first_sunday+(occurrence-1)*7);
     }

   datetime UtcDateTime(const int year,const int month,const int day,const int hour) const
     {
      MqlDateTime value;
      ZeroMemory(value);
      value.year=year;
      value.mon=month;
      value.day=day;
      value.hour=hour;
      return(StructToTime(value));
     }

   bool IsLondonDst(const datetime utc_time) const
     {
      MqlDateTime value;
      if(!TimeToStruct(utc_time,value)) return(false);
      const datetime start=UtcDateTime(value.year,3,LastSunday(value.year,3),1);
      const datetime end=UtcDateTime(value.year,10,LastSunday(value.year,10),1);
      return(utc_time>=start && utc_time<end);
     }

   bool IsNewYorkDst(const datetime utc_time) const
     {
      MqlDateTime value;
      if(!TimeToStruct(utc_time,value)) return(false);
      const datetime start=UtcDateTime(value.year,3,NthSunday(value.year,3,2),7);
      const datetime end=UtcDateTime(value.year,11,NthSunday(value.year,11,1),6);
      return(utc_time>=start && utc_time<end);
     }

   bool InWindow(const datetime local_time,const int start_hour,const int end_hour) const
     {
      MqlDateTime value;
      if(!TimeToStruct(local_time,value)) return(false);
      const int minute_of_day=value.hour*60+value.min;
      return(minute_of_day>=start_hour*60 && minute_of_day<end_hour*60);
     }

   bool HasValidWindows(void) const
     {
      return(m_configuration.london_session_start_hour>=0 && m_configuration.london_session_start_hour<24 &&
             m_configuration.london_session_end_hour>m_configuration.london_session_start_hour && m_configuration.london_session_end_hour<=24 &&
             m_configuration.new_york_session_start_hour>=0 && m_configuration.new_york_session_start_hour<24 &&
             m_configuration.new_york_session_end_hour>m_configuration.new_york_session_start_hour && m_configuration.new_york_session_end_hour<=24);
     }

   void Reset(E2SessionResult &result,const datetime source_time) const
     {
      ZeroMemory(result);
      result.source_time=source_time;
      result.status=E2_SESSION_TIME_CONVERSION_FAILED;
     }

public:
   E2SessionFilter(void):m_initialized(false) {}

   void Initialize(const E2Config &configuration)
     {
      m_configuration=configuration;
      m_initialized=true;
     }

   bool Evaluate(const datetime source_time,E2SessionResult &result) const
     {
      Reset(result,source_time);
      if(!m_initialized) return(false);
      result.london_enabled=m_configuration.enable_london_session;
      result.new_york_enabled=m_configuration.enable_new_york_session;
      if(!result.london_enabled && !result.new_york_enabled)
        {
         result.status=E2_SESSION_NO_SESSIONS_ENABLED;
         return(true);
        }
      if(!HasValidWindows())
        {
         result.status=E2_SESSION_INVALID_CONFIGURATION;
         return(true);
        }
      if(m_configuration.broker_utc_offset_hours < -14 || m_configuration.broker_utc_offset_hours > 14 || source_time<=0)
        return(true);

      result.utc_time=source_time;
      result.utc_time-=m_configuration.broker_utc_offset_hours*3600;
      MqlDateTime utc_parts;
      if(result.utc_time<=0 || !TimeToStruct(result.utc_time,utc_parts)) return(true);
      if(utc_parts.day_of_week==0 || utc_parts.day_of_week==6)
        {
         result.status=E2_SESSION_WEEKEND;
         return(true);
        }

      result.london_local_time=result.utc_time+(IsLondonDst(result.utc_time) ? 3600 : 0);
      result.new_york_local_time=result.utc_time+(IsNewYorkDst(result.utc_time) ? -4*3600 : -5*3600);
      result.in_london=result.london_enabled && InWindow(result.london_local_time,m_configuration.london_session_start_hour,m_configuration.london_session_end_hour);
      result.in_new_york=result.new_york_enabled && InWindow(result.new_york_local_time,m_configuration.new_york_session_start_hour,m_configuration.new_york_session_end_hour);
      result.eligible=(result.in_london || result.in_new_york);
      result.status=(result.eligible ? E2_SESSION_VALID_SESSION : E2_SESSION_OUTSIDE_ENABLED_SESSIONS);
      return(true);
     }
  };

#endif // E2_FILTERS_E2SESSIONFILTER_MQH
