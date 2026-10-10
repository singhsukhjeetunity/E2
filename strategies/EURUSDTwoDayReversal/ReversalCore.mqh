#ifndef E2_TWO_DAY_REVERSAL_CORE_MQH
#define E2_TWO_DAY_REVERSAL_CORE_MQH
// Pure calculations shared by the MQL5 EA and portable regression tests.
// bars[0] is the newest COMPLETED eligible broker D1 session.
struct E2RDailyBar {
   double high,low,close;
};
struct E2RDailySeries {
   E2RDailyBar bars[257];
   int count;
};
struct E2RSnapshot {
   double high,low,atr,momentum_percent,efficiency;
   bool allowed;
};
bool E2RValidBar(const E2RDailyBar &bar) {
   return MathIsValidNumber(bar.high)&&MathIsValidNumber(bar.low)&&MathIsValidNumber(bar.close)&&
      bar.low>0&&bar.high>=bar.low&&bar.close>=bar.low&&bar.close<=bar.high;
}
bool E2RBuildSnapshot(const E2RDailySeries &series,const int atr_period,
                     const int momentum_period,const int efficiency_period,
                     const bool use_momentum,const double max_momentum_percent,
                     const bool use_efficiency,const double max_efficiency,E2RSnapshot &out) {
   out.high=0;out.low=0;out.atr=0;out.momentum_percent=0;out.efficiency=0;out.allowed=false;
   if(atr_period<1||atr_period>256||momentum_period<1||momentum_period>256||
      efficiency_period<1||efficiency_period>256||max_momentum_percent<0||
      !MathIsValidNumber(max_momentum_percent)||!MathIsValidNumber(max_efficiency)||
      max_efficiency<0||max_efficiency>1)return false;
   int required=atr_period+1;
   if(required<2)required=2;
   if(use_momentum&&required<momentum_period+1)required=momentum_period+1;
   if(use_efficiency&&required<efficiency_period+1)required=efficiency_period+1;
   if(series.count<required||series.count>257)return false;
   for(int i=0;i<required;i++)if(!E2RValidBar(series.bars[i]))return false;
   out.high=MathMax(series.bars[0].high,series.bars[1].high);
   out.low=MathMin(series.bars[0].low,series.bars[1].low);
   if(out.high<=out.low)return false;
   for(int i=0;i<atr_period;i++) {
      double previous=series.bars[i+1].close;
      out.atr+=MathMax(series.bars[i].high-series.bars[i].low,
         MathMax(MathAbs(series.bars[i].high-previous),MathAbs(series.bars[i].low-previous)));
   }
   out.atr/=atr_period; // Simple mean of completed-session true ranges, not Wilder ATR.
   if(out.atr<=0||!MathIsValidNumber(out.atr))return false;
   if(use_momentum)out.momentum_percent=100*(series.bars[0].close/series.bars[momentum_period].close-1);
   if(use_efficiency) {
      double path=0;
      for(int i=0;i<efficiency_period;i++)path+=MathAbs(series.bars[i].close-series.bars[i+1].close);
      out.efficiency=path>0?MathAbs(series.bars[0].close-series.bars[efficiency_period].close)/path:0;
   }
   out.allowed=(!use_momentum||MathAbs(out.momentum_percent)<=max_momentum_percent)&&
      (!use_efficiency||out.efficiency<=max_efficiency);
   return true;
}
// Fresh crossings prevent attaching/restarting outside the channel from chasing an old touch.
// Bid is the signal series on both sides; long executions use the actual Ask.
int E2RTouchSide(const double previous_bid,const double bid,const double low,const double high) {
   if(previous_bid<=0||bid<=0||low<=0||high<=low||
      !MathIsValidNumber(previous_bid)||!MathIsValidNumber(bid))return 0;
   if(previous_bid>low&&bid<=low)return 1;
   if(previous_bid<high&&bid>=high)return -1;
   return 0;
}
double E2RVolumeFloor(const double raw,const double step,const double minimum,const double maximum) {
   if(!MathIsValidNumber(raw)||!MathIsValidNumber(step)||!MathIsValidNumber(minimum)||
      !MathIsValidNumber(maximum)||raw<=0||step<=0||minimum<=0||maximum<minimum)return 0;
   double volume=MathFloor(MathMin(raw,maximum)/step)*step;
   return volume>=minimum?volume:0; // Never round UP to the broker minimum.
}
#endif
