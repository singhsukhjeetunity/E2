#ifndef E2_INDEX_MOMENTUM_CORE_MQH
#define E2_INDEX_MOMENTUM_CORE_MQH

#ifdef __cplusplus
#include <algorithm>
#include <cmath>
#define MathAbs std::fabs
#endif

struct MFSession {
   int day;
   double cash_close,ten_price,closing_open;
};

#ifndef __cplusplus
double MFMedian(double &values[],const int count) {
   if(count<=0)return 0.0;
   double copy[];ArrayResize(copy,count);
   for(int i=0;i<count;i++)copy[i]=values[i];
   ArraySort(copy);
   return count%2?copy[count/2]:(copy[count/2-1]+copy[count/2])*0.5;
}
#else
double MFMedianCpp(const double values[],const int count) {
   if(count<=0)return 0.0;
   double copy[256];if(count>256)return 0.0;
   for(int i=0;i<count;i++)copy[i]=values[i];
   std::sort(copy,copy+count);
   return count%2?copy[count/2]:(copy[count/2-1]+copy[count/2])*0.5;
}
#endif

int MFDirection(const double prior_close,const double ten_price) {
   if(prior_close<=0||ten_price<=0)return 0;
   if(ten_price>prior_close)return 1;
   if(ten_price<prior_close)return -1;
   return 0;
}

double MFRequestedCashRisk(const double equity,const double percent,
                           const double fixed_cash,const bool use_fixed) {
   if(use_fixed)return fixed_cash>0?fixed_cash:0.0;
   if(equity<=0||percent<=0)return 0.0;
   return equity*percent/100.0;
}

int MFRandomSide(const int ny_day,const ulong seed) {
   ulong x=((ulong)ny_day)^seed;x^=x>>12;x^=x<<25;x^=x>>27;
   return ((x*2685821657736338717ULL)&1ULL)==0ULL?-1:1;
}

#endif
