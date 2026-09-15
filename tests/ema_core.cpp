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
#include "../strategies/EMAPullback/EMACore.mqh"
#include "../strategies/EMAPullback/SessionClock.mqh"
NPBar bar(long i,double close=100,int minutes=60) {
    return {i*minutes*60,100,std::fmax(102,close),std::fmin(98,close),close,minutes};
}
void warm(NPState &s,int minutes=60) {
    NPReset(s);double atr;
    for(int i=0;i<100;i++)assert(!NPConsume(s,bar(i,100,minutes),minutes,14,20,50,atr));
}
int main() {
    NPState s;double a;warm(s);
    warm(s,30);auto incomplete=bar(100,101,30);incomplete.minutes=29;
    assert(!NPConsume(s,incomplete,30,14,20,50,a));
    warm(s,30);assert(!NPConsume(s,bar(101,101,30),30,14,20,50,a));
    // Current ATR includes the current bar, with Wilder alpha rather than SMA seeding.
    NPReset(s);NPConsume(s,bar(0),60,14,20,50,a);assert(a==4);
    auto wide=bar(1);wide.high=110;
    NPConsume(s,wide,60,14,20,50,a);assert(std::abs(a-(4+8.0/14))<1e-12);
    // After flat history, a close above the seeded EMA crosses and fast exceeds slow.
    warm(s,30);assert(NPConsume(s,bar(100,101,30),30,14,20,50,a));
    assert(!NPConsume(s,bar(101,101.5,30),30,14,20,50,a));
    NPReset(s);for(int i=0;i<99;i++)
        assert(!NPConsume(s,bar(i,100+i*.01,30),30,14,20,50,a));
    // UTC -> NY and broker round trips straddle both DST regimes.
    assert(!NPUSDst(NPDate(2024,3,10,6,59)));
    assert(NPUSDst(NPDate(2024,3,10,7)));
    assert(!NPUSDst(NPDate(2024,11,3,6)));
    assert(!NPEUDst(NPDate(2024,3,31,0,59)));
    assert(NPEUDst(NPDate(2024,3,31,1)));
    datetime u=0;
    for(int mode=1;mode<=3;mode++)for(int month=1;month<=12;month++){
        datetime x=NPDate(2024,month,15,15);
        assert(NPToUtc(NPToServer(x,(NPClockMode)mode,7200),(NPClockMode)mode,7200,u)&&u==x);
    }
    assert(!NPToUtc(NPDate(2024,11,3,8,30),NP_US_SEASONAL,7200,u));
    assert(!NPToUtc(NPDate(2024,3,10,9,30),NP_US_SEASONAL,7200,u));
    assert(NPCloseMinute(NPDate(2025,1,9,15))==0);
    assert(NPCloseMinute(NPDate(2024,11,29,15))==780);
    assert(NPCloseMinute(NPDate(2024,11,27,15))==960);
    assert(NPCloseMinute(NPDate(2026,7,3,15))==0);
    assert(NPCloseMinute(NPDate(2027,1,4,15))==-1);
    assert(NPDeadline(NPDate(2024,7,3,15))==NPDate(2024,7,3,16,55));
    assert(NPDeadline(NPDate(2024,1,3,15))==NPDate(2024,1,3,20,55));
    // Friday broker close precedes the planned cash exit (UTC+2 feed).
    auto fri=NPDate(2024,7,5);
    auto end=NPSessionEnd(fri,60,21*3600);
    assert(end==fri+21*3600);
    assert(NPEarlierExit(NPDate(2024,7,5,19,55),end-7200,5)==NPDate(2024,7,5,18,55));
    // Midnight and overnight ends, plus broker close later than cash close.
    assert(NPSessionEnd(fri,3600,86400)==fri+86400);
    assert(NPSessionEnd(fri,22*3600,2*3600)==fri+26*3600);
    assert(NPEarlierExit(fri+19*3600,fri+23*3600,5)==fri+19*3600);
    // Exact deadline / grace boundaries; Sunday completion must be invalid.
    auto deadline=fri+19*3600;
    assert(!NPExitOverdue(deadline,deadline));
    assert(!NPExitOverdue(deadline+60,deadline));
    assert(NPExitOverdue(deadline+61,deadline));
    assert(NPExitOverdue(fri+3*86400,deadline));
    assert(NPRetryClose(deadline,0));
    assert(!NPRetryClose(deadline+4,deadline));
    assert(NPRetryClose(deadline+5,deadline));
}
