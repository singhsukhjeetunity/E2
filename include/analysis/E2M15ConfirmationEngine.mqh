#ifndef E2_ANALYSIS_E2M15CONFIRMATIONENGINE_MQH
#define E2_ANALYSIS_E2M15CONFIRMATIONENGINE_MQH

#include "E2MarketData.mqh"
#include "E2H1ZoneEngine.mqh"

struct E2M15ZoneContext
  {
   string zone_id;
   E2H1ZoneV2Type type;
   E2H1ZoneV2State state;
   double lower,upper;
   datetime creation_time,invalidation_time;
  };

struct E2M15ConfirmationResult
  {
   E2ResearchConfirmationType type;
   bool passed,history_available,median_valid,zero_range,zone_validity_pass,direction_pass,body_multiplier_pass,body_range_pass,closing_location_pass,previous_break_pass,zone_edge_pass,zone_intersection_pass,wick_body_pass,wick_range_pass;
   datetime evaluation_time,candle_time,known_from_time;
   string zone_id,reason;
   E2H1ZoneV2Type zone_type;
   double zone_lower,zone_upper,open,high,low,close,body,range,body_range_ratio,close_location,previous_high,previous_low,median_body,body_multiplier,lower_wick,upper_wick,relevant_wick,wick_body_ratio,wick_range_ratio,relevant_zone_edge;
  };

class E2M15ConfirmationEngine
  {
private:
   E2MarketData *m_market;
   E2Logger *m_logger;
   int m_lookback; bool m_verbose;
   double m_body_multiplier,m_body_range_min,m_close_fraction,m_wick_body_min,m_wick_range_min;
   datetime m_cached_candle_time;
   bool m_cached_history;
   MqlRates m_cached_candle,m_cached_previous;
   double m_cached_median;
   ulong m_measurement_count;

   bool Valid(const MqlRates &bar) const { return(MathIsValidNumber(bar.open)&&MathIsValidNumber(bar.high)&&MathIsValidNumber(bar.low)&&MathIsValidNumber(bar.close)&&bar.high>=bar.low); }
   double Epsilon(const double value) const { return(MathMax(1e-10,MathAbs(value)*1e-10)); }
   bool GreaterOrEqual(const double left,const double right) const { return(left>right || MathAbs(left-right)<=Epsilon(right)); }
   void SortAscending(double &values[]) const
     { for(int i=1;i<ArraySize(values);i++){double value=values[i];int j=i-1;while(j>=0 && values[j]>value){values[j+1]=values[j];j--;}values[j+1]=value;} }
   bool MedianPrecedingBodies(const MqlRates &bars[],const int candidate,double &median) const
     {
      median=0.0;if(candidate<m_lookback)return(false);double bodies[];ArrayResize(bodies,m_lookback);
      for(int i=0;i<m_lookback;i++)bodies[i]=MathAbs(bars[candidate-m_lookback+i].close-bars[candidate-m_lookback+i].open);
     SortAscending(bodies);const int upper=m_lookback/2;median=(m_lookback%2==0 ? (bodies[upper-1]+bodies[upper])/2.0 : bodies[upper]);return(true);
     }
   bool PrepareCandleMeasurement(const string symbol,const datetime evaluation)
     {
      MqlRates bars[];
      if(!m_market.GetClosedBarsAsOf(symbol,PERIOD_M15,evaluation,m_lookback+1,bars))return(false);
      const int candidate=ArraySize(bars)-1;
      if(candidate<1)return(false);
      for(int i=0;i<ArraySize(bars);i++)if(!Valid(bars[i]))return(false);
      if(bars[candidate].time==m_cached_candle_time)return(true);
      m_cached_candle_time=bars[candidate].time;
      m_cached_candle=bars[candidate];m_cached_previous=bars[candidate-1];m_cached_median=0.0;
      m_cached_history=MedianPrecedingBodies(bars,candidate,m_cached_median);
      m_measurement_count++;
      return(true);
     }
   void Reset(E2M15ConfirmationResult &result,const E2ResearchConfirmationType type,const E2M15ZoneContext &zone,const datetime evaluation) const
     { ZeroMemory(result);result.type=type;result.evaluation_time=evaluation;result.zone_id=zone.zone_id;result.zone_type=zone.type;result.zone_lower=zone.lower;result.zone_upper=zone.upper;result.reason="NOT_EVALUATED"; }
   void FillMeasurements(E2M15ConfirmationResult &result,const MqlRates &candle,const MqlRates &previous,const double median) const
     {
      result.candle_time=candle.time;result.known_from_time=candle.time+PeriodSeconds(PERIOD_M15);result.open=candle.open;result.high=candle.high;result.low=candle.low;result.close=candle.close;result.body=MathAbs(candle.close-candle.open);result.range=candle.high-candle.low;result.previous_high=previous.high;result.previous_low=previous.low;result.median_body=median;
      result.zero_range=(result.range<=Epsilon(result.range));if(!result.zero_range){result.body_range_ratio=result.body/result.range;result.close_location=(result.close-result.low)/result.range;result.lower_wick=MathMin(result.open,result.close)-result.low;result.upper_wick=result.high-MathMax(result.open,result.close);}
      if(median>0.0)result.body_multiplier=result.body/median;
     }
   bool ZoneValidAt(const E2M15ZoneContext &zone,const datetime known) const
     { return(zone.zone_id!="" && zone.upper>=zone.lower && zone.creation_time<=known && (zone.state==E2_H1_ZONE_V2_ACTIVE || zone.invalidation_time>known)); }
   void EvaluateMomentum(E2M15ConfirmationResult &result,const E2M15ZoneContext &zone,const MqlRates &candle,const MqlRates &previous,const bool bullish) const
     {
      result.direction_pass=(bullish ? candle.close>candle.open : candle.close<candle.open);result.median_valid=(result.median_body>0.0);result.body_multiplier_pass=(result.median_valid && GreaterOrEqual(result.body,m_body_multiplier*result.median_body));
      if(!result.zero_range){result.body_range_pass=GreaterOrEqual(result.body_range_ratio,m_body_range_min);result.closing_location_pass=(bullish ? GreaterOrEqual(result.close_location,1.0-m_close_fraction) : GreaterOrEqual(m_close_fraction,result.close_location));}
      result.previous_break_pass=(bullish ? candle.close>previous.high : candle.close<previous.low);result.relevant_zone_edge=(bullish ? zone.upper : zone.lower);result.zone_edge_pass=(bullish ? candle.close>zone.upper : candle.close<zone.lower);
      result.passed=result.history_available && result.zone_validity_pass && !result.zero_range && result.direction_pass && result.body_multiplier_pass && result.body_range_pass && result.closing_location_pass && result.previous_break_pass && result.zone_edge_pass;
     }
   void EvaluateRejection(E2M15ConfirmationResult &result,const E2M15ZoneContext &zone,const MqlRates &candle,const bool bullish) const
     {
      result.direction_pass=(bullish ? candle.close>candle.open : candle.close<candle.open);result.zone_intersection_pass=(candle.low<=zone.upper && candle.high>=zone.lower);result.relevant_zone_edge=(bullish ? zone.upper : zone.lower);result.zone_edge_pass=(bullish ? candle.close>zone.upper : candle.close<zone.lower);
      result.relevant_wick=(bullish ? result.lower_wick : result.upper_wick);if(result.body>0.0)result.wick_body_ratio=result.relevant_wick/result.body;if(!result.zero_range)result.wick_range_ratio=result.relevant_wick/result.range;
      result.wick_body_pass=(result.body>0.0 && GreaterOrEqual(result.relevant_wick,m_wick_body_min*result.body));result.wick_range_pass=(!result.zero_range && GreaterOrEqual(result.wick_range_ratio,m_wick_range_min));
      const bool role_pass=(bullish ? zone.type==E2_H1_ZONE_V2_SUPPORT : zone.type==E2_H1_ZONE_V2_RESISTANCE);result.passed=result.zone_validity_pass && role_pass && !result.zero_range && result.direction_pass && result.zone_intersection_pass && result.zone_edge_pass && result.wick_body_pass && result.wick_range_pass;
     }
   void LogPassed(const E2M15ConfirmationResult &result) const
     {
      if(m_logger==NULL || !m_logger.IsDebugEnabled() || !m_verbose || !result.passed)return;
      m_logger.Debug("time="+TimeToString(result.candle_time,TIME_DATE|TIME_MINUTES)+", knownFrom="+TimeToString(result.known_from_time,TIME_DATE|TIME_MINUTES)+", zone="+result.zone_id+", type="+E2ResearchConfirmationTypeName(result.type)+", bodyMult="+DoubleToString(result.body_multiplier,2)+", bodyRange="+DoubleToString(result.body_range_ratio,2)+", closeLoc="+DoubleToString(result.close_location,2)+", prevBreak="+(result.previous_break_pass?"yes":"no")+", zoneBreak="+(result.zone_edge_pass?"yes":"no")+", PASS.","M15ConfirmV2");
     }
   void LogBoundaryFailure(const E2M15ConfirmationResult &result) const
     {
      if(m_logger==NULL || !m_logger.IsDebugEnabled() || !m_verbose || result.passed || !result.history_available || !result.zone_validity_pass || !result.direction_pass || result.zero_range)return;
      const bool momentum=(result.type==E2_RESEARCH_CONFIRMATION_BULLISH_MOMENTUM || result.type==E2_RESEARCH_CONFIRMATION_BEARISH_MOMENTUM);const bool threshold_failure=(momentum ? (!result.body_multiplier_pass || !result.body_range_pass || !result.closing_location_pass || !result.previous_break_pass || !result.zone_edge_pass) : (!result.wick_body_pass || !result.wick_range_pass || !result.zone_intersection_pass || !result.zone_edge_pass));
      if(threshold_failure)m_logger.Debug("time="+TimeToString(result.candle_time,TIME_DATE|TIME_MINUTES)+", zone="+result.zone_id+", type="+E2ResearchConfirmationTypeName(result.type)+", bodyMult="+DoubleToString(result.body_multiplier,2)+", bodyRange="+DoubleToString(result.body_range_ratio,2)+", closeLoc="+DoubleToString(result.close_location,2)+", wickBody="+DoubleToString(result.wick_body_ratio,2)+", wickRange="+DoubleToString(result.wick_range_ratio,2)+", FAIL_THRESHOLD.","M15ConfirmV2");
     }
public:
   E2M15ConfirmationEngine(void):m_market(NULL),m_logger(NULL),m_lookback(20),m_verbose(false),m_body_multiplier(1.25),m_body_range_min(0.60),m_close_fraction(0.20),m_wick_body_min(1.50),m_wick_range_min(0.40),m_cached_candle_time(0),m_cached_history(false),m_cached_median(0.0),m_measurement_count(0) {ZeroMemory(m_cached_candle);ZeroMemory(m_cached_previous);}
   void Initialize(const E2Config &config,E2MarketData &market,E2Logger &logger)
     {m_market=&market;m_logger=&logger;m_verbose=config.research_verbose_diagnostics;m_lookback=config.research_m15_body_median_lookback;m_body_multiplier=config.research_m15_momentum_body_multiplier;m_body_range_min=config.research_m15_momentum_body_range_minimum;m_close_fraction=config.research_m15_momentum_closing_location_fraction;m_wick_body_min=config.research_m15_rejection_wick_body_minimum;m_wick_range_min=config.research_m15_rejection_wick_range_minimum;m_cached_candle_time=0;m_cached_history=false;m_cached_median=0.0;m_measurement_count=0;ZeroMemory(m_cached_candle);ZeroMemory(m_cached_previous);}
   ulong MeasurementCount(void) const { return(m_measurement_count); }
   bool Evaluate(const string symbol,const datetime evaluation,const E2M15ZoneContext &zone,E2M15ConfirmationResult &results[])
     {
      ArrayResize(results,4);const E2ResearchConfirmationType types[]={E2_RESEARCH_CONFIRMATION_BULLISH_MOMENTUM,E2_RESEARCH_CONFIRMATION_BEARISH_MOMENTUM,E2_RESEARCH_CONFIRMATION_BULLISH_RANGE_REJECTION,E2_RESEARCH_CONFIRMATION_BEARISH_RANGE_REJECTION};for(int i=0;i<4;i++)Reset(results[i],types[i],zone,evaluation);
      if(m_market==NULL)return(false);
      if(!PrepareCandleMeasurement(symbol,evaluation)){for(int j=0;j<4;j++)results[j].reason="INVALID_OHLC_OR_HISTORY";return(false);}
      for(int i=0;i<4;i++){results[i].history_available=m_cached_history;FillMeasurements(results[i],m_cached_candle,m_cached_previous,m_cached_median);results[i].zone_validity_pass=ZoneValidAt(zone,results[i].known_from_time);}
      EvaluateMomentum(results[0],zone,m_cached_candle,m_cached_previous,true);EvaluateMomentum(results[1],zone,m_cached_candle,m_cached_previous,false);EvaluateRejection(results[2],zone,m_cached_candle,true);EvaluateRejection(results[3],zone,m_cached_candle,false);
      for(int i=0;i<4;i++){results[i].reason=(results[i].passed ? "PASS" : (!m_cached_history ? "INSUFFICIENT_HISTORY" : (results[i].zero_range ? "ZERO_RANGE" : "CONDITIONS_FAILED")));LogPassed(results[i]);LogBoundaryFailure(results[i]);}return(true);
     }
  };

#endif // E2_ANALYSIS_E2M15CONFIRMATIONENGINE_MQH
