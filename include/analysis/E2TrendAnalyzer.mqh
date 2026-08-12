#ifndef E2_ANALYSIS_E2TRENDANALYZER_MQH
#define E2_ANALYSIS_E2TRENDANALYZER_MQH

#include "E2MarketData.mqh"

enum E2TrendState
  {
   E2_TREND_UNKNOWN,
   E2_TREND_BULLISH,
   E2_TREND_BEARISH,
   E2_TREND_RANGE
  };

enum E2PivotType
  {
   E2_PIVOT_HIGH,
   E2_PIVOT_LOW
  };

enum E2StructureLabel
  {
   E2_STRUCTURE_NONE,
   E2_STRUCTURE_HH,
   E2_STRUCTURE_HL,
   E2_STRUCTURE_LH,
   E2_STRUCTURE_LL
  };

struct E2Pivot
  {
   E2PivotType       type;
   datetime          time;
   double            price;
  };

struct E2TrendResult
  {
   E2TrendState      state;
   bool              adx_available;
   double            adx_value;
   bool              adx_passed;
   datetime          closed_bar_time;
   int               h4_available_bars;
   int               adx_required_bars;
   string            readiness_reason;
   int               confirmed_pivot_count;
   E2StructureLabel  latest_high_label;
   E2StructureLabel  latest_low_label;
  };

string E2TrendStateName(const E2TrendState state)
  {
   switch(state)
     {
      case E2_TREND_BULLISH: return("BULLISH");
      case E2_TREND_BEARISH: return("BEARISH");
      case E2_TREND_RANGE:   return("RANGE");
      default:                return("UNKNOWN");
     }
  }

string E2StructureLabelName(const E2StructureLabel label)
  {
   switch(label)
     {
      case E2_STRUCTURE_HH: return("HH");
      case E2_STRUCTURE_HL: return("HL");
      case E2_STRUCTURE_LH: return("LH");
      case E2_STRUCTURE_LL: return("LL");
      default:               return("NONE");
     }
  }

class E2TrendAnalyzer
  {
private:
   E2MarketData      *m_market_data;
   E2Logger          *m_logger;
   int               m_sensitivity;
   int               m_lookback_bars;
   bool              m_adx_enabled;
   int               m_adx_period;
   double            m_adx_minimum_threshold;

   void ResetResult(E2TrendResult &result)
     {
      result.state=E2_TREND_UNKNOWN;
      result.adx_available=false;
      result.adx_value=0.0;
      result.adx_passed=false;
      result.closed_bar_time=0;
      result.h4_available_bars=0;
      result.adx_required_bars=0;
      result.readiness_reason="UNKNOWN";
      result.confirmed_pivot_count=0;
      result.latest_high_label=E2_STRUCTURE_NONE;
      result.latest_low_label=E2_STRUCTURE_NONE;
     }


   bool IsPivotHigh(const MqlRates &bars[],const int index) const
     {
      const double value=bars[index].high;
      for(int offset=1; offset<=m_sensitivity; offset++)
         if(value<=bars[index-offset].high || value<=bars[index+offset].high)
            return(false);
      return(true);
     }

   bool IsPivotLow(const MqlRates &bars[],const int index) const
     {
      const double value=bars[index].low;
      for(int offset=1; offset<=m_sensitivity; offset++)
         if(value>=bars[index-offset].low || value>=bars[index+offset].low)
            return(false);
      return(true);
     }

   void AddResolvedPivot(E2Pivot &pivots[],const E2Pivot &candidate)
     {
      const int count=ArraySize(pivots);
      if(count==0)
        {
         ArrayResize(pivots,1);
         pivots[0]=candidate;
         return;
        }

      const int last_index=count-1;
      if(pivots[last_index].type!=candidate.type)
        {
         ArrayResize(pivots,count+1);
         pivots[count]=candidate;
         return;
        }

      // Consecutive same-type pivots collapse to their more extreme price.
      // This ensures a minor high cannot become structural before a low, or
      // a minor low before a high, has separated the sequence.
      if((candidate.type==E2_PIVOT_HIGH && candidate.price>pivots[last_index].price) ||
         (candidate.type==E2_PIVOT_LOW && candidate.price<pivots[last_index].price))
         pivots[last_index]=candidate;
     }

   void DetectConfirmedPivots(const MqlRates &bars[],E2Pivot &pivots[])
     {
      ArrayResize(pivots,0);
      const int count=ArraySize(bars);
      // The final sensitivity bars are excluded: they cannot yet confirm the
      // right side of a pivot at this historical as-of evaluation time.
      for(int index=m_sensitivity; index<count-m_sensitivity; index++)
        {
         const bool is_high=IsPivotHigh(bars,index);
         const bool is_low=IsPivotLow(bars,index);
         // A wide outside candle can satisfy both tests. It is not assigned a
         // structural direction, preventing one timestamp from creating an
         // artificial high/low alternation.
         if(is_high && is_low)
            continue;

         E2Pivot candidate;
         if(is_high)
           {
            candidate.type=E2_PIVOT_HIGH;
            candidate.time=bars[index].time;
            candidate.price=bars[index].high;
            AddResolvedPivot(pivots,candidate);
           }
         else if(is_low)
           {
            candidate.type=E2_PIVOT_LOW;
            candidate.time=bars[index].time;
            candidate.price=bars[index].low;
            AddResolvedPivot(pivots,candidate);
           }
        }
     }

   E2TrendState ClassifyStructure(const E2Pivot &pivots[],E2TrendResult &result) const
     {
      const int count=ArraySize(pivots);
      result.confirmed_pivot_count=count;
      if(count<4)
         return(E2_TREND_RANGE);

      const E2Pivot first_high=pivots[count-4].type==E2_PIVOT_HIGH ? pivots[count-4] : pivots[count-3];
      const E2Pivot first_low=pivots[count-4].type==E2_PIVOT_LOW ? pivots[count-4] : pivots[count-3];
      const E2Pivot last_high=pivots[count-2].type==E2_PIVOT_HIGH ? pivots[count-2] : pivots[count-1];
      const E2Pivot last_low=pivots[count-2].type==E2_PIVOT_LOW ? pivots[count-2] : pivots[count-1];

      if(last_high.price>first_high.price)
         result.latest_high_label=E2_STRUCTURE_HH;
      else if(last_high.price<first_high.price)
         result.latest_high_label=E2_STRUCTURE_LH;

      if(last_low.price>first_low.price)
         result.latest_low_label=E2_STRUCTURE_HL;
      else if(last_low.price<first_low.price)
         result.latest_low_label=E2_STRUCTURE_LL;

      if(result.latest_high_label==E2_STRUCTURE_HH && result.latest_low_label==E2_STRUCTURE_HL)
         return(E2_TREND_BULLISH);
      if(result.latest_high_label==E2_STRUCTURE_LH && result.latest_low_label==E2_STRUCTURE_LL)
         return(E2_TREND_BEARISH);
      return(E2_TREND_RANGE);
     }

   bool ReadInternalAdx(const string symbol,const datetime evaluation_time,E2TrendResult &result)
     {
      // Wilder ADX needs period observations to seed smoothed TR/+DM/-DM and
      // another period of DX observations to seed ADX. 2*period+1 bars gives
      // that seed plus one endpoint update, all ending at evaluation_time.
      result.adx_required_bars=m_adx_period*2+1;
      MqlRates bars[];
      if(!m_market_data.GetClosedBarsAsOf(symbol,m_market_data.TrendTimeframe(),evaluation_time,result.adx_required_bars,bars))
        {
         result.readiness_reason="Insufficient closed H4 history for Wilder ADX (requires "+IntegerToString(result.adx_required_bars)+" bars).";
         return(false);
        }

      if(ArraySize(bars)!=result.adx_required_bars)
        {
         result.readiness_reason="Closed H4 history for Wilder ADX is incomplete.";
         return(false);
        }

      double smoothed_tr=0.0;
      double smoothed_plus_dm=0.0;
      double smoothed_minus_dm=0.0;
      double adx_sum=0.0;
      double adx=0.0;
      int dx_count=0;
      for(int index=1;index<ArraySize(bars);index++)
        {
         const MqlRates current=bars[index];
         const MqlRates previous=bars[index-1];
         if(!MathIsValidNumber(current.high) || !MathIsValidNumber(current.low) || !MathIsValidNumber(current.close) || !MathIsValidNumber(previous.high) || !MathIsValidNumber(previous.low) || !MathIsValidNumber(previous.close) || current.high<current.low)
           {
            result.readiness_reason="Closed H4 OHLC contains an invalid value for Wilder ADX.";
            return(false);
           }

         const double upward_move=current.high-previous.high;
         const double downward_move=previous.low-current.low;
         const double plus_dm=(upward_move>downward_move && upward_move>0.0 ? upward_move : 0.0);
         const double minus_dm=(downward_move>upward_move && downward_move>0.0 ? downward_move : 0.0);
         const double true_range=MathMax(current.high-current.low,MathMax(MathAbs(current.high-previous.close),MathAbs(current.low-previous.close)));
         if(!MathIsValidNumber(true_range) || true_range<0.0)
           {
            result.readiness_reason="True Range calculation failed for closed H4 data.";
            return(false);
           }

         if(index<=m_adx_period)
           {
            smoothed_tr+=true_range;
            smoothed_plus_dm+=plus_dm;
            smoothed_minus_dm+=minus_dm;
           }
         else
           {
            smoothed_tr=smoothed_tr-(smoothed_tr/m_adx_period)+true_range;
            smoothed_plus_dm=smoothed_plus_dm-(smoothed_plus_dm/m_adx_period)+plus_dm;
            smoothed_minus_dm=smoothed_minus_dm-(smoothed_minus_dm/m_adx_period)+minus_dm;
           }

         if(index<m_adx_period)
            continue;

         const double plus_di=(smoothed_tr>0.0 ? 100.0*smoothed_plus_dm/smoothed_tr : 0.0);
         const double minus_di=(smoothed_tr>0.0 ? 100.0*smoothed_minus_dm/smoothed_tr : 0.0);
         const double di_sum=plus_di+minus_di;
         const double dx=(di_sum>0.0 ? 100.0*MathAbs(plus_di-minus_di)/di_sum : 0.0);
         if(!MathIsValidNumber(dx))
           {
            result.readiness_reason="DX calculation produced an invalid value.";
            return(false);
           }

         dx_count++;
         if(dx_count<=m_adx_period)
           {
            adx_sum+=dx;
            if(dx_count==m_adx_period)
               adx=adx_sum/m_adx_period;
           }
         else
            adx=((adx*(m_adx_period-1))+dx)/m_adx_period;
        }

      if(dx_count<m_adx_period || !MathIsValidNumber(adx))
        {
         result.readiness_reason="Wilder ADX seed is incomplete.";
         return(false);
        }

      result.adx_value=adx;
      return(true);
     }

public:
                     E2TrendAnalyzer(void) : m_market_data(NULL),m_logger(NULL),m_sensitivity(0),m_lookback_bars(0),m_adx_enabled(false),m_adx_period(0),m_adx_minimum_threshold(0.0) {}

   void              Initialize(const E2Config &configuration,E2MarketData &market_data,E2Logger &logger)
     {
      Deinitialize();
      m_market_data=&market_data;
      m_logger=&logger;
      m_sensitivity=configuration.swing_sensitivity;
      m_lookback_bars=configuration.trend_structure_lookback_bars;
      m_adx_enabled=configuration.adx_enabled;
      m_adx_period=configuration.adx_period;
      m_adx_minimum_threshold=configuration.adx_minimum_threshold;
     }

   void              Deinitialize(void)
     {
     }

   bool              Evaluate(const string symbol,const datetime evaluation_time,E2TrendResult &result)
     {
      ResetResult(result);
      if(m_market_data==NULL)
        {
         result.readiness_reason="Market-data module is not initialized.";
         return(false);
        }

      result.h4_available_bars=Bars(symbol,m_market_data.TrendTimeframe());
      MqlRates bars[];
      if(!m_market_data.GetClosedBarsAsOf(symbol,m_market_data.TrendTimeframe(),evaluation_time,m_lookback_bars,bars))
        {
         result.readiness_reason="H4 market history is not ready or has fewer than "+IntegerToString(m_lookback_bars)+" requested bars.";
         return(false);
        }

      if(ArraySize(bars)!=m_lookback_bars)
        {
         result.readiness_reason="H4 structure history returned an incomplete bar range.";
         return(false);
        }

      result.closed_bar_time=bars[ArraySize(bars)-1].time;

      E2Pivot pivots[];
      DetectConfirmedPivots(bars,pivots);
      const E2TrendState structural_state=ClassifyStructure(pivots,result);

      if(!m_adx_enabled)
        {
         result.adx_passed=true;
         result.state=structural_state;
         result.readiness_reason="READY (ADX disabled).";
         return(true);
        }

      if(!ReadInternalAdx(symbol,evaluation_time,result))
         return(false);

      result.adx_available=true;
      result.adx_passed=(result.adx_value>=m_adx_minimum_threshold);
      result.state=(structural_state==E2_TREND_RANGE || !result.adx_passed) ? E2_TREND_RANGE : structural_state;
      result.readiness_reason="READY";
      return(true);
     }
  };

#endif // E2_ANALYSIS_E2TRENDANALYZER_MQH
