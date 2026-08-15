#ifndef E2_STRATEGY_E2RESEARCHTYPES_MQH
#define E2_STRATEGY_E2RESEARCHTYPES_MQH

// Canonical v1.1 research vocabulary. These definitions are intentionally
// independent of analysis, reporting, and visualization implementation.
enum E2StrategyType
  {
   E2_STRATEGY_NONE,
   E2_STRATEGY_TREND_CONTINUATION,
   E2_STRATEGY_RANGE_MEAN_REVERSION,
   E2_STRATEGY_RANGE_BREAKOUT
  };

enum E2ManagementMode
  {
   E2_MANAGEMENT_NONE,
   E2_MANAGEMENT_FIXED_2R,
   E2_MANAGEMENT_ZONE_TARGET_TRAILING
  };

enum E2RegimeType
  {
   E2_REGIME_UNKNOWN,
   E2_REGIME_UPTREND,
   E2_REGIME_DOWNTREND,
   E2_REGIME_RANGE,
   E2_REGIME_TRANSITION_UNCLASSIFIED
  };

enum E2TacticalBreakoutState
  {
   E2_TACTICAL_NONE,
   E2_TACTICAL_RANGE_BREAKOUT_PENDING_BULLISH,
   E2_TACTICAL_RANGE_BREAKOUT_PENDING_BEARISH
  };

enum E2BoundaryResponse
  {
   E2_BOUNDARY_NONE,
   E2_BOUNDARY_ACCEPTED_OUTSIDE,
   E2_BOUNDARY_REJECTED_INSIDE,
   E2_BOUNDARY_AMBIGUOUS_NO_TRADE
  };

enum E2ResearchConfirmationType
  {
   E2_RESEARCH_CONFIRMATION_NONE,
   E2_RESEARCH_CONFIRMATION_BULLISH_MOMENTUM,
   E2_RESEARCH_CONFIRMATION_BEARISH_MOMENTUM,
   E2_RESEARCH_CONFIRMATION_BULLISH_RANGE_REJECTION,
   E2_RESEARCH_CONFIRMATION_BEARISH_RANGE_REJECTION
  };

string E2ResearchConfirmationTypeName(const E2ResearchConfirmationType value)
  {
   switch(value)
     {
      case E2_RESEARCH_CONFIRMATION_BULLISH_MOMENTUM: return("BULLISH_MOMENTUM");
      case E2_RESEARCH_CONFIRMATION_BEARISH_MOMENTUM: return("BEARISH_MOMENTUM");
      case E2_RESEARCH_CONFIRMATION_BULLISH_RANGE_REJECTION: return("BULLISH_RANGE_REJECTION");
      case E2_RESEARCH_CONFIRMATION_BEARISH_RANGE_REJECTION: return("BEARISH_RANGE_REJECTION");
      default: return("NONE");
     }
  }

string E2StrategyTypeName(const E2StrategyType value)
  {
   switch(value)
     {
      case E2_STRATEGY_TREND_CONTINUATION:   return("TREND_CONTINUATION");
      case E2_STRATEGY_RANGE_MEAN_REVERSION: return("RANGE_MEAN_REVERSION");
      case E2_STRATEGY_RANGE_BREAKOUT:       return("RANGE_BREAKOUT");
      default:                                return("NONE");
     }
  }

string E2ManagementModeName(const E2ManagementMode value)
  {
   switch(value)
     {
      case E2_MANAGEMENT_FIXED_2R:              return("FIXED_2R");
      case E2_MANAGEMENT_ZONE_TARGET_TRAILING:  return("ZONE_TARGET_TRAILING");
      default:                                   return("NONE");
     }
  }

string E2RegimeTypeName(const E2RegimeType value)
  {
   switch(value)
     {
      case E2_REGIME_UPTREND:                  return("UPTREND");
      case E2_REGIME_DOWNTREND:                return("DOWNTREND");
      case E2_REGIME_RANGE:                    return("RANGE");
      case E2_REGIME_TRANSITION_UNCLASSIFIED:  return("TRANSITION_UNCLASSIFIED");
      default:                                  return("UNKNOWN");
     }
  }

string E2TacticalBreakoutStateName(const E2TacticalBreakoutState value)
  {
   switch(value)
     {
      case E2_TACTICAL_RANGE_BREAKOUT_PENDING_BULLISH: return("RANGE_BREAKOUT_PENDING_BULLISH");
      case E2_TACTICAL_RANGE_BREAKOUT_PENDING_BEARISH: return("RANGE_BREAKOUT_PENDING_BEARISH");
      default:                                         return("NONE");
     }
  }

string E2BoundaryResponseName(const E2BoundaryResponse value)
  {
   switch(value)
     {
      case E2_BOUNDARY_ACCEPTED_OUTSIDE:      return("ACCEPTED_OUTSIDE");
      case E2_BOUNDARY_REJECTED_INSIDE:       return("REJECTED_INSIDE");
      case E2_BOUNDARY_AMBIGUOUS_NO_TRADE:    return("AMBIGUOUS_NO_TRADE");
      default:                                 return("NONE");
     }
  }

// Decision-time carrier for future strategy/state producers. Sprint 1.1 does
// not populate or consume it; later producers set it once before passing a
// const copy to reporting and visualization consumers.
struct E2ResearchMetadata
  {
   E2StrategyType           strategy_type;
   E2RegimeType             h4_regime_at_setup_creation;
   E2RegimeType             h4_regime_at_entry;
   E2TacticalBreakoutState  tactical_breakout_state;
   E2BoundaryResponse       boundary_response;
   E2ManagementMode         management_mode;
   int                      h4_range_id;
   int                      h1_zone_id;
   int                      zone_attempt_number;
   datetime                 setup_creation_time;
   datetime                 confirmation_time;
   datetime                 breakout_acceptance_time;
   datetime                 retest_time;
  };

void E2ResetResearchMetadata(E2ResearchMetadata &metadata)
  {
   metadata.strategy_type=E2_STRATEGY_NONE;
   metadata.h4_regime_at_setup_creation=E2_REGIME_UNKNOWN;
   metadata.h4_regime_at_entry=E2_REGIME_UNKNOWN;
   metadata.tactical_breakout_state=E2_TACTICAL_NONE;
   metadata.boundary_response=E2_BOUNDARY_NONE;
   metadata.management_mode=E2_MANAGEMENT_NONE;
   metadata.h4_range_id=-1;
   metadata.h1_zone_id=-1;
   metadata.zone_attempt_number=0;
   metadata.setup_creation_time=0;
   metadata.confirmation_time=0;
   metadata.breakout_acceptance_time=0;
   metadata.retest_time=0;
  }

#endif // E2_STRATEGY_E2RESEARCHTYPES_MQH
