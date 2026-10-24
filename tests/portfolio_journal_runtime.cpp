// Execute the actual MQL reporting module against deterministic broker/file APIs.
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <vector>
using string=std::string;using datetime=long long;
enum {INVALID_HANDLE=-1,FILE_READ=1,FILE_WRITE=2,FILE_CSV=4,FILE_ANSI=8,FILE_COMMON=16,
 FILE_SHARE_READ=32,FILE_BIN=64,FILE_REWRITE=128,CP_UTF8=65001,TIME_DATE=1,TIME_SECONDS=2,
 MQL_TESTER=1,TERMINAL_CONNECTED=2,ACCOUNT_SERVER=3,ACCOUNT_LOGIN=4,
 DEAL_TYPE=10,DEAL_ENTRY,DEAL_MAGIC,DEAL_TIME,DEAL_TIME_MSC,DEAL_POSITION_ID,DEAL_SYMBOL,
 DEAL_PRICE,DEAL_VOLUME,DEAL_SL,DEAL_TP,DEAL_PROFIT,DEAL_COMMISSION,DEAL_SWAP,DEAL_FEE,DEAL_REASON,
 POSITION_IDENTIFIER,DEAL_TYPE_BUY=50,DEAL_TYPE_SELL,DEAL_TYPE_BALANCE,
 DEAL_ENTRY_IN=60,DEAL_ENTRY_OUT,DEAL_ENTRY_OUT_BY,DEAL_ENTRY_INOUT,
 ORDER_TYPE_BUY=70,ORDER_TYPE_SELL,DEAL_REASON_SL=80,DEAL_REASON_TP,DEAL_REASON_SO,DEAL_REASON_EXPERT,
 TRADE_TRANSACTION_DEAL_ADD=90};
struct MqlTradeTransaction {int type=TRADE_TRANSACTION_DEAL_ADD;ulong deal=0;};
datetime now=1760000000;bool connected=true,historyOK=true,tester=false,profitOK=true,moveOK=true,writeOK=true;
int errorCode=0,profitCalls=0;double conversion=1;long login=123;
struct Deal {ulong id=0,position=0,magic=420609;long edge=DEAL_ENTRY_IN,type=DEAL_TYPE_BUY,ms=0;
 string symbol="BTCUSD";double price=100,volume=1,sl=90,tp=110,profit=0,commission=0,swap=0,fee=0;long reason=DEAL_REASON_EXPERT;};
std::vector<Deal> history;std::vector<ulong> selected;std::set<ulong> opened;ulong currentPosition=0;
Deal &deal(ulong id){for(auto &d:history)if(d.id==id)return d;assert(false);return history.front();}
datetime TimeLocal(){return now;}datetime TimeCurrent(){return now;}
int MQLInfoInteger(int){return tester;}long TerminalInfoInteger(int){return connected;}
string AccountInfoString(int){return "Broker-Test";}long AccountInfoInteger(int){return login;}
template<class... T>void Print(T...){}
template<class T>int ArraySize(const std::vector<T>&v){return static_cast<int>(v.size());}
template<class T>void ArrayResize(std::vector<T>&v,int n){v.resize(n);}
template<class T>void ArraySort(std::vector<T>&v){std::sort(v.begin(),v.end());}
template<class T>void ArrayCopy(std::vector<T>&to,const std::vector<T>&from){to=from;}
template<class T>void ZeroMemory(T &v){v=T{};}
double MathAbs(double v){return std::abs(v);}bool MathIsValidNumber(double v){return std::isfinite(v);}
string DoubleToString(double v,int digits){std::ostringstream s;s<<std::fixed<<std::setprecision(digits)<<v;return s.str();}
long StringToInteger(const string &s){try{return std::stoll(s);}catch(...){return 0;}}
double StringToDouble(const string &s){try{return std::stod(s);}catch(...){return 0;}}
template<class T>string StringFormat(const string &format,T v){char b[128];string f=format;
 auto p=f.find("I64");if(p!=string::npos)f.replace(p,3,"l");std::snprintf(b,sizeof(b),f.c_str(),v);return b;}
string TimeToString(datetime t,int){return std::to_string(t);}
void StringReplace(string &s,const string &from,const string &to){auto p=s.find(from);if(p!=string::npos)s.replace(p,from.size(),to);}
bool HistorySelect(datetime start,datetime end){selected.clear();if(!historyOK)return false;
 for(auto d:history)if(d.ms/1000>=start&&d.ms/1000<=end)selected.push_back(d.id);return true;}
int HistoryDealsTotal(){return selected.size();}ulong HistoryDealGetTicket(int i){return selected[i];}
bool HistoryDealSelect(ulong id){selected.clear();for(auto d:history)if(d.id==id){selected.push_back(id);return true;}return false;}
long HistoryDealGetInteger(ulong id,int field){auto d=deal(id);switch(field){case DEAL_TYPE:return d.type;case DEAL_ENTRY:return d.edge;
 case DEAL_MAGIC:return d.magic;case DEAL_TIME:return d.ms/1000;case DEAL_TIME_MSC:return d.ms;case DEAL_POSITION_ID:return d.position;default:return d.reason;}}
string HistoryDealGetString(ulong id,int){return deal(id).symbol;}
double HistoryDealGetDouble(ulong id,int field){auto d=deal(id);switch(field){case DEAL_PRICE:return d.price;case DEAL_VOLUME:return d.volume;
 case DEAL_SL:return d.sl;case DEAL_TP:return d.tp;case DEAL_PROFIT:return d.profit;case DEAL_COMMISSION:return d.commission;
 case DEAL_SWAP:return d.swap;case DEAL_FEE:return d.fee;default:return 0;}}
bool OrderCalcProfit(int side,const string&,double volume,double price,double stop,double &loss){profitCalls++;
 loss=(side==ORDER_TYPE_BUY?stop-price:price-stop)*volume*conversion;return profitOK;}
int PositionsTotal(){return opened.size();}ulong PositionGetTicket(int i){auto p=opened.begin();std::advance(p,i);currentPosition=*p;return *p;}
long PositionGetInteger(int){return currentPosition;}
// CSV fields/line boundaries are modeled explicitly, including persistent files.
using Table=std::vector<std::vector<string>>;
std::map<string,Table> disk;std::map<int,string> paths;std::map<int,int> flags;
std::map<int,std::pair<int,int>> cursor;int nextHandle=1;
void ResetLastError(){errorCode=0;}int GetLastError(){return errorCode;}
bool FileIsExist(const string &path,int){return disk.count(path);}
int FileOpen(const string &path,int mode,char=',',int=CP_UTF8){
 if(mode&FILE_BIN){for(auto [h,p]:paths)if(p==path)return INVALID_HANDLE;}
 if((mode&FILE_READ)&&!(mode&FILE_WRITE)&&!disk.count(path))return INVALID_HANDLE;
 if(mode&FILE_WRITE)disk[path].clear();
 int h=nextHandle++;paths[h]=path;flags[h]=mode;cursor[h]={0,0};return h;}
template<class T>string asText(T v){std::ostringstream s;s<<v;return s.str();}
template<class... T>unsigned FileWrite(int h,T...v){if(!writeOK){errorCode=1;return 0;}disk[paths[h]].push_back({asText(v)...});return 1;}
void FileFlush(int){}void FileClose(int h){paths.erase(h);flags.erase(h);cursor.erase(h);}
bool FileIsEnding(int h){auto c=cursor[h];auto &t=disk[paths[h]];return c.first>=static_cast<int>(t.size())||
 (c.first==static_cast<int>(t.size())-1&&c.second>=static_cast<int>(t.back().size()));}
bool FileIsLineEnding(int h){auto c=cursor[h];auto &t=disk[paths[h]];return c.first>=static_cast<int>(t.size())||c.second>=static_cast<int>(t[c.first].size());}
string FileReadString(int h){auto &c=cursor[h];auto &t=disk[paths[h]];
 if(c.first<static_cast<int>(t.size())&&c.second>=static_cast<int>(t[c.first].size())){c.first++;c.second=0;}
 if(c.first>=static_cast<int>(t.size()))return "";return t[c.first][c.second++];}
bool FileMove(const string &from,int,const string &to,int){if(!moveOK)return false;disk[to]=disk[from];disk.erase(from);return true;}
bool E2ReportFolder(const string&,string &folder){folder="E2/Portfolio";return true;}
string E2PathPart(const string &s){return s;}
#include "journal.mqh"
void resetMemory(){
 pgj_risks.clear();pgj_pending.clear();pgj_previous.clear();pgj_base="";pgj_lock=INVALID_HANDLE;
 pgj_active=false;pgj_dirty=true;pgj_risk_dirty=false;pgj_last_scan=0;pgj_last_attempt=0;pgj_last_warning=0;
 InpLiveJournalEnabled=true;InpJournalRefreshSeconds=60;
}
void reset(){
 paths.clear();disk.clear();cursor.clear();flags.clear();history.clear();selected.clear();opened.clear();
 now=1760000000;connected=true;historyOK=true;tester=false;profitOK=true;moveOK=true;writeOK=true;
 conversion=1;profitCalls=0;login=123;errorCode=0;resetMemory();
}
Deal entry(ulong id,ulong position,ulong magic=420609,double volume=1){Deal d;d.id=id;d.position=position;d.magic=magic;d.volume=volume;d.ms=now*1000;return d;}
Deal close(ulong id,ulong position,double volume=1,double profit=10){auto d=entry(id,position,999,volume);d.edge=DEAL_ENTRY_OUT;d.type=DEAL_TYPE_SELL;
 d.price=110;d.profit=profit;return d;}
void liveEntry(Deal d){history.push_back(d);opened.insert(d.position);PGJTransaction({TRADE_TRANSACTION_DEAL_ADD,d.id});}
void finish(Deal d){history.push_back(d);opened.erase(d.position);PGJTransaction({TRADE_TRANSACTION_DEAL_ADD,d.id});now+=5;PGJTimer();}
Table csv(){return disk[pgj_base+"_Trades.csv"];}
int main(){
 // All five magic numbers, partial fills/closes, manual exits, all fees and exact R.
 reset();PGJInit();assert(pgj_active);
 const ulong magics[]={2026001,2026091703,420603,420605,420609};
 for(int i=0;i<5;i++){
  auto a=entry(10+i*10,100+i,magics[i],.4);a.commission=-.1;liveEntry(a);
  auto b=entry(11+i*10,100+i,magics[i],.6);b.commission=-.2;liveEntry(b);
  auto c=close(12+i*10,100+i,.3,3);c.fee=-.1;history.push_back(c);PGJTransaction({TRADE_TRANSACTION_DEAL_ADD,c.id});
  now+=5;PGJTimer();assert(csv().size()==static_cast<size_t>(i+1)); // open trade excluded
  auto z=close(13+i*10,100+i,.7,7);z.commission=-.2;z.swap=-.4;z.fee=-.1;finish(z);
 }
 auto t=csv();assert(t.size()==6);
 for(int i=1;i<=5;i++){assert(t[i].size()==30);assert(t[i][9]=="FINALIZED");
  assert(std::abs(std::stod(t[i][7])-8.9)<1e-8);assert(std::abs(std::stod(t[i][8])-10)<1e-8);
  assert(std::abs(std::stod(t[i][21])-.89)<1e-8);assert(t[i][28]=="BROKER_SERVER");}
 // Repeated callbacks, timers and restarts overwrite the same file without duplicates.
 string filename=pgj_base+"_Trades.csv";PGJTransaction({TRADE_TRANSACTION_DEAL_ADD,53});now+=5;PGJTimer();assert(csv()==t);
 PGJClose();resetMemory();conversion=99;now+=100;PGJInit();assert(pgj_active);PGJTimer();assert(csv()==t);
 assert(pgj_risks.size()==10); // historical conversions aren't recomputed at restart
 // Closed, historical trades without a live snapshot retain cash but never invent R.
 PGJClose();reset();auto a=entry(1,200);a.ms-=100000;history.push_back(a);auto z=close(2,200);z.ms-=50000;history.push_back(z);
 PGJInit();PGJTimer();t=csv();assert(t.size()==2&&t[1][7]=="10.00000000"&&t[1][8].empty()&&t[1][21].empty());
 assert(t[1][23]=="INITIAL_RISK_UNAVAILABLE"&&profitCalls==0);
 // Delayed fees are reflected; partial closes never become duplicate completed rows.
 deal(2).commission=-1;now+=60;PGJTimer();assert(csv()[1][7]=="9.00000000");
 // A shorter history, unavailable history, disconnect, write error or failed replace
 // preserves the last good CSV and retries. Restoration succeeds without duplication.
 t=csv();auto full=history;history.clear();now+=60;PGJTimer();assert(csv()==t);
 history=full;historyOK=false;now+=60;PGJTimer();assert(csv()==t);
 historyOK=true;connected=false;now+=60;PGJTimer();assert(csv()==t);
 connected=true;moveOK=false;deal(2).profit=20;now+=60;PGJTimer();assert(csv()==t);
 moveOK=true;writeOK=false;now+=60;PGJTimer();assert(csv()==t);
 writeOK=true;now+=5;PGJTimer();assert(csv()[1][7]=="19.00000000");
 t=csv();PGJClose();resetMemory();history.clear();now+=60;PGJInit();PGJTimer();assert(csv()==t);
 history=full;deal(2).profit=20;now+=60;PGJTimer();assert(csv()==t);
 // Exclude deposits and unrelated/manual-origin trades.
 auto deposit=entry(3,0,0);deposit.type=DEAL_TYPE_BALANCE;deposit.profit=10000;history.push_back(deposit);
 history.push_back(entry(4,300,777));history.push_back(close(5,300));now+=60;PGJTimer();assert(csv().size()==2);
 // A netting position mixed with another strategy gets no fabricated strategy R.
 PGJClose();reset();PGJInit();liveEntry(entry(1,400));liveEntry(entry(2,400,420605));finish(close(3,400,2,20));
 assert(csv().size()==2&&csv()[1][9]=="INVALID"&&csv()[1][21].empty());
 // Reversals are explicitly invalid, not interpreted as clean long-only trades.
 PGJClose();reset();PGJInit();auto reversal=entry(1,401);reversal.edge=DEAL_ENTRY_INOUT;history.push_back(reversal);
 history.push_back(close(2,401));PGJTimer();assert(csv().size()==2&&csv()[1][9]=="INVALID");
 // Journal is disabled in tester and on request, without opening any files.
 PGJClose();reset();tester=true;PGJInit();assert(!pgj_active&&disk.empty());
 tester=false;InpLiveJournalEnabled=false;PGJInit();assert(!pgj_active&&disk.empty());
 // Writer lock prevents another terminal from using the same account journal.
 reset();PGJInit();int lock=pgj_lock;assert(lock!=INVALID_HANDLE);resetMemory();PGJInit();assert(!pgj_active);
 FileClose(lock);resetMemory();PGJInit();assert(pgj_active);
 PGJClose();resetMemory();login=456;PGJInit();assert(pgj_base.find("456")!=string::npos);
 // Corrupt risk state / malformed existing CSV never get overwritten as empty files.
 PGJClose();reset();PGJInit();string base=pgj_base;PGJClose();disk[base+"_risk.dat"]={{"CORRUPT"}};
 resetMemory();PGJInit();assert(!pgj_active&&disk[base+"_risk.dat"][0][0]=="CORRUPT");
 disk.erase(base+"_risk.dat");disk[base+"_Trades.csv"]={{"wrong-header"}};
 resetMemory();PGJInit();assert(!pgj_active&&disk[base+"_Trades.csv"][0][0]=="wrong-header");
 // Deal callback may precede history visibility; capture only once when it arrives.
 reset();PGJInit();PGJTransaction({TRADE_TRANSACTION_DEAL_ADD,1});assert(pgj_pending.size()==1);
 now++;liveEntry(entry(1,600));PGJTimer();assert(pgj_pending.empty()&&pgj_risks.size()==1);
 finish(close(2,600));assert(csv().size()==2&&csv()[1][8]=="10.00000000");
 // A temporarily missing conversion retries, without substituting requested risk.
 PGJClose();reset();PGJInit();profitOK=false;liveEntry(entry(1,601));assert(pgj_pending.size()==1);
 profitOK=true;now+=2;PGJTimer();assert(pgj_pending.empty()&&pgj_risks.size()==1);
 // Session Momentum both sides, zero TP and preserved initial-risk snapshots.
 PGJClose();reset();PGJInit();
 assert(PGJName(420611)=="NAS100_SESSION_MOMENTUM");
 auto smLong=entry(1,701,420611);smLong.tp=0;liveEntry(smLong);finish(close(2,701));
 assert(csv()[1][2]=="NAS100_SESSION_MOMENTUM"&&csv()[1][4]=="LONG");
 assert(csv()[1][8]=="10.00000000"&&csv()[1][20].empty());
 auto smShort=entry(3,702,420611);smShort.type=DEAL_TYPE_SELL;smShort.sl=110;smShort.tp=0;
 liveEntry(smShort);auto shortExit=close(4,702);shortExit.type=DEAL_TYPE_BUY;finish(shortExit);
 assert(csv()[2][4]=="SHORT"&&csv()[2][8]=="10.00000000");
 // New mapping participates in duplicate-magic validation; 0 disables only it.
 PGJClose();reset();InpJournalSessionMomentumMagic=InpJournalORBMagic;PGJInit();assert(!pgj_active);
 InpJournalSessionMomentumMagic=0;PGJInit();assert(pgj_active&&PGJName(420611)=="");
 PGJClose();InpJournalSessionMomentumMagic=420611;
 // Rows follow final close time, independently of position identifier order.
 PGJClose();reset();PGJInit();liveEntry(entry(1,900));liveEntry(entry(2,100));
 finish(close(3,900));finish(close(4,100));assert(csv()[1][14]=="900"&&csv()[2][14]=="100");
 std::cout<<"Portfolio live journal: five-system reconciliation, fees/R, partial fills, restarts, history/storage failures, isolation and tester bypass passed\n";
}
