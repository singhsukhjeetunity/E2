#ifndef E2_RISK_E2ORDERREQUEST_MQH
#define E2_RISK_E2ORDERREQUEST_MQH
#include "..\\core\\E2TradeTypes.mqh"
enum E2OrderRequestStatus { E2_ORDER_REQUEST_INVALID=0,E2_ORDER_REQUEST_VALID=1 };
struct E2OrderRequest
  {
   E2OrderRequestStatus status; string symbol,setup_id,signal_id,execution_id; E2TradeDirection direction;
   datetime signal_time,signal_known_from,request_time;
   double requested_entry_price,structural_stop_price,submitted_stop_price,take_profit_price,requested_risk_cash,volume;
  };
void E2ResetOrderRequest(E2OrderRequest &request){ZeroMemory(request);request.status=E2_ORDER_REQUEST_INVALID;request.direction=E2_DIRECTION_NONE;}
#endif
