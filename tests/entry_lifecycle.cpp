// Runs the production reconciliation header against a deterministic broker fake.
// This is not a substitute for MetaEditor compilation or a demo terminal test.
#include <string>
#include <vector>
#include <cmath>
#include <cassert>
#include <iostream>
using string=std::string;
using datetime=long;
const string _Symbol="XAUUSD";
const int MQL_TESTER=1;long MQLInfoInteger(int){return 0;}
enum {ACCOUNT_LOGIN,ACCOUNT_SERVER,FILE_WRITE=4,FILE_READ=8,FILE_CSV=16,FILE_ANSI=32,FILE_REWRITE=64,INVALID_HANDLE=-1};
enum {DEAL_SYMBOL,DEAL_MAGIC,DEAL_ENTRY,DEAL_TYPE,DEAL_TIME,DEAL_ORDER,DEAL_COMMENT,DEAL_POSITION_ID,DEAL_VOLUME,DEAL_PRICE,
      ORDER_STATE,ORDER_VOLUME_INITIAL,ORDER_VOLUME_CURRENT,POSITION_IDENTIFIER,POSITION_SYMBOL,POSITION_MAGIC,
      SYMBOL_TRADE_TICK_SIZE,POSITION_VOLUME,POSITION_SL,POSITION_TP};
enum {DEAL_ENTRY_IN=100,DEAL_ENTRY_OUT,DEAL_ENTRY_OUT_BY,DEAL_TYPE_BUY,ORDER_STATE_FILLED,ORDER_STATE_CANCELED,ORDER_STATE_REJECTED,ORDER_STATE_EXPIRED};
enum E2TradeDirection {E2_DIRECTION_NONE,E2_DIRECTION_LONG,E2_DIRECTION_SHORT};
struct E2PositionMetadata {string candidate_id,execution_id,symbol,time_policy_digest;E2TradeDirection direction;
 datetime signal_time,entry_time,range_start_rule,range_end_rule;unsigned long entry_deal,position_id,position_ticket;
 double volume,fill_price,submitted_stop,original_r,target_r,target_price,requested_risk_cash,actual_risk_cash,range_high,range_low,signal_close,extension_distance;int rule_day;};
struct E2Candidate {string candidate_id;int rule_day;datetime range_start_rule,range_end_rule;double range_high,range_low,signal_close,extension_distance;};
struct E2OrderRequest {string execution_id,symbol;E2TradeDirection direction;datetime signal_time,request_time;double submitted_stop_price,requested_risk_cash,volume;};
struct E2ExecutionResult {unsigned long order_ticket,deal_ticket;};
struct {unsigned long expert_magic_number=77;string time_policy_digest="test";double xau_target_r=1.5;}g_configuration;
unsigned long clock_ms=1000;
bool journal=false,delete_ok=true,save_ok=true,order_active=false,history_ok=true,position_open=true,modify_ok=true;
double sl=90,tp=116.5,position_volume=1,expected_volume=1;
int registrations=0,modifications=0,saves=0;
struct Deal {unsigned long id,order,pid,magic;long entry,type;double volume,price;};
std::vector<Deal> deals;
Deal& deal(unsigned long id){for(auto& d:deals)if(d.id==id)return d;throw 1;}
template<class T>void ZeroMemory(T& x){x=T{};}
template<class... T>void Print(T... args){}
string IntegerToString(long v){return std::to_string(v);}
string StringFormat(const string&,unsigned long v){return std::to_string(v);}
string DoubleToString(double v,int){return std::to_string(v);}
long StringToInteger(const string& v){return v.empty()?0:std::stol(v);}
double StringToDouble(const string& v){return v.empty()?0:std::stod(v);}
void StringReplace(string& s,const string& from,const string& to){size_t p;while((p=s.find(from))!=string::npos)s.replace(p,from.size(),to);}
long AccountInfoInteger(int){return 1;} string AccountInfoString(int){return "demo";}
unsigned long GetTickCount64(){return clock_ms;}
datetime TimeCurrent(){return 2000;}
int FileOpen(const string&,int,char){return 1;}
template<class... T>unsigned int FileWrite(int,T...){return 1;}
void FileFlush(int){} void FileClose(int){}
bool FileMove(const string&,int,const string&,int){journal=true;return true;}
bool FileIsExist(const string&){return journal;}
bool FileDelete(const string&){if(delete_ok)journal=false;return delete_ok;}
bool FileIsEnding(int){return true;} string FileReadString(int){return "";}
bool MathIsValidNumber(double x){return std::isfinite(x);}double MathAbs(double x){return std::abs(x);}
bool HistorySelect(datetime,datetime){return history_ok;}int HistoryDealsTotal(){return deals.size();}
unsigned long HistoryDealGetTicket(int i){return deals[i].id;}
string HistoryDealGetString(unsigned long,int key){return key==DEAL_SYMBOL?"XAUUSD":"match";}
long HistoryDealGetInteger(unsigned long id,int k){auto& d=deal(id);switch(k){case DEAL_MAGIC:return d.magic;case DEAL_ENTRY:return d.entry;case DEAL_TYPE:return d.type;case DEAL_TIME:return 1001;case DEAL_ORDER:return d.order;case DEAL_POSITION_ID:return d.pid;}return 0;}
double HistoryDealGetDouble(unsigned long id,int k){return k==DEAL_VOLUME?deal(id).volume:deal(id).price;}
bool OrderSelect(unsigned long){return order_active;}bool HistoryOrderSelect(unsigned long){return history_ok;}
long HistoryOrderGetInteger(unsigned long,int){return ORDER_STATE_FILLED;}
double HistoryOrderGetDouble(unsigned long,int k){return k==ORDER_VOLUME_INITIAL?expected_volume:0;}
int PositionsTotal(){return position_open?1:0;}unsigned long PositionGetTicket(int){return 42;}
long PositionGetInteger(int k){return k==POSITION_IDENTIFIER?42:77;}
string PositionGetString(int){return "XAUUSD";}
double SymbolInfoDouble(const string&,int){return .01;}
double PositionGetDouble(int k){return k==POSITION_VOLUME?position_volume:k==POSITION_SL?sl:tp;}
bool PositionSelectByTicket(unsigned long){return position_open;}bool HistorySelectByPosition(unsigned long){return true;}
struct {double NormalizePrice(double v){return std::round(v*100)/100;}}g_symbol_info;
struct {bool AttachProtection(const string&,unsigned long,double s,double t,unsigned int& rc,string& desc){modifications++;if(modify_ok){sl=s;tp=t;}return modify_ok;}}g_order_executor;
struct {bool CalculateActualRisk(const string&,E2TradeDirection,double v,double e,double s,double& out){out=v*(e-s);return true;}void RecordOriginalRiskCash(double){}}g_position_sizer;
struct {bool Save(const E2PositionMetadata&){saves++;return save_ok;}void RecordLock(){}}g_position_recovery;
struct {bool Register(const E2PositionMetadata&,bool){registrations++;return true;}void RecordExecuted(const string&,const E2ExecutionResult&,const E2PositionMetadata&){}}g_trade_reporter;
int g_recovered_positions_registered=0,g_new_positions_registered=0;
struct {int targets_attached=0,recovered_positions_validated=0,new_positions_registered=0;}g_r_verify;
#include "../include/execution/E2EntryLifecycle.mqh"
void reset(){g_entry={};g_entry.symbol="XAUUSD";g_entry.direction=E2_DIRECTION_LONG;g_entry.submitted_stop=90;g_entry.target_r=1.5;
 g_entry_requested=1000;g_entry_requested_volume=1;g_entry_result={7,0};g_entry_pending=true;g_entry_registered=false;g_entry_restarted=false;
 g_entry_retry_ms=0;g_entry_alert_ms=0;clock_ms=1000;journal=true;delete_ok=save_ok=history_ok=position_open=modify_ok=true;
 order_active=false;sl=90;tp=115;position_volume=expected_volume=1;registrations=modifications=saves=0;deals.clear();}
void filled(){deals.push_back({8,7,42,77,DEAL_ENTRY_IN,DEAL_TYPE_BUY,1,101});}
void retry(){clock_ms+=1001;E2ReconcileEntry();}
int main(){
 reset();E2ReconcileEntry();assert(g_entry_pending&&registrations==0);filled();retry();assert(!g_entry_pending&&registrations==1&&tp==117.5&&sl==90);retry();assert(registrations==1);
 reset();filled();modify_ok=false;E2ReconcileEntry();assert(g_entry_pending&&registrations==0);modify_ok=true;retry();assert(!g_entry_pending&&registrations==1);
 reset();filled();save_ok=false;E2ReconcileEntry();assert(tp==117.5&&g_entry_pending);save_ok=true;retry();assert(registrations==1&&!g_entry_pending);
 reset();filled();delete_ok=false;E2ReconcileEntry();assert(g_entry_pending&&registrations==1);delete_ok=true;retry();assert(!g_entry_pending&&registrations==1);
 reset();filled();deals[0].magic=88;E2ReconcileEntry();assert(g_entry_pending&&registrations==0);
 reset();filled();deals[0].order=99;E2ReconcileEntry();assert(g_entry_pending&&registrations==0);
 reset();filled();order_active=true;E2ReconcileEntry();assert(g_entry_pending);order_active=false;retry();assert(!g_entry_pending);
 reset();deals={{8,7,42,77,DEAL_ENTRY_IN,DEAL_TYPE_BUY,.4,100}};E2ReconcileEntry();assert(g_entry_pending);deals.push_back({9,7,42,77,DEAL_ENTRY_IN,DEAL_TYPE_BUY,.6,102});retry();assert(!g_entry_pending&&tp==118);
 reset();filled();g_entry_restarted=true;E2ReconcileEntry();assert(!g_entry_pending&&g_recovered_positions_registered==1);
 reset();filled();position_open=false;E2ReconcileEntry();assert(g_entry_pending);deals.push_back({9,9,42,77,DEAL_ENTRY_OUT,DEAL_TYPE_BUY,1,115});retry();assert(!g_entry_pending&&registrations==1);
 std::cout<<"10 production reconciliation scenarios passed\n";
}
