#ifndef EMA_CORE_MQH
#define EMA_CORE_MQH
// Portable signal/indicator code: shared by the EA and C++ test harness.
#ifdef __cplusplus
#include <cmath>
#define MathAbs std::fabs
#define MathMax std::fmax
#endif
struct NPBar {
   long start;
   double open,high,low,close;
   int minutes;
};
struct NPState {
   int count,history;
   double atr,fast,slow,previous_close;
   NPBar recent[32];
};
void NPReset(NPState &s) {
   s.count=0;s.history=0;s.atr=0;s.fast=0;s.slow=0;s.previous_close=0;
   for(int i=0;i<32;i++){s.recent[i].start=0;s.recent[i].open=0;s.recent[i].high=0;s.recent[i].low=0;s.recent[i].close=0;s.recent[i].minutes=0;}
}
bool NPConsume(NPState &s,const NPBar &b,const int period_minutes,
               const int atr_length,
               const int fast_length,const int slow_length,double &risk_atr) {
   double old_fast=s.fast;
   double tr=b.high-b.low;
   if(s.count>0) {
      tr=MathMax(tr,MathMax(MathAbs(b.high-s.previous_close),MathAbs(b.low-s.previous_close)));
      s.atr+=(tr-s.atr)/atr_length;
      s.fast+=(b.close-s.fast)*2.0/(fast_length+1);
      s.slow+=(b.close-s.slow)*2.0/(slow_length+1);
   } else {s.atr=tr;s.fast=b.close;s.slow=b.close;}
   s.count++;
   bool ready=s.history>0 && b.minutes==period_minutes &&
      s.recent[0].minutes==period_minutes &&
      s.recent[0].start+period_minutes*60==b.start &&
      s.count>=100 && s.count>=slow_length;
   bool signal=false;
   if(ready)
      signal=s.fast>s.slow && s.previous_close<=old_fast && b.close>s.fast;
   risk_atr=s.atr;
   for(int i=30;i>=0;i--)s.recent[i+1]=s.recent[i];
   s.recent[0]=b;if(s.history<32)s.history++;
   s.previous_close=b.close;
   return(signal);
}
#endif
