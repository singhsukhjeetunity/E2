#ifndef E2_CORE_E2CONFIG_MQH
#define E2_CORE_E2CONFIG_MQH

// External EA inputs are intentionally kept here. Future modules receive the
// E2Config structure instead of depending on these input variables directly.

enum E2RiskBase
  {
   E2_RISK_BASE_BALANCE,
   E2_RISK_BASE_EQUITY
  };

input group "GENERAL"
input ulong InpExpertMagicNumber = 2026001; // Identifier reserved for E2 orders.
input bool  InpTradingEnabled   = true;    // Master switch for future trade execution.
input bool  InpDebugMode        = false;   // Enables future diagnostic output.

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
input double InpZoneTolerancePips       = 5.0; // Price-reaction tolerance, expressed in pips.
input double InpZoneMergeTolerancePips  = 5.0; // Nearby-zone merge tolerance, expressed in pips.
input double InpStopLossZoneBufferPips  = 2.0; // Future stop buffer beyond a zone, expressed in pips.

input group "CONFIRMATIONS"
input bool InpEnableEngulfingConfirmation           = true; // Enable future engulfing-candle confirmation.
input bool InpEnablePinBarConfirmation              = true; // Enable future pin-bar confirmation.
input bool InpEnableMomentumCandleConfirmation      = true; // Enable future momentum-candle confirmation.
input bool InpEnableBreakPreviousCandleConfirmation = true; // Enable future previous-candle-break confirmation.

input group "RISK"
input double InpRiskPercent         = 1.0; // Risk per trade as a percentage of the final selected risk base.
input double InpRewardRiskTarget    = 2.0; // Take-profit target expressed as reward-to-risk (R).
input E2RiskBase InpRiskBase         = E2_RISK_BASE_BALANCE; // Future sizing base; no sizing is performed in Sprint 2.1.

input group "EXECUTION"
input double InpMaxEntryDeviationPips = 2.0;  // Reject plans whose market price has moved farther than this distance.
input bool   InpExecutionTestEnabled  = false; // Explicit one-attempt test harness; restricted to tester/demo environments.

input group "SESSIONS"
input bool InpEnableLondonSession   = true; // Allow future entries during the London session.
input bool InpEnableNewYorkSession  = true; // Allow future entries during the New York session.
// Session times and broker/server-time conversion are intentionally deferred to Sprint 1.5.

input group "NEWS"
input bool InpNewsFilterEnabled          = true; // Enable future high-impact-news entry exclusion.
input int  InpHighImpactBufferBeforeMins = 60;   // Minutes to exclude before high-impact news.
input int  InpHighImpactBufferAfterMins  = 60;   // Minutes to exclude after high-impact news.

input group "REPORTING"
input bool InpLoggingEnabled   = true;  // Enable future strategy-independent logging.
input bool InpCsvExportEnabled = false; // Enable future CSV export.

struct E2Config
  {
   ulong           expert_magic_number;
   bool            trading_enabled;
   bool            debug_mode;

   ENUM_TIMEFRAMES trend_timeframe;
   ENUM_TIMEFRAMES zone_timeframe;
   ENUM_TIMEFRAMES confirmation_timeframe;

   int             swing_sensitivity;
   int             trend_structure_lookback_bars;
   bool            adx_enabled;
   int             adx_period;
   double          adx_minimum_threshold;

   int             minimum_zone_touches;
   double          zone_tolerance_pips;
   double          zone_merge_tolerance_pips;
   double          stop_loss_zone_buffer_pips;

   bool            enable_engulfing_confirmation;
   bool            enable_pin_bar_confirmation;
   bool            enable_momentum_candle_confirmation;
   bool            enable_break_previous_candle_confirmation;

   double          risk_percent;
   double          reward_risk_target;
   E2RiskBase      risk_base;
   double          max_entry_deviation_pips;
   bool            execution_test_enabled;

   bool            enable_london_session;
   bool            enable_new_york_session;

   bool            news_filter_enabled;
   int             high_impact_buffer_before_minutes;
   int             high_impact_buffer_after_minutes;

   bool            logging_enabled;
   bool            csv_export_enabled;
  };

// Copies the EA inputs once during initialization. Pip values remain in pip
// units so future symbol-aware price conversion can use each symbol's specs.
void E2LoadConfiguration(E2Config &configuration)
  {
   configuration.expert_magic_number                    = InpExpertMagicNumber;
   configuration.trading_enabled                        = InpTradingEnabled;
   configuration.debug_mode                             = InpDebugMode;
   configuration.trend_timeframe                        = InpTrendTimeframe;
   configuration.zone_timeframe                         = InpZoneTimeframe;
   configuration.confirmation_timeframe                 = InpConfirmationTimeframe;
   configuration.swing_sensitivity                      = InpSwingSensitivity;
   configuration.trend_structure_lookback_bars          = InpTrendStructureLookbackBars;
   configuration.adx_enabled                            = InpAdxEnabled;
   configuration.adx_period                             = InpAdxPeriod;
   configuration.adx_minimum_threshold                  = InpAdxMinimumThreshold;
   configuration.minimum_zone_touches                   = InpMinimumZoneTouches;
   configuration.zone_tolerance_pips                    = InpZoneTolerancePips;
   configuration.zone_merge_tolerance_pips              = InpZoneMergeTolerancePips;
   configuration.stop_loss_zone_buffer_pips             = InpStopLossZoneBufferPips;
   configuration.enable_engulfing_confirmation          = InpEnableEngulfingConfirmation;
   configuration.enable_pin_bar_confirmation            = InpEnablePinBarConfirmation;
   configuration.enable_momentum_candle_confirmation    = InpEnableMomentumCandleConfirmation;
   configuration.enable_break_previous_candle_confirmation = InpEnableBreakPreviousCandleConfirmation;
   configuration.risk_percent                           = InpRiskPercent;
   configuration.reward_risk_target                     = InpRewardRiskTarget;
   configuration.risk_base                              = InpRiskBase;
   configuration.max_entry_deviation_pips               = InpMaxEntryDeviationPips;
   configuration.execution_test_enabled                 = InpExecutionTestEnabled;
   configuration.enable_london_session                  = InpEnableLondonSession;
   configuration.enable_new_york_session                = InpEnableNewYorkSession;
   configuration.news_filter_enabled                    = InpNewsFilterEnabled;
   configuration.high_impact_buffer_before_minutes      = InpHighImpactBufferBeforeMins;
   configuration.high_impact_buffer_after_minutes       = InpHighImpactBufferAfterMins;
   configuration.logging_enabled                        = InpLoggingEnabled;
   configuration.csv_export_enabled                     = InpCsvExportEnabled;
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
   if(configuration.zone_tolerance_pips < 0.0 || configuration.zone_merge_tolerance_pips < 0.0 || configuration.stop_loss_zone_buffer_pips < 0.0)
     {
      reason = "Zone tolerances and stop-loss zone buffer cannot be negative.";
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
