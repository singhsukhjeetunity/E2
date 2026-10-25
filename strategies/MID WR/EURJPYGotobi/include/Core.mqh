#ifndef RC_CORE_MQH
#define RC_CORE_MQH
// Pure signal rules: bars are completed and oldest first. No broker APIs.
struct RCBar { datetime start; double open,high,low,close; int minutes; };
double RCIBS(const RCBar &b) {
   return b.high>b.low?(b.close-b.low)/(b.high-b.low):0.5;
}
double RCTR(const RCBar &b,const double previous) {
   return MathMax(b.high-b.low,MathMax(MathAbs(b.high-previous),MathAbs(b.low-previous)));
}
double RCRangeMean(const RCBar &bars[],const int count,const int period) {
   if(period<1||count<period)return 0;
   double sum=0;for(int i=count-period;i<count;i++)sum+=bars[i].high-bars[i].low;
   return sum/period;
}
double RCATR(const RCBar &bars[],const int count,const int period) {
   if(period<1||count<period+1)return 0;
   double sum=0;for(int i=count-period;i<count;i++)sum+=RCTR(bars[i],bars[i-1].close);
   return sum/period; // Explicit simple mean of true ranges, not Wilder smoothing.
}
double RCHigh(const RCBar &bars[],const int count,const int period) {
   if(period<1||count<period)return 0;
   double value=bars[count-period].high;
   for(int i=count-period+1;i<count;i++)value=MathMax(value,bars[i].high);
   return value;
}
double RCLow(const RCBar &bars[],const int count,const int period) {
   if(period<1||count<period)return 0;
   double value=bars[count-period].low;
   for(int i=count-period+1;i<count;i++)value=MathMin(value,bars[i].low);
   return value;
}
double RCER(const RCBar &bars[],const int count,const int period) {
   if(period<1||count<=period)return -1;
   double path=0;for(int i=count-period;i<count;i++)path+=MathAbs(bars[i].close-bars[i-1].close);
   return path>0?MathAbs(bars[count-1].close-bars[count-period-1].close)/path:0;
}
bool RCRegime(const RCBar &bars[],const int count,const int momentum_period,
              const int er_period,const double maximum_er,const double maximum_momentum_atr,
              const double atr) {
   if(atr<=0||count<=momentum_period||momentum_period<1)return false;
   double er=RCER(bars,count,er_period);
   double momentum=MathAbs(bars[count-1].close-bars[count-momentum_period-1].close)/atr;
   return er>=0&&er<=maximum_er&&momentum<=maximum_momentum_atr;
}
bool RCPullback(const RCBar &bars[],const int count,const int high_period,
                const int range_period,const double band_multiple,const double maximum_ibs) {
   if(count<2||count<high_period||count<range_period)return false;
   return RCIBS(bars[count-1])<maximum_ibs&&
          bars[count-1].close<RCHigh(bars,count,high_period)-band_multiple*RCRangeMean(bars,count,range_period);
}
int RCReclaim(const RCBar &previous,const RCBar &latest,const double low,const double high) {
   if(previous.close<low&&latest.close>low)return 1;
   if(previous.close>high&&latest.close<high)return -1;
   return 0;
}
int RCGapDirection(const double open,const double previous_low,const double previous_high) {
   if(open<previous_low)return 1;
   if(open>previous_high)return -1;
   return 0;
}
// Round down only: an undersized risk budget must never force the broker minimum.
double RCVolume(const double budget,const double loss_per_lot,const double minimum,
                const double maximum,const double step) {
   if(budget<=0||loss_per_lot<=0||step<=0||minimum<=0||maximum<minimum)return 0;
   double raw=MathMin(maximum,budget/loss_per_lot);
   double lots=MathFloor((raw+step*1e-9)/step)*step;
   return lots>=minimum&&lots*loss_per_lot<=budget+1e-7?lots:0;
}
#endif
