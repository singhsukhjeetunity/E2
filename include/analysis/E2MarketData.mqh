#ifndef E2_ANALYSIS_E2MARKETDATA_MQH
#define E2_ANALYSIS_E2MARKETDATA_MQH

#include "..\\core\\E2Config.mqh"
#include "..\\reporting\\E2Logger.mqh"

// The market-data boundary uses MqlRates directly. For GetClosedBar(),
// closed_shift 0 means the platform's most recently closed bar (series shift
// 1); it never means the still-forming series bar at platform shift 0.
//
// GetClosedBars() returns bars in chronological order: bars[0] is oldest and
// bars[ArraySize(bars)-1] is newest. The array is explicitly non-series.
class E2MarketData
  {
private:
   ENUM_TIMEFRAMES   m_trend_timeframe;
   ENUM_TIMEFRAMES   m_zone_timeframe;
   ENUM_TIMEFRAMES   m_confirmation_timeframe;
   E2Logger          *m_logger;

   void ReportDebug(const string message)
     {
      if(m_logger!=NULL)
         m_logger.Debug(message,"MarketData");
     }

   bool IsHistoryReady(const string symbol,const ENUM_TIMEFRAMES timeframe)
     {
      if(symbol=="")
        {
         ReportDebug("History request rejected because symbol is empty.");
         return(false);
        }

      long synchronized=0;
      if(!SeriesInfoInteger(symbol,timeframe,SERIES_SYNCHRONIZED,synchronized) || synchronized==0)
        {
         ReportDebug("History is not synchronized for "+symbol+" on "+EnumToString(timeframe)+".");
         return(false);
        }
      return(true);
     }

   bool CopySingleBar(const string symbol,const ENUM_TIMEFRAMES timeframe,const int platform_shift,MqlRates &bar)
     {
      if(platform_shift<0)
        {
         ReportDebug("History request rejected because the bar shift is negative.");
         return(false);
        }

      MqlRates rates[];
      ArraySetAsSeries(rates,false);
      ResetLastError();
      const int copied=CopyRates(symbol,timeframe,platform_shift,1,rates);
      if(copied!=1)
        {
         const int error_code=GetLastError();
         ReportDebug("Unable to read one "+EnumToString(timeframe)+" bar for "+symbol+" (copied "+IntegerToString(copied)+", error "+IntegerToString(error_code)+").");
         return(false);
        }

      bar=rates[0];
      return(true);
     }

public:
                     E2MarketData(void) : m_trend_timeframe(PERIOD_CURRENT),m_zone_timeframe(PERIOD_CURRENT),m_confirmation_timeframe(PERIOD_CURRENT),m_logger(NULL) {}

   void              Initialize(const E2Config &configuration,E2Logger &logger)
     {
      m_trend_timeframe=configuration.trend_timeframe;
      m_zone_timeframe=configuration.zone_timeframe;
      m_confirmation_timeframe=configuration.confirmation_timeframe;
      m_logger=&logger;
     }

   ENUM_TIMEFRAMES   TrendTimeframe(void) const
     {
      return(m_trend_timeframe);
     }

   ENUM_TIMEFRAMES   ZoneTimeframe(void) const
     {
      return(m_zone_timeframe);
     }

   ENUM_TIMEFRAMES   ConfirmationTimeframe(void) const
     {
      return(m_confirmation_timeframe);
     }

   bool              GetClosedBar(const string symbol,const ENUM_TIMEFRAMES timeframe,const int closed_shift,MqlRates &bar)
     {
      if(closed_shift<0 || !IsHistoryReady(symbol,timeframe))
         return(false);

      return(CopySingleBar(symbol,timeframe,closed_shift+1,bar));
     }

   bool              GetClosedBars(const string symbol,const ENUM_TIMEFRAMES timeframe,const int closed_shift,const int count,MqlRates &bars[])
     {
      ArrayResize(bars,0);
      ArraySetAsSeries(bars,false);

      if(closed_shift<0 || count<=0 || !IsHistoryReady(symbol,timeframe))
        {
         ReportDebug("History request rejected because its closed-bar range is invalid.");
         return(false);
        }

      ResetLastError();
      const int copied=CopyRates(symbol,timeframe,closed_shift+1,count,bars);
      if(copied!=count)
        {
         const int error_code=GetLastError();
         ArrayResize(bars,0);
         ReportDebug("Unable to read "+IntegerToString(count)+" "+EnumToString(timeframe)+" bars for "+symbol+" (copied "+IntegerToString(copied)+", error "+IntegerToString(error_code)+").");
         return(false);
        }

      return(true);
     }

   // Returns the bar whose opening time plus its timeframe duration is less
   // than or equal to evaluation_time. Therefore no bar still open at that
   // historical evaluation point can be returned.
   bool              GetClosedBarAsOf(const string symbol,const ENUM_TIMEFRAMES timeframe,const datetime evaluation_time,MqlRates &bar)
     {
      if(evaluation_time<=0 || !IsHistoryReady(symbol,timeframe))
        {
         ReportDebug("As-of history request rejected because its evaluation time is invalid or history is unavailable.");
         return(false);
        }

      const int seconds_per_bar=PeriodSeconds(timeframe);
      if(seconds_per_bar<=0)
        {
         ReportDebug("As-of history request rejected because timeframe duration is unavailable.");
         return(false);
        }

      int platform_shift=iBarShift(symbol,timeframe,evaluation_time,false);
      if(platform_shift<0)
        {
         ReportDebug("No "+EnumToString(timeframe)+" bar exists at or before the requested evaluation time.");
         return(false);
        }

      MqlRates candidate;
      if(!CopySingleBar(symbol,timeframe,platform_shift,candidate))
         return(false);

      if(candidate.time+seconds_per_bar>evaluation_time)
         platform_shift++;

      if(!CopySingleBar(symbol,timeframe,platform_shift,bar))
         return(false);

      if(bar.time+seconds_per_bar>evaluation_time)
        {
         ReportDebug("No closed "+EnumToString(timeframe)+" bar is available at the requested evaluation time.");
         return(false);
        }

      return(true);
     }

   bool              GetClosedBarsAsOf(const string symbol,const ENUM_TIMEFRAMES timeframe,const datetime evaluation_time,const int count,MqlRates &bars[])
     {
      ArrayResize(bars,0);
      ArraySetAsSeries(bars,false);
      if(count<=0)
         return(false);

      MqlRates latest_closed;
      if(!GetClosedBarAsOf(symbol,timeframe,evaluation_time,latest_closed))
         return(false);

      const int platform_shift=iBarShift(symbol,timeframe,latest_closed.time,true);
      if(platform_shift<0)
        {
         ReportDebug("Unable to locate the latest closed bar for an as-of history range.");
         return(false);
        }

      ResetLastError();
      const int copied=CopyRates(symbol,timeframe,platform_shift,count,bars);
      if(copied!=count)
        {
         const int error_code=GetLastError();
         ArrayResize(bars,0);
         ReportDebug("Unable to read the requested as-of history range (copied "+IntegerToString(copied)+", error "+IntegerToString(error_code)+").");
         return(false);
        }
      return(true);
     }
  };

#endif // E2_ANALYSIS_E2MARKETDATA_MQH
