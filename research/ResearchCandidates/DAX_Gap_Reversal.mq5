#property strict
#property version "1.12"
#property description "Research DAX true opening gap fade, previous completed M30 bar confirmation."
#define RC_NAME "RC DAX gap reversal"
#define RC_DEFAULT_MAGIC 420605
#define RC_DEFAULT_SPREAD 300
#define RC_DEFAULT_DST RC_EU
#define RC_DEFAULT_OFFSET 60
#define RC_DEFAULT_OPEN 480
#define RC_DEFAULT_CLOSE 1320
input group "Strategy parameters"
input int InpEntryWindowMinutes=180; // Entry window after session open (minutes)
#include "include/Runtime.mqh"
datetime rc_open_day=0;
double rc_session_open=0;
bool RCValidate(){return InpEntryWindowMinutes>=30&&InpEntryWindowMinutes<=1440;}
datetime RCStrategyDeadline(const datetime opened_utc){return RCSessionDeadline(opened_utc);}
void RCProcess(const datetime utc) {
   if(RCMinuteEvent(utc)&&!RCRefreshDays(utc))return;
   if(!rc_ready||!RCInSession(utc)||rc_count<1||RCHasOwn())return;
   datetime wall=RCSessionWall(utc),open=RCBoundary(wall,InpSessionOpenMinute);
   if(utc<open+1800||utc>=open+InpEntryWindowMinutes*60)return;
   if(rc_open_day!=RCDay(wall)) {
      MqlRates minute[];
      int n=CopyRates(_Symbol,PERIOD_M1,RCServer(open),RCServer(open+299),minute);
      if(n<=0)return;
      ArraySetAsSeries(minute,false);rc_session_open=minute[0].open;rc_open_day=RCDay(wall);
   }
   int direction=RCGapDirection(rc_session_open,rc_days[rc_count-1].low,rc_days[rc_count-1].high);
   if(direction==0)return;
   RCBar bars[];int count=InpATRPeriod+2;
   if(!RCRecentBars(PERIOD_M30,count,bars))return;
   RCBar previous=bars[count-1];
   if(previous.start<open||utc>=previous.start+3600||rc_last_bid<=0)return;
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick))return;
   bool triggered=direction>0?(rc_last_bid<=previous.high&&tick.bid>previous.high):
                              (rc_last_bid>=previous.low&&tick.bid<previous.low);
   if(triggered)RCEnter(direction,InpStopATR*RCATR(bars,count,InpATRPeriod),InpTargetR,utc,previous.start+1800);
}

void RCWriteStrategySettings(const int h) {
   FileWrite(h,"InpEntryWindowMinutes",InpEntryWindowMinutes);
}
