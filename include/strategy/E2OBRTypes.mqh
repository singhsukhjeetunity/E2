#ifndef E2_STRATEGY_E2OBRTYPES_MQH
#define E2_STRATEGY_E2OBRTYPES_MQH
#include "..\\core\\E2TradeTypes.mqh"

struct E2OBROpeningRange
  {
   bool complete,frozen; string symbol,london_day,session; datetime start_time,end_time,known_from;
   double high,low; int bars_collected;
  };

struct E2OBRCandidate
  {
   string candidate_id,symbol,london_day,session; E2TradeDirection direction;
   double or_high,or_low,breakout_close,atr,adx,or_size,or_size_atr_ratio,breakout_distance,breakout_distance_atr_ratio;
   datetime or_start,or_end,or_known_from,breakout_candle_time,breakout_known_from,candidate_known_from;
  };

struct E2OBRVerification
  {
   long london_days_observed,opening_ranges_complete,opening_ranges_incomplete,breakout_eligible_candles,long_close_breakouts,short_close_breakouts,adx_pass,range_size_pass,long_gap_pass,short_gap_pass,long_candidates,short_candidates,total_candidates,duplicate_candidates,causality_violations;
  };
struct E2OBRWeekdayVerification
  {bool monday_enabled,tuesday_enabled,wednesday_enabled,thursday_enabled,friday_enabled;long otherwise_valid_signals_checked,monday_otherwise_valid,tuesday_otherwise_valid,wednesday_otherwise_valid,thursday_otherwise_valid,friday_otherwise_valid,monday_suppressed,tuesday_suppressed,wednesday_suppressed,thursday_suppressed,friday_suppressed,total_disabled_weekday_suppressed,enabled_weekday_candidates,disabled_weekday_candidates_created,weekday_mapping_violations;};
struct E2OBRSuppressedSignal
  {string symbol,london_day,london_weekday,session;E2TradeDirection direction;datetime breakout_time;double or_high,or_low,breakout_close,atr,adx,or_atr,gap_atr;};

struct E2OBRTimeVerification
  {
   long gmt_days,bst_days,dst_transition_observations,or_reconstruction_successes,or_reconstruction_failures,or_mutation_violations,invalid_or_bars,day_reset_violations;
  };
struct E2OBRSessionVerification
  {string selected_session;long session_days_observed,opening_ranges_complete,opening_ranges_incomplete,session_time_conversion_violations,session_day_mapping_violations,session_weekday_mapping_violations,or_bar_count_violations,or_start_violations,or_end_violations,or_mutation_violations,dst_transition_observations,dst_transition_violations;};

struct E2OBRPlanContext
  {
   E2OBRCandidate candidate; datetime intended_entry_time,request_time; double quote_price,structural_stop,submitted_stop,requested_risk_cash,planned_risk_cash,volume;
  };

struct E2OBRPlanVerification
  {
   long candidates_received,entry_windows_reached,expired_candidates,rejected_day_consumed,rejected_entry_gap,rejected_stop_geometry,rejected_position_open,rejected_spread,rejected_quote,rejected_sizing,rejected_margin,rejected_other,valid_execution_requests,long_requests,short_requests,duplicate_requests,plan_causality_violations;
  };

struct E2OBRExecutionVerification
  {
   long requests_received,execution_attempts,execution_successes,execution_failures,long_attempts,short_attempts,successful_entries,day_locks_created,duplicate_execution_attempts,unresolved_execution_states,registration_failures,protection_failures;
  };

struct E2OBRRecoveryVerification
  {
   long initializations,or_recovery_successes,or_recovery_failures,day_lock_recoveries,open_position_recoveries,metadata_recovery_failures,duplicate_day_entry_violations,original_r_recovery_violations;
  };

struct E2OBRPositionMetadata
  {
   bool valid; ulong position_id,order_ticket,entry_deal; string candidate_id,execution_id,london_day,symbol; E2TradeDirection direction;
   datetime breakout_time,entry_time; double or_high,or_low,frozen_atr,frozen_adx,fill_price,structural_stop,submitted_stop,original_r_price,target_price,requested_risk_cash,actual_risk_cash,volume;
  };

struct E2OBRReconcileVerification { string trade_csv_status; long candidate_count,plan_candidate_count,valid_request_count,execution_attempt_count,successful_entry_count,registered_position_count,finalized_trade_count,trade_csv_rows,trade_csv_row_mismatch,unique_trade_ids,unique_candidate_ids_for_trades,day_locks_created,unique_successful_symbol_days,duplicate_trade_ids,duplicate_successful_symbol_days,orphan_executions,orphan_registrations,orphan_finalizations,missing_candidate_links,missing_execution_links,trade_count_mismatch; };
struct E2OBRFinancialVerification { double gross_profit,commission,swap,fees,net_profit,net_r,win_rate,average_r,average_win_r,average_loss_r,profit_factor_r,maximum_drawdown_r,profit_difference,r_difference; long wins,losses,breakevens,trade_count_difference; };
struct E2OBRRVerification { long trades_checked,invalid_original_r,original_r_mismatches,tp_geometry_mismatches,non_positive_original_r,original_r_mutation_violations; double maximum_tp_difference_ticks; };
struct E2OBRDayVerification { long successful_entries,unique_successful_days,max_entries_per_symbol_london_day,duplicate_successful_days,day_locks_created,day_lock_mismatch; };
struct E2OBREntryTimeVerification { long candidates_checked,missed_window_candidates,attempts_checked,correct_next_bar_attempts,same_bar_violations,actual_late_execution_violations,early_entry_violations,missing_candidate_timestamp,entry_time_violations; };
struct E2OBREntryGapVerification { long accepted_checked,rejected_checked,false_accepts,false_rejects,atr_mutation_violations,gap_decision_violations; };
#endif
