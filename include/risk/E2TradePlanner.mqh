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
   E2_PLAN_NORMALIZATION_FAILED
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
   E2TradePlanStatus status;
   E2SizingStatus    sizing_status;
   string            symbol;
   E2TradeDirection  direction;
   double            entry_price;
   double            stop_loss_price;
   double            take_profit_price;
   double            requested_reward_risk;
   double            actual_reward_risk;
   double            volume;
   double            target_risk_money;
   double            actual_risk_money;
   double            actual_risk_percent;
   double            stop_distance_price;
   double            stop_distance_pips;
   double            expected_reward_money;
  };

string E2TradePlanStatusName(const E2TradePlanStatus status)
  {
   switch(status)
     {
      case E2_PLAN_VALID:                   return("VALID");
      case E2_PLAN_INVALID_INPUT:           return("INVALID_INPUT");
      case E2_PLAN_INVALID_DIRECTION:       return("INVALID_DIRECTION");
      case E2_PLAN_INVALID_ENTRY:           return("INVALID_ENTRY");
      case E2_PLAN_INVALID_STOP:            return("INVALID_STOP");
      case E2_PLAN_INVALID_TAKE_PROFIT:     return("INVALID_TAKE_PROFIT");
      case E2_PLAN_INVALID_RR:              return("INVALID_RR");
      case E2_PLAN_POSITION_SIZING_FAILED:  return("POSITION_SIZING_FAILED");
      default:                               return("NORMALIZATION_FAILED");
     }
  }

class E2TradePlanner
  {
private:
   E2SymbolInfo      *m_symbol_info;
   E2PositionSizer   *m_position_sizer;
   E2Logger          *m_logger;

   void ResetPlan(E2TradePlan &plan)
     {
      plan.status=E2_PLAN_INVALID_INPUT;
      plan.sizing_status=E2_SIZING_INVALID_INPUT;
      plan.symbol="";
      plan.direction=E2_DIRECTION_BUY;
      plan.entry_price=0.0;
      plan.stop_loss_price=0.0;
      plan.take_profit_price=0.0;
      plan.requested_reward_risk=0.0;
      plan.actual_reward_risk=0.0;
      plan.volume=0.0;
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
         m_logger.Debug(message,"TradePlanner");
     }

public:
                     E2TradePlanner(void) : m_symbol_info(NULL),m_position_sizer(NULL),m_logger(NULL) {}

   void              Initialize(E2SymbolInfo &symbol_info,E2PositionSizer &position_sizer,E2Logger &logger)
     {
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
      plan.target_risk_money=sizing.target_risk_money;
      plan.actual_risk_money=sizing.actual_risk_money;
      plan.actual_risk_percent=sizing.actual_risk_percent;
      plan.expected_reward_money=plan.actual_risk_money*plan.actual_reward_risk;
      plan.status=E2_PLAN_VALID;
      return(true);
     }

   void              LogDiagnostic(const E2TradePlan &plan) const
     {
      ReportDebug("Status="+E2TradePlanStatusName(plan.status)+", entry="+DoubleToString(plan.entry_price,8)+", SL="+DoubleToString(plan.stop_loss_price,8)+", TP="+DoubleToString(plan.take_profit_price,8)+", requested RR="+DoubleToString(plan.requested_reward_risk,2)+", actual RR="+DoubleToString(plan.actual_reward_risk,4)+", volume="+DoubleToString(plan.volume,4)+", target risk="+DoubleToString(plan.target_risk_money,2)+", actual risk="+DoubleToString(plan.actual_risk_money,2)+", sizing="+E2SizingStatusName(plan.sizing_status)+".");
     }
  };

#endif // E2_RISK_E2TRADEPLANNER_MQH
