#ifndef E2_RISK_E2TRADEPLANNER_MQH
#define E2_RISK_E2TRADEPLANNER_MQH

#include "E2PositionSizer.mqh"

enum E2TradePlanStatus
  {
   E2_PLAN_VALID,
   E2_PLAN_INVALID_INPUT,
   E2_PLAN_INVALID_DIRECTION,
   E2_PLAN_INVALID_ENTRY,
   E2_PLAN_INVALID_STOP,
   E2_PLAN_INVALID_TAKE_PROFIT,
   E2_PLAN_INVALID_RR,
   E2_PLAN_POSITION_SIZING_FAILED,
   E2_PLAN_NORMALIZATION_FAILED,
   E2_PLAN_INVALID_STRATEGY_SIGNAL,
   E2_PLAN_INVALID_ZONE,
   E2_PLAN_MARKET_PRICE_UNAVAILABLE,
   E2_PLAN_INVALID_SYMBOL_SPEC,
   E2_PLAN_INVALID_ACCOUNT_EQUITY,
   E2_PLAN_INVALID_RISK_PERCENT,
   E2_PLAN_STOP_TOO_CLOSE,
   E2_PLAN_LOSS_CALCULATION_FAILED,
   E2_PLAN_VOLUME_CALCULATION_FAILED,
   E2_PLAN_VOLUME_BELOW_MINIMUM,
   E2_PLAN_VOLUME_ABOVE_MAXIMUM,
   E2_PLAN_RISK_EXCEEDED
  };

struct E2TradeIntent
  {
   string            symbol;
   E2TradeDirection  direction;
   double            entry_price;
   double            stop_loss_price;
   double            reward_risk_target;
   string            strategy_id;
   datetime          setup_time;
   string            reason_tag;
  };

struct E2TradePlan
  {
   bool              ready;
   bool              valid;
   datetime          evaluation_time;
   E2TradePlanStatus status;
   E2SizingStatus    sizing_status;
   string            symbol;
   E2TradeDirection  direction;
   int               zone_id;
   string            zone_role;
   double            zone_lower;
   double            zone_upper;
   double            bid;
   double            ask;
   string            entry_side;
   double            spread_points;
   double            spread_pips;
   double            entry_price;
   double            stop_loss_price;
   double            take_profit_price;
   double            requested_reward_risk;
   double            actual_reward_risk;
   double            volume;
   double            raw_volume;
   double            loss_per_lot;
   double            account_equity;
   double            risk_percent;
   double            volume_min;
   double            volume_max;
   double            volume_step;
   double            target_risk_money;
   double            actual_risk_money;
   double            actual_risk_percent;
   double            stop_distance_price;
   double            stop_distance_pips;
   double            expected_reward_money;
  };

struct E2StrategyPlanRequest
  {
   string            symbol;
   datetime          evaluation_time;
   bool              valid_strategy_signal;
   E2TradeDirection  direction;
   int               zone_id;
   string            zone_role;
   double            zone_lower;
   double            zone_upper;
  };

string E2TradePlanStatusName(const E2TradePlanStatus status)
  {
   switch(status)
     {
      case E2_PLAN_VALID:                   return("VALID_PLAN");
      case E2_PLAN_INVALID_INPUT:           return("INVALID_INPUT");
      case E2_PLAN_INVALID_DIRECTION:       return("INVALID_DIRECTION");
      case E2_PLAN_INVALID_ENTRY:           return("INVALID_ENTRY");
      case E2_PLAN_INVALID_STOP:            return("INVALID_STOP");
      case E2_PLAN_INVALID_TAKE_PROFIT:     return("INVALID_TAKE_PROFIT");
      case E2_PLAN_INVALID_RR:              return("INVALID_RR");
      case E2_PLAN_POSITION_SIZING_FAILED:  return("POSITION_SIZING_FAILED");
      case E2_PLAN_NORMALIZATION_FAILED:     return("INVALID_SYMBOL_SPEC");
      case E2_PLAN_INVALID_STRATEGY_SIGNAL:  return("INVALID_STRATEGY_SIGNAL");
      case E2_PLAN_INVALID_ZONE:             return("INVALID_ZONE");
      case E2_PLAN_MARKET_PRICE_UNAVAILABLE: return("MARKET_PRICE_UNAVAILABLE");
      case E2_PLAN_INVALID_SYMBOL_SPEC:      return("INVALID_SYMBOL_SPEC");
      case E2_PLAN_INVALID_ACCOUNT_EQUITY:   return("INVALID_ACCOUNT_EQUITY");
      case E2_PLAN_INVALID_RISK_PERCENT:     return("INVALID_RISK_PERCENT");
      case E2_PLAN_STOP_TOO_CLOSE:           return("STOP_TOO_CLOSE");
      case E2_PLAN_LOSS_CALCULATION_FAILED:  return("LOSS_CALCULATION_FAILED");
      case E2_PLAN_VOLUME_CALCULATION_FAILED:return("VOLUME_CALCULATION_FAILED");
      case E2_PLAN_VOLUME_BELOW_MINIMUM:     return("VOLUME_BELOW_MINIMUM");
      case E2_PLAN_VOLUME_ABOVE_MAXIMUM:     return("VOLUME_ABOVE_MAXIMUM");
      default:                                return("RISK_EXCEEDED");
     }
  }

class E2TradePlanner
  {
private:
   E2SymbolInfo      *m_symbol_info;
   E2PositionSizer   *m_position_sizer;
   E2Logger          *m_logger;
   E2Config          m_configuration;

   double NormalizeDown(const double value,const E2SymbolSpecification &specification) const { return(NormalizeDouble(MathFloor(value/specification.tick_size+1e-10)*specification.tick_size,specification.digits)); }
   double NormalizeUp(const double value,const E2SymbolSpecification &specification) const { return(NormalizeDouble(MathCeil(value/specification.tick_size-1e-10)*specification.tick_size,specification.digits)); }
   void MapSizingFailure(E2TradePlan &plan) const
     {
      if(plan.sizing_status==E2_SIZING_ACCOUNT_DATA_UNAVAILABLE) plan.status=E2_PLAN_INVALID_ACCOUNT_EQUITY;
      else if(plan.sizing_status==E2_SIZING_SYMBOL_DATA_UNAVAILABLE) plan.status=E2_PLAN_INVALID_SYMBOL_SPEC;
      else if(plan.sizing_status==E2_SIZING_CALCULATION_FAILED) plan.status=E2_PLAN_LOSS_CALCULATION_FAILED;
      else if(plan.sizing_status==E2_SIZING_VOLUME_BELOW_MINIMUM) plan.status=E2_PLAN_VOLUME_BELOW_MINIMUM;
      else if(plan.sizing_status==E2_SIZING_VOLUME_ABOVE_MAXIMUM) plan.status=E2_PLAN_VOLUME_ABOVE_MAXIMUM;
      else if(plan.sizing_status==E2_SIZING_RISK_EXCEEDS_LIMIT) plan.status=E2_PLAN_RISK_EXCEEDED;
      else plan.status=E2_PLAN_VOLUME_CALCULATION_FAILED;
     }

   void ResetPlan(E2TradePlan &plan)
     {
      plan.status=E2_PLAN_INVALID_INPUT;
      plan.ready=false;
      plan.valid=false;
      plan.evaluation_time=0;
      plan.sizing_status=E2_SIZING_INVALID_INPUT;
      plan.symbol="";
      plan.direction=E2_DIRECTION_BUY;
      plan.zone_id=-1; plan.zone_role=""; plan.zone_lower=0.0; plan.zone_upper=0.0;
      plan.bid=0.0; plan.ask=0.0; plan.entry_side=""; plan.spread_points=0.0; plan.spread_pips=0.0;
      plan.entry_price=0.0;
      plan.stop_loss_price=0.0;
      plan.take_profit_price=0.0;
      plan.requested_reward_risk=0.0;
      plan.actual_reward_risk=0.0;
      plan.volume=0.0;
      plan.raw_volume=0.0; plan.loss_per_lot=0.0; plan.account_equity=0.0; plan.risk_percent=0.0; plan.volume_min=0.0; plan.volume_max=0.0; plan.volume_step=0.0;
      plan.target_risk_money=0.0;
      plan.actual_risk_money=0.0;
      plan.actual_risk_percent=0.0;
      plan.stop_distance_price=0.0;
      plan.stop_distance_pips=0.0;
      plan.expected_reward_money=0.0;
     }

   void ReportDebug(const string message) const
     {
      if(m_logger!=NULL)
         m_logger.Debug(message,"TradePlan");
     }

public:
                     E2TradePlanner(void) : m_symbol_info(NULL),m_position_sizer(NULL),m_logger(NULL) {}

   void              Initialize(const E2Config &configuration,E2SymbolInfo &symbol_info,E2PositionSizer &position_sizer,E2Logger &logger)
     {
      m_configuration=configuration;
      m_symbol_info=&symbol_info;
      m_position_sizer=&position_sizer;
      m_logger=&logger;
     }

   bool              CreatePlan(const E2TradeIntent &intent,E2TradePlan &plan)
     {
      ResetPlan(plan);
      if(m_symbol_info==NULL || m_position_sizer==NULL || intent.symbol=="")
         return(false);
      if(intent.direction!=E2_DIRECTION_BUY && intent.direction!=E2_DIRECTION_SELL)
        {
         plan.status=E2_PLAN_INVALID_DIRECTION;
         return(false);
        }
      if(intent.entry_price<=0.0)
        {
         plan.status=E2_PLAN_INVALID_ENTRY;
         return(false);
        }
      if(intent.stop_loss_price<=0.0)
        {
         plan.status=E2_PLAN_INVALID_STOP;
         return(false);
        }
      if(intent.reward_risk_target<=0.0)
        {
         plan.status=E2_PLAN_INVALID_RR;
         return(false);
        }

      if(!m_symbol_info.IsInitialized() || m_symbol_info.Specification().symbol!=intent.symbol)
         if(!m_symbol_info.Refresh(intent.symbol))
           {
            plan.status=E2_PLAN_NORMALIZATION_FAILED;
            return(false);
           }

      E2SymbolSpecification specification=m_symbol_info.Specification();
      plan.symbol=intent.symbol;
      plan.direction=intent.direction;
      plan.requested_reward_risk=intent.reward_risk_target;
      plan.entry_price=m_symbol_info.NormalizePrice(intent.entry_price);
      plan.stop_loss_price=m_symbol_info.NormalizePrice(intent.stop_loss_price);
      if(plan.entry_price<=0.0 || plan.stop_loss_price<=0.0)
        {
         plan.status=E2_PLAN_NORMALIZATION_FAILED;
         return(false);
        }

      if((plan.direction==E2_DIRECTION_BUY && plan.stop_loss_price>=plan.entry_price) ||
         (plan.direction==E2_DIRECTION_SELL && plan.stop_loss_price<=plan.entry_price))
        {
         plan.status=E2_PLAN_INVALID_STOP;
         return(false);
        }

      plan.stop_distance_price=MathAbs(plan.entry_price-plan.stop_loss_price);
      plan.stop_distance_pips=plan.stop_distance_price/specification.pip_size;
      const double raw_take_profit=(plan.direction==E2_DIRECTION_BUY ?
                                   plan.entry_price+plan.stop_distance_price*plan.requested_reward_risk :
                                   plan.entry_price-plan.stop_distance_price*plan.requested_reward_risk);
      plan.take_profit_price=m_symbol_info.NormalizePrice(raw_take_profit);
      if((plan.direction==E2_DIRECTION_BUY && plan.take_profit_price<=plan.entry_price) ||
         (plan.direction==E2_DIRECTION_SELL && plan.take_profit_price>=plan.entry_price))
        {
         plan.status=E2_PLAN_INVALID_TAKE_PROFIT;
         return(false);
        }

      plan.actual_reward_risk=MathAbs(plan.take_profit_price-plan.entry_price)/plan.stop_distance_price;
      // Tick rounding can move TP by at most half a tick; this tolerance is
      // the corresponding RR deviation, with a small numeric floor.
      const double rr_tolerance=MathMax(0.001,specification.tick_size/(plan.stop_distance_price*2.0)+0.00000001);
      if(MathAbs(plan.actual_reward_risk-plan.requested_reward_risk)>rr_tolerance)
        {
         plan.status=E2_PLAN_INVALID_TAKE_PROFIT;
         return(false);
        }

      E2PositionSizingResult sizing;
      if(!m_position_sizer.Calculate(plan.symbol,plan.direction,plan.entry_price,plan.stop_loss_price,sizing))
        {
         plan.status=E2_PLAN_POSITION_SIZING_FAILED;
         plan.sizing_status=sizing.status;
         return(false);
        }

      plan.sizing_status=sizing.status;
      plan.volume=sizing.volume;
      plan.raw_volume=sizing.raw_volume;
      plan.loss_per_lot=sizing.monetary_loss_per_lot;
      plan.account_equity=sizing.risk_base_value;
      plan.risk_percent=m_configuration.risk_percent;
      plan.volume_min=specification.volume_min;
      plan.volume_max=specification.volume_max;
      plan.volume_step=specification.volume_step;
      plan.target_risk_money=sizing.target_risk_money;
      plan.actual_risk_money=sizing.actual_risk_money;
      plan.actual_risk_percent=sizing.actual_risk_percent;
      plan.expected_reward_money=plan.actual_risk_money*plan.actual_reward_risk;
      plan.status=E2_PLAN_VALID;
      plan.ready=true;
      plan.valid=true;
      return(true);
     }

   bool CreateStrategyPlan(const E2StrategyPlanRequest &request,E2TradePlan &plan)
     {
      ResetPlan(plan);
      plan.evaluation_time=request.evaluation_time;
      plan.symbol=request.symbol; plan.zone_id=request.zone_id; plan.zone_role=request.zone_role; plan.zone_lower=request.zone_lower; plan.zone_upper=request.zone_upper;
      if(!request.valid_strategy_signal){plan.status=E2_PLAN_INVALID_STRATEGY_SIGNAL;return(false);}
      if(request.direction!=E2_DIRECTION_BUY && request.direction!=E2_DIRECTION_SELL){plan.status=E2_PLAN_INVALID_DIRECTION;return(false);}
      if(request.symbol=="" || m_symbol_info==NULL || m_position_sizer==NULL || !m_symbol_info.Refresh(request.symbol)){plan.status=E2_PLAN_INVALID_SYMBOL_SPEC;return(false);}
      E2SymbolSpecification specification=m_symbol_info.Specification();
      if(specification.pip_size<=0.0 || specification.tick_size<=0.0 || specification.volume_min<=0.0){plan.status=E2_PLAN_INVALID_SYMBOL_SPEC;return(false);}
      if((request.direction==E2_DIRECTION_BUY && (request.zone_role!="SUPPORT" || request.zone_lower<=0.0 || request.zone_upper<request.zone_lower)) || (request.direction==E2_DIRECTION_SELL && (request.zone_role!="RESISTANCE" || request.zone_lower<=0.0 || request.zone_upper<request.zone_lower))){plan.status=E2_PLAN_INVALID_ZONE;return(false);}
      if(m_configuration.risk_percent<=0.0){plan.status=E2_PLAN_INVALID_RISK_PERCENT;return(false);}
      MqlTick tick;
      if(!SymbolInfoTick(request.symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0 || !MathIsValidNumber(tick.bid) || !MathIsValidNumber(tick.ask)){plan.status=E2_PLAN_MARKET_PRICE_UNAVAILABLE;return(false);}
      plan.bid=tick.bid;plan.ask=tick.ask;plan.spread_points=(tick.ask-tick.bid)/specification.point;plan.spread_pips=(tick.ask-tick.bid)/specification.pip_size;
      E2TradeIntent intent;intent.symbol=request.symbol;intent.direction=request.direction;intent.entry_price=(request.direction==E2_DIRECTION_BUY ? tick.ask : tick.bid);intent.stop_loss_price=(request.direction==E2_DIRECTION_BUY ? NormalizeDown(request.zone_lower-m_configuration.stop_loss_zone_buffer_pips*specification.pip_size,specification) : NormalizeUp(request.zone_upper+m_configuration.stop_loss_zone_buffer_pips*specification.pip_size,specification));intent.reward_risk_target=m_configuration.reward_risk_target;intent.strategy_id="E2";intent.setup_time=request.evaluation_time;intent.reason_tag="strategy signal";
      const double minimum_stop_distance=specification.stops_level_points*specification.point;
      if((request.direction==E2_DIRECTION_BUY && intent.stop_loss_price>=intent.entry_price) || (request.direction==E2_DIRECTION_SELL && intent.stop_loss_price<=intent.entry_price)){plan.status=E2_PLAN_INVALID_STOP;return(false);}
      if(minimum_stop_distance>0.0 && MathAbs(intent.entry_price-intent.stop_loss_price)+1e-12<minimum_stop_distance){plan.status=E2_PLAN_STOP_TOO_CLOSE;return(false);}
      if(!CreatePlan(intent,plan)){if(plan.status==E2_PLAN_POSITION_SIZING_FAILED)MapSizingFailure(plan);return(false);}
      plan.evaluation_time=request.evaluation_time;plan.zone_id=request.zone_id;plan.zone_role=request.zone_role;plan.zone_lower=request.zone_lower;plan.zone_upper=request.zone_upper;plan.bid=tick.bid;plan.ask=tick.ask;plan.entry_side=(request.direction==E2_DIRECTION_BUY ? "ASK" : "BID");plan.spread_points=(tick.ask-tick.bid)/specification.point;plan.spread_pips=(tick.ask-tick.bid)/specification.pip_size;
      if(minimum_stop_distance>0.0 && MathAbs(plan.take_profit_price-plan.entry_price)+1e-12<minimum_stop_distance){plan.status=E2_PLAN_INVALID_TAKE_PROFIT;plan.valid=false;return(false);}
      plan.status=E2_PLAN_VALID;plan.ready=true;plan.valid=true;return(true);
     }

   void              LogDiagnostic(const E2TradePlan &plan) const
     {
      ReportDebug("Evaluation="+TimeToString(plan.evaluation_time,TIME_DATE|TIME_MINUTES)+", valid="+(plan.valid ? "yes" : "no")+", direction="+(plan.direction==E2_DIRECTION_BUY ? "LONG" : "SHORT")+", entry="+DoubleToString(plan.entry_price,8)+", SL="+DoubleToString(plan.stop_loss_price,8)+", TP="+DoubleToString(plan.take_profit_price,8)+", stopPips="+DoubleToString(plan.stop_distance_pips,2)+", RR="+DoubleToString(plan.actual_reward_risk,2)+", equity="+DoubleToString(plan.account_equity,2)+", targetRisk="+DoubleToString(plan.target_risk_money,2)+", rawVolume="+DoubleToString(plan.raw_volume,4)+", volume="+DoubleToString(plan.volume,4)+", actualRisk="+DoubleToString(plan.actual_risk_money,2)+", actualRiskPct="+DoubleToString(plan.actual_risk_percent,4)+", reason="+E2TradePlanStatusName(plan.status)+".");
     }
  };

#endif // E2_RISK_E2TRADEPLANNER_MQH
