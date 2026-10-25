#ifndef E2_TRAILING_METHOD_MQH
#define E2_TRAILING_METHOD_MQH
enum E2TrailingMethod { E2_TRAIL_EMA=0,E2_TRAIL_ATR=1 };
input group "=== TRAILING STOP METHOD ==="
input E2TrailingMethod InpTrailingMethod=E2_TRAIL_EMA;
input int InpTrailingATRPeriod=14;
input double InpTrailingATRMultiplier=2.0;
bool E2TrailMethodValid() {
   if(InpTrailingMethod!=E2_TRAIL_EMA&&InpTrailingMethod!=E2_TRAIL_ATR)return false;
   return InpTrailingMethod!=E2_TRAIL_ATR||(InpTrailingATRPeriod>=1&&InpTrailingATRPeriod<=1000&&
      MathIsValidNumber(InpTrailingATRMultiplier)&&InpTrailingATRMultiplier>0);
}
double E2TrailLevel(const int direction,const double ema,const double close,const double atr) {
   if(InpTrailingMethod==E2_TRAIL_EMA)return MathIsValidNumber(ema)&&ema>0?ema:0;
   if(InpTrailingMethod!=E2_TRAIL_ATR||!MathIsValidNumber(close)||close<=0||
      !MathIsValidNumber(atr)||atr<=0||!E2TrailMethodValid())return 0;
   double level=close-direction*atr*InpTrailingATRMultiplier;
   return MathIsValidNumber(level)&&level>0?level:0;
}
string E2TrailMethodDigest() {
   // Existing EMA config hashes remain stable; ATR comparisons are identifiable.
   if(InpTrailingMethod==E2_TRAIL_EMA)return "";
   return "|trail_method=ATR|trail_atr_period="+IntegerToString(InpTrailingATRPeriod)+
      "|trail_atr_multiple="+DoubleToString(InpTrailingATRMultiplier,8);
}
#endif
