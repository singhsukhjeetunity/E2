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

class E2H1ZoneEngine
  {
private:
   E2MarketData *m_market;
   E2Logger *m_logger;
   int m_strength,m_lookback,m_atr_period,m_min_separation;
   double m_cluster_atr,m_departure_atr,m_invalidation_atr,m_rearm_atr;
   datetime m_last_closed;
   bool m_has_cached;
   E2H1ZoneV2Record m_cached[];

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
         if(departed){pivot.departure_qualified=true;pivot.departure_confirmed_time=bars[i].time+PeriodSeconds(PERIOD_H1);return;}
        }
     }
   void ResetRecord(E2H1ZoneV2Record &zone) const
     {
      ZeroMemory(zone);zone.type=E2_H1_ZONE_V2_SUPPORT;zone.state=E2_H1_ZONE_V2_ACTIVE;zone.invalidation_reason="";zone.merged_from_ids="";
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
   void LogNewEvents(const E2H1ZoneV2Record &zones[],const datetime latest_available) const
     {
      if(m_logger==NULL || !m_logger.IsDebugEnabled())return;
      for(int i=0;i<ArraySize(zones);i++)
        {
         if(zones[i].creation_time==latest_available)m_logger.Debug("event=CREATED zoneId="+zones[i].zone_id+", type="+E2H1ZoneV2TypeName(zones[i].type)+", time="+TimeToString(zones[i].creation_time,TIME_DATE|TIME_MINUTES)+", lower="+DoubleToString(zones[i].lower,_Digits)+", upper="+DoubleToString(zones[i].upper,_Digits)+", p1="+TimeToString(zones[i].source_pivot_1_time,TIME_DATE|TIME_MINUTES)+", p2="+TimeToString(zones[i].source_pivot_2_time,TIME_DATE|TIME_MINUTES)+", atr="+DoubleToString(zones[i].creation_atr,_Digits)+".","H1ZoneV2");
         if(zones[i].invalidation_time==latest_available)m_logger.Debug("event=INVALIDATED zoneId="+zones[i].zone_id+", time="+TimeToString(zones[i].invalidation_time,TIME_DATE|TIME_MINUTES)+", distanceATR="+DoubleToString(zones[i].invalidation_distance_atr,3)+".","H1ZoneV2");
        }
     }
   void CopyRecords(E2H1ZoneV2Record &target[],const E2H1ZoneV2Record &source[]) const
     { ArrayResize(target,ArraySize(source));for(int i=0;i<ArraySize(source);i++)target[i]=source[i]; }
   void BuildZonesFromPivots(const string symbol,const E2H1ZoneV2Type type,const E2H1ZoneV2Pivot &pivots[],E2H1ZoneV2Record &result[],const MqlRates &bars[],const double &atr[]) const
     {
      for(int second=1;second<ArraySize(pivots);second++)
        {
         E2H1ZoneV2Pivot two=pivots[second];if(!two.departure_qualified)continue;
         for(int first=0;first<second;first++)
           {
            E2H1ZoneV2Pivot one=pivots[first];if(!one.departure_qualified || MathAbs(two.pivot_index-one.pivot_index)<m_min_separation)continue;
            if(MathAbs(two.price-one.price)>m_cluster_atr*two.qualification_atr+Epsilon(two.qualification_atr))continue;
            const datetime creation=MathMax(two.known_from_time,two.departure_confirmed_time);const string id=ZoneId(symbol,type,one,two,creation);if(ZoneExists(result,id))continue;
            E2H1ZoneV2Record zone;ResetRecord(zone);zone.zone_id=id;zone.type=type;zone.creation_time=creation;zone.lower=MathMin(one.price,two.price);zone.upper=MathMax(one.price,two.price);zone.creation_atr=two.qualification_atr;
            zone.source_pivot_1_id=one.id;zone.source_pivot_1_time=one.pivot_time;zone.source_pivot_1_known_from=one.known_from_time;zone.source_pivot_1_departure_confirmed_time=one.departure_confirmed_time;zone.source_pivot_1_price=one.price;
            zone.source_pivot_2_id=two.id;zone.source_pivot_2_time=two.pivot_time;zone.source_pivot_2_known_from=two.known_from_time;zone.source_pivot_2_departure_confirmed_time=two.departure_confirmed_time;zone.source_pivot_2_price=two.price;
            BuildInteractions(zone,bars,atr);AppendZone(result,zone);
           }
        }
     }
public:
   E2H1ZoneEngine(void):m_market(NULL),m_logger(NULL),m_strength(3),m_lookback(240),m_atr_period(14),m_min_separation(3),m_cluster_atr(0.50),m_departure_atr(1.00),m_invalidation_atr(0.10),m_rearm_atr(0.50),m_last_closed(0),m_has_cached(false) {}
   void Initialize(const E2Config &config,E2MarketData &market,E2Logger &logger)
     {m_market=&market;m_logger=&logger;m_strength=3;m_lookback=config.zone_lookback_bars;m_atr_period=config.research_h1_atr_period;m_min_separation=config.research_h1_minimum_touch_separation_bars;m_cluster_atr=config.research_h1_zone_pivot_clustering_atr;m_departure_atr=config.research_h1_minimum_post_touch_departure_atr;m_invalidation_atr=config.research_h1_zone_invalidation_atr;m_rearm_atr=config.research_h1_zone_rearm_distance_atr;m_last_closed=0;m_has_cached=false;ArrayResize(m_cached,0);}
   datetime LastClosedTime(void) const { return(m_last_closed); }
   bool Evaluate(const string symbol,const datetime evaluation_time,E2H1ZoneV2Record &result[])
     {
      ArrayResize(result,0);if(m_market==NULL)return(false);MqlRates latest;
      if(!m_market.GetClosedBarAsOf(symbol,PERIOD_H1,evaluation_time,latest))return(false);
      if(m_has_cached && latest.time==m_last_closed){CopyRecords(result,m_cached);return(true);}
      MqlRates bars[];if(!m_market.GetClosedBarsAsOf(symbol,PERIOD_H1,evaluation_time,m_lookback,bars))return(false);
      double atr[];if(!Atr(bars,atr))return(false);
      E2H1ZoneV2Pivot highs[],lows[];
      const int seconds=PeriodSeconds(PERIOD_H1),count=ArraySize(bars);
      for(int i=m_strength;i<count;i++)
        {
         const int pivot=i-m_strength;if(pivot<m_strength || i>=count || atr[i]<=0.0)continue;
         E2H1ZoneV2Pivot value;ZeroMemory(value);value.pivot_index=pivot;value.pivot_time=bars[pivot].time;value.known_from_time=bars[i].time+seconds;value.qualification_atr=atr[i];
         if(Pivot(bars,pivot,true)){value.high=true;value.id=PivotId(true,value.pivot_time);QualifyDeparture(value,bars);AppendPivot(highs,value);}
         if(Pivot(bars,pivot,false)){value.high=false;value.id=PivotId(false,value.pivot_time);QualifyDeparture(value,bars);AppendPivot(lows,value);}
        }
      BuildZonesFromPivots(symbol,E2_H1_ZONE_V2_SUPPORT,lows,result,bars,atr);BuildZonesFromPivots(symbol,E2_H1_ZONE_V2_RESISTANCE,highs,result,bars,atr);
      CopyRecords(m_cached,result);m_last_closed=latest.time;m_has_cached=true;LogNewEvents(result,latest.time+seconds);return(true);
     }
  };

#endif // E2_ANALYSIS_E2H1ZONEENGINE_MQH
