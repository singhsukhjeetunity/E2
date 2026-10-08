#pragma once
// Deterministic portable test API, NOT an MQL5 compiler or broker simulator.
#include <algorithm>
#include <cassert>
#include <cmath>
#include <ctime>
#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <sstream>
#include <cstdarg>
#include <fstream>
using string=std::string;
using datetime=long long;
using ENUM_TIMEFRAMES=int;
using ENUM_DAY_OF_WEEK=int;
using ENUM_DEAL_ENTRY=int;
using ENUM_DEAL_TYPE=int;
using ENUM_ORDER_TYPE=int;
constexpr int PERIOD_M1=1,PERIOD_M15=15,PERIOD_M30=30;
constexpr int INIT_FAILED=1;
constexpr int INIT_SUCCEEDED=0,INIT_PARAMETERS_INCORRECT=2;
constexpr int TRADE_RETCODE_DONE=10009,TRADE_RETCODE_DONE_PARTIAL=10010;
constexpr int ACCOUNT_MARGIN_MODE=1,ACCOUNT_MARGIN_MODE_RETAIL_HEDGING=2,ACCOUNT_EQUITY=3,ACCOUNT_MARGIN_FREE=4;
constexpr int POSITION_SYMBOL=5,POSITION_MAGIC=6,POSITION_TIME=7,POSITION_SL=8;
constexpr int DEAL_SYMBOL=9,DEAL_MAGIC=10,DEAL_ENTRY=11,DEAL_TYPE=12;
constexpr int DEAL_ENTRY_IN=0,DEAL_ENTRY_INOUT=2,DEAL_TYPE_BUY=0,DEAL_TYPE_SELL=1;
constexpr int ORDER_TYPE_BUY=0,ORDER_TYPE_SELL=1;
constexpr int SYMBOL_TRADE_TICK_SIZE=13,SYMBOL_TRADE_STOPS_LEVEL=14,SYMBOL_TRADE_FREEZE_LEVEL=15;
constexpr int SYMBOL_VOLUME_MIN=16,SYMBOL_VOLUME_MAX=17,SYMBOL_VOLUME_STEP=18;
constexpr int DEAL_POSITION_ID=40,DEAL_TIME=41,DEAL_TIME_MSC=42,DEAL_REASON=43;
constexpr int DEAL_ENTRY_OUT=1,DEAL_ENTRY_OUT_BY=3;
constexpr int DEAL_VOLUME=44,DEAL_PRICE=45,DEAL_SL=46,DEAL_TP=47,DEAL_PROFIT=48,DEAL_COMMISSION=49,DEAL_SWAP=50,DEAL_FEE=51;
constexpr int INVALID_HANDLE=-1,FILE_WRITE=1,FILE_CSV=2,FILE_ANSI=4,FILE_COMMON=8,FILE_SHARE_READ=16,CP_UTF8=65001;
constexpr int ACCOUNT_BALANCE=52,ACCOUNT_TRADE_MODE=53,ACCOUNT_TRADE_MODE_DEMO=0,ACCOUNT_LOGIN=54;
constexpr int MQL_TESTER=55,TERMINAL_COMMONDATA_PATH=56;
constexpr int TRADE_TRANSACTION_DEAL_ADD=1;
struct MqlTradeTransaction{int type=TRADE_TRANSACTION_DEAL_ADD;ulong deal=0;};struct MqlTradeRequest{};struct MqlTradeResult{};
int mock_error=0;bool mock_file_fail=false;
int GetLastError(){return mock_error;}void ResetLastError(){mock_error=0;}
string DoubleToString(double x,int n){std::ostringstream s;s.precision(n);s<<std::fixed<<x;return s.str();}
string StringFormat(const char *fmt,...){char buf[256];va_list args;va_start(args,fmt);vsnprintf(buf,sizeof(buf),fmt,args);va_end(args);return buf;}
void StringReplace(string &s,const string &from,const string &to){size_t pos=0;while((pos=s.find(from,pos))!=string::npos){s.replace(pos,from.size(),to);pos+=to.size();}}
std::map<string,std::vector<std::vector<string>>> mock_files;
std::map<int,string> mock_handles;int mock_next_handle=1;
int FileOpen(const string &path,int,char,int){if(mock_file_fail){mock_error=5004;return INVALID_HANDLE;}int h=mock_next_handle++;mock_handles[h]=path;mock_files[path].clear();return h;}
bool FileIsExist(const string &path,int){return mock_files.count(path)>0;}
template<class T>string mock_string(const T &x){std::ostringstream out;out<<x;return out.str();}
template<class... T>int FileWrite(int h,const T&... values){mock_files[mock_handles.at(h)].push_back({mock_string(values)...});return sizeof...(values);}
void FileFlush(int){}void FileClose(int h){mock_handles.erase(h);}
int MQLInfoInteger(int){return 1;}
string TerminalInfoString(int){return "COMMON";}
datetime TimeLocal(){return 1000000;}ulong GetMicrosecondCount(){return 123;}
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
template<class T>int ArraySize(const std::vector<T> &v){return (int)v.size();}
template<class T>void ArrayResize(std::vector<T> &v,int n){v.resize(n);}
template<class T>void ArraySetAsSeries(std::vector<T>&,bool){}
template<class T>void ZeroMemory(T &v){v=T{};}
template<class... T>void Print(const T&...){}
int PeriodSeconds(int p){return p*60;}
datetime test_now=0,history_since=0,history_until=0;
int test_mode=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
double test_cash=100000,test_free=100000,test_min_lot=.01;
MqlTick test_tick;
struct TestPosition {ulong ticket,magic;string symbol;datetime time;double stop,lots;double target=0;};
std::vector<TestPosition> test_positions;int selected=-1;
struct TestDeal {
 ulong ticket,magic;string symbol;datetime time;int entry,type;
 ulong position=0;double volume=0,price=0,sl=0,tp=0,profit=0,commission=0,swap=0,fee=0;
 long reason=0;
};
std::vector<TestDeal> test_deals;
std::vector<MqlRates> test_minutes,test_m15,test_m30;
bool test_session_closed=false,test_order_rejected=false;
bool SymbolInfoSessionTrade(const string&,int,uint i,datetime &from,datetime &to){if(i>0||test_session_closed)return false;from=0;to=86400;return true;}
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
bool HistoryDealSelect(ulong){history_since=0;history_until=test_now;return true;}
TestDeal &deal(ulong ticket){return test_deals.at(ticket-1);}
string HistoryDealGetString(ulong t,int){return deal(t).symbol;}
long long HistoryDealGetInteger(ulong t,int property) {
   auto &d=deal(t);
   if(d.time<history_since||d.time>history_until)return -1;
   if(property==DEAL_MAGIC)return d.magic;
   if(property==DEAL_POSITION_ID)return d.position;
   if(property==DEAL_TIME)return d.time;
   if(property==DEAL_TIME_MSC)return d.time*1000;
   if(property==DEAL_REASON)return d.reason;
   return property==DEAL_ENTRY?d.entry:d.type;
}
double HistoryDealGetDouble(ulong t,int property) {
 auto &d=deal(t);
 if(property==DEAL_VOLUME)return d.volume;
 if(property==DEAL_PRICE)return d.price;
 if(property==DEAL_SL)return d.sl;
 if(property==DEAL_TP)return d.tp;
 if(property==DEAL_PROFIT)return d.profit;
 if(property==DEAL_COMMISSION)return d.commission;
 if(property==DEAL_SWAP)return d.swap;
 return d.fee;
}
datetime iTime(const string&,int,int){return test_now-test_now%60;}
long test_copied_minutes=0;
int CopyRates(const string&,int frame,datetime from,datetime to,std::vector<MqlRates> &out) {
   out.clear();const auto &source=frame==PERIOD_M1?test_minutes:frame==PERIOD_M15?test_m15:test_m30;
   for(auto r:source)if(r.time>=from&&r.time<=to)out.push_back(r);
   test_copied_minutes+=(long)out.size();
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
   bool enter(int side,double lots,const string &symbol,double stop,double target) {
      if(test_order_rejected)return false;
      ulong ticket=test_positions.size()+100;
      test_positions.push_back({ticket,magic,symbol,test_now,stop,lots,target});
      test_deals.push_back({test_deals.size()+1,magic,symbol,test_now,DEAL_ENTRY_IN,side});return true;
   }
public:
   void SetExpertMagicNumber(ulong m){magic=m;}
   void SetDeviationInPoints(ulong){}
   void SetAsyncMode(bool){}
   void SetTypeFillingBySymbol(const string&){}
   uint ResultRetcode(){return TRADE_RETCODE_DONE;}
   string ResultRetcodeDescription(){return "mock";}
   bool Buy(double lots,const string &symbol,double,double stop,double target,const string&){return enter(0,lots,symbol,stop,target);}
   bool Sell(double lots,const string &symbol,double,double stop,double target,const string&){return enter(1,lots,symbol,stop,target);}
   bool PositionClose(ulong ticket,ulong) {
      auto it=std::find_if(test_positions.begin(),test_positions.end(),[&](auto p){return p.ticket==ticket;});
      if(it==test_positions.end())return false;
      test_positions.erase(it);return true;
   }
};
