#property strict
#property version "1.00"
#property description "Gotobi EURJPY: 15:55 UTC before fix, 00:55 UTC fix exit, 60-pip SL and 200-pip safety TP."
#define RC_NAME "RC EURJPY Gotobi"
#define RC_DEFAULT_MAGIC 420603
#define RC_DEFAULT_SPREAD 30
#define RC_DEFAULT_DST RC_FIXED
#define RC_DEFAULT_OFFSET 0
#define RC_DEFAULT_OPEN 0
#define RC_DEFAULT_CLOSE 1440
input int InpEntryUTCMinute=955;
input int InpFixUTCMinute=55;
input double InpStopPips=60;
input double InpSafetyTargetPips=200;
input double InpMaximumSpreadPips=3;
input double InpPipSize=0; // 0: 10 points for 3/5 digits, one point otherwise. Override if needed.
input string InpExcludedJapaneseDates=""; // Holiday dates NOT automatically rescheduled.
#include "include/Runtime.mqh"
bool RCValidate(){return InpEntryUTCMinute>InpFixUTCMinute&&InpEntryUTCMinute<1440&&InpFixUTCMinute>=0&&
                        InpStopPips>0&&InpSafetyTargetPips>0&&InpMaximumSpreadPips>0&&InpPipSize>=0;}
datetime RCStrategyDeadline(const datetime opened_utc) {
   datetime fix=RCDay(opened_utc)+InpFixUTCMinute*60;
   return fix>opened_utc?fix:fix+86400;
}
void RCProcess(const datetime utc) {
   if(RCHasOwn())return;
   datetime entry=RCDay(utc)+InpEntryUTCMinute*60;
   if(utc<entry||utc>entry+InpEntryGraceSeconds)return;
   datetime fix=RCDay(utc)+86400+InpFixUTCMinute*60,japan=fix+9*3600;
   if(!RCGotobi(japan)||RCListed(InpExcludedJapaneseDates,japan))return;
   double pip=InpPipSize>0?InpPipSize:(_Digits==3||_Digits==5?10*_Point:_Point);
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick)||(tick.ask-tick.bid)/pip>InpMaximumSpreadPips)return;
   // Independent entry uniqueness survives restart and exit-before-fix stops.
   RCEnter(1,InpStopPips*pip,InpSafetyTargetPips/InpStopPips,utc,entry);
}
