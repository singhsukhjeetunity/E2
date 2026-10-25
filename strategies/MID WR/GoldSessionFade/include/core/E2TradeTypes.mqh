#ifndef E2_CORE_E2TRADETYPES_MQH
#define E2_CORE_E2TRADETYPES_MQH
enum E2TradeDirection { E2_DIRECTION_NONE=0,E2_DIRECTION_LONG=1,E2_DIRECTION_SHORT=2 };
string E2TradeDirectionName(const E2TradeDirection direction){if(direction==E2_DIRECTION_LONG)return("LONG");if(direction==E2_DIRECTION_SHORT)return("SHORT");return("NONE");}
#endif
