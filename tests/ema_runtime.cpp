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
const int MQL_TESTER=1,FILE_COMMON=2,FILE_WRITE=4,FILE_READ=8,FILE_TXT=16,FILE_UNICODE=32,FILE_BIN=64,FILE_REWRITE=128,INVALID_HANDLE=-1;
const int ACCOUNT_MARGIN_MODE=10,ACCOUNT_MARGIN_MODE_RETAIL_HEDGING=11;
const int ACCOUNT_SERVER=1,ACCOUNT_LOGIN=2,POSITION_SYMBOL=3,POSITION_MAGIC=4,POSITION_TYPE=5,POSITION_IDENTIFIER=6,POSITION_TYPE_BUY=7,ORDER_SYMBOL=8,ORDER_MAGIC=9;
string _Symbol="USTEC";unsigned long InpEMAMagic=2026091402;
bool tester=false,g_state_ready=false,g_failed=false,write_fail=false,move_fail=false;
int g_instance_lock=-1,error=0,next_handle=1;
string g_state_file,g_scope,g_config="settings";
struct Slot {datetime last_exit_minute=0;int active=-1;bool pending=false;};
Slot g_slots[1];std::vector<NPRecord>g_records;
double g_cash[1]={},g_r[1]={};
struct Pos {string symbol;unsigned long magic,pid;long type;};std::vector<Pos>positions;Pos selected;
int PositionsTotal(){return positions.size();}
unsigned long PositionGetTicket(int i){selected=positions[i];return i+1;}
string PositionGetString(int){return selected.symbol;}
long PositionGetInteger(int k){return k==POSITION_MAGIC?selected.magic:(k==POSITION_TYPE?selected.type:selected.pid);}
int OrdersTotal(){return 0;}unsigned long OrderGetTicket(int){return 0;}string OrderGetString(int){return "";}long OrderGetInteger(int){return 0;}
long MQLInfoInteger(int){return tester;}
string AccountInfoString(int){return "Broker";}long AccountInfoInteger(int){return 123;}
template<class... T>void Print(T...){}
void Fail(const string&){g_failed=true;}
void ResetLastError(){error=0;}int GetLastError(){return error;}
struct Handle {string path;size_t cursor=0;};std::map<int,Handle>handles;std::map<string,string>files;
string key(const string &p,int f){return (f&FILE_COMMON?"common:":"local:")+p;}
int FileOpen(const string &p,int flags){string k=key(p,flags);for(auto &h:handles)if(h.second.path==k)return -1;if(write_fail&&(flags&FILE_WRITE))return -1;if(!(flags&FILE_WRITE)&&!files.count(k))return -1;if((flags&FILE_WRITE)&&!(flags&FILE_READ))files[k]="";handles[next_handle]={k,0};return next_handle++;}
void FileClose(int h){handles.erase(h);}void FileFlush(int){}
uint FileWriteString(int h,const string &s){if(write_fail)return 0;files[handles[h].path]+=s;return s.size()*2;}
string FileReadString(int h){auto &x=handles[h];auto &s=files[x.path];auto b=s.find("\r\n",x.cursor);if(b==string::npos)return "";string out=s.substr(x.cursor,b-x.cursor);x.cursor=b+2;return out;}
bool FileIsExist(const string &p,int f){return files.count(key(p,f));}
bool FileDelete(const string &p,int f){files.erase(key(p,f));return true;}
bool FileMove(const string &a,int af,const string &b,int bf){if(move_fail)return false;files[key(b,bf)]=files[key(a,af)];files.erase(key(a,af));return true;}
unsigned long PositionFor(int,unsigned long pid=0){for(auto &p:positions)if(p.magic==InpEMAMagic&&(pid==0||p.pid==pid))return 1;return 0;}
// Generated directly from EMAEngine.mqh by run_ema_runtime.py.
#include "ema_storage_under_test.mqh"
void fresh(){g_state_ready=false;g_failed=false;g_instance_lock=-1;g_state_file="";g_scope="";g_last_checkpoint="";g_slots[0]=Slot{};g_records.clear();}
void detach(){FileClose(g_instance_lock);fresh();}
void pending(){NPRecord r{};r.report_id="original-run_trade";r.id="NP1_1_0";r.strategy="NP_EMA_M30_LONG";r.status="UNCONFIRMED";r.requested=100;r.deadline=1000;r.requested_distance=30;r.requested_risk=100;r.sl=70;r.tp=115;g_records={r};g_slots[0].active=0;g_slots[0].pending=true;}
int main(){
 assert(NPWarmupMinutes(14,20,50)==31440);
 assert(NPWarmupMinutes(100,20,50)==61440);
 assert(InitializeState());string path=key(g_state_file,FILE_COMMON);assert(files.count(path));
 pending();assert(SaveState());string durable=files[path];detach();assert(InitializeState());assert(g_slots[0].pending&&g_records[0].report_id=="original-run_trade");
 // Confirmed fill retains initial protection/risk for restart and offline exit.
 auto &r=g_records[0];r.status="OPEN";r.position=17;r.volume=2;r.fill=100;r.risk_cash=100;r.entry=101;g_slots[0].pending=false;assert(SaveState());
 positions={{"USTEC",InpEMAMagic,17,POSITION_TYPE_BUY}};detach();assert(InitializeState());assert(g_records[0].risk_cash==100&&g_records[0].sl==70&&g_records[0].deadline==1000);
 // A second attachment cannot take over the lock.
 int lock=g_instance_lock;assert(!InitializeState());g_instance_lock=lock;
 // A failed replacement leaves the prior valid checkpoint intact.
 durable=files[path];g_records[0].last_close_attempt=999;move_fail=true;assert(!SaveState());assert(files[path]==durable);move_fail=false;
 detach();g_config="different";assert(!InitializeState());FileClose(g_instance_lock);fresh();g_config="settings";
 assert(InitializeState());g_records[0].status="FINALIZED";g_records[0].exit=999;g_records[0].net=50;positions.clear();assert(SaveState());detach();assert(InitializeState());assert(g_records[0].status=="FINALIZED");
 // Corruption must not be treated as an empty account.
 detach();files[path]+="broken";files[path][0]='X';assert(!InitializeState());FileClose(g_instance_lock);fresh();files.erase(path);
 positions={{"USTEC",InpEMAMagic,17,POSITION_TYPE_BUY}};assert(!InitializeState());FileClose(g_instance_lock);fresh();positions.clear();
 assert(InitializeState());pending();write_fail=true;assert(!SaveState());write_fail=false;detach();
 // Tester state is isolated and reset without deleting terminal state.
 string saved=files[path];tester=true;assert(InitializeState());assert(g_slots[0].active==-1);assert(files[path]==saved);detach();tester=false;
 std::cout<<"EMA warm-up/checkpoint/storage/restart scenarios passed\n";
}
