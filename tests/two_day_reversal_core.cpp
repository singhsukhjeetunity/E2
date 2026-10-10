#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
#include <limits>
double MathMax(double a,double b){return std::max(a,b);}
double MathMin(double a,double b){return std::min(a,b);}
double MathAbs(double a){return std::abs(a);}
double MathFloor(double a){return std::floor(a);}
bool MathIsValidNumber(double a){return std::isfinite(a);}
#include "../strategies/EURUSDTwoDayReversal/ReversalCore.mqh"
int main(){
 E2RDailySeries s{};s.count=16;
 for(int i=0;i<s.count;i++)s.bars[i]={1.12,1.08,i%2?1.099:1.101};
 s.bars[0].high=1.13;s.bars[1].low=1.07;
 E2RSnapshot out{};
 assert(E2RBuildSnapshot(s,14,10,10,true,1,true,.35,out));
 assert(out.high==1.13&&out.low==1.07&&out.allowed);
 assert(std::abs(out.atr-(.10+12*.04)/14)<1e-12);
 assert(out.momentum_percent==0&&out.efficiency==0);
 s.count=14;assert(!E2RBuildSnapshot(s,14,10,10,true,1,true,.35,out));
 s.count=16;
 for(int i=0;i<s.count;i++)s.bars[i].close=1.11-i*.001;
 assert(E2RBuildSnapshot(s,14,10,10,true,2,true,.35,out)&&!out.allowed);
 assert(std::abs(out.efficiency-1)<1e-12);
 assert(E2RBuildSnapshot(s,14,10,10,true,.1,false,.35,out)&&!out.allowed);
 assert(E2RBuildSnapshot(s,14,10,10,false,.1,false,.35,out)&&out.allowed);
 s.bars[0].close=std::numeric_limits<double>::quiet_NaN();
 assert(!E2RBuildSnapshot(s,14,10,10,false,1,false,.35,out));
 s.bars[0].close=1.11;
 assert(!E2RBuildSnapshot(s,0,10,10,false,1,false,.35,out));
 assert(!E2RBuildSnapshot(s,14,10,10,false,1,false,1.1,out));
 assert(E2RTouchSide(1.1,1.07,1.07,1.13)==1);
 assert(E2RTouchSide(1.1,1.13,1.07,1.13)==-1);
 assert(E2RTouchSide(0,1.07,1.07,1.13)==0); // first tick/restart
 assert(E2RTouchSide(1.06,1.05,1.07,1.13)==0); // no chasing old breach
 assert(E2RTouchSide(1.14,1.15,1.07,1.13)==0);
 assert(E2RTouchSide(1.14,1.1,1.07,1.13)==0); // re-entering range isn't a reversal trigger
 assert(E2RVolumeFloor(.009,.01,.01,100)==0);
 assert(E2RVolumeFloor(.029,.01,.01,100)<=.029);
 assert(E2RVolumeFloor(200,.01,.01,100)==100);
 assert(E2RVolumeFloor(1,0,.01,100)==0);
 assert(E2RVolumeFloor(std::numeric_limits<double>::infinity(),.01,.01,100)==0);
 std::cout<<"Two-day reversal: levels, filter regimes, warmup, fresh touches and risk flooring passed\n";
}
