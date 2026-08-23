#ifndef E2_REPORTING_E2BACKTESTSUMMARY_MQH
#define E2_REPORTING_E2BACKTESTSUMMARY_MQH
#include "E2Logger.mqh"
#include "..\\strategy\\E2OBRTypes.mqh"
class E2BacktestSummary
  {
private: E2Logger *m_logger;
public: E2BacktestSummary(void):m_logger(NULL){} void Initialize(E2Logger &logger){m_logger=&logger;}
   void CoreVerify(const bool initialized,const int candidates,const int requests,const int attempts,const int successes,const int registered,const int finalized,const int duplicate_execution_ids,const int duplicate_finalized,const int causality,const int ownership,const int unknown_positions)
     {if(m_logger==NULL)return;m_logger.Info("initialized="+IntegerToString((int)initialized)+", strategyCandidates="+IntegerToString(candidates)+", tradeRequests="+IntegerToString(requests)+", executionAttempts="+IntegerToString(attempts)+", executionSuccesses="+IntegerToString(successes)+", positionsRegistered="+IntegerToString(registered)+", finalizedTrades="+IntegerToString(finalized)+", duplicateExecutionIds="+IntegerToString(duplicate_execution_ids)+", duplicateFinalizedTrades="+IntegerToString(duplicate_finalized)+", causalityViolations="+IntegerToString(causality)+", ownershipViolations="+IntegerToString(ownership)+", unknownE2Positions="+IntegerToString(unknown_positions)+".","E2_CORE_VERIFY");}
   void OBRVerify(const E2OBRVerification &v)
     {if(m_logger==NULL)return;m_logger.Info("londonDaysObserved="+IntegerToString((int)v.london_days_observed)+", openingRangesComplete="+IntegerToString((int)v.opening_ranges_complete)+", openingRangesIncomplete="+IntegerToString((int)v.opening_ranges_incomplete)+", breakoutEligibleCandles="+IntegerToString((int)v.breakout_eligible_candles)+", longCloseBreakouts="+IntegerToString((int)v.long_close_breakouts)+", shortCloseBreakouts="+IntegerToString((int)v.short_close_breakouts)+", adxPass="+IntegerToString((int)v.adx_pass)+", rangeSizePass="+IntegerToString((int)v.range_size_pass)+", longGapPass="+IntegerToString((int)v.long_gap_pass)+", shortGapPass="+IntegerToString((int)v.short_gap_pass)+", longCandidates="+IntegerToString((int)v.long_candidates)+", shortCandidates="+IntegerToString((int)v.short_candidates)+", totalCandidates="+IntegerToString((int)v.total_candidates)+", duplicateCandidates="+IntegerToString((int)v.duplicate_candidates)+", causalityViolations="+IntegerToString((int)v.causality_violations)+".","OBR_VERIFY");}
   void OBRTimeVerify(const E2OBRTimeVerification &v)
     {if(m_logger==NULL)return;m_logger.Info("gmtDays="+IntegerToString((int)v.gmt_days)+", bstDays="+IntegerToString((int)v.bst_days)+", dstTransitionObservations="+IntegerToString((int)v.dst_transition_observations)+", orReconstructionSuccesses="+IntegerToString((int)v.or_reconstruction_successes)+", orReconstructionFailures="+IntegerToString((int)v.or_reconstruction_failures)+", orMutationViolations="+IntegerToString((int)v.or_mutation_violations)+", invalidOrBars="+IntegerToString((int)v.invalid_or_bars)+", dayResetViolations="+IntegerToString((int)v.day_reset_violations)+".","OBR_TIME_VERIFY");}
  };
#endif
