#ifndef E2_ANALYSIS_E2H4REGIMEENGINE_MQH
#define E2_ANALYSIS_E2H4REGIMEENGINE_MQH

#include "E2MarketData.mqh"

enum E2H4BreakDirection { E2_H4_BREAK_NONE,E2_H4_BREAK_BULLISH,E2_H4_BREAK_BEARISH };

struct E2H4RegimeSwing
  {
   bool valid;
   bool high;
   datetime pivot_time,known_from_time;
   double price;
  };

struct E2H4RangeVerification
  {
   long h4_contexts,uptrend_contexts,downtrend_contexts,range_contexts,neutral_contexts,insufficient_data,range_adx_pass,range_containment_checks,range_width_pass,range_classifications,causality_violations;
   double average_range_width_atr,minimum_range_width_atr,maximum_range_width_atr;
  };

struct E2H4RegimeResult
  {
   bool ready,trend_entry_eligible,trend_overextended,range_valid,range_measurements_valid;
   datetime evaluation_time,closed_h4_time,known_from_time,breakout_time;
   E2RegimeType regime;
   E2H4BreakDirection active_break_direction;
   double latest_close,ema20,ema50,ema50_five_bars_ago,adx,atr,distance_close_to_ema20,distance_close_to_ema20_atr;
   E2H4RegimeSwing latest_swing_high,previous_swing_high,latest_swing_low,previous_swing_low;
   bool bullish_structure_break_active,bearish_structure_break_active;
   double broken_swing_price,breakout_close,breakout_atr,breakout_distance_atr;
   int range_containment_lookback;
   double range_high,range_low,range_width,normalized_range_width;
   string readiness_reason;
  };

class E2H4RegimeEngine
  {
private:
   E2MarketData *m_market;
   E2Logger *m_logger;
   int m_sensitivity,m_lookback,m_fast,m_slow,m_slope,m_atr_period,m_adx_period;
   double m_adx_min,m_break_atr,m_extension_atr,m_range_adx_max,m_range_max_width_atr;
   int m_range_lookback;
   E2H4RangeVerification m_range_verify;double m_range_width_sum;
   datetime m_last_closed;
   E2H4RegimeResult m_cached;
   bool m_has_cached,m_verbose;

   double Epsilon(const double scale) const { return(MathMax(1e-10,MathAbs(scale)*1e-10)); }
   bool GreaterOrEqual(const double left,const double right) const { return(left>right || MathAbs(left-right)<=Epsilon(right)); }
   bool StrictAbove(const double left,const double right) const { return(left>right+Epsilon(right)); }
   bool StrictBelow(const double left,const double right) const { return(left<right-Epsilon(right)); }
   void ResetSwing(E2H4RegimeSwing &s) const { s.valid=false;s.high=false;s.pivot_time=0;s.known_from_time=0;s.price=0.0; }
   void Reset(E2H4RegimeResult &r,const datetime t) const
     {
      ZeroMemory(r);r.evaluation_time=t;r.regime=E2_REGIME_UNKNOWN;r.active_break_direction=E2_H4_BREAK_NONE;r.readiness_reason="NOT_READY";
      ResetSwing(r.latest_swing_high);ResetSwing(r.previous_swing_high);ResetSwing(r.latest_swing_low);ResetSwing(r.previous_swing_low);
     }
   bool Pivot(const MqlRates &b[],const int index,const bool high) const
     {
      const double value=(high ? b[index].high : b[index].low);
      for(int offset=1;offset<=m_sensitivity;offset++)
        {
         // Equality is deliberately not a pivot: ties are deterministic and
         // cannot produce an arbitrary first/last swing selection.
         if(high ? value<=b[index-offset].high || value<=b[index+offset].high : value>=b[index-offset].low || value>=b[index+offset].low) return(false);
        }
      return(true);
     }
   void AppendSwing(E2H4RegimeSwing &values[],const E2H4RegimeSwing &value) const
     { const int count=ArraySize(values);ArrayResize(values,count+1);values[count]=value; }
   bool ValidBar(const MqlRates &b) const { return(MathIsValidNumber(b.open)&&MathIsValidNumber(b.high)&&MathIsValidNumber(b.low)&&MathIsValidNumber(b.close)&&b.high>=b.low); }
   bool Indicators(const MqlRates &b[],double &ema_fast[],double &ema_slow[],double &atr[],double &adx[]) const
     {
      const int count=ArraySize(b);ArrayResize(ema_fast,count);ArrayResize(ema_slow,count);ArrayResize(atr,count);ArrayResize(adx,count);
      for(int i=0;i<count;i++){ema_fast[i]=0.0;ema_slow[i]=0.0;atr[i]=0.0;adx[i]=0.0;if(!ValidBar(b[i]))return(false);}
      if(count<=m_slow || count<=m_atr_period || count<2*m_adx_period+1)return(false);
      double sum_fast=0.0,sum_slow=0.0;
      for(int i=0;i<m_fast;i++)sum_fast+=b[i].close;
      for(int i=0;i<m_slow;i++)sum_slow+=b[i].close;
      ema_fast[m_fast-1]=sum_fast/m_fast;ema_slow[m_slow-1]=sum_slow/m_slow;
      const double fast_alpha=2.0/(m_fast+1.0),slow_alpha=2.0/(m_slow+1.0);
      for(int i=m_fast;i<count;i++)ema_fast[i]=ema_fast[i-1]+fast_alpha*(b[i].close-ema_fast[i-1]);
      for(int i=m_slow;i<count;i++)ema_slow[i]=ema_slow[i-1]+slow_alpha*(b[i].close-ema_slow[i-1]);
      double smooth_tr=0.0,smooth_plus=0.0,smooth_minus=0.0,adx_sum=0.0,value_adx=0.0;int dx_count=0;
      for(int i=1;i<count;i++)
        {
         const double up=b[i].high-b[i-1].high,down=b[i-1].low-b[i].low;
         const double plus=(up>down && up>0.0 ? up : 0.0),minus=(down>up && down>0.0 ? down : 0.0);
         const double tr=MathMax(b[i].high-b[i].low,MathMax(MathAbs(b[i].high-b[i-1].close),MathAbs(b[i].low-b[i-1].close)));
         if(i<=m_atr_period){smooth_tr+=tr;smooth_plus+=plus;smooth_minus+=minus;if(i==m_atr_period)atr[i]=smooth_tr/m_atr_period;}
         else {smooth_tr=smooth_tr-smooth_tr/m_atr_period+tr;smooth_plus=smooth_plus-smooth_plus/m_atr_period+plus;smooth_minus=smooth_minus-smooth_minus/m_atr_period+minus;atr[i]=smooth_tr/m_atr_period;}
         if(i<m_adx_period)continue;
         const double plus_di=(smooth_tr>0.0 ? 100.0*smooth_plus/smooth_tr : 0.0),minus_di=(smooth_tr>0.0 ? 100.0*smooth_minus/smooth_tr : 0.0),di_sum=plus_di+minus_di;
         const double dx=(di_sum>0.0 ? 100.0*MathAbs(plus_di-minus_di)/di_sum : 0.0);dx_count++;
         if(dx_count<=m_adx_period){adx_sum+=dx;if(dx_count==m_adx_period)value_adx=adx_sum/m_adx_period;}
         else value_adx=(value_adx*(m_adx_period-1)+dx)/m_adx_period;
         if(dx_count>=m_adx_period)adx[i]=value_adx;
        }
      return(true);
     }
   bool TrendInvalidated(const MqlRates &b[],const datetime after,const double level,const bool bullish) const
     {
      const int seconds=PeriodSeconds(m_market.TrendTimeframe());
      for(int i=0;i<ArraySize(b);i++)if(b[i].time+seconds>after && (bullish ? StrictBelow(b[i].close,level) : StrictAbove(b[i].close,level)))return(true);
      return(false);
     }
   void LogChange(const E2H4RegimeResult &r) const
     {
      if(m_logger==NULL || !m_logger.IsDebugEnabled() || !m_verbose)return;
      m_logger.Debug("time="+TimeToString(r.closed_h4_time,TIME_DATE|TIME_MINUTES)+", regime="+E2RegimeTypeName(r.regime)+", eligible="+(r.trend_entry_eligible?"yes":"no")+", overextended="+(r.trend_overextended?"yes":"no")+", HH="+(r.latest_swing_high.valid?DoubleToString(r.latest_swing_high.price,8):"NA")+", HL="+(r.latest_swing_low.valid?DoubleToString(r.latest_swing_low.price,8):"NA")+", EMA20="+DoubleToString(r.ema20,8)+", EMA50="+DoubleToString(r.ema50,8)+", EMA50Slope5="+DoubleToString(r.ema50-r.ema50_five_bars_ago,8)+", ADX="+DoubleToString(r.adx,2)+", ATR="+DoubleToString(r.atr,8)+", extensionATR="+DoubleToString(r.distance_close_to_ema20_atr,3)+", bullBreak="+(r.bullish_structure_break_active?"yes":"no")+", rangeWidthATR="+(r.range_measurements_valid?DoubleToString(r.normalized_range_width,3):"NA")+".","H4RegimeV2");
     }
   bool Changed(const E2H4RegimeResult &a,const E2H4RegimeResult &b) const
     { return(!a.ready || a.regime!=b.regime || a.trend_entry_eligible!=b.trend_entry_eligible || a.trend_overextended!=b.trend_overextended || a.active_break_direction!=b.active_break_direction || a.range_valid!=b.range_valid || a.normalized_range_width!=b.normalized_range_width); }
public:
   E2H4RegimeEngine(void):m_market(NULL),m_logger(NULL),m_sensitivity(3),m_lookback(300),m_fast(20),m_slow(50),m_slope(5),m_atr_period(14),m_adx_period(14),m_adx_min(20.0),m_break_atr(0.10),m_extension_atr(1.50),m_range_adx_max(20.0),m_range_max_width_atr(6.0),m_range_lookback(20),m_range_width_sum(0.0),m_last_closed(0),m_has_cached(false){}
   void Initialize(const E2Config &c,E2MarketData &market,E2Logger &logger)
     {m_market=&market;m_logger=&logger;m_verbose=c.research_verbose_diagnostics;m_sensitivity=c.swing_sensitivity;m_lookback=MathMax(c.trend_structure_lookback_bars,300);m_fast=c.research_h4_ema_fast_period;m_slow=c.research_h4_ema_slow_period;m_slope=c.research_h4_ema_slope_lookback;m_atr_period=c.research_h4_atr_period;m_adx_period=c.adx_period;m_adx_min=c.adx_minimum_threshold;m_break_atr=c.research_h4_structural_breakout_distance_atr;m_extension_atr=c.research_h4_trend_extension_limit_atr;m_range_adx_max=c.h4_range_adx_maximum;m_range_lookback=c.h4_range_containment_lookback;m_range_max_width_atr=c.h4_range_maximum_width_atr;m_last_closed=0;m_has_cached=false;m_range_width_sum=0.0;ZeroMemory(m_range_verify);}
   bool Evaluate(const string symbol,const datetime evaluation_time,E2H4RegimeResult &result)
     {
      Reset(result,evaluation_time);if(m_market==NULL)return(false);MqlRates latest;
      if(!m_market.GetClosedBarAsOf(symbol,m_market.TrendTimeframe(),evaluation_time,latest)){result.readiness_reason="CLOSED_H4_UNAVAILABLE";m_range_verify.insufficient_data++;return(false);}
      if(m_has_cached && latest.time==m_last_closed){result=m_cached;result.evaluation_time=evaluation_time;return(result.ready);}
      MqlRates b[];if(!m_market.GetClosedBarsAsOf(symbol,m_market.TrendTimeframe(),evaluation_time,m_lookback,b)){result.readiness_reason="INSUFFICIENT_H4_HISTORY";m_range_verify.insufficient_data++;return(false);}
      double fast[],slow[],atr[],adx[];if(!Indicators(b,fast,slow,atr,adx)){result.readiness_reason="INDICATOR_HISTORY_UNAVAILABLE";m_range_verify.insufficient_data++;return(false);}
      const int count=ArraySize(b),seconds=PeriodSeconds(m_market.TrendTimeframe());E2H4RegimeSwing highs[],lows[];E2H4RegimeSwing last_bull,last_bear;ResetSwing(last_bull);ResetSwing(last_bear);
      int last_bull_break_index=-1,last_bear_break_index=-1;
      for(int i=0;i<count;i++)
        {
         const datetime available=b[i].time+seconds;
         if(i>=m_sensitivity && i<count-m_sensitivity && atr[i]>0.0)
           {
            const int p=i-m_sensitivity;E2H4RegimeSwing s;s.valid=true;s.pivot_time=b[p].time;s.known_from_time=available;
            if(Pivot(b,p,true)){s.high=true;s.price=b[p].high;AppendSwing(highs,s);}
            if(Pivot(b,p,false)){s.high=false;s.price=b[p].low;AppendSwing(lows,s);}
           }
         // A break may use only swings confirmed before this candle closed.
         if(i>0 && atr[i]>0.0 && ArraySize(highs)>0){E2H4RegimeSwing h=highs[ArraySize(highs)-1];if(h.known_from_time<available && (!last_bull.valid || last_bull.pivot_time!=h.pivot_time) && GreaterOrEqual(b[i].close,h.price+m_break_atr*atr[i])){last_bull=h;last_bull.known_from_time=available;last_bull_break_index=i;}}
         if(i>0 && atr[i]>0.0 && ArraySize(lows)>0){E2H4RegimeSwing l=lows[ArraySize(lows)-1];if(l.known_from_time<available && (!last_bear.valid || last_bear.pivot_time!=l.pivot_time) && GreaterOrEqual(b[i].close,l.price-m_break_atr*atr[i])){last_bear=l;last_bear.known_from_time=available;last_bear_break_index=i;}}
        }
      const int last=count-1;result.ready=true;result.closed_h4_time=b[last].time;result.known_from_time=b[last].time+seconds;result.latest_close=b[last].close;result.ema20=fast[last];result.ema50=slow[last];result.ema50_five_bars_ago=slow[last-m_slope];result.adx=adx[last];result.atr=atr[last];result.distance_close_to_ema20=MathAbs(result.latest_close-result.ema20);result.distance_close_to_ema20_atr=(result.atr>0.0?result.distance_close_to_ema20/result.atr:0.0);
      if(ArraySize(highs)>=2){result.previous_swing_high=highs[ArraySize(highs)-2];result.latest_swing_high=highs[ArraySize(highs)-1];}if(ArraySize(lows)>=2){result.previous_swing_low=lows[ArraySize(lows)-2];result.latest_swing_low=lows[ArraySize(lows)-1];}
      const bool hh=result.latest_swing_high.valid && StrictAbove(result.latest_swing_high.price,result.previous_swing_high.price),hl=result.latest_swing_low.valid && StrictAbove(result.latest_swing_low.price,result.previous_swing_low.price),lh=result.latest_swing_high.valid && StrictBelow(result.latest_swing_high.price,result.previous_swing_high.price),ll=result.latest_swing_low.valid && StrictBelow(result.latest_swing_low.price,result.previous_swing_low.price);
      const bool bull_break=last_bull.valid && !TrendInvalidated(b,last_bull.known_from_time,result.latest_swing_low.price,true),bear_break=last_bear.valid && !TrendInvalidated(b,last_bear.known_from_time,result.latest_swing_high.price,false);
      const bool bull=hh&&hl&&bull_break&&StrictAbove(result.ema20,result.ema50)&&StrictAbove(result.ema50,result.ema50_five_bars_ago)&&GreaterOrEqual(result.adx,m_adx_min);
      const bool bear=lh&&ll&&bear_break&&StrictBelow(result.ema20,result.ema50)&&StrictBelow(result.ema50,result.ema50_five_bars_ago)&&GreaterOrEqual(result.adx,m_adx_min);
      result.bullish_structure_break_active=bull_break;result.bearish_structure_break_active=bear_break;
      if(bull){result.regime=E2_REGIME_UPTREND;result.active_break_direction=E2_H4_BREAK_BULLISH;result.breakout_time=last_bull.known_from_time;result.broken_swing_price=last_bull.price;}
      else if(bear){result.regime=E2_REGIME_DOWNTREND;result.active_break_direction=E2_H4_BREAK_BEARISH;result.breakout_time=last_bear.known_from_time;result.broken_swing_price=last_bear.price;}
      else
        {
         const bool enough=(count>=m_range_lookback && result.atr>0.0);
         if(!enough)m_range_verify.insufficient_data++;
         else
           {
            result.range_measurements_valid=true;result.range_containment_lookback=m_range_lookback;result.range_high=b[last].high;result.range_low=b[last].low;
            for(int i=last-m_range_lookback+1;i<=last;i++){if(b[i].high>result.range_high)result.range_high=b[i].high;if(b[i].low<result.range_low)result.range_low=b[i].low;}
            result.range_width=result.range_high-result.range_low;result.normalized_range_width=result.range_width/result.atr;m_range_verify.range_containment_checks++;m_range_width_sum+=result.normalized_range_width;
            if(m_range_verify.range_containment_checks==1){m_range_verify.minimum_range_width_atr=result.normalized_range_width;m_range_verify.maximum_range_width_atr=result.normalized_range_width;}else{m_range_verify.minimum_range_width_atr=MathMin(m_range_verify.minimum_range_width_atr,result.normalized_range_width);m_range_verify.maximum_range_width_atr=MathMax(m_range_verify.maximum_range_width_atr,result.normalized_range_width);}
            const bool adx_pass=result.adx<=m_range_adx_max+Epsilon(m_range_adx_max);if(adx_pass)m_range_verify.range_adx_pass++;const bool width_pass=result.normalized_range_width<=m_range_max_width_atr+Epsilon(m_range_max_width_atr);if(width_pass)m_range_verify.range_width_pass++;
            result.range_valid=adx_pass&&width_pass;
           }
         result.regime=(result.range_valid?E2_REGIME_RANGE:E2_REGIME_TRANSITION_UNCLASSIFIED);
        }
      const int break_index=(result.active_break_direction==E2_H4_BREAK_BULLISH ? last_bull_break_index : last_bear_break_index);if(break_index>=0){result.breakout_close=b[break_index].close;result.breakout_atr=atr[break_index];result.breakout_distance_atr=(result.breakout_atr>0.0?MathAbs(result.breakout_close-result.broken_swing_price)/result.breakout_atr:0.0);}
      if(result.regime==E2_REGIME_UPTREND || result.regime==E2_REGIME_DOWNTREND){result.trend_overextended=StrictAbove(result.distance_close_to_ema20_atr,m_extension_atr);result.trend_entry_eligible=!result.trend_overextended;}
      m_range_verify.h4_contexts++;if(result.regime==E2_REGIME_UPTREND)m_range_verify.uptrend_contexts++;else if(result.regime==E2_REGIME_DOWNTREND)m_range_verify.downtrend_contexts++;else if(result.regime==E2_REGIME_RANGE){m_range_verify.range_contexts++;m_range_verify.range_classifications++;}else m_range_verify.neutral_contexts++;if(result.known_from_time>evaluation_time)m_range_verify.causality_violations++;
      result.readiness_reason="READY";if(!m_has_cached || Changed(result,m_cached))LogChange(result);m_cached=result;m_last_closed=latest.time;m_has_cached=true;return(true);
     }
   E2H4RangeVerification RangeVerification(void) const { E2H4RangeVerification value=m_range_verify;if(value.range_containment_checks>0)value.average_range_width_atr=m_range_width_sum/value.range_containment_checks;return(value); }
  };

#endif // E2_ANALYSIS_E2H4REGIMEENGINE_MQH
