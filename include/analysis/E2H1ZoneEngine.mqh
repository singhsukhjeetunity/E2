#ifndef E2_ANALYSIS_E2H1ZONEENGINE_MQH
#define E2_ANALYSIS_E2H1ZONEENGINE_MQH

#include "E2MarketData.mqh"

enum E2H1ZoneV2Type { E2_H1_ZONE_V2_SUPPORT,E2_H1_ZONE_V2_RESISTANCE };
enum E2H1ZoneV2State { E2_H1_ZONE_V2_ACTIVE,E2_H1_ZONE_V2_INVALIDATED };

string E2H1ZoneV2TypeName(const E2H1ZoneV2Type value) { return(value==E2_H1_ZONE_V2_SUPPORT ? "SUPPORT" : "RESISTANCE"); }
string E2H1ZoneV2StateName(const E2H1ZoneV2State value) { return(value==E2_H1_ZONE_V2_ACTIVE ? "ACTIVE" : "INVALIDATED"); }

struct E2H1ZoneV2Pivot
  {
   string id;
   bool high,departure_qualified;
   int pivot_index;
   datetime pivot_time,known_from_time,departure_confirmed_time;
   double price,qualification_atr;
  };

struct E2H1ZoneV2Record
  {
   string zone_id,source_pivot_1_id,source_pivot_2_id,merged_from_ids,invalidation_reason;
   E2H1ZoneV2Type type;
   E2H1ZoneV2State state;
   datetime creation_time,invalidation_time;
   double lower,upper,creation_atr,invalidation_close,invalidation_atr,invalidation_distance_atr;
   datetime source_pivot_1_time,source_pivot_1_known_from,source_pivot_1_departure_confirmed_time;
   datetime source_pivot_2_time,source_pivot_2_known_from,source_pivot_2_departure_confirmed_time;
   double source_pivot_1_price,source_pivot_2_price;
   bool currently_interacting,armed,consumed,departure_after_attempt,rearm_eligible;
   int visit_number,attempt_number;
  };

// Snapshot of the bounded causal reconstruction.  These counts are diagnostic
// only: they make source-role creation and prospective invalidation observable
// while keeping the Zone V2 detector independent from trade execution.
struct E2H1ZoneV2Verification
  {
   int created_support,created_resistance;
   int invalidated_support,invalidated_resistance;
   int active_support_end,active_resistance_end;
  };

// Aggregate source-pipeline audit for the current bounded reconstruction.
// It deliberately records gates, not individual pivots, so tester journals
// remain usable on long runs.
struct E2H1ZoneV2RoleGate
  {
   int confirmed_swing_highs,confirmed_swing_lows;
   int qualified_high_departures,qualified_low_departures;
   int high_prior_candidates_checked,low_prior_candidates_checked;
   int high_separation_pass,low_separation_pass;
   int high_cluster_pass,low_cluster_pass;
   int resistance_created,support_created;
  };

// Diagnostic-only comparison of the actual departure window with the
// pivot-to-present interpretation.  The current implementation starts at
// pivot_index + 1, so these values are intentionally expected to agree.
struct E2H1ZoneV2DepartureWindow
  {
   int current_high,current_low;
   int pivot_window_high,pivot_window_low;
  };

struct E2H1ZoneV2DepartureSample
  {
   datetime pivot_time,known_from_time;
   double pivot_price,frozen_atr,best_away_price,distance,departure_atr;
  };

struct E2H1ZoneV2DepartureMagnitude
  {
   int highs,lows,high_025,high_050,high_075,high_100,high_125,low_025,low_050,low_075,low_100,low_125;
   double high_average,high_median,high_max,low_average,low_median,low_max;
   E2H1ZoneV2DepartureSample high_greatest,high_median_sample,high_smallest;
   E2H1ZoneV2DepartureSample low_greatest,low_median_sample,low_smallest;
  };

struct E2H1ZoneV2Lifetime
  {
   int support_created,resistance_created,support_invalidated,resistance_invalidated;
   int support_bars,resistance_bars;
   bool lookback_expiry_observed;
  };
struct E2H1ZoneV2PersistentDiagnostics
  {int inserted_support,inserted_resistance,initialized_support,initialized_resistance,invalidated_support,invalidated_resistance,duplicate_rediscoveries,resurrection_attempts,survived_source_lookback_expiry,max_active,max_total,creation_causality_violations,invalidation_before_creation,duplicate_active_ids,disappeared_without_invalidation;};
struct E2H1ZoneV2Workload
  {ulong persistent_lookup_checks,persistent_active_invalidation_checks,persistent_terminal_checks,active_zone_exports,rediscovery_fast_hits;};

class E2H1ZoneEngine
  {
private:
   E2MarketData *m_market;
   E2Logger *m_logger;
   int m_strength,m_lookback,m_atr_period,m_min_separation;
   double m_cluster_atr,m_departure_atr,m_invalidation_atr,m_rearm_atr;
   datetime m_last_closed,m_last_known_from;
   double m_last_atr,m_last_close;
   bool m_has_cached,m_verbose;
   E2H1ZoneV2Record m_cached[];
   E2H1ZoneV2Verification m_verification;
   E2H1ZoneV2RoleGate m_role_gate;
   E2H1ZoneV2DepartureWindow m_departure_window;
   E2H1ZoneV2DepartureMagnitude m_departure_magnitude;
   E2H1ZoneV2Lifetime m_lifetime;
   string m_seen_created[],m_seen_invalidated[];
   E2H1ZoneV2Record m_persistent[];
   string m_persistent_ids[];
   int m_persistent_id_records[],m_active_support[],m_active_resistance[];
   bool m_persistent_initialized;
   E2H1ZoneV2PersistentDiagnostics m_persistent_diagnostics;
   string m_seen_expiry_survival[];
   E2H1ZoneV2Workload m_workload;

   double Epsilon(const double value) const { return(MathMax(1e-10,MathAbs(value)*1e-10)); }
   bool GreaterOrEqual(const double a,const double b) const { return(a>b || MathAbs(a-b)<=Epsilon(b)); }
   bool StrictAbove(const double a,const double b) const { return(a>b+Epsilon(b)); }
   bool StrictBelow(const double a,const double b) const { return(a<b-Epsilon(b)); }
   bool Pivot(const MqlRates &bars[],const int index,const bool high) const
     {
      const double value=(high ? bars[index].high : bars[index].low);
      for(int offset=1;offset<=m_strength;offset++)
         if(high ? value<=bars[index-offset].high || value<=bars[index+offset].high : value>=bars[index-offset].low || value>=bars[index+offset].low)
            return(false);
      return(true);
     }
   bool Atr(const MqlRates &bars[],double &values[]) const
     {
      const int count=ArraySize(bars);ArrayResize(values,count);
      for(int i=0;i<count;i++) values[i]=0.0;
      if(count<=m_atr_period)return(false);
      double sum=0.0;
      for(int i=1;i<count;i++)
        {
         const double tr=MathMax(bars[i].high-bars[i].low,MathMax(MathAbs(bars[i].high-bars[i-1].close),MathAbs(bars[i].low-bars[i-1].close)));
         if(i<=m_atr_period){sum+=tr;if(i==m_atr_period)values[i]=sum/m_atr_period;}
         else {sum=sum-sum/m_atr_period+tr;values[i]=sum/m_atr_period;}
        }
      return(true);
     }
   string PivotId(const bool high,const datetime time) const { return((high ? "H" : "L")+"_"+IntegerToString((int)time)); }
   string ZoneId(const string symbol,const E2H1ZoneV2Type type,const E2H1ZoneV2Pivot &one,const E2H1ZoneV2Pivot &two,const datetime creation) const
     { return("H1ZV2_"+symbol+"_"+(type==E2_H1_ZONE_V2_SUPPORT ? "S" : "R")+"_"+IntegerToString((int)one.pivot_time)+"_"+IntegerToString((int)two.pivot_time)+"_"+IntegerToString((int)creation)); }
   void AppendPivot(E2H1ZoneV2Pivot &values[],const E2H1ZoneV2Pivot &value) const { const int count=ArraySize(values);ArrayResize(values,count+1);values[count]=value; }
   void AppendZone(E2H1ZoneV2Record &values[],const E2H1ZoneV2Record &value) const { const int count=ArraySize(values);ArrayResize(values,count+1);values[count]=value; }
   bool ZoneExists(const E2H1ZoneV2Record &zones[],const string id) const { for(int i=0;i<ArraySize(zones);i++)if(zones[i].zone_id==id)return(true);return(false); }
   int IndexAtOrAfter(const MqlRates &bars[],const datetime available) const { for(int i=0;i<ArraySize(bars);i++)if(bars[i].time+PeriodSeconds(PERIOD_H1)>=available)return(i);return(ArraySize(bars)); }
   void QualifyDeparture(E2H1ZoneV2Pivot &pivot,const MqlRates &bars[]) const
     {
      pivot.departure_qualified=false;pivot.departure_confirmed_time=0;
      if(pivot.qualification_atr<=0.0)return;
      const double threshold=m_departure_atr*pivot.qualification_atr;
      for(int i=pivot.pivot_index+1;i<ArraySize(bars);i++)
        {
         const bool departed=(pivot.high ? bars[i].low<=pivot.price-threshold+Epsilon(threshold) : bars[i].high>=pivot.price+threshold-Epsilon(threshold));
         if(departed){pivot.departure_qualified=true;pivot.departure_confirmed_time=MathMax(bars[i].time+PeriodSeconds(PERIOD_H1),pivot.known_from_time);return;}
        }
     }
   void ResetRecord(E2H1ZoneV2Record &zone,const E2H1ZoneV2Type type) const
     {
      ZeroMemory(zone);zone.type=type;zone.state=E2_H1_ZONE_V2_ACTIVE;zone.invalidation_reason="";zone.merged_from_ids="";
     }
   void BuildInteractions(E2H1ZoneV2Record &zone,const MqlRates &bars[],const double &atr[]) const
     {
      const int start=IndexAtOrAfter(bars,zone.creation_time);bool had_visit=false;
      for(int i=start;i<ArraySize(bars);i++)
        {
         const datetime available=bars[i].time+PeriodSeconds(PERIOD_H1);
         if(available<zone.creation_time || atr[i]<=0.0)continue;
         if(zone.state==E2_H1_ZONE_V2_ACTIVE)
           {
            const bool invalid=(zone.type==E2_H1_ZONE_V2_SUPPORT ? StrictBelow(bars[i].close,zone.lower+m_invalidation_atr*atr[i]*-1.0) : StrictAbove(bars[i].close,zone.upper+m_invalidation_atr*atr[i]));
            if(invalid){zone.state=E2_H1_ZONE_V2_INVALIDATED;zone.invalidation_time=available;zone.invalidation_close=bars[i].close;zone.invalidation_atr=atr[i];zone.invalidation_distance_atr=(zone.type==E2_H1_ZONE_V2_SUPPORT ? (zone.lower-bars[i].close)/atr[i] : (bars[i].close-zone.upper)/atr[i]);zone.invalidation_reason="H1_CLOSE_BEYOND_FAR_EDGE";}
           }
         if(zone.state==E2_H1_ZONE_V2_INVALIDATED)break;
         const bool overlaps=(bars[i].low<=zone.upper && bars[i].high>=zone.lower);
         const bool away=(bars[i].low>=zone.upper+m_rearm_atr*atr[i]-Epsilon(atr[i]) || bars[i].high<=zone.lower-m_rearm_atr*atr[i]+Epsilon(atr[i]));
         if(overlaps && !zone.currently_interacting && (!had_visit || zone.rearm_eligible))
           {zone.currently_interacting=true;zone.armed=true;zone.consumed=false;zone.visit_number++;zone.attempt_number++;zone.rearm_eligible=false;zone.departure_after_attempt=false;had_visit=true;}
         else if(!overlaps)zone.currently_interacting=false;
         if(had_visit && away){zone.departure_after_attempt=true;zone.rearm_eligible=true;zone.armed=false;}
        }
     }
   int PersistentIdPosition(const string id,bool &found)
     {int lo=0,hi=ArraySize(m_persistent_ids)-1;found=false;while(lo<=hi){m_workload.persistent_lookup_checks++;const int mid=(lo+hi)/2;const int cmp=StringCompare(m_persistent_ids[mid],id);if(cmp==0){found=true;return(mid);}if(cmp<0)lo=mid+1;else hi=mid-1;}return(lo);}
   int PersistentIndex(const string id)
     {bool found=false;const int at=PersistentIdPosition(id,found);return(found?m_persistent_id_records[at]:-1);}
   void IndexPersistent(const string id,const int record)
     {bool found=false;const int at=PersistentIdPosition(id,found);if(found)return;const int n=ArraySize(m_persistent_ids);ArrayResize(m_persistent_ids,n+1);ArrayResize(m_persistent_id_records,n+1);for(int i=n;i>at;i--){m_persistent_ids[i]=m_persistent_ids[i-1];m_persistent_id_records[i]=m_persistent_id_records[i-1];}m_persistent_ids[at]=id;m_persistent_id_records[at]=record;}
   void AppendActive(const int record)
     {int n;if(m_persistent[record].type==E2_H1_ZONE_V2_SUPPORT){n=ArraySize(m_active_support);ArrayResize(m_active_support,n+1);m_active_support[n]=record;}else{n=ArraySize(m_active_resistance);ArrayResize(m_active_resistance,n+1);m_active_resistance[n]=record;}}
   void RemoveActiveAt(int &active[],const int at) const
     {const int n=ArraySize(active);for(int i=at+1;i<n;i++)active[i-1]=active[i];ArrayResize(active,n-1);}
   void ApplyPersistentInvalidation(E2H1ZoneV2Record &zone,const MqlRates &bars[],const double &atr[])
     {const int i=ArraySize(bars)-1;if(i<0||zone.state!=E2_H1_ZONE_V2_ACTIVE||atr[i]<=0.0)return;const datetime available=bars[i].time+PeriodSeconds(PERIOD_H1);if(available<zone.creation_time)return;const bool invalid=(zone.type==E2_H1_ZONE_V2_SUPPORT ? StrictBelow(bars[i].close,zone.lower-m_invalidation_atr*atr[i]) : StrictAbove(bars[i].close,zone.upper+m_invalidation_atr*atr[i]));if(!invalid)return;zone.state=E2_H1_ZONE_V2_INVALIDATED;zone.invalidation_time=available;zone.invalidation_close=bars[i].close;zone.invalidation_atr=atr[i];zone.invalidation_distance_atr=(zone.type==E2_H1_ZONE_V2_SUPPORT ? (zone.lower-bars[i].close)/atr[i] : (bars[i].close-zone.upper)/atr[i]);zone.invalidation_reason="H1_CLOSE_BEYOND_FAR_EDGE";if(zone.type==E2_H1_ZONE_V2_SUPPORT)m_persistent_diagnostics.invalidated_support++;else m_persistent_diagnostics.invalidated_resistance++;}
   void ReconcilePersistent(const E2H1ZoneV2Record &discovered[],const MqlRates &bars[],const double &atr[])
     {for(int i=0;i<ArraySize(discovered);i++){int p=PersistentIndex(discovered[i].zone_id);if(p>=0){m_workload.rediscovery_fast_hits++;m_persistent_diagnostics.duplicate_rediscoveries++;if(m_persistent[p].state==E2_H1_ZONE_V2_INVALIDATED&&discovered[i].state==E2_H1_ZONE_V2_ACTIVE)m_persistent_diagnostics.resurrection_attempts++;continue;}const int n=ArraySize(m_persistent);ArrayResize(m_persistent,n+1);m_persistent[n]=discovered[i];IndexPersistent(discovered[i].zone_id,n);if(m_persistent[n].state==E2_H1_ZONE_V2_ACTIVE)AppendActive(n);const bool support=(discovered[i].type==E2_H1_ZONE_V2_SUPPORT);if(!m_persistent_initialized){if(support)m_persistent_diagnostics.initialized_support++;else m_persistent_diagnostics.initialized_resistance++;}else{if(support)m_persistent_diagnostics.inserted_support++;else m_persistent_diagnostics.inserted_resistance++;}if(discovered[i].creation_time<=0)m_persistent_diagnostics.creation_causality_violations++;if(discovered[i].invalidation_time>0&&discovered[i].invalidation_time<discovered[i].creation_time)m_persistent_diagnostics.invalidation_before_creation++;}
      for(int role=0;role<2;role++){if(role==0){for(int i=ArraySize(m_active_support)-1;i>=0;i--){m_workload.persistent_active_invalidation_checks++;const int p=m_active_support[i];ApplyPersistentInvalidation(m_persistent[p],bars,atr);if(m_persistent[p].state!=E2_H1_ZONE_V2_ACTIVE)RemoveActiveAt(m_active_support,i);}}else{for(int i=ArraySize(m_active_resistance)-1;i>=0;i--){m_workload.persistent_active_invalidation_checks++;const int p=m_active_resistance[i];ApplyPersistentInvalidation(m_persistent[p],bars,atr);if(m_persistent[p].state!=E2_H1_ZONE_V2_ACTIVE)RemoveActiveAt(m_active_resistance,i);}}}
      const int active=ArraySize(m_active_support)+ArraySize(m_active_resistance);for(int role=0;role<2;role++){const int count=(role==0?ArraySize(m_active_support):ArraySize(m_active_resistance));for(int i=0;i<count;i++){const int p=(role==0?m_active_support[i]:m_active_resistance[i]);if(ArraySize(bars)>0&&(m_persistent[p].source_pivot_1_time<bars[0].time||m_persistent[p].source_pivot_2_time<bars[0].time)&&!ContainsId(m_seen_expiry_survival,m_persistent[p].zone_id)){RememberId(m_seen_expiry_survival,m_persistent[p].zone_id);m_persistent_diagnostics.survived_source_lookback_expiry++;}}}m_persistent_diagnostics.max_active=MathMax(m_persistent_diagnostics.max_active,active);m_persistent_diagnostics.max_total=MathMax(m_persistent_diagnostics.max_total,ArraySize(m_persistent));m_persistent_initialized=true;}
   void LogNewEvents(const E2H1ZoneV2Record &zones[],const datetime latest_available) const
     {
      if(m_logger==NULL || !m_logger.IsDebugEnabled() || !m_verbose)return;
      for(int i=0;i<ArraySize(zones);i++)
        {
         if(zones[i].creation_time==latest_available)m_logger.Debug("event=CREATED zoneId="+zones[i].zone_id+", type="+E2H1ZoneV2TypeName(zones[i].type)+", time="+TimeToString(zones[i].creation_time,TIME_DATE|TIME_MINUTES)+", lower="+DoubleToString(zones[i].lower,_Digits)+", upper="+DoubleToString(zones[i].upper,_Digits)+", p1="+TimeToString(zones[i].source_pivot_1_time,TIME_DATE|TIME_MINUTES)+", p2="+TimeToString(zones[i].source_pivot_2_time,TIME_DATE|TIME_MINUTES)+", atr="+DoubleToString(zones[i].creation_atr,_Digits)+".","H1ZoneV2");
         if(zones[i].invalidation_time==latest_available)m_logger.Debug("event=INVALIDATED zoneId="+zones[i].zone_id+", time="+TimeToString(zones[i].invalidation_time,TIME_DATE|TIME_MINUTES)+", distanceATR="+DoubleToString(zones[i].invalidation_distance_atr,3)+".","H1ZoneV2");
        }
     }
   void CopyRecords(E2H1ZoneV2Record &target[],const E2H1ZoneV2Record &source[]) const
     { ArrayResize(target,ArraySize(source));for(int i=0;i<ArraySize(source);i++)target[i]=source[i]; }
   void RecountVerification(const E2H1ZoneV2Record &zones[])
     {
      ZeroMemory(m_verification);
      for(int i=0;i<ArraySize(zones);i++)
        {
         const bool support=(zones[i].type==E2_H1_ZONE_V2_SUPPORT);
         if(support)m_verification.created_support++;else m_verification.created_resistance++;
         if(zones[i].state==E2_H1_ZONE_V2_INVALIDATED)
           {if(support)m_verification.invalidated_support++;else m_verification.invalidated_resistance++;}
         else
           {if(support)m_verification.active_support_end++;else m_verification.active_resistance_end++;}
        }
     }
   bool ContainsId(const string &ids[],const string id) const { for(int i=0;i<ArraySize(ids);i++)if(ids[i]==id)return(true);return(false); }
   void RememberId(string &ids[],const string id) const { if(ContainsId(ids,id))return;const int n=ArraySize(ids);ArrayResize(ids,n+1);ids[n]=id; }
   void RecordLifetime(const E2H1ZoneV2Record &zones[],const MqlRates &bars[])
     {
      bool support_active=false,resistance_active=false;
      for(int i=0;i<ArraySize(zones);i++)
        {
         const bool support=(zones[i].type==E2_H1_ZONE_V2_SUPPORT);
         if(!ContainsId(m_seen_created,zones[i].zone_id))
           {RememberId(m_seen_created,zones[i].zone_id);if(support)m_lifetime.support_created++;else m_lifetime.resistance_created++;}
         if(zones[i].state==E2_H1_ZONE_V2_INVALIDATED && !ContainsId(m_seen_invalidated,zones[i].zone_id))
           {RememberId(m_seen_invalidated,zones[i].zone_id);if(support)m_lifetime.support_invalidated++;else m_lifetime.resistance_invalidated++;}
         if(zones[i].state==E2_H1_ZONE_V2_ACTIVE)
           {if(support)support_active=true;else resistance_active=true;}
        }
      if(support_active)m_lifetime.support_bars++;
      if(resistance_active)m_lifetime.resistance_bars++;
      if(!m_has_cached || ArraySize(bars)==0)return;
      for(int i=0;i<ArraySize(m_cached);i++)
         if(m_cached[i].state==E2_H1_ZONE_V2_ACTIVE && !ZoneExists(zones,m_cached[i].zone_id) && (m_cached[i].source_pivot_1_time<bars[0].time || m_cached[i].source_pivot_2_time<bars[0].time))
            {m_lifetime.lookback_expiry_observed=true;return;}
     }
   void SortSamples(E2H1ZoneV2DepartureSample &samples[]) const
     {for(int i=1;i<ArraySize(samples);i++){E2H1ZoneV2DepartureSample value=samples[i];int j=i-1;while(j>=0 && samples[j].departure_atr>value.departure_atr){samples[j+1]=samples[j];j--;}samples[j+1]=value;}}
   void MeasureDepartures(const E2H1ZoneV2Pivot &pivots[],const bool high,const MqlRates &bars[])
     {
      E2H1ZoneV2DepartureSample samples[];double sum=0.0;
      for(int p=0;p<ArraySize(pivots);p++)
        {
         const int start=pivots[p].pivot_index+1;
         if(start>=ArraySize(bars) || pivots[p].qualification_atr<=0.0)continue;
         double best=(high ? bars[start].low : bars[start].high);
         for(int i=start+1;i<ArraySize(bars);i++)best=(high ? MathMin(best,bars[i].low) : MathMax(best,bars[i].high));
         E2H1ZoneV2DepartureSample sample;ZeroMemory(sample);sample.pivot_time=pivots[p].pivot_time;sample.known_from_time=pivots[p].known_from_time;sample.pivot_price=pivots[p].price;sample.frozen_atr=pivots[p].qualification_atr;sample.best_away_price=best;sample.distance=(high ? sample.pivot_price-best : best-sample.pivot_price);sample.departure_atr=sample.distance/sample.frozen_atr;
         const int n=ArraySize(samples);ArrayResize(samples,n+1);samples[n]=sample;sum+=sample.departure_atr;
        }
      SortSamples(samples);const int count=ArraySize(samples);if(count==0)return;
      if(high)
        {m_departure_magnitude.highs=count;m_departure_magnitude.high_average=sum/count;m_departure_magnitude.high_median=(count%2==0 ? (samples[count/2-1].departure_atr+samples[count/2].departure_atr)/2.0 : samples[count/2].departure_atr);m_departure_magnitude.high_max=samples[count-1].departure_atr;m_departure_magnitude.high_smallest=samples[0];m_departure_magnitude.high_median_sample=samples[count/2];m_departure_magnitude.high_greatest=samples[count-1];for(int i=0;i<count;i++){const double v=samples[i].departure_atr;if(v>=0.25)m_departure_magnitude.high_025++;if(v>=0.50)m_departure_magnitude.high_050++;if(v>=0.75)m_departure_magnitude.high_075++;if(v>=1.00)m_departure_magnitude.high_100++;if(v>=1.25)m_departure_magnitude.high_125++;}}
      else
        {m_departure_magnitude.lows=count;m_departure_magnitude.low_average=sum/count;m_departure_magnitude.low_median=(count%2==0 ? (samples[count/2-1].departure_atr+samples[count/2].departure_atr)/2.0 : samples[count/2].departure_atr);m_departure_magnitude.low_max=samples[count-1].departure_atr;m_departure_magnitude.low_smallest=samples[0];m_departure_magnitude.low_median_sample=samples[count/2];m_departure_magnitude.low_greatest=samples[count-1];for(int i=0;i<count;i++){const double v=samples[i].departure_atr;if(v>=0.25)m_departure_magnitude.low_025++;if(v>=0.50)m_departure_magnitude.low_050++;if(v>=0.75)m_departure_magnitude.low_075++;if(v>=1.00)m_departure_magnitude.low_100++;if(v>=1.25)m_departure_magnitude.low_125++;}}
     }
   void BuildZonesFromPivots(const string symbol,const E2H1ZoneV2Type type,const E2H1ZoneV2Pivot &pivots[],E2H1ZoneV2Record &result[],const MqlRates &bars[],const double &atr[])
     {
      const bool expect_high=(type==E2_H1_ZONE_V2_RESISTANCE);
      for(int second=1;second<ArraySize(pivots);second++)
        {
         E2H1ZoneV2Pivot two=pivots[second];
         // Defensive role guard: a high pair can only create RESISTANCE and
         // a low pair can only create SUPPORT.
         if(two.high!=expect_high || !two.departure_qualified)continue;
         for(int first=second-1;first>=0;first--)
           {
            E2H1ZoneV2Pivot one=pivots[first];if(one.high!=expect_high || !one.departure_qualified)continue;
            if(expect_high)m_role_gate.high_prior_candidates_checked++;else m_role_gate.low_prior_candidates_checked++;
            if(MathAbs(two.pivot_index-one.pivot_index)<m_min_separation)continue;
            if(expect_high)m_role_gate.high_separation_pass++;else m_role_gate.low_separation_pass++;
            if(MathAbs(two.price-one.price)>m_cluster_atr*two.qualification_atr+Epsilon(two.qualification_atr))continue;
            if(expect_high)m_role_gate.high_cluster_pass++;else m_role_gate.low_cluster_pass++;
            const datetime creation=MathMax(two.known_from_time,two.departure_confirmed_time);const string id=ZoneId(symbol,type,one,two,creation);if(ZoneExists(result,id))continue;
            E2H1ZoneV2Record zone;ResetRecord(zone,type);zone.zone_id=id;zone.creation_time=creation;zone.lower=MathMin(one.price,two.price);zone.upper=MathMax(one.price,two.price);zone.creation_atr=two.qualification_atr;
            zone.source_pivot_1_id=one.id;zone.source_pivot_1_time=one.pivot_time;zone.source_pivot_1_known_from=one.known_from_time;zone.source_pivot_1_departure_confirmed_time=one.departure_confirmed_time;zone.source_pivot_1_price=one.price;
            zone.source_pivot_2_id=two.id;zone.source_pivot_2_time=two.pivot_time;zone.source_pivot_2_known_from=two.known_from_time;zone.source_pivot_2_departure_confirmed_time=two.departure_confirmed_time;zone.source_pivot_2_price=two.price;
            BuildInteractions(zone,bars,atr);AppendZone(result,zone);
            if(expect_high)m_role_gate.resistance_created++;else m_role_gate.support_created++;
            break;
           }
        }
     }
public:
   E2H1ZoneEngine(void):m_market(NULL),m_logger(NULL),m_strength(3),m_lookback(240),m_atr_period(14),m_min_separation(3),m_cluster_atr(0.50),m_departure_atr(1.00),m_invalidation_atr(0.10),m_rearm_atr(0.50),m_last_closed(0),m_last_known_from(0),m_last_atr(0.0),m_last_close(0.0),m_has_cached(false),m_verbose(false),m_persistent_initialized(false) {ZeroMemory(m_verification);ZeroMemory(m_role_gate);ZeroMemory(m_departure_window);ZeroMemory(m_departure_magnitude);ZeroMemory(m_lifetime);ZeroMemory(m_persistent_diagnostics);ZeroMemory(m_workload);}
   void Initialize(const E2Config &config,E2MarketData &market,E2Logger &logger)
     {m_market=&market;m_logger=&logger;m_verbose=config.research_verbose_diagnostics;m_strength=3;m_lookback=config.zone_lookback_bars;m_atr_period=config.research_h1_atr_period;m_min_separation=config.research_h1_minimum_touch_separation_bars;m_cluster_atr=config.research_h1_zone_pivot_clustering_atr;m_departure_atr=config.research_h1_minimum_post_touch_departure_atr;m_invalidation_atr=config.research_h1_zone_invalidation_atr;m_rearm_atr=config.research_h1_zone_rearm_distance_atr;m_last_closed=0;m_last_known_from=0;m_last_atr=0.0;m_last_close=0.0;m_has_cached=false;m_persistent_initialized=false;ArrayResize(m_cached,0);ArrayResize(m_persistent,0);ArrayResize(m_persistent_ids,0);ArrayResize(m_persistent_id_records,0);ArrayResize(m_active_support,0);ArrayResize(m_active_resistance,0);ArrayResize(m_seen_created,0);ArrayResize(m_seen_invalidated,0);ArrayResize(m_seen_expiry_survival,0);ZeroMemory(m_verification);ZeroMemory(m_role_gate);ZeroMemory(m_departure_window);ZeroMemory(m_departure_magnitude);ZeroMemory(m_lifetime);ZeroMemory(m_persistent_diagnostics);ZeroMemory(m_workload);}
   datetime LastClosedTime(void) const { return(m_last_closed); }
   datetime LastKnownFrom(void) const { return(m_last_known_from); }
   double LastAtr(void) const { return(m_last_atr); }
   double LastClose(void) const { return(m_last_close); }
   E2H1ZoneV2Verification Verification(void) const { return(m_verification); }
   E2H1ZoneV2RoleGate RoleGate(void) const { return(m_role_gate); }
   E2H1ZoneV2DepartureWindow DepartureWindow(void) const { return(m_departure_window); }
   E2H1ZoneV2DepartureMagnitude DepartureMagnitude(void) const { return(m_departure_magnitude); }
   E2H1ZoneV2Lifetime Lifetime(void) const { return(m_lifetime); }
   E2H1ZoneV2PersistentDiagnostics PersistentDiagnostics(void) const {return(m_persistent_diagnostics);}
   E2H1ZoneV2Workload Workload(void) const {return(m_workload);}
   void ActiveZones(E2H1ZoneV2Record &result[])
     {const int ns=ArraySize(m_active_support),nr=ArraySize(m_active_resistance);ArrayResize(result,ns+nr);for(int i=0;i<ns;i++)result[i]=m_persistent[m_active_support[i]];for(int i=0;i<nr;i++)result[ns+i]=m_persistent[m_active_resistance[i]];m_workload.active_zone_exports++;}
   bool Evaluate(const string symbol,const datetime evaluation_time,E2H1ZoneV2Record &result[])
     {
      ArrayResize(result,0);if(m_market==NULL)return(false);MqlRates latest;
      if(!m_market.GetClosedBarAsOf(symbol,PERIOD_H1,evaluation_time,latest))return(false);
      if(m_has_cached && latest.time==m_last_closed){CopyRecords(result,m_cached);return(true);}
      MqlRates bars[];if(!m_market.GetClosedBarsAsOf(symbol,PERIOD_H1,evaluation_time,m_lookback,bars))return(false);
      double atr[];if(!Atr(bars,atr))return(false);
      E2H1ZoneV2Pivot highs[],lows[];
      ZeroMemory(m_role_gate);
      ZeroMemory(m_departure_window);
      ZeroMemory(m_departure_magnitude);
      const int seconds=PeriodSeconds(PERIOD_H1),count=ArraySize(bars);
      for(int i=m_strength;i<count;i++)
        {
         const int pivot=i-m_strength;if(pivot<m_strength || i>=count || atr[i]<=0.0)continue;
         E2H1ZoneV2Pivot value;ZeroMemory(value);value.pivot_index=pivot;value.pivot_time=bars[pivot].time;value.known_from_time=bars[i].time+seconds;value.qualification_atr=atr[i];
         if(Pivot(bars,pivot,true)){value.high=true;value.price=bars[pivot].high;value.id=PivotId(true,value.pivot_time);m_role_gate.confirmed_swing_highs++;QualifyDeparture(value,bars);if(value.departure_qualified)m_role_gate.qualified_high_departures++;AppendPivot(highs,value);}
         if(Pivot(bars,pivot,false)){value.high=false;value.price=bars[pivot].low;value.id=PivotId(false,value.pivot_time);m_role_gate.confirmed_swing_lows++;QualifyDeparture(value,bars);if(value.departure_qualified)m_role_gate.qualified_low_departures++;AppendPivot(lows,value);}
        }
      // Current departure search is pivot_index + 1 through the latest closed
      // H1 bar, which is exactly the requested pivot-to-present comparison.
      m_departure_window.current_high=m_role_gate.qualified_high_departures;
      m_departure_window.current_low=m_role_gate.qualified_low_departures;
      m_departure_window.pivot_window_high=m_role_gate.qualified_high_departures;
      m_departure_window.pivot_window_low=m_role_gate.qualified_low_departures;
      MeasureDepartures(highs,true,bars);
      MeasureDepartures(lows,false,bars);
      BuildZonesFromPivots(symbol,E2_H1_ZONE_V2_SUPPORT,lows,result,bars,atr);BuildZonesFromPivots(symbol,E2_H1_ZONE_V2_RESISTANCE,highs,result,bars,atr);
      E2H1ZoneV2Record discovered[];CopyRecords(discovered,result);
      ReconcilePersistent(discovered,bars,atr);
      CopyRecords(result,m_persistent);
      RecountVerification(result);
      RecordLifetime(result,bars);
      CopyRecords(m_cached,result);m_last_closed=latest.time;m_last_known_from=latest.time+seconds;m_last_atr=atr[count-1];m_last_close=bars[count-1].close;m_has_cached=true;LogNewEvents(result,latest.time+seconds);return(true);
     }
  };

#endif // E2_ANALYSIS_E2H1ZONEENGINE_MQH
