#ifndef E2_ANALYSIS_E2RANGEMEANREVERSIONENGINE_MQH
#define E2_ANALYSIS_E2RANGEMEANREVERSIONENGINE_MQH

#include "E2H1RangeBoundaryEngine.mqh"
#include "E2M15ConfirmationEngine.mqh"

enum E2RangeMeanReversionDirection{E2_RMR_LONG,E2_RMR_SHORT};
enum E2RangeMeanReversionState{E2_RMR_IDLE,E2_RMR_ARMED_FROM_INTERIOR,E2_RMR_BOUNDARY_ACTIVE,E2_RMR_CONSUMED_WAIT_REARM};
string E2RangeMeanReversionDirectionName(const E2RangeMeanReversionDirection value){return(value==E2_RMR_LONG?"LONG":"SHORT");}

struct E2RangeMeanReversionCandidate
  {
   E2StrategyType setup_type;
   string candidate_id,symbol,range_id,source_zone_id;
   E2RangeMeanReversionDirection direction;
   E2H1ZoneV2Type source_zone_role;
   int attempt_number;
   datetime range_known_from,boundary_visit_time,boundary_visit_known_from,confirmation_candle,confirmation_known_from,h4_regime_known_from;
   double lower_reference,upper_reference,range_center,range_height,source_zone_lower,source_zone_upper;
   E2RegimeType h4_regime;
   E2M15ConfirmationResult confirmation;
  };

struct E2RangeMeanReversionVerification
  {
   long m15_contexts,h4_range_eligible,active_range_contexts,long_interior_arms,short_interior_arms,long_boundary_visits,short_boundary_visits,bullish_rejection_passes,bearish_rejection_passes,long_candidates,short_candidates,total_candidates,rearms_long,rearms_short,duplicate_candidates,same_confirmation_collisions,collision_resolutions,causality_violations,invalidated_h4_loss,invalidated_range_loss,max_attempts_per_range_long,max_attempts_per_range_short;
  };

struct E2RangeMeanReversionSide
  {
   E2RangeMeanReversionState state;
   int attempt_number;
   datetime visit_time,visit_known_from;
  };

struct E2RangeMeanReversionClaim
  {
   E2RangeMeanReversionDirection direction;
   E2M15ConfirmationResult confirmation;
   string source_zone_id;
   double boundary_distance;
  };

class E2RangeMeanReversionEngine
  {
private:
   E2MarketData *m_market;E2M15ConfirmationEngine *m_confirmation;E2Logger *m_logger;
   bool m_enabled,m_verbose;double m_outer_fraction,m_rearm_atr;datetime m_last_m15;string m_range_id,m_seen_candidates[];
   E2RangeMeanReversionSide m_long,m_short;E2RangeMeanReversionVerification m_verify;
   double Eps(const double value)const{return(MathMax(1e-10,MathAbs(value)*1e-10));}
   bool Seen(const string id)const{for(int i=0;i<ArraySize(m_seen_candidates);i++)if(m_seen_candidates[i]==id)return(true);return(false);}
   void Remember(const string id){const int n=ArraySize(m_seen_candidates);ArrayResize(m_seen_candidates,n+1);m_seen_candidates[n]=id;}
   void ResetSide(E2RangeMeanReversionSide &side){ZeroMemory(side);side.state=E2_RMR_IDLE;}
   void ResetRange(const string id){m_range_id=id;ResetSide(m_long);ResetSide(m_short);}
   E2M15ZoneContext Zone(const E2H1RangeBoundaryContext &range,const E2RangeMeanReversionDirection direction)const
     {E2M15ZoneContext zone;ZeroMemory(zone);const bool is_long=(direction==E2_RMR_LONG);zone.zone_id=(is_long?range.lower_zone_id:range.upper_zone_id);zone.type=(is_long?E2_H1_ZONE_V2_SUPPORT:E2_H1_ZONE_V2_RESISTANCE);zone.state=E2_H1_ZONE_V2_ACTIVE;zone.lower=(is_long?range.lower_zone_lower:range.upper_zone_lower);zone.upper=(is_long?range.lower_zone_upper:range.upper_zone_upper);zone.creation_time=(is_long?range.lower_zone_creation_time:range.upper_zone_creation_time);return(zone);}
   string CandidateId(const string symbol,const E2H1RangeBoundaryContext &range,const E2RangeMeanReversionDirection direction,const int attempt,const datetime known)const
     {return("RMR_"+symbol+"_"+range.range_id+"_"+E2RangeMeanReversionDirectionName(direction)+"_"+IntegerToString(attempt)+"_"+IntegerToString((int)known));}
   bool ClaimWins(const E2RangeMeanReversionClaim &left,const E2RangeMeanReversionClaim &right)const
     {if(left.confirmation.wick_range_ratio>right.confirmation.wick_range_ratio+Eps(right.confirmation.wick_range_ratio))return(true);if(left.confirmation.wick_range_ratio<right.confirmation.wick_range_ratio-Eps(right.confirmation.wick_range_ratio))return(false);if(left.boundary_distance<right.boundary_distance-Eps(right.boundary_distance))return(true);if(left.boundary_distance>right.boundary_distance+Eps(right.boundary_distance))return(false);return(StringCompare(left.source_zone_id,right.source_zone_id)<0);}
   void AddClaim(E2RangeMeanReversionClaim &claims[],const E2RangeMeanReversionClaim &claim)const{const int n=ArraySize(claims);ArrayResize(claims,n+1);claims[n]=claim;}
   void Emit(E2RangeMeanReversionCandidate &output[],const string symbol,const E2H4RegimeResult &h4,const E2H1RangeBoundaryContext &range,const E2RangeMeanReversionClaim &claim,const E2RangeMeanReversionSide &side)
     {
      E2RangeMeanReversionCandidate candidate;ZeroMemory(candidate);candidate.setup_type=E2_STRATEGY_RANGE_MEAN_REVERSION;candidate.symbol=symbol;candidate.range_id=range.range_id;candidate.direction=claim.direction;candidate.source_zone_id=claim.source_zone_id;candidate.source_zone_role=(claim.direction==E2_RMR_LONG?E2_H1_ZONE_V2_SUPPORT:E2_H1_ZONE_V2_RESISTANCE);candidate.attempt_number=side.attempt_number;candidate.range_known_from=range.known_from_time;candidate.boundary_visit_time=side.visit_time;candidate.boundary_visit_known_from=side.visit_known_from;candidate.confirmation_candle=claim.confirmation.candle_time;candidate.confirmation_known_from=claim.confirmation.known_from_time;candidate.h4_regime=h4.regime;candidate.h4_regime_known_from=h4.known_from_time;candidate.lower_reference=range.lower_reference_price;candidate.upper_reference=range.upper_reference_price;candidate.range_center=range.range_center;candidate.range_height=range.range_height;candidate.source_zone_lower=(claim.direction==E2_RMR_LONG?range.lower_zone_lower:range.upper_zone_lower);candidate.source_zone_upper=(claim.direction==E2_RMR_LONG?range.lower_zone_upper:range.upper_zone_upper);candidate.confirmation=claim.confirmation;candidate.candidate_id=CandidateId(symbol,range,claim.direction,side.attempt_number,candidate.confirmation_known_from);
      if(Seen(candidate.candidate_id)){m_verify.duplicate_candidates++;return;}Remember(candidate.candidate_id);
      if(candidate.confirmation_known_from<h4.known_from_time||candidate.confirmation_known_from<range.known_from_time||candidate.confirmation_known_from<side.visit_known_from||candidate.confirmation_known_from!=candidate.confirmation_candle+PeriodSeconds(PERIOD_M15))m_verify.causality_violations++;
      const int n=ArraySize(output);ArrayResize(output,n+1);output[n]=candidate;m_verify.total_candidates++;if(claim.direction==E2_RMR_LONG)m_verify.long_candidates++;else m_verify.short_candidates++;
     }
public:
   E2RangeMeanReversionEngine(void):m_market(NULL),m_confirmation(NULL),m_logger(NULL),m_enabled(false),m_verbose(false),m_outer_fraction(0.20),m_rearm_atr(0.50),m_last_m15(0),m_range_id(""){ResetSide(m_long);ResetSide(m_short);ZeroMemory(m_verify);}
   void Initialize(const E2Config &config,E2MarketData &market,E2M15ConfirmationEngine &confirmation,E2Logger &logger)
     {m_market=&market;m_confirmation=&confirmation;m_logger=&logger;m_enabled=config.enable_range_mean_reversion;m_verbose=config.research_verbose_diagnostics;m_outer_fraction=config.research_range_outer_entry_region_fraction;m_rearm_atr=config.research_h1_zone_rearm_distance_atr;m_last_m15=0;ResetRange("");ArrayResize(m_seen_candidates,0);ZeroMemory(m_verify);}
   E2RangeMeanReversionVerification Verification(void)const{return(m_verify);}
   bool Evaluate(const string symbol,const datetime evaluation,const E2H4RegimeResult &h4,const E2H1RangeBoundaryContext &range,const double h1_atr,E2RangeMeanReversionCandidate &output[])
     {
      ArrayResize(output,0);if(!m_enabled||m_market==NULL||m_confirmation==NULL)return(false);MqlRates bar;if(!m_market.GetClosedBarAsOf(symbol,PERIOD_M15,evaluation,bar)||bar.time==m_last_m15)return(false);m_last_m15=bar.time;m_verify.m15_contexts++;const datetime known=bar.time+PeriodSeconds(PERIOD_M15);
      if(h4.regime!=E2_REGIME_RANGE){if(m_range_id!="")m_verify.invalidated_h4_loss++;ResetRange("");return(true);}m_verify.h4_range_eligible++;
      if(!range.valid){if(m_range_id!="")m_verify.invalidated_range_loss++;ResetRange("");return(true);}m_verify.active_range_contexts++;
      if(m_range_id!=range.range_id){if(m_range_id!="")m_verify.invalidated_range_loss++;ResetRange(range.range_id);}
      const bool long_was_armed=(m_long.state==E2_RMR_ARMED_FROM_INTERIOR),short_was_armed=(m_short.state==E2_RMR_ARMED_FROM_INTERIOR);
      const double lower_outer=range.lower_reference_price+range.range_height*m_outer_fraction,upper_outer=range.upper_reference_price-range.range_height*m_outer_fraction,rearm=MathMax(0.0,m_rearm_atr*h1_atr);
      const bool long_rearmed=(bar.close>=range.lower_zone_upper+rearm-Eps(rearm)),short_rearmed=(bar.close<=range.upper_zone_lower-rearm+Eps(rearm));
      if((m_long.state==E2_RMR_BOUNDARY_ACTIVE||m_long.state==E2_RMR_CONSUMED_WAIT_REARM)&&long_rearmed){m_long.state=E2_RMR_ARMED_FROM_INTERIOR;m_verify.rearms_long++;m_verify.long_interior_arms++;}
      else if(m_long.state==E2_RMR_IDLE&&bar.close>lower_outer+Eps(lower_outer)){m_long.state=E2_RMR_ARMED_FROM_INTERIOR;m_verify.long_interior_arms++;}
      if((m_short.state==E2_RMR_BOUNDARY_ACTIVE||m_short.state==E2_RMR_CONSUMED_WAIT_REARM)&&short_rearmed){m_short.state=E2_RMR_ARMED_FROM_INTERIOR;m_verify.rearms_short++;m_verify.short_interior_arms++;}
      else if(m_short.state==E2_RMR_IDLE&&bar.close<upper_outer-Eps(upper_outer)){m_short.state=E2_RMR_ARMED_FROM_INTERIOR;m_verify.short_interior_arms++;}
      const bool long_visit=(long_was_armed&&bar.close<=lower_outer+Eps(lower_outer)&&bar.low<=range.lower_zone_upper&&bar.high>=range.lower_zone_lower),short_visit=(short_was_armed&&bar.close>=upper_outer-Eps(upper_outer)&&bar.low<=range.upper_zone_upper&&bar.high>=range.upper_zone_lower);
      if(long_visit){m_long.state=E2_RMR_BOUNDARY_ACTIVE;m_long.attempt_number++;m_long.visit_time=bar.time;m_long.visit_known_from=known;m_verify.long_boundary_visits++;m_verify.max_attempts_per_range_long=MathMax(m_verify.max_attempts_per_range_long,m_long.attempt_number);}
      if(short_visit){m_short.state=E2_RMR_BOUNDARY_ACTIVE;m_short.attempt_number++;m_short.visit_time=bar.time;m_short.visit_known_from=known;m_verify.short_boundary_visits++;m_verify.max_attempts_per_range_short=MathMax(m_verify.max_attempts_per_range_short,m_short.attempt_number);}
      E2RangeMeanReversionClaim claims[];
      if(m_long.state==E2_RMR_BOUNDARY_ACTIVE){E2M15ConfirmationResult confirmations[];E2M15ZoneContext zone=Zone(range,E2_RMR_LONG);if(m_confirmation.Evaluate(symbol,evaluation,zone,confirmations)&&confirmations[2].passed){m_verify.bullish_rejection_passes++;E2RangeMeanReversionClaim claim;claim.direction=E2_RMR_LONG;claim.confirmation=confirmations[2];claim.source_zone_id=zone.zone_id;claim.boundary_distance=MathAbs(confirmations[2].close-range.lower_reference_price);AddClaim(claims,claim);}}
      if(m_short.state==E2_RMR_BOUNDARY_ACTIVE){E2M15ConfirmationResult confirmations[];E2M15ZoneContext zone=Zone(range,E2_RMR_SHORT);if(m_confirmation.Evaluate(symbol,evaluation,zone,confirmations)&&confirmations[3].passed){m_verify.bearish_rejection_passes++;E2RangeMeanReversionClaim claim;claim.direction=E2_RMR_SHORT;claim.confirmation=confirmations[3];claim.source_zone_id=zone.zone_id;claim.boundary_distance=MathAbs(confirmations[3].close-range.upper_reference_price);AddClaim(claims,claim);}}
      if(ArraySize(claims)>0){int winner=0;if(ArraySize(claims)>1){m_verify.same_confirmation_collisions++;m_verify.collision_resolutions++;for(int i=1;i<ArraySize(claims);i++)if(ClaimWins(claims[i],claims[winner]))winner=i;}E2RangeMeanReversionClaim claim=claims[winner];if(claim.direction==E2_RMR_LONG){Emit(output,symbol,h4,range,claim,m_long);m_long.state=E2_RMR_CONSUMED_WAIT_REARM;}else{Emit(output,symbol,h4,range,claim,m_short);m_short.state=E2_RMR_CONSUMED_WAIT_REARM;}}
      return(true);
     }
  };

#endif // E2_ANALYSIS_E2RANGEMEANREVERSIONENGINE_MQH
