#ifndef E2_CORE_E2CONFIG_MQH
#define E2_CORE_E2CONFIG_MQH

#include "..\\strategy\\E2ResearchTypes.mqh"

// External EA inputs are intentionally kept here. Future modules receive the
// E2Config structure instead of depending on these input variables directly.

enum E2RiskBase
  {
   E2_RISK_BASE_BALANCE,
   E2_RISK_BASE_EQUITY
  };

enum E2VisualAuditMode
  {
   E2_VISUAL_STRATEGY_AUDIT=0,
   E2_VISUAL_ALL_TRADES=1,
   E2_VISUAL_SINGLE_TRADE=2
  };

input group "GENERAL"
input ulong InpExpertMagicNumber = 2026001; // Identifier reserved for E2 orders.
input bool  InpTradingEnabled   = true;    // Master switch for future trade execution.
input bool  InpDebugMode        = false;   // Enables future diagnostic output.

input group "V1.1 ALPHA STRATEGY FRAMEWORK"
input bool InpEnableTrendContinuation = true;
input bool InpEnableRangeMeanReversion = false;
input bool InpEnableRangeBreakout = false;

input group "V1.1 ALPHA MANAGEMENT FRAMEWORK"
input bool InpEnableFixed2RManagement = true;
input bool InpEnableZoneTargetTrailingManagement = false;

input group "V1.1 ALPHA H4 RESEARCH (INERT)"
input int InpResearchH4EmaFastPeriod = 20;
input int InpResearchH4EmaSlowPeriod = 50;
input int InpResearchH4EmaSlopeLookback = 5;
input int InpResearchH4AtrPeriod = 14;
input double InpResearchH4StructuralBreakoutDistanceAtr = 0.10;
input double InpResearchH4TrendExtensionLimitAtr = 1.50;

input group "V1.1 ALPHA RANGE RESEARCH (INERT)"
input double InpResearchRangeClusterVariationMaximumAtr = 0.50;
input double InpResearchRangeMinimumHeightAtr = 3.00;
input double InpResearchRangeEma50FlatnessMaximumAtr = 0.10;
input double InpResearchRangeBoundaryInvalidationAtr = 0.25;
input double InpResearchRangeOuterEntryRegionFraction = 0.20;

input group "TIMEFRAMES"
input ENUM_TIMEFRAMES InpTrendTimeframe        = PERIOD_H4;  // H4 market structure timeframe.
input ENUM_TIMEFRAMES InpZoneTimeframe         = PERIOD_H1;  // H1 support/resistance timeframe.
input ENUM_TIMEFRAMES InpConfirmationTimeframe = PERIOD_M15; // M15 entry-confirmation timeframe.

input group "TREND / RANGE"
input int  InpSwingSensitivity = 3;    // Closed bars required on each side to confirm an H4 pivot.
input int  InpTrendStructureLookbackBars = 80; // Closed trend-timeframe bars used for confirmed-pivot structure.
input bool InpAdxEnabled        = true; // Use ADX in the future trend/range classifier.
input int  InpAdxPeriod         = 14;   // ADX calculation period.
input double InpAdxMinimumThreshold = 20.0; // Provisional ADX trend-strength threshold; finalized in Sprint 1.2.

input group "SUPPORT / RESISTANCE"
input int    InpMinimumZoneTouches     = 2;   // Minimum H1 reactions required to form a zone.
input int    InpZoneLookbackBars        = 240; // Closed H1 bars used for deterministic zone analysis.
input double InpZoneTolerancePips       = 5.0; // Price-reaction tolerance, expressed in pips.
input double InpZoneMergeTolerancePips  = 5.0; // Nearby-zone merge tolerance, expressed in pips.
input double InpStopLossZoneBufferPips  = 2.0; // Future stop buffer beyond a zone, expressed in pips.

input group "V1.1 ALPHA H1 RESEARCH (INERT)"
input int InpResearchH1AtrPeriod = 14;
input double InpResearchH1ZonePivotClusteringAtr = 0.50;
input int InpResearchH1MinimumTouchSeparationBars = 3;
input double InpResearchH1MinimumPostTouchDepartureAtr = 1.00;
input double InpResearchH1ZoneInvalidationAtr = 0.10;
input double InpResearchH1BreakoutDistanceAtr = 0.10;
input int InpResearchH1BreakoutBodyLookback = 20;
input double InpResearchH1BreakoutBodyMultiplier = 1.25;
input double InpResearchH1BreakoutBodyRangeMinimum = 0.60;
input double InpResearchH1BreakoutClosingLocationFraction = 0.20;
input int InpResearchH1BreakoutRetestExpiryBars = 12;
input double InpResearchH1BreakoutInvalidationDepthAtr = 0.10;
input double InpResearchH1ZoneRearmDistanceAtr = 0.50;

input group "CONFIRMATIONS"
input bool InpEnableEngulfingConfirmation           = true; // Enable future engulfing-candle confirmation.
input bool InpEnablePinBarConfirmation              = true; // Enable future pin-bar confirmation.
input bool InpEnableMomentumCandleConfirmation      = true; // Enable future momentum-candle confirmation.
input bool InpEnableBreakPreviousCandleConfirmation = true; // Enable future previous-candle-break confirmation.
input double InpPinBarMinimumWickToBodyRatio = 2.0; // Provisional minimum dominant-wick/body ratio.
input double InpPinBarMaximumOppositeWickToBodyRatio = 1.0; // Provisional maximum opposite-wick/body ratio.
input int InpMomentumBodyLookback = 20; // Prior closed M15 bodies used as momentum context.
input double InpMomentumBodyMultiplier = 1.5; // Provisional body-size multiple of prior average.

input group "V1.1 ALPHA M15 RESEARCH (INERT)"
input int InpResearchM15BodyMedianLookback = 20;
input double InpResearchM15MomentumBodyMultiplier = 1.25;
input double InpResearchM15MomentumBodyRangeMinimum = 0.60;
input double InpResearchM15MomentumClosingLocationFraction = 0.20;
input double InpResearchM15RejectionWickBodyMinimum = 1.50;
input double InpResearchM15RejectionWickRangeMinimum = 0.40;

input group "RISK"
input double InpRiskPercent         = 1.0; // Risk per trade as a percentage of the final selected risk base.
input double InpRewardRiskTarget    = 2.0; // Take-profit target expressed as reward-to-risk (R).
input E2RiskBase InpRiskBase         = E2_RISK_BASE_EQUITY; // E2 trade planning uses account equity as its risk base.

input group "EXECUTION"
input double InpMaxEntryDeviationPips = 2.0;  // Reject plans whose market price has moved farther than this distance.
input bool   InpExecutionTestEnabled  = false; // Explicit one-attempt test harness; restricted to tester/demo environments.
input double InpMaxSpreadPips          = 3.0;  // Provisional broker-generic spread ceiling; set to zero to disable this filter.
input int    InpMaxQuoteAgeSeconds     = 10;   // Reject quotes older than this; set to zero to disable the age check.
input int    InpMinimumSecondsBetweenExecutions = 5; // Generic new-order cooldown after a successful execution.

input group "SESSIONS"
input bool InpEnableLondonSession   = true; // Allow future entries during the London session.
input bool InpEnableNewYorkSession  = true; // Allow future entries during the New York session.
input int  InpBrokerUtcOffsetHours  = 999;  // Required server/source UTC offset (-14..14); 999 disables session eligibility until configured.
input int  InpLondonSessionStartHour = 8;   // London local session start, inclusive.
input int  InpLondonSessionEndHour   = 17;  // London local session end, exclusive.
input int  InpNewYorkSessionStartHour = 8;  // New York local session start, inclusive.
input int  InpNewYorkSessionEndHour   = 17; // New York local session end, exclusive.
input bool InpSessionDiagnosticsEnabled = false; // Emit concise deterministic session/DST examples when debug logging is enabled.

input group "NEWS"
input bool InpNewsFilterEnabled          = true; // Enable deterministic historical-news entry exclusion.
input int  InpHighImpactBufferBeforeMins = 30;   // Minutes to exclude before a scheduled event, inclusive.
input int  InpHighImpactBufferAfterMins  = 30;   // Minutes to exclude after a scheduled event, inclusive.
input bool InpNewsHighImpactOnly          = true; // When false, all recognized event impacts are blocking.
input string InpNewsDataFile              = "E2_news_events.csv"; // FILE_COMMON CSV; schema is documented in E2NewsFilter.mqh.
input bool InpNewsDiagnosticsEnabled      = false; // Emit concise data-load diagnostics when debug logging is enabled.

input group "REPORTING"
input bool InpLoggingEnabled   = true;  // Enable future strategy-independent logging.
input bool InpCsvExportEnabled = false; // Enable future CSV export.

input group "VISUALIZATION"
input bool InpVisualModeEnabled = true; // Audit-only MT5 Strategy Tester Visual Mode overlay.
input bool InpVisualShowZones = true;
input bool InpVisualShowTrendPanel = true;
input bool InpVisualShowConfirmations = true;
input bool InpVisualShowTrades = true;
input bool InpVisualShowRejectedCandidates = false;
input bool InpVisualShowH4RegimeV2 = true; // Read-only H4 Regime V2 audit overlay.
input bool InpVisualShowH1ZoneV2 = true; // Read-only H1 Zone V2 audit overlay.
input E2VisualAuditMode InpVisualAuditMode = E2_VISUAL_ALL_TRADES;
input ulong InpVisualFocusTradeId = 0; // Position identity for SINGLE_TRADE mode; 0 is invalid/no focus.
input bool InpVisualCleanupOnDeinit = true;

struct E2Config
  {
   ulong           expert_magic_number;
   bool            trading_enabled;
   bool            debug_mode;
   bool            enable_trend_continuation;
   bool            enable_range_mean_reversion;
   bool            enable_range_breakout;
   bool            enable_fixed_2r_management;
   bool            enable_zone_target_trailing_management;

   int             research_h4_ema_fast_period;
   int             research_h4_ema_slow_period;
   int             research_h4_ema_slope_lookback;
   int             research_h4_atr_period;
   double          research_h4_structural_breakout_distance_atr;
   double          research_h4_trend_extension_limit_atr;
   double          research_range_cluster_variation_maximum_atr;
   double          research_range_minimum_height_atr;
   double          research_range_ema50_flatness_maximum_atr;
   double          research_range_boundary_invalidation_atr;
   double          research_range_outer_entry_region_fraction;

   ENUM_TIMEFRAMES trend_timeframe;
   ENUM_TIMEFRAMES zone_timeframe;
   ENUM_TIMEFRAMES confirmation_timeframe;

   int             swing_sensitivity;
   int             trend_structure_lookback_bars;
   bool            adx_enabled;
   int             adx_period;
   double          adx_minimum_threshold;

   int             minimum_zone_touches;
   int             zone_lookback_bars;
   double          zone_tolerance_pips;
   double          zone_merge_tolerance_pips;
   double          stop_loss_zone_buffer_pips;
   int             research_h1_atr_period;
   double          research_h1_zone_pivot_clustering_atr;
   int             research_h1_minimum_touch_separation_bars;
   double          research_h1_minimum_post_touch_departure_atr;
   double          research_h1_zone_invalidation_atr;
   double          research_h1_breakout_distance_atr;
   int             research_h1_breakout_body_lookback;
   double          research_h1_breakout_body_multiplier;
   double          research_h1_breakout_body_range_minimum;
   double          research_h1_breakout_closing_location_fraction;
   int             research_h1_breakout_retest_expiry_bars;
   double          research_h1_breakout_invalidation_depth_atr;
   double          research_h1_zone_rearm_distance_atr;

   bool            enable_engulfing_confirmation;
   bool            enable_pin_bar_confirmation;
   bool            enable_momentum_candle_confirmation;
   bool            enable_break_previous_candle_confirmation;
   double          pin_bar_minimum_wick_to_body_ratio;
   double          pin_bar_maximum_opposite_wick_to_body_ratio;
   int             momentum_body_lookback;
   double          momentum_body_multiplier;
   int             research_m15_body_median_lookback;
   double          research_m15_momentum_body_multiplier;
   double          research_m15_momentum_body_range_minimum;
   double          research_m15_momentum_closing_location_fraction;
   double          research_m15_rejection_wick_body_minimum;
   double          research_m15_rejection_wick_range_minimum;

   double          risk_percent;
   double          reward_risk_target;
   E2RiskBase      risk_base;
   double          max_entry_deviation_pips;
   bool            execution_test_enabled;
   double          max_spread_pips;
   int             max_quote_age_seconds;
   int             minimum_seconds_between_executions;

   bool            enable_london_session;
   bool            enable_new_york_session;
   int             broker_utc_offset_hours;
   int             london_session_start_hour;
   int             london_session_end_hour;
   int             new_york_session_start_hour;
   int             new_york_session_end_hour;
   bool            session_diagnostics_enabled;

   bool            news_filter_enabled;
   int             high_impact_buffer_before_minutes;
   int             high_impact_buffer_after_minutes;
   bool            news_high_impact_only;
   string          news_data_file;
   bool            news_diagnostics_enabled;

   bool            logging_enabled;
   bool            csv_export_enabled;
   bool            visual_mode_enabled;
   bool            visual_show_zones;
   bool            visual_show_trend_panel;
   bool            visual_show_confirmations;
   bool            visual_show_trades;
   bool            visual_show_rejected_candidates;
   bool            visual_show_h4_regime_v2;
   bool            visual_show_h1_zone_v2;
   E2VisualAuditMode visual_audit_mode;
   ulong           visual_focus_trade_id;
   bool            visual_cleanup_on_deinit;
  };

// Copies the EA inputs once during initialization. Pip values remain in pip
// units so future symbol-aware price conversion can use each symbol's specs.
void E2LoadConfiguration(E2Config &configuration)
  {
   configuration.expert_magic_number                    = InpExpertMagicNumber;
   configuration.trading_enabled                        = InpTradingEnabled;
   configuration.debug_mode                             = InpDebugMode;
   configuration.enable_trend_continuation              = InpEnableTrendContinuation;
   configuration.enable_range_mean_reversion            = InpEnableRangeMeanReversion;
   configuration.enable_range_breakout                  = InpEnableRangeBreakout;
   configuration.enable_fixed_2r_management             = InpEnableFixed2RManagement;
   configuration.enable_zone_target_trailing_management = InpEnableZoneTargetTrailingManagement;
   configuration.research_h4_ema_fast_period            = InpResearchH4EmaFastPeriod;
   configuration.research_h4_ema_slow_period            = InpResearchH4EmaSlowPeriod;
   configuration.research_h4_ema_slope_lookback         = InpResearchH4EmaSlopeLookback;
   configuration.research_h4_atr_period                 = InpResearchH4AtrPeriod;
   configuration.research_h4_structural_breakout_distance_atr = InpResearchH4StructuralBreakoutDistanceAtr;
   configuration.research_h4_trend_extension_limit_atr  = InpResearchH4TrendExtensionLimitAtr;
   configuration.research_range_cluster_variation_maximum_atr = InpResearchRangeClusterVariationMaximumAtr;
   configuration.research_range_minimum_height_atr      = InpResearchRangeMinimumHeightAtr;
   configuration.research_range_ema50_flatness_maximum_atr = InpResearchRangeEma50FlatnessMaximumAtr;
   configuration.research_range_boundary_invalidation_atr = InpResearchRangeBoundaryInvalidationAtr;
   configuration.research_range_outer_entry_region_fraction = InpResearchRangeOuterEntryRegionFraction;
   configuration.trend_timeframe                        = InpTrendTimeframe;
   configuration.zone_timeframe                         = InpZoneTimeframe;
   configuration.confirmation_timeframe                 = InpConfirmationTimeframe;
   configuration.swing_sensitivity                      = InpSwingSensitivity;
   configuration.trend_structure_lookback_bars          = InpTrendStructureLookbackBars;
   configuration.adx_enabled                            = InpAdxEnabled;
   configuration.adx_period                             = InpAdxPeriod;
   configuration.adx_minimum_threshold                  = InpAdxMinimumThreshold;
   configuration.minimum_zone_touches                   = InpMinimumZoneTouches;
   configuration.zone_lookback_bars                     = InpZoneLookbackBars;
   configuration.zone_tolerance_pips                    = InpZoneTolerancePips;
   configuration.zone_merge_tolerance_pips              = InpZoneMergeTolerancePips;
   configuration.stop_loss_zone_buffer_pips             = InpStopLossZoneBufferPips;
   configuration.research_h1_atr_period                 = InpResearchH1AtrPeriod;
   configuration.research_h1_zone_pivot_clustering_atr  = InpResearchH1ZonePivotClusteringAtr;
   configuration.research_h1_minimum_touch_separation_bars = InpResearchH1MinimumTouchSeparationBars;
   configuration.research_h1_minimum_post_touch_departure_atr = InpResearchH1MinimumPostTouchDepartureAtr;
   configuration.research_h1_zone_invalidation_atr      = InpResearchH1ZoneInvalidationAtr;
   configuration.research_h1_breakout_distance_atr      = InpResearchH1BreakoutDistanceAtr;
   configuration.research_h1_breakout_body_lookback     = InpResearchH1BreakoutBodyLookback;
   configuration.research_h1_breakout_body_multiplier   = InpResearchH1BreakoutBodyMultiplier;
   configuration.research_h1_breakout_body_range_minimum = InpResearchH1BreakoutBodyRangeMinimum;
   configuration.research_h1_breakout_closing_location_fraction = InpResearchH1BreakoutClosingLocationFraction;
   configuration.research_h1_breakout_retest_expiry_bars = InpResearchH1BreakoutRetestExpiryBars;
   configuration.research_h1_breakout_invalidation_depth_atr = InpResearchH1BreakoutInvalidationDepthAtr;
   configuration.research_h1_zone_rearm_distance_atr    = InpResearchH1ZoneRearmDistanceAtr;
   configuration.enable_engulfing_confirmation          = InpEnableEngulfingConfirmation;
   configuration.enable_pin_bar_confirmation            = InpEnablePinBarConfirmation;
   configuration.enable_momentum_candle_confirmation    = InpEnableMomentumCandleConfirmation;
   configuration.enable_break_previous_candle_confirmation = InpEnableBreakPreviousCandleConfirmation;
   configuration.pin_bar_minimum_wick_to_body_ratio = InpPinBarMinimumWickToBodyRatio;
   configuration.pin_bar_maximum_opposite_wick_to_body_ratio = InpPinBarMaximumOppositeWickToBodyRatio;
   configuration.momentum_body_lookback = InpMomentumBodyLookback;
   configuration.momentum_body_multiplier = InpMomentumBodyMultiplier;
   configuration.research_m15_body_median_lookback = InpResearchM15BodyMedianLookback;
   configuration.research_m15_momentum_body_multiplier = InpResearchM15MomentumBodyMultiplier;
   configuration.research_m15_momentum_body_range_minimum = InpResearchM15MomentumBodyRangeMinimum;
   configuration.research_m15_momentum_closing_location_fraction = InpResearchM15MomentumClosingLocationFraction;
   configuration.research_m15_rejection_wick_body_minimum = InpResearchM15RejectionWickBodyMinimum;
   configuration.research_m15_rejection_wick_range_minimum = InpResearchM15RejectionWickRangeMinimum;
   configuration.risk_percent                           = InpRiskPercent;
   configuration.reward_risk_target                     = InpRewardRiskTarget;
   configuration.risk_base                              = InpRiskBase;
   configuration.max_entry_deviation_pips               = InpMaxEntryDeviationPips;
   configuration.execution_test_enabled                 = InpExecutionTestEnabled;
   configuration.max_spread_pips                        = InpMaxSpreadPips;
   configuration.max_quote_age_seconds                  = InpMaxQuoteAgeSeconds;
   configuration.minimum_seconds_between_executions     = InpMinimumSecondsBetweenExecutions;
   configuration.enable_london_session                  = InpEnableLondonSession;
   configuration.enable_new_york_session                = InpEnableNewYorkSession;
   configuration.broker_utc_offset_hours                = InpBrokerUtcOffsetHours;
   configuration.london_session_start_hour              = InpLondonSessionStartHour;
   configuration.london_session_end_hour                = InpLondonSessionEndHour;
   configuration.new_york_session_start_hour            = InpNewYorkSessionStartHour;
   configuration.new_york_session_end_hour              = InpNewYorkSessionEndHour;
   configuration.session_diagnostics_enabled            = InpSessionDiagnosticsEnabled;
   configuration.news_filter_enabled                    = InpNewsFilterEnabled;
   configuration.high_impact_buffer_before_minutes      = InpHighImpactBufferBeforeMins;
   configuration.high_impact_buffer_after_minutes       = InpHighImpactBufferAfterMins;
   configuration.news_high_impact_only                  = InpNewsHighImpactOnly;
   configuration.news_data_file                         = InpNewsDataFile;
   configuration.news_diagnostics_enabled               = InpNewsDiagnosticsEnabled;
   configuration.logging_enabled                        = InpLoggingEnabled;
   configuration.csv_export_enabled                     = InpCsvExportEnabled;
   configuration.visual_mode_enabled                    = InpVisualModeEnabled;
   configuration.visual_show_zones                      = InpVisualShowZones;
   configuration.visual_show_trend_panel                = InpVisualShowTrendPanel;
   configuration.visual_show_confirmations              = InpVisualShowConfirmations;
   configuration.visual_show_trades                     = InpVisualShowTrades;
   configuration.visual_show_rejected_candidates        = InpVisualShowRejectedCandidates;
   configuration.visual_show_h4_regime_v2               = InpVisualShowH4RegimeV2;
   configuration.visual_show_h1_zone_v2                 = InpVisualShowH1ZoneV2;
   configuration.visual_audit_mode                      = InpVisualAuditMode;
   configuration.visual_focus_trade_id                  = InpVisualFocusTradeId;
   configuration.visual_cleanup_on_deinit               = InpVisualCleanupOnDeinit;
  }

// Validates only universally invalid values; strategy-specific constraints are
// deferred to the sprints that define their final algorithms.
bool E2ValidateConfiguration(const E2Config &configuration,string &reason)
  {
   reason = "";

   if(configuration.risk_percent <= 0.0)
     {
      reason = "Risk percentage must be greater than zero.";
      return(false);
     }
   if(configuration.reward_risk_target <= 0.0)
     {
      reason = "Reward-to-risk target must be greater than zero.";
      return(false);
     }
   if(configuration.adx_period <= 0)
     {
      reason = "ADX period must be greater than zero.";
     return(false);
     }
   if(configuration.max_entry_deviation_pips < 0.0)
     {
      reason = "Maximum entry deviation cannot be negative.";
     return(false);
     }
   if(configuration.max_spread_pips < 0.0 || configuration.max_quote_age_seconds < 0 || configuration.minimum_seconds_between_executions < 0)
     {
      reason = "Execution safety values cannot be negative.";
      return(false);
     }
   if(configuration.swing_sensitivity < 1)
     {
      reason = "Swing sensitivity must be at least one.";
      return(false);
     }
   if(configuration.trend_structure_lookback_bars < (configuration.swing_sensitivity*2+1))
     {
      reason = "Trend structure lookback must contain a complete pivot window.";
      return(false);
     }
   if(configuration.minimum_zone_touches < 1)
     {
      reason = "Minimum zone touches must be at least one.";
     return(false);
     }
   if(configuration.zone_lookback_bars < (configuration.swing_sensitivity*2+1))
     {
      reason = "Zone lookback must contain a complete pivot window.";
      return(false);
     }
   if(configuration.zone_tolerance_pips < 0.0 || configuration.zone_merge_tolerance_pips < 0.0 || configuration.stop_loss_zone_buffer_pips < 0.0)
     {
      reason = "Zone tolerances and stop-loss zone buffer cannot be negative.";
     return(false);
     }
   if(configuration.research_h1_atr_period < 1 || configuration.research_h1_minimum_touch_separation_bars < 1 || configuration.research_h1_zone_pivot_clustering_atr < 0.0 || configuration.research_h1_minimum_post_touch_departure_atr <= 0.0 || configuration.research_h1_zone_invalidation_atr < 0.0 || configuration.research_h1_zone_rearm_distance_atr < 0.0)
     {
      reason = "H1 Zone V2 research values are invalid.";
      return(false);
     }
   if(configuration.pin_bar_minimum_wick_to_body_ratio < 0.0 || configuration.pin_bar_maximum_opposite_wick_to_body_ratio < 0.0 || configuration.momentum_body_lookback < 1 || configuration.momentum_body_multiplier <= 0.0)
     {
      reason = "Confirmation thresholds are invalid.";
      return(false);
     }
   if(configuration.high_impact_buffer_before_minutes < 0 || configuration.high_impact_buffer_after_minutes < 0)
     {
      reason = "High-impact news buffers cannot be negative.";
      return(false);
     }

   return(true);
  }

#endif // E2_CORE_E2CONFIG_MQH
