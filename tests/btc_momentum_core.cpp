#include <algorithm>
#include <cassert>
#include <cmath>
#include <limits>
#include <vector>
#include <iostream>
double MathMax(double a,double b){return std::max(a,b);}
double MathMin(double a,double b){return std::min(a,b);}
double MathFloor(double a){return std::floor(a);}
bool MathIsValidNumber(double a){return std::isfinite(a);}
#include "core.mqh"
int main(){
 assert(E2BZoneFirst({50,71,72},3,70)==1);
 assert(E2BZoneFirst({50,71,70},3,70)==-1);
 assert(E2BZoneFirst({71,72},2,70)==-2);
 assert(E2BZoneFirst({50,std::numeric_limits<double>::infinity()},2,70)==-2);
 assert(E2BEntryKind(99,100,100,.0075,.0025,2,false)==2);
 assert(E2BEntryKind(101,101,100,.0075,.0025,2,false)==3);
 assert(E2BEntryKind(99,100,100,.0075,.0025,1,false)==0);
 assert(E2BEntryKind(101,101,100,.0075,.0025,0,false)==0);
 assert(E2BEntryKind(100,100,0,.0075,.0025,2,true)==1);
 assert(E2BEntryKind(100,100,0,.0075,.0025,2,false)==0);
 assert(!E2BValidOHLC(101,100,100));
 assert(E2BRiskFits(1000,1000,2));assert(E2BRiskFits(980,1000,2));
 assert(!E2BRiskFits(979,1000,2));assert(!E2BRiskFits(1001,1000,2));
 assert(!E2BRiskFits(.05,1000,2));assert(!E2BRiskFits(0,1000,2));
 assert(!E2BRiskFits(std::numeric_limits<double>::infinity(),1000,2));
 assert(E2BVolumeFloor(.009,.01,.01,100)==0);
 assert(E2BVolumeFloor(.029,.01,.01,100)<=.029);
 std::cout<<"BTC pure core: zone boundaries, truncation, entry modes, OHLC and risk flooring passed\n";
}
