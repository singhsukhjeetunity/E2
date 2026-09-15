// Compile the exact MQL report-path helper against an in-memory file API.
#include <cassert>
#include <string>
#include <set>
#include <cstdio>
using string=std::string;
using ushort=unsigned short;
using uint=unsigned int;
const int FILE_COMMON=1,MQL_TESTER=2,ACCOUNT_TRADE_MODE=3,ACCOUNT_TRADE_MODE_DEMO=4,ACCOUNT_SERVER=5,ACCOUNT_LOGIN=6,ERR_FILE_IS_DIRECTORY=5018;
int error=0; bool tester=true; int mode=ACCOUNT_TRADE_MODE_DEMO;
std::set<string> directories,files;
int StringLen(const string &s){return s.size();}
ushort StringGetCharacter(const string &s,int i){return s[i];}
string StringSubstr(const string &s,int i,int n){return s.substr(i,n);}
string StringFormat(const char*,unsigned long long v){return std::to_string(v);}
string StringFormat(const char*,uint v){char b[16];std::snprintf(b,sizeof b,"%04X",v);return b;}
string IntegerToString(int v){return std::to_string(v);}
void ResetLastError(){error=0;}
int GetLastError(){return error;}
bool FolderCreate(const string &s,int){if(files.count(s)||directories.count(s)){error=5020;return false;}directories.insert(s);return true;}
bool FileIsExist(const string &s,int){if(directories.count(s)){error=ERR_FILE_IS_DIRECTORY;return false;}return files.count(s);}
template<class... T> void Print(T...){}
int MQLInfoInteger(int){return tester;}
unsigned long long AccountInfoInteger(int k){return k==ACCOUNT_LOGIN?123:mode;}
string AccountInfoString(int){return "Broker-Demo";}
unsigned long long GetTickCount64(){return 1234;}
unsigned long long GetMicrosecondCount(){return 5678;}
template<class T,unsigned long N> int ArraySize(const T(&)[N]){return N;}
#include "../strategies/shared/ReportFolders.mqh"
int main(){
 assert(E2PathPart("EUR/USD")!=E2PathPart("EUR_USD"));
 assert(E2PathPart("CON")=="v-CON");
 assert(E2PathPart("../USD").find('/')==string::npos);
 string run="run1",path;
 assert(E2ReportFolder("EMAPullback","USTEC",run,path));
 assert(path=="E2\\Reports\\Backtests\\v-Broker-Demo_123\\EMAPullback\\v-USTEC\\run1");
 run="run1";assert(E2ReportFolder("EMAPullback","USTEC",run,path));assert(run=="run1_1");
 tester=false;run="run1";assert(E2ReportFolder("GoldSessionFade","XAUUSD",run,path));assert(path.find("\\Demo\\")!=string::npos);
 mode=99;run="run1";assert(E2ReportFolder("GoldSessionFade","XAUUSD",run,path));assert(path.find("\\Live\\")!=string::npos);
 directories.clear();files.insert("E2");assert(!E2ReportFolder("EMAPullback","USTEC",run,path));
}
