#ifndef E2_REPORTING_E2BACKTESTSUMMARY_MQH
#define E2_REPORTING_E2BACKTESTSUMMARY_MQH
#include "E2Logger.mqh"
class E2BacktestSummary
  {
private: E2Logger *m_logger;
public: E2BacktestSummary(void):m_logger(NULL){} void Initialize(E2Logger &logger){m_logger=&logger;}
   void CoreVerify(const bool initialized,const int candidates,const int requests,const int attempts,const int successes,const int registered,const int finalized,const int duplicate_execution_ids,const int duplicate_finalized,const int causality,const int ownership,const int unknown_positions)
     {if(m_logger==NULL)return;m_logger.Info("initialized="+IntegerToString((int)initialized)+", strategyCandidates="+IntegerToString(candidates)+", tradeRequests="+IntegerToString(requests)+", executionAttempts="+IntegerToString(attempts)+", executionSuccesses="+IntegerToString(successes)+", positionsRegistered="+IntegerToString(registered)+", finalizedTrades="+IntegerToString(finalized)+", duplicateExecutionIds="+IntegerToString(duplicate_execution_ids)+", duplicateFinalizedTrades="+IntegerToString(duplicate_finalized)+", causalityViolations="+IntegerToString(causality)+", ownershipViolations="+IntegerToString(ownership)+", unknownE2Positions="+IntegerToString(unknown_positions)+".","E2_CORE_VERIFY");}
  };
#endif
