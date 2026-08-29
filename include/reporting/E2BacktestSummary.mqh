#ifndef E2_REPORTING_E2BACKTESTSUMMARY_MQH
#define E2_REPORTING_E2BACKTESTSUMMARY_MQH

#include "E2Logger.mqh"
#include "..\\risk\\E2PositionSizer.mqh"

class E2BacktestSummary
  {
private:E2Logger *m_logger;
public:
   E2BacktestSummary(void):m_logger(NULL){}
   void Initialize(E2Logger &logger){m_logger=&logger;}
   void CoreVerify(const bool initialized,const int candidates,const int requests,const int attempts,const int successes,const int registered,const int finalized,const int duplicate_execution_ids,const int duplicate_finalized,const int causality,const int ownership,const int unknown_positions)
     {if(m_logger==NULL)return;m_logger.Info("initialized="+IntegerToString((int)initialized)+", strategyCandidates="+IntegerToString(candidates)+", tradeRequests="+IntegerToString(requests)+", executionAttempts="+IntegerToString(attempts)+", executionSuccesses="+IntegerToString(successes)+", positionsRegistered="+IntegerToString(registered)+", finalizedTrades="+IntegerToString(finalized)+", duplicateExecutionIds="+IntegerToString(duplicate_execution_ids)+", duplicateFinalizedTrades="+IntegerToString(duplicate_finalized)+", causalityViolations="+IntegerToString(causality)+", ownershipViolations="+IntegerToString(ownership)+", unknownE2Positions="+IntegerToString(unknown_positions)+".","E2_CORE_VERIFY");}
   void RiskVerify(const E2RiskModeVerification &v)
     {if(m_logger==NULL)return;m_logger.Info("tradesSized="+IntegerToString(v.trades_sized)+", fixedCashRequests="+IntegerToString(v.fixed_cash_requests)+", balancePercentRequests="+IntegerToString(v.balance_percent_requests)+", requestedMin="+DoubleToString(v.requested_min,2)+", requestedMax="+DoubleToString(v.requested_max,2)+", requestedAverage="+DoubleToString(v.trades_sized>0?v.requested_sum/v.trades_sized:0.0,2)+", actualInitialRiskMin="+DoubleToString(v.original_min,2)+", actualInitialRiskMax="+DoubleToString(v.original_max,2)+", actualInitialRiskAverage="+DoubleToString(v.trades_sized>0?v.original_sum/v.trades_sized:0.0,2)+", minimumRiskDifference="+DoubleToString(v.difference_min,2)+", maximumRiskDifference="+DoubleToString(v.difference_max,2)+", averageRiskDifference="+DoubleToString(v.trades_sized>0?v.difference_sum/v.trades_sized:0.0,2)+", actualRiskAboveRequested="+IntegerToString(v.actual_risk_above_requested)+", riskModeMismatch="+IntegerToString(v.risk_mode_mismatch)+", invalidRiskRequests="+IntegerToString(v.invalid_risk_requests)+".","E2_RISK_VERIFY");}
  };

#endif
