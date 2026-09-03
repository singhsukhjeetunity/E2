#ifndef E2_LONDON_BREAKOUT_ENGINE_MQH
#define E2_LONDON_BREAKOUT_ENGINE_MQH
#include "E2StrategyTypes.mqh"
#include "E2PositionRecovery.mqh"
#include "..\\core\\E2Config.mqh"
#include "..\\time\\E2BrokerTimeAdapter.mqh"
#include "..\\execution\\E2WeekendFlat.mqh"

class E2LondonRange
{
private:
   E2Config m_config;
   int m_day,m_count,m_next_minute;
   double m_high,m_low;
   bool m_frozen,m_valid;
public:
   void Initialize(const E2Config &config){m_config=config;Reset(0);}
   void Reset(const int day){m_day=day;m_count=0;m_next_minute=m_config.range_start;m_high=0;m_low=0;m_frozen=false;m_valid=true;}
   // Pure alpha/session API: receives London-local timestamps only.
   void Observe(const datetime london_open,const double high,const double low)
   {
      int day=E2CalendarDay(london_open),minute=E2MinuteOfDay(london_open);
      if(day!=m_day)Reset(day);
      if(!m_frozen&&minute>=m_config.range_start&&minute<m_config.range_end)
      {
         if(minute!=m_next_minute||high<low||low<=0)m_valid=false;
         if(m_count==0){m_high=high;m_low=low;}else{m_high=MathMax(m_high,high);m_low=MathMin(m_low,low);}
         m_count++;m_next_minute=minute+5;
      }
      if(!m_frozen&&minute+5>=m_config.range_end)
      {
         m_frozen=true;
         m_valid=m_valid&&m_count==(m_config.range_end-m_config.range_start)/5&&m_high>m_low;
      }
   }
   bool Signal(const datetime london_open,const double close,E2TradeDirection &direction)const
   {
      direction=E2_DIRECTION_NONE;int minute=E2MinuteOfDay(london_open);
      if(E2CalendarDay(london_open)!=m_day||!m_frozen||!m_valid||minute<m_config.breakout_start||minute>=m_config.breakout_end)return(false);
      if(close>m_high)direction=E2_DIRECTION_LONG;else if(close<m_low)direction=E2_DIRECTION_SHORT;
      return(direction!=E2_DIRECTION_NONE);
   }
   int Day()const{return(m_day);}
   double High()const{return(m_high);}
   double Low()const{return(m_low);}
   bool Frozen()const{return(m_frozen);}
   bool Valid()const{return(m_valid);}
   string StateFingerprint()const{return(StringFormat("%d|%d|%d|%.16f|%.16f|%d|%d",m_day,m_count,m_next_minute,m_high,m_low,(int)m_frozen,(int)m_valid));}
};

class E2LondonBreakoutEngine
{
private:
   E2Config m_config;string m_symbol;
   E2BrokerTimeAdapter *m_time;E2WeekendFlat *m_weekend;E2Logger *m_logger;
   E2LondonRange m_range;datetime m_last,m_last_error;int m_atr;
   E2SignalVerification m_verify;
   bool TimeError(const datetime now)
   {
      m_verify.time_failures++;
      if(m_last_error==0||now-m_last_error>=300){m_logger.Error("Timestamp outside configured coverage or ambiguous; new signals disabled.","LRB_TIME");m_last_error=now;}
      return(false);
   }
   bool Process(const MqlRates &bar,const bool emit,E2Candidate &candidate,bool &found)
   {
      found=false;datetime local;
      if(!m_time.London(bar.time,local))return(TimeError(TimeCurrent()));
      m_range.Observe(local,bar.high,bar.low);m_verify.bars_observed++;
      if(!emit)return(true);
      E2TradeDirection direction;if(!m_range.Signal(local,bar.close,direction))return(true);
      datetime known=bar.time+300;
      // Stored/historical signals are never queued through a weekend or replayed Monday.
      if(m_weekend.IsBlockedAt(known)||m_weekend.IsBlockedAt(TimeCurrent())){m_weekend.LogExpire("LRB|"+IntegerToString((long)bar.time),known);return(true);}
      ZeroMemory(candidate);candidate.symbol=m_symbol;candidate.timeframe="M5";candidate.london_day=m_range.Day();
      candidate.candidate_id="LRB|"+m_symbol+"|"+IntegerToString(candidate.london_day)+"|"+IntegerToString((long)bar.time)+"|"+E2TradeDirectionName(direction);
      candidate.direction=direction;candidate.signal_bar_time=bar.time;candidate.signal_known_time=known;candidate.signal_close=bar.close;
      candidate.range_start_london=E2LocalMidnight(local)+m_config.range_start*60;
      candidate.range_end_london=E2LocalMidnight(local)+m_config.range_end*60;
      candidate.range_high=m_range.High();candidate.range_low=m_range.Low();
      candidate.breakout_distance=(direction==E2_DIRECTION_LONG?bar.close-m_range.High():m_range.Low()-bar.close);
      candidate.atr_multiplier=m_config.atr_multiplier;
      if(m_config.stop_mode==ATR)
      {
         int shift=iBarShift(m_symbol,PERIOD_M5,bar.time,true);double values[];
         if(shift<1||CopyBuffer(m_atr,0,shift,1,values)!=1||values[0]<=0||!MathIsValidNumber(values[0]))return(false);
         candidate.atr=values[0];candidate.risk_distance=values[0]*m_config.atr_multiplier;
      }
      else candidate.risk_distance=candidate.range_high-candidate.range_low;
      candidate.execution_window_start=known;candidate.execution_window_end=known+300;
      m_verify.total_candidates++;if(direction==E2_DIRECTION_LONG)m_verify.long_candidates++;else m_verify.short_candidates++;
      found=true;return(true);
   }
public:
   E2LondonBreakoutEngine(void):m_time(NULL),m_weekend(NULL),m_logger(NULL),m_last(0),m_last_error(0),m_atr(INVALID_HANDLE){ZeroMemory(m_verify);}
   bool Initialize(const string symbol,const E2Config &config,E2BrokerTimeAdapter &time,E2WeekendFlat &weekend,E2Logger &logger)
   {
      m_config=config;m_symbol=symbol;m_time=&time;m_weekend=&weekend;m_logger=&logger;m_last=0;m_last_error=0;ZeroMemory(m_verify);
      m_range.Initialize(config);
      datetime now=TimeCurrent(),local,utc;
      if(!time.London(now,local)||!time.ServerToUtc(now,utc))return(false);
      // Exact reconstruction needs current London midnight and all subsequent closed M5 bars.
      datetime start_utc=(datetime)((long)utc-((long)local-(long)E2LocalMidnight(local))-3600);
      if(start_utc<time.CoverageStart()){logger.Error("Profile does not cover today's complete range reconstruction.","LRB_INIT");return(false);}
      if(config.stop_mode==ATR){m_atr=iATR(symbol,PERIOD_M5,config.atr_length);if(m_atr==INVALID_HANDLE)return(false);}
      MqlRates bars[];ArraySetAsSeries(bars,false);
      int count=CopyRates(symbol,PERIOD_M5,now-2*86400,now-1,bars);
      if(count<0)
      {
         // An interval wholly inside a weekend/holiday can be empty although
         // synchronized history exists. Do not confuse that with missing history.
         MqlRates previous[];
         if(CopyRates(symbol,PERIOD_M5,1,1,previous)!=1||previous[0].time>=now-2*86400)
            {logger.Error("Completed M5 reconstruction history unavailable.","LRB_INIT");return(false);}
         count=0;
      }
      int today=E2CalendarDay(local);
      for(int i=0;i<count;i++)
      {
         if(bars[i].time+300>now)continue;
         datetime b_local,bu;
         // Old days are not required. Coverage errors in the current-day neighborhood fail closed.
         if(!time.ServerToUtc(bars[i].time,bu)){if(bars[i].time>now-28*3600)return(false);continue;}
         if(!E2UtcToLondon(bu,b_local))return(false);
         if(E2CalendarDay(b_local)!=today)continue;
         E2Candidate unused;bool found;if(!Process(bars[i],false,unused,found))return(false);
      }
      // No entry on startup from a candle completed before attachment/restart.
      m_last=iTime(symbol,PERIOD_M5,1);
      logger.Info("LondonDay="+IntegerToString(today)+", rangeBarsRebuiltFromHistory=1, frozen="+IntegerToString((int)m_range.Frozen())+", rangeValid="+IntegerToString((int)m_range.Valid())+", restartSignalsReplayed=0.","LRB_STATE");
      return(true);
   }
   bool Evaluate(E2Candidate &out[],E2PositionRecovery &recovery)
   {
      ArrayResize(out,0);datetime local;if(!m_time.London(TimeCurrent(),local))return(TimeError(TimeCurrent()));
      datetime latest=iTime(m_symbol,PERIOD_M5,1);if(latest<=0||latest<=m_last)return(false);
      bool allow_entry=!recovery.DayConsumed(TimeCurrent());
      MqlRates bars[];ArraySetAsSeries(bars,false);
      int n=CopyRates(m_symbol,PERIOD_M5,m_last+1,latest,bars);if(n<=0)return(false);
      for(int i=0;i<n;i++)
      {
         if(bars[i].time+300>TimeCurrent())continue;
         E2Candidate c;bool found;
         // Replay missed bars solely to rebuild range; only the latest executable bar may signal.
         bool emit=(allow_entry&&bars[i].time==latest&&TimeCurrent()<bars[i].time+600&&iTime(m_symbol,PERIOD_M5,0)==bars[i].time+300);
         if(!Process(bars[i],emit,c,found))return(false);
         m_last=bars[i].time;
         if(found){int size=ArraySize(out);ArrayResize(out,size+1);out[size]=c;}
      }
      return(ArraySize(out)>0);
   }
   E2SignalVerification SignalVerification()const{return(m_verify);}
   string RangeState()const{return(m_range.StateFingerprint());}
   void Shutdown(){if(m_atr!=INVALID_HANDLE){IndicatorRelease(m_atr);m_atr=INVALID_HANDLE;}}
};
#endif
