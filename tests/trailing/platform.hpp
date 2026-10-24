#pragma once
#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
#include <string>
#include <vector>
using string=std::string;using datetime=long long;using ENUM_TIMEFRAMES=int;
constexpr int PERIOD_CURRENT=0,PERIOD_M5=5,PERIOD_M30=30,PERIOD_H1=60,INVALID_HANDLE=-1;
constexpr int MODE_EMA=1,PRICE_CLOSE=0,POSITION_SYMBOL=1,POSITION_MAGIC=2,POSITION_TYPE=3;
constexpr int POSITION_SL=4,POSITION_TP=5,POSITION_TYPE_BUY=0,POSITION_TYPE_SELL=1;
constexpr int SYMBOL_TRADE_TICK_SIZE=6,SYMBOL_TRADE_STOPS_LEVEL=7,SYMBOL_TRADE_FREEZE_LEVEL=8;
constexpr int TRADE_ACTION_SLTP=6,TRADE_RETCODE_DONE=10009,TRADE_RETCODE_DONE_PARTIAL=10010;
const double EMPTY_VALUE=1.7976931348623157e308;
string _Symbol="NAS100";int _Period=PERIOD_M5,_Digits=2;double _Point=.01;
struct MqlRates{datetime time=0;double close=0;};
struct MqlTick{double bid=0,ask=0;datetime time=0;};
struct MqlTradeRequest{int action=0;ulong position=0,magic=0;string symbol;double sl=0,tp=0;};
struct MqlTradeResult{uint retcode=0;};
struct Position {ulong ticket,magic;string symbol;int side;double sl,tp;};
std::vector<Position> positions;int selected=0;
datetime now=1800000000,bar_time=1799999700;
MqlTick quote{110,110.1,now};
double value=100,tick_size=.01;int stop_level=0,freeze_level=0,bars_calculated=200,indicator_calls=0,releases=0;
bool indicator_ok=true,rates_ok=true,buffer_ok=true,send_ok=true,close_ok=true;
int last_tf=0,last_period=0;uint send_code=TRADE_RETCODE_DONE;
std::vector<MqlTradeRequest> requests;std::vector<ulong> closes;
double MathAbs(double v){return std::abs(v);}double MathMin(double a,double b){return std::min(a,b);}
double MathMax(double a,double b){return std::max(a,b);}double MathFloor(double v){return std::floor(v);}
double MathCeil(double v){return std::ceil(v);}bool MathIsValidNumber(double v){return std::isfinite(v);}
double NormalizeDouble(double v,int digits){double k=std::pow(10,digits);return std::round(v*k)/k;}
string IntegerToString(long long v){return std::to_string(v);}
template<class... T>void Print(T...){}
template<class T>int ArraySize(const std::vector<T> &v){return v.size();}
template<class T>void ArrayResize(std::vector<T> &v,int n){v.resize(n);}
template<class T>void ZeroMemory(T &v){v=T{};}
datetime TimeCurrent(){return now;}int PeriodSeconds(int frame){return frame*60;}
int iMA(const string &symbol,int frame,int period,int shift,int mode,int price){
 assert(symbol==_Symbol&&shift==0&&mode==MODE_EMA&&price==PRICE_CLOSE);
 indicator_calls++;last_tf=frame;last_period=period;return indicator_ok?42:INVALID_HANDLE;
}
void IndicatorRelease(int){releases++;}
int BarsCalculated(int){return bars_calculated;}
int CopyRates(const string&,int frame,int shift,int count,std::vector<MqlRates> &out){
 assert(frame==last_tf&&shift==1&&count==1);out={{bar_time,99999}};return rates_ok?1:0;}
int CopyBuffer(int,int buffer,int shift,int count,std::vector<double> &out){
 assert(buffer==0&&shift==1&&count==1);out={value};return buffer_ok?1:0;}
datetime iTime(const string&,int,int shift){assert(shift==1);return bar_time;}
bool SymbolInfoTick(const string&,MqlTick &out){out=quote;return true;}
double SymbolInfoDouble(const string&,int){return tick_size;}
long SymbolInfoInteger(const string&,int field){return field==SYMBOL_TRADE_STOPS_LEVEL?stop_level:freeze_level;}
int PositionsTotal(){return positions.size();}
ulong PositionGetTicket(int i){selected=i;return positions.at(i).ticket;}
string PositionGetString(int){return positions.at(selected).symbol;}
long PositionGetInteger(int field){return field==POSITION_MAGIC?positions.at(selected).magic:positions.at(selected).side;}
double PositionGetDouble(int field){return field==POSITION_SL?positions.at(selected).sl:positions.at(selected).tp;}
bool PositionSelectByTicket(ulong t){for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)==t)return true;return false;}
bool OrderSend(const MqlTradeRequest &req,MqlTradeResult &res){
 requests.push_back(req);res.retcode=send_code;
 assert(req.action==TRADE_ACTION_SLTP&&req.position>0&&req.symbol==_Symbol);
 if(send_ok&&(send_code==TRADE_RETCODE_DONE||send_code==TRADE_RETCODE_DONE_PARTIAL)){
   assert(PositionSelectByTicket(req.position));
   assert((ulong)PositionGetInteger(POSITION_MAGIC)==req.magic);
   positions[selected].sl=req.sl;positions[selected].tp=req.tp;
 }
 return send_ok;
}
#include "trailing.mqh"
bool E2TrailClose(const ulong ticket){
 closes.push_back(ticket);assert(PositionSelectByTicket(ticket));
 assert(positions[selected].symbol==_Symbol&&positions[selected].magic==e2trail_magic);
 if(close_ok)positions.erase(positions.begin()+selected);
 return close_ok;
}
