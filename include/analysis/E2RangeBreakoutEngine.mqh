#ifndef E2_ANALYSIS_E2RANGEBREAKOUTENGINE_MQH
#define E2_ANALYSIS_E2RANGEBREAKOUTENGINE_MQH

#include "E2H1RangeBoundaryEngine.mqh"
#include "E2M15ConfirmationEngine.mqh"

enum E2RangeBreakoutDirection{E2_RB_LONG,E2_RB_SHORT};
enum E2RangeBreakoutState{E2_RB_IDLE,E2_RB_BREAKOUT_ACCEPTED,E2_RB_RETEST_ACTIVE,E2_RB_CONSUMED_WAIT_REARM};

struct E2RangeBreakoutCandidate
  {
   E2StrategyType setup_type;string candidate_id,symbol,range_id,challenged_zone_id,opposing_zone_id;E2RangeBreakoutDirection direction;int attempt_number;
   datetime range_known_from,breakout_candle,breakout_known_from,retest_time,retest_known_from,confirmation_candle,confirmation_known_from,h4_known_from;
   double lower_reference,upper_reference,range_center,range_height,challenged_zone_lower,challenged_zone_upper,opposing_zone_lower,opposing_zone_upper;
   double breakout_atr,breakout_distance_atr,h1_body,h1_range,h1_median_body,h1_body_multiplier_ratio,h1_body_range,h1_closing_location;
   E2M15ConfirmationResult confirmation;E2RegimeType h4_regime;
  };

struct E2RangeBreakoutVerification
  {
   long m15_contexts,h1_contexts,h4_range_eligible,active_range_contexts,long_breakout_checks,short_breakout_checks,long_distance_pass,short_distance_pass,long_strong_body_pass,short_strong_body_pass,long_breakouts_accepted,short_breakouts_accepted,long_retests,short_retests,bullish_momentum_passes,bearish_momentum_passes,long_candidates,short_candidates,total_candidates,expired_long,expired_short,invalidated_h4_loss,invalidated_range_loss,invalidated_depth_long,invalidated_depth_short,rearms_long,rearms_short,duplicate_candidates,multiple_claimant_timestamps,max_claimants,ownership_resolutions,same_confirmation_multiple_candidates,causality_violations,max_attempts_per_range_long,max_attempts_per_range_short;
   long pre_event_long_checks,pre_event_short_checks,pre_event_long_distance_pass,pre_event_short_distance_pass,source_range_invalidated_on_breakout_long,source_range_invalidated_on_breakout_short,breakouts_survived_expected_range_invalidation;
   double max_long_distance_atr,max_short_distance_atr,average_long_distance_atr,average_short_distance_atr;
  };
struct E2RBH1Verification{long evaluations,distance_pass,direction_pass,body_median_pass,body_range_pass,closing_location_pass,total_pass,zero_range_candles,insufficient_body_history,causality_violations;};
struct E2RBDistanceSample{bool valid,passed;E2RangeBreakoutDirection direction;string range_id,zone_id;datetime candle,known_from;double close,atr,zone_lower,zone_upper,edge,threshold,raw_distance,raw_distance_atr;};

class E2RangeBreakoutSide
  {
public:
   E2RangeBreakoutState state;E2RangeBreakoutDirection direction;bool source_invalidation_observed;string range_id,symbol,challenged_zone_id,opposing_zone_id;int attempt,h1_age;
   datetime range_known_from,breakout_candle,breakout_known_from,retest_time,retest_known_from,h4_known_from;
   double lower_reference,upper_reference,range_center,range_height,challenged_lower,challenged_upper,opposing_lower,opposing_upper;
   double breakout_close,breakout_atr,breakout_distance_atr,body,candle_range,median_body,body_multiplier,body_range,closing_location;
   E2RegimeType origin_h4_regime;
  };
struct E2RangeBreakoutClaim{E2RangeBreakoutDirection direction;E2M15ConfirmationResult confirmation;double boundary_distance;};

class E2RangeBreakoutEngine
  {
private:
   E2Config m_config;E2MarketData *m_market;E2M15ConfirmationEngine *m_confirmation;E2Logger *m_logger;datetime m_last_h1,m_last_m15;string m_seen[];
   E2RangeBreakoutSide m_long,m_short;E2RangeBreakoutVerification m_verify;E2RBH1Verification m_h1_verify;E2RBDistanceSample m_long_samples[3],m_short_samples[3];double m_long_sum,m_short_sum;long m_long_count,m_short_count;
   double Epsilon(const double v)const{return(MathMax(1e-10,MathAbs(v)*1e-10));}
   bool GE(const double a,const double b)const{return(a>b||MathAbs(a-b)<=Epsilon(b));}
   void Sort(double &v[])const{for(int i=1;i<ArraySize(v);i++){double x=v[i];int j=i-1;while(j>=0&&v[j]>x){v[j+1]=v[j];j--;}v[j+1]=x;}}
   bool Seen(const string id)const{for(int i=0;i<ArraySize(m_seen);i++)if(m_seen[i]==id)return(true);return(false);}
   void Remember(const string id){int n=ArraySize(m_seen);ArrayResize(m_seen,n+1);m_seen[n]=id;}
   void Reset(E2RangeBreakoutSide &s,const E2RangeBreakoutDirection direction){ZeroMemory(s);s.state=E2_RB_IDLE;s.direction=direction;}
   bool Median(const MqlRates &bars[],const int at,double &median)const{const int n=m_config.research_h1_breakout_body_lookback;if(at<n)return(false);double b[];ArrayResize(b,n);for(int i=0;i<n;i++)b[i]=MathAbs(bars[at-n+i].close-bars[at-n+i].open);Sort(b);const int u=n/2;median=(n%2!=0?b[u]:(b[u-1]+b[u])/2.0);return(median>0.0);}
   void AddSample(E2RBDistanceSample &samples[],const E2RBDistanceSample &sample){for(int i=0;i<3;i++)if(!samples[i].valid||sample.raw_distance_atr>samples[i].raw_distance_atr){for(int j=2;j>i;j--)samples[j]=samples[j-1];samples[i]=sample;return;}}
   E2M15ZoneContext FrozenZone(const E2RangeBreakoutSide &s)const{E2M15ZoneContext z;ZeroMemory(z);z.zone_id=s.challenged_zone_id;z.type=(s.direction==E2_RB_LONG?E2_H1_ZONE_V2_SUPPORT:E2_H1_ZONE_V2_RESISTANCE);z.state=E2_H1_ZONE_V2_ACTIVE;z.lower=s.challenged_lower;z.upper=s.challenged_upper;z.creation_time=s.range_known_from;return(z);}
   void FreezeAcceptance(E2RangeBreakoutSide &s,const string symbol,const E2H4RegimeResult &h4,const E2H1RangeBoundaryContext &r,const MqlRates &bar,const double atr,const double median)
     {
      const E2RangeBreakoutDirection direction=s.direction;const int prior_attempt=(s.range_id==r.range_id?s.attempt:0);Reset(s,direction);s.state=E2_RB_BREAKOUT_ACCEPTED;s.range_id=r.range_id;s.symbol=symbol;s.attempt=prior_attempt+1;s.h1_age=0;s.range_known_from=r.known_from_time;s.breakout_candle=bar.time;s.breakout_known_from=bar.time+PeriodSeconds(PERIOD_H1);s.h4_known_from=h4.known_from_time;s.origin_h4_regime=h4.regime;
      s.lower_reference=r.lower_reference_price;s.upper_reference=r.upper_reference_price;s.range_center=r.range_center;s.range_height=r.range_height;
      if(direction==E2_RB_LONG){s.challenged_zone_id=r.upper_zone_id;s.opposing_zone_id=r.lower_zone_id;s.challenged_lower=r.upper_zone_lower;s.challenged_upper=r.upper_zone_upper;s.opposing_lower=r.lower_zone_lower;s.opposing_upper=r.lower_zone_upper;}else{s.challenged_zone_id=r.lower_zone_id;s.opposing_zone_id=r.upper_zone_id;s.challenged_lower=r.lower_zone_lower;s.challenged_upper=r.lower_zone_upper;s.opposing_lower=r.upper_zone_lower;s.opposing_upper=r.upper_zone_upper;}
      s.breakout_close=bar.close;s.breakout_atr=atr;s.breakout_distance_atr=(direction==E2_RB_LONG?(bar.close-s.challenged_upper):(s.challenged_lower-bar.close))/atr;s.body=MathAbs(bar.close-bar.open);s.candle_range=bar.high-bar.low;s.median_body=median;s.body_multiplier=s.body/median;s.body_range=s.body/s.candle_range;s.closing_location=(direction==E2_RB_LONG?(bar.high-bar.close)/s.candle_range:(bar.close-bar.low)/s.candle_range);
      if(direction==E2_RB_LONG){m_verify.long_breakouts_accepted++;m_verify.max_attempts_per_range_long=MathMax(m_verify.max_attempts_per_range_long,s.attempt);}else{m_verify.short_breakouts_accepted++;m_verify.max_attempts_per_range_short=MathMax(m_verify.max_attempts_per_range_short,s.attempt);}
     }
   void AgeOrInvalidate(E2RangeBreakoutSide &s,const MqlRates &bar,const double atr)
     {
      if(s.state==E2_RB_IDLE)return;
      if(s.state==E2_RB_CONSUMED_WAIT_REARM){const bool rearm=(s.direction==E2_RB_LONG?bar.close<=s.challenged_lower-m_config.research_h1_zone_rearm_distance_atr*atr:bar.close>=s.challenged_upper+m_config.research_h1_zone_rearm_distance_atr*atr);if(rearm){if(s.direction==E2_RB_LONG)m_verify.rearms_long++;else m_verify.rearms_short++;s.state=E2_RB_IDLE;}return;}
      s.h1_age++;if(s.h1_age>m_config.research_h1_breakout_retest_expiry_bars){if(s.direction==E2_RB_LONG)m_verify.expired_long++;else m_verify.expired_short++;s.state=E2_RB_IDLE;return;}
      const bool depth=(s.direction==E2_RB_LONG?bar.close<s.challenged_lower-m_config.research_h1_breakout_invalidation_depth_atr*atr:bar.close>s.challenged_upper+m_config.research_h1_breakout_invalidation_depth_atr*atr);if(depth){if(s.direction==E2_RB_LONG)m_verify.invalidated_depth_long++;else m_verify.invalidated_depth_short++;s.state=E2_RB_IDLE;}
     }
   void CheckAcceptance(E2RangeBreakoutSide &s,const string symbol,const E2H4RegimeResult &h4,const E2H1RangeBoundaryContext &r,const MqlRates &bar,const double atr,const double median)
     {
      const bool bull=(s.direction==E2_RB_LONG);m_h1_verify.evaluations++;if(bull){m_verify.long_breakout_checks++;m_verify.pre_event_long_checks++;}else{m_verify.short_breakout_checks++;m_verify.pre_event_short_checks++;}
      const double candle_range=bar.high-bar.low;if(candle_range<=Epsilon(candle_range)){m_h1_verify.zero_range_candles++;return;}const double edge=(bull?r.upper_zone_upper:r.lower_zone_lower),threshold=(bull?edge+m_config.research_h1_breakout_distance_atr*atr:edge-m_config.research_h1_breakout_distance_atr*atr),raw=(bull?bar.close-edge:edge-bar.close),raw_atr=raw/atr;const bool distance=(bull?GE(bar.close,threshold):GE(threshold,bar.close));
      E2RBDistanceSample sample;ZeroMemory(sample);sample.valid=true;sample.passed=distance;sample.direction=s.direction;sample.range_id=r.range_id;sample.zone_id=(bull?r.upper_zone_id:r.lower_zone_id);sample.candle=bar.time;sample.known_from=bar.time+PeriodSeconds(PERIOD_H1);sample.close=bar.close;sample.atr=atr;sample.zone_lower=(bull?r.upper_zone_lower:r.lower_zone_lower);sample.zone_upper=(bull?r.upper_zone_upper:r.lower_zone_upper);sample.edge=edge;sample.threshold=threshold;sample.raw_distance=raw;sample.raw_distance_atr=raw_atr;if(bull){AddSample(m_long_samples,sample);m_long_sum+=raw_atr;m_long_count++;}else{AddSample(m_short_samples,sample);m_short_sum+=raw_atr;m_short_count++;}
      if(distance){m_h1_verify.distance_pass++;if(bull){m_verify.long_distance_pass++;m_verify.pre_event_long_distance_pass++;}else{m_verify.short_distance_pass++;m_verify.pre_event_short_distance_pass++;}}
      const bool direction=(bull?bar.close>bar.open:bar.close<bar.open);if(direction)m_h1_verify.direction_pass++;const double body=MathAbs(bar.close-bar.open),br=body/candle_range,loc=(bull?(bar.high-bar.close)/candle_range:(bar.close-bar.low)/candle_range);const bool body_pass=GE(body,median*m_config.research_h1_breakout_body_multiplier),range_pass=GE(br,m_config.research_h1_breakout_body_range_minimum),location_pass=GE(m_config.research_h1_breakout_closing_location_fraction,loc);if(body_pass)m_h1_verify.body_median_pass++;if(range_pass)m_h1_verify.body_range_pass++;if(location_pass)m_h1_verify.closing_location_pass++;const bool strong=direction&&body_pass&&range_pass&&location_pass;if(strong){if(bull)m_verify.long_strong_body_pass++;else m_verify.short_strong_body_pass++;}if(distance&&strong){m_h1_verify.total_pass++;FreezeAcceptance(s,symbol,h4,r,bar,atr,median);}
     }
   void Emit(E2RangeBreakoutCandidate &out[],const E2H4RegimeResult &current_h4,const E2RangeBreakoutClaim &claim)
     {
      E2RangeBreakoutSide *s=(claim.direction==E2_RB_LONG?&m_long:&m_short);E2RangeBreakoutCandidate c;ZeroMemory(c);c.setup_type=E2_STRATEGY_RANGE_BREAKOUT;c.symbol=s.symbol;c.range_id=s.range_id;c.direction=s.direction;c.attempt_number=s.attempt;c.range_known_from=s.range_known_from;c.breakout_candle=s.breakout_candle;c.breakout_known_from=s.breakout_known_from;c.retest_time=s.retest_time;c.retest_known_from=s.retest_known_from;c.confirmation_candle=claim.confirmation.candle_time;c.confirmation_known_from=claim.confirmation.known_from_time;c.h4_regime=s.origin_h4_regime;c.h4_known_from=s.h4_known_from;c.challenged_zone_id=s.challenged_zone_id;c.opposing_zone_id=s.opposing_zone_id;c.lower_reference=s.lower_reference;c.upper_reference=s.upper_reference;c.range_center=s.range_center;c.range_height=s.range_height;c.challenged_zone_lower=s.challenged_lower;c.challenged_zone_upper=s.challenged_upper;c.opposing_zone_lower=s.opposing_lower;c.opposing_zone_upper=s.opposing_upper;c.breakout_atr=s.breakout_atr;c.breakout_distance_atr=s.breakout_distance_atr;c.h1_body=s.body;c.h1_range=s.candle_range;c.h1_median_body=s.median_body;c.h1_body_multiplier_ratio=s.body_multiplier;c.h1_body_range=s.body_range;c.h1_closing_location=s.closing_location;c.confirmation=claim.confirmation;c.candidate_id="RB_"+s.symbol+"_"+s.range_id+"_"+(s.direction==E2_RB_LONG?"LONG":"SHORT")+"_"+IntegerToString(s.attempt)+"_"+IntegerToString((int)c.confirmation_known_from);if(Seen(c.candidate_id)){m_verify.duplicate_candidates++;return;}Remember(c.candidate_id);int n=ArraySize(out);ArrayResize(out,n+1);out[n]=c;s.state=E2_RB_CONSUMED_WAIT_REARM;if(s.direction==E2_RB_LONG)m_verify.long_candidates++;else m_verify.short_candidates++;m_verify.total_candidates++;
     }
public:
   E2RangeBreakoutEngine(void):m_market(NULL),m_confirmation(NULL),m_logger(NULL),m_last_h1(0),m_last_m15(0),m_long_sum(0.0),m_short_sum(0.0),m_long_count(0),m_short_count(0){ZeroMemory(m_verify);ZeroMemory(m_h1_verify);ZeroMemory(m_long_samples);ZeroMemory(m_short_samples);Reset(m_long,E2_RB_LONG);Reset(m_short,E2_RB_SHORT);}
   void Initialize(const E2Config &config,E2MarketData &market,E2M15ConfirmationEngine &confirmation,E2Logger &logger){m_config=config;m_market=&market;m_confirmation=&confirmation;m_logger=&logger;m_last_h1=0;m_last_m15=0;m_long_sum=0.0;m_short_sum=0.0;m_long_count=0;m_short_count=0;ArrayResize(m_seen,0);ZeroMemory(m_verify);ZeroMemory(m_h1_verify);ZeroMemory(m_long_samples);ZeroMemory(m_short_samples);Reset(m_long,E2_RB_LONG);Reset(m_short,E2_RB_SHORT);}
   void ProcessPreEventH1(const string symbol,const datetime evaluation,const E2H4RegimeResult &h4,const E2H1RangeBoundaryContext &pre_range,const double atr)
     {
      if(!m_config.enable_range_breakout||m_market==NULL||atr<=0.0)return;MqlRates bars[];const int need=m_config.research_h1_breakout_body_lookback+1;if(!m_market.GetClosedBarsAsOf(symbol,PERIOD_H1,evaluation,need,bars))return;const int at=ArraySize(bars)-1;if(at<0||bars[at].time==m_last_h1)return;m_last_h1=bars[at].time;m_verify.h1_contexts++;const datetime known=bars[at].time+PeriodSeconds(PERIOD_H1);if(known>evaluation){m_verify.causality_violations++;m_h1_verify.causality_violations++;return;}AgeOrInvalidate(m_long,bars[at],atr);AgeOrInvalidate(m_short,bars[at],atr);if(h4.regime!=E2_REGIME_RANGE||!pre_range.valid)return;m_verify.h4_range_eligible++;m_verify.active_range_contexts++;double median=0.0;if(!Median(bars,at,median)){m_h1_verify.insufficient_body_history+=2;return;}if(m_long.state==E2_RB_IDLE)CheckAcceptance(m_long,symbol,h4,pre_range,bars[at],atr,median);if(m_short.state==E2_RB_IDLE)CheckAcceptance(m_short,symbol,h4,pre_range,bars[at],atr,median);
     }
   void ObservePostEventRange(const E2H1RangeBoundaryContext &post_range)
     {if(m_long.state==E2_RB_BREAKOUT_ACCEPTED&&!m_long.source_invalidation_observed&&(!post_range.valid||post_range.range_id!=m_long.range_id)){m_long.source_invalidation_observed=true;m_verify.source_range_invalidated_on_breakout_long++;m_verify.breakouts_survived_expected_range_invalidation++;}if(m_short.state==E2_RB_BREAKOUT_ACCEPTED&&!m_short.source_invalidation_observed&&(!post_range.valid||post_range.range_id!=m_short.range_id)){m_short.source_invalidation_observed=true;m_verify.source_range_invalidated_on_breakout_short++;m_verify.breakouts_survived_expected_range_invalidation++;}}
   bool EvaluateM15(const string symbol,const datetime evaluation,const E2H4RegimeResult &current_h4,E2RangeBreakoutCandidate &out[])
     {
      ArrayResize(out,0);if(!m_config.enable_range_breakout||m_market==NULL)return(false);MqlRates bar;if(!m_market.GetClosedBarAsOf(symbol,PERIOD_M15,evaluation,bar)||bar.time==m_last_m15)return(false);m_last_m15=bar.time;m_verify.m15_contexts++;E2RangeBreakoutClaim claims[];ArrayResize(claims,0);
      for(int d=0;d<2;d++){E2RangeBreakoutSide *s=(d==0?&m_long:&m_short);const bool bull=(d==0);if(s.state!=E2_RB_BREAKOUT_ACCEPTED&&s.state!=E2_RB_RETEST_ACTIVE)continue;E2M15ZoneContext zone=FrozenZone(*s);E2M15ConfirmationResult conf;if(!m_confirmation.EvaluateDirectionalMomentum(symbol,evaluation,zone,bull,conf))continue;if(conf.known_from_time<=s.breakout_known_from){m_verify.causality_violations++;continue;}const bool intersection=(conf.low<=zone.upper&&conf.high>=zone.lower);if(s.state==E2_RB_BREAKOUT_ACCEPTED&&intersection){s.state=E2_RB_RETEST_ACTIVE;s.retest_time=conf.candle_time;s.retest_known_from=conf.known_from_time;if(bull)m_verify.long_retests++;else m_verify.short_retests++;}if(s.state==E2_RB_RETEST_ACTIVE&&conf.passed&&s.retest_known_from<=conf.known_from_time){if(bull)m_verify.bullish_momentum_passes++;else m_verify.bearish_momentum_passes++;E2RangeBreakoutClaim c;c.direction=s.direction;c.confirmation=conf;c.boundary_distance=MathAbs(conf.close-(bull?s.challenged_upper:s.challenged_lower));int n=ArraySize(claims);ArrayResize(claims,n+1);claims[n]=c;}}
      if(ArraySize(claims)>1){m_verify.multiple_claimant_timestamps++;m_verify.max_claimants=MathMax(m_verify.max_claimants,ArraySize(claims));m_verify.ownership_resolutions++;if(claims[1].boundary_distance<claims[0].boundary_distance-Epsilon(claims[0].boundary_distance)){E2RangeBreakoutClaim t=claims[0];claims[0]=claims[1];claims[1]=t;}}if(ArraySize(claims)>0)Emit(out,current_h4,claims[0]);return(ArraySize(out)>0);
     }
   E2RangeBreakoutVerification Verification()const{E2RangeBreakoutVerification v=m_verify;v.max_long_distance_atr=(m_long_samples[0].valid?m_long_samples[0].raw_distance_atr:0.0);v.max_short_distance_atr=(m_short_samples[0].valid?m_short_samples[0].raw_distance_atr:0.0);v.average_long_distance_atr=(m_long_count>0?m_long_sum/m_long_count:0.0);v.average_short_distance_atr=(m_short_count>0?m_short_sum/m_short_count:0.0);return(v);}E2RBH1Verification H1Verification()const{return(m_h1_verify);}
   void ReportAudit()const{if(m_logger==NULL)return;for(int d=0;d<2;d++)for(int i=0;i<3;i++){const E2RBDistanceSample s=(d==0?m_long_samples[i]:m_short_samples[i]);if(!s.valid)continue;m_logger.Info("direction="+(d==0?"LONG":"SHORT")+", rangeId="+s.range_id+", h1Candle="+TimeToString(s.candle,TIME_DATE|TIME_MINUTES)+", h1KnownFrom="+TimeToString(s.known_from,TIME_DATE|TIME_MINUTES)+", h1Close="+DoubleToString(s.close,_Digits)+", h1ATR="+DoubleToString(s.atr,_Digits)+", challengedZoneId="+s.zone_id+", zoneLower="+DoubleToString(s.zone_lower,_Digits)+", zoneUpper="+DoubleToString(s.zone_upper,_Digits)+", breakoutEdge="+DoubleToString(s.edge,_Digits)+", requiredThreshold="+DoubleToString(s.threshold,_Digits)+", rawDistancePrice="+DoubleToString(s.raw_distance,_Digits)+", rawDistanceATR="+DoubleToString(s.raw_distance_atr,3)+", pass="+(s.passed?"yes":"no"),"RB_DISTANCE_SAMPLE");}}
  };

#endif
