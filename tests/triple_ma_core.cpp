#include <cassert>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <string>
using string=std::string;
using uint=unsigned int;
double MathAbs(double v){return std::abs(v);}
int StringLen(const string &s){return static_cast<int>(s.size());}
unsigned short StringGetCharacter(const string &s,int i){return static_cast<unsigned char>(s.at(i));}
#include "../research/TripleMA/TripleMACore.mqh"

int main()
  {
   // Cross up/down with correct current-bar slow alignment.
   assert(TripleMASignal(9,10,12,11,8)==1);
   assert(TripleMASignal(11,10,8,9,12)==-1);
   // Current alignment alone never emits a new trade.
   assert(TripleMASignal(12,11,13,12,8)==0);
   assert(TripleMASignal(8,9,7,8,12)==0);
   // Cross without slow confirmation, or equality to slow, is rejected.
   assert(TripleMASignal(9,10,12,11,11.5)==0);
   assert(TripleMASignal(11,10,8,9,8.5)==0);
   assert(TripleMASignal(9,10,12,11,11)==0);
   assert(TripleMASignal(11,10,8,9,9)==0);
   // Previous equality counts as crossing; current equality does not.
   assert(TripleMASignal(10,10,12,11,8)==1);
   assert(TripleMASignal(10,10,8,9,12)==-1);
   assert(TripleMASignal(9,10,11,11,8)==0);
   // Reversal symmetry over a positive-price reflection.
   for(int fp=5;fp<=15;fp++)for(int mp=5;mp<=15;mp++)
   for(int fc=5;fc<=15;fc++)for(int mc=5;mc<=15;mc++)
      assert(TripleMASignal(fp,mp,fc,mc,10)==-TripleMASignal(20-fp,20-mp,20-fc,20-mc,10));
   // Actual-fill TP moves correctly in both directions and different R values.
   assert(TripleMATarget(1,100,98,1)==102);
   assert(TripleMATarget(-1,100,102,1)==98);
   assert(TripleMATarget(1,101,98,1.5)==105.5);
   assert(TripleMATarget(-1,99,102,1.5)==94.5);
   assert(TripleMAProtectionValid(1,100,98,102));
   assert(TripleMAProtectionValid(-1,100,102,98));
   assert(!TripleMAProtectionValid(1,100,101,102));
   assert(!TripleMAProtectionValid(-1,100,102,103));
   assert(!TripleMAProtectionValid(1,100,98,0));
   assert(TripleMARiskWithinBudget(99.99,100));
   assert(!TripleMARiskWithinBudget(100.01,100));
   assert(!TripleMARiskWithinBudget(0,100));
   assert(!TripleMARiskWithinBudget(-1,100));
   assert(!TripleMARiskWithinBudget(NAN,100));
   assert(TripleMAHash("TRIPLE_MA|10|20|50")!=TripleMAHash("TRIPLE_MA|10|20|51"));
   std::cout<<"TripleMA signal boundaries, 14641 direction-symmetry cases, target geometry and risk-budget checks passed\n";
  }
