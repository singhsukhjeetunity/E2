#ifndef E2_ANALYSIS_E2M15CONFIRMATIONENGINE_MQH
#define E2_ANALYSIS_E2M15CONFIRMATIONENGINE_MQH

#include "E2MarketData.mqh"
#include "E2H1ZoneEngine.mqh"

enum E2RejectionDirection{E2_REJECTION_DIRECTION_NONE,E2_REJECTION_DIRECTION_BULLISH,E2_REJECTION_DIRECTION_BEARISH};
enum E2RejectionFailureReason{E2_REJECTION_NOT_EVALUATED,E2_REJECTION_INVALID_CANDLE,E2_REJECTION_INVALID_ZONE,E2_REJECTION_CAUSALITY_VIOLATION,E2_REJECTION_NO_ZONE_INTERSECTION,E2_REJECTION_WRONG_DIRECTION,E2_REJECTION_NO_RECOVERY,E2_REJECTION_WICK_BODY_TOO_SMALL,E2_REJECTION_WICK_RANGE_TOO_SMALL,E2_REJECTION_PASS};
string E2RejectionFailureReasonName(const E2RejectionFailureReason value)
  {string names[]={"NOT_EVALUATED","INVALID_CANDLE","INVALID_ZONE","CAUSALITY_VIOLATION","NO_ZONE_INTERSECTION","WRONG_DIRECTION","NO_RECOVERY","WICK_BODY_TOO_SMALL","WICK_RANGE_TOO_SMALL","PASS"};return(names[(int)value]);}

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
   E2ResearchConfirmationType type;E2RejectionDirection rejection_direction;E2RejectionFailureReason rejection_failure;
   bool valid_input,passed,history_available,median_valid,zero_range,zone_validity_pass,direction_pass,recovery_pass,body_multiplier_pass,body_range_pass,closing_location_pass,previous_break_pass,zone_edge_pass,zone_intersection,zone_intersection_pass,wick_body_pass,wick_range_pass;
   datetime evaluation_time,candle_time,known_from_time;
   string zone_id,reason;
   E2H1ZoneV2Type zone_type;
   double zone_lower,zone_upper,open,high,low,close,body,range,candle_range,body_range_ratio,close_location,previous_high,previous_low,median_body,body_multiplier,lower_wick,upper_wick,relevant_wick,wick_body_ratio,wick_range_ratio,relevant_zone_edge;
  };

struct E2M15RejectionVerification
  {
   long evaluations,bullish_evaluations,bearish_evaluations,invalid_candles,zone_intersection_pass,direction_pass,recovery_pass,wick_body_pass,wick_range_pass,bullish_passes,bearish_passes,total_passes,zero_body_candles,zero_range_candles,causality_violations,duplicate_evaluation_suppressions;
   double average_bullish_wick_body_ratio,average_bearish_wick_body_ratio,average_bullish_wick_range_ratio,average_bearish_wick_range_ratio,maximum_bullish_wick_body_ratio,maximum_bearish_wick_body_ratio;
  };

struct E2M15RejectionCacheEntry{string key;E2M15ConfirmationResult result;};

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
   E2M15RejectionVerification m_rejection_verify;double m_bullish_wick_body_sum,m_bearish_wick_body_sum,m_bullish_wick_range_sum,m_bearish_wick_range_sum;long m_bullish_ratio_count,m_bearish_ratio_count;E2M15RejectionCacheEntry m_rejection_cache[];

   bool Valid(const MqlRates &bar) const { return(MathIsValidNumber(bar.open)&&MathIsValidNumber(bar.high)&&MathIsValidNumber(bar.low)&&MathIsValidNumber(bar.close)&&bar.high>=bar.low&&bar.open>=bar.low&&bar.open<=bar.high&&bar.close>=bar.low&&bar.close<=bar.high); }
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
      m_cached_candle_time=bars[candidate].time;ArrayResize(m_rejection_cache,0);
      m_cached_candle=bars[candidate];m_cached_previous=bars[candidate-1];m_cached_median=0.0;
      m_cached_history=MedianPrecedingBodies(bars,candidate,m_cached_median);
      m_measurement_count++;
      return(true);
     }
   void Reset(E2M15ConfirmationResult &result,const E2ResearchConfirmationType type,const E2M15ZoneContext &zone,const datetime evaluation) const
     { ZeroMemory(result);result.type=type;result.evaluation_time=evaluation;result.zone_id=zone.zone_id;result.zone_type=zone.type;result.zone_lower=zone.lower;result.zone_upper=zone.upper;result.reason="NOT_EVALUATED";result.rejection_failure=E2_REJECTION_NOT_EVALUATED; }
   void FillMeasurements(E2M15ConfirmationResult &result,const MqlRates &candle,const MqlRates &previous,const double median) const
     {
      result.candle_time=candle.time;result.known_from_time=candle.time+PeriodSeconds(PERIOD_M15);result.open=candle.open;result.high=candle.high;result.low=candle.low;result.close=candle.close;result.body=MathAbs(candle.close-candle.open);result.range=candle.high-candle.low;result.candle_range=result.range;result.previous_high=previous.high;result.previous_low=previous.low;result.median_body=median;
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
      result.rejection_direction=(bullish?E2_REJECTION_DIRECTION_BULLISH:E2_REJECTION_DIRECTION_BEARISH);result.direction_pass=(bullish ? candle.close>candle.open : candle.close<candle.open);result.zone_intersection_pass=(candle.low<=zone.upper && candle.high>=zone.lower);result.zone_intersection=result.zone_intersection_pass;result.relevant_zone_edge=(bullish ? zone.upper : zone.lower);result.zone_edge_pass=(bullish ? candle.close>zone.upper : candle.close<zone.lower);result.recovery_pass=result.zone_edge_pass;
      result.relevant_wick=(bullish ? result.lower_wick : result.upper_wick);if(result.body>0.0)result.wick_body_ratio=result.relevant_wick/result.body;if(!result.zero_range)result.wick_range_ratio=result.relevant_wick/result.range;
      result.wick_body_pass=(result.body>0.0 && GreaterOrEqual(result.relevant_wick,m_wick_body_min*result.body));result.wick_range_pass=(!result.zero_range && GreaterOrEqual(result.wick_range_ratio,m_wick_range_min));
      const bool role_pass=(bullish ? zone.type==E2_H1_ZONE_V2_SUPPORT : zone.type==E2_H1_ZONE_V2_RESISTANCE);result.valid_input=Valid(candle)&&result.zone_validity_pass&&role_pass&&!result.zero_range;
      if(!Valid(candle)||result.zero_range)result.rejection_failure=E2_REJECTION_INVALID_CANDLE;else if(!result.zone_validity_pass||!role_pass)result.rejection_failure=E2_REJECTION_INVALID_ZONE;else if(result.known_from_time>result.evaluation_time)result.rejection_failure=E2_REJECTION_CAUSALITY_VIOLATION;else if(!result.zone_intersection_pass)result.rejection_failure=E2_REJECTION_NO_ZONE_INTERSECTION;else if(!result.direction_pass)result.rejection_failure=E2_REJECTION_WRONG_DIRECTION;else if(!result.recovery_pass)result.rejection_failure=E2_REJECTION_NO_RECOVERY;else if(!result.wick_body_pass)result.rejection_failure=E2_REJECTION_WICK_BODY_TOO_SMALL;else if(!result.wick_range_pass)result.rejection_failure=E2_REJECTION_WICK_RANGE_TOO_SMALL;else result.rejection_failure=E2_REJECTION_PASS;
      result.passed=(result.rejection_failure==E2_REJECTION_PASS);result.reason=E2RejectionFailureReasonName(result.rejection_failure);
     }
   string RejectionKey(const E2M15ZoneContext &zone,const bool bullish)const{return(IntegerToString((int)m_cached_candle_time)+"|"+zone.zone_id+"|"+DoubleToString(zone.lower,16)+"|"+DoubleToString(zone.upper,16)+"|"+IntegerToString((int)zone.type)+"|"+IntegerToString((int)zone.state)+"|"+IntegerToString((int)zone.creation_time)+"|"+IntegerToString((int)zone.invalidation_time)+"|"+(bullish?"B":"S"));}
   int CachedRejection(const string key)const{for(int i=0;i<ArraySize(m_rejection_cache);i++)if(m_rejection_cache[i].key==key)return(i);return(-1);}
   void RecordRejection(const E2M15ConfirmationResult &result,const bool bullish)
     {
      m_rejection_verify.evaluations++;if(bullish)m_rejection_verify.bullish_evaluations++;else m_rejection_verify.bearish_evaluations++;if(!result.valid_input)m_rejection_verify.invalid_candles+=(result.rejection_failure==E2_REJECTION_INVALID_CANDLE);if(result.zone_intersection_pass)m_rejection_verify.zone_intersection_pass++;if(result.direction_pass)m_rejection_verify.direction_pass++;if(result.recovery_pass)m_rejection_verify.recovery_pass++;if(result.wick_body_pass)m_rejection_verify.wick_body_pass++;if(result.wick_range_pass)m_rejection_verify.wick_range_pass++;if(result.body<=Epsilon(result.body))m_rejection_verify.zero_body_candles++;if(result.zero_range)m_rejection_verify.zero_range_candles++;if(result.rejection_failure==E2_REJECTION_CAUSALITY_VIOLATION)m_rejection_verify.causality_violations++;
      if(result.passed){m_rejection_verify.total_passes++;if(bullish)m_rejection_verify.bullish_passes++;else m_rejection_verify.bearish_passes++;}
      if(result.valid_input){if(bullish){m_bullish_wick_body_sum+=result.wick_body_ratio;m_bullish_wick_range_sum+=result.wick_range_ratio;m_bullish_ratio_count++;m_rejection_verify.maximum_bullish_wick_body_ratio=MathMax(m_rejection_verify.maximum_bullish_wick_body_ratio,result.wick_body_ratio);}else{m_bearish_wick_body_sum+=result.wick_body_ratio;m_bearish_wick_range_sum+=result.wick_range_ratio;m_bearish_ratio_count++;m_rejection_verify.maximum_bearish_wick_body_ratio=MathMax(m_rejection_verify.maximum_bearish_wick_body_ratio,result.wick_body_ratio);}}
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
   E2M15ConfirmationEngine(void):m_market(NULL),m_logger(NULL),m_lookback(20),m_verbose(false),m_body_multiplier(1.25),m_body_range_min(0.60),m_close_fraction(0.20),m_wick_body_min(1.50),m_wick_range_min(0.40),m_cached_candle_time(0),m_cached_history(false),m_cached_median(0.0),m_measurement_count(0),m_bullish_wick_body_sum(0.0),m_bearish_wick_body_sum(0.0),m_bullish_wick_range_sum(0.0),m_bearish_wick_range_sum(0.0),m_bullish_ratio_count(0),m_bearish_ratio_count(0) {ZeroMemory(m_cached_candle);ZeroMemory(m_cached_previous);ZeroMemory(m_rejection_verify);}
   void Initialize(const E2Config &config,E2MarketData &market,E2Logger &logger)
     {m_market=&market;m_logger=&logger;m_verbose=config.research_verbose_diagnostics;m_lookback=config.research_m15_body_median_lookback;m_body_multiplier=config.research_m15_momentum_body_multiplier;m_body_range_min=config.research_m15_momentum_body_range_minimum;m_close_fraction=config.research_m15_momentum_closing_location_fraction;m_wick_body_min=config.research_m15_rejection_wick_body_minimum;m_wick_range_min=config.research_m15_rejection_wick_range_minimum;m_cached_candle_time=0;m_cached_history=false;m_cached_median=0.0;m_measurement_count=0;m_bullish_wick_body_sum=0.0;m_bearish_wick_body_sum=0.0;m_bullish_wick_range_sum=0.0;m_bearish_wick_range_sum=0.0;m_bullish_ratio_count=0;m_bearish_ratio_count=0;ZeroMemory(m_cached_candle);ZeroMemory(m_cached_previous);ZeroMemory(m_rejection_verify);ArrayResize(m_rejection_cache,0);}
   ulong MeasurementCount(void) const { return(m_measurement_count); }
   E2M15RejectionVerification RejectionVerification(void)const
     {E2M15RejectionVerification value=m_rejection_verify;if(m_bullish_ratio_count>0){value.average_bullish_wick_body_ratio=m_bullish_wick_body_sum/m_bullish_ratio_count;value.average_bullish_wick_range_ratio=m_bullish_wick_range_sum/m_bullish_ratio_count;}if(m_bearish_ratio_count>0){value.average_bearish_wick_body_ratio=m_bearish_wick_body_sum/m_bearish_ratio_count;value.average_bearish_wick_range_ratio=m_bearish_wick_range_sum/m_bearish_ratio_count;}return(value);}
   bool EvaluateDirectionalRejection(const string symbol,const datetime evaluation,const E2M15ZoneContext &zone,const bool bullish,E2M15ConfirmationResult &result)
     {
      const E2ResearchConfirmationType type=(bullish?E2_RESEARCH_CONFIRMATION_BULLISH_RANGE_REJECTION:E2_RESEARCH_CONFIRMATION_BEARISH_RANGE_REJECTION);Reset(result,type,zone,evaluation);if(m_market==NULL)return(false);
      if(!PrepareCandleMeasurement(symbol,evaluation)){result.rejection_direction=(bullish?E2_REJECTION_DIRECTION_BULLISH:E2_REJECTION_DIRECTION_BEARISH);result.rejection_failure=E2_REJECTION_INVALID_CANDLE;result.reason=E2RejectionFailureReasonName(result.rejection_failure);m_rejection_verify.evaluations++;if(bullish)m_rejection_verify.bullish_evaluations++;else m_rejection_verify.bearish_evaluations++;m_rejection_verify.invalid_candles++;return(false);}
      const string key=RejectionKey(zone,bullish);const int cached=CachedRejection(key);if(cached>=0){result=m_rejection_cache[cached].result;result.evaluation_time=evaluation;m_rejection_verify.duplicate_evaluation_suppressions++;return(true);}
      result.history_available=m_cached_history;FillMeasurements(result,m_cached_candle,m_cached_previous,m_cached_median);result.zone_validity_pass=ZoneValidAt(zone,result.known_from_time);EvaluateRejection(result,zone,m_cached_candle,bullish);RecordRejection(result,bullish);const int n=ArraySize(m_rejection_cache);ArrayResize(m_rejection_cache,n+1);m_rejection_cache[n].key=key;m_rejection_cache[n].result=result;LogPassed(result);LogBoundaryFailure(result);return(true);
     }
   bool Evaluate(const string symbol,const datetime evaluation,const E2M15ZoneContext &zone,E2M15ConfirmationResult &results[])
     {
      ArrayResize(results,4);const E2ResearchConfirmationType types[]={E2_RESEARCH_CONFIRMATION_BULLISH_MOMENTUM,E2_RESEARCH_CONFIRMATION_BEARISH_MOMENTUM,E2_RESEARCH_CONFIRMATION_BULLISH_RANGE_REJECTION,E2_RESEARCH_CONFIRMATION_BEARISH_RANGE_REJECTION};for(int i=0;i<4;i++)Reset(results[i],types[i],zone,evaluation);
      if(m_market==NULL)return(false);
      if(!PrepareCandleMeasurement(symbol,evaluation)){for(int j=0;j<4;j++)results[j].reason="INVALID_OHLC_OR_HISTORY";return(false);}
      for(int i=0;i<2;i++){results[i].history_available=m_cached_history;FillMeasurements(results[i],m_cached_candle,m_cached_previous,m_cached_median);results[i].zone_validity_pass=ZoneValidAt(zone,results[i].known_from_time);}
      EvaluateMomentum(results[0],zone,m_cached_candle,m_cached_previous,true);EvaluateMomentum(results[1],zone,m_cached_candle,m_cached_previous,false);
      for(int i=0;i<2;i++){results[i].reason=(results[i].passed ? "PASS" : (!m_cached_history ? "INSUFFICIENT_HISTORY" : (results[i].zero_range ? "ZERO_RANGE" : "CONDITIONS_FAILED")));LogPassed(results[i]);LogBoundaryFailure(results[i]);}
      EvaluateDirectionalRejection(symbol,evaluation,zone,true,results[2]);EvaluateDirectionalRejection(symbol,evaluation,zone,false,results[3]);return(true);
     }
  };

#endif // E2_ANALYSIS_E2M15CONFIRMATIONENGINE_MQH
