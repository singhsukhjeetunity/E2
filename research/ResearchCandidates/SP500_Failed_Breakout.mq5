#property strict
#property version "1.10"
#property description "Research reconstruction of prior-session high/low close-and-reclaim reversal, M15."
#define RC_NAME "RC SP500 failed breakout"
#define RC_DEFAULT_MAGIC 420604
#define RC_DEFAULT_SPREAD 300
#define RC_DEFAULT_DST RC_US
#define RC_DEFAULT_OFFSET -300
#define RC_DEFAULT_OPEN 570
#define RC_DEFAULT_CLOSE 960
input group "Strategy parameters"
input bool InpEnableLong=true; // Allow long trades
input bool InpEnableShort=true; // Allow short trades
#include "include/Runtime.mqh"
datetime rc_processed_bar=0;
bool RCValidate(){return InpEnableLong||InpEnableShort;}
datetime RCStrategyDeadline(const datetime opened_utc){return RCSessionDeadline(opened_utc);}
void RCProcess(const datetime utc) {
   if(!RCMinuteEvent(utc)||!RCInSession(utc)||!RCRefreshDays(utc)||rc_count<1)return;
   RCBar bars[];int count=InpATRPeriod+2;
   if(!RCRecentBars(PERIOD_M15,count,bars))return;
   RCBar previous=bars[count-2],latest=bars[count-1];
   datetime open=RCBoundary(RCSessionWall(utc),InpSessionOpenMinute);
   if(latest.start==rc_processed_bar||previous.start<open||latest.start!=previous.start+900||
      utc>latest.start+900+InpEntryGraceSeconds)return;
   rc_processed_bar=latest.start;
   int direction=RCReclaim(previous,latest,rc_days[rc_count-1].low,rc_days[rc_count-1].high);
   if((direction>0&&!InpEnableLong)||(direction<0&&!InpEnableShort))return;
   if(direction!=0)RCEnter(direction,InpStopATR*RCATR(bars,count,InpATRPeriod),InpTargetR,utc,latest.start+900);
}

void RCWriteStrategySettings(const int h) {
   FileWrite(h,"InpEnableLong",InpEnableLong);
   FileWrite(h,"InpEnableShort",InpEnableShort);
}
