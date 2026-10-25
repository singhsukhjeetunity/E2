#ifndef E2_BTC_MOMENTUM_CORE_MQH
#define E2_BTC_MOMENTUM_CORE_MQH
bool E2BValidOHLC(const double low,const double high,const double close) {
   return MathIsValidNumber(low)&&MathIsValidNumber(high)&&MathIsValidNumber(close)&&
      low>0&&high>=low&&close>=low&&close<=high;
}
// Chronological completed RSI values. -1 inactive, -2 unsafe, >=0 zone start.
int E2BZoneFirst(const double &values[],const int count,const double threshold) {
   if(count<2||!MathIsValidNumber(threshold)||threshold<=0||threshold>=100)return -2;
   int first=count;
   for(int i=count-1;i>=0;i--) {
      if(!MathIsValidNumber(values[i])||values[i]<0||values[i]>100)return -2;
      if(values[i]<=threshold)return first==count?-1:first;
      first=i;
   }
   return -2; // zone began before available history: do not reset its entry budget
}
// 1 base, 2 pullback, 3 breakout, 0 no signal. Hybrid prioritizes pullback.
int E2BEntryKind(const double close,const double zone_high,const double prior_high,
   const double pullback,const double breakout,const int mode,const bool base) {
   if(!MathIsValidNumber(close)||!MathIsValidNumber(zone_high)||!MathIsValidNumber(prior_high)||
      !MathIsValidNumber(pullback)||!MathIsValidNumber(breakout)||close<=0||zone_high<=0||
      prior_high<0||pullback<=0||breakout<=0||mode<0||mode>2)return 0;
   if(base)return 1;
   if(mode!=1&&(zone_high-close)/zone_high>=pullback)return 2;
   if(mode!=0&&prior_high>0&&(close-prior_high)/prior_high>=breakout)return 3;
   return 0;
}
bool E2BRiskFits(const double actual,const double intended,const double tolerance_percent) {
   if(!MathIsValidNumber(actual)||!MathIsValidNumber(intended)||!MathIsValidNumber(tolerance_percent)||
      actual<=0||intended<=0||tolerance_percent<0||tolerance_percent>10)return false;
   double epsilon=intended*1e-10;
   return actual<=intended+epsilon&&actual+epsilon>=intended*(1-tolerance_percent/100);
}
double E2BVolumeFloor(const double raw,const double step,const double minimum,const double maximum) {
   if(!MathIsValidNumber(raw)||!MathIsValidNumber(step)||!MathIsValidNumber(minimum)||
      !MathIsValidNumber(maximum)||raw<=0||step<=0||minimum<=0||maximum<minimum)return 0;
   double volume=MathFloor(MathMin(raw,maximum)/step)*step;
   return volume>=minimum?volume:0;
}
#endif
