#ifndef E2_CORE_E2CONFIG_MQH
#define E2_CORE_E2CONFIG_MQH

#include "..\\strategy\\E2ResearchTypes.mqh"

// External EA inputs are intentionally kept here. Future modules receive the
// E2Config structure instead of depending on these input variables directly.

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

input group "SETUP SELECTION"
input bool InpEnableTrendContinuation = true;
input bool InpResearchVerificationSummary = true; // Bounded semantic-regression and invariant summary.
input bool InpResearchVerboseDiagnostics = false;
input bool InpEnableRangeMeanReversion = false;
input bool InpEnableRangeBreakout = false;

input group "MANAGEMENT"
input bool InpEnableFixed2RManagement = true;
input bool InpEnableZoneTargetTrailingManagement = false;

input group "H4 REGIME"
input int InpResearchH4EmaFastPeriod = 20;
input int InpResearchH4EmaSlowPeriod = 50;
input int InpResearchH4EmaSlopeLookback = 5;
input int InpResearchH4AtrPeriod = 14;
input double InpResearchH4StructuralBreakoutDistanceAtr = 0.10;
input double InpResearchH4TrendExtensionLimitAtr = 1.50;
input double InpH4RangeAdxMaximum = 20.0;
input int InpH4RangeContainmentLookback = 20;
input double InpH4RangeMaximumWidthAtr = 6.0;

input group "RANGE CLASSIFICATION"
input double InpResearchRangeOuterEntryRegionFraction = 0.20;
input double InpRangeBoundaryContainmentToleranceAtr = 0.25;
input double InpRangeBoundaryMinimumHeightAtr = 3.0;
input double InpResearchRangeBoundaryInvalidationAtr = 0.25;

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
input int    InpZoneLookbackBars        = 240; // Closed H1 bars used for deterministic zone analysis.

input group "H1 PERSISTENT ZONES / TREND CONTINUATION"
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

input group "M15 CONFIRMATION"
input int InpResearchM15BodyMedianLookback = 20;
input double InpResearchM15MomentumBodyMultiplier = 1.25;
input double InpResearchM15MomentumBodyRangeMinimum = 0.60;
input double InpResearchM15MomentumClosingLocationFraction = 0.20;
input double InpResearchM15RejectionWickBodyMinimum = 1.50;
input double InpResearchM15RejectionWickRangeMinimum = 0.40;

input group "RISK"
input double InpRiskPercent         = 1.0; // Risk per trade as a percentage of the final selected risk base.

input group "EXECUTION"
input double InpMaxEntryDeviationPips = 2.0;  // Reject plans whose market price has moved farther than this distance.
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

input group "NEWS"
input bool InpNewsFilterEnabled          = true; // Enable deterministic historical-news entry exclusion.
input int  InpHighImpactBufferBeforeMins = 30;   // Minutes to exclude before a scheduled event, inclusive.
input int  InpHighImpactBufferAfterMins  = 30;   // Minutes to exclude after a scheduled event, inclusive.
input bool InpNewsHighImpactOnly          = true; // When false, all recognized event impacts are blocking.
input string InpNewsDataFile              = "E2_news_events.csv"; // FILE_COMMON CSV; schema is documented in E2NewsFilter.mqh.

input group "REPORTING"
input bool InpLoggingEnabled   = true;  // Enable future strategy-independent logging.
input bool InpCsvExportEnabled = false; // Enable future CSV export.

input group "VISUALIZATION"
input bool InpVisualModeEnabled = true; // Audit-only MT5 Strategy Tester Visual Mode overlay.
input bool InpVisualShowConfirmations = true;
input bool InpVisualShowTrades = true;
input bool InpVisualShowH4RegimeV2 = true; // Read-only H4 Regime V2 audit overlay.
input bool InpVisualShowH1ZoneV2 = true; // Read-only H1 Zone V2 audit overlay.
input bool InpVisualShowH1RangeBoundaries = true; // Read-only frozen range-boundary audit overlay.
input bool InpVisualShowM15ConfirmationV2 = true; // Read-only M15 Confirmation V2 audit overlay.
input bool InpVisualShowTrendContinuationV2 = true; // Read-only Trend Continuation V2 audit overlay.
input bool InpVisualShowRangeMeanReversionV2 = true; // Passed RMR candidates only.
input E2VisualAuditMode InpVisualAuditMode = E2_VISUAL_ALL_TRADES;
input ulong InpVisualFocusTradeId = 0; // Position identity for SINGLE_TRADE mode; 0 is invalid/no focus.
input bool InpVisualCleanupOnDeinit = true;

struct E2Config
  {
   ulong           expert_magic_number;
   bool            trading_enabled;
   bool            debug_mode;
   bool            enable_trend_continuation;
   bool            research_verification_summary;
   bool            research_verbose_diagnostics;
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
   double          h4_range_adx_maximum;
   int             h4_range_containment_lookback;
   double          h4_range_maximum_width_atr;
   double          research_range_outer_entry_region_fraction;
   double          range_boundary_containment_tolerance_atr;
   double          range_boundary_minimum_height_atr;
   double          research_range_boundary_invalidation_atr;

   ENUM_TIMEFRAMES trend_timeframe;
   ENUM_TIMEFRAMES zone_timeframe;
   ENUM_TIMEFRAMES confirmation_timeframe;

   int             swing_sensitivity;
   int             trend_structure_lookback_bars;
   bool            adx_enabled;
   int             adx_period;
   double          adx_minimum_threshold;

   int             zone_lookback_bars;
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

   int             research_m15_body_median_lookback;
   double          research_m15_momentum_body_multiplier;
   double          research_m15_momentum_body_range_minimum;
   double          research_m15_momentum_closing_location_fraction;
   double          research_m15_rejection_wick_body_minimum;
   double          research_m15_rejection_wick_range_minimum;

   double          risk_percent;
   double          max_entry_deviation_pips;
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

   bool            news_filter_enabled;
   int             high_impact_buffer_before_minutes;
   int             high_impact_buffer_after_minutes;
   bool            news_high_impact_only;
   string          news_data_file;

   bool            logging_enabled;
   bool            csv_export_enabled;
   bool            visual_mode_enabled;
   bool            visual_show_confirmations;
   bool            visual_show_trades;
   bool            visual_show_h4_regime_v2;
   bool            visual_show_h1_zone_v2;
   bool            visual_show_h1_range_boundaries;
   bool            visual_show_m15_confirmation_v2;
   bool            visual_show_trend_continuation_v2;
   bool            visual_show_range_mean_reversion_v2;
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
   configuration.research_verification_summary          = InpResearchVerificationSummary;
   configuration.research_verbose_diagnostics           = InpResearchVerboseDiagnostics;
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
   configuration.h4_range_adx_maximum                   = InpH4RangeAdxMaximum;
   configuration.h4_range_containment_lookback          = InpH4RangeContainmentLookback;
   configuration.h4_range_maximum_width_atr             = InpH4RangeMaximumWidthAtr;
   configuration.research_range_outer_entry_region_fraction = InpResearchRangeOuterEntryRegionFraction;
   configuration.range_boundary_containment_tolerance_atr = InpRangeBoundaryContainmentToleranceAtr;
   configuration.range_boundary_minimum_height_atr = InpRangeBoundaryMinimumHeightAtr;
   configuration.research_range_boundary_invalidation_atr = InpResearchRangeBoundaryInvalidationAtr;
   configuration.trend_timeframe                        = InpTrendTimeframe;
   configuration.zone_timeframe                         = InpZoneTimeframe;
   configuration.confirmation_timeframe                 = InpConfirmationTimeframe;
   configuration.swing_sensitivity                      = InpSwingSensitivity;
   configuration.trend_structure_lookback_bars          = InpTrendStructureLookbackBars;
   configuration.adx_enabled                            = InpAdxEnabled;
   configuration.adx_period                             = InpAdxPeriod;
   configuration.adx_minimum_threshold                  = InpAdxMinimumThreshold;
   configuration.zone_lookback_bars                     = InpZoneLookbackBars;
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
   configuration.research_m15_body_median_lookback = InpResearchM15BodyMedianLookback;
   configuration.research_m15_momentum_body_multiplier = InpResearchM15MomentumBodyMultiplier;
   configuration.research_m15_momentum_body_range_minimum = InpResearchM15MomentumBodyRangeMinimum;
   configuration.research_m15_momentum_closing_location_fraction = InpResearchM15MomentumClosingLocationFraction;
   configuration.research_m15_rejection_wick_body_minimum = InpResearchM15RejectionWickBodyMinimum;
   configuration.research_m15_rejection_wick_range_minimum = InpResearchM15RejectionWickRangeMinimum;
   configuration.risk_percent                           = InpRiskPercent;
   configuration.max_entry_deviation_pips               = InpMaxEntryDeviationPips;
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
   configuration.news_filter_enabled                    = InpNewsFilterEnabled;
   configuration.high_impact_buffer_before_minutes      = InpHighImpactBufferBeforeMins;
   configuration.high_impact_buffer_after_minutes       = InpHighImpactBufferAfterMins;
   configuration.news_high_impact_only                  = InpNewsHighImpactOnly;
   configuration.news_data_file                         = InpNewsDataFile;
   configuration.logging_enabled                        = InpLoggingEnabled;
   configuration.csv_export_enabled                     = InpCsvExportEnabled;
   configuration.visual_mode_enabled                    = InpVisualModeEnabled;
   configuration.visual_show_confirmations              = InpVisualShowConfirmations;
   configuration.visual_show_trades                     = InpVisualShowTrades;
   configuration.visual_show_h4_regime_v2               = InpVisualShowH4RegimeV2;
   configuration.visual_show_h1_zone_v2                 = InpVisualShowH1ZoneV2;
   configuration.visual_show_h1_range_boundaries         = InpVisualShowH1RangeBoundaries;
   configuration.visual_show_m15_confirmation_v2        = InpVisualShowM15ConfirmationV2;
   configuration.visual_show_trend_continuation_v2      = InpVisualShowTrendContinuationV2;
   configuration.visual_show_range_mean_reversion_v2    = InpVisualShowRangeMeanReversionV2;
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
   if(configuration.zone_lookback_bars < (configuration.swing_sensitivity*2+1))
     {
      reason = "Zone lookback must contain a complete pivot window.";
      return(false);
     }
   if(configuration.research_h1_atr_period < 1 || configuration.research_h1_minimum_touch_separation_bars < 1 || configuration.research_h1_zone_pivot_clustering_atr < 0.0 || configuration.research_h1_minimum_post_touch_departure_atr <= 0.0 || configuration.research_h1_zone_invalidation_atr < 0.0 || configuration.research_h1_zone_rearm_distance_atr < 0.0)
     {
      reason = "H1 Zone V2 research values are invalid.";
     return(false);
     }
   if(configuration.h4_range_adx_maximum < 0.0 || configuration.h4_range_containment_lookback < 1 || configuration.h4_range_maximum_width_atr <= 0.0)
     {
      reason = "H4 range-regime values are invalid.";
     return(false);
     }
   if(configuration.range_boundary_containment_tolerance_atr < 0.0 || configuration.range_boundary_minimum_height_atr <= 0.0 || configuration.research_range_boundary_invalidation_atr < 0.0)
     {
      reason = "H1 range-boundary values are invalid.";
      return(false);
     }
   if(configuration.research_m15_body_median_lookback < 1 || configuration.research_m15_momentum_body_multiplier <= 0.0 || configuration.research_m15_momentum_body_range_minimum < 0.0 || configuration.research_m15_momentum_body_range_minimum > 1.0 || configuration.research_m15_momentum_closing_location_fraction < 0.0 || configuration.research_m15_momentum_closing_location_fraction > 1.0 || configuration.research_m15_rejection_wick_body_minimum < 0.0 || configuration.research_m15_rejection_wick_range_minimum < 0.0 || configuration.research_m15_rejection_wick_range_minimum > 1.0)
     {
      reason = "M15 Confirmation V2 research values are invalid.";
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
