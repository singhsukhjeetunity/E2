#ifndef E2_STRATEGY_E2OBRTYPES_MQH
#define E2_STRATEGY_E2OBRTYPES_MQH
#include "..\\core\\E2TradeTypes.mqh"

struct E2OBROpeningRange
  {
   bool complete,frozen; string symbol,london_day; datetime start_time,end_time,known_from;
   double high,low; int bars_collected;
  };

struct E2OBRCandidate
  {
   string candidate_id,symbol,london_day; E2TradeDirection direction;
   double or_high,or_low,breakout_close,atr,adx,or_size,or_size_atr_ratio,breakout_distance,breakout_distance_atr_ratio;
   datetime or_start,or_end,or_known_from,breakout_candle_time,breakout_known_from,candidate_known_from;
  };

struct E2OBRVerification
  {
   long london_days_observed,opening_ranges_complete,opening_ranges_incomplete,breakout_eligible_candles,long_close_breakouts,short_close_breakouts,adx_pass,range_size_pass,long_gap_pass,short_gap_pass,long_candidates,short_candidates,total_candidates,duplicate_candidates,causality_violations;
  };

struct E2OBRTimeVerification
  {
   long gmt_days,bst_days,dst_transition_observations,or_reconstruction_successes,or_reconstruction_failures,or_mutation_violations,invalid_or_bars,day_reset_violations;
  };
#endif
