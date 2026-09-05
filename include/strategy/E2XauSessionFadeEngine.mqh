#ifndef E2_XAU_SESSION_FADE_ENGINE_MQH
#define E2_XAU_SESSION_FADE_ENGINE_MQH

#include "E2StrategyTypes.mqh"
#include "E2PositionRecovery.mqh"
#include "..\\core\\E2Config.mqh"
#include "..\\time\\E2LondonTime.mqh"
#include "..\\execution\\E2WeekendFlat.mqh"

class E2XauSessionRange
  {
private:
   E2Config m_config;
   int m_day,m_count,m_next_minute;
   double m_high,m_low;
   bool m_frozen,m_valid;
public:
   void Initialize(const E2Config &config){m_config=config;Reset(0);}
   void Reset(const int day){m_day=day;m_count=0;m_next_minute=m_config.xau_range_start;m_high=0.0;m_low=0.0;m_frozen=false;m_valid=true;}
   void Observe(const datetime server_open,const double high,const double low)
     {
      int day=E2CalendarDay(server_open),minute=E2MinuteOfDay(server_open);
      if(day!=m_day)Reset(day);
      if(!m_frozen&&minute>=m_config.xau_range_start&&minute<m_config.xau_range_end)
        {
         if(minute!=m_next_minute||high<low||low<=0.0)m_valid=false;
         if(m_count==0){m_high=high;m_low=low;}else{m_high=MathMax(m_high,high);m_low=MathMin(m_low,low);}
         m_count++;m_next_minute=minute+5;
        }
      if(!m_frozen&&minute+5>=m_config.xau_range_end)
        {
         m_frozen=true;
         m_valid=m_valid&&m_count==(m_config.xau_range_end-m_config.xau_range_start)/5&&m_high>m_low;
        }
     }
   bool Signal(const datetime server_open,const double close)const
     {
      int minute=E2MinuteOfDay(server_open);
      return(E2CalendarDay(server_open)==m_day&&m_frozen&&m_valid&&minute>=m_config.xau_range_end&&close<m_low);
     }
   int Day()const{return(m_day);}
   double High()const{return(m_high);}
   double Low()const{return(m_low);}
   bool Frozen()const{return(m_frozen);}
   bool Valid()const{return(m_valid);}
  };

class E2XauSessionFadeEngine
  {
private:
   E2Config m_config;string m_symbol;
   E2WeekendFlat *m_weekend;E2Logger *m_logger;
   E2XauSessionRange m_range;datetime m_last;int m_atr,m_signaled_day;
   E2SignalVerification m_verify;

   bool TrendEfficient(const datetime bar_time,const double threshold)
     {
      int shift=iBarShift(m_symbol,PERIOD_M5,bar_time,true);
      if(shift<1)return(false);
      int lookback=m_config.xau_trend_lookback_bars;
      double closes[];
      ArrayResize(closes,lookback+1);
      for(int i=0;i<=lookback;i++)
        {
         closes[i]=iClose(m_symbol,PERIOD_M5,shift+i);
         if(closes[i]<=0.0||!MathIsValidNumber(closes[i]))return(false);
        }
      double path=0.0;
      for(int i=0;i<lookback;i++)path+=MathAbs(closes[i]-closes[i+1]);
      if(path<=0.0||!MathIsValidNumber(path))return(false);
      double efficiency=MathAbs(closes[0]-closes[lookback])/path;
      return(efficiency>=threshold);
     }

   bool Process(const MqlRates &bar,const bool emit,E2Candidate &candidate,bool &found)
     {
      found=false;
      m_range.Observe(bar.time,bar.high,bar.low);
      m_verify.bars_observed++;
      if(!emit)return(true);
      if(m_signaled_day==m_range.Day())return(true);
      if(!m_range.Signal(bar.time,bar.close))return(true);
      if(!TrendEfficient(bar.time,m_config.xau_trend_efficiency_min))return(true);
      datetime known=bar.time+300;
      if(m_weekend.IsBlockedAt(known)||m_weekend.IsBlockedAt(TimeCurrent())){m_weekend.LogExpire("XAU_SF|"+IntegerToString((long)bar.time),known);return(true);}
      int shift=iBarShift(m_symbol,PERIOD_M5,bar.time,true);double values[];
      if(shift<1||CopyBuffer(m_atr,0,shift,1,values)!=1||values[0]<=0.0||!MathIsValidNumber(values[0]))return(false);
      ZeroMemory(candidate);
      candidate.symbol=m_symbol;candidate.timeframe="M5";candidate.london_day=m_range.Day();
      candidate.candidate_id="XAU_SF|"+m_symbol+"|"+IntegerToString(candidate.london_day)+"|"+IntegerToString((long)bar.time)+"|LONG";
      candidate.direction=E2_DIRECTION_LONG;candidate.signal_bar_time=bar.time;candidate.signal_known_time=known;
      candidate.signal_close=bar.close;candidate.range_start_london=E2LocalMidnight(bar.time)+m_config.xau_range_start*60;
      candidate.range_end_london=E2LocalMidnight(bar.time)+m_config.xau_range_end*60;
      candidate.range_high=m_range.High();candidate.range_low=m_range.Low();
      candidate.breakout_distance=m_range.Low()-bar.close;
      candidate.atr=values[0];candidate.atr_multiplier=m_config.xau_atr_multiplier;
      candidate.risk_distance=values[0]*m_config.xau_atr_multiplier;
      candidate.execution_window_start=known;candidate.execution_window_end=known+300;
      m_verify.total_candidates++;m_verify.long_candidates++;
      m_signaled_day=m_range.Day();
      found=true;
      return(true);
     }
public:
   E2XauSessionFadeEngine(void):m_weekend(NULL),m_logger(NULL),m_last(0),m_atr(INVALID_HANDLE),m_signaled_day(0){ZeroMemory(m_verify);}
   bool Initialize(const string symbol,const E2Config &config,E2WeekendFlat &weekend,E2Logger &logger)
     {
      m_config=config;m_symbol=symbol;m_weekend=&weekend;m_logger=&logger;m_last=0;m_signaled_day=0;ZeroMemory(m_verify);
      m_range.Initialize(config);
      m_atr=iATR(symbol,PERIOD_M5,config.xau_atr_length);
      if(m_atr==INVALID_HANDLE)return(false);
      datetime now=TimeCurrent();
      MqlRates bars[];ArraySetAsSeries(bars,false);
      int count=CopyRates(symbol,PERIOD_M5,now-2*86400,now-1,bars);
      if(count<0)return(false);
      int today=E2CalendarDay(now);
      for(int i=0;i<count;i++)
        {
         if(bars[i].time+300>now)continue;
         if(E2CalendarDay(bars[i].time)!=today)continue;
         E2Candidate unused;bool found;if(!Process(bars[i],false,unused,found))return(false);
        }
      m_last=iTime(symbol,PERIOD_M5,1);
      logger.Info("serverDay="+IntegerToString(today)+", rangeFrozen="+IntegerToString((int)m_range.Frozen())+", rangeValid="+IntegerToString((int)m_range.Valid())+", restartSignalsReplayed=0.","XAU_SF_STATE");
      return(true);
     }
   bool Evaluate(E2Candidate &out[],E2PositionRecovery &recovery)
     {
      ArrayResize(out,0);
      datetime latest=iTime(m_symbol,PERIOD_M5,1);
      if(latest<=0||latest<=m_last)return(false);
      bool allow_entry=!recovery.DayConsumed(TimeCurrent());
      MqlRates bars[];ArraySetAsSeries(bars,false);
      int n=CopyRates(m_symbol,PERIOD_M5,m_last+1,latest,bars);
      if(n<=0)return(false);
      for(int i=0;i<n;i++)
        {
         if(bars[i].time+300>TimeCurrent())continue;
         E2Candidate c;bool found;
         bool emit=(allow_entry&&bars[i].time==latest&&TimeCurrent()<bars[i].time+600&&iTime(m_symbol,PERIOD_M5,0)==bars[i].time+300);
         if(!Process(bars[i],emit,c,found))return(false);
         m_last=bars[i].time;
         if(found){int size=ArraySize(out);ArrayResize(out,size+1);out[size]=c;}
        }
      return(ArraySize(out)>0);
     }
   E2SignalVerification SignalVerification()const{return(m_verify);}
   void Shutdown(){if(m_atr!=INVALID_HANDLE){IndicatorRelease(m_atr);m_atr=INVALID_HANDLE;}}
  };

#endif
