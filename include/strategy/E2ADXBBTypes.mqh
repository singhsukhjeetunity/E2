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

struct E2ADXBBPositionMetadata
  {
   string candidate_id,execution_id,symbol;
   E2TradeDirection direction;
   datetime signal_time,entry_time;
   ulong entry_deal,position_id,position_ticket;
   double volume,fill_price,submitted_stop,original_r,target_r,target_price,requested_risk_cash,actual_risk_cash;
  };

struct E2ADXBBPlanVerification
  {int candidates_received,requests_created,expired_candidates,duplicate_candidates,invalid_candidates,position_rejections,day_rejections,sizing_rejections,quote_rejections;};
struct E2ADXBBExecutionVerification
  {int attempts,successes,failures,duplicate_execution_ids,unresolved_entry_deals,protection_failures;};
struct E2ADXBBRVerification
  {int new_positions_registered,recovered_positions_validated,targets_attached,immutable_r_violations,invalid_r_geometry;};
struct E2ADXBBDayVerification
  {int enabled,history_locks_found,locks_created,candidates_suppressed,failed_attempts_locked;datetime history_range_start,history_range_end;int entry_deals_scanned,owned_entry_deals_found,today_owned_entry_deals_found,daily_lock_recovered;string daily_lock_failure_reason;};
struct E2ADXBBDayRecoveryDiagnostics
  {string target_broker_date,current_server_date,latest_owned_entry_deal_date,recovered_position_entry_date,date_comparison_result,failure_reason;datetime current_server_time,latest_owned_entry_deal_time,recovered_position_entry_time;ulong latest_owned_entry_deal,recovered_position_entry_deal;int owned_entry_deals_found,same_date_owned_entry_deals_found;};
struct E2ADXBBRecoveryVerification
  {int startup_open_positions,states_loaded,states_saved,states_cleared,recovery_failures,orphan_states;};

struct E2ADXBBRecoveryDiagnostics
  {
   string state_file_expected,state_file_found;
   int file_open_success,file_open_error,rows_read,valid_rows_parsed,fields_read,expected_fields,symbol_match,magic_match,position_identifier_match,position_ticket_match,direction_match,entry_deal_resolved,fill_valid,initial_sl_valid,original_r_valid,target_r_valid,tp_valid;
   int original_r_comparisons_performed,original_r_mismatches,sl_comparisons_performed,sl_mismatches,tp_comparisons_performed,tp_mismatches;
   string selected_recovery_record,recovery_failure_reason;
  };

#endif
