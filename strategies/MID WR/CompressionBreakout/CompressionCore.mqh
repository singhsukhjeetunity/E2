#ifndef COMPRESSION_CORE_MQH
#define COMPRESSION_CORE_MQH
// Portable, causal signal implementation shared with the C++ parity tests.
#ifdef __cplusplus
#include <cmath>
#define MathAbs std::fabs
#define MathMax std::fmax
#endif
struct CBBar {
   long start;
   double open,high,low,close;
   int minutes;
};
struct CBState {
   int count,history,atr_count;
   double atr,previous_close;
   CBBar recent[501];
   double atr_history[1000]; // Newest first; only ATR observations at count >=200.
};
void CBReset(CBState &s) {
   s.count=0;s.history=0;s.atr_count=0;s.atr=0;s.previous_close=0;
   for(int i=0;i<501;i++){s.recent[i].start=0;s.recent[i].open=0;s.recent[i].high=0;s.recent[i].low=0;s.recent[i].close=0;s.recent[i].minutes=0;}
   for(int i=0;i<1000;i++)s.atr_history[i]=0;
}
int CBWarmupMinutes(const int atr_length,const int channel,const int compression) {
   int bars=600;
   if(atr_length*20+compression+200>bars)bars=atr_length*20+compression+200;
   if(channel+compression+200>bars)bars=channel+compression+200;
   return bars*30;
}
bool CBConsume(CBState &s,const CBBar &b,const int period_minutes,
               const int atr_length,const int channel,const int compression,
               const double ratio,double &risk_atr) {
   if(atr_length<1||channel<2||channel>500||compression<2||compression>1000)return false;
   bool signal=false;
   // Compression uses previous ATR and its previous 100-value average.
   // Today's breakout cannot manufacture its own compression condition.
   if(s.history>=channel+1 && s.atr_count>=compression && b.minutes==period_minutes) {
      double high=s.recent[0].high,previous_high=s.recent[1].high,sum=0;
      for(int i=0;i<channel;i++) {
         high=MathMax(high,s.recent[i].high);
         previous_high=MathMax(previous_high,s.recent[i+1].high);
      }
      for(int i=0;i<compression;i++)sum+=s.atr_history[i];
      signal=b.close>high && s.previous_close<=previous_high && s.atr<ratio*sum/compression;
   }
   double tr=b.high-b.low;
   if(s.count>0) {
      tr=MathMax(tr,MathMax(MathAbs(b.high-s.previous_close),MathAbs(b.low-s.previous_close)));
      s.atr+=(tr-s.atr)/atr_length;
   } else s.atr=tr;
   s.count++;
   risk_atr=s.atr; // Stop uses ATR including the completed breakout bar.
   if(s.count>=200) {
      for(int i=compression-1;i>0;i--)s.atr_history[i]=s.atr_history[i-1];
      s.atr_history[0]=s.atr;if(s.atr_count<compression)s.atr_count++;
   }
   for(int i=channel;i>0;i--)s.recent[i]=s.recent[i-1];
   s.recent[0]=b;if(s.history<channel+1)s.history++;
   s.previous_close=b.close;
   return signal;
}
#endif
