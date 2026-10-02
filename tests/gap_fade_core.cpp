#include "../strategies/IndexOvernightGapFade/GapFadeCore.mqh"
#include <cassert>
#include <iostream>

int main() {
   GFDayBar d[15];
   for(int i=0;i<15;i++)d[i]={20260101+i,100.0,102.0,98.0,100.0};
   assert(std::fabs(GFWilderAtr(d,15,14)-4.0)<1e-12);
   assert(GFSignal(101.0,100.0,4.0,0.15,1.0,101.0,100.5)==-1);
   assert(GFSignal(99.0,100.0,4.0,0.15,1.0,99.0,99.5)==1);
   assert(GFSignal(100.1,100.0,4.0,0.15,1.0,100.1,99.0)==0);
   assert(GFSignal(105.0,100.0,4.0,0.15,1.0,105.0,104.0)==0);
   assert(GFSignal(101.0,100.0,4.0,0.15,1.0,101.0,101.0)==0);
   assert(GFRandomSide(20260102,7)==GFRandomSide(20260102,7));
   std::cout << "gap fade core checks passed\n";
}
