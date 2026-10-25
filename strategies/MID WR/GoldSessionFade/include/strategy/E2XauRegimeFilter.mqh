#ifndef E2_XAU_REGIME_FILTER_MQH
#define E2_XAU_REGIME_FILTER_MQH

#include "E2StrategyTypes.mqh"
#include "..\\core\\E2Config.mqh"
#include "..\\reporting\\E2Logger.mqh"

struct E2XauRegimeObservation
  {
   datetime known_time;
   double ratio;
  };

string E2XauRegimeFilterModeName(const E2XauRegimeFilterMode mode)
  {
   if(mode==E2_XAU_REGIME_BLOCK_UNFAVOURABLE)return("BLOCK_UNFAVOURABLE");
   if(mode==E2_XAU_REGIME_FAVOURABLE_ONLY)return("FAVOURABLE_ONLY");
   return("OFF");
  }

string E2XauRegimeLookbackModeName(const E2XauRegimeLookbackMode mode)
  {
   if(mode==E2_XAU_REGIME_LOOKBACK_3_MONTHS)return("CALENDAR_3_MONTHS");
   if(mode==E2_XAU_REGIME_LOOKBACK_12_MONTHS)return("CALENDAR_12_MONTHS");
   if(mode==E2_XAU_REGIME_LOOKBACK_N_OBSERVATIONS)return("N_OBSERVATIONS");
   return("CALENDAR_6_MONTHS");
  }

class E2XauRegimeFilter
  {
private:
   E2Config m_config;
   E2Logger *m_logger;
   E2XauRegimeObservation m_observations[];
   bool m_ready_logged;

   int DaysInMonth(const int year,const int month)const
     {
      if(month==2)
        {
         bool leap=(year%400==0)||(year%4==0&&year%100!=0);
         return(leap?29:28);
        }
      if(month==4||month==6||month==9||month==11)return(30);
      return(31);
     }

   datetime SubtractCalendarMonths(const datetime value,const int months)const
     {
      MqlDateTime dt;
      if(!TimeToStruct(value,dt))return(value-months*31*86400);
      int total=dt.year*12+(dt.mon-1)-months;
      int year=total/12;
      int month=total%12+1;
      if(month<=0){month+=12;year--;}
      dt.year=year;
      dt.mon=month;
      dt.day=MathMin(dt.day,DaysInMonth(year,month));
      return(StructToTime(dt));
     }

   int LookbackMonths()const
     {
      if(m_config.xau_regime_lookback_mode==E2_XAU_REGIME_LOOKBACK_3_MONTHS)return(3);
      if(m_config.xau_regime_lookback_mode==E2_XAU_REGIME_LOOKBACK_12_MONTHS)return(12);
      return(6);
     }

   void Snapshot(const datetime known_time,double &average,int &count)const
     {
      average=0.0;
      count=0;
      double sum=0.0;
      const int total=ArraySize(m_observations);
      if(m_config.xau_regime_lookback_mode==E2_XAU_REGIME_LOOKBACK_N_OBSERVATIONS)
        {
         int limit=MathMin(m_config.xau_regime_observation_lookback,total);
         for(int i=total-limit;i<total;i++)
           {
            if(i<0||m_observations[i].known_time>=known_time)continue;
            sum+=m_observations[i].ratio;
            count++;
           }
        }
      else
        {
         datetime cutoff=SubtractCalendarMonths(known_time,LookbackMonths());
         for(int i=0;i<total;i++)
           {
            if(m_observations[i].known_time<cutoff||m_observations[i].known_time>=known_time)continue;
            sum+=m_observations[i].ratio;
            count++;
           }
        }
      if(count>0)average=sum/count;
     }

   string StateName(const double average,const bool ready)const
     {
      if(!ready)return("REGIME_NOT_READY");
      if(average<m_config.xau_regime_unfavourable_threshold)return("UNFAVOURABLE");
      if(average<m_config.xau_regime_favourable_threshold)return("NEUTRAL");
      if(average<m_config.xau_regime_very_favourable_threshold)return("FAVOURABLE");
      return("VERY_FAVOURABLE");
     }

   bool Allowed(const double average,const bool ready)const
     {
      if(m_config.xau_regime_filter_mode==E2_XAU_REGIME_OFF)return(true);
      if(!ready)return(m_config.xau_regime_allow_until_ready);
      if(m_config.xau_regime_filter_mode==E2_XAU_REGIME_BLOCK_UNFAVOURABLE)
         return(average>=m_config.xau_regime_unfavourable_threshold);
      return(average>=m_config.xau_regime_favourable_threshold);
     }

   void Append(const datetime known_time,const double ratio)
     {
      int n=ArraySize(m_observations);
      ArrayResize(m_observations,n+1);
      m_observations[n].known_time=known_time;
      m_observations[n].ratio=ratio;
     }

public:
   E2XauRegimeFilter(void):m_logger(NULL),m_ready_logged(false){ArrayResize(m_observations,0);}

   void Initialize(const E2Config &config,E2Logger &logger)
     {
      m_config=config;
      m_logger=&logger;
      m_ready_logged=false;
      ArrayResize(m_observations,0);
     }

   datetime ReplayStart(const datetime now)const
     {
      if(m_config.xau_regime_lookback_mode==E2_XAU_REGIME_LOOKBACK_N_OBSERVATIONS)
        {
         int days=MathMax(365,m_config.xau_regime_observation_lookback*5);
         days=MathMin(days,3650);
         return(now-(datetime)days*86400);
        }
      // Extra buffer lets the first classified setup have a complete selected window
      // when broker history before the requested test start is available.
      return(SubtractCalendarMonths(now,LookbackMonths())-7*86400);
     }

   bool Assess(E2Candidate &candidate,const bool emit_log)
     {
      double width=candidate.range_high-candidate.range_low;
      if(width<=0.0||!MathIsValidNumber(width)||candidate.extension_distance<0.0||!MathIsValidNumber(candidate.extension_distance))
         return(false);

      candidate.extension_ratio=candidate.extension_distance/width;

      double average=0.0;
      int count=0;
      Snapshot(candidate.signal_known_time,average,count);

      candidate.regime_trailing_ratio=average;
      candidate.regime_observations=count;
      candidate.regime_ready=(count>=m_config.xau_regime_minimum_observations?1:0);
      candidate.regime_state=StateName(average,candidate.regime_ready!=0);
      candidate.regime_allowed=(Allowed(average,candidate.regime_ready!=0)?1:0);
      candidate.regime_decision=(candidate.regime_allowed!=0?"ALLOWED":"BLOCKED");

      if(emit_log&&m_logger!=NULL)
        {
         if(candidate.regime_ready!=0&&!m_ready_logged)
           {
            m_ready_logged=true;
            m_logger.Info("observations="+IntegerToString(count)+", trailingRatio="+DoubleToString(average,6)+
               ", lookback="+E2XauRegimeLookbackModeName(m_config.xau_regime_lookback_mode)+".","XAU_REGIME_READY");
           }
         m_logger.Info("candidateId="+candidate.candidate_id+
            ", rangeWidth="+DoubleToString(width,10)+
            ", extensionDistance="+DoubleToString(candidate.extension_distance,10)+
            ", extensionRatio="+DoubleToString(candidate.extension_ratio,6)+
            ", trailingRatio="+DoubleToString(candidate.regime_trailing_ratio,6)+
            ", observations="+IntegerToString(candidate.regime_observations)+
            ", regimeState="+candidate.regime_state+
            ", filterMode="+E2XauRegimeFilterModeName(m_config.xau_regime_filter_mode)+
            ", decision="+candidate.regime_decision+
            ", setupValid=true.","XAU_REGIME");
        }

      // Causality: add the current setup only after its decision has been made.
      Append(candidate.signal_known_time,candidate.extension_ratio);
      return(true);
     }

   int ObservationCount()const{return(ArraySize(m_observations));}
  };

#endif
