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
   int               m_adx_handle;
   string            m_adx_symbol;

   void ResetResult(E2TrendResult &result)
     {
      result.state=E2_TREND_UNKNOWN;
      result.adx_available=false;
      result.adx_value=0.0;
      result.adx_passed=false;
      result.confirmed_pivot_count=0;
      result.latest_high_label=E2_STRUCTURE_NONE;
      result.latest_low_label=E2_STRUCTURE_NONE;
     }

   void ReportDebug(const string message)
     {
      if(m_logger!=NULL)
         m_logger.Debug(message,"Trend");
     }

   void ReleaseAdxHandle(void)
     {
      if(m_adx_handle!=INVALID_HANDLE)
         IndicatorRelease(m_adx_handle);
      m_adx_handle=INVALID_HANDLE;
      m_adx_symbol="";
     }

   bool EnsureAdxHandle(const string symbol)
     {
      if(m_adx_handle!=INVALID_HANDLE && m_adx_symbol==symbol)
         return(true);

      ReleaseAdxHandle();
      ResetLastError();
      m_adx_handle=iADX(symbol,m_market_data.TrendTimeframe(),m_adx_period);
      if(m_adx_handle==INVALID_HANDLE)
        {
         ReportDebug("Unable to create ADX handle (error "+IntegerToString(GetLastError())+").");
         return(false);
        }
      m_adx_symbol=symbol;
      return(true);
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

   bool ReadClosedAdx(const string symbol,const datetime evaluation_time,double &adx_value)
     {
      if(!EnsureAdxHandle(symbol))
         return(false);

      MqlRates closed_bar;
      if(!m_market_data.GetClosedBarAsOf(symbol,m_market_data.TrendTimeframe(),evaluation_time,closed_bar))
         return(false);

      const int bar_shift=iBarShift(symbol,m_market_data.TrendTimeframe(),closed_bar.time,true);
      if(bar_shift<0 || BarsCalculated(m_adx_handle)<=bar_shift)
        {
         ReportDebug("ADX data is not ready for the requested closed H4 bar.");
         return(false);
        }

      double values[];
      ResetLastError();
      const int copied=CopyBuffer(m_adx_handle,0,bar_shift,1,values);
      if(copied!=1)
        {
         ReportDebug("Unable to read closed ADX data (copied "+IntegerToString(copied)+", error "+IntegerToString(GetLastError())+").");
         return(false);
        }
      adx_value=values[0];
      return(true);
     }

public:
                     E2TrendAnalyzer(void) : m_market_data(NULL),m_logger(NULL),m_sensitivity(0),m_lookback_bars(0),m_adx_enabled(false),m_adx_period(0),m_adx_minimum_threshold(0.0),m_adx_handle(INVALID_HANDLE),m_adx_symbol("") {}

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
      ReleaseAdxHandle();
     }

   bool              Evaluate(const string symbol,const datetime evaluation_time,E2TrendResult &result)
     {
      ResetResult(result);
      if(m_market_data==NULL)
        {
         ReportDebug("Trend evaluation requested before market-data initialization.");
         return(false);
        }

      MqlRates bars[];
      if(!m_market_data.GetClosedBarsAsOf(symbol,m_market_data.TrendTimeframe(),evaluation_time,m_lookback_bars,bars))
         return(false);

      E2Pivot pivots[];
      DetectConfirmedPivots(bars,pivots);
      const E2TrendState structural_state=ClassifyStructure(pivots,result);
      if(structural_state==E2_TREND_RANGE)
        {
         result.state=E2_TREND_RANGE;
         return(true);
        }

      if(!m_adx_enabled)
        {
         result.adx_passed=true;
         result.state=structural_state;
         return(true);
        }

      double adx_value=0.0;
      if(!ReadClosedAdx(symbol,evaluation_time,adx_value))
         return(false);

      result.adx_available=true;
      result.adx_value=adx_value;
      result.adx_passed=(adx_value>=m_adx_minimum_threshold);
      result.state=result.adx_passed ? structural_state : E2_TREND_RANGE;
      return(true);
     }
  };

#endif // E2_ANALYSIS_E2TRENDANALYZER_MQH
