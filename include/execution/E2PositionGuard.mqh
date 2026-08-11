#ifndef E2_EXECUTION_E2POSITIONGUARD_MQH
#define E2_EXECUTION_E2POSITIONGUARD_MQH

#include "..\\core\\E2Config.mqh"
#include "..\\risk\\E2TradePlanner.mqh"
enum E2PositionGuardStatus { E2_GUARD_CLEAR,E2_GUARD_POSITION_ALREADY_OPEN,E2_GUARD_PENDING_ORDER_EXISTS,E2_GUARD_DIRECTION_CONFLICT,E2_GUARD_POSITION_STATE_UNAVAILABLE,E2_GUARD_ACCOUNT_MODE_UNSUPPORTED };
struct E2PositionGuardResult { E2PositionGuardStatus status; int open_e2_positions; int pending_e2_orders; };
string E2PositionGuardStatusName(const E2PositionGuardStatus status)
  { switch(status) { case E2_GUARD_CLEAR:return("CLEAR"); case E2_GUARD_POSITION_ALREADY_OPEN:return("POSITION_ALREADY_OPEN"); case E2_GUARD_PENDING_ORDER_EXISTS:return("PENDING_ORDER_EXISTS"); case E2_GUARD_DIRECTION_CONFLICT:return("DIRECTION_CONFLICT"); case E2_GUARD_ACCOUNT_MODE_UNSUPPORTED:return("ACCOUNT_MODE_UNSUPPORTED"); default:return("POSITION_STATE_UNAVAILABLE"); } }
class E2PositionGuard
  { private: ulong m_magic; E2Logger *m_logger;
    public: E2PositionGuard(void):m_magic(0),m_logger(NULL){}
    void Initialize(const E2Config &c,E2Logger &l){m_magic=c.expert_magic_number;m_logger=&l;}
    int CountOpenE2Positions(const string s){int n=0;for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==s&&(ulong)PositionGetInteger(POSITION_MAGIC)==m_magic)n++;}return(n);}
    bool HasOpenE2Position(const string s){return(CountOpenE2Positions(s)>0);}
    bool HasPendingE2Order(const string s){for(int i=0;i<OrdersTotal();i++){ulong t=OrderGetTicket(i);if(t>0&&OrderGetString(ORDER_SYMBOL)==s&&(ulong)OrderGetInteger(ORDER_MAGIC)==m_magic)return(true);}return(false);}
    bool CanOpen(const E2TradePlan &p,E2PositionGuardResult &r)
      {r.status=E2_GUARD_CLEAR;r.open_e2_positions=CountOpenE2Positions(p.symbol);r.pending_e2_orders=HasPendingE2Order(p.symbol)?1:0;
       const bool netting=(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
       if(netting){for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==p.symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)!=m_magic){r.status=E2_GUARD_ACCOUNT_MODE_UNSUPPORTED;return(false);}}}
       if(r.open_e2_positions>0){for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==p.symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==m_magic){ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);r.status=((p.direction==E2_DIRECTION_BUY&&type==POSITION_TYPE_BUY)||(p.direction==E2_DIRECTION_SELL&&type==POSITION_TYPE_SELL))?E2_GUARD_POSITION_ALREADY_OPEN:E2_GUARD_DIRECTION_CONFLICT;return(false);}}}
       if(r.pending_e2_orders>0){r.status=E2_GUARD_PENDING_ORDER_EXISTS;return(false);}return(true);}
  };
#endif
