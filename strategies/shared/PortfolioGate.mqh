#ifndef E2_PORTFOLIO_GATE_MQH
#define E2_PORTFOLIO_GATE_MQH
// Account-wide terminal Global Variables. These are shared ONLY by EAs in one
// MT5 terminal/account. Never delete the daily BASE/DAY/LOCK while trading.
// Entries fail closed if the PortfolioGuard's timer stops updating its heartbeat.
#define E2PG_HEARTBEAT_TTL 10

string E2PGPrefix()
{
   string server=AccountInfoString(ACCOUNT_SERVER);
   uint hash=2166136261;
   for(int i=0;i<StringLen(server);i++)
   {
      hash^=(uint)StringGetCharacter(server,i);
      hash*=16777619;
   }
   return "E2PG_"+StringFormat("%08X",hash)+"_"+
          StringFormat("%I64d",AccountInfoInteger(ACCOUNT_LOGIN))+"_";
}
int E2PGDayKey(const datetime server_time,const int reset_hour,const int reset_minute)
{
   if(server_time<=0||reset_hour<0||reset_hour>23||reset_minute<0||reset_minute>59)return 0;
   MqlDateTime d;
   if(!TimeToStruct(server_time-reset_hour*3600-reset_minute*60,d))return 0;
   return d.year*10000+d.mon*100+d.day;
}
int E2PGMinutesAfterReset(const datetime server_time,const int reset_hour,const int reset_minute)
{
   long shift=(long)server_time-reset_hour*3600-reset_minute*60;
   if(shift<0)return -1;
   return (int)((shift%86400)/60);
}
bool E2PGFresh(const datetime now_local,const double heartbeat)
{
   if(now_local<=0||!MathIsValidNumber(heartbeat)||heartbeat<=0)return false;
   double seconds=(double)now_local-heartbeat;
   return seconds>=0.0&&seconds<=E2PG_HEARTBEAT_TTL;
}
bool E2PGCanEnter()
{
   // MT5's ordinary single-EA tester cannot attach a second controller.
   // Live/demo trading NEVER uses this bypass.
   if(MQLInfoInteger(MQL_TESTER)!=0)return true;
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))return false;
   string key=E2PGPrefix();
   if(!GlobalVariableCheck(key+"HB")||
      !GlobalVariableCheck(key+"DAY")||
      !GlobalVariableCheck(key+"READY")||
      !GlobalVariableCheck(key+"LOCK")||
      !GlobalVariableCheck(key+"FLOOR")||
      !GlobalVariableCheck(key+"RH")||
      !GlobalVariableCheck(key+"RM"))return false;
   if(!E2PGFresh(TimeLocal(),GlobalVariableGet(key+"HB")))return false;
   if(GlobalVariableGet(key+"READY")<0.5||GlobalVariableGet(key+"LOCK")>=0.5)return false;
   int hour=(int)GlobalVariableGet(key+"RH");
   int minute=(int)GlobalVariableGet(key+"RM");
   int day=E2PGDayKey(TimeTradeServer(),hour,minute);
   if(day==0||day!=(int)GlobalVariableGet(key+"DAY"))return false;
   double floor=GlobalVariableGet(key+"FLOOR");
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(!MathIsValidNumber(floor)||!MathIsValidNumber(equity)||floor<=0||equity<=0)return false;
   if(equity<=floor)
   {
      // A latched equity breach must be visible to the guard immediately.
      GlobalVariableSet(key+"LOCK",1.0);
      GlobalVariablesFlush();
      return false;
   }
   return true;
}
#endif
