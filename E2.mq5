//+------------------------------------------------------------------+
//|                                                           E2.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "include\\core\\E2Config.mqh"
#include "include\\core\\E2SymbolInfo.mqh"
#include "include\\core\\E2AccountInfo.mqh"
#include "include\\core\\E2Environment.mqh"
#include "include\\reporting\\E2TradeReporter.mqh"
#include "include\\reporting\\E2BacktestSummary.mqh"
#include "include\\analysis\\E2MarketData.mqh"
#include "include\\analysis\\E2H4RegimeEngine.mqh"
#include "include\\analysis\\E2H1ZoneEngine.mqh"
#include "include\\analysis\\E2H1RangeBoundaryEngine.mqh"
#include "include\\analysis\\E2M15ConfirmationEngine.mqh"
#include "include\\analysis\\E2TrendContinuationEngine.mqh"
#include "include\\analysis\\E2RangeMeanReversionEngine.mqh"
#include "include\\analysis\\E2RangeBreakoutEngine.mqh"
#include "include\\strategy\\E2V2TradePlanEngine.mqh"
#include "include\\filters\\E2SessionFilter.mqh"
#include "include\\filters\\E2NewsFilter.mqh"
#include "include\\risk\\E2PositionSizer.mqh"
#include "include\\execution\\E2OrderExecutor.mqh"
#include "include\\execution\\E2PositionGuard.mqh"
#include "include\\execution\\E2ExecutionSafety.mqh"
#include "include\\execution\\E2V2ExecutionEngine.mqh"
#include "include\\execution\\E2V2PositionManager.mqh"
#include "include\\visualization\\E2Visualizer.mqh"

E2Config g_configuration;
E2Environment g_environment;
E2Logger g_logger;
E2TradeReporter g_trade_reporter;
E2BacktestSummary g_backtest_summary;
E2MarketData g_market_data;
E2H4RegimeEngine g_h4_regime_engine;
E2H1ZoneEngine g_h1_zone_engine;
E2H1RangeBoundaryEngine g_h1_range_boundary_engine;
E2M15ConfirmationEngine g_m15_confirmation_engine;
E2TrendContinuationEngine g_trend_continuation_engine;
E2RangeMeanReversionEngine g_range_mean_reversion_engine;
E2RangeBreakoutEngine g_range_breakout_engine;
E2V2TradePlanEngine g_v2_trade_plan_engine;
E2SessionFilter g_session_filter;
E2NewsFilter g_news_filter;
E2SymbolInfo g_symbol_info;
E2AccountInfo g_account_info;
E2PositionSizer g_position_sizer;
E2OrderExecutor g_order_executor;
E2PositionGuard g_position_guard;
E2ExecutionSafety g_execution_safety;
E2V2ExecutionEngine g_v2_execution_engine;
E2V2PositionManager g_v2_position_manager;
E2Visualizer g_visualizer;
ulong g_diagnostic_tick_count=0;
datetime g_last_h1_zone_v2_visual_bar=0;
datetime g_last_m15_confirmation_v2_bar=0;
datetime g_last_h4_v2_bar=0,g_last_h1_v2_bar=0,g_last_tc_v2_bar=0;
datetime g_last_rmr_bar=0;
datetime g_last_rb_bar=0;
ulong g_v2_h4_calls=0,g_v2_h1_calls=0,g_v2_m15_calls=0,g_v2_m15_contexts=0;
E2H1ZoneV2Record g_h1_v2_zones[];
E2H4RegimeResult g_current_h4_regime;
bool g_has_current_h4_regime=false;
E2H1RangeBoundaryContext g_current_h1_range;

string E2YesNo(const bool value)
  {
   return(value ? "yes" : "no");
  }

string E2H1DepartureSampleText(const E2H1ZoneV2DepartureSample &sample)
  {
   return("pivot="+TimeToString(sample.pivot_time,TIME_DATE|TIME_MINUTES)+", price="+DoubleToString(sample.pivot_price,_Digits)+", knownFrom="+TimeToString(sample.known_from_time,TIME_DATE|TIME_MINUTES)+", frozenATR="+DoubleToString(sample.frozen_atr,_Digits)+", bestAway="+DoubleToString(sample.best_away_price,_Digits)+", distance="+DoubleToString(sample.distance,_Digits)+", departureATR="+DoubleToString(sample.departure_atr,3));
  }



void E2RunH4RegimeV2(void)
  {
   const datetime closed=iTime(_Symbol,PERIOD_H4,1);if(closed<=0 || closed==g_last_h4_v2_bar)return;g_last_h4_v2_bar=closed;
   g_v2_h4_calls++;
   E2H4RegimeResult result;
   if(g_h4_regime_engine.Evaluate(_Symbol,TimeCurrent(),result))
     {g_current_h4_regime=result;g_has_current_h4_regime=true;g_visualizer.UpdateH4RegimeV2(result);}
  }

void E2RunH1ZoneV2(void)
  {
   const datetime closed=iTime(_Symbol,PERIOD_H1,1);if(closed<=0 || closed==g_last_h1_v2_bar)return;g_last_h1_v2_bar=closed;
   g_v2_h1_calls++;
   const E2H1RangeBoundaryContext pre_update_range=g_current_h1_range;
   E2H1ZoneV2Record zones[];
   if(g_h1_zone_engine.Evaluate(_Symbol,TimeCurrent(),zones))
     {
      ArrayResize(g_h1_v2_zones,ArraySize(zones));for(int i=0;i<ArraySize(zones);i++)g_h1_v2_zones[i]=zones[i];
      const datetime closed_h1=g_h1_zone_engine.LastClosedTime();
      if(closed_h1!=g_last_h1_zone_v2_visual_bar)
        {g_last_h1_zone_v2_visual_bar=closed_h1;g_visualizer.UpdateH1ZoneV2(zones,TimeCurrent());}
      if(g_has_current_h4_regime)
        {g_range_breakout_engine.ProcessPreEventH1(_Symbol,TimeCurrent(),g_current_h4_regime,pre_update_range,g_h1_zone_engine.LastAtr());g_h1_range_boundary_engine.Evaluate(_Symbol,TimeCurrent(),g_current_h4_regime,zones,g_h1_zone_engine.LastKnownFrom(),g_h1_zone_engine.LastClose(),g_h1_zone_engine.LastAtr(),g_current_h1_range);g_range_breakout_engine.ObservePostEventRange(g_current_h1_range);g_visualizer.UpdateH1RangeBoundary(g_current_h1_range,TimeCurrent());}
     }
  }

void E2RunM15ConfirmationV2(void)
  {
   // Standalone all-active-zone confirmation is an optional visual audit only.
   // TC V2 evaluates its own RETEST_ACTIVE contexts below, regardless of this.
   if(!g_configuration.visual_mode_enabled || !g_configuration.visual_show_m15_confirmation_v2)return;
   MqlRates closed;
   if(!g_market_data.GetClosedBarAsOf(_Symbol,PERIOD_M15,TimeCurrent(),closed) || closed.time==g_last_m15_confirmation_v2_bar)return;
   g_last_m15_confirmation_v2_bar=closed.time;
   E2H1ZoneV2Record zones[];g_h1_zone_engine.ActiveZones(zones);
   for(int i=0;i<ArraySize(zones);i++)
     {
      if(zones[i].state!=E2_H1_ZONE_V2_ACTIVE)continue;g_v2_m15_contexts++;
      E2M15ZoneContext context;context.zone_id=zones[i].zone_id;context.type=zones[i].type;context.state=zones[i].state;context.lower=zones[i].lower;context.upper=zones[i].upper;context.creation_time=zones[i].creation_time;context.invalidation_time=zones[i].invalidation_time;
      E2M15ConfirmationResult results[];
      g_v2_m15_calls++;if(g_m15_confirmation_engine.Evaluate(_Symbol,TimeCurrent(),context,results))g_visualizer.UpdateM15ConfirmationV2(results);
     }
  }

void E2RunTrendContinuationV2(void)
  {
   const datetime closed=iTime(_Symbol,PERIOD_M15,1);if(closed<=0 || closed==g_last_tc_v2_bar)return;g_last_tc_v2_bar=closed;
   E2H4RegimeResult h4; E2TrendContinuationCandidate candidates[];
   if(!g_h4_regime_engine.Evaluate(_Symbol,TimeCurrent(),h4) || ArraySize(g_h1_v2_zones)==0)return;
   if(g_trend_continuation_engine.Evaluate(_Symbol,TimeCurrent(),h4,g_h1_v2_zones,candidates)){g_visualizer.UpdateTrendContinuationV2(candidates);for(int i=0;i<ArraySize(candidates);i++){E2V2TradePlan plan;if(g_v2_trade_plan_engine.RouteTrendContinuation(_Symbol,TimeCurrent(),candidates[i],h4,g_h1_v2_zones,plan)){E2V2ExecutionResult execution;g_v2_execution_engine.Execute(_Symbol,plan,execution);}if(g_configuration.research_verification_summary)g_logger.Info("#"+IntegerToString(i+1)+" "+E2TrendContinuationDirectionName(candidates[i].direction)+" regime="+E2RegimeTypeName(candidates[i].h4_regime_at_confirmation)+" eligible="+E2YesNo(candidates[i].trend_entry_eligible)+" overextended="+E2YesNo(candidates[i].overextended)+" zone="+candidates[i].source_zone_id+" attempt="+IntegerToString(candidates[i].attempt_number)+" breakoutCandle="+TimeToString(candidates[i].breakout_time,TIME_DATE|TIME_MINUTES)+" breakoutKnownFrom="+TimeToString(candidates[i].breakout_known_from_time,TIME_DATE|TIME_MINUTES)+" retest="+TimeToString(candidates[i].retest_time,TIME_DATE|TIME_MINUTES)+" retestKnownFrom="+TimeToString(candidates[i].retest_known_from_time,TIME_DATE|TIME_MINUTES)+" confirmationCandle="+TimeToString(candidates[i].candidate_time,TIME_DATE|TIME_MINUTES)+" confirmationKnownFrom="+TimeToString(candidates[i].candidate_known_from_time,TIME_DATE|TIME_MINUTES),"TCV2_CANDIDATE");}}
  }

void E2RunRangeMeanReversion(void)
  {
   const datetime closed=iTime(_Symbol,PERIOD_M15,1);if(closed<=0||closed==g_last_rmr_bar)return;g_last_rmr_bar=closed;
   if(!g_has_current_h4_regime)return;E2RangeMeanReversionCandidate candidates[];
   if(g_range_mean_reversion_engine.Evaluate(_Symbol,TimeCurrent(),g_current_h4_regime,g_current_h1_range,g_h1_zone_engine.LastAtr(),candidates))
     {g_visualizer.UpdateRangeMeanReversion(candidates);for(int i=0;i<ArraySize(candidates);i++){E2V2TradePlan plan;if(g_v2_trade_plan_engine.RouteRangeMeanReversion(_Symbol,TimeCurrent(),candidates[i],g_current_h4_regime,g_current_h1_range,g_h1_v2_zones,plan)){E2V2ExecutionResult execution;g_v2_execution_engine.Execute(_Symbol,plan,execution);}}}
  }

void E2RunRangeBreakout(void)
  {
   const datetime closed=iTime(_Symbol,PERIOD_M15,1);if(closed<=0||closed==g_last_rb_bar)return;g_last_rb_bar=closed;
   if(!g_has_current_h4_regime)return;E2RangeBreakoutCandidate candidates[];
   if(g_range_breakout_engine.EvaluateM15(_Symbol,TimeCurrent(),g_current_h4_regime,candidates))
     {g_visualizer.UpdateRangeBreakout(candidates);for(int i=0;i<ArraySize(candidates);i++){E2V2TradePlan plan;if(g_v2_trade_plan_engine.RouteRangeBreakout(_Symbol,TimeCurrent(),candidates[i],g_h1_v2_zones,plan)){E2V2ExecutionResult execution;g_v2_execution_engine.Execute(_Symbol,plan,execution);}if(g_configuration.research_verification_summary)g_logger.Info("id="+candidates[i].candidate_id+", range="+candidates[i].range_id+", direction="+(candidates[i].direction==E2_RB_LONG?"LONG":"SHORT")+", attempt="+IntegerToString(candidates[i].attempt_number)+", breakout="+TimeToString(candidates[i].breakout_candle,TIME_DATE|TIME_MINUTES)+", breakoutKnownFrom="+TimeToString(candidates[i].breakout_known_from,TIME_DATE|TIME_MINUTES)+", retest="+TimeToString(candidates[i].retest_time,TIME_DATE|TIME_MINUTES)+", retestKnownFrom="+TimeToString(candidates[i].retest_known_from,TIME_DATE|TIME_MINUTES)+", confirmation="+TimeToString(candidates[i].confirmation_candle,TIME_DATE|TIME_MINUTES)+", confirmationKnownFrom="+TimeToString(candidates[i].confirmation_known_from,TIME_DATE|TIME_MINUTES),"RB_CANDIDATE");}}
  }





//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   E2LoadConfiguration(g_configuration);
   g_environment.Initialize();
   g_diagnostic_tick_count=0;
   g_last_h1_zone_v2_visual_bar=0;
   g_last_m15_confirmation_v2_bar=0;
   g_last_h4_v2_bar=0;
   g_last_h1_v2_bar=0;
   g_last_tc_v2_bar=0;
   g_last_rmr_bar=0;
   g_last_rb_bar=0;
   g_v2_h4_calls=0;
   g_v2_h1_calls=0;
   g_v2_m15_calls=0;
   g_v2_m15_contexts=0;
   g_has_current_h4_regime=false;
   ZeroMemory(g_current_h4_regime);
   ZeroMemory(g_current_h1_range);
   g_logger.Initialize(g_configuration.logging_enabled,g_configuration.debug_mode);
   g_logger.Info("E2 initialization started.","Lifecycle");

   string validation_reason;
   if(!E2ValidateConfiguration(g_configuration,validation_reason))
     {
      g_logger.Error("Configuration validation failed: "+validation_reason,"Lifecycle");
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_logger.Info("Configuration validated.","Lifecycle");
   g_logger.Debug("Debug logging is enabled.","Lifecycle");
   if(!g_symbol_info.Initialize(_Symbol,g_logger))
      g_logger.Warning("Symbol specification diagnostics are unavailable for this run.","Lifecycle");
   if(!g_account_info.Initialize(g_logger))
      g_logger.Warning("Account specification diagnostics are unavailable for this run.","Lifecycle");
   g_position_sizer.Initialize(g_configuration,g_symbol_info,g_account_info,g_logger);
   g_position_guard.Initialize(g_configuration,g_logger);
   g_execution_safety.Initialize(g_configuration,g_logger);
   g_order_executor.Initialize(g_configuration,g_symbol_info,g_account_info,g_position_guard,g_execution_safety,g_logger);
   g_market_data.Initialize(g_configuration,g_logger);
   g_h4_regime_engine.Initialize(g_configuration,g_market_data,g_logger);
   g_h1_zone_engine.Initialize(g_configuration,g_market_data,g_logger);
   g_h1_range_boundary_engine.Initialize(g_configuration,g_logger);
   g_m15_confirmation_engine.Initialize(g_configuration,g_market_data,g_logger);
   g_trend_continuation_engine.Initialize(g_configuration,g_market_data,g_m15_confirmation_engine,g_logger);
   g_range_mean_reversion_engine.Initialize(g_configuration,g_market_data,g_m15_confirmation_engine,g_logger);
   g_range_breakout_engine.Initialize(g_configuration,g_market_data,g_m15_confirmation_engine,g_logger);
   g_session_filter.Initialize(g_configuration);
   g_news_filter.Initialize(g_configuration,g_logger);
   g_v2_trade_plan_engine.Initialize(g_configuration,g_symbol_info,g_position_sizer,g_position_guard,g_session_filter,g_news_filter,g_logger);
   g_visualizer.Initialize(g_configuration,g_logger);
   if(!g_trade_reporter.Initialize(g_configuration.csv_export_enabled,g_configuration.expert_magic_number,_Symbol,g_logger))
      g_logger.Warning("Trade CSV reporting disabled for this run because initialization failed.","Reporting");
   g_v2_execution_engine.Initialize(g_configuration,g_symbol_info,g_position_sizer,g_position_guard,g_order_executor,g_trade_reporter,g_logger);
   g_v2_position_manager.Initialize(g_configuration,g_logger);
   if(g_environment.IsTester() && !g_backtest_summary.Initialize(g_configuration.csv_export_enabled,g_configuration,_Symbol,g_trade_reporter.RunId(),g_logger))
      g_logger.Warning("Backtest summary CSV reporting disabled for this run because initialization failed.","Reporting");
   E2RunH4RegimeV2();
   E2RunH1ZoneV2();
   E2RunM15ConfirmationV2();
   E2RunRangeMeanReversion();
   E2RunRangeBreakout();
   E2RunTrendContinuationV2();

   g_logger.Info("Reporting initialized.","Lifecycle");
   g_logger.Info("E2 initialized successfully.","Lifecycle");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_environment.IsTester() && g_configuration.research_verification_summary)
     {
      E2TrendContinuationVerification v=g_trend_continuation_engine.Verification();
      E2TCGateDiagnostics g=g_trend_continuation_engine.Gates();
      E2H1ZoneV2Verification z=g_h1_zone_engine.Verification();
      E2H1ZoneV2RoleGate rg=g_h1_zone_engine.RoleGate();
      E2H1ZoneV2DepartureWindow dw=g_h1_zone_engine.DepartureWindow();
      E2H1ZoneV2DepartureMagnitude dm=g_h1_zone_engine.DepartureMagnitude();
      E2H1ZoneV2Lifetime life=g_h1_zone_engine.Lifetime();
      E2H1ZoneV2PersistentDiagnostics pd=g_h1_zone_engine.PersistentDiagnostics();
      E2H1ZoneV2Workload pw=g_h1_zone_engine.Workload();
      E2V2PlanVerification pv=g_v2_trade_plan_engine.Verification();
      E2V2ExecutionVerification ev=g_v2_execution_engine.Verification();
      E2V2ManagementDiagnostics global_mv=g_v2_position_manager.Diagnostics();
      E2V2ManagementDiagnostics mv=g_v2_position_manager.TCDiagnostics();
      E2H4RangeVerification hv=g_h4_regime_engine.RangeVerification();
      E2H1RangeVerification h1rv=g_h1_range_boundary_engine.Verification();
      E2RangeMeanReversionVerification rmrv=g_range_mean_reversion_engine.Verification();
      E2RangeBreakoutVerification rbv=g_range_breakout_engine.Verification();
      E2RBH1Verification rbh1=g_range_breakout_engine.H1Verification();
      E2M15RejectionVerification rejectionv=g_m15_confirmation_engine.RejectionVerification();
      E2RMRPlanVerification rmrpv=g_v2_trade_plan_engine.RMRVerification();
      E2RMRExecutionVerification rmrev=g_v2_execution_engine.RMRVerification();
      E2RMRManagementDiagnostics rmrmv=g_v2_position_manager.RMRDiagnostics();
      E2RBPlanVerification rbpv=g_v2_trade_plan_engine.RBVerification();
      E2RBExecutionVerification rbev=g_v2_execution_engine.RBVerification();
      E2RMRManagementDiagnostics rbmv=g_v2_position_manager.RBDiagnostics();
      g_logger.Info("h4Contexts="+IntegerToString((int)hv.h4_contexts)+", uptrendContexts="+IntegerToString((int)hv.uptrend_contexts)+", downtrendContexts="+IntegerToString((int)hv.downtrend_contexts)+", rangeContexts="+IntegerToString((int)hv.range_contexts)+", neutralContexts="+IntegerToString((int)hv.neutral_contexts)+", insufficientData="+IntegerToString((int)hv.insufficient_data)+", rangeAdxPass="+IntegerToString((int)hv.range_adx_pass)+", rangeContainmentChecks="+IntegerToString((int)hv.range_containment_checks)+", rangeWidthPass="+IntegerToString((int)hv.range_width_pass)+", rangeClassifications="+IntegerToString((int)hv.range_classifications)+", causalityViolations="+IntegerToString((int)hv.causality_violations)+", avgRangeWidthATR="+DoubleToString(hv.average_range_width_atr,3)+", minRangeWidthATR="+DoubleToString(hv.minimum_range_width_atr,3)+", maxRangeWidthATR="+DoubleToString(hv.maximum_range_width_atr,3),"H4_RANGE_VERIFY");
      g_logger.Info("h1Contexts="+IntegerToString((int)h1rv.h1_contexts)+", h4RangeContextsObserved="+IntegerToString((int)h1rv.h4_range_contexts_observed)+", contextsWithSupport="+IntegerToString((int)h1rv.contexts_with_support)+", contextsWithResistance="+IntegerToString((int)h1rv.contexts_with_resistance)+", pairChecks="+IntegerToString((int)h1rv.pair_checks)+", pairsOrderValid="+IntegerToString((int)h1rv.pairs_order_valid)+", pairsContainmentPass="+IntegerToString((int)h1rv.pairs_containment_pass)+", pairsHeightPass="+IntegerToString((int)h1rv.pairs_height_pass)+", rangesCreated="+IntegerToString((int)h1rv.ranges_created)+", rangesInvalidatedH4Loss="+IntegerToString((int)h1rv.ranges_invalidated_h4_loss)+", rangesInvalidatedLowerZone="+IntegerToString((int)h1rv.ranges_invalidated_lower_zone)+", rangesInvalidatedUpperZone="+IntegerToString((int)h1rv.ranges_invalidated_upper_zone)+", rangesInvalidatedLowerBreak="+IntegerToString((int)h1rv.ranges_invalidated_lower_break)+", rangesInvalidatedUpperBreak="+IntegerToString((int)h1rv.ranges_invalidated_upper_break)+", activeRangeAtEnd="+E2YesNo(h1rv.active_range_at_end),"H1_RANGE_VERIFY");
      g_logger.Info("duplicateRangeIds="+IntegerToString((int)h1rv.duplicate_range_ids)+", boundaryMutationViolations="+IntegerToString((int)h1rv.boundary_mutation_violations)+", causalityViolations="+IntegerToString((int)h1rv.causality_violations)+", avgRangeHeightATR="+DoubleToString(h1rv.average_range_height_atr,3)+", minRangeHeightATR="+DoubleToString(h1rv.minimum_range_height_atr,3)+", maxRangeHeightATR="+DoubleToString(h1rv.maximum_range_height_atr,3)+", maxCandidatePairs="+IntegerToString((int)h1rv.max_candidate_pairs),"H1_RANGE_VERIFY_2");
      g_logger.Info("m15Contexts="+IntegerToString((int)rmrv.m15_contexts)+", h4RangeEligible="+IntegerToString((int)rmrv.h4_range_eligible)+", activeRangeContexts="+IntegerToString((int)rmrv.active_range_contexts)+", longInteriorArms="+IntegerToString((int)rmrv.long_interior_arms)+", shortInteriorArms="+IntegerToString((int)rmrv.short_interior_arms)+", longBoundaryVisits="+IntegerToString((int)rmrv.long_boundary_visits)+", shortBoundaryVisits="+IntegerToString((int)rmrv.short_boundary_visits)+", bullishRejectionPasses="+IntegerToString((int)rmrv.bullish_rejection_passes)+", bearishRejectionPasses="+IntegerToString((int)rmrv.bearish_rejection_passes)+", longCandidates="+IntegerToString((int)rmrv.long_candidates)+", shortCandidates="+IntegerToString((int)rmrv.short_candidates)+", totalCandidates="+IntegerToString((int)rmrv.total_candidates)+", rearmsLong="+IntegerToString((int)rmrv.rearms_long)+", rearmsShort="+IntegerToString((int)rmrv.rearms_short)+", duplicateCandidates="+IntegerToString((int)rmrv.duplicate_candidates)+", sameConfirmationCollisions="+IntegerToString((int)rmrv.same_confirmation_collisions)+", collisionResolutions="+IntegerToString((int)rmrv.collision_resolutions)+", causalityViolations="+IntegerToString((int)rmrv.causality_violations)+", invalidatedH4Loss="+IntegerToString((int)rmrv.invalidated_h4_loss)+", invalidatedRangeLoss="+IntegerToString((int)rmrv.invalidated_range_loss)+", maxAttemptsPerRangeLong="+IntegerToString((int)rmrv.max_attempts_per_range_long)+", maxAttemptsPerRangeShort="+IntegerToString((int)rmrv.max_attempts_per_range_short),"RMR_VERIFY");
      g_logger.Info("m15Contexts="+IntegerToString((int)rbv.m15_contexts)+", h1Contexts="+IntegerToString((int)rbv.h1_contexts)+", h4RangeEligible="+IntegerToString((int)rbv.h4_range_eligible)+", activeRangeContexts="+IntegerToString((int)rbv.active_range_contexts)+", longBreakoutChecks="+IntegerToString((int)rbv.long_breakout_checks)+", shortBreakoutChecks="+IntegerToString((int)rbv.short_breakout_checks)+", longDistancePass="+IntegerToString((int)rbv.long_distance_pass)+", shortDistancePass="+IntegerToString((int)rbv.short_distance_pass)+", longStrongBodyPass="+IntegerToString((int)rbv.long_strong_body_pass)+", shortStrongBodyPass="+IntegerToString((int)rbv.short_strong_body_pass)+", longBreakoutsAccepted="+IntegerToString((int)rbv.long_breakouts_accepted)+", shortBreakoutsAccepted="+IntegerToString((int)rbv.short_breakouts_accepted)+", longRetests="+IntegerToString((int)rbv.long_retests)+", shortRetests="+IntegerToString((int)rbv.short_retests)+", bullishMomentumPasses="+IntegerToString((int)rbv.bullish_momentum_passes)+", bearishMomentumPasses="+IntegerToString((int)rbv.bearish_momentum_passes)+", longCandidates="+IntegerToString((int)rbv.long_candidates)+", shortCandidates="+IntegerToString((int)rbv.short_candidates)+", totalCandidates="+IntegerToString((int)rbv.total_candidates)+", expiredLong="+IntegerToString((int)rbv.expired_long)+", expiredShort="+IntegerToString((int)rbv.expired_short)+", invalidatedH4Loss="+IntegerToString((int)rbv.invalidated_h4_loss)+", invalidatedRangeLoss="+IntegerToString((int)rbv.invalidated_range_loss)+", invalidatedDepthLong="+IntegerToString((int)rbv.invalidated_depth_long)+", invalidatedDepthShort="+IntegerToString((int)rbv.invalidated_depth_short)+", rearmsLong="+IntegerToString((int)rbv.rearms_long)+", rearmsShort="+IntegerToString((int)rbv.rearms_short)+", duplicateCandidates="+IntegerToString((int)rbv.duplicate_candidates)+", multipleClaimantTimestamps="+IntegerToString((int)rbv.multiple_claimant_timestamps)+", maxClaimants="+IntegerToString((int)rbv.max_claimants)+", ownershipResolutions="+IntegerToString((int)rbv.ownership_resolutions)+", sameConfirmationMultipleCandidates="+IntegerToString((int)rbv.same_confirmation_multiple_candidates)+", causalityViolations="+IntegerToString((int)rbv.causality_violations)+", maxAttemptsPerRangeLong="+IntegerToString((int)rbv.max_attempts_per_range_long)+", maxAttemptsPerRangeShort="+IntegerToString((int)rbv.max_attempts_per_range_short)+", maxLongDistanceATR="+DoubleToString(rbv.max_long_distance_atr,3)+", maxShortDistanceATR="+DoubleToString(rbv.max_short_distance_atr,3)+", avgLongDistanceATR="+DoubleToString(rbv.average_long_distance_atr,3)+", avgShortDistanceATR="+DoubleToString(rbv.average_short_distance_atr,3),"RB_VERIFY");
      g_range_breakout_engine.ReportAudit();
      g_logger.Info("evaluations="+IntegerToString((int)rbh1.evaluations)+", distancePass="+IntegerToString((int)rbh1.distance_pass)+", directionPass="+IntegerToString((int)rbh1.direction_pass)+", bodyMedianPass="+IntegerToString((int)rbh1.body_median_pass)+", bodyRangePass="+IntegerToString((int)rbh1.body_range_pass)+", closingLocationPass="+IntegerToString((int)rbh1.closing_location_pass)+", totalPass="+IntegerToString((int)rbh1.total_pass)+", zeroRangeCandles="+IntegerToString((int)rbh1.zero_range_candles)+", insufficientBodyHistory="+IntegerToString((int)rbh1.insufficient_body_history)+", causalityViolations="+IntegerToString((int)rbh1.causality_violations),"RB_H1_BREAKOUT_VERIFY");
      g_logger.Info("preEventLongChecks="+IntegerToString((int)rbv.pre_event_long_checks)+", preEventShortChecks="+IntegerToString((int)rbv.pre_event_short_checks)+", preEventLongDistancePass="+IntegerToString((int)rbv.pre_event_long_distance_pass)+", preEventShortDistancePass="+IntegerToString((int)rbv.pre_event_short_distance_pass)+", sourceRangeInvalidatedOnBreakoutLong="+IntegerToString((int)rbv.source_range_invalidated_on_breakout_long)+", sourceRangeInvalidatedOnBreakoutShort="+IntegerToString((int)rbv.source_range_invalidated_on_breakout_short)+", breakoutsSurvivedExpectedRangeInvalidation="+IntegerToString((int)rbv.breakouts_survived_expected_range_invalidation),"RB_VERIFY_2");
      g_logger.Info("evaluations="+IntegerToString((int)rejectionv.evaluations)+", bullishEvaluations="+IntegerToString((int)rejectionv.bullish_evaluations)+", bearishEvaluations="+IntegerToString((int)rejectionv.bearish_evaluations)+", invalidCandles="+IntegerToString((int)rejectionv.invalid_candles)+", zoneIntersectionPass="+IntegerToString((int)rejectionv.zone_intersection_pass)+", directionPass="+IntegerToString((int)rejectionv.direction_pass)+", recoveryPass="+IntegerToString((int)rejectionv.recovery_pass)+", wickBodyPass="+IntegerToString((int)rejectionv.wick_body_pass)+", wickRangePass="+IntegerToString((int)rejectionv.wick_range_pass)+", bullishPasses="+IntegerToString((int)rejectionv.bullish_passes)+", bearishPasses="+IntegerToString((int)rejectionv.bearish_passes)+", totalPasses="+IntegerToString((int)rejectionv.total_passes)+", zeroBodyCandles="+IntegerToString((int)rejectionv.zero_body_candles)+", zeroRangeCandles="+IntegerToString((int)rejectionv.zero_range_candles)+", causalityViolations="+IntegerToString((int)rejectionv.causality_violations)+", duplicateEvaluationSuppressions="+IntegerToString((int)rejectionv.duplicate_evaluation_suppressions)+", avgBullishWickBodyRatio="+DoubleToString(rejectionv.average_bullish_wick_body_ratio,3)+", avgBearishWickBodyRatio="+DoubleToString(rejectionv.average_bearish_wick_body_ratio,3)+", avgBullishWickRangeRatio="+DoubleToString(rejectionv.average_bullish_wick_range_ratio,3)+", avgBearishWickRangeRatio="+DoubleToString(rejectionv.average_bearish_wick_range_ratio,3)+", maxBullishWickBodyRatio="+DoubleToString(rejectionv.maximum_bullish_wick_body_ratio,3)+", maxBearishWickBodyRatio="+DoubleToString(rejectionv.maximum_bearish_wick_body_ratio,3),"M15_REJECTION_VERIFY");
      g_logger.Info("candidatesReceived="+IntegerToString(rmrpv.candidates_received)+", entryWindowsReached="+IntegerToString(rmrpv.entry_windows_reached)+", plansValid="+IntegerToString(rmrpv.plans_valid)+", plansRejected="+IntegerToString(rmrpv.plans_rejected)+", rejectedRegime="+IntegerToString(rmrpv.rejected_regime)+", rejectedRangeInvalid="+IntegerToString(rmrpv.rejected_range_invalid)+", rejectedSourceZone="+IntegerToString(rmrpv.rejected_source_zone)+", rejectedSession="+IntegerToString(rmrpv.rejected_session)+", rejectedNews="+IntegerToString(rmrpv.rejected_news)+", rejectedPosition="+IntegerToString(rmrpv.rejected_position)+", rejectedBelow2R="+IntegerToString(rmrpv.rejected_below_2r)+", rejectedStop="+IntegerToString(rmrpv.rejected_stop)+", rejectedRisk="+IntegerToString(rmrpv.rejected_risk)+", rejectedManagement="+IntegerToString(rmrpv.rejected_management)+", rejectedOther="+IntegerToString(rmrpv.rejected_other)+", longPlans="+IntegerToString(rmrpv.long_plans)+", shortPlans="+IntegerToString(rmrpv.short_plans)+", duplicatePlans="+IntegerToString(rmrpv.duplicate_plans)+", planCausalityViolations="+IntegerToString(rmrpv.plan_causality_violations)+", avgAvailableR="+DoubleToString(rmrpv.average_available_r,3)+", minAvailableR="+DoubleToString(rmrpv.minimum_available_r,3)+", maxAvailableR="+DoubleToString(rmrpv.maximum_available_r,3),"RMR_PLAN_VERIFY");
      g_logger.Info("validPlansReceived="+IntegerToString(rmrev.valid_plans_received)+", executionAttempts="+IntegerToString(rmrev.execution_attempts)+", executionSuccesses="+IntegerToString(rmrev.execution_successes)+", executionFailures="+IntegerToString(rmrev.execution_failures)+", longAttempts="+IntegerToString(rmrev.long_attempts)+", shortAttempts="+IntegerToString(rmrev.short_attempts)+", rejectedPositionOpen="+IntegerToString(rmrev.rejected_position_open)+", rejectedQuote="+IntegerToString(rmrev.rejected_quote)+", rejectedStops="+IntegerToString(rmrev.rejected_stops)+", rejectedVolume="+IntegerToString(rmrev.rejected_volume)+", rejectedMargin="+IntegerToString(rmrev.rejected_margin)+", rejectedMarket="+IntegerToString(rmrev.rejected_market)+", rejectedOther="+IntegerToString(rmrev.rejected_other)+", duplicateExecutionAttempts="+IntegerToString(rmrev.duplicate_execution_attempts)+", successfulPositionsRegistered="+IntegerToString(rmrev.successful_positions_registered)+", metadataRegistrationFailures="+IntegerToString(rmrev.metadata_registration_failures),"RMR_EXEC_VERIFY");
      g_logger.Info("positionsManaged="+IntegerToString(rmrmv.positions_managed)+", managementChecks="+StringFormat("%I64u",rmrmv.management_checks)+", milestone2Reached="+IntegerToString(rmrmv.milestone_2_reached)+", higherMilestonesReached="+IntegerToString(rmrmv.higher_milestones_reached)+", slModifyAttempts="+IntegerToString(rmrmv.sl_modify_attempts)+", slModifySuccess="+IntegerToString(rmrmv.sl_modify_success)+", slModifyFailures="+IntegerToString(rmrmv.sl_modify_failures)+", brokerConstraintDeferrals="+IntegerToString(rmrmv.broker_constraint_deferrals)+", stopRegressionViolations="+IntegerToString(rmrmv.stop_regression_violations)+", invalidOriginalR="+IntegerToString(rmrmv.invalid_original_r)+", recoveredPositions="+IntegerToString(rmrmv.recovered_positions),"RMR_MANAGE_VERIFY");
      g_logger.Info("candidatesReceived="+IntegerToString(rbpv.candidates_received)+", entryWindowsReached="+IntegerToString(rbpv.entry_windows_reached)+", plansValid="+IntegerToString(rbpv.plans_valid)+", plansRejected="+IntegerToString(rbpv.plans_rejected)+", rejectedRegime="+IntegerToString(rbpv.rejected_regime)+", rejectedRangeContext="+IntegerToString(rbpv.rejected_range_context)+", rejectedSourceZone="+IntegerToString(rbpv.rejected_source_zone)+", rejectedTarget="+IntegerToString(rbpv.rejected_target)+", rejectedSession="+IntegerToString(rbpv.rejected_session)+", rejectedNews="+IntegerToString(rbpv.rejected_news)+", rejectedPosition="+IntegerToString(rbpv.rejected_position)+", rejectedBelow2R="+IntegerToString(rbpv.rejected_below_2r)+", rejectedStop="+IntegerToString(rbpv.rejected_stop)+", rejectedRisk="+IntegerToString(rbpv.rejected_risk)+", rejectedManagement="+IntegerToString(rbpv.rejected_management)+", rejectedOther="+IntegerToString(rbpv.rejected_other)+", longPlans="+IntegerToString(rbpv.long_plans)+", shortPlans="+IntegerToString(rbpv.short_plans)+", duplicatePlans="+IntegerToString(rbpv.duplicate_plans)+", planCausalityViolations="+IntegerToString(rbpv.plan_causality_violations)+", avgAvailableR="+DoubleToString(rbpv.average_available_r,3)+", minAvailableR="+DoubleToString(rbpv.minimum_available_r,3)+", maxAvailableR="+DoubleToString(rbpv.maximum_available_r,3),"RB_PLAN_VERIFY");
      g_logger.Info("validPlansReceived="+IntegerToString(rbev.valid_plans_received)+", executionAttempts="+IntegerToString(rbev.execution_attempts)+", executionSuccesses="+IntegerToString(rbev.execution_successes)+", executionFailures="+IntegerToString(rbev.execution_failures)+", longAttempts="+IntegerToString(rbev.long_attempts)+", shortAttempts="+IntegerToString(rbev.short_attempts)+", rejectedPositionOpen="+IntegerToString(rbev.rejected_position_open)+", rejectedQuote="+IntegerToString(rbev.rejected_quote)+", rejectedStops="+IntegerToString(rbev.rejected_stops)+", rejectedVolume="+IntegerToString(rbev.rejected_volume)+", rejectedRR="+IntegerToString(rbev.rejected_rr)+", rejectedMargin="+IntegerToString(rbev.rejected_margin)+", rejectedMarket="+IntegerToString(rbev.rejected_market)+", rejectedOther="+IntegerToString(rbev.rejected_other)+", duplicateExecutionAttempts="+IntegerToString(rbev.duplicate_execution_attempts)+", successfulPositionsRegistered="+IntegerToString(rbev.successful_positions_registered)+", metadataRegistrationFailures="+IntegerToString(rbev.metadata_registration_failures),"RB_EXEC_VERIFY");
      g_logger.Info("positionsManaged="+IntegerToString(rbmv.positions_managed)+", managementChecks="+StringFormat("%I64u",rbmv.management_checks)+", milestone2Reached="+IntegerToString(rbmv.milestone_2_reached)+", higherMilestonesReached="+IntegerToString(rbmv.higher_milestones_reached)+", slModifyAttempts="+IntegerToString(rbmv.sl_modify_attempts)+", slModifySuccess="+IntegerToString(rbmv.sl_modify_success)+", slModifyFailures="+IntegerToString(rbmv.sl_modify_failures)+", brokerConstraintDeferrals="+IntegerToString(rbmv.broker_constraint_deferrals)+", stopRegressionViolations="+IntegerToString(rbmv.stop_regression_violations)+", invalidOriginalR="+IntegerToString(rbmv.invalid_original_r)+", recoveredPositions="+IntegerToString(rbmv.recovered_positions),"RB_MANAGE_VERIFY");
      g_logger.Info("h1Bars="+IntegerToString((int)g.h1_bars)+", uptrend="+IntegerToString((int)g.uptrend)+", eligible="+IntegerToString((int)g.eligible)+", resistanceBars="+IntegerToString((int)g.resistance_bar)+", resistanceObs="+IntegerToString((int)g.resistance_observations)+", checks="+IntegerToString((int)g.resistance_checks)+", aboveEdge="+IntegerToString((int)g.above_edge)+", distancePass="+IntegerToString((int)g.distance_long)+", accepted="+IntegerToString(v.break_long),"TCV2_GATE_LONG");
      g_logger.Info("h1Bars="+IntegerToString((int)g.h1_bars)+", downtrend="+IntegerToString((int)g.downtrend)+", eligible="+IntegerToString((int)g.eligible)+", supportBars="+IntegerToString((int)g.support_bar)+", supportObs="+IntegerToString((int)g.support_observations)+", checks="+IntegerToString((int)g.support_checks)+", belowEdge="+IntegerToString((int)g.below_edge)+", distancePass="+IntegerToString((int)g.distance_short)+", accepted="+IntegerToString(v.break_short),"TCV2_GATE_SHORT");
      g_logger.Info("h1Bars="+IntegerToString((int)g.h1_bars)+", zero="+IntegerToString((int)g.zero_zone)+", nonzero="+IntegerToString((int)g.nonzero_zone)+", maxZones="+IntegerToString((int)g.max_zones)+", maxSupport="+IntegerToString((int)g.max_support)+", maxResistance="+IntegerToString((int)g.max_resistance),"TCV2_ZONE_SUPPLY");
      g_logger.Info("created_support="+IntegerToString(z.created_support)+", created_resistance="+IntegerToString(z.created_resistance)+", invalidated_support="+IntegerToString(z.invalidated_support)+", invalidated_resistance="+IntegerToString(z.invalidated_resistance)+", active_support_end="+IntegerToString(z.active_support_end)+", active_resistance_end="+IntegerToString(z.active_resistance_end),"H1ZV2_VERIFY");
      g_logger.Info("highs="+IntegerToString(rg.confirmed_swing_highs)+", lows="+IntegerToString(rg.confirmed_swing_lows)+", highDepartures="+IntegerToString(rg.qualified_high_departures)+", lowDepartures="+IntegerToString(rg.qualified_low_departures)+", highPriorChecks="+IntegerToString(rg.high_prior_candidates_checked)+", lowPriorChecks="+IntegerToString(rg.low_prior_candidates_checked)+", highSeparationPass="+IntegerToString(rg.high_separation_pass)+", lowSeparationPass="+IntegerToString(rg.low_separation_pass)+", highClusterPass="+IntegerToString(rg.high_cluster_pass)+", lowClusterPass="+IntegerToString(rg.low_cluster_pass)+", resistanceCreated="+IntegerToString(rg.resistance_created)+", supportCreated="+IntegerToString(rg.support_created),"H1ZV2_ROLE_GATE");
      g_logger.Info("currentHigh="+IntegerToString(dw.current_high)+", currentLow="+IntegerToString(dw.current_low)+", pivotWindowHigh="+IntegerToString(dw.pivot_window_high)+", pivotWindowLow="+IntegerToString(dw.pivot_window_low),"H1ZV2_DEPARTURE_WINDOW");
      g_logger.Info("highs="+IntegerToString(dm.highs)+", high025="+IntegerToString(dm.high_025)+", high050="+IntegerToString(dm.high_050)+", high075="+IntegerToString(dm.high_075)+", high100="+IntegerToString(dm.high_100)+", high125="+IntegerToString(dm.high_125)+", highAvg="+DoubleToString(dm.high_average,3)+", highMedian="+DoubleToString(dm.high_median,3)+", highMax="+DoubleToString(dm.high_max,3)+", lows="+IntegerToString(dm.lows)+", low025="+IntegerToString(dm.low_025)+", low050="+IntegerToString(dm.low_050)+", low075="+IntegerToString(dm.low_075)+", low100="+IntegerToString(dm.low_100)+", low125="+IntegerToString(dm.low_125)+", lowAvg="+DoubleToString(dm.low_average,3)+", lowMedian="+DoubleToString(dm.low_median,3)+", lowMax="+DoubleToString(dm.low_max,3),"H1ZV2_DEPARTURE_MAG");
      if(dm.highs>0){g_logger.Info("rank=greatest, "+E2H1DepartureSampleText(dm.high_greatest),"H1ZV2_HIGH_SAMPLE");g_logger.Info("rank=median, "+E2H1DepartureSampleText(dm.high_median_sample),"H1ZV2_HIGH_SAMPLE");g_logger.Info("rank=smallest, "+E2H1DepartureSampleText(dm.high_smallest),"H1ZV2_HIGH_SAMPLE");}
      if(dm.lows>0){g_logger.Info("rank=greatest, "+E2H1DepartureSampleText(dm.low_greatest),"H1ZV2_LOW_SAMPLE");g_logger.Info("rank=median, "+E2H1DepartureSampleText(dm.low_median_sample),"H1ZV2_LOW_SAMPLE");g_logger.Info("rank=smallest, "+E2H1DepartureSampleText(dm.low_smallest),"H1ZV2_LOW_SAMPLE");}
      g_logger.Info("supportCreatedRun="+IntegerToString(life.support_created)+", resistanceCreatedRun="+IntegerToString(life.resistance_created)+", supportInvalidatedRun="+IntegerToString(life.support_invalidated)+", resistanceInvalidatedRun="+IntegerToString(life.resistance_invalidated)+", supportBars="+IntegerToString(life.support_bars)+", resistanceBars="+IntegerToString(life.resistance_bars)+", lookbackExpiryObserved="+E2YesNo(life.lookback_expiry_observed),"H1ZV2_LIFETIME");
      g_logger.Info("insertedSupport="+IntegerToString(pd.inserted_support)+", insertedResistance="+IntegerToString(pd.inserted_resistance)+", initializedSupport="+IntegerToString(pd.initialized_support)+", initializedResistance="+IntegerToString(pd.initialized_resistance)+", invalidatedSupport="+IntegerToString(pd.invalidated_support)+", invalidatedResistance="+IntegerToString(pd.invalidated_resistance)+", rediscoveries="+IntegerToString(pd.duplicate_rediscoveries)+", resurrectionAttempts="+IntegerToString(pd.resurrection_attempts)+", survivedSourceLookbackExpiry="+IntegerToString(pd.survived_source_lookback_expiry)+", maxActive="+IntegerToString(pd.max_active)+", maxTotal="+IntegerToString(pd.max_total)+", creationCausalityViolations="+IntegerToString(pd.creation_causality_violations)+", invalidationBeforeCreation="+IntegerToString(pd.invalidation_before_creation)+", duplicateActiveIds="+IntegerToString(pd.duplicate_active_ids)+", disappearedWithoutInvalidation="+IntegerToString(pd.disappeared_without_invalidation),"H1ZV2_PERSISTENT");
      g_logger.Info("h4Calls="+StringFormat("%I64u",g_v2_h4_calls)+", h1Calls="+StringFormat("%I64u",g_v2_h1_calls)+", m15StandaloneCalls="+StringFormat("%I64u",g_v2_m15_calls)+", standaloneContexts="+StringFormat("%I64u",g_v2_m15_contexts)+", tcConfirmationContexts="+IntegerToString((int)g.confirmation_contexts)+", m15CandidateCalcs="+StringFormat("%I64u",g_m15_confirmation_engine.MeasurementCount())+", tcCalls="+IntegerToString((int)g.tc_calls)+", activeStates="+IntegerToString((int)g.active_state_evaluations)+", persistentLookupChecks="+StringFormat("%I64u",pw.persistent_lookup_checks)+", persistentActiveInvalidationChecks="+StringFormat("%I64u",pw.persistent_active_invalidation_checks)+", persistentTerminalChecks="+StringFormat("%I64u",pw.persistent_terminal_checks)+", activeZoneExports="+StringFormat("%I64u",pw.active_zone_exports)+", tcH1BreakoutZoneChecks="+StringFormat("%I64u",g.h1_breakout_zone_checks)+", tcM15StateChecks="+StringFormat("%I64u",g.m15_state_checks)+", tcRecordLookupChecks="+StringFormat("%I64u",g.record_lookup_checks)+", rediscoveryFastHits="+StringFormat("%I64u",pw.rediscovery_fast_hits),"V2_WORKLOAD");
      g_logger.Info("breakouts_long="+IntegerToString(v.break_long)+", breakouts_short="+IntegerToString(v.break_short)+", retests_long="+IntegerToString(v.retest_long)+", retests_short="+IntegerToString(v.retest_short)+", candidates_long="+IntegerToString(v.candidate_long)+", candidates_short="+IntegerToString(v.candidate_short)+", duplicates_suppressed="+IntegerToString(v.duplicate_suppressed)+", duplicate_candidates="+IntegerToString(v.duplicate_candidates),"TCV2_VERIFY");
      g_logger.Info("confirmations_long="+IntegerToString(v.confirm_long)+", confirmations_short="+IntegerToString(v.confirm_short)+", total_candidates="+IntegerToString(v.total)+", unique_zone_attempts="+IntegerToString(v.unique_attempts)+", invalid_h4_loss="+IntegerToString(v.h4_loss)+", invalid_h4_overextension="+IntegerToString(v.h4_overextended)+", invalid_flipped_zone="+IntegerToString(v.flipped_invalid)+", multiple_claimant_timestamps="+IntegerToString(v.confirmation_timestamps_with_multiple_claimants)+", max_claimants="+IntegerToString(v.maximum_claimants_one_confirmation)+", ownership_resolutions="+IntegerToString(v.ownership_resolutions)+", same_confirmation_multiple_candidates="+IntegerToString(v.same_confirmation_multiple_candidates)+", causal_order_violations="+IntegerToString(v.causal_order_violations),"TCV2_VERIFY");
      g_logger.Info("candidatesReceived="+IntegerToString(pv.candidates_received)+", entryWindowsReached="+IntegerToString(pv.entry_windows_reached)+", plansValid="+IntegerToString(pv.plans_valid)+", plansRejected="+IntegerToString(pv.plans_rejected)+", rejectedRegime="+IntegerToString(pv.rejected_regime)+", rejectedOverextension="+IntegerToString(pv.rejected_overextension)+", rejectedZone="+IntegerToString(pv.rejected_zone)+", rejectedSession="+IntegerToString(pv.rejected_session)+", rejectedNews="+IntegerToString(pv.rejected_news)+", rejectedPosition="+IntegerToString(pv.rejected_position)+", rejectedNoTarget="+IntegerToString(pv.rejected_no_target)+", rejectedBelow2R="+IntegerToString(pv.rejected_below_2r)+", rejectedStop="+IntegerToString(pv.rejected_stop)+", rejectedRisk="+IntegerToString(pv.rejected_risk)+", rejectedManagement="+IntegerToString(pv.rejected_management)+", rejectedOther="+IntegerToString(pv.rejected_other)+", fixed2RPlans="+IntegerToString(pv.fixed_2r_plans)+", zoneTrailingPlans="+IntegerToString(pv.zone_trailing_plans)+", longPlans="+IntegerToString(pv.long_plans)+", shortPlans="+IntegerToString(pv.short_plans)+", duplicatePlans="+IntegerToString(pv.duplicate_plans)+", planCausalityViolations="+IntegerToString(pv.plan_causality_violations)+", avgAvailableR="+DoubleToString(pv.average_available_r,3)+", medianAvailableR="+DoubleToString(pv.median_available_r,3)+", minAvailableR="+DoubleToString(pv.minimum_available_r,3)+", maxAvailableR="+DoubleToString(pv.maximum_available_r,3),"TCV2_PLAN_VERIFY");
      g_logger.Info("validPlansReceived="+IntegerToString(ev.valid_plans_received)+", executionDisabled="+IntegerToString(ev.execution_disabled)+", executionAttempts="+IntegerToString(ev.execution_attempts)+", executionSuccesses="+IntegerToString(ev.execution_successes)+", executionFailures="+IntegerToString(ev.execution_failures)+", longAttempts="+IntegerToString(ev.long_attempts)+", shortAttempts="+IntegerToString(ev.short_attempts)+", fixed2RAttempts="+IntegerToString(ev.fixed_2r_attempts)+", zoneTrailingAttempts="+IntegerToString(ev.zone_trailing_attempts)+", rejectedPositionOpen="+IntegerToString(ev.rejected_position_open)+", rejectedQuote="+IntegerToString(ev.rejected_quote)+", rejectedStops="+IntegerToString(ev.rejected_stops)+", rejectedVolume="+IntegerToString(ev.rejected_volume)+", rejectedRR="+IntegerToString(ev.rejected_rr)+", rejectedMargin="+IntegerToString(ev.rejected_margin)+", rejectedMarket="+IntegerToString(ev.rejected_market)+", rejectedOther="+IntegerToString(ev.rejected_other)+", duplicateExecutionAttempts="+IntegerToString(ev.duplicate_execution_attempts)+", successfulPositionsRegistered="+IntegerToString(ev.successful_positions_registered)+", metadataRegistrationFailures="+IntegerToString(ev.metadata_registration_failures)+", unaccountedValidPlans="+IntegerToString(ev.unaccounted_valid_plans)+", executionCausalityViolations="+IntegerToString(ev.execution_causality_violations)+", avgPlannedToQuoteDifference="+DoubleToString(ev.average_planned_to_quote_difference,_Digits)+", avgQuoteToFillSlippage="+DoubleToString(ev.average_quote_to_fill_slippage,_Digits)+", avgActualRiskCash="+DoubleToString(ev.average_actual_risk_cash,2)+", maxActualRiskDeviationPct="+DoubleToString(ev.max_actual_risk_deviation_percent,4),"V2_EXEC_VERIFY");
      g_logger.Info("positionsManaged="+IntegerToString(mv.positions_managed)+", fixed2RPositionsObserved="+IntegerToString(mv.fixed_2r_positions_observed)+", trailingPositionsManaged="+IntegerToString(mv.trailing_positions_managed)+", managementChecks="+StringFormat("%I64u",mv.management_checks)+", milestone2Reached="+IntegerToString(mv.milestone_2_reached)+", higherMilestonesReached="+IntegerToString(mv.higher_milestones_reached)+", slModifyAttempts="+IntegerToString(mv.sl_modify_attempts)+", slModifySuccess="+IntegerToString(mv.sl_modify_success)+", slModifyFailures="+IntegerToString(mv.sl_modify_failures)+", brokerConstraintDeferrals="+IntegerToString(mv.broker_constraint_deferrals)+", duplicateModifySuppressed="+IntegerToString(mv.duplicate_modify_suppressed)+", stopRegressionViolations="+IntegerToString(mv.stop_regression_violations)+", invalidOriginalR="+IntegerToString(mv.invalid_original_r)+", recoveredPositions="+IntegerToString(mv.recovered_positions),"TCV2_MANAGE_VERIFY");
      g_logger.Info("positionsManaged="+IntegerToString(global_mv.positions_managed)+", fixed2RPositionsObserved="+IntegerToString(global_mv.fixed_2r_positions_observed)+", trailingPositionsManaged="+IntegerToString(global_mv.trailing_positions_managed)+", managementChecks="+StringFormat("%I64u",global_mv.management_checks)+", milestone2Reached="+IntegerToString(global_mv.milestone_2_reached)+", higherMilestonesReached="+IntegerToString(global_mv.higher_milestones_reached)+", slModifyAttempts="+IntegerToString(global_mv.sl_modify_attempts)+", slModifySuccess="+IntegerToString(global_mv.sl_modify_success)+", slModifyFailures="+IntegerToString(global_mv.sl_modify_failures)+", brokerConstraintDeferrals="+IntegerToString(global_mv.broker_constraint_deferrals)+", duplicateModifySuppressed="+IntegerToString(global_mv.duplicate_modify_suppressed)+", stopRegressionViolations="+IntegerToString(global_mv.stop_regression_violations)+", invalidOriginalR="+IntegerToString(global_mv.invalid_original_r)+", recoveredPositions="+IntegerToString(global_mv.recovered_positions),"V2_MANAGE_VERIFY");
     }
   g_trade_reporter.Reconcile();
   if(g_environment.IsTester() && g_configuration.research_verification_summary)
     {
      const E2TrendContinuationVerification v2_only_candidates=g_trend_continuation_engine.Verification();
      const E2V2PlanVerification v2_only_plans=g_v2_trade_plan_engine.Verification();
      const E2V2ExecutionVerification v2_only_execution=g_v2_execution_engine.Verification();
      const E2RMRExecutionVerification rmr_only_execution=g_v2_execution_engine.RMRVerification();
      const E2RBExecutionVerification rb_only_execution=g_v2_execution_engine.RBVerification();
      g_logger.Info("legacyStrategyCalls=0, legacySignals=0, legacyPlans=0, legacyExecutionAttempts=0, legacyFinalizedTrades=0, v2Candidates="+IntegerToString(v2_only_candidates.total)+", v2Plans="+IntegerToString(v2_only_plans.plans_valid)+", v2ExecutionAttempts="+IntegerToString(v2_only_execution.execution_attempts-rmr_only_execution.execution_attempts-rb_only_execution.execution_attempts)+", v2ExecutionSuccesses="+IntegerToString(v2_only_execution.execution_successes-rmr_only_execution.execution_successes-rb_only_execution.execution_successes)+", reportingForeignTrades=0","V2_ONLY");
     }
   const int unresolved=g_trade_reporter.ReportUnresolved();
   E2ReportedTrade finalized_trades[];
   g_trade_reporter.FinalizedTrades(finalized_trades);
   const E2TrendContinuationVerification tc_summary_candidates=g_trend_continuation_engine.Verification();
   const E2V2PlanVerification tc_summary_plans=g_v2_trade_plan_engine.Verification();
   const E2V2ExecutionVerification tc_summary_execution=g_v2_execution_engine.Verification();
   const E2RangeMeanReversionVerification rmr_summary_candidates=g_range_mean_reversion_engine.Verification();
   const E2RMRPlanVerification rmr_summary_plans=g_v2_trade_plan_engine.RMRVerification();
   const E2RMRExecutionVerification rmr_summary_execution=g_v2_execution_engine.RMRVerification();
   const E2RangeBreakoutVerification rb_summary_candidates=g_range_breakout_engine.Verification();
   const E2RBPlanVerification rb_summary_plans=g_v2_trade_plan_engine.RBVerification();
   const E2RBExecutionVerification rb_summary_execution=g_v2_execution_engine.RBVerification();
   int tc_finalized=0,rmr_finalized=0,rb_finalized=0,cross_setup_contamination=0;
   for(int report_trade=0;report_trade<ArraySize(finalized_trades);report_trade++){if(finalized_trades[report_trade].entry.strategy_type=="TREND_CONTINUATION")tc_finalized++;else if(finalized_trades[report_trade].entry.strategy_type=="RANGE_MEAN_REVERSION")rmr_finalized++;else if(finalized_trades[report_trade].entry.strategy_type=="RANGE_BREAKOUT")rb_finalized++;else cross_setup_contamination++;}
   const int tc_execution_attempts=tc_summary_execution.execution_attempts-rmr_summary_execution.execution_attempts-rb_summary_execution.execution_attempts,tc_execution_successes=tc_summary_execution.execution_successes-rmr_summary_execution.execution_successes-rb_summary_execution.execution_successes;
   const int tc_unresolved=g_trade_reporter.UnresolvedForSetup("TREND_CONTINUATION"),rmr_unresolved=g_trade_reporter.UnresolvedForSetup("RANGE_MEAN_REVERSION"),rb_unresolved=g_trade_reporter.UnresolvedForSetup("RANGE_BREAKOUT");
   if(g_environment.IsTester() && g_configuration.research_verification_summary)
     {
      g_logger.Info("candidates="+IntegerToString(tc_summary_candidates.total)+", plannerCandidates="+IntegerToString(tc_summary_plans.candidates_received)+", validPlans="+IntegerToString(tc_summary_plans.plans_valid)+", executionPlans="+IntegerToString(tc_summary_execution.valid_plans_received-rmr_summary_execution.valid_plans_received-rb_summary_execution.valid_plans_received)+", executionAttempts="+IntegerToString(tc_execution_attempts)+", executionSuccesses="+IntegerToString(tc_execution_successes)+", finalizedTrades="+IntegerToString(tc_finalized)+", unresolved="+IntegerToString(tc_unresolved)+", crossSetupContamination="+IntegerToString(cross_setup_contamination)+", "+g_trade_reporter.InvariantSummary(),"TC_REPORT_VERIFY");
      g_logger.Info("candidates="+IntegerToString(rmr_summary_candidates.total_candidates)+", plannerCandidates="+IntegerToString(rmr_summary_plans.candidates_received)+", validPlans="+IntegerToString(rmr_summary_plans.plans_valid)+", executionPlans="+IntegerToString(rmr_summary_execution.valid_plans_received)+", executionAttempts="+IntegerToString(rmr_summary_execution.execution_attempts)+", executionSuccesses="+IntegerToString(rmr_summary_execution.execution_successes)+", finalizedTrades="+IntegerToString(rmr_finalized)+", unresolved="+IntegerToString(rmr_unresolved)+", duplicateEntriesSuppressed="+IntegerToString(g_trade_reporter.DuplicateEntriesSuppressed())+", duplicateFinalizedRows=0, crossSetupContamination="+IntegerToString(cross_setup_contamination)+", invalidOriginalR="+IntegerToString(g_trade_reporter.InvalidOriginalR())+", impossibleRealizedR="+IntegerToString(g_trade_reporter.ImpossibleRealizedR()),"RMR_REPORT_VERIFY");
      g_logger.Info("reportCausalityViolations="+IntegerToString(g_trade_reporter.ReportCausalityViolations("TREND_CONTINUATION"))+", setupIdentityFailures="+IntegerToString(g_trade_reporter.SetupIdentityFailures("TREND_CONTINUATION"))+", duplicateFinalizedRows="+IntegerToString(g_trade_reporter.DuplicateFinalizedTradeIds("TREND_CONTINUATION"))+", invalidStructuralStop="+IntegerToString(g_trade_reporter.InvalidStructuralStop("TREND_CONTINUATION"))+", structuralStopAdjustedByBroker="+IntegerToString(g_trade_reporter.StructuralStopAdjustedByBroker("TREND_CONTINUATION")),"TC_REPORT_VERIFY_2");
      g_logger.Info("reportCausalityViolations="+IntegerToString(g_trade_reporter.ReportCausalityViolations("RANGE_MEAN_REVERSION"))+", setupIdentityFailures="+IntegerToString(g_trade_reporter.SetupIdentityFailures("RANGE_MEAN_REVERSION"))+", duplicateFinalizedRows="+IntegerToString(g_trade_reporter.DuplicateFinalizedTradeIds("RANGE_MEAN_REVERSION"))+", invalidStructuralStop="+IntegerToString(g_trade_reporter.InvalidStructuralStop("RANGE_MEAN_REVERSION"))+", structuralStopAdjustedByBroker="+IntegerToString(g_trade_reporter.StructuralStopAdjustedByBroker("RANGE_MEAN_REVERSION")),"RMR_REPORT_VERIFY_2");
      g_logger.Info("candidates="+IntegerToString((int)rb_summary_candidates.total_candidates)+", plannerCandidates="+IntegerToString(rb_summary_plans.candidates_received)+", validPlans="+IntegerToString(rb_summary_plans.plans_valid)+", executionPlans="+IntegerToString(rb_summary_execution.valid_plans_received)+", executionAttempts="+IntegerToString(rb_summary_execution.execution_attempts)+", executionSuccesses="+IntegerToString(rb_summary_execution.execution_successes)+", finalizedTrades="+IntegerToString(rb_finalized)+", unresolved="+IntegerToString(rb_unresolved)+", duplicateEntriesSuppressed="+IntegerToString(g_trade_reporter.DuplicateEntriesSuppressed())+", duplicateFinalizedRows="+IntegerToString(g_trade_reporter.DuplicateFinalizedTradeIds("RANGE_BREAKOUT"))+", crossSetupContamination="+IntegerToString(cross_setup_contamination)+", invalidOriginalR="+IntegerToString(g_trade_reporter.InvalidOriginalR("RANGE_BREAKOUT"))+", impossibleRealizedR="+IntegerToString(g_trade_reporter.ImpossibleRealizedR("RANGE_BREAKOUT")),"RB_REPORT_VERIFY");
      g_logger.Info("reportCausalityViolations="+IntegerToString(g_trade_reporter.ReportCausalityViolations("RANGE_BREAKOUT"))+", setupIdentityFailures="+IntegerToString(g_trade_reporter.SetupIdentityFailures("RANGE_BREAKOUT"))+", duplicateFinalizedRows="+IntegerToString(g_trade_reporter.DuplicateFinalizedTradeIds("RANGE_BREAKOUT"))+", invalidStructuralStop="+IntegerToString(g_trade_reporter.InvalidStructuralStop("RANGE_BREAKOUT"))+", structuralStopAdjustedByBroker="+IntegerToString(g_trade_reporter.StructuralStopAdjustedByBroker("RANGE_BREAKOUT"))+", missingRangeIdentity="+IntegerToString(g_trade_reporter.MissingRangeIdentity("RANGE_BREAKOUT"))+", missingCandidateIdentity="+IntegerToString(g_trade_reporter.MissingCandidateIdentity("RANGE_BREAKOUT"))+", missingPlanIdentity="+IntegerToString(g_trade_reporter.MissingPlanIdentity("RANGE_BREAKOUT"))+", missingTargetIdentity="+IntegerToString(g_trade_reporter.MissingTargetIdentity("RANGE_BREAKOUT")),"RB_REPORT_VERIFY_2");
     }
   for(int visual_trade=0;visual_trade<ArraySize(finalized_trades);visual_trade++) g_visualizer.DrawFinal(finalized_trades[visual_trade]);
   g_visualizer.ReportFocusNotFound();
   g_backtest_summary.FinalizeSetup(g_environment.IsTester(),"TREND_CONTINUATION",finalized_trades,tc_unresolved,tc_summary_candidates.total,tc_summary_plans.entry_windows_reached,tc_summary_plans.plans_valid,tc_execution_attempts,tc_execution_successes);
   g_backtest_summary.FinalizeSetup(g_environment.IsTester(),"RANGE_MEAN_REVERSION",finalized_trades,rmr_unresolved,(int)rmr_summary_candidates.total_candidates,rmr_summary_plans.entry_windows_reached,rmr_summary_plans.plans_valid,rmr_summary_execution.execution_attempts,rmr_summary_execution.execution_successes);
   g_backtest_summary.FinalizeSetup(g_environment.IsTester(),"RANGE_BREAKOUT",finalized_trades,rb_unresolved,(int)rb_summary_candidates.total_candidates,rb_summary_plans.entry_windows_reached,rb_summary_plans.plans_valid,rb_summary_execution.execution_attempts,rb_summary_execution.execution_successes);
   g_backtest_summary.Close();
   g_trade_reporter.Close();
   g_visualizer.Cleanup();
   g_logger.Info("Run completed: symbol="+_Symbol+", environment="+g_environment.Name()+", ticks="+StringFormat("%I64u",g_diagnostic_tick_count)+", reason="+IntegerToString(reason)+".","Lifecycle");
   g_logger.Info("E2 deinitialized.","Lifecycle");
  }
//+------------------------------------------------------------------+
//| Native trade transaction callback                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD)
     {
      g_trade_reporter.OnDeal(trans.deal);
      E2ReportedTrade finalized[];
      g_trade_reporter.FinalizedTrades(finalized);
      for(int visual_trade=0;visual_trade<ArraySize(finalized);visual_trade++) g_visualizer.DrawFinal(finalized[visual_trade]);
     }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_diagnostic_tick_count++;
   g_v2_position_manager.Check();
   E2RunH4RegimeV2();
   E2RunH1ZoneV2();
   E2RunM15ConfirmationV2();
   E2RunRangeMeanReversion();
   E2RunRangeBreakout();
   E2RunTrendContinuationV2();
  }
//+------------------------------------------------------------------+
