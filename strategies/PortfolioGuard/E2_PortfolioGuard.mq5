#property strict
#property version "1.00"
#property description "E2 portfolio-wide daily equity loss guard. Attach ONCE per MT5 account."
#include <Trade/Trade.mqh>
#include "..\\shared\\PortfolioGate.mqh"

enum E2PGLimitMode { E2PG_PERCENT_OF_REFERENCE=0, E2PG_FIXED_ACCOUNT_CASH=1 };

input group "=== PORTFOLIO DAILY LOSS ==="
input E2PGLimitMode InpDailyLossMode=E2PG_PERCENT_OF_REFERENCE;
input double InpDailyLossPercent=2.0; // Percent of daily reference equity
input double InpDailyLossCash=2000.0; // Account currency; used only in fixed-cash mode
input bool InpCloseAllOnLimit=true;   // Close ALL account positions and delete ALL pending orders

input group "=== DAILY RESET (BROKER SERVER CLOCK) ==="
input int InpResetServerHour=0;       // Must match the firm's actual daily reset
input int InpResetServerMinute=0;
input double InpFirstDayReferenceEquity=0.0; // Optional; required for first mid-day deployment

input group "=== EXECUTION SAFETY ==="
input ulong InpCloseDeviationPoints=50; // Broker POINTS; affects forced closes only

CTrade pg_trade;
string pg_key="";
bool pg_owns_guard=false;
bool pg_ready=false;
bool pg_locked=false;
int pg_day=0;
datetime pg_last_warning=0;

bool PGWrite(const string suffix,const double value)
{
   return GlobalVariableSet(pg_key+suffix,value)>0;
}
bool PGFieldsPresent()
{
   return GlobalVariableCheck(pg_key+"DAY")&&
          GlobalVariableCheck(pg_key+"BASE")&&
          GlobalVariableCheck(pg_key+"FLOOR")&&
          GlobalVariableCheck(pg_key+"LOCK")&&
          GlobalVariableCheck(pg_key+"READY")&&
          GlobalVariableCheck(pg_key+"RH")&&
          GlobalVariableCheck(pg_key+"RM");
}
bool PGExistingDayValid(const int day)
{
   if(!PGFieldsPresent())return false;
   if((int)GlobalVariableGet(pg_key+"DAY")!=day)return false;
   if((int)GlobalVariableGet(pg_key+"RH")!=InpResetServerHour||
      (int)GlobalVariableGet(pg_key+"RM")!=InpResetServerMinute)return false;
   double base=GlobalVariableGet(pg_key+"BASE");
   double floor=GlobalVariableGet(pg_key+"FLOOR");
   if(GlobalVariableGet(pg_key+"READY")<0.5)
      return base==0.0&&floor==0.0&&GlobalVariableGet(pg_key+"LOCK")>=0.5;
   if(!MathIsValidNumber(base)||!MathIsValidNumber(floor)||
      base<=0.0||floor<=0.0||floor>=base)return false;
   return true;
}
double PGFloor(const double reference)
{
   if(InpDailyLossMode==E2PG_PERCENT_OF_REFERENCE)
      return reference*(1.0-InpDailyLossPercent/100.0);
   return reference-InpDailyLossCash;
}
void PGWarn(const string message)
{
   datetime now=TimeLocal();
   if(now-pg_last_warning>=60||pg_last_warning==0)
   {
      Print("[E2 PortfolioGuard] ",message);
      pg_last_warning=now;
   }
}
bool PGSetDay(const int day,const bool can_seed,const double manual_reference)
{
   // Publish READY=0 before changing any other field. Missing or incomplete
   // state always blocks entry in all four live/demo EAs.
   if(!PGWrite("READY",0.0)||!PGWrite("LOCK",1.0))return false;
   double reference=can_seed?(manual_reference>0.0?manual_reference:
                               AccountInfoDouble(ACCOUNT_EQUITY)):0.0;
   double floor=can_seed?PGFloor(reference):0.0;
   if(can_seed&&(!MathIsValidNumber(reference)||!MathIsValidNumber(floor)||
      reference<=0.0||floor<=0.0||floor>=reference))return false;
   if(!PGWrite("DAY",(double)day)||!PGWrite("BASE",reference)||
      !PGWrite("FLOOR",floor)||
      !PGWrite("RH",(double)InpResetServerHour)||
      !PGWrite("RM",(double)InpResetServerMinute))return false;
   bool breached=can_seed&&AccountInfoDouble(ACCOUNT_EQUITY)<=floor;
   if(can_seed)
   {
      if(!PGWrite("LOCK",breached?1.0:0.0)||!PGWrite("READY",1.0))return false;
   }
   pg_ready=can_seed;
   pg_locked=!can_seed||breached;
   pg_day=day;
   GlobalVariablesFlush();
   if(can_seed)
      PrintFormat("[E2 PortfolioGuard] Day %d initialized; equity reference=%.2f, floor=%.2f, locked=%d",
                  day,reference,floor,(int)pg_locked);
   else
      Print("[E2 PortfolioGuard] No verified beginning-of-day reference. All E2 entries BLOCKED until next reset. Set InpFirstDayReferenceEquity if the correct daily reference is known.");
   return true;
}
void PGCloseAccountPositions()
{
   // Pending orders might later open new positions: cancel first.
   // Applies to E2, copied and manually placed trades in this entire account.
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong order=OrderGetTicket(i);
      if(order==0)continue;
      bool sent=pg_trade.OrderDelete(order);
      uint code=pg_trade.ResultRetcode();
      if(!sent||code!=TRADE_RETCODE_DONE)
         PGWarn(StringFormat("Pending order %I64u could not be canceled; retcode=%u (retrying)",order,code));
   }
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(!pg_trade.SetTypeFillingBySymbol(symbol))
      {
         PGWarn("Cannot determine filling mode for "+symbol+"; retrying close");
         continue;
      }
      bool sent=pg_trade.PositionClose(ticket);
      uint code=pg_trade.ResultRetcode();
      if(!sent||(code!=TRADE_RETCODE_DONE&&code!=TRADE_RETCODE_DONE_PARTIAL&&
                 code!=TRADE_RETCODE_PLACED))
         PGWarn(StringFormat("Position %I64u (%s) not closed yet; retcode=%u (retrying)",ticket,symbol,code));
   }
}
void PGRun()
{
   if(!pg_owns_guard)return;
   datetime server=TimeTradeServer();
   datetime local=TimeLocal();
   int day=E2PGDayKey(server,InpResetServerHour,InpResetServerMinute);
   if(day<=0||local<=0)return; // No heartbeat: trading EAs fail closed.
   if(day!=pg_day)
   {
      // An uninterrupted guard can carry the account across midnight.
      // After a long shutdown, never invent yesterday's floating-equity snapshot.
      bool continuous=E2PGFresh(local,GlobalVariableCheck(pg_key+"HB")?
                                   GlobalVariableGet(pg_key+"HB"):0.0);
      bool within_reset=E2PGMinutesAfterReset(server,InpResetServerHour,InpResetServerMinute)<5;
      if(!PGSetDay(day,continuous||within_reset||MQLInfoInteger(MQL_TESTER)!=0,0.0))
      {
         PGWarn("Cannot initialize new-day lock; E2 entries remain blocked.");
         return;
      }
   }
   if(!PGFieldsPresent()||!PGExistingDayValid(day))
   {
      PGWarn("Missing/corrupt daily equity state or reset-time mismatch; guard is fail-closed.");
      PGWrite("READY",0.0);
      PGWrite("LOCK",1.0);
      GlobalVariablesFlush();
      return;
   }
   pg_ready=GlobalVariableGet(pg_key+"READY")>=0.5;
   pg_locked=GlobalVariableGet(pg_key+"LOCK")>=0.5;
   if(pg_ready)
   {
      double equity=AccountInfoDouble(ACCOUNT_EQUITY);
      double floor=GlobalVariableGet(pg_key+"FLOOR");
      if(!MathIsValidNumber(equity)||equity<=0.0)return; // No heartbeat.
      if(!pg_locked&&equity<=floor)
      {
         if(!PGWrite("LOCK",1.0))return;
         pg_locked=true;
         GlobalVariablesFlush();
         PrintFormat("[E2 PortfolioGuard] DAILY LOSS LIMIT HIT. Equity=%.2f floor=%.2f. All further E2 entries blocked.",equity,floor);
      }
      // A lock is sticky for the entire broker-defined day, including restarts.
      // Keep retrying failed closes and deleting pending orders on every timer.
      if(pg_locked&&InpCloseAllOnLimit)PGCloseAccountPositions();
   }
   // Heartbeat is published LAST, only after the day/lock have been checked.
   PGWrite("HB",(double)local);
   double base=GlobalVariableGet(pg_key+"BASE");
   double floor=GlobalVariableGet(pg_key+"FLOOR");
   string state=!pg_ready?"NO DAILY REFERENCE (entries blocked)":
                 (pg_locked?"DAILY LIMIT LOCKED":"ACTIVE");
   Comment("E2 PortfolioGuard | ",state,
           "\nAccount equity: ",DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2),
           "\nDaily reference: ",DoubleToString(base,2),
           "\nEquity floor: ",DoubleToString(floor,2),
           "\nReset (server): ",IntegerToString(InpResetServerHour),":",
                              IntegerToString(InpResetServerMinute));
}
int OnInit()
{
   if((int)InpDailyLossMode<0||(int)InpDailyLossMode>1||
      !MathIsValidNumber(InpDailyLossPercent)||InpDailyLossPercent<=0.0||InpDailyLossPercent>=100.0||
      !MathIsValidNumber(InpDailyLossCash)||InpDailyLossCash<=0.0||
      InpResetServerHour<0||InpResetServerHour>23||
      InpResetServerMinute<0||InpResetServerMinute>59||
      !MathIsValidNumber(InpFirstDayReferenceEquity)||InpFirstDayReferenceEquity<0.0||
      InpCloseDeviationPoints>100000)return INIT_PARAMETERS_INCORRECT;
   pg_key=E2PGPrefix();
   datetime local=TimeLocal(),server=TimeTradeServer();
   if(local<=0||server<=0)return INIT_FAILED;
   if(GlobalVariableCheck(pg_key+"HB")&&
      E2PGFresh(local,GlobalVariableGet(pg_key+"HB")))
   {
      Print("[E2 PortfolioGuard] Another active guard detected for this account in this MT5 terminal.");
      return INIT_FAILED;
   }
   // New trading rules never override an existing daily loss reference or lock.
   int day=E2PGDayKey(server,InpResetServerHour,InpResetServerMinute);
   if(day<=0)return INIT_FAILED;
   bool same_day=PGExistingDayValid(day);
   if(!same_day&&GlobalVariableCheck(pg_key+"DAY")&&
      (int)GlobalVariableGet(pg_key+"DAY")==day)
   {
      Print("[E2 PortfolioGuard] Existing same-day state invalid or reset configuration changed. Failing closed; do not reset the daily budget.");
      return INIT_FAILED;
   }
   pg_trade.SetAsyncMode(false);
   pg_trade.SetDeviationInPoints(InpCloseDeviationPoints);
   if(!same_day)
   {
      bool within_reset=E2PGMinutesAfterReset(server,InpResetServerHour,InpResetServerMinute)<5;
      // A first-install manual reference is NEVER reused after a later day
      // or VPS outage. Stale input must not silently reset a prop account budget.
      bool manual_first=!GlobalVariableCheck(pg_key+"DAY")&&!within_reset&&
                        InpFirstDayReferenceEquity>0.0;
      bool can_seed=within_reset||manual_first||MQLInfoInteger(MQL_TESTER)!=0;
      if(!PGSetDay(day,can_seed,manual_first?InpFirstDayReferenceEquity:0.0))
         return INIT_FAILED;
   }
   else
   {
      // Operator may supply the CORRECT opening reference after installing
      // mid-day in fail-closed unseeded mode. Never reset a valid daily lock.
      if(GlobalVariableGet(pg_key+"READY")<0.5&&
         InpFirstDayReferenceEquity>0.0)
      {
         if(!PGSetDay(day,true,InpFirstDayReferenceEquity))return INIT_FAILED;
      }
      else
      {
         pg_day=day;
         pg_ready=GlobalVariableGet(pg_key+"READY")>=0.5;
         pg_locked=GlobalVariableGet(pg_key+"LOCK")>=0.5;
         Print("[E2 PortfolioGuard] Existing account/day reference and lock recovered without reset.");
      }
   }
   pg_owns_guard=true;
   if(!EventSetTimer(1))
   {
      pg_owns_guard=false;
      Print("[E2 PortfolioGuard] Could not start timer; no E2 entries permitted.");
      return INIT_FAILED;
   }
   PGRun();
   return INIT_SUCCEEDED;
}
void OnTick(){PGRun();}
void OnTimer(){PGRun();}
void OnDeinit(const int reason)
{
   if(pg_owns_guard)
   {
      EventKillTimer();
      PGWrite("HB",0.0);
      GlobalVariablesFlush();
   }
   Comment("");
}
