#ifndef E2_STRATEGY_E2ADXBBTYPES_MQH
#define E2_STRATEGY_E2ADXBBTYPES_MQH

#include "..\\core\\E2TradeTypes.mqh"

struct E2ADXBBCandidate
  {
   string candidate_id,symbol,timeframe;
   datetime signal_bar_time,signal_known_time;
   E2TradeDirection direction;
   double signal_close,adx,di_plus,di_minus,bb_basis,bb_upper,bb_lower,atr,atr_multiplier,risk_distance;
   datetime execution_window_start,execution_window_end;
  };

struct E2ADXBBSignalVerification
  {
   long bars_observed,completed_bars_processed,indicator_warmup_bars,invalid_indicator_bars,ranging_bars,trending_bars,close_below_lower_band,close_above_upper_band,long_candidates,short_candidates,total_candidates,duplicate_candidates,invalid_band_geometry,invalid_atr_bars,causality_violations;
  };

struct E2ADXBBIndicatorVerification
  {
   long bars_checked,adx_valid_bars,bb_valid_bars,atr_valid_bars,bb_geometry_violations,rma_initialization_violations,indicator_timestamp_violations;
   double adx_min,adx_max,atr_min,atr_max;
  };

#endif
