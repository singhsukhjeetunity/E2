#ifndef E2_STRATEGY_E2TYPES_MQH
#define E2_STRATEGY_E2TYPES_MQH

#include "..\\core\\E2TradeTypes.mqh"

struct E2Candidate
  {
   string candidate_id,symbol,timeframe;
   datetime signal_bar_time,signal_known_time;
   E2TradeDirection direction;
   double signal_close,atr,atr_multiplier,risk_distance;
   int rule_day;datetime range_start_rule,range_end_rule;
   double range_high,range_low,extension_distance;
   datetime execution_window_start,execution_window_end;
  };

struct E2SignalVerification
{long bars_observed,total_candidates,long_candidates,short_candidates,invalid_ranges,time_failures;};
struct E2PositionMetadata
  {
   string candidate_id,execution_id,symbol;
   E2TradeDirection direction;
   datetime signal_time,entry_time;
   ulong entry_deal,position_id,position_ticket;
   double volume,fill_price,submitted_stop,original_r,target_r,target_price,requested_risk_cash,actual_risk_cash;
   int rule_day;datetime range_start_rule,range_end_rule;
   double range_high,range_low,signal_close,extension_distance;
   string time_policy_digest;
  };

struct E2PlanVerification
  {int candidates_received,requests_created,expired_candidates,duplicate_candidates,invalid_candidates,position_rejections,day_rejections,sizing_rejections,quote_rejections;};
struct E2PlanningAudit
  {string status,reason,request_id,execution_id;datetime planning_time;double planning_bid,planning_ask,planning_spread,raw_sl,submitted_sl,sl_adjustment_distance,requested_cash_risk,calculated_volume;int sl_adjusted;};
struct E2ExecutionVerification
  {int attempts,successes,failures,duplicate_execution_ids,unresolved_entry_deals,protection_failures;};
struct E2RVerification
  {int new_positions_registered,recovered_positions_validated,targets_attached,immutable_r_violations,invalid_r_geometry;};
struct E2DayVerification
  {int enabled,history_locks_found,locks_created,candidates_suppressed,failed_attempts_locked;datetime history_range_start,history_range_end;int entry_deals_scanned,owned_entry_deals_found,today_owned_entry_deals_found,daily_lock_recovered,max_entries_per_symbol_day,duplicate_day_entry_violations,day_mapping_violations;string daily_lock_failure_reason;};
struct E2DayRecoveryDiagnostics
  {string target_broker_date,current_server_date,latest_owned_entry_deal_date,recovered_position_entry_date,date_comparison_result,failure_reason;datetime current_server_time,latest_owned_entry_deal_time,recovered_position_entry_time;ulong latest_owned_entry_deal,recovered_position_entry_deal;int owned_entry_deals_found,same_date_owned_entry_deals_found;};
struct E2RecoveryVerification
  {int startup_open_positions,states_loaded,states_saved,states_cleared,recovery_failures,orphan_states;};

struct E2RecoveryDiagnostics
  {
   string state_file_expected,state_file_found;
   int file_open_success,file_open_error,rows_read,valid_rows_parsed,fields_read,expected_fields,symbol_match,magic_match,position_identifier_match,position_ticket_match,direction_match,entry_deal_resolved,fill_valid,initial_sl_valid,original_r_valid,target_r_valid,tp_valid;
   int original_r_comparisons_performed,original_r_mismatches,sl_comparisons_performed,sl_mismatches,tp_comparisons_performed,tp_mismatches;
   string selected_recovery_record,recovery_failure_reason;
  };
struct E2ReconcileVerification
  {int signal_rows,unique_signal_candidate_ids,duplicate_signal_rows,trade_rows,unique_trade_ids,duplicate_trade_rows,total_candidates,executed_candidates,execution_failed_candidates,expired_candidates,position_rejected_candidates,day_rejected_candidates,sizing_rejected_candidates,safety_rejected_candidates,other_candidate_outcomes,candidate_outcome_sum,trade_requests,execution_attempts,execution_successes,new_positions_registered,finalized_trades,orphan_signal_rows,orphan_trade_rows,missing_signal_rows,missing_trade_rows,reconciliation_violations,write_failures;};
struct E2FinancialVerification
  {int trades_checked,financial_mismatch_trades,invalid_initial_risk_trades,invalid_realized_r_trades;double gross_profit_sum,commission_sum,swap_sum,fee_sum,net_profit_sum,mt5_authoritative_profit_sum,financial_difference;};

#endif
