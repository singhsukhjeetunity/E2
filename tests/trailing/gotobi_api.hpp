// APIs needed to compile the real disabled overlay in baseline Gotobi tests.
// Enabled indicator/execution behavior is tested separately in tests/trailing.
constexpr int PERIOD_CURRENT=0,PERIOD_M5=5,MODE_EMA=1,PRICE_CLOSE=0;
constexpr int POSITION_TYPE=101,POSITION_TP=102,POSITION_TYPE_BUY=0,TRADE_ACTION_SLTP=6;
int _Period=PERIOD_M5;
const double EMPTY_VALUE=1.7976931348623157e308;
int iATR(const string&,int,int){return INVALID_HANDLE;}
int iMA(const string&,int,int,int,int,int){return INVALID_HANDLE;}
int BarsCalculated(int){return 0;}
int CopyBuffer(int,int,int,int,std::vector<double>&){return 0;}
void IndicatorRelease(int){}
bool PositionSelectByTicket(ulong ticket){for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)==ticket)return true;return false;}
bool OrderSend(const MqlTradeRequest&,MqlTradeResult&){assert(false&&"disabled overlay must not send");return false;}
