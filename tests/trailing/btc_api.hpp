// Compile real overlay code in the existing disabled BTC baseline harness.
constexpr int PERIOD_CURRENT=0,MODE_EMA=1,SYMBOL_TRADE_FREEZE_LEVEL=200,TRADE_ACTION_SLTP=6;
int _Period=PERIOD_M5;
const double EMPTY_VALUE=1.7976931348623157e308;
int iMA(const string&,int,int,int,int,int){return INVALID_HANDLE;}
int PeriodSeconds(int period){return period*60;}
double MathCeil(double value){return std::ceil(value);}
template<class T>void ZeroMemory(T &v){v=T{};}
