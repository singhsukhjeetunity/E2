#pragma once
// Deterministic portable test API, NOT an MQL5 compiler or broker simulator.
#include <algorithm>
#include <cassert>
#include <cmath>
#include <ctime>
#include <iostream>
#include <string>
#include <vector>
using string=std::string;
using datetime=long long;
using ENUM_TIMEFRAMES=int;
using ENUM_DEAL_ENTRY=int;
using ENUM_DEAL_TYPE=int;
using ENUM_ORDER_TYPE=int;
constexpr int PERIOD_M1=1,PERIOD_M15=15,PERIOD_M30=30;
constexpr int INIT_SUCCEEDED=0,INIT_PARAMETERS_INCORRECT=2;
constexpr int TRADE_RETCODE_DONE=10009,TRADE_RETCODE_DONE_PARTIAL=10010;
constexpr int ACCOUNT_MARGIN_MODE=1,ACCOUNT_MARGIN_MODE_RETAIL_HEDGING=2,ACCOUNT_EQUITY=3,ACCOUNT_MARGIN_FREE=4;
constexpr int POSITION_SYMBOL=5,POSITION_MAGIC=6,POSITION_TIME=7,POSITION_SL=8;
constexpr int DEAL_SYMBOL=9,DEAL_MAGIC=10,DEAL_ENTRY=11,DEAL_TYPE=12;
constexpr int DEAL_ENTRY_IN=0,DEAL_ENTRY_INOUT=2,DEAL_TYPE_BUY=0,DEAL_TYPE_SELL=1;
constexpr int ORDER_TYPE_BUY=0,ORDER_TYPE_SELL=1;
constexpr int SYMBOL_TRADE_TICK_SIZE=13,SYMBOL_TRADE_STOPS_LEVEL=14,SYMBOL_TRADE_FREEZE_LEVEL=15;
constexpr int SYMBOL_VOLUME_MIN=16,SYMBOL_VOLUME_MAX=17,SYMBOL_VOLUME_STEP=18;
string _Symbol="TEST";double _Point=.01;int _Digits=2;
struct MqlDateTime {int year=0,mon=0,day=0,hour=0,min=0,sec=0,day_of_week=0;};
struct MqlTick {double bid=100,ask=100.02;};
struct MqlRates {datetime time=0;double open=0,high=0,low=0,close=0;};
datetime StructToTime(const MqlDateTime &m) {
   std::tm t{};t.tm_year=m.year-1900;t.tm_mon=m.mon-1;t.tm_mday=m.day;
   t.tm_hour=m.hour;t.tm_min=m.min;t.tm_sec=m.sec;return timegm(&t);
}
void TimeToStruct(datetime x,MqlDateTime &m) {
   std::time_t v=x;auto t=*std::gmtime(&v);
   m={t.tm_year+1900,t.tm_mon+1,t.tm_mday,t.tm_hour,t.tm_min,t.tm_sec,t.tm_wday};
}
double MathMax(double a,double b){return std::max(a,b);}
double MathMin(double a,double b){return std::min(a,b);}
double MathAbs(double a){return std::abs(a);}
double MathFloor(double a){return std::floor(a);}
double MathCeil(double a){return std::ceil(a);}
double NormalizeDouble(double a,int n){double x=std::pow(10,n);return std::round(a*x)/x;}
string IntegerToString(long long x){return std::to_string(x);}
int StringFind(const string &s,const string &x){auto p=s.find(x);return p==string::npos?-1:(int)p;}
template<class T>void ArrayResize(std::vector<T> &v,int n){v.resize(n);}
template<class T>void ArraySetAsSeries(std::vector<T>&,bool){}
template<class T>void ZeroMemory(T &v){v=T{};}
template<class... T>void Print(const T&...){}
int PeriodSeconds(int p){return p*60;}
datetime test_now=0,history_since=0,history_until=0;
int test_mode=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
double test_cash=100000,test_free=100000,test_min_lot=.01;
MqlTick test_tick;
struct TestPosition {ulong ticket,magic;string symbol;datetime time;double stop,lots;};
std::vector<TestPosition> test_positions;int selected=-1;
struct TestDeal {ulong ticket,magic;string symbol;datetime time;int entry,type;};
std::vector<TestDeal> test_deals;
std::vector<MqlRates> test_minutes,test_m15,test_m30;
datetime TimeCurrent(){return test_now;}
long long AccountInfoInteger(int){return test_mode;}
double AccountInfoDouble(int property){return property==ACCOUNT_EQUITY?test_cash:test_free;}
bool SymbolInfoTick(const string&,MqlTick &t){t=test_tick;return true;}
double SymbolInfoDouble(const string&,int property) {
   if(property==SYMBOL_VOLUME_MIN)return test_min_lot;
   if(property==SYMBOL_VOLUME_MAX)return 100;
   return .01;
}
long long SymbolInfoInteger(const string&,int){return 0;}
bool OrderCalcProfit(int side,const string&,double lots,double entry,double stop,double &out){out=(side==0?stop-entry:entry-stop)*1000*lots;return true;}
bool OrderCalcMargin(int,const string&,double lots,double,double &out){out=lots*100;return true;}
int PositionsTotal(){return (int)test_positions.size();}
ulong PositionGetTicket(int i){selected=i;return test_positions[i].ticket;}
string PositionGetString(int){return test_positions[selected].symbol;}
long long PositionGetInteger(int property){return property==POSITION_MAGIC?test_positions[selected].magic:test_positions[selected].time;}
double PositionGetDouble(int){return test_positions[selected].stop;}
bool HistorySelect(datetime from,datetime to){history_since=from;history_until=to;return true;}
int HistoryDealsTotal(){return (int)test_deals.size();}
ulong HistoryDealGetTicket(int i){return test_deals[i].ticket;}
TestDeal &deal(ulong ticket){return test_deals.at(ticket-1);}
string HistoryDealGetString(ulong t,int){return deal(t).symbol;}
long long HistoryDealGetInteger(ulong t,int property) {
   auto &d=deal(t);
   if(d.time<history_since||d.time>history_until)return -1;
   if(property==DEAL_MAGIC)return d.magic;
   return property==DEAL_ENTRY?d.entry:d.type;
}
datetime iTime(const string&,int,int){return test_now-test_now%60;}
int CopyRates(const string&,int frame,datetime from,datetime to,std::vector<MqlRates> &out) {
   out.clear();const auto &source=frame==PERIOD_M1?test_minutes:frame==PERIOD_M15?test_m15:test_m30;
   for(auto r:source)if(r.time>=from&&r.time<=to)out.push_back(r);
   return (int)out.size();
}
int CopyRates(const string&,int frame,int shift,int count,std::vector<MqlRates> &out) {
   out.clear();const auto &source=frame==PERIOD_M15?test_m15:test_m30;
   std::vector<MqlRates> closed;
   for(auto r:source)if(r.time+PeriodSeconds(frame)<=test_now)closed.push_back(r);
   int end=(int)closed.size()-(shift-1),start=std::max(0,end-count);
   for(int i=start;i<end;i++)out.push_back(closed[i]);
   return (int)out.size();
}
class CTrade {
   ulong magic=0;
   bool enter(int side,double lots,const string &symbol,double stop) {
      ulong ticket=test_positions.size()+100;
      test_positions.push_back({ticket,magic,symbol,test_now,stop,lots});
      test_deals.push_back({test_deals.size()+1,magic,symbol,test_now,DEAL_ENTRY_IN,side});return true;
   }
public:
   void SetExpertMagicNumber(ulong m){magic=m;}
   void SetDeviationInPoints(ulong){}
   void SetAsyncMode(bool){}
   void SetTypeFillingBySymbol(const string&){}
   uint ResultRetcode(){return TRADE_RETCODE_DONE;}
   string ResultRetcodeDescription(){return "mock";}
   bool Buy(double lots,const string &symbol,double,double stop,double,const string&){return enter(0,lots,symbol,stop);}
   bool Sell(double lots,const string &symbol,double,double stop,double,const string&){return enter(1,lots,symbol,stop);}
   bool PositionClose(ulong ticket,ulong) {
      auto it=std::find_if(test_positions.begin(),test_positions.end(),[&](auto p){return p.ticket==ticket;});
      if(it==test_positions.end())return false;
      test_positions.erase(it);return true;
   }
};
