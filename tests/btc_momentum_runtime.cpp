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
enum{PERIOD_D1=1440,PERIOD_H1=60,PERIOD_H4=240,PRICE_CLOSE=0,PERIOD_M5=5,PERIOD_M30=30,SYMBOL_TRADE_CONTRACT_SIZE=99,SYMBOL_TRADE_TICK_SIZE=1,SYMBOL_FILLING_MODE,SYMBOL_VOLUME_STEP,SYMBOL_VOLUME_MIN,SYMBOL_VOLUME_MAX,
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
struct MqlTick{double bid=10000,ask=10000.01;datetime time=0;};
struct MqlTradeRequest{int action=0,type=0,type_filling=0;string symbol,comment;ulong magic=0,position=0;double volume=0,price=0,sl=0,tp=0;int deviation=0;};
struct MqlTradeResult{uint retcode=0;};struct MqlTradeCheckResult{uint retcode=0;string comment;};
struct MqlTradeTransaction{int type=0;ulong deal=0;};
string _Symbol="BTCUSD";int _Digits=2;double _Point=.01;
std::vector<MqlRates> history,m30History;
std::vector<double> rsiValues;std::vector<datetime> h4Times;bool indicatorOK=true;
datetime now=D(12,12);MqlTick quote;
bool guard=true,haveHistory=true,checkOK=true,profitOK=true,sendOK=true,tester=false;
bool occupied=false,closed=false;double positionSL=1.05,positionTP=1.2;datetime positionOpened=D(8,12);
double volumeMinimum=.01,volumeMaximum=100,volumeStep=.01,contractSize=1,marginPerLot=1000;
double balance=100000,freeMargin=100000;uint nextRetcode=TRADE_RETCODE_DONE;
std::vector<MqlTradeRequest> submissions;std::map<string,double> globals;
struct Deal{ulong id=0;datetime time=0;ulong magic=420609;long edge=DEAL_ENTRY_IN;
 ulong position=555;double price=1.1,volume=1,profit=0,commission=0,swap=0,fee=0;};
std::vector<Deal> deals;std::vector<Deal> selectedDeals;Deal selectedDeal;
datetime TimeCurrent(){return now;}
datetime iTime(const string&,int period,int shift){
 if(period==PERIOD_H1)return now-now%3600;
 if(period==PERIOD_H4)return shift==1?h4Times.back():now-now%14400;
 return now-now%300;
}
int iRSI(const string&,int,int,int){return indicatorOK?42:INVALID_HANDLE;}
void IndicatorRelease(int){}
int BarsCalculated(int){return indicatorOK?static_cast<int>(rsiValues.size()):0;}
int CopyBuffer(int,int,int shift,int count,std::vector<double>&out){assert(shift==1);if(!indicatorOK)return 0;out.assign(rsiValues.end()-count,rsiValues.end());return count;}
int CopyTime(const string&,int period,int shift,int count,std::vector<datetime>&out){assert(period==PERIOD_H4&&shift==1);out.assign(h4Times.end()-count,h4Times.end());return count;}
int CopyRates(const string&,int period,datetime start,datetime end,std::vector<MqlRates>&out){assert(period==PERIOD_H1);out.clear();for(auto b:history)if(b.time>=start&&b.time<=end)out.push_back(b);return ArraySize(out);}
bool SymbolInfoTick(const string&,MqlTick &tick){tick=quote;return true;}
double SymbolInfoDouble(const string&,int field){switch(field){case SYMBOL_TRADE_TICK_SIZE:return .01;case SYMBOL_VOLUME_STEP:return volumeStep;case SYMBOL_VOLUME_MIN:return volumeMinimum;case SYMBOL_VOLUME_MAX:return volumeMaximum;case SYMBOL_TRADE_CONTRACT_SIZE:return contractSize;default:return 0;}}
long SymbolInfoInteger(const string&,int field){return field==SYMBOL_FILLING_MODE?SYMBOL_FILLING_IOC:0;}
string SymbolInfoString(const string&,int field){return field==SYMBOL_CURRENCY_BASE?"BTC":"USD";}
double AccountInfoDouble(int field){return field==ACCOUNT_BALANCE?balance:freeMargin;}
string AccountInfoString(int){return "Mock";}long AccountInfoInteger(int){return 42;}
int PositionsTotal(){return occupied&&!closed?1:0;}ulong PositionGetTicket(int){return PositionsTotal()?123:0;}
string PositionGetString(int){return _Symbol;}
long PositionGetInteger(int field){switch(field){case POSITION_MAGIC:return 420609;case POSITION_TYPE:return POSITION_TYPE_BUY;case POSITION_TIME:return positionOpened;case POSITION_IDENTIFIER:return 555;default:return 0;}}
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
bool OrderCalcProfit(int side,const string&,double volume,double entry,double stop,double &loss){loss=(side==ORDER_TYPE_BUY?stop-entry:entry-stop)*volume*contractSize;return profitOK;}
bool OrderCalcMargin(int,const string&,double volume,const double,double &margin){margin=marginPerLot*volume;return true;}
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
#include "core.mqh"
#include "runtime.mqh"
void reset(){
 globals.clear();submissions.clear();deals.clear();history.clear();csv.clear();filePaths.clear();nextFile=1;
 now=D(12,12);quote={10000,10000.01,now};indicatorOK=true;
 rsiValues.assign(64,50);rsiValues.back()=72;h4Times.clear();
 for(int i=0;i<64;i++)h4Times.push_back(now-14400*(64-i));
 history.push_back({now-3600,10000,10010,9990,10000});
 guard=true;haveHistory=true;checkOK=true;profitOK=true;sendOK=true;occupied=false;closed=false;
 nextRetcode=TRADE_RETCODE_DONE;balance=100000;freeMargin=100000;
 volumeMinimum=.01;volumeMaximum=100;volumeStep=.01;contractSize=1;marginPerLot=1000;InpRiskTolerancePercent=2;
 InpRSIPeriod=20;InpRSIThreshold=70;InpBaseEntry=true;InpEntryMode=BTC_HYBRID;
 InpFixedCashRisk=1000;InpRiskMode=E2_RISK_FIXED_CASH;InpStopPercent=1.25;
 InpMaxEntriesPerZone=6;InpCooldownHours=2;InpMaxHoldingHours=0;
 InpWeekendFlat=false;InpFridayFlatHour=20;InpFridayFlatMinute=0;
 InpBrokerClockVerified=true;InpBrokerClockMode=NP_FIXED_UTC_OFFSET;
 InpServerUTCOffsetWinterHours=0;InpServerUTCOffsetSummerHours=0;
 g_rsiHandle=42;g_lastH1=now-3600;g_statePrefix="BTC_TEST_";g_lastCloseAttempt=0;g_running=false;
 g_reportBase="";g_reportStartTime=now;g_recoveredIds.clear();g_signalFile=INVALID_HANDLE;g_equityFile=INVALID_HANDLE;g_equityMinute=0;
 StateWrite("SUBMITTED",0);StateWrite("PENDING",0);StateWrite("EXIT_PENDING",0);StateWrite("SIGNAL",0);
 positionSL=1.05;positionTP=1.2;positionOpened=D(8,12);
}
int main(){
 reset();datetime start=0;double r=0;assert(ActiveZone(now,start,r)&&start==now&&r==72);
 Run(true);assert(submissions.size()==1&&submissions[0].type==ORDER_TYPE_BUY);
 auto req=submissions[0];assert(req.sl<quote.bid&&req.tp>quote.ask);
 assert(std::abs((req.price-req.sl)-(req.tp-req.price))<.011);
 double loss=0;OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,req.volume,req.price,req.sl,loss);assert(-loss<=1000+1e-8);
 now+=10;quote.time=now;Run(true);assert(submissions.size()==1); // once per bar
 g_lastH1=now-now%3600-3600;Run(true);assert(submissions.size()==1); // durable signal lock after restart
 reset();g_lastH1=now;Run(true);assert(submissions.empty()); // attach doesn't replay base
 reset();Run(false);assert(submissions.empty()); // timer isolation
 reset();rsiValues.back()=70;Run(true);assert(submissions.empty()); // strict threshold
 reset();rsiValues.assign(64,72);Run(true);assert(submissions.empty()); // truncated zone fails closed
 reset();indicatorOK=false;Run(true);assert(submissions.empty());indicatorOK=true;Run(true);assert(submissions.size()==1);
 reset();now+=61;quote.time=now;Run(true);assert(submissions.empty()); // stale entry boundary
 reset();quote.time=now-11;Run(true);assert(submissions.empty());quote.time=now;Run(true);assert(submissions.empty()); // consume blocked signal
 reset();guard=false;Run(true);assert(submissions.empty());guard=true;Run(true);assert(submissions.empty());
 reset();InpBrokerClockVerified=false;Run(true);assert(submissions.empty());
 reset();quote.ask=10010;Run(true);assert(submissions.empty()); // spread cap
 reset();haveHistory=false;Run(true);assert(submissions.empty());
 reset();occupied=true;Run(true);assert(submissions.empty());
 reset();InpFixedCashRisk=.1;AttemptEntry(quote,now,"BASE");assert(submissions.empty());
 reset();profitOK=false;AttemptEntry(quote,now,"BASE");assert(submissions.empty());
 reset();checkOK=false;AttemptEntry(quote,now,"BASE");assert(submissions.empty());
 reset();InpRiskMode=E2_RISK_BALANCE_PERCENT;InpBalanceRiskPercent=.5;AttemptEntry(quote,now,"BASE");
 assert(submissions.size()==1);OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,submissions[0].volume,submissions[0].price,submissions[0].sl,loss);assert(-loss<=500+1e-8);
 // Reproduce the uploaded tiny constant-lot configuration: fail rather than risk cents.
 reset();contractSize=100000;volumeMinimum=1e-8;volumeMaximum=1e-7;volumeStep=1e-8;
 assert(SizeForStop(ORDER_TYPE_BUY,454.3102,448.6313)==0);
 AttemptEntry(quote,now,"BASE");assert(submissions.empty());
 // Corrected lot bounds permit the same intended cash risk under a 100,000 contract.
 volumeMaximum=1;assert(SizeForStop(ORDER_TYPE_BUY,454.3102,448.6313)>0);
 double lot=SizeForStop(ORDER_TYPE_BUY,454.3102,448.6313);
 OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,lot,454.3102,448.6313,loss);assert(-loss>=980&&-loss<=1000);
 // No shrinking risk to accommodate available margin.
 reset();freeMargin=500;AttemptEntry(quote,now,"BASE");assert(submissions.empty());
 // Lot ceiling and coarse lot steps both enforce the risk tolerance.
 reset();volumeMaximum=1;assert(SizeForStop(ORDER_TYPE_BUY,10000,9875)==0);
 reset();volumeStep=3;assert(SizeForStop(ORDER_TYPE_BUY,10000,9875)==0);
 reset();volumeStep=.1;lot=SizeForStop(ORDER_TYPE_BUY,10000,9871);assert(lot>0&&lot*129>=980&&lot*129<=1000);
 reset();marginPerLot=0;assert(SizeForStop(ORDER_TYPE_BUY,10000,9875)>0); // valid zero-margin symbol
 reset();assert(ValidInputs());InpRiskTolerancePercent=11;assert(!ValidInputs());
 // Unknown execution survives restart/rollover; authoritative history resolves it.
 reset();sendOK=false;nextRetcode=TRADE_RETCODE_TIMEOUT;AttemptEntry(quote,now,"BASE");assert(SubmissionBlocked());
 now+=3600;quote.time=now;assert(SubmissionBlocked());AttemptEntry(quote,now,"BASE");assert(submissions.size()==1);
 deals.push_back({777,now-3600,420609,DEAL_ENTRY_IN});assert(!SubmissionBlocked());
 reset();nextRetcode=10006;AttemptEntry(quote,now,"BASE");assert(!SubmissionBlocked());
 // Zone budget counts unique positions, not partial fills.
 reset();for(int i=0;i<6;i++)deals.push_back({static_cast<ulong>(10+i),now,420609,DEAL_ENTRY_IN,static_cast<ulong>(100+i)});
 deals.push_back({17,now,420609,DEAL_ENTRY_IN,100});int used=0;datetime exit=0;
 assert(ZoneUsage(now,used,exit)&&used==6);AttemptEntry(quote,now,"BASE");assert(submissions.empty());
 // A manual/guard exit consumes cooldown too.
 reset();deals.push_back({10,now-1000,420609,DEAL_ENTRY_IN,100});
 deals.push_back({11,now-1,999,DEAL_ENTRY_OUT,100});AttemptEntry(quote,now-2000,"PULLBACK");assert(submissions.empty());
 // Completed H1 pullback and breakout signals, excluding current-bar highs.
 reset();rsiValues[62]=72;InpBaseEntry=false;history.clear();
 history.push_back({now-5*3600,10100,10110,10090,10100});history.push_back({now-3600,10000,10010,9990,10000});
 Run(true);assert(submissions.size()==1); // .99% drop from zone close high
 reset();rsiValues[62]=72;InpBaseEntry=false;InpEntryMode=BTC_BREAKOUT;history.clear();
 history.push_back({now-5*3600,10000,10000,9990,10000});history.push_back({now-3600,10030,10040,10020,10030});
 Run(true);assert(submissions.size()==1); // current high 10040 must not enter lookback
 // Price bracket remains active through regime exit, clock loss and guard block.
 reset();occupied=true;guard=false;InpBrokerClockVerified=false;ManageExits();assert(submissions.empty());
 InpMaxHoldingHours=24;ManageExits();assert(submissions.size()==1&&submissions[0].position==123);
 reset();occupied=true;positionSL=0;ManageExits();assert(submissions.size()==1);
 // Server-time Friday boundary; partial-hour cutoff and the entire weekend.
 reset();InpWeekendFlat=true;InpFridayFlatMinute=30;
 assert(!WeekendFlatWindow(D(16,20)+29*60+59));
 assert(WeekendFlatWindow(D(16,20)+30*60));
 assert(WeekendFlatWindow(D(17))&&WeekendFlatWindow(D(18,23)));
 assert(!WeekendFlatWindow(D(19)));
 InpWeekendFlat=false;assert(!WeekendFlatWindow(D(17)));
 // Weekend closing is independent of entry history, UTC profile and guard.
 reset();InpWeekendFlat=true;now=D(16,20);quote.time=now;occupied=true;
 guard=false;haveHistory=false;InpBrokerClockVerified=false;Run(false);
 assert(submissions.size()==1&&submissions[0].position==123&&submissions[0].type==ORDER_TYPE_SELL);
 // Rejected closes retry after five seconds, never open a replacement trade.
 reset();InpWeekendFlat=true;now=D(16,20);quote.time=now;occupied=true;nextRetcode=10018;
 Run(true);assert(submissions.size()==1&&submissions[0].position==123);
 now+=4;Run(true);assert(submissions.size()==1);
 now++;Run(false);assert(submissions.size()==2&&submissions[1].position==123);
 // Entry gate cannot be bypassed through the direct submission path.
 reset();InpWeekendFlat=true;now=D(16,20);quote.time=now;
 AttemptEntry(quote,now,"BASE");assert(submissions.empty());
 now=D(17);quote.time=now;AttemptEntry(quote,now,"BASE");assert(submissions.empty());
 now=D(18,23);quote.time=now;AttemptEntry(quote,now,"BASE");assert(submissions.empty());
 // Monday may submit a fresh signal; the completed blocked H1 isn't replayed.
 Run(true);assert(g_lastH1==now);
 now=D(19);quote.time=now;AttemptEntry(quote,now,"BASE");assert(submissions.size()==1);
 // A missed Friday close survives a Monday restart; fresh Monday positions stay.
 reset();InpWeekendFlat=true;now=D(19,1);quote.time=now;occupied=true;positionOpened=D(16,19);
 Run(false);assert(submissions.size()==1&&submissions[0].position==123);
 reset();InpWeekendFlat=true;now=D(19,1);quote.time=now;occupied=true;positionOpened=D(19);
 Run(false);assert(submissions.empty());
 assert(!WeekendExitDue(D(16,19),D(16,18))); // Friday before this week's cutoff
 assert(WeekendExitDue(D(16,19),D(9,18))); // already carried over last weekend
 reset();InpFridayFlatHour=24;assert(!ValidInputs());
 reset();InpFridayFlatMinute=60;assert(!ValidInputs());
 // Ambiguous close stays pending rather than resubmitting.
 reset();occupied=true;positionSL=0;sendOK=false;nextRetcode=TRADE_RETCODE_CONNECTION;ManageExits();
 now+=10;ManageExits();assert(submissions.size()==1);
 // Actual CSV exporter includes entry fees and different-magic manual exit.
 reset();g_reportBase="fixture";g_reportStartTime=D(12);
 deals.push_back({100,D(12,1),420609,DEAL_ENTRY_IN,555,1.1,1,0,-.001,0,0});
 deals.push_back({101,D(12,2),999,DEAL_ENTRY_OUT,555,1.11,1,.01,-.001,-.001,-.001});
 RExportTrades();assert(csv[1].size()==2);auto row=csv[1][1];assert(row[10]=="FINALIZED");
 assert(std::abs(std::stod(row[8])-.006)<1e-8&&std::abs(std::stod(row[19])-.6)<1e-8);
 g_equityFile=2;REquity(now);assert(std::abs(std::stod(csv[2][0][3])-.006)<1e-8);
 auto hash=RConfig();InpStopPercent=2;assert(RConfig()!=hash);
 hash=RConfig();InpWeekendFlat=true;assert(RConfig()!=hash);
 hash=RConfig();InpFridayFlatMinute=30;assert(RConfig()!=hash);
 std::cout<<"BTC EA runtime: completed H4/H1 signals, strict 1R, guards, costs, zone limits, cooldown, restart/timeout and independent exits passed\n";
}
