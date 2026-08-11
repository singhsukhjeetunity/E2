#ifndef E2_EXECUTION_E2ORDEREXECUTOR_MQH
#define E2_EXECUTION_E2ORDEREXECUTOR_MQH

#include <Trade\\Trade.mqh>
#include "..\\core\\E2Config.mqh"
#include "..\\core\\E2SymbolInfo.mqh"
#include "..\\core\\E2AccountInfo.mqh"
#include "..\\risk\\E2TradePlanner.mqh"
#include "E2PositionGuard.mqh"

enum E2ExecutionStatus { E2_EXECUTION_EXECUTED, E2_EXECUTION_TRADING_DISABLED, E2_EXECUTION_INVALID_PLAN, E2_EXECUTION_SYMBOL_UNAVAILABLE, E2_EXECUTION_MARKET_PRICE_UNAVAILABLE, E2_EXECUTION_PRICE_DEVIATION_EXCEEDED, E2_EXECUTION_INVALID_CURRENT_GEOMETRY, E2_EXECUTION_BROKER_STOP_CONSTRAINT, E2_EXECUTION_TRADING_NOT_ALLOWED, E2_EXECUTION_INSUFFICIENT_MARGIN, E2_EXECUTION_ORDER_REJECTED, E2_EXECUTION_FAILED };

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
      case E2_EXECUTION_EXECUTED: return("EXECUTED"); case E2_EXECUTION_TRADING_DISABLED: return("TRADING_DISABLED"); case E2_EXECUTION_INVALID_PLAN: return("INVALID_PLAN"); case E2_EXECUTION_SYMBOL_UNAVAILABLE: return("SYMBOL_UNAVAILABLE"); case E2_EXECUTION_MARKET_PRICE_UNAVAILABLE: return("MARKET_PRICE_UNAVAILABLE"); case E2_EXECUTION_PRICE_DEVIATION_EXCEEDED: return("PRICE_DEVIATION_EXCEEDED"); case E2_EXECUTION_INVALID_CURRENT_GEOMETRY: return("INVALID_CURRENT_GEOMETRY"); case E2_EXECUTION_BROKER_STOP_CONSTRAINT: return("BROKER_STOP_CONSTRAINT"); case E2_EXECUTION_TRADING_NOT_ALLOWED: return("TRADING_NOT_ALLOWED"); case E2_EXECUTION_INSUFFICIENT_MARGIN: return("INSUFFICIENT_MARGIN"); case E2_EXECUTION_ORDER_REJECTED: return("ORDER_REJECTED"); default: return("EXECUTION_FAILED");
     }
  }

class E2OrderExecutor
  {
private:
   CTrade m_trade; E2SymbolInfo *m_symbol_info; E2AccountInfo *m_account_info; E2Logger *m_logger;
   ulong m_magic_number; bool m_trading_enabled; double m_max_entry_deviation_pips;
   E2PositionGuard *m_guard;

   void ResetResult(E2ExecutionResult &result)
     {
      result.status=E2_EXECUTION_FAILED; result.retcode=0; result.retcode_description=""; result.order_ticket=0; result.deal_ticket=0; result.requested_volume=0.0; result.executed_volume=0.0; result.planned_entry_price=0.0; result.requested_market_price=0.0; result.actual_execution_price=0.0; result.stop_loss_price=0.0; result.take_profit_price=0.0; result.symbol=""; result.direction=E2_DIRECTION_BUY;
     }
   void Fail(E2ExecutionResult &result,const E2ExecutionStatus status,const string description="") const
     {
      result.status=status; if(description!="") result.retcode_description=description;
      if(m_logger!=NULL) m_logger.Error("Execution failed: status="+E2ExecutionStatusName(status)+", retcode="+IntegerToString((int)result.retcode)+", description="+result.retcode_description+".","Execution");
     }
   bool SuccessfulRetcode(const uint code) const { return(code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL); }

public:
   E2OrderExecutor(void) : m_symbol_info(NULL),m_account_info(NULL),m_logger(NULL),m_magic_number(0),m_trading_enabled(false),m_max_entry_deviation_pips(0.0),m_guard(NULL) {}
   void Initialize(const E2Config &config,E2SymbolInfo &symbol_info,E2AccountInfo &account_info,E2PositionGuard &guard,E2Logger &logger)
     {
      m_symbol_info=&symbol_info; m_account_info=&account_info; m_guard=&guard; m_logger=&logger; m_magic_number=config.expert_magic_number; m_trading_enabled=config.trading_enabled; m_max_entry_deviation_pips=config.max_entry_deviation_pips;
      m_trade.SetAsyncMode(false); m_trade.SetExpertMagicNumber(m_magic_number);
     }

   bool Execute(const E2TradePlan &plan,const string comment,E2ExecutionResult &result)
     {
      ResetResult(result); result.symbol=plan.symbol; result.direction=plan.direction; result.planned_entry_price=plan.entry_price; result.requested_volume=plan.volume; result.stop_loss_price=plan.stop_loss_price; result.take_profit_price=plan.take_profit_price;
      if(!m_trading_enabled) { Fail(result,E2_EXECUTION_TRADING_DISABLED); return(false); }
      E2PositionGuardResult guard_result;
      if(m_guard==NULL || !m_guard.CanOpen(plan,guard_result)) { Fail(result,E2_EXECUTION_INVALID_PLAN,"PositionGuard="+E2PositionGuardStatusName(guard_result.status)); return(false); }
      if(plan.status!=E2_PLAN_VALID || plan.symbol=="" || plan.volume<=0.0 || !MathIsValidNumber(plan.entry_price) || !MathIsValidNumber(plan.stop_loss_price) || !MathIsValidNumber(plan.take_profit_price)) { Fail(result,E2_EXECUTION_INVALID_PLAN); return(false); }
      if(m_symbol_info==NULL || m_account_info==NULL || (!m_symbol_info.IsInitialized() && !m_symbol_info.Refresh(plan.symbol)) || (m_symbol_info.IsInitialized() && m_symbol_info.Specification().symbol!=plan.symbol && !m_symbol_info.Refresh(plan.symbol))) { Fail(result,E2_EXECUTION_SYMBOL_UNAVAILABLE); return(false); }
      E2SymbolSpecification spec=m_symbol_info.Specification();
      double valid_volume=0.0;
      if(!m_symbol_info.NormalizeVolume(plan.volume,valid_volume) || MathAbs(valid_volume-plan.volume)>spec.volume_step*0.000001) { Fail(result,E2_EXECUTION_INVALID_PLAN,"Invalid broker volume."); return(false); }
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) { Fail(result,E2_EXECUTION_TRADING_NOT_ALLOWED); return(false); }

      MqlTick tick;
      if(!SymbolInfoTick(plan.symbol,tick)) { Fail(result,E2_EXECUTION_MARKET_PRICE_UNAVAILABLE); return(false); }
      result.requested_market_price=(plan.direction==E2_DIRECTION_BUY ? tick.ask : tick.bid);
      if(result.requested_market_price<=0.0 || !MathIsValidNumber(result.requested_market_price)) { Fail(result,E2_EXECUTION_MARKET_PRICE_UNAVAILABLE); return(false); }
      if(MathAbs(result.requested_market_price-plan.entry_price)>m_max_entry_deviation_pips*spec.pip_size) { Fail(result,E2_EXECUTION_PRICE_DEVIATION_EXCEEDED); return(false); }
      if((plan.direction==E2_DIRECTION_BUY && !(plan.stop_loss_price<result.requested_market_price && result.requested_market_price<plan.take_profit_price)) || (plan.direction==E2_DIRECTION_SELL && !(plan.take_profit_price<result.requested_market_price && result.requested_market_price<plan.stop_loss_price))) { Fail(result,E2_EXECUTION_INVALID_CURRENT_GEOMETRY); return(false); }
      const double minimum_stop_distance=MathMax((double)SymbolInfoInteger(plan.symbol,SYMBOL_TRADE_STOPS_LEVEL),(double)SymbolInfoInteger(plan.symbol,SYMBOL_TRADE_FREEZE_LEVEL))*spec.point;
      if(minimum_stop_distance>0.0 && (MathAbs(result.requested_market_price-plan.stop_loss_price)<minimum_stop_distance || MathAbs(plan.take_profit_price-result.requested_market_price)<minimum_stop_distance)) { Fail(result,E2_EXECUTION_BROKER_STOP_CONSTRAINT); return(false); }

      if(!m_account_info.Refresh()) { Fail(result,E2_EXECUTION_TRADING_NOT_ALLOWED,"Account data unavailable."); return(false); }
      const ENUM_ORDER_TYPE order_type=(plan.direction==E2_DIRECTION_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL); double margin=0.0;
      if(OrderCalcMargin(order_type,plan.symbol,plan.volume,result.requested_market_price,margin) && margin>m_account_info.FreeMargin()) { Fail(result,E2_EXECUTION_INSUFFICIENT_MARGIN); return(false); }
      if(!m_trade.SetTypeFillingBySymbol(plan.symbol)) { Fail(result,E2_EXECUTION_FAILED,"Unable to set symbol filling mode."); return(false); }
      m_trade.SetExpertMagicNumber(m_magic_number);
      if(m_logger!=NULL) m_logger.Info((plan.direction==E2_DIRECTION_BUY ? "BUY " : "SELL ")+plan.symbol+" volume="+DoubleToString(plan.volume,4)+", planned_entry="+DoubleToString(plan.entry_price,spec.digits)+", market_price="+DoubleToString(result.requested_market_price,spec.digits)+", SL="+DoubleToString(plan.stop_loss_price,spec.digits)+", TP="+DoubleToString(plan.take_profit_price,spec.digits)+".","Execution");
      const bool sent=(plan.direction==E2_DIRECTION_BUY ? m_trade.Buy(plan.volume,plan.symbol,result.requested_market_price,plan.stop_loss_price,plan.take_profit_price,comment) : m_trade.Sell(plan.volume,plan.symbol,result.requested_market_price,plan.stop_loss_price,plan.take_profit_price,comment));
      result.retcode=m_trade.ResultRetcode(); result.retcode_description=m_trade.ResultRetcodeDescription(); result.order_ticket=m_trade.ResultOrder(); result.deal_ticket=m_trade.ResultDeal(); result.executed_volume=m_trade.ResultVolume(); result.actual_execution_price=m_trade.ResultPrice();
      if(!sent || !SuccessfulRetcode(result.retcode)) { Fail(result,E2_EXECUTION_ORDER_REJECTED); return(false); }
      result.status=E2_EXECUTION_EXECUTED;
      if(m_logger!=NULL) m_logger.Info("Execution succeeded: deal="+StringFormat("%I64u",result.deal_ticket)+", order="+StringFormat("%I64u",result.order_ticket)+", price="+DoubleToString(result.actual_execution_price,spec.digits)+", retcode="+IntegerToString((int)result.retcode)+".","Execution");
      return(true);
     }
  };

#endif // E2_EXECUTION_E2ORDEREXECUTOR_MQH
