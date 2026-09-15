// Executes the production checkpoint codec and SaveState/InitializeState functions
// against deterministic account, position and file APIs (no broker connection).
#include <cassert>
#include <cmath>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <sstream>
#include <iomanip>
#include <iostream>
using string=std::string;
using datetime=long;
using uint=unsigned int;
using ushort=unsigned short;
int StringLen(const string &s){return s.size();}
ushort StringGetCharacter(const string &s,int i){return s[i];}
string IntegerToString(long n){return std::to_string(n);}
string DoubleToString(double n,int digits){std::ostringstream s;s<<std::fixed<<std::setprecision(digits)<<n;return s.str();}
string StringFormat(const char *fmt,unsigned long n){if(string(fmt)=="%08X"){std::ostringstream s;s<<std::hex<<std::uppercase<<std::setw(8)<<std::setfill('0')<<n;return s.str();}return std::to_string(n);}
string StringFormat(const char *fmt,uint n){return StringFormat(fmt,(unsigned long)n);}
string StringFormat(const char *fmt,long n){return StringFormat(fmt,(unsigned long)n);}
long StringToInteger(const string &s){try{return std::stol(s);}catch(...){return 0;}}
double StringToDouble(const string &s){try{return std::stod(s);}catch(...){return 0;}}
int StringSplit(const string &s,char delim,std::vector<string> &out){out.clear();size_t a=0,b;while((b=s.find(delim,a))!=string::npos){out.push_back(s.substr(a,b-a));a=b+1;}out.push_back(s.substr(a));return out.size();}
bool MathIsValidNumber(double n){return std::isfinite(n);}
template<class T>void ZeroMemory(T &x){x=T{};}
template<class T>void ArrayResize(std::vector<T> &x,int n){x.resize(n);}
#include "../strategies/EMAPullback/EMAState.mqh"
const string _Symbol="USTEC";const double _Point=.01;
const int SYMBOL_TRADE_STOPS_LEVEL=1,SYMBOL_VOLUME_STEP=2,SYMBOL_VOLUME_MIN=3,SYMBOL_VOLUME_MAX=4,SYMBOL_FILLING_MODE=5,SYMBOL_TRADE_EXEMODE=6;
const int SYMBOL_FILLING_FOK=1,SYMBOL_FILLING_IOC=2,SYMBOL_TRADE_EXECUTION_MARKET=4;
const int TRADE_ACTION_DEAL=1,ORDER_TYPE_BUY=2,ORDER_FILLING_FOK=3,ORDER_FILLING_IOC=4,ORDER_FILLING_RETURN=5;
const int TRADE_RETCODE_DONE=100,TRADE_RETCODE_PLACED=101,TRADE_RETCODE_DONE_PARTIAL=102;
struct MqlDateTime{int hour=11,min=0;};struct MqlTick{double ask=100,bid=99.9;};
struct MqlTradeRequest{int action=0,type=0,type_filling=0;string symbol,comment;unsigned long magic=0,deviation=0;double volume=0,price=0,sl=0,tp=0;};
struct MqlTradeResult{unsigned long order=0;int retcode=TRADE_RETCODE_DONE;};struct MqlTradeCheckResult{string comment;};
struct Slot{datetime signal_time=10000,seen_signal=0,last_exit_minute=0;bool signal=true,pending=false;double signal_atr=10;int active=-1;};
Slot g_slots[1];std::vector<NPRecord>g_records;string g_run="run";
bool g_failed=false,disk_ok=true,durable=false,owned=true;int sends=0,g_session_day=1,g_session_count=120;
int InpMaxEntryDelaySeconds=5;double InpMaxSpreadPriceUnits=4,InpEMAStopATR=3,InpEMATargetR=.5,InpEMACashRisk=1000,InpMaxDeviationPriceUnits=.5;
bool Enabled(int){return true;}int NPCloseMinute(datetime){return 960;}
datetime NPNy(datetime t){return t;}int NPDay(datetime){return 1;}void TimeToStruct(datetime,MqlDateTime&){}
unsigned long PositionFor(int){return 0;}unsigned long Magic(int){return 123;}
bool EntryOwnershipClear(){return owned;}bool ExitDeadline(datetime t,datetime &d){d=t+100;return true;}
bool SymbolInfoTick(const string&,MqlTick&){return true;}
long SymbolInfoInteger(const string&,int k){return k==SYMBOL_FILLING_MODE?SYMBOL_FILLING_FOK:0;}
double SymbolInfoDouble(const string&,int k){return k==SYMBOL_VOLUME_MAX?100:1;}
bool CashRisk(int,double,double,double,double &risk){risk=100;return true;}
double RoundPrice(double x){return x;}double NormalizeDouble(double x,int){return x;}
double MathFloor(double x){return std::floor(x);}double MathCeil(double x){return std::ceil(x);}double MathMin(double a,double b){return std::fmin(a,b);}
int ArraySize(const std::vector<NPRecord>&r){return r.size();}
bool OrderCheck(const MqlTradeRequest&,MqlTradeCheckResult&){return true;}
string Strategy(int){return "NP_EMA_M30_LONG";}datetime TimeCurrent(){return 10000;}
string Stamp(datetime t){return std::to_string(t);}void Audit(int,datetime,const string&,const string&){}
void Fail(const string&){g_failed=true;}
bool SaveState(){if(!disk_ok){Fail("disk");return false;}durable=g_slots[0].pending&&g_slots[0].active>=0;return true;}
bool OrderSend(const MqlTradeRequest &r,MqlTradeResult &out){assert(durable);assert(r.type==ORDER_TYPE_BUY&&r.sl<r.price&&r.tp>r.price);sends++;out.order=55;return true;}
void Reconcile(int,datetime){}
#include "ema_entry.mqh"
void reset(){g_slots[0]=Slot{};g_records.clear();g_failed=false;durable=false;sends=0;disk_ok=true;owned=true;}
int main(){
 reset();disk_ok=false;Enter(0,10000);assert(sends==0&&g_failed);
 reset();Enter(0,10000);assert(sends==1&&g_slots[0].pending);Enter(0,10000);assert(sends==1);
 g_slots[0].signal_time=10001;Enter(0,10001);assert(sends==1); // Pending intent occupies the slot.
 reset();owned=false;Enter(0,10000);assert(sends==0);
 reset();Enter(0,10006);assert(sends==0); // Stale signals cannot execute.
 std::cout<<"EMA durable-before-send, pending/repeated signal and ownership entry tests passed\n";
}
