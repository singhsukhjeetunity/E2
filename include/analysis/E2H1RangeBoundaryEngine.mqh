#ifndef E2_ANALYSIS_E2H1RANGEBOUNDARYENGINE_MQH
#define E2_ANALYSIS_E2H1RANGEBOUNDARYENGINE_MQH

#include "E2H4RegimeEngine.mqh"
#include "E2H1ZoneEngine.mqh"

struct E2H1RangeBoundaryContext
  {
   bool valid;
   string range_id,symbol,lower_zone_id,upper_zone_id,invalidation_reason;
   datetime known_from_time,h4_regime_known_from,lower_zone_creation_time,upper_zone_creation_time,invalidation_time;
   double lower_zone_lower,lower_zone_upper,upper_zone_lower,upper_zone_upper;
   double lower_reference_price,upper_reference_price,range_center,range_height,range_height_atr;
   double h4_range_high,h4_range_low,creation_h1_atr,invalidation_h1_close,invalidation_h1_atr;
  };

struct E2H1RangeVerification
  {
   long h1_contexts,h4_range_contexts_observed,contexts_with_support,contexts_with_resistance,pair_checks,pairs_order_valid,pairs_containment_pass,pairs_height_pass,ranges_created;
   long ranges_invalidated_h4_loss,ranges_invalidated_lower_zone,ranges_invalidated_upper_zone,ranges_invalidated_lower_break,ranges_invalidated_upper_break;
   long duplicate_range_ids,boundary_mutation_violations,causality_violations,max_candidate_pairs;
   bool active_range_at_end;
   double average_range_height_atr,minimum_range_height_atr,maximum_range_height_atr;
  };

class E2H1RangeBoundaryEngine
  {
private:
   double m_containment_tolerance_atr,m_minimum_height_atr,m_invalidation_atr,m_height_sum;
   bool m_verbose;
   E2Logger *m_logger;
   E2H1RangeBoundaryContext m_current;
   E2H1RangeVerification m_verify;
   string m_seen_ids[];

   double Epsilon(const double value) const{return(MathMax(1e-10,MathAbs(value)*1e-10));}
   bool Seen(const string id)const{for(int i=0;i<ArraySize(m_seen_ids);i++)if(m_seen_ids[i]==id)return(true);return(false);}
   void Remember(const string id){const int n=ArraySize(m_seen_ids);ArrayResize(m_seen_ids,n+1);m_seen_ids[n]=id;}
   int Find(const E2H1ZoneV2Record &zones[],const string id)const{for(int i=0;i<ArraySize(zones);i++)if(zones[i].zone_id==id&&zones[i].state==E2_H1_ZONE_V2_ACTIVE)return(i);return(-1);}
   datetime MaximumTime(const datetime a,const datetime b,const datetime c,const datetime d)const{return(MathMax(MathMax(a,b),MathMax(c,d)));}
   string RangeId(const string symbol,const string lower_id,const string upper_id,const datetime known)const{return("H1RANGE_"+symbol+"_"+lower_id+"_"+upper_id+"_"+IntegerToString((int)known));}
   void Invalidate(const datetime known,const string reason)
     {
      m_current.valid=false;m_current.invalidation_time=known;m_current.invalidation_reason=reason;
      if(reason=="H4_RANGE_LOST")m_verify.ranges_invalidated_h4_loss++;
      else if(reason=="LOWER_ZONE_INACTIVE")m_verify.ranges_invalidated_lower_zone++;
      else if(reason=="UPPER_ZONE_INACTIVE")m_verify.ranges_invalidated_upper_zone++;
      else if(reason=="LOWER_BOUNDARY_BREAK")m_verify.ranges_invalidated_lower_break++;
      else if(reason=="UPPER_BOUNDARY_BREAK")m_verify.ranges_invalidated_upper_break++;
      if(m_logger!=NULL&&m_verbose)m_logger.Debug("rangeId="+m_current.range_id+", reason="+reason+", time="+TimeToString(known,TIME_DATE|TIME_MINUTES)+".","H1Range");
     }
   bool Better(const double height,const datetime ready,const string lower_id,const string upper_id,const double best_height,const datetime best_ready,const string best_lower,const string best_upper)const
     {
      if(height>best_height+Epsilon(best_height))return(true);
      if(height<best_height-Epsilon(best_height))return(false);
      if(ready!=best_ready)return(ready<best_ready);
      const int lower_compare=StringCompare(lower_id,best_lower);if(lower_compare!=0)return(lower_compare<0);
      return(StringCompare(upper_id,best_upper)<0);
     }
public:
   E2H1RangeBoundaryEngine(void):m_containment_tolerance_atr(0.25),m_minimum_height_atr(3.0),m_invalidation_atr(0.25),m_height_sum(0.0),m_verbose(false),m_logger(NULL){ZeroMemory(m_current);ZeroMemory(m_verify);}
   void Initialize(const E2Config &config,E2Logger &logger)
     {m_containment_tolerance_atr=config.range_boundary_containment_tolerance_atr;m_minimum_height_atr=config.range_boundary_minimum_height_atr;m_invalidation_atr=config.research_range_boundary_invalidation_atr;m_verbose=config.research_verbose_diagnostics;m_logger=&logger;m_height_sum=0.0;ZeroMemory(m_current);ZeroMemory(m_verify);ArrayResize(m_seen_ids,0);}
   bool Evaluate(const string symbol,const datetime evaluation_time,const E2H4RegimeResult &h4,const E2H1ZoneV2Record &zones[],const datetime h1_known_from,const double h1_close,const double h1_atr,E2H1RangeBoundaryContext &result)
     {
      m_verify.h1_contexts++;
      bool has_support=false,has_resistance=false;
      if(h4.regime==E2_REGIME_RANGE)
        {
         m_verify.h4_range_contexts_observed++;
         for(int i=0;i<ArraySize(zones);i++){if(zones[i].state!=E2_H1_ZONE_V2_ACTIVE)continue;if(zones[i].type==E2_H1_ZONE_V2_SUPPORT)has_support=true;else if(zones[i].type==E2_H1_ZONE_V2_RESISTANCE)has_resistance=true;}
         if(has_support)m_verify.contexts_with_support++;if(has_resistance)m_verify.contexts_with_resistance++;
        }
      if(m_current.valid)
        {
         if(h4.regime!=E2_REGIME_RANGE){Invalidate(h1_known_from,"H4_RANGE_LOST");result=m_current;return(false);}
         const int lower=Find(zones,m_current.lower_zone_id),upper=Find(zones,m_current.upper_zone_id);
         if(lower<0){Invalidate(h1_known_from,"LOWER_ZONE_INACTIVE");result=m_current;return(false);}
         if(upper<0){Invalidate(h1_known_from,"UPPER_ZONE_INACTIVE");result=m_current;return(false);}
         if(h1_atr>0.0&&h1_close<m_current.lower_zone_lower-m_invalidation_atr*h1_atr-Epsilon(h1_atr)){m_current.invalidation_h1_close=h1_close;m_current.invalidation_h1_atr=h1_atr;Invalidate(h1_known_from,"LOWER_BOUNDARY_BREAK");result=m_current;return(false);}
         if(h1_atr>0.0&&h1_close>m_current.upper_zone_upper+m_invalidation_atr*h1_atr+Epsilon(h1_atr)){m_current.invalidation_h1_close=h1_close;m_current.invalidation_h1_atr=h1_atr;Invalidate(h1_known_from,"UPPER_BOUNDARY_BREAK");result=m_current;return(false);}
         result=m_current;m_verify.active_range_at_end=true;return(true);
        }
      m_verify.active_range_at_end=false;
      if(h4.regime!=E2_REGIME_RANGE||!h4.range_valid||!h4.range_measurements_valid||h1_atr<=0.0){result=m_current;return(false);}
      if(!has_support||!has_resistance){result=m_current;return(false);}
      bool found=false;double best_height=-1.0;datetime best_ready=0;int best_lower=-1,best_upper=-1;long candidate_pairs=0;
      for(int lower=0;lower<ArraySize(zones);lower++)
        {
         if(zones[lower].state!=E2_H1_ZONE_V2_ACTIVE||zones[lower].type!=E2_H1_ZONE_V2_SUPPORT)continue;
         const double lower_reference=(zones[lower].lower+zones[lower].upper)/2.0;
         for(int upper=0;upper<ArraySize(zones);upper++)
           {
            if(zones[upper].state!=E2_H1_ZONE_V2_ACTIVE||zones[upper].type!=E2_H1_ZONE_V2_RESISTANCE)continue;
            m_verify.pair_checks++;candidate_pairs++;const double upper_reference=(zones[upper].lower+zones[upper].upper)/2.0;
            if(upper_reference<=lower_reference+Epsilon(lower_reference))continue;m_verify.pairs_order_valid++;
            if(lower_reference<h4.range_low-m_containment_tolerance_atr*h1_atr-Epsilon(h1_atr)||upper_reference>h4.range_high+m_containment_tolerance_atr*h1_atr+Epsilon(h1_atr))continue;m_verify.pairs_containment_pass++;
            const double height=upper_reference-lower_reference,height_atr=height/h1_atr;if(height_atr+Epsilon(height_atr)<m_minimum_height_atr)continue;m_verify.pairs_height_pass++;
            const datetime ready=MathMax(zones[lower].creation_time,zones[upper].creation_time);
            if(!found||Better(height_atr,ready,zones[lower].zone_id,zones[upper].zone_id,best_height,best_ready,(best_lower>=0?zones[best_lower].zone_id:""),(best_upper>=0?zones[best_upper].zone_id:""))){found=true;best_height=height_atr;best_ready=ready;best_lower=lower;best_upper=upper;}
           }
        }
      m_verify.max_candidate_pairs=MathMax(m_verify.max_candidate_pairs,candidate_pairs);
      if(!found){result=m_current;return(false);}
      ZeroMemory(m_current);m_current.valid=true;m_current.symbol=symbol;m_current.lower_zone_id=zones[best_lower].zone_id;m_current.upper_zone_id=zones[best_upper].zone_id;m_current.lower_zone_creation_time=zones[best_lower].creation_time;m_current.upper_zone_creation_time=zones[best_upper].creation_time;m_current.h4_regime_known_from=h4.known_from_time;m_current.known_from_time=MaximumTime(h4.known_from_time,zones[best_lower].creation_time,zones[best_upper].creation_time,h1_known_from);m_current.range_id=RangeId(symbol,m_current.lower_zone_id,m_current.upper_zone_id,m_current.known_from_time);
      m_current.lower_zone_lower=zones[best_lower].lower;m_current.lower_zone_upper=zones[best_lower].upper;m_current.upper_zone_lower=zones[best_upper].lower;m_current.upper_zone_upper=zones[best_upper].upper;m_current.lower_reference_price=(m_current.lower_zone_lower+m_current.lower_zone_upper)/2.0;m_current.upper_reference_price=(m_current.upper_zone_lower+m_current.upper_zone_upper)/2.0;m_current.range_height=m_current.upper_reference_price-m_current.lower_reference_price;m_current.range_height_atr=m_current.range_height/h1_atr;m_current.range_center=(m_current.lower_reference_price+m_current.upper_reference_price)/2.0;m_current.creation_h1_atr=h1_atr;m_current.h4_range_high=h4.range_high;m_current.h4_range_low=h4.range_low;
      if(Seen(m_current.range_id))m_verify.duplicate_range_ids++;else Remember(m_current.range_id);if(m_current.known_from_time>evaluation_time||m_current.known_from_time<h4.known_from_time||m_current.known_from_time<m_current.lower_zone_creation_time||m_current.known_from_time<m_current.upper_zone_creation_time)m_verify.causality_violations++;
      m_verify.ranges_created++;m_height_sum+=m_current.range_height_atr;if(m_verify.ranges_created==1){m_verify.minimum_range_height_atr=m_current.range_height_atr;m_verify.maximum_range_height_atr=m_current.range_height_atr;}else{m_verify.minimum_range_height_atr=MathMin(m_verify.minimum_range_height_atr,m_current.range_height_atr);m_verify.maximum_range_height_atr=MathMax(m_verify.maximum_range_height_atr,m_current.range_height_atr);}m_verify.active_range_at_end=true;
      if(m_logger!=NULL&&m_verbose)m_logger.Debug("rangeId="+m_current.range_id+", lower="+m_current.lower_zone_id+", upper="+m_current.upper_zone_id+", knownFrom="+TimeToString(m_current.known_from_time,TIME_DATE|TIME_MINUTES)+", heightATR="+DoubleToString(m_current.range_height_atr,3)+".","H1Range");
      result=m_current;return(true);
     }
   bool Current(E2H1RangeBoundaryContext &result)const{result=m_current;return(m_current.valid);}
   E2H1RangeVerification Verification(void)const{E2H1RangeVerification value=m_verify;if(value.ranges_created>0)value.average_range_height_atr=m_height_sum/value.ranges_created;value.active_range_at_end=m_current.valid;return(value);}
  };

#endif // E2_ANALYSIS_E2H1RANGEBOUNDARYENGINE_MQH
