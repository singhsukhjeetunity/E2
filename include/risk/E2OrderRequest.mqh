#ifndef E2_RISK_E2ORDERREQUEST_MQH
#define E2_RISK_E2ORDERREQUEST_MQH

#include "E2PositionSizer.mqh"

// Minimal broker-facing request produced by the execution adapter.
// Strategic candidate/target/management metadata remains in E2V2TradePlan.
enum E2OrderRequestStatus
  {
   E2_ORDER_REQUEST_INVALID=0,
   E2_ORDER_REQUEST_VALID=1
  };

struct E2OrderRequest
  {
   E2OrderRequestStatus status;
   string               symbol;
   E2TradeDirection     direction;
   double               entry_price;
   double               stop_loss_price;
   double               take_profit_price;
   double               volume;
  };

#endif // E2_RISK_E2ORDERREQUEST_MQH
