// Compile the exact signal and clock headers used by MT5; no trading API emulation.
#include <cassert>
#include <cmath>
#include <ctime>
#include <string>
using string=std::string;
using datetime=long long;
struct MqlDateTime {int year=0,mon=0,day=0,hour=0,min=0,sec=0,day_of_week=0;};
datetime StructToTime(const MqlDateTime &m) {
    std::tm t{};t.tm_year=m.year-1900;t.tm_mon=m.mon-1;t.tm_mday=m.day;
    t.tm_hour=m.hour;t.tm_min=m.min;t.tm_sec=m.sec;return timegm(&t);
}
void TimeToStruct(datetime x,MqlDateTime &m) {
    std::time_t v=x;auto t=*std::gmtime(&v);
    m={t.tm_year+1900,t.tm_mon+1,t.tm_mday,t.tm_hour,t.tm_min,t.tm_sec,t.tm_wday};
}
string IntegerToString(long long x){return std::to_string(x);}
int StringFind(const string &s,const string &x){auto p=s.find(x);return p==string::npos?-1:(int)p;}
#include <vector>
#include <algorithm>
#include <iostream>
#include "../strategies/EMAPullback/EMACore.mqh"
#include "../strategies/EMAPullback/SessionClock.mqh"
#include "ema_slot.mqh"
struct MqlRates {datetime time;double open,high,low,close;};
NPSlot g_slots[1];
int InpATRLength=14,InpEMAFast=20,InpEMASlow=50;
bool g_seeded=false,g_failed=false,g_bootstrapped=false;
datetime g_last_server_minute=0,g_last_utc_minute=0,g_history_notice=0;
int g_session_day=0,g_session_count=0;
const string _Symbol="USTEC";const int PERIOD_M1=1;
std::vector<MqlRates> history;
int history_cap=-1;
void ArraySetAsSeries(std::vector<MqlRates>&,bool){}
void ResetLastError(){}
void Audit(int,datetime,const string&,const string&){}
void Fail(const string&){g_failed=true;}
bool Utc(datetime s,datetime &u){u=s;return true;}
bool Enabled(int){return true;}int PeriodMinutes(int){return 30;}
#define MathMin std::fmin
#include "ema_warmup_size.mqh"
int CopyRates(const string&,int,datetime stop,int count,std::vector<MqlRates>&out){
 out.clear();for(auto b:history)if(b.time<=stop)out.push_back(b);
 if(history_cap==0)return -1;
 if(history_cap>0)count=std::min(count,history_cap);
 if((int)out.size()>count)out.erase(out.begin(),out.end()-count);
 return out.size();
}
int CopyRates(const string&,int,datetime start,datetime stop,std::vector<MqlRates>&out){
 if(history_cap==0)return -1;
 out.clear();for(auto b:history)if(b.time>=start&&b.time<=stop)out.push_back(b);return out.size();
}
#include "ema_feed.mqh"
int main(){
 NPReset(g_slots[0].indicators);
 datetime start=NPDate(2026,8,1),now=start+40000*60;
 for(int i=0;i<40000;i++){double c=100+(i%300)*.01;history.push_back({start+i*60,c,c+1,c-1,c});}
 history_cap=0;assert(!Feed(now,now));assert(!g_seeded&&g_last_server_minute==0);
 history_cap=100;assert(!Feed(now,now));assert(!g_seeded&&g_slots[0].indicators.count==0);
 history_cap=-1;assert(!Feed(now,now));assert(g_seeded&&g_bootstrapped);
 assert(g_slots[0].indicators.count>=1000);
 assert(g_slots[0].seen_signal==g_slots[0].signal_time); // Never trade the bootstrap signal.
 int count=g_slots[0].indicators.count;datetime cursor=g_last_server_minute;
 assert(Feed(now,now));assert(g_slots[0].indicators.count==count); // No duplicate consumption.
 history_cap=0;assert(!Feed(now+60,now+60));assert(g_last_server_minute==cursor);
 history_cap=-1;history.push_back({now,105,106,104,105});
 assert(Feed(now+60,now+60));assert(g_last_server_minute==now);
 assert(!g_failed);
 std::cout<<"EMA history wait, bootstrap suppression, completed-bar and retry tests passed\n";
}
