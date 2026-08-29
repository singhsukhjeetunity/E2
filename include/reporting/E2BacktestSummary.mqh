#ifndef E2_REPORTING_E2BACKTESTSUMMARY_MQH
#define E2_REPORTING_E2BACKTESTSUMMARY_MQH

#include "E2Logger.mqh"
#include "..\\risk\\E2PositionSizer.mqh"
#include "..\\strategy\\E2ADXBBTypes.mqh"

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
   void ADXBBSignalVerify(const E2ADXBBSignalVerification &v)
     {if(m_logger==NULL)return;m_logger.Info("barsObserved="+IntegerToString((int)v.bars_observed)+", completedBarsProcessed="+IntegerToString((int)v.completed_bars_processed)+", indicatorWarmupBars="+IntegerToString((int)v.indicator_warmup_bars)+", invalidIndicatorBars="+IntegerToString((int)v.invalid_indicator_bars)+", rangingBars="+IntegerToString((int)v.ranging_bars)+", trendingBars="+IntegerToString((int)v.trending_bars)+", closeBelowLowerBand="+IntegerToString((int)v.close_below_lower_band)+", closeAboveUpperBand="+IntegerToString((int)v.close_above_upper_band)+", longCandidates="+IntegerToString((int)v.long_candidates)+", shortCandidates="+IntegerToString((int)v.short_candidates)+", totalCandidates="+IntegerToString((int)v.total_candidates)+", duplicateCandidates="+IntegerToString((int)v.duplicate_candidates)+", invalidBandGeometry="+IntegerToString((int)v.invalid_band_geometry)+", invalidAtrBars="+IntegerToString((int)v.invalid_atr_bars)+", causalityViolations="+IntegerToString((int)v.causality_violations)+".","ADXBB_SIGNAL_VERIFY");}
   void ADXBBIndicatorVerify(const E2ADXBBIndicatorVerification &v)
     {if(m_logger==NULL)return;m_logger.Info("barsChecked="+IntegerToString((int)v.bars_checked)+", adxValidBars="+IntegerToString((int)v.adx_valid_bars)+", bbValidBars="+IntegerToString((int)v.bb_valid_bars)+", atrValidBars="+IntegerToString((int)v.atr_valid_bars)+", adxMin="+DoubleToString(v.adx_min,10)+", adxMax="+DoubleToString(v.adx_max,10)+", atrMin="+DoubleToString(v.atr_min,10)+", atrMax="+DoubleToString(v.atr_max,10)+", bbGeometryViolations="+IntegerToString((int)v.bb_geometry_violations)+", rmaInitializationViolations="+IntegerToString((int)v.rma_initialization_violations)+", indicatorTimestampViolations="+IntegerToString((int)v.indicator_timestamp_violations)+".","ADXBB_INDICATOR_VERIFY");}
  };

#endif
