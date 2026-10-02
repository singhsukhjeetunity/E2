#ifndef E2_GAP_FADE_CORE_MQH
#define E2_GAP_FADE_CORE_MQH

#ifdef __cplusplus
#include <cmath>
#define MathAbs std::fabs
#define MathMax std::fmax
#define GF_ARRAY_REF
#else
#define GF_ARRAY_REF &
#endif

struct GFDayBar {
   int day;
   double open,high,low,close;
};

double GFWilderAtr(const GFDayBar GF_ARRAY_REF days[],const int count,const int length) {
   if(length<1 || count<length+1)return 0.0;
   double atr=0.0;
   // Seed on the oldest length observations, then apply Wilder smoothing through
   // every later completed session. The caller supplies a long causal warm-up.
   for(int i=1;i<=length;i++) {
      double tr=days[i].high-days[i].low;
      tr=MathMax(tr,MathAbs(days[i].high-days[i-1].close));
      tr=MathMax(tr,MathAbs(days[i].low-days[i-1].close));
      atr+=tr;
   }
   atr/=length;
   for(int i=length+1;i<count;i++) {
      double tr=days[i].high-days[i].low;
      tr=MathMax(tr,MathAbs(days[i].high-days[i-1].close));
      tr=MathMax(tr,MathAbs(days[i].low-days[i-1].close));
      atr=(atr*(length-1)+tr)/length;
   }
   return atr;
}

int GFSignal(const double today_open,const double prior_close,const double atr,
             const double min_gap_atr,const double max_gap_atr,
             const double first_open,const double first_close) {
   if(atr<=0 || min_gap_atr<0 || max_gap_atr<=min_gap_atr)return 0;
   double gap=today_open-prior_close;
   double multiple=MathAbs(gap)/atr;
   if(multiple<min_gap_atr || multiple>max_gap_atr)return 0;
   if(gap>0 && first_close<first_open)return -1;
   if(gap<0 && first_close>first_open)return 1;
   return 0;
}

// Reproducible, date-based control arm. It never depends on tester call order.
int GFRandomSide(const int ny_day,const ulong seed) {
   ulong x=((ulong)ny_day)^seed;
   x^=x>>12;x^=x<<25;x^=x>>27;
   return ((x*2685821657736338717ULL)&1ULL)==0ULL?-1:1;
}

#endif
