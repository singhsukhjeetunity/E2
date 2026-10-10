// Exercise exact MQL PortfolioGate.mqh permission logic against deterministic APIs.
// Portable C++ checks do NOT claim native MetaEditor compilation.
#include <cassert>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <ctime>
#include <map>
#include <string>
#include <iostream>
using string=std::string;
using datetime=long long;
using uint=unsigned int;
using ushort=unsigned short;
const int MQL_TESTER=1,TERMINAL_CONNECTED=2,ACCOUNT_LOGIN=3,ACCOUNT_EQUITY=4,ACCOUNT_SERVER=5;
bool tester=false,connected=true;
string server_name="Test-Broker";
datetime local_time=0,server_time=0;
double account_equity=100000;
std::map<string,double> values;
int flushes=0;
int MQLInfoInteger(int){return tester?1:0;}
int TerminalInfoInteger(int){return connected?1:0;}
long AccountInfoInteger(int){return 1234567;}
string AccountInfoString(int){return server_name;}
double AccountInfoDouble(int){return account_equity;}
datetime TimeTradeServer(){return server_time;}
datetime TimeLocal(){return local_time;}
int StringLen(const string& s){return (int)s.size();}
ushort StringGetCharacter(const string& s,int i){return (unsigned char)s.at(i);}
string StringFormat(const char* fmt,unsigned int n) {
   char buffer[32];
   std::snprintf(buffer,sizeof(buffer),fmt,n);
   return buffer;
}
string StringFormat(const char*,long n){return std::to_string(n);}
bool MathIsValidNumber(double x){return std::isfinite(x);}
struct MqlDateTime {int year=0,mon=0,day=0,hour=0,min=0,sec=0;};
bool TimeToStruct(datetime t,MqlDateTime& out) {
   std::time_t raw=(std::time_t)t;
   std::tm* result=std::gmtime(&raw);
   if(result==nullptr)return false;
   out.year=result->tm_year+1900;out.mon=result->tm_mon+1;out.day=result->tm_mday;
   out.hour=result->tm_hour;out.min=result->tm_min;out.sec=result->tm_sec;
   return true;
}
bool GlobalVariableCheck(const string& name){return values.count(name)>0;}
double GlobalVariableGet(const string& name){return values.at(name);}
datetime GlobalVariableSet(const string& name,double value){values[name]=value;return 1;}
void GlobalVariablesFlush(){flushes++;}

#include "../strategies/shared/PortfolioGate.mqh"

datetime dt(int y,int m,int d,int h,int minute=0) {
   std::tm t{};t.tm_year=y-1900;t.tm_mon=m-1;t.tm_mday=d;
   t.tm_hour=h;t.tm_min=minute;
   return timegm(&t);
}
void put(const string& suffix,double v){values[E2PGPrefix()+suffix]=v;}
int main() {
   local_time=dt(2026,10,9,12);
   server_time=local_time;
   assert(E2PGDayKey(dt(2026,10,9,0,30),1,0)==20261008);
   assert(E2PGDayKey(dt(2026,10,9,1,0),1,0)==20261009);
   assert(E2PGMinutesAfterReset(dt(2026,10,9,1,3),1,0)==3);
   assert(E2PGMinutesAfterReset(dt(2026,10,9,0,59),1,0)==1439);
   assert(!E2PGFresh(local_time,(double)(local_time-11)));
   assert(E2PGFresh(local_time,(double)(local_time-10)));
   assert(!E2PGCanEnter()); // Missing guard -> fail closed.
   tester=true;assert(E2PGCanEnter());tester=false; // Single-EA tester bypass ONLY.
   put("HB",(double)local_time);
   put("DAY",20261009);put("READY",1);put("LOCK",0);
   put("FLOOR",97000);put("RH",0);put("RM",0);
   assert(E2PGCanEnter());
   connected=false;assert(!E2PGCanEnter());connected=true;
   put("HB",(double)(local_time-11));assert(!E2PGCanEnter());put("HB",(double)local_time);
   put("DAY",20261008);assert(!E2PGCanEnter());put("DAY",20261009);
   put("READY",0);assert(!E2PGCanEnter());put("READY",1);
   put("LOCK",1);assert(!E2PGCanEnter());put("LOCK",0);
   account_equity=97000;
   assert(!E2PGCanEnter());assert(values[E2PGPrefix()+"LOCK"]==1&&flushes>0);
   account_equity=99000;assert(!E2PGCanEnter()); // Latch persists despite bounce.
   put("LOCK",0);
   assert(E2PGCanEnter());
   server_name="Another-Server";
   assert(!E2PGCanEnter()); // Account/server scoping prevents cross-broker leakage.
   std::cout<<"Account-wide entry gate: missing/stale/unseeded/locked/equity/day/cross-server checks passed\n";
}
