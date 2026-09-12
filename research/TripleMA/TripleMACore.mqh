#ifndef TRIPLE_MA_CORE_MQH
#define TRIPLE_MA_CORE_MQH

// Inputs are completed bars: previous = shift 2, current = shift 1.
// Slow-MA alignment is required on the crossover bar only.
int TripleMASignal(const double fast_previous,const double medium_previous,
                   const double fast_current,const double medium_current,const double slow_current)
  {
   if(fast_previous<=medium_previous && fast_current>medium_current &&
      fast_current>slow_current && medium_current>slow_current)return(1);
   if(fast_previous>=medium_previous && fast_current<medium_current &&
      fast_current<slow_current && medium_current<slow_current)return(-1);
   return(0);
  }

double TripleMATarget(const int direction,const double fill,const double stop,const double target_r)
  {return(fill+direction*MathAbs(fill-stop)*target_r);}

bool TripleMAProtectionValid(const int direction,const double fill,const double stop,const double target)
  {return((direction==1||direction==-1)&&fill>0&&stop>0&&target>0&&direction*(fill-stop)>0&&direction*(target-fill)>0);}

bool TripleMARiskWithinBudget(const double actual,const double requested)
  {return(actual>0&&requested>0&&actual<=requested+0.000001);}

uint TripleMAHash(const string value)
  {
   uint hash=2166136261;
   for(int i=0;i<StringLen(value);i++){hash^=(uint)StringGetCharacter(value,i);hash*=16777619;}
   return(hash);
  }
#endif
