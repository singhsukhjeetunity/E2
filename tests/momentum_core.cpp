#include "../strategies/IndexClosingMomentum/MomentumCore.mqh"
#include <cassert>
#include <iostream>

int main() {
   assert(MFDirection(100.0,101.0)==1);
   assert(MFDirection(100.0,99.0)==-1);
   assert(MFDirection(100.0,100.0)==0);
   double odd[5]={5,1,4,2,3};assert(MFMedianCpp(odd,5)==3);
   double even[4]={4,1,3,2};assert(MFMedianCpp(even,4)==2.5);
   assert(std::fabs(MFRequestedCashRisk(100000,0.5,200,false)-500)<1e-12);
   assert(std::fabs(MFRequestedCashRisk(100000,0.5,200,true)-200)<1e-12);
   assert(MFRandomSide(20260102,17)==MFRandomSide(20260102,17));
   std::cout << "momentum core checks passed\n";
}
