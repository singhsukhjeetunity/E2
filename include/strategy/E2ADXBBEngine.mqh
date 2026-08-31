#ifndef E2_STRATEGY_E2ADXBBENGINE_MQH
#define E2_STRATEGY_E2ADXBBENGINE_MQH

#include "E2ADXBBTypes.mqh"
#include "..\\core\\E2Config.mqh"
#include "..\\analysis\\E2MarketData.mqh"
#include "..\\reporting\\E2CsvExporter.mqh"
#include "..\\research\\E2ADXBBRegimeResearch.mqh"
#include "..\\execution\\E2WeekendFlat.mqh"

struct E2ADXRmaState
  {
   int count;
   double seed_sum,value;
   bool valid;
  };

class E2ADXBBEngine
  {
private:
   E2Config m_config;
   E2MarketData *m_market;
   E2Logger *m_logger;
   string m_symbol,m_candidate_ids[];
   datetime m_last_processed_bar,m_pending_setup_time;
   E2TradeDirection m_pending_setup_direction;
   E2ADXBBHybridDecision m_pending_hybrid_decision;
   bool m_have_previous;
   double m_previous_high,m_previous_low,m_previous_close,m_bb_buffer_price,m_closes[];
   E2ADXRmaState m_tr_di,m_plus_dm,m_minus_dm,m_dx,m_atr;
   E2ADXBBSignalVerification m_signal_verify;
   E2ADXBBIndicatorVerification m_indicator_verify;
   E2CsvExporter m_validation_csv;
   E2ADXBBRegimeResearch m_regime_research;
   E2WeekendFlat *m_weekend;

   void ResetRma(E2ADXRmaState &state){state.count=0;state.seed_sum=0.0;state.value=0.0;state.valid=false;}
   bool UpdateRma(E2ADXRmaState &state,const double sample,const int length)
     {
      if(!MathIsValidNumber(sample)||length<1)return(false);
      if(!state.valid)
        {
         state.seed_sum+=sample;state.count++;
         if(state.count<length)return(false);
         if(state.count>length){m_indicator_verify.rma_initialization_violations++;return(false);}
         state.value=state.seed_sum/length;state.valid=MathIsValidNumber(state.value);return(state.valid);
        }
      state.value=(state.value*(length-1)+sample)/length;
      return(MathIsValidNumber(state.value));
     }
   void AddClose(const double close)
     {
      int count=ArraySize(m_closes);
      if(count<m_config.adxbb_bb_length){ArrayResize(m_closes,count+1);m_closes[count]=close;return;}
      for(int i=1;i<count;i++)m_closes[i-1]=m_closes[i];m_closes[count-1]=close;
     }
   bool Bollinger(double &basis,double &upper,double &lower)
     {
      basis=0.0;upper=0.0;lower=0.0;const int count=ArraySize(m_closes);if(count<m_config.adxbb_bb_length)return(false);
      for(int i=0;i<count;i++)basis+=m_closes[i];basis/=count;double variance=0.0;for(int i=0;i<count;i++){double delta=m_closes[i]-basis;variance+=delta*delta;}variance/=count;if(!MathIsValidNumber(variance))return(false);variance=MathMax(0.0,variance);double deviation=m_config.adxbb_bb_stddev*MathSqrt(variance);upper=basis+deviation;lower=basis-deviation;return(MathIsValidNumber(basis)&&MathIsValidNumber(upper)&&MathIsValidNumber(lower));
     }
   bool Seen(const string id)const{for(int i=0;i<ArraySize(m_candidate_ids);i++)if(m_candidate_ids[i]==id)return(true);return(false);}
   void Remember(const string id){int count=ArraySize(m_candidate_ids);ArrayResize(m_candidate_ids,count+1);m_candidate_ids[count]=id;}
   void Append(E2ADXBBCandidate &values[],const E2ADXBBCandidate &candidate)const{int count=ArraySize(values);ArrayResize(values,count+1);values[count]=candidate;}
   string Number(const double value,const int digits=10)const{return(DoubleToString(value,digits));}
   string BoolText(const bool value)const{return(value?"1":"0");}
   void ExportRow(const MqlRates &bar,const double di_plus,const double di_minus,const double adx,const double basis,const double upper,const double lower,const double atr,const bool di_valid,const bool adx_valid,const bool bb_valid,const bool atr_valid,const bool ranging,const bool long_signal,const bool short_signal)
     {
      if(!m_validation_csv.IsInitialized())return;string row[]={TimeToString(bar.time,TIME_DATE|TIME_MINUTES),Number(bar.open),Number(bar.high),Number(bar.low),Number(bar.close),(di_valid?Number(di_plus):""),(di_valid?Number(di_minus):""),(adx_valid?Number(adx):""),(bb_valid?Number(basis):""),(bb_valid?Number(upper):""),(bb_valid?Number(lower):""),(atr_valid?Number(atr):""),BoolText(di_valid),BoolText(adx_valid),BoolText(bb_valid),BoolText(atr_valid),BoolText(ranging),BoolText(long_signal),BoolText(short_signal)};m_validation_csv.WriteRow(row);
     }
   void DebugDecision(const MqlRates &bar,const string result,const double lower=0.0,const double upper=0.0)const{if(m_logger!=NULL&&m_config.debug_mode)m_logger.Debug("bar="+TimeToString(bar.time,TIME_DATE|TIME_MINUTES)+", result="+result+", bbBufferPips="+Number(m_config.adxbb_bb_buffer_pips)+", bbBufferPrice="+Number(m_bb_buffer_price)+", effectiveLongThreshold="+Number(lower-m_bb_buffer_price)+", effectiveShortThreshold="+Number(upper+m_bb_buffer_price)+".","ADXBB_SIGNAL");}
   void DebugReentry(const string component,const E2TradeDirection direction,const string result,const MqlRates &bar,const double adx,const double lower,const double upper)const{if(m_logger==NULL||!m_config.debug_mode)return;string boundary=(direction==E2_DIRECTION_LONG?"bbLower="+Number(lower):"bbUpper="+Number(upper));string threshold=(direction==E2_DIRECTION_LONG?"effectiveLongThreshold="+Number(lower-m_bb_buffer_price):"effectiveShortThreshold="+Number(upper+m_bb_buffer_price));m_logger.Debug("direction="+E2TradeDirectionName(direction)+", result="+result+", close="+Number(bar.close)+", "+boundary+", "+threshold+", adx="+Number(adx)+".",component);}
   void DebugDirection(const E2TradeDirection signal_direction,const E2TradeDirection execution_direction)const{if(m_logger!=NULL&&m_config.debug_mode)m_logger.Debug("signalDirection="+E2TradeDirectionName(signal_direction)+", executionDirection="+E2TradeDirectionName(execution_direction)+", hybridEnabled="+IntegerToString((int)m_config.adxbb_hybrid_regime_enabled)+", legacyInvertApplied="+IntegerToString((int)(!m_config.adxbb_hybrid_regime_enabled&&m_config.adxbb_invert_trade_direction))+".","ADXBB_DIRECTION");}
   void ProcessBar(const MqlRates &bar,E2ADXBBCandidate &candidates[])
     {
      m_signal_verify.bars_observed++;m_indicator_verify.bars_checked++;
      if(bar.time<=0||!MathIsValidNumber(bar.open)||!MathIsValidNumber(bar.high)||!MathIsValidNumber(bar.low)||!MathIsValidNumber(bar.close)||bar.high<bar.low||bar.close<=0.0){m_signal_verify.invalid_indicator_bars++;return;}
      if(m_last_processed_bar>0&&bar.time<=m_last_processed_bar)m_indicator_verify.indicator_timestamp_violations++;
      double true_range=bar.high-bar.low,plus=0.0,minus=0.0;
      if(m_have_previous)
        {
         true_range=MathMax(true_range,MathMax(MathAbs(bar.high-m_previous_close),MathAbs(bar.low-m_previous_close)));
         double up_move=bar.high-m_previous_high,down_move=m_previous_low-bar.low;
         if(up_move>down_move&&up_move>0.0)plus=up_move;else if(down_move>up_move&&down_move>0.0)minus=down_move;
        }
      m_previous_high=bar.high;m_previous_low=bar.low;m_previous_close=bar.close;m_have_previous=true;AddClose(bar.close);
      const bool tr_di_valid=UpdateRma(m_tr_di,true_range,m_config.adxbb_di_length),plus_valid=UpdateRma(m_plus_dm,plus,m_config.adxbb_di_length),minus_valid=UpdateRma(m_minus_dm,minus,m_config.adxbb_di_length);
      double di_plus=0.0,di_minus=0.0,adx=0.0;
      bool adx_valid=false;
      if(tr_di_valid&&plus_valid&&minus_valid&&m_tr_di.value>0.0)
        {
         di_plus=100.0*m_plus_dm.value/m_tr_di.value;di_minus=100.0*m_minus_dm.value/m_tr_di.value;double denominator=di_plus+di_minus;double dx=(denominator>0.0?100.0*MathAbs(di_plus-di_minus)/denominator:0.0);adx_valid=UpdateRma(m_dx,dx,m_config.adxbb_adx_length);if(adx_valid)adx=m_dx.value;
        }
      const bool atr_valid=UpdateRma(m_atr,true_range,m_config.adxbb_atr_length);double atr=(atr_valid?m_atr.value:0.0);double basis=0.0,upper=0.0,lower=0.0;const bool bb_valid=Bollinger(basis,upper,lower);
      if(adx_valid){m_indicator_verify.adx_valid_bars++;if(m_indicator_verify.adx_valid_bars==1){m_indicator_verify.adx_min=adx;m_indicator_verify.adx_max=adx;}else{m_indicator_verify.adx_min=MathMin(m_indicator_verify.adx_min,adx);m_indicator_verify.adx_max=MathMax(m_indicator_verify.adx_max,adx);}}
      if(bb_valid)m_indicator_verify.bb_valid_bars++;
      if(atr_valid){m_indicator_verify.atr_valid_bars++;if(m_indicator_verify.atr_valid_bars==1){m_indicator_verify.atr_min=atr;m_indicator_verify.atr_max=atr;}else{m_indicator_verify.atr_min=MathMin(m_indicator_verify.atr_min,atr);m_indicator_verify.atr_max=MathMax(m_indicator_verify.atr_max,atr);}}
      const double effective_long_threshold=lower-m_bb_buffer_price,effective_short_threshold=upper+m_bb_buffer_price;const bool di_valid=(tr_di_valid&&plus_valid&&minus_valid&&m_tr_di.value>0.0);const bool all_valid=(adx_valid&&bb_valid&&atr_valid);const bool ranging=(all_valid&&adx<m_config.adxbb_adx_threshold);const bool long_setup=(all_valid&&ranging&&bar.close<effective_long_threshold),short_setup=(all_valid&&ranging&&bar.close>effective_short_threshold);bool long_signal=long_setup,short_signal=short_setup;
      const E2TradeDirection raw_event_direction=(long_setup?E2_DIRECTION_LONG:(short_setup?E2_DIRECTION_SHORT:E2_DIRECTION_NONE));const E2ADXBBHybridDecision raw_hybrid_decision=m_regime_research.Observe(bar,(adx_valid?adx:EMPTY_VALUE),(di_valid?di_plus:EMPTY_VALUE),(di_valid?di_minus:EMPTY_VALUE),(bb_valid?upper:EMPTY_VALUE),(bb_valid?basis:EMPTY_VALUE),(bb_valid?lower:EMPTY_VALUE),(atr_valid?atr:EMPTY_VALUE),raw_event_direction);E2ADXBBHybridDecision signal_hybrid_decision=raw_hybrid_decision;
      if(m_config.adxbb_require_bb_reentry_confirmation){long_signal=false;short_signal=false;signal_hybrid_decision=E2_HYBRID_SKIP;if(m_pending_setup_direction!=E2_DIRECTION_NONE){const bool immediate=(bar.time==m_pending_setup_time+PeriodSeconds(PERIOD_M5));const bool confirmed=(immediate&&bb_valid&&atr_valid&&((m_pending_setup_direction==E2_DIRECTION_LONG&&bar.close>=lower)||(m_pending_setup_direction==E2_DIRECTION_SHORT&&bar.close<=upper)));if(confirmed){long_signal=(m_pending_setup_direction==E2_DIRECTION_LONG);short_signal=(m_pending_setup_direction==E2_DIRECTION_SHORT);signal_hybrid_decision=m_pending_hybrid_decision;DebugReentry("ADXBB_REENTRY_CONFIRM",m_pending_setup_direction,"CONFIRMED",bar,adx,lower,upper);}else DebugReentry("ADXBB_REENTRY_CONFIRM",m_pending_setup_direction,"EXPIRED",bar,adx,lower,upper);}m_pending_setup_direction=(long_setup?E2_DIRECTION_LONG:(short_setup?E2_DIRECTION_SHORT:E2_DIRECTION_NONE));m_pending_setup_time=(m_pending_setup_direction==E2_DIRECTION_NONE?0:bar.time);m_pending_hybrid_decision=(m_pending_setup_direction==E2_DIRECTION_NONE?E2_HYBRID_SKIP:raw_hybrid_decision);if(m_pending_setup_direction!=E2_DIRECTION_NONE)DebugReentry("ADXBB_REENTRY_SETUP",m_pending_setup_direction,"PENDING",bar,adx,lower,upper);}
      const datetime known=bar.time+PeriodSeconds(PERIOD_M5);if(m_weekend!=NULL&&m_weekend.IsBlockedAt(known)){if(m_pending_setup_direction!=E2_DIRECTION_NONE||raw_event_direction!=E2_DIRECTION_NONE)m_weekend.LogExpire("ADXBB|"+m_symbol+"|M5|"+IntegerToString((int)bar.time),known);m_pending_setup_direction=E2_DIRECTION_NONE;m_pending_setup_time=0;m_pending_hybrid_decision=E2_HYBRID_SKIP;long_signal=false;short_signal=false;}
      ExportRow(bar,di_plus,di_minus,adx,basis,upper,lower,atr,di_valid,adx_valid,bb_valid,atr_valid,ranging,long_signal,short_signal);
      if(!adx_valid||!bb_valid||!atr_valid){m_signal_verify.indicator_warmup_bars++;DebugDecision(bar,"INDICATOR_WARMUP",lower,upper);return;}
      m_signal_verify.completed_bars_processed++;
      if(!MathIsValidNumber(adx)||!MathIsValidNumber(di_plus)||!MathIsValidNumber(di_minus)||!MathIsValidNumber(basis)||!MathIsValidNumber(upper)||!MathIsValidNumber(lower)||!MathIsValidNumber(atr)){m_signal_verify.invalid_indicator_bars++;DebugDecision(bar,"INVALID_INDICATOR",lower,upper);return;}
      if(!(lower<=basis&&basis<=upper)){m_signal_verify.invalid_band_geometry++;m_indicator_verify.bb_geometry_violations++;DebugDecision(bar,"INVALID_BAND_GEOMETRY",lower,upper);return;}
      const double risk_distance=atr*m_config.adxbb_atr_multiplier;if(!MathIsValidNumber(risk_distance)||risk_distance<=0.0){m_signal_verify.invalid_atr_bars++;DebugDecision(bar,"INVALID_ATR",lower,upper);return;}
      if(ranging)m_signal_verify.ranging_bars++;else m_signal_verify.trending_bars++;
      const bool below=(bar.close<effective_long_threshold),above=(bar.close>effective_short_threshold);if(below)m_signal_verify.close_below_lower_band++;if(above)m_signal_verify.close_above_upper_band++;
      if(!m_config.adxbb_require_bb_reentry_confirmation){if(!ranging){DebugDecision(bar,"ADX_NOT_RANGING",lower,upper);return;}if(!below&&!above){DebugDecision(bar,"CLOSE_INSIDE_BANDS",lower,upper);return;}}
      else if(!long_signal&&!short_signal)return;
      if(long_signal&&short_signal){m_signal_verify.invalid_band_geometry++;m_indicator_verify.bb_geometry_violations++;DebugDecision(bar,"AMBIGUOUS_DIRECTION",lower,upper);return;}
      const E2TradeDirection signal_direction=(long_signal?E2_DIRECTION_LONG:(short_signal?E2_DIRECTION_SHORT:E2_DIRECTION_NONE));if(signal_direction==E2_DIRECTION_NONE)return;E2TradeDirection direction;if(m_config.adxbb_hybrid_regime_enabled){if(signal_hybrid_decision==E2_HYBRID_SKIP){DebugDecision(bar,"HYBRID_Q50_SKIP",lower,upper);return;}direction=(signal_hybrid_decision==E2_HYBRID_FADE?signal_direction:(signal_direction==E2_DIRECTION_LONG?E2_DIRECTION_SHORT:E2_DIRECTION_LONG));}else direction=(!m_config.adxbb_invert_trade_direction?signal_direction:(signal_direction==E2_DIRECTION_LONG?E2_DIRECTION_SHORT:E2_DIRECTION_LONG));DebugDirection(signal_direction,direction);
      if(known<=bar.time){m_signal_verify.causality_violations++;return;}
      E2ADXBBCandidate candidate;ZeroMemory(candidate);candidate.symbol=m_symbol;candidate.timeframe="M5";candidate.signal_bar_time=bar.time;candidate.signal_known_time=known;candidate.direction=direction;candidate.signal_close=bar.close;candidate.adx=adx;candidate.di_plus=di_plus;candidate.di_minus=di_minus;candidate.bb_basis=basis;candidate.bb_upper=upper;candidate.bb_lower=lower;candidate.atr=atr;candidate.atr_multiplier=m_config.adxbb_atr_multiplier;candidate.risk_distance=risk_distance;candidate.execution_window_start=known;candidate.execution_window_end=known+PeriodSeconds(PERIOD_M5);candidate.candidate_id="ADXBB|"+m_symbol+"|M5|"+IntegerToString((int)bar.time)+"|"+E2TradeDirectionName(signal_direction);
      if(Seen(candidate.candidate_id)){m_signal_verify.duplicate_candidates++;DebugDecision(bar,"DUPLICATE_CANDIDATE",lower,upper);return;}Remember(candidate.candidate_id);Append(candidates,candidate);m_signal_verify.total_candidates++;if(direction==E2_DIRECTION_LONG){m_signal_verify.long_candidates++;DebugDecision(bar,"LONG_SIGNAL",lower,upper);}else{m_signal_verify.short_candidates++;DebugDecision(bar,"SHORT_SIGNAL",lower,upper);}
     }
public:
   E2ADXBBEngine(void):m_market(NULL),m_logger(NULL),m_symbol(""),m_last_processed_bar(0),m_pending_setup_time(0),m_pending_setup_direction(E2_DIRECTION_NONE),m_pending_hybrid_decision(E2_HYBRID_SKIP),m_have_previous(false),m_previous_high(0.0),m_previous_low(0.0),m_previous_close(0.0),m_bb_buffer_price(0.0),m_weekend(NULL){ZeroMemory(m_signal_verify);ZeroMemory(m_indicator_verify);ResetRma(m_tr_di);ResetRma(m_plus_dm);ResetRma(m_minus_dm);ResetRma(m_dx);ResetRma(m_atr);}
   bool Initialize(const string symbol,const E2Config &config,const double pip_size,const string run_id,const string config_hash,E2MarketData &market,E2WeekendFlat &weekend,E2Logger &logger)
     {
      m_symbol=symbol;m_config=config;m_market=&market;m_weekend=&weekend;m_logger=&logger;m_last_processed_bar=0;m_pending_setup_time=0;m_pending_setup_direction=E2_DIRECTION_NONE;m_pending_hybrid_decision=E2_HYBRID_SKIP;m_have_previous=false;m_bb_buffer_price=config.adxbb_bb_buffer_pips*pip_size;if(pip_size<=0.0||!MathIsValidNumber(m_bb_buffer_price)||m_bb_buffer_price<0.0)return(false);ArrayResize(m_closes,0);ArrayResize(m_candidate_ids,0);ZeroMemory(m_signal_verify);ZeroMemory(m_indicator_verify);ResetRma(m_tr_di);ResetRma(m_plus_dm);ResetRma(m_minus_dm);ResetRma(m_dx);ResetRma(m_atr);
      if(!m_regime_research.Initialize(config,symbol,run_id,config_hash,pip_size,market,logger))return(false);logger.Info("enabled="+IntegerToString((int)config.adxbb_hybrid_regime_enabled)+", methodology=HYBRID_V1_Q50, maturityThresholdATR=0.500000, qualityThresholdPercentile=0.500000, percentileLookback="+IntegerToString(config.adxbb_regime_percentile_lookback)+", directionAuthority="+(config.adxbb_hybrid_regime_enabled?"HYBRID_V1_Q50":"LEGACY")+", legacyInvertApplied="+IntegerToString((int)(!config.adxbb_hybrid_regime_enabled&&config.adxbb_invert_trade_direction))+".","ADXBB_HYBRID_EXECUTION");if(config.csv_export_enabled){string safe=symbol;StringReplace(safe,"/","_");StringReplace(safe,"\\","_");if(!m_validation_csv.Initialize("E2_ADXBB_"+safe+"_M5_INDICATOR_VALIDATION.csv",logger))return(false);string header[]={"timestamp","open","high","low","close","di_plus","di_minus","adx","bb_basis","bb_upper","bb_lower","atr","di_valid","adx_valid","bb_valid","atr_valid","is_ranging","long_signal","short_signal"};if(!m_validation_csv.WriteHeader(header))return(false);}return(true);
     }
   bool Evaluate(E2ADXBBCandidate &new_candidates[])
     {
      ArrayResize(new_candidates,0);if(m_market==NULL)return(false);MqlRates latest;if(!m_market.GetClosedBar(m_symbol,PERIOD_M5,0,latest))return(false);if(latest.time<=m_last_processed_bar)return(true);MqlRates bars[];ArraySetAsSeries(bars,false);int copied=0;if(m_last_processed_bar==0)copied=CopyRates(m_symbol,PERIOD_M5,1,10000,bars);else copied=CopyRates(m_symbol,PERIOD_M5,m_last_processed_bar+1,latest.time,bars);if(copied<=0)return(false);for(int i=0;i<copied;i++){if(bars[i].time<=m_last_processed_bar||bars[i].time>latest.time)continue;ProcessBar(bars[i],new_candidates);m_last_processed_bar=bars[i].time;}return(true);
     }
   E2ADXBBSignalVerification SignalVerification(void)const{return(m_signal_verify);}
   E2ADXBBIndicatorVerification IndicatorVerification(void)const{return(m_indicator_verify);}
   void Shutdown(void){m_regime_research.Shutdown();m_validation_csv.Close();}
  };

#endif
