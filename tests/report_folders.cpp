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
 string path;
 assert(E2ReportFolder("EMAPullback",path));assert(path=="E2\\EMAPullback");
 assert(E2ReportFolder("EMAPullback",path));assert(directories.size()==2);
 assert(E2ReportBase("USTEC","run1")!=E2ReportBase("USTEC","run2"));
 auto test=E2ReportBase("USTEC","run1");tester=false;
 assert(E2ReportBase("USTEC","run1")!=test);
 assert(E2ReportFolder("GoldSessionFade",path));assert(path=="E2\\GoldSessionFade");
 assert(directories.size()==3);
 directories.clear();files.insert("E2");assert(!E2ReportFolder("EMAPullback",path));
}
