#property strict
#property version "1.00"
#property description "Research reconstruction: two-session extremes, daily momentum and efficiency filters."
#define RC_NAME "RC EuroFX extreme reversal"
#define RC_DEFAULT_MAGIC 420601
#define RC_DEFAULT_SPREAD 30
#define RC_DEFAULT_DST RC_FIXED
#define RC_DEFAULT_OFFSET 0
#define RC_DEFAULT_OPEN 0
#define RC_DEFAULT_CLOSE 1320
input int InpExtremeSessions=2;
input int InpMomentumSessions=5;
input int InpEfficiencySessions=10;
input double InpMaximumEfficiency=0.35;
input double InpMaximumMomentumATR=1.5;
#include "include/Runtime.mqh"
bool RCValidate() {
   return InpExtremeSessions>=1&&InpExtremeSessions<=30&&InpMomentumSessions>=1&&InpMomentumSessions<=30&&
          InpEfficiencySessions>=1&&InpEfficiencySessions<=30&&InpMaximumEfficiency>=0&&
          InpMaximumEfficiency<=1&&InpMaximumMomentumATR>0;
}
datetime RCStrategyDeadline(const datetime opened_utc){return RCSessionDeadline(opened_utc);}
void RCProcess(const datetime utc) {
   if(RCMinuteEvent(utc)&&!RCRefreshDays(utc))return;
   if(!rc_ready||!RCInSession(utc)||rc_count<InpExtremeSessions||RCHasOwn()||rc_last_bid<=0)return;
   double atr=RCATR(rc_days,rc_count,InpATRPeriod);
   if(!RCRegime(rc_days,rc_count,InpMomentumSessions,InpEfficiencySessions,
                InpMaximumEfficiency,InpMaximumMomentumATR,atr))return;
   double high=RCHigh(rc_days,rc_count,InpExtremeSessions),low=RCLow(rc_days,rc_count,InpExtremeSessions);
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick))return;
   // Crossing a level from inside the range; attach/restart outside it never chases.
   int direction=rc_last_bid<high&&tick.bid>=high?-1:rc_last_bid>low&&tick.bid<=low?1:0;
   if(direction!=0)RCEnter(direction,InpStopATR*atr,InpTargetR,utc);
}
