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
   assert(std::fabs(GFRequestedCashRisk(100000.0,0.5,200.0,false)-500.0)<1e-12);
   assert(std::fabs(GFRequestedCashRisk(100000.0,0.5,200.0,true)-200.0)<1e-12);
   assert(GFRequestedCashRisk(100000.0,0.0,200.0,false)==0.0);
   assert(GFRequestedCashRisk(100000.0,0.5,0.0,true)==0.0);
   std::cout << "gap fade core checks passed\n";
}
