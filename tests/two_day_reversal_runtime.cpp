// Compile the actual EA runtime (arrays/input declarations translated) against deterministic APIs.
#include <algorithm>
#include <cassert>
#include <cmath>
#include <ctime>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <vector>
using string=std::string;using datetime=long long;using uint=unsigned int;
using ENUM_ORDER_TYPE=int;using ENUM_ORDER_TYPE_FILLING=int;using ENUM_DEAL_REASON=int;
struct MqlDateTime{int year=0,mon=0,day=0,hour=0,min=0,sec=0,day_of_week=0;};
datetime StructToTime(const MqlDateTime &m){std::tm t{};t.tm_year=m.year-1900;t.tm_mon=m.mon-1;t.tm_mday=m.day;t.tm_hour=m.hour;t.tm_min=m.min;t.tm_sec=m.sec;return timegm(&t);}
bool TimeToStruct(datetime x,MqlDateTime &m){std::time_t v=x;auto t=*std::gmtime(&v);m={t.tm_year+1900,t.tm_mon+1,t.tm_mday,t.tm_hour,t.tm_min,t.tm_sec,t.tm_wday};return true;}
datetime D(int day,int hour=0){return StructToTime({2026,10,day,hour});}
double MathMax(double a,double b){return std::max(a,b);}double MathMin(double a,double b){return std::min(a,b);}
double MathAbs(double a){return std::abs(a);}double MathFloor(double a){return std::floor(a);}
double MathRound(double a){return std::round(a);}bool MathIsValidNumber(double a){return std::isfinite(a);}
double NormalizeDouble(double a,int digits){double k=std::pow(10,digits);return std::round(a*k)/k;}
string IntegerToString(long n){return std::to_string(n);}int StringFind(const string &s,const string &v){auto p=s.find(v);return p==string::npos?-1:static_cast<int>(p);}
template<class... T>string StringFormat(const string &s,T...){return s;} // formatting isn't under test
template<class... T>void Print(T...){}template<class... T>void PrintFormat(T...){}
template<class T>int ArraySize(const std::vector<T>&v){return static_cast<int>(v.size());}
template<class T>void ArrayResize(std::vector<T>&v,int n){v.resize(n);}template<class T>void ArraySetAsSeries(std::vector<T>&,bool){}
enum{PERIOD_D1=1440,PERIOD_M5=5,SYMBOL_TRADE_TICK_SIZE=1,SYMBOL_FILLING_MODE,SYMBOL_VOLUME_STEP,SYMBOL_VOLUME_MIN,SYMBOL_VOLUME_MAX,
 SYMBOL_TRADE_STOPS_LEVEL,SYMBOL_CURRENCY_BASE,SYMBOL_CURRENCY_PROFIT,ACCOUNT_BALANCE,ACCOUNT_MARGIN_FREE,ACCOUNT_SERVER,ACCOUNT_LOGIN,
 POSITION_SYMBOL,POSITION_MAGIC,POSITION_TYPE,POSITION_SL,POSITION_TP,POSITION_TIME,POSITION_VOLUME,POSITION_IDENTIFIER,
 ORDER_SYMBOL,DEAL_SYMBOL,DEAL_MAGIC,DEAL_ENTRY,DEAL_ENTRY_IN,DEAL_ENTRY_INOUT,DEAL_TIME,
 DEAL_POSITION_ID,DEAL_PROFIT,DEAL_COMMISSION,DEAL_SWAP,DEAL_FEE,DEAL_TYPE,DEAL_PRICE,DEAL_VOLUME,DEAL_TIME_MSC,
 DEAL_ORDER,DEAL_REASON,DEAL_ENTRY_OUT,DEAL_ENTRY_OUT_BY,DEAL_TYPE_BUY,ORDER_SL,ORDER_TP,POSITION_PROFIT,POSITION_SWAP,
 DEAL_REASON_SL,DEAL_REASON_TP,DEAL_REASON_SO,DEAL_REASON_EXPERT,
 SYMBOL_FILLING_IOC=1,SYMBOL_FILLING_FOK=2,ORDER_FILLING_IOC=1,ORDER_FILLING_FOK=2,ORDER_FILLING_RETURN=3,
 ORDER_TYPE_BUY=0,ORDER_TYPE_SELL=1,POSITION_TYPE_BUY=0,POSITION_TYPE_SELL=1,TRADE_ACTION_DEAL=1,
 TRADE_RETCODE_DONE=10009,TRADE_RETCODE_DONE_PARTIAL=10010,TRADE_RETCODE_TIMEOUT=10012,TRADE_RETCODE_PLACED=10008,
 TRADE_RETCODE_CONNECTION=10031,TRADE_TRANSACTION_DEAL_ADD=1,MQL_TESTER=1,INIT_PARAMETERS_INCORRECT=-2,INIT_FAILED=-1,INIT_SUCCEEDED=0,
 INVALID_HANDLE=-1,FILE_COMMON=1,FILE_WRITE=2,FILE_CSV=4,FILE_ANSI=8,FILE_TXT=16,CP_UTF8=65001,TIME_DATE=1,TIME_SECONDS=2};
struct MqlRates{datetime time=0;double open=1.1,high=1.11,low=1.09,close=1.1;};
struct MqlTick{double bid=1.1,ask=1.1001;};
struct MqlTradeRequest{int action=0,type=0,type_filling=0;string symbol,comment;ulong magic=0,position=0;double volume=0,price=0,sl=0,tp=0;int deviation=0;};
struct MqlTradeResult{uint retcode=0;};struct MqlTradeCheckResult{uint retcode=0;string comment;};
struct MqlTradeTransaction{int type=0;ulong deal=0;};
string _Symbol="EURUSD";int _Digits=5;double _Point=.00001;
std::vector<MqlRates> history;
datetime now=D(12,12);MqlTick quote;
bool guard=true,haveHistory=true,checkOK=true,profitOK=true,sendOK=true,tester=false;
bool occupied=false,closed=false;double positionSL=1.05,positionTP=1.2;datetime positionOpened=D(8,12);
double balance=100000,freeMargin=100000;uint nextRetcode=TRADE_RETCODE_DONE;
std::vector<MqlTradeRequest> submissions;std::map<string,double> globals;
struct Deal{ulong id=0;datetime time=0;ulong magic=420606;long edge=DEAL_ENTRY_IN;
 ulong position=555;double price=1.1,volume=1,profit=0,commission=0,swap=0,fee=0;};
std::vector<Deal> deals;std::vector<Deal> selectedDeals;Deal selectedDeal;
datetime TimeCurrent(){return now;}
datetime iTime(const string&,int period,int shift){return period==PERIOD_D1?(shift==0?D(12):history[history.size()-1-shift].time):now-now%300;}
int iBarShift(const string&,int,datetime opened,bool){int count=0;for(auto b:history)if(b.time>=opened-opened%86400)count++;return count;}
int CopyRates(const string&,int,int shift,int count,std::vector<MqlRates>&out){assert(shift==1);out.clear();int begin=std::max(0,static_cast<int>(history.size())-count);for(int i=begin;i<static_cast<int>(history.size());i++)out.push_back(history[i]);return ArraySize(out);}
bool SymbolInfoTick(const string&,MqlTick &tick){tick=quote;return true;}
double SymbolInfoDouble(const string&,int field){switch(field){case SYMBOL_TRADE_TICK_SIZE:return .00001;case SYMBOL_VOLUME_STEP:return .01;case SYMBOL_VOLUME_MIN:return .01;case SYMBOL_VOLUME_MAX:return 100;default:return 0;}}
long SymbolInfoInteger(const string&,int field){return field==SYMBOL_FILLING_MODE?SYMBOL_FILLING_IOC:0;}
string SymbolInfoString(const string&,int field){return field==SYMBOL_CURRENCY_BASE?"EUR":"USD";}
double AccountInfoDouble(int field){return field==ACCOUNT_BALANCE?balance:freeMargin;}
string AccountInfoString(int){return "Mock";}long AccountInfoInteger(int){return 42;}
int PositionsTotal(){return occupied&&!closed?1:0;}ulong PositionGetTicket(int){return PositionsTotal()?123:0;}
string PositionGetString(int){return _Symbol;}
long PositionGetInteger(int field){switch(field){case POSITION_MAGIC:return 420606;case POSITION_TYPE:return POSITION_TYPE_BUY;case POSITION_TIME:return positionOpened;case POSITION_IDENTIFIER:return 555;default:return 0;}}
double PositionGetDouble(int field){return field==POSITION_SL?positionSL:(field==POSITION_TP?positionTP:1);}
bool PositionSelectByTicket(ulong){return PositionsTotal()>0;}
int OrdersTotal(){return 0;}ulong OrderGetTicket(int){return 0;}string OrderGetString(int){return _Symbol;}
bool HistorySelect(datetime start,datetime end){selectedDeals.clear();for(auto d:deals)if(d.time>=start&&d.time<=end)selectedDeals.push_back(d);return haveHistory;}
int HistoryDealsTotal(){return ArraySize(selectedDeals);}ulong HistoryDealGetTicket(int i){selectedDeal=selectedDeals[i];return selectedDeal.id;}
string HistoryDealGetString(ulong,int){return _Symbol;}
long HistoryDealGetInteger(ulong,int field){switch(field){case DEAL_MAGIC:return selectedDeal.magic;case DEAL_ENTRY:return selectedDeal.edge;
 case DEAL_POSITION_ID:return selectedDeal.position;case DEAL_ORDER:return 333;case DEAL_TYPE:return DEAL_TYPE_BUY;
 case DEAL_TIME_MSC:return selectedDeal.time*1000;case DEAL_REASON:return DEAL_REASON_EXPERT;default:return selectedDeal.time;}}
double HistoryDealGetDouble(ulong,int field){switch(field){case DEAL_PRICE:return selectedDeal.price;case DEAL_VOLUME:return selectedDeal.volume;
 case DEAL_PROFIT:return selectedDeal.profit;case DEAL_COMMISSION:return selectedDeal.commission;case DEAL_SWAP:return selectedDeal.swap;
 case DEAL_FEE:return selectedDeal.fee;default:return 0;}}
double HistoryOrderGetDouble(ulong,int field){return field==ORDER_SL?1.09:1.115;}
bool HistoryDealSelect(ulong){return true;}
bool GlobalVariableCheck(const string &key){return globals.count(key)>0;}
datetime GlobalVariableSet(const string &key,double v){globals[key]=v;return now;}
double GlobalVariableGet(const string &key){return globals[key];}void GlobalVariablesFlush(){}
bool GlobalVariableSetOnCondition(const string &key,double value,double expected){if(!globals.count(key)||globals[key]!=expected)return false;globals[key]=value;return true;}
bool OrderCalcProfit(int side,const string&,double volume,double entry,double stop,double &loss){loss=(side==ORDER_TYPE_BUY?stop-entry:entry-stop)*100000*volume;return profitOK;}
bool OrderCalcMargin(int,const string&,double,const double,double &margin){margin=1000;return true;}
bool OrderCheck(const MqlTradeRequest&,MqlTradeCheckResult &check){check.retcode=0;return checkOK;}
bool OrderSend(const MqlTradeRequest &req,MqlTradeResult &res){submissions.push_back(req);res.retcode=nextRetcode;return sendOK;}
bool E2PGCanEnter(){return guard;}int MQLInfoInteger(int){return tester;}ulong GetMicrosecondCount(){return 99;}
bool EventSetTimer(int){return true;}void EventKillTimer(){}
string DoubleToString(double value,int){return std::to_string(value);}
int StringLen(const string &s){return s.size();}unsigned short StringGetCharacter(const string &s,int i){return s[i];}
string TimeToString(datetime time,int){return std::to_string(time);}void StringReplace(string&,const string&,const string&){}
bool E2ReportFolder(const string&,string &out){out="reports";return true;}
string E2ReportBase(const string&,const string &run){return run;}string E2UniqueReportRun(const string &run){return run;}
std::map<int,std::vector<std::vector<string>>> csv;std::map<int,string> filePaths;int nextFile=1;
bool FileIsExist(const string&,int){return false;}int GetLastError(){return 0;}
int FileOpen(const string &path,int,char,int){filePaths[nextFile]=path;csv[nextFile].clear();return nextFile++;}
template<class T>string asText(const T &v){std::ostringstream s;s<<v;return s.str();}
template<class... T>void FileWrite(int file,T...v){csv[file].push_back({asText(v)...});}
void FileWriteString(int,const string&){}void FileFlush(int){}void FileClose(int){}
#include "../strategies/shared/SessionClock.mqh"
#include "../strategies/EURUSDTwoDayReversal/ReversalCore.mqh"
#include "runtime.mqh"
void reset(){
 globals.clear();submissions.clear();deals.clear();history.clear();csv.clear();filePaths.clear();nextFile=1;
 g_reportBase="";g_reportStartTime=now;g_recoveredIds.clear();g_signalFile=INVALID_HANDLE;g_equityFile=INVALID_HANDLE;g_equityMinute=0;
 for(int day=1;day<=11;day++)history.push_back({D(day),1.1,1.11,1.09,1.1});
 guard=true;haveHistory=true;checkOK=true;profitOK=true;sendOK=true;occupied=false;closed=false;
 nextRetcode=TRADE_RETCODE_DONE;now=D(12,12);quote={1.1,1.1001};
 InpATRSessionPeriod=2;InpMomentumSessions=2;InpEfficiencySessions=2;
 InpUseMomentumFilter=false;InpUseEfficiencyFilter=false;InpOneTradePerSession=true;
 InpBrokerClockVerified=true;InpBrokerClockMode=NP_FIXED_UTC_OFFSET;
 InpServerUTCOffsetWinterHours=0;InpServerUTCOffsetSummerHours=0;
 InpFixedCashRisk=1000;InpRiskMode=E2_RISK_FIXED_CASH;
 g_session=D(12);g_statePrefix="TEST_";g_snapshotReady=false;g_previousBid=0;g_lastCloseAttempt=0;g_running=false;
 StateWrite("SUBMITTED",0);StateWrite("PENDING",0);StateWrite("EXIT_PENDING",0);
 assert(BuildSnapshot());g_snapshotReady=true;
}
int main(){
 reset();assert(g_snapshot.high==1.11&&g_snapshot.low==1.09);
 assert(EligibleSession(D(9))&&!EligibleSession(D(11))); // Friday included, Sunday excluded
 Run(true);assert(submissions.empty());quote={1.09,1.0901};Run(true);
 assert(submissions.size()==1&&submissions[0].type==ORDER_TYPE_BUY);
 assert(submissions[0].sl<quote.bid&&submissions[0].tp>quote.ask);
 double loss=0;OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,submissions[0].volume,submissions[0].price,submissions[0].sl,loss);
 assert(-loss<=InpFixedCashRisk+1e-8);
 quote={1.1,1.1001};Run(true);quote={1.11,1.1101};Run(true);assert(submissions.size()==1);
 reset();AttemptEntry(-1,{1.11,1.1101});assert(submissions.size()==1&&submissions[0].type==ORDER_TYPE_SELL);
 assert(submissions[0].sl>1.1101&&submissions[0].tp<1.11);
 reset();guard=false;AttemptEntry(1,{1.09,1.0901});assert(submissions.empty());
 reset();AttemptEntry(1,{1.09,1.091});assert(submissions.empty()); // spread
 reset();InpFixedCashRisk=.1;AttemptEntry(1,{1.09,1.0901});assert(submissions.empty()); // below min lot
 reset();checkOK=false;AttemptEntry(1,{1.09,1.0901});assert(submissions.empty());
 reset();nextRetcode=TRADE_RETCODE_TIMEOUT;sendOK=false;AttemptEntry(1,{1.09,1.0901});assert(submissions.size()==1);
 assert(SubmissionBlocked());g_previousBid=0;g_session=D(13);now=D(13,12);
 assert(SubmissionBlocked());AttemptEntry(-1,{1.11,1.1101});assert(submissions.size()==1); // rollover/restart never unlock unknown fill
 deals.push_back({777,D(12,12),420606,DEAL_ENTRY_IN});assert(!SubmissionBlocked()); // authoritative fill resolves pending
 reset();nextRetcode=10006;AttemptEntry(1,{1.09,1.0901});assert(!SubmissionBlocked()); // definite rejection can recover
 reset();deals.push_back({888,now,420606,DEAL_ENTRY_IN});assert(SubmissionBlocked()); // restart consumes day's entry from history
 reset();haveHistory=false;assert(SubmissionBlocked());
 reset();occupied=true;AttemptEntry(1,{1.09,1.0901});assert(submissions.empty()); // manual/other strategy occupancy
 // Clock/guard/filters do not suppress time exits; Thursday and Friday count as two sessions.
 reset();occupied=true;guard=false;InpBrokerClockVerified=false;g_snapshot.allowed=false;
 assert(CompletedHoldingSessions(D(8,12))==2);ManageExits();assert(submissions.size()==1&&submissions[0].position==123);
 reset();occupied=true;positionOpened=now;positionSL=0;ManageExits();assert(submissions.size()==1);positionSL=1.05;
 // Timers never place entries, and the first quote after initialization is only a seed.
 reset();quote={1.09,1.0901};Run(false);Run(true);assert(submissions.empty());
 reset();InpBrokerClockVerified=false;Run(true);quote={1.09,1.0901};Run(true);assert(submissions.empty());
 // A second chart cannot acquire an already-held submission intent.
 reset();StateWrite("PENDING",1);assert(!GlobalVariableSetOnCondition(g_statePrefix+"PENDING",1,0));
 // The actual exporter reconciles entry commission with a different-magic manual exit.
 reset();g_reportBase="fixture";g_reportStartTime=D(12);
 deals.push_back({100,D(12,1),420606,DEAL_ENTRY_IN,555,1.1,1,0,-3,0,0});
 deals.push_back({101,D(12,2),999,DEAL_ENTRY_OUT,555,1.11,1,1000,-3,-4,-1});
 RExportTrades();assert(csv[1].size()==2);
 auto row=csv[1][1];assert(row[10]=="FINALIZED");assert(std::abs(std::stod(row[8])-989)<1e-8);
 assert(std::abs(std::stod(row[9])-1000)<1e-8&&std::abs(std::stod(row[19])-.989)<1e-8);
 g_equityFile=2;REquity(now);assert(std::abs(std::stod(csv[2][0][3])-989)<1e-8);
 // A position opened before a restart still exports its complete history.
 g_reportStartTime=D(12,2);g_recoveredIds.push_back(555);RExportTrades();assert(csv[2].size()==2);
 assert(std::abs(std::stod(csv[2][1][8])-989)<1e-8);
 std::cout<<"Actual two-day EA runtime: both directions, guard, SL/TP, risk, restarts, uncertain fills, exits and timer isolation passed\n";
 std::cout<<"Actual CSV exporter: manual exits, recovered positions, cash equity and net R reconcile\n";
}
