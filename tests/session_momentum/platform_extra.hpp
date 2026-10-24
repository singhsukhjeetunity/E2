// Extra deterministic APIs for the actual Session Momentum EA.
constexpr int PERIOD_M5=5,MODE_EMA=1,PRICE_CLOSE=0;
constexpr int POSITION_TYPE=101,POSITION_TP=102,POSITION_VOLUME=103,POSITION_IDENTIFIER=104;
constexpr int POSITION_PROFIT=105,POSITION_SWAP=106,POSITION_TYPE_BUY=0,POSITION_TYPE_SELL=1;
constexpr int DEAL_REASON_SL=1,DEAL_REASON_TP=2,DEAL_REASON_SO=3,DEAL_REASON_EXPERT=4;
constexpr int TIME_DATE=1,TIME_SECONDS=2;
using ENUM_DEAL_REASON=int;
const double EMPTY_VALUE=1.7976931348623157e308;
bool test_guard=true,test_modify_ok=true;int test_modifies=0,test_ema_bars=120;
double test_ema=100;bool test_buffer_ok=true,test_indicator_ok=true;
int iMA(const string&,int,int period,int,int mode,int price){assert(period==12&&mode==MODE_EMA&&price==PRICE_CLOSE);return test_indicator_ok?1:INVALID_HANDLE;}
int BarsCalculated(int){return test_ema_bars;}
int CopyBuffer(int,int,int shift,int count,std::vector<double> &out){assert(shift==1&&count==1);out={test_ema};return test_buffer_ok?1:0;}
void IndicatorRelease(int){}
bool EventSetTimer(int){return true;}void EventKillTimer(){}
string TimeToString(datetime time,int){return std::to_string(time);}
string E2UniqueReportRun(const string &run){return run+"_123";}
string E2ReportBase(const string &symbol,const string &run){return symbol+"_"+run;}
double testPositionValue(int property) {
 auto &p=test_positions.at(selected);
 if(property==POSITION_TP)return p.target;if(property==POSITION_VOLUME)return p.lots;
 if(property==POSITION_PROFIT||property==POSITION_SWAP)return 0;
 return p.stop;
}
long long testPositionInteger(int property) {
 auto &p=test_positions.at(selected);
 if(property==POSITION_TYPE)return p.kind;if(property==POSITION_IDENTIFIER)return p.ticket;
 return property==POSITION_MAGIC?p.magic:p.time;
}
datetime testITime(const string&,int,int shift) {
 if(shift==0)return test_now-test_now%300;
 std::vector<MqlRates> bars;for(auto r:test_m30)if(r.time+300<=test_now)bars.push_back(r);
 return bars.empty()?0:bars.back().time;
}
