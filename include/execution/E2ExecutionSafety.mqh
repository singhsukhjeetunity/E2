#ifndef E2_EXECUTION_E2EXECUTIONSAFETY_MQH
#define E2_EXECUTION_E2EXECUTIONSAFETY_MQH

#include "..\\core\\E2Config.mqh"
#include "..\\core\\E2SymbolInfo.mqh"
#include "..\\risk\\E2TradePlanner.mqh"

enum E2ExecutionSafetyStatus
  {
   E2_SAFETY_CLEAR,
   E2_SAFETY_TRADING_DISABLED,
   E2_SAFETY_SYMBOL_UNAVAILABLE,
   E2_SAFETY_NO_VALID_QUOTE,
   E2_SAFETY_MARKET_CLOSED,
   E2_SAFETY_SYMBOL_TRADING_DISABLED,
   E2_SAFETY_TRADING_NOT_ALLOWED,
   E2_SAFETY_VOLUME_INVALID,
   E2_SAFETY_SPREAD_TOO_HIGH,
   E2_SAFETY_EXECUTION_COOLDOWN,
   E2_SAFETY_TRADE_CONTEXT_UNAVAILABLE
  };

struct E2ExecutionSafetyResult
  {
   E2ExecutionSafetyStatus status;
   MqlTick tick;
   double spread_pips;
   string reason;
  };

class E2ExecutionSafety
  {
private:
   bool m_trading_enabled;
   double m_max_spread_pips;
   int m_max_quote_age_seconds;
   int m_minimum_seconds_between_executions;
   datetime m_last_execution_time;
   E2Logger *m_logger;

   bool Reject(E2ExecutionSafetyResult &result,const E2ExecutionSafetyStatus status,const string reason) const
     {
      result.status=status;
      result.reason=reason;
      if(m_logger!=NULL)
         m_logger.Warning("Rejected: "+reason,"ExecutionSafety");
      return(false);
     }

   bool IsVolumeValid(const double volume,const E2SymbolSpecification &spec) const
     {
      if(!MathIsValidNumber(volume) || volume<=0.0 || spec.volume_min<=0.0 || spec.volume_max<spec.volume_min || spec.volume_step<=0.0)
         return(false);
      if(volume<spec.volume_min-1e-10 || volume>spec.volume_max+1e-10)
         return(false);
      const double steps=(volume-spec.volume_min)/spec.volume_step;
      return(MathAbs(steps-MathRound(steps))<=1e-7);
     }

   bool IsTradeSessionOpen(const string symbol,bool &session_metadata_available) const
     {
      session_metadata_available=false;
      const datetime now=TimeCurrent();
      MqlDateTime now_parts;
      TimeToStruct(now,now_parts);
      const int now_seconds=now_parts.hour*3600+now_parts.min*60+now_parts.sec;
      const ENUM_DAY_OF_WEEK day=(ENUM_DAY_OF_WEEK)now_parts.day_of_week;
      for(uint index=0;index<16;index++)
        {
         datetime from=0;
         datetime to=0;
         if(!SymbolInfoSessionTrade(symbol,day,index,from,to))
            break;
         session_metadata_available=true;
         MqlDateTime from_parts;
         MqlDateTime to_parts;
         TimeToStruct(from,from_parts);
         TimeToStruct(to,to_parts);
         const int from_seconds=from_parts.hour*3600+from_parts.min*60+from_parts.sec;
         const int to_seconds=to_parts.hour*3600+to_parts.min*60+to_parts.sec;
         if(from_seconds==to_seconds || (from_seconds<to_seconds && now_seconds>=from_seconds && now_seconds<=to_seconds) || (from_seconds>to_seconds && (now_seconds>=from_seconds || now_seconds<=to_seconds)))
            return(true);
        }
      return(false);
     }

public:
   E2ExecutionSafety(void) : m_trading_enabled(false),m_max_spread_pips(0.0),m_max_quote_age_seconds(0),m_minimum_seconds_between_executions(0),m_last_execution_time(0),m_logger(NULL) {}

   void Initialize(const E2Config &config,E2Logger &logger)
     {
      m_trading_enabled=config.trading_enabled;
      m_max_spread_pips=config.max_spread_pips;
      m_max_quote_age_seconds=config.max_quote_age_seconds;
      m_minimum_seconds_between_executions=config.minimum_seconds_between_executions;
      m_last_execution_time=0;
      m_logger=&logger;
     }

   bool CanExecute(const E2TradePlan &plan,const E2SymbolSpecification &spec,E2ExecutionSafetyResult &result)
     {
      result.status=E2_SAFETY_CLEAR;
      result.spread_pips=0.0;
      result.reason="";
      ZeroMemory(result.tick);
      if(!m_trading_enabled)
         return(Reject(result,E2_SAFETY_TRADING_DISABLED,"trading is disabled"));
      if(plan.symbol=="" || !SymbolSelect(plan.symbol,true))
         return(Reject(result,E2_SAFETY_SYMBOL_UNAVAILABLE,"symbol unavailable"));
      const ENUM_SYMBOL_TRADE_MODE trade_mode=(ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(plan.symbol,SYMBOL_TRADE_MODE);
      if(trade_mode==SYMBOL_TRADE_MODE_DISABLED || trade_mode==SYMBOL_TRADE_MODE_CLOSEONLY || (plan.direction==E2_DIRECTION_BUY && trade_mode==SYMBOL_TRADE_MODE_SHORTONLY) || (plan.direction==E2_DIRECTION_SELL && trade_mode==SYMBOL_TRADE_MODE_LONGONLY))
         return(Reject(result,E2_SAFETY_SYMBOL_TRADING_DISABLED,"symbol trading mode does not permit this order"));
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
         return(Reject(result,E2_SAFETY_TRADING_NOT_ALLOWED,"terminal, EA, or account trading permission is unavailable"));
      bool session_metadata_available=false;
      if(!IsTradeSessionOpen(plan.symbol,session_metadata_available) && session_metadata_available)
         return(Reject(result,E2_SAFETY_MARKET_CLOSED,"market trading session is closed"));
      if(!SymbolInfoTick(plan.symbol,result.tick) || result.tick.bid<=0.0 || result.tick.ask<=0.0 || result.tick.ask<result.tick.bid || result.tick.time<=0)
         return(Reject(result,E2_SAFETY_NO_VALID_QUOTE,"market quote is unavailable"));
      if(m_max_quote_age_seconds>0 && TimeCurrent()-result.tick.time>m_max_quote_age_seconds)
         return(Reject(result,E2_SAFETY_NO_VALID_QUOTE,"market quote is stale"));
      if(!IsVolumeValid(plan.volume,spec))
         return(Reject(result,E2_SAFETY_VOLUME_INVALID,"volume is outside broker limits or step"));
      if(spec.pip_size<=0.0)
         return(Reject(result,E2_SAFETY_NO_VALID_QUOTE,"symbol pip metadata is unavailable"));
      result.spread_pips=(result.tick.ask-result.tick.bid)/spec.pip_size;
      // Admit only representational noise: one-millionth of a price tick in
      // pip units, with a tiny absolute floor. A real extra executable tick
      // remains well beyond this tolerance and still rejects.
      const double spread_tolerance_pips=MathMax(1e-9,(spec.tick_size/spec.pip_size)*1e-6);
      if(m_max_spread_pips>0.0 && result.spread_pips>m_max_spread_pips+spread_tolerance_pips)
         return(Reject(result,E2_SAFETY_SPREAD_TOO_HIGH,"spread="+DoubleToString(result.spread_pips,4)+" pips, max="+DoubleToString(m_max_spread_pips,4)+" pips"));
      if(m_minimum_seconds_between_executions>0 && m_last_execution_time>0 && TimeCurrent()-m_last_execution_time<m_minimum_seconds_between_executions)
         return(Reject(result,E2_SAFETY_EXECUTION_COOLDOWN,"execution cooldown is active"));
      return(true);
     }

   void RecordSuccessfulExecution(void)
     {
      m_last_execution_time=TimeCurrent();
     }
  };

#endif // E2_EXECUTION_E2EXECUTIONSAFETY_MQH
