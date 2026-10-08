#include <cassert>
#include <cmath>
#include <ctime>
#include <string>
#include <vector>
#include <algorithm>
#include <iostream>
using string=std::string;using datetime=long long;
struct MqlDateTime{int year=0,mon=0,day=0,hour=0,min=0,sec=0,day_of_week=0;};
datetime StructToTime(const MqlDateTime &m){std::tm t{};t.tm_year=m.year-1900;t.tm_mon=m.mon-1;t.tm_mday=m.day;t.tm_hour=m.hour;t.tm_min=m.min;t.tm_sec=m.sec;return timegm(&t);}
bool TimeToStruct(datetime x,MqlDateTime &m){std::time_t v=x;auto t=*std::gmtime(&v);m={t.tm_year+1900,t.tm_mon+1,t.tm_mday,t.tm_hour,t.tm_min,t.tm_sec,t.tm_wday};return true;}
datetime date(int d,int h=0,int m=0){return StructToTime({2026,10,d,h,m,0,0});}
double MathMax(double a,double b){return std::max(a,b);}double MathMin(double a,double b){return std::min(a,b);}
double MathAbs(double a){return std::abs(a);}bool MathIsValidNumber(double a){return std::isfinite(a);}
string IntegerToString(long long n){return std::to_string(n);}string DoubleToString(double n,int){return std::to_string(n);}
template<class T>void ZeroMemory(T &x){x=T{};}template<class T>int ArraySize(const std::vector<T>&v){return v.size();}
template<class T>void ArrayResize(std::vector<T>&v,int n){v.resize(n);}template<class T>void ArraySetAsSeries(std::vector<T>&,bool){}
enum E2XauRegimeFilterMode{E2_XAU_REGIME_OFF,E2_XAU_REGIME_BLOCK_UNFAVOURABLE,E2_XAU_REGIME_FAVOURABLE_ONLY};
enum E2XauRegimeLookbackMode{E2_XAU_REGIME_LOOKBACK_3_MONTHS,E2_XAU_REGIME_LOOKBACK_6_MONTHS,E2_XAU_REGIME_LOOKBACK_12_MONTHS,E2_XAU_REGIME_LOOKBACK_N_OBSERVATIONS};
enum{E2_XAU_TIME_SERVER,E2_XAU_TIME_UTC,E2_XAU_TIME_NEW_YORK,E2_DIRECTION_LONG,PERIOD_M5=5,INVALID_HANDLE=-1};
struct E2Config{
 int xau_range_start=720,xau_range_end=750,xau_time_basis=E2_XAU_TIME_UTC,xau_block_friday_entries_from_hour=-1;
 int xau_trend_lookback_bars=1,xau_atr_length=14,xau_regime_observation_lookback=3,xau_regime_minimum_observations=2;
 double xau_trend_efficiency_min=.3,xau_atr_multiplier=8,xau_regime_unfavourable_threshold=.01,xau_regime_favourable_threshold=.01,xau_regime_very_favourable_threshold=1.45;
 bool xau_regime_allow_until_ready=false;
 E2XauRegimeFilterMode xau_regime_filter_mode=E2_XAU_REGIME_FAVOURABLE_ONLY;
 E2XauRegimeLookbackMode xau_regime_lookback_mode=E2_XAU_REGIME_LOOKBACK_N_OBSERVATIONS;
};
struct E2Candidate{
 string symbol,timeframe,candidate_id,regime_state,regime_decision;int rule_day=0,direction=0,regime_observations=0,regime_ready=0,regime_allowed=0;
 datetime signal_bar_time=0,signal_known_time=0,range_start_rule=0,range_end_rule=0,execution_window_start=0,execution_window_end=0;
 double signal_close=0,range_high=0,range_low=0,extension_distance=0,atr=0,atr_multiplier=0,risk_distance=0,extension_ratio=0,regime_trailing_ratio=0;
};
struct E2SignalVerification{int time_failures=0,bars_observed=0,total_candidates=0,long_candidates=0;};
struct E2Logger{void Info(const string&,const string&){}void Error(const string&,const string&){} };
struct E2BrokerTimeAdapter{bool ServerToUtc(datetime t,datetime &u){u=t;return true;}};
struct E2WeekendFlat{bool IsBlockedAt(datetime){return false;}void LogExpire(const string&,datetime){} };
struct E2PositionRecovery{bool DayConsumed(datetime){return false;}};
#include "../strategies/GoldSessionFade/include/time/E2TimeUtils.mqh"
struct MqlRates{datetime time=0;double open=105,high=110,low=100,close=105;};
std::vector<MqlRates> history;datetime now;
datetime TimeCurrent(){return now;}int iATR(const string&,int,int){return 1;}void IndicatorRelease(int){}
int iBarShift(const string&,int,datetime t,bool){for(int i=(int)history.size()-1;i>=0;i--)if(history[i].time==t)return (int)history.size()-i;return -1;}
double iClose(const string&,int,int shift){int k=(int)history.size()-shift;return k>=0?history[k].close:0;}
int CopyBuffer(int,int,int,int,std::vector<double>&v){v={2};return 1;}
datetime iTime(const string&,int,int shift){return shift==0?now-now%300:history.back().time;}
int CopyRates(const string&,int,datetime start,datetime end,std::vector<MqlRates>&v){v.clear();for(auto b:history)if(b.time>=start&&b.time<=end)v.push_back(b);return v.size();}
#include "gold_regime.mqh"
#include "gold_engine.mqh"
int main(){
 for(int d:{5,6}){for(int m=0;m<6;m++)history.push_back({date(d,12,m*5),105,110,100,105});history.push_back({date(d,12,30),105,106,98,99});history.push_back({date(d,12,35),99,100,97,98});}
 for(int m=0;m<6;m++)history.push_back({date(7,12,m*5),105,110,100,105});
 now=date(7,12,30);E2Config config;E2BrokerTimeAdapter clock;E2WeekendFlat weekend;E2Logger log;E2PositionRecovery recovery;
 E2XauSessionFadeEngine engine;assert(engine.Initialize("XAUUSD",config,clock,weekend,log));
 assert(engine.RegimeObservations()==2);assert(engine.SignalVerification().total_candidates==0);
 std::vector<E2Candidate> out;assert(!engine.Evaluate(out,recovery)&&out.empty()); // Old signals never trade.
 history.push_back({date(7,12,30),105,106,98,99});now=date(7,12,35);
 assert(engine.Evaluate(out,recovery)&&out.size()==1&&out[0].regime_ready&&out[0].regime_allowed);
 assert(out[0].regime_observations==2&&engine.RegimeObservations()==3);
 E2XauSessionFadeEngine restarted;assert(restarted.Initialize("XAUUSD",config,clock,weekend,log));
 assert(restarted.RegimeObservations()==3);assert(!restarted.Evaluate(out,recovery));
 history.push_back({date(7,12,35),99,100,97,98});now=date(7,12,40);
 assert(!restarted.Evaluate(out,recovery)); // No second candidate on the replayed setup day.
 std::cout<<"Gold actual engine: regime reconstruction, restart equivalence, readiness and no old-signal replay passed\n";
}
