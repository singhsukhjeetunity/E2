#property strict
#property version "1.10"
#property description "Public daily IBS/range pullback; next-tick execution and configurable risk overlay."
#define RC_NAME "RC daily IBS pullback"
#define RC_DEFAULT_MAGIC 420602
#define RC_DAILY_IBS
#define RC_DEFAULT_SPREAD 300
#define RC_DEFAULT_DST RC_US
#define RC_DEFAULT_OFFSET -300
#define RC_DEFAULT_OPEN 570
#define RC_DEFAULT_CLOSE 960
input group "Strategy parameters"
input int InpHighSessions=10; // High lookback (sessions)
input int InpRangeSessions=25; // Range lookback (sessions)
input double InpRangeBandMultiple=1.0; // Pullback range multiplier
input double InpMaximumIBS=0.30; // Maximum IBS (0 to 1)
#include "include/Runtime.mqh"
datetime rc_processed_close=0;
bool RCValidate(){return InpHighSessions>0&&InpHighSessions<=60&&InpRangeSessions>0&&InpRangeSessions<=60&&
                        InpRangeBandMultiple>0&&InpMaximumIBS>0&&InpMaximumIBS<1;}
datetime RCStrategyDeadline(const datetime opened_utc){return 0;} // Exit on daily strength or overlay.
void RCProcess(const datetime utc) {
   if(!RCMinuteEvent(utc))return;
   if(!RCRefreshDays(utc)||rc_count<2)return;
   // Exits may be recovered after a missed close/restart; entry grace never delays exits.
   if(RCHasOwn()) {
      bool strength=false;
      for(int p=PositionsTotal()-1;p>=0;p--) {
         if(PositionGetTicket(p)==0||!RCIsOwn())continue;
         datetime opened=0;
         if(!RCUtc((datetime)PositionGetInteger(POSITION_TIME),InpBrokerDST,InpBrokerWinterUTCMinutes,opened))continue;
         for(int i=1;i<rc_count;i++) {
            datetime day=RCDay(RCSessionWall(rc_days[i].start));
            if(RCBoundary(day,RCCloseMinute(day))>opened&&rc_days[i].close>rc_days[i-1].high)strength=true;
         }
      }
      if(strength)RCCloseOwn();
      return; // Never exit and re-enter on the same evaluation tick.
   }
   datetime wall=RCSessionWall(utc),end=RCSessionDeadline(utc);
   if(!RCSessionAllowed(wall)||end<=0||utc<end||utc>end+InpEntryGraceSeconds||rc_processed_close==end)return;
   if(RCDay(RCSessionWall(rc_days[rc_count-1].start))!=RCDay(wall))return;
   rc_processed_close=end;
   if(RCPullback(rc_days,rc_count,InpHighSessions,InpRangeSessions,InpRangeBandMultiple,InpMaximumIBS))
      RCEnter(1,InpStopATR*RCATR(rc_days,rc_count,InpATRPeriod),InpTargetR,utc,end);
}

void RCWriteStrategySettings(const int h) {
   FileWrite(h,"InpHighSessions",InpHighSessions);
   FileWrite(h,"InpRangeSessions",InpRangeSessions);
   FileWrite(h,"InpRangeBandMultiple",InpRangeBandMultiple);
   FileWrite(h,"InpMaximumIBS",InpMaximumIBS);
}
