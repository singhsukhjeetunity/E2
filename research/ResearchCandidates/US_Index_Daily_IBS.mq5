#property strict
#property version "1.11"
#property description "Public daily IBS/range pullback; next-tick execution and configurable risk overlay."
#define RC_NAME "RC daily IBS pullback"
#define RC_DEFAULT_MAGIC 420602
#define RC_DAILY_IBS
#define RC_REPORT_VERSION "1.11"
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
input int InpEntryExpiryMinutes=180; // Wait for tradable entry after close (minutes)
#include "include/Runtime.mqh"
datetime rc_processed_close=0,rc_last_entry_attempt=0;
bool RCIBSTradeOpen(const datetime server) {
   MqlDateTime d;TimeToStruct(server,d);
   long second=server%86400;
   // Check current and previous weekday for sessions crossing broker midnight.
   for(int back=0;back<=1;back++) {
      ENUM_DAY_OF_WEEK weekday=(ENUM_DAY_OF_WEEK)((d.day_of_week-back+7)%7);
      for(uint i=0;i<32;i++) {
         datetime from=0,to=0;
         if(!SymbolInfoSessionTrade(_Symbol,weekday,i,from,to))break;
         long point=second+back*86400;
         if(to>from&&point>=from&&point<to)return true;
      }
   }
   return false; // Unknown schedule fails closed.
}
bool RCValidate(){return InpHighSessions>0&&InpHighSessions<=60&&InpRangeSessions>0&&InpRangeSessions<=60&&
                        InpRangeBandMultiple>0&&InpMaximumIBS>0&&InpMaximumIBS<1&&
                        InpEntryExpiryMinutes>=1&&InpEntryExpiryMinutes<=360;}
datetime RCStrategyDeadline(const datetime opened_utc){return 0;} // Exit on daily strength or overlay.
void RCProcess(const datetime utc) {
   bool minute=RCMinuteEvent(utc);
   if(minute&&!RCRefreshDays(utc))return;
   if(!rc_ready||rc_count<2)return;
   // Exits may be recovered after a missed close/restart; entry grace never delays exits.
   if(RCHasOwn()) {
      if(!minute)return;
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
   // Reconstruct the latest completed-session signal on every retry/restart.
   datetime signal_day=RCDay(RCSessionWall(rc_days[rc_count-1].start));
   datetime end=RCBoundary(signal_day,RCCloseMinute(signal_day));
   if(end<=0||utc<end||rc_processed_close==end)return;
   if(utc>end+InpEntryExpiryMinutes*60){rc_processed_close=end;return;}
   if(!RCPullback(rc_days,rc_count,InpHighSessions,InpRangeSessions,InpRangeBandMultiple,InpMaximumIBS)) {
      rc_processed_close=end;return;
   }
   if(!RCIBSTradeOpen(TimeCurrent()))return;
   if(rc_last_entry_attempt>0&&utc-rc_last_entry_attempt<60)return;
   rc_last_entry_attempt=utc;
   // Keep the signal on rejected orders. Broker history prevents duplicate/restart entry.
   if(RCEnter(1,InpStopATR*RCATR(rc_days,rc_count,InpATRPeriod),InpTargetR,utc,end)) {
      rc_processed_close=end;
      Print("IBS completed-close entry delay (seconds): ",utc-end);
   }
}

void RCWriteStrategySettings(const int h) {
   FileWrite(h,"InpHighSessions",InpHighSessions);
   FileWrite(h,"InpRangeSessions",InpRangeSessions);
   FileWrite(h,"InpRangeBandMultiple",InpRangeBandMultiple);
   FileWrite(h,"InpMaximumIBS",InpMaximumIBS);
   FileWrite(h,"InpEntryExpiryMinutes",InpEntryExpiryMinutes);
}
