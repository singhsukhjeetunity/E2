#ifndef E2_EXECUTION_E2ORDEREXECUTOR_MQH
#define E2_EXECUTION_E2ORDEREXECUTOR_MQH

#include <Trade\\Trade.mqh>
#include "..\\core\\E2Config.mqh"
#include "..\\core\\E2SymbolInfo.mqh"
#include "..\\core\\E2AccountInfo.mqh"
#include "..\\risk\\E2TradePlanner.mqh"
#include "E2PositionGuard.mqh"
#include "E2PositionManager.mqh"
#include "E2ExecutionSafety.mqh"

enum E2ExecutionStatus { E2_EXECUTION_EXECUTED, E2_EXECUTION_TRADING_DISABLED, E2_EXECUTION_INVALID_PLAN, E2_EXECUTION_SYMBOL_UNAVAILABLE, E2_EXECUTION_MARKET_PRICE_UNAVAILABLE, E2_EXECUTION_PRICE_DEVIATION_EXCEEDED, E2_EXECUTION_INVALID_CURRENT_GEOMETRY, E2_EXECUTION_BROKER_STOP_CONSTRAINT, E2_EXECUTION_TRADING_NOT_ALLOWED, E2_EXECUTION_INSUFFICIENT_MARGIN, E2_EXECUTION_ORDER_REJECTED, E2_EXECUTION_FAILED, E2_EXECUTION_SPREAD_TOO_HIGH, E2_EXECUTION_NO_VALID_QUOTE, E2_EXECUTION_MARKET_CLOSED, E2_EXECUTION_SYMBOL_TRADING_DISABLED, E2_EXECUTION_VOLUME_INVALID, E2_EXECUTION_MARGIN_INSUFFICIENT, E2_EXECUTION_EXECUTION_COOLDOWN, E2_EXECUTION_TRADE_CONTEXT_UNAVAILABLE, E2_EXECUTION_POSITION_ALREADY_OPEN, E2_EXECUTION_PENDING_ORDER_EXISTS, E2_EXECUTION_DIRECTION_CONFLICT, E2_EXECUTION_POSITION_STATE_UNAVAILABLE, E2_EXECUTION_ACCOUNT_MODE_UNSUPPORTED };

struct E2ExecutionResult
  {
   E2ExecutionStatus status;
   uint retcode; string retcode_description; ulong order_ticket; ulong deal_ticket;
   double requested_volume; double executed_volume; double planned_entry_price; double requested_market_price; double actual_execution_price; double stop_loss_price; double take_profit_price;
   string symbol; E2TradeDirection direction;
  };

string E2ExecutionStatusName(const E2ExecutionStatus status)
  {
   switch(status)
     {
      case E2_EXECUTION_EXECUTED: return("EXECUTED"); case E2_EXECUTION_TRADING_DISABLED: return("TRADING_DISABLED"); case E2_EXECUTION_INVALID_PLAN: return("INVALID_PLAN"); case E2_EXECUTION_SYMBOL_UNAVAILABLE: return("SYMBOL_UNAVAILABLE"); case E2_EXECUTION_MARKET_PRICE_UNAVAILABLE: return("MARKET_PRICE_UNAVAILABLE"); case E2_EXECUTION_PRICE_DEVIATION_EXCEEDED: return("PRICE_DEVIATION_EXCEEDED"); case E2_EXECUTION_INVALID_CURRENT_GEOMETRY: return("INVALID_CURRENT_GEOMETRY"); case E2_EXECUTION_BROKER_STOP_CONSTRAINT: return("BROKER_STOP_CONSTRAINT"); case E2_EXECUTION_TRADING_NOT_ALLOWED: return("TRADING_NOT_ALLOWED"); case E2_EXECUTION_INSUFFICIENT_MARGIN: return("INSUFFICIENT_MARGIN"); case E2_EXECUTION_ORDER_REJECTED: return("ORDER_REJECTED"); case E2_EXECUTION_SPREAD_TOO_HIGH: return("SPREAD_TOO_HIGH"); case E2_EXECUTION_NO_VALID_QUOTE: return("NO_VALID_QUOTE"); case E2_EXECUTION_MARKET_CLOSED: return("MARKET_CLOSED"); case E2_EXECUTION_SYMBOL_TRADING_DISABLED: return("SYMBOL_TRADING_DISABLED"); case E2_EXECUTION_VOLUME_INVALID: return("VOLUME_INVALID"); case E2_EXECUTION_MARGIN_INSUFFICIENT: return("MARGIN_INSUFFICIENT"); case E2_EXECUTION_EXECUTION_COOLDOWN: return("EXECUTION_COOLDOWN"); case E2_EXECUTION_TRADE_CONTEXT_UNAVAILABLE: return("TRADE_CONTEXT_UNAVAILABLE"); case E2_EXECUTION_POSITION_ALREADY_OPEN: return("POSITION_ALREADY_OPEN"); case E2_EXECUTION_PENDING_ORDER_EXISTS: return("PENDING_ORDER_EXISTS"); case E2_EXECUTION_DIRECTION_CONFLICT: return("DIRECTION_CONFLICT"); case E2_EXECUTION_POSITION_STATE_UNAVAILABLE: return("POSITION_STATE_UNAVAILABLE"); case E2_EXECUTION_ACCOUNT_MODE_UNSUPPORTED: return("ACCOUNT_MODE_UNSUPPORTED"); default: return("EXECUTION_FAILED");
     }
  }

class E2OrderExecutor
  {
private:
   CTrade m_trade; E2SymbolInfo *m_symbol_info; E2AccountInfo *m_account_info; E2Logger *m_logger;
   ulong m_magic_number; bool m_trading_enabled; double m_max_entry_deviation_pips;
   E2PositionGuard *m_guard;
   E2ExecutionSafety *m_safety;
   E2PositionManager *m_position_manager;

   void ResetResult(E2ExecutionResult &result)
     {
      result.status=E2_EXECUTION_FAILED; result.retcode=0; result.retcode_description=""; result.order_ticket=0; result.deal_ticket=0; result.requested_volume=0.0; result.executed_volume=0.0; result.planned_entry_price=0.0; result.requested_market_price=0.0; result.actual_execution_price=0.0; result.stop_loss_price=0.0; result.take_profit_price=0.0; result.symbol=""; result.direction=E2_DIRECTION_BUY;
     }
   void Fail(E2ExecutionResult &result,const E2ExecutionStatus status,const string description="") const
     {
      result.status=status; if(description!="") result.retcode_description=description;
      if(m_logger!=NULL)
        {
         const string message="Execution rejected: status="+E2ExecutionStatusName(status)+", retcode="+IntegerToString((int)result.retcode)+", description="+result.retcode_description+".";
         if(status==E2_EXECUTION_FAILED) m_logger.Error(message,"Execution"); else m_logger.Warning(message,"Execution");
        }
     }
   bool SuccessfulRetcode(const uint code) const { return(code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL); }
   bool TemporaryExecutionRetcode(const uint code) const { return(code==TRADE_RETCODE_LOCKED || code==TRADE_RETCODE_TOO_MANY_REQUESTS); }
   E2ExecutionStatus GuardStatus(const E2PositionGuardStatus status) const
     {
      switch(status)
        {
         case E2_GUARD_POSITION_ALREADY_OPEN: return(E2_EXECUTION_POSITION_ALREADY_OPEN);
         case E2_GUARD_PENDING_ORDER_EXISTS: return(E2_EXECUTION_PENDING_ORDER_EXISTS);
         case E2_GUARD_DIRECTION_CONFLICT: return(E2_EXECUTION_DIRECTION_CONFLICT);
         case E2_GUARD_ACCOUNT_MODE_UNSUPPORTED: return(E2_EXECUTION_ACCOUNT_MODE_UNSUPPORTED);
         default: return(E2_EXECUTION_POSITION_STATE_UNAVAILABLE);
        }
     }
   E2ExecutionStatus SafetyStatus(const E2ExecutionSafetyStatus status) const
     {
      switch(status)
        {
         case E2_SAFETY_TRADING_DISABLED: return(E2_EXECUTION_TRADING_DISABLED);
         case E2_SAFETY_SYMBOL_UNAVAILABLE: return(E2_EXECUTION_SYMBOL_UNAVAILABLE);
         case E2_SAFETY_SPREAD_TOO_HIGH: return(E2_EXECUTION_SPREAD_TOO_HIGH);
         case E2_SAFETY_MARKET_CLOSED: return(E2_EXECUTION_MARKET_CLOSED);
         case E2_SAFETY_SYMBOL_TRADING_DISABLED: return(E2_EXECUTION_SYMBOL_TRADING_DISABLED);
         case E2_SAFETY_TRADING_NOT_ALLOWED: return(E2_EXECUTION_TRADING_NOT_ALLOWED);
         case E2_SAFETY_VOLUME_INVALID: return(E2_EXECUTION_VOLUME_INVALID);
         case E2_SAFETY_EXECUTION_COOLDOWN: return(E2_EXECUTION_EXECUTION_COOLDOWN);
         case E2_SAFETY_TRADE_CONTEXT_UNAVAILABLE: return(E2_EXECUTION_TRADE_CONTEXT_UNAVAILABLE);
         default: return(E2_EXECUTION_NO_VALID_QUOTE);
        }
     }

public:
   E2OrderExecutor(void) : m_symbol_info(NULL),m_account_info(NULL),m_logger(NULL),m_magic_number(0),m_trading_enabled(false),m_max_entry_deviation_pips(0.0),m_guard(NULL),m_safety(NULL),m_position_manager(NULL) {}
   void Initialize(const E2Config &config,E2SymbolInfo &symbol_info,E2AccountInfo &account_info,E2PositionGuard &guard,E2PositionManager &position_manager,E2ExecutionSafety &safety,E2Logger &logger)
     {
      m_symbol_info=&symbol_info; m_account_info=&account_info; m_guard=&guard; m_position_manager=&position_manager; m_safety=&safety; m_logger=&logger; m_magic_number=config.expert_magic_number; m_trading_enabled=config.trading_enabled; m_max_entry_deviation_pips=config.max_entry_deviation_pips;
      m_trade.SetAsyncMode(false); m_trade.SetExpertMagicNumber(m_magic_number);
     }

   bool Execute(const E2TradePlan &plan,const string comment,E2ExecutionResult &result)
     {
      ResetResult(result); result.symbol=plan.symbol; result.direction=plan.direction; result.planned_entry_price=plan.entry_price; result.requested_volume=plan.volume; result.stop_loss_price=plan.stop_loss_price; result.take_profit_price=plan.take_profit_price;
      if(!m_trading_enabled) { Fail(result,E2_EXECUTION_TRADING_DISABLED); return(false); }
      if(plan.status!=E2_PLAN_VALID || plan.symbol=="" || plan.volume<=0.0 || !MathIsValidNumber(plan.entry_price) || !MathIsValidNumber(plan.stop_loss_price) || !MathIsValidNumber(plan.take_profit_price)) { Fail(result,E2_EXECUTION_INVALID_PLAN); return(false); }
      if(m_symbol_info==NULL || m_account_info==NULL || (!m_symbol_info.IsInitialized() && !m_symbol_info.Refresh(plan.symbol)) || (m_symbol_info.IsInitialized() && m_symbol_info.Specification().symbol!=plan.symbol && !m_symbol_info.Refresh(plan.symbol))) { Fail(result,E2_EXECUTION_SYMBOL_UNAVAILABLE); return(false); }
      E2SymbolSpecification spec=m_symbol_info.Specification();
      E2PositionGuardResult guard_result;
      if(m_guard==NULL || !m_guard.CanOpen(plan,guard_result)) { Fail(result,GuardStatus(guard_result.status),"PositionGuard="+E2PositionGuardStatusName(guard_result.status)); return(false); }
      E2ExecutionSafetyResult safety_result;
      if(m_safety==NULL || !m_safety.CanExecute(plan,spec,safety_result)) { Fail(result,m_safety==NULL ? E2_EXECUTION_FAILED : SafetyStatus(safety_result.status),m_safety==NULL ? "ExecutionSafety unavailable." : safety_result.reason); return(false); }
      MqlTick tick=safety_result.tick;
      result.requested_market_price=(plan.direction==E2_DIRECTION_BUY ? tick.ask : tick.bid);
      if(result.requested_market_price<=0.0 || !MathIsValidNumber(result.requested_market_price)) { Fail(result,E2_EXECUTION_MARKET_PRICE_UNAVAILABLE); return(false); }
      if(MathAbs(result.requested_market_price-plan.entry_price)>m_max_entry_deviation_pips*spec.pip_size) { Fail(result,E2_EXECUTION_PRICE_DEVIATION_EXCEEDED); return(false); }
      if((plan.direction==E2_DIRECTION_BUY && !(plan.stop_loss_price<result.requested_market_price && result.requested_market_price<plan.take_profit_price)) || (plan.direction==E2_DIRECTION_SELL && !(plan.take_profit_price<result.requested_market_price && result.requested_market_price<plan.stop_loss_price))) { Fail(result,E2_EXECUTION_INVALID_CURRENT_GEOMETRY); return(false); }
      const double minimum_stop_distance=MathMax((double)SymbolInfoInteger(plan.symbol,SYMBOL_TRADE_STOPS_LEVEL),(double)SymbolInfoInteger(plan.symbol,SYMBOL_TRADE_FREEZE_LEVEL))*spec.point;
      if(minimum_stop_distance>0.0 && (MathAbs(result.requested_market_price-plan.stop_loss_price)<minimum_stop_distance || MathAbs(plan.take_profit_price-result.requested_market_price)<minimum_stop_distance)) { Fail(result,E2_EXECUTION_BROKER_STOP_CONSTRAINT); return(false); }

      if(!m_account_info.Refresh()) { Fail(result,E2_EXECUTION_TRADING_NOT_ALLOWED,"Account data unavailable."); return(false); }
      const ENUM_ORDER_TYPE order_type=(plan.direction==E2_DIRECTION_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL); double margin=0.0;
      if(!OrderCalcMargin(order_type,plan.symbol,plan.volume,result.requested_market_price,margin) || !MathIsValidNumber(margin) || margin<0.0) { Fail(result,E2_EXECUTION_BROKER_STOP_CONSTRAINT,"Margin preflight unavailable."); return(false); }
      if(margin>m_account_info.FreeMargin()) { Fail(result,E2_EXECUTION_MARGIN_INSUFFICIENT); return(false); }
      if(!m_trade.SetTypeFillingBySymbol(plan.symbol)) { Fail(result,E2_EXECUTION_FAILED,"Unable to set symbol filling mode."); return(false); }
      m_trade.SetExpertMagicNumber(m_magic_number);
      if(m_logger!=NULL) m_logger.Debug("Attempt direction="+(plan.direction==E2_DIRECTION_BUY ? "BUY" : "SELL")+", symbol="+plan.symbol+", volume="+DoubleToString(plan.volume,4)+", plannedEntry="+DoubleToString(plan.entry_price,spec.digits)+", marketPrice="+DoubleToString(result.requested_market_price,spec.digits)+".","Execution");
      const bool sent=(plan.direction==E2_DIRECTION_BUY ? m_trade.Buy(plan.volume,plan.symbol,result.requested_market_price,plan.stop_loss_price,plan.take_profit_price,comment) : m_trade.Sell(plan.volume,plan.symbol,result.requested_market_price,plan.stop_loss_price,plan.take_profit_price,comment));
      result.retcode=m_trade.ResultRetcode(); result.retcode_description=m_trade.ResultRetcodeDescription(); result.order_ticket=m_trade.ResultOrder(); result.deal_ticket=m_trade.ResultDeal(); result.executed_volume=m_trade.ResultVolume(); result.actual_execution_price=m_trade.ResultPrice();
      if(!sent || !SuccessfulRetcode(result.retcode)) { Fail(result,TemporaryExecutionRetcode(result.retcode) ? E2_EXECUTION_TRADE_CONTEXT_UNAVAILABLE : E2_EXECUTION_ORDER_REJECTED); return(false); }
      result.status=E2_EXECUTION_EXECUTED;
      if(m_safety!=NULL) m_safety.RecordSuccessfulExecution();
      if(m_position_manager!=NULL) m_position_manager.Refresh();
      return(true);
     }
  };

#endif // E2_EXECUTION_E2ORDEREXECUTOR_MQH
