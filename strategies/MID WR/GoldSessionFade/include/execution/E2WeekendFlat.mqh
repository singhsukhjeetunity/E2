#ifndef E2_EXECUTION_E2WEEKENDFLAT_MQH
#define E2_EXECUTION_E2WEEKENDFLAT_MQH

#include "..\\core\\E2Config.mqh"
#include "..\\reporting\\E2Logger.mqh"

class E2WeekendFlat
  {
private:
   bool m_enabled,m_resolved;
   int m_minutes;
   string m_symbol;
   E2Logger *m_logger;
   datetime m_cached_friday,m_friday_close,m_cutoff,m_resume,m_logged_friday,m_failed_friday,m_last_close_attempt;
   ulong m_last_close_ticket;

   datetime DayStart(const datetime value)const
     {MqlDateTime p;if(!TimeToStruct(value,p))return(0);p.hour=0;p.min=0;p.sec=0;return(StructToTime(p));}
   datetime MostRecentFriday(const datetime value)const
     {MqlDateTime p;if(!TimeToStruct(value,p))return(0);datetime start=DayStart(value);int back=(p.day_of_week-5+7)%7;return(start-back*86400);}
   int SessionSeconds(const datetime value)const
     {long v=(long)value;int seconds=(int)(v%86400);return(seconds<0?seconds+86400:seconds);}
   bool Resolve(const datetime friday)
     {
      if(friday<=0)return(false);if(friday==m_cached_friday)return(m_resolved);m_cached_friday=friday;m_resolved=false;m_friday_close=0;m_cutoff=0;m_resume=0;
      for(uint i=0;;i++){datetime from=0,to=0;ResetLastError();if(!SymbolInfoSessionTrade(m_symbol,FRIDAY,i,from,to))break;int fs=SessionSeconds(from),ts=SessionSeconds(to);datetime end=friday+ts;if(ts<=fs)end+=86400;if(end>m_friday_close)m_friday_close=end;}
      if(m_friday_close<=friday){LogFailure(friday,"NO_VALID_FRIDAY_SESSION_CLOSE");return(false);}
      for(int offset=1;offset<=7&&m_resume==0;offset++){ENUM_DAY_OF_WEEK day=(ENUM_DAY_OF_WEEK)((5+offset)%7);for(uint i=0;;i++){datetime from=0,to=0;if(!SymbolInfoSessionTrade(m_symbol,day,i,from,to))break;datetime start=friday+offset*86400+SessionSeconds(from);if(start>m_friday_close&&(m_resume==0||start<m_resume))m_resume=start;}}
      if(m_resume<=m_friday_close){LogFailure(friday,"NO_VALID_NEXT_SESSION_OPEN");return(false);}m_cutoff=m_friday_close-m_minutes*60;if(m_cutoff<friday)m_cutoff=friday;m_resolved=true;return(true);
     }
   void LogFailure(const datetime friday,const string reason)
     {if(m_logger==NULL||m_failed_friday==friday)return;m_failed_friday=friday;m_logger.Error("reason="+reason+", symbol="+m_symbol+", serverTime="+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+".","WEEKEND_FLAT");}
   void LogSchedule(const datetime friday,const datetime basis)
     {if(m_logger==NULL||m_logged_friday==friday)return;if(basis<m_cutoff-86400)return;m_logged_friday=friday;m_logger.Info("symbol="+m_symbol+", fridaySessionClose="+TimeToString(m_friday_close,TIME_DATE|TIME_SECONDS)+", cutoff="+TimeToString(m_cutoff,TIME_DATE|TIME_SECONDS)+", resume="+TimeToString(m_resume,TIME_DATE|TIME_SECONDS)+", serverTimeBasis="+TimeToString(basis,TIME_DATE|TIME_SECONDS)+".","WEEKEND_FLAT");}
public:
   E2WeekendFlat(void):m_enabled(false),m_resolved(false),m_minutes(30),m_symbol(""),m_logger(NULL),m_cached_friday(0),m_friday_close(0),m_cutoff(0),m_resume(0),m_logged_friday(0),m_failed_friday(0),m_last_close_attempt(0),m_last_close_ticket(0){}
   void Initialize(const E2Config &config,const string symbol,E2Logger &logger)
     {m_enabled=config.weekend_flat_enabled;m_minutes=config.weekend_flat_minutes_before_session_close;m_symbol=symbol;m_logger=&logger;m_cached_friday=0;m_resolved=false;m_logged_friday=0;m_failed_friday=0;m_last_close_attempt=0;m_last_close_ticket=0;logger.Info("enabled="+IntegerToString((int)m_enabled)+", minutes_before_close="+IntegerToString(m_minutes)+".","WEEKEND_FLAT");}
   bool IsBlockedAt(const datetime server_time)
     {if(!m_enabled||server_time<=0)return(false);datetime friday=MostRecentFriday(server_time);if(!Resolve(friday))return(false);LogSchedule(friday,server_time);return(server_time>=m_cutoff&&server_time<m_resume);}
   bool ShouldAttemptClose(const ulong ticket,const datetime server_time)
     {if(ticket==0||!IsBlockedAt(server_time))return(false);if(ticket==m_last_close_ticket&&server_time-m_last_close_attempt<10)return(false);m_last_close_ticket=ticket;m_last_close_attempt=server_time;return(true);}
   void LogEntryBlock(const string candidate_id,const datetime server_time){if(m_logger!=NULL)m_logger.Warning("candidateId="+candidate_id+", serverTime="+TimeToString(server_time,TIME_DATE|TIME_SECONDS)+".","WEEKEND_CUTOFF_ENTRY_BLOCK");}
   void LogExpire(const string identity,const datetime server_time){if(m_logger!=NULL)m_logger.Warning("identity="+identity+", serverTime="+TimeToString(server_time,TIME_DATE|TIME_SECONDS)+".","WEEKEND_CUTOFF_EXPIRE");}
   bool Enabled(void)const{return(m_enabled);}datetime Cutoff(void)const{return(m_cutoff);}datetime Resume(void)const{return(m_resume);}
  };

#endif
