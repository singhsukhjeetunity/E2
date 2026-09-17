#ifndef COMPRESSION_ENGINE_MQH
#define COMPRESSION_ENGINE_MQH
#include <Trade/Trade.mqh>
#include "CompressionCore.mqh"
#include "..\\EMAPullback\\EMAState.mqh"
#include "CompressionClock.mqh"
#include "..\\shared\\ReportFolders.mqh"

input group "Historical broker time"
input NPClockMode InpBrokerClock=NP_CLOCK_UNSET;
input int InpBrokerWinterUtcOffsetSeconds=0;
input group "Strategy settings"
input int InpATRLength=14;
input int InpChannelBars=20;
input int InpCompressionBars=100;
input double InpCompressionRatio=0.8;
input double InpStopATR=3.0;
input double InpTargetR=2.0;
input bool InpOneTradePerDay=false; // Research baseline: off. When on: one filled entry per UTC date, symbol and magic
input group "Risk and identification"
input double InpCashRisk=1000.0;
input ulong InpMagic=2026091703;
input group "Execution and reporting"
input int InpBrokerCloseBufferMinutes=5; // Exit before the active broker session ends
input double InpMaxSpreadPriceUnits=0.03;
input double InpMaxDeviationPriceUnits=0.005;
input int InpMaxEntryDelaySeconds=5;
input bool InpExportCsv=true;

struct NPSlot {
   CBState indicators;
   CBBar forming;
   bool has_bar,pending,signal;
   datetime signal_time,seen_signal,last_exit_minute;
   double signal_atr;
   int active;
};
NPSlot g_slots[1];
NPRecord g_records[];
CTrade g_trade;
datetime g_last_server_minute=0,g_last_utc_minute=0,g_equity_minute=0;
datetime g_test_from=0,g_test_until=0;
int g_signals=INVALID_HANDLE,g_equity=INVALID_HANDLE;
string g_run,g_config,g_report_folder,g_report_base;
bool g_ready=false,g_failed=false,g_seeded=false,g_bootstrapped=false;
string g_state_file,g_scope;
int g_instance_lock=INVALID_HANDLE;
datetime g_history_notice=0;
double g_cash[1],g_r[1];
double g_equity_peak=0,g_equity_dd=0;

bool Enabled(const int s) {return s==0;}
int PeriodMinutes(const int s) {return 30;}
ulong Magic(const int s) {return InpMagic;}
string Strategy(const int s) {return "CB_COMPRESSION_M30_LONG";}
string Stamp(const datetime t) {
   if(t==0)return "";
   string x=TimeToString(t,TIME_DATE|TIME_SECONDS);StringReplace(x,".","-");return x;
}
string Number(const double n) {return DoubleToString(n,10);}
string Hash(const string x) {
   uint h=2166136261;
   for(int i=0;i<StringLen(x);i++){h^=(uint)StringGetCharacter(x,i);h*=16777619;}
   return StringFormat("%08X",h);
}
void Fail(const string why) {
   if(!g_failed)Print("[CB][FAILED] ",why,". New entries stopped; existing positions still managed.");
   g_failed=true;
}
bool Utc(const datetime server,datetime &utc) {
   if(NPToUtc(server,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds,utc))return true;
   Fail("Uncovered or ambiguous broker timestamp");return false;
}
void Audit(const int slot,const datetime utc,const string event,const string detail) {
   Print("[CB][",Strategy(slot),"] ",event," ",detail);
   if(g_signals!=INVALID_HANDLE) {
      FileWrite(g_signals,"NP_SIGNAL_V1",g_run,Strategy(slot),Stamp(utc),event,detail);
      FileFlush(g_signals);
   }
}
double RoundPrice(const double p) {
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return NormalizeDouble(MathRound(p/tick)*tick,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
}
ulong PositionFor(const int s,const ulong pid=0) {
   for(int i=0;i<PositionsTotal();i++){
      ulong t=PositionGetTicket(i);
      if(t>0 && PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==Magic(s) &&
         (pid==0||(ulong)PositionGetInteger(POSITION_IDENTIFIER)==pid))return t;
   }
   return 0;
}
bool CashRisk(const int s,const double volume,const double fill,const double sl,double &risk) {
   double profit=0;
   if(!OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,volume,fill,sl,profit))return false;
   risk=MathAbs(profit);return MathIsValidNumber(risk)&&risk>0;
}
// One instance owns this account/server/symbol/magic state. Tester agents use
// local state; demo and real terminals use the SAME Common Files mechanism.
int StateFlags() {return MQLInfoInteger(MQL_TESTER)?0:FILE_COMMON;}
string g_last_checkpoint="";
bool SaveState() {
   if(g_instance_lock==INVALID_HANDLE)return false;
   NPCheckpoint c;ZeroMemory(c);
   c.scope=g_scope;c.config=g_config;c.failed=g_failed;
   c.last_exit=g_slots[0].last_exit_minute;c.active=g_slots[0].active>=0;
   c.pending=g_slots[0].pending;
   if(c.active)c.record=g_records[g_slots[0].active];
   string payload=NPEncode(c);
   if(payload==g_last_checkpoint)return true;
   string text=payload+"\r\n"+Hash(payload)+"\r\n";
   string temp=g_state_file+".tmp";
   int h=FileOpen(temp,FILE_WRITE|FILE_TXT|FILE_UNICODE|StateFlags());
   if(h==INVALID_HANDLE){Fail("Cannot write compression recovery state; new entries blocked");return false;}
   ResetLastError();uint written=FileWriteString(h,text);FileFlush(h);int error=GetLastError();FileClose(h);
   if(written!=(uint)(StringLen(text)*2)||error!=0 ||
      !FileMove(temp,StateFlags(),g_state_file,StateFlags()|FILE_REWRITE)) {
      Fail("Cannot commit compression recovery state; new entries blocked");return false;
   }
   g_last_checkpoint=payload;return true;
}
bool EntryOwnershipClear() {
   bool netting=AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   for(int i=0;i<PositionsTotal();i++) {
      ulong t=PositionGetTicket(i);if(t==0||PositionGetString(POSITION_SYMBOL)!=_Symbol)continue;
      if(netting || (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic)return false;
   }
   for(int i=0;i<OrdersTotal();i++) {
      ulong t=OrderGetTicket(i);if(t==0||OrderGetString(ORDER_SYMBOL)!=_Symbol)continue;
      if(netting || (ulong)OrderGetInteger(ORDER_MAGIC)==InpMagic)return false;
   }
   return true;
}
bool InitializeState() {
   g_scope=Hash(AccountInfoString(ACCOUNT_SERVER)+"|"+StringFormat("%I64d",AccountInfoInteger(ACCOUNT_LOGIN))+"|"+_Symbol+"|"+StringFormat("%I64u",InpMagic));
   g_state_file="E2_CB_STATE_"+g_scope+".dat";
   g_instance_lock=FileOpen(g_state_file+".lock",FILE_READ|FILE_WRITE|FILE_BIN|StateFlags());
   if(g_instance_lock==INVALID_HANDLE){Print("[CB] Another EA owns this account/symbol/magic, or state storage is unavailable.");return false;}
   if(MQLInfoInteger(MQL_TESTER) && FileIsExist(g_state_file,StateFlags()))
      if(!FileDelete(g_state_file,StateFlags()))return false;
   int matches=0;
   for(int i=0;i<PositionsTotal();i++) {
      ulong t=PositionGetTicket(i);
      if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic)matches++;
   }
   if(matches>1){Print("[CB] Multiple matching compression positions; cannot recover independently.");return false;}
   if(FileIsExist(g_state_file,StateFlags())) {
      int h=FileOpen(g_state_file,FILE_READ|FILE_TXT|FILE_UNICODE|StateFlags());
      if(h==INVALID_HANDLE)return false;
      string payload=FileReadString(h),checksum=FileReadString(h);FileClose(h);
      NPCheckpoint c;ZeroMemory(c);
      if(checksum!=Hash(payload)||!NPDecode(payload,c)||c.scope!=g_scope){Print("[CB] Invalid recovery checkpoint. Preserve the file and reconcile the account.");return false;}
      if(c.config!=g_config&&(c.active||c.failed)){Print("[CB] Restore the saved inputs before recovering an active/stopped EA.");return false;}
      g_failed=c.failed;g_slots[0].last_exit_minute=c.last_exit;
      if(c.active) {
         ArrayResize(g_records,1);g_records[0]=c.record;
         g_slots[0].active=0;g_slots[0].pending=c.pending;
         if(c.record.status=="FINALIZED"){g_cash[0]=c.record.net;g_r[0]=c.record.net/c.record.risk_cash;}
         if(matches>0 && !c.pending && PositionFor(0,c.record.position)==0){Print("[CB] Position identity differs from saved state.");return false;}
         Print("[CB] Restored trade intent ",c.record.id,"; pending=",c.pending);
      } else if(matches>0){Print("[CB] Open compression position has no saved trade record.");return false;}
   } else if(matches>0){Print("[CB] Missing recovery state for open compression position. No trade is guessed.");return false;}
   if(g_slots[0].active<0) {
      for(int i=0;i<OrdersTotal();i++) {
         ulong t=OrderGetTicket(i);
         if(t>0&&OrderGetString(ORDER_SYMBOL)==_Symbol&&(ulong)OrderGetInteger(ORDER_MAGIC)==InpMagic){Print("[CB] Outstanding compression order has no saved intent.");return false;}
      }
   }
   return SaveState();
}

void FinalBar(const int s) {
   if(!g_slots[s].has_bar)return;
   double atr=0;
   bool signal=CBConsume(g_slots[s].indicators,g_slots[s].forming,PeriodMinutes(s),
      InpATRLength,InpChannelBars,InpCompressionBars,InpCompressionRatio,atr);
   g_slots[s].signal=signal;
   g_slots[s].signal_time=(datetime)(g_slots[s].forming.start+PeriodMinutes(s)*60);
   g_slots[s].signal_atr=atr;g_slots[s].has_bar=false;
}
void Minute(const MqlRates &r) {
   datetime utc=0;if(!Utc(r.time,utc))return;
   if(g_last_utc_minute>0 && utc<=g_last_utc_minute){Fail("Duplicate or backward UTC M1 history");return;}
   g_last_utc_minute=utc;
   for(int s=0;s<1;s++) {
      if(!Enabled(s))continue;
      int seconds=PeriodMinutes(s)*60;long bucket=((long)utc/seconds)*seconds;
      if(g_slots[s].has_bar && g_slots[s].forming.start!=bucket)FinalBar(s);
      if(!g_slots[s].has_bar) {
         g_slots[s].forming.start=bucket;g_slots[s].forming.open=r.open;
         g_slots[s].forming.high=r.high;g_slots[s].forming.low=r.low;
         g_slots[s].forming.close=r.close;g_slots[s].forming.minutes=1;g_slots[s].has_bar=true;
      } else {
         g_slots[s].forming.high=MathMax(g_slots[s].forming.high,r.high);
         g_slots[s].forming.low=MathMin(g_slots[s].forming.low,r.low);
         g_slots[s].forming.close=r.close;g_slots[s].forming.minutes++;
      }
   }
}
int WarmupMinutes() {return CBWarmupMinutes(InpATRLength,InpChannelBars,InpCompressionBars);}
bool Feed(const datetime server_now,const datetime utc_now) {
   datetime stop=server_now-server_now%60-1;
   MqlRates m[];ArraySetAsSeries(m,false);
   ResetLastError();
   int n=0;
   if(!g_seeded) {
      n=CopyRates(_Symbol,PERIOD_M1,stop,WarmupMinutes(),m);
      if(n<WarmupMinutes()) {
         if(utc_now-g_history_notice>=60){Audit(0,utc_now,"WARMUP_WAIT","Loading completed M1 history: "+IntegerToString(n)+"/"+IntegerToString(WarmupMinutes()));g_history_notice=utc_now;}
         return false;
      }
   } else {
      datetime start=g_last_server_minute+60;
      if(start<=stop)n=CopyRates(_Symbol,PERIOD_M1,start,stop,m);
      if(n<0)return false; // Retry without moving the cursor.
   }
   for(int i=0;i<n;i++) {
      if(m[i].time>stop){Fail("History includes an unfinished minute");return false;}
      Minute(m[i]);g_last_server_minute=m[i].time;
      if(g_failed)return false;
   }
   // Advance only to the last observed bar. Missing/unavailable history is retried.
   for(int i=0;i<1;i++)
      if(g_slots[i].has_bar && g_slots[i].forming.start+PeriodMinutes(i)*60<=(long)utc_now)FinalBar(i);
   if(!g_seeded){g_seeded=true;Audit(0,utc_now,"WARMUP_READY",IntegerToString(n)+" completed M1 bars");}
   if(!g_bootstrapped){g_slots[0].seen_signal=g_slots[0].signal_time;g_bootstrapped=true;return false;}
   return !g_failed;
}
// Resolve the session containing the entry, including overnight sessions.
// Never assume the broker remains tradable until the US cash close.
bool ExitDeadline(const datetime now,datetime &deadline) {
   datetime server=NPToServer(now,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds);
   MqlDateTime t;TimeToStruct(server,t);
   datetime midnight=NPDate(t.year,t.mon,t.day),end=0;
   for(int back=0;back<=1;back++) {
      datetime day=midnight-back*86400;MqlDateTime d;TimeToStruct(day,d);
      for(uint j=0;j<64;j++) {
         datetime from=0,to=0;
         if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)d.day_of_week,j,from,to))break;
         if(from==0&&to==0)continue;
         datetime start=day+from%86400,finish=NPSessionEnd(day,from,to);
         if(server>=start&&server<finish&&(end==0||finish<end))end=finish;
      }
   }
   if(end==0)return false;
   datetime end_utc;if(!Utc(end,end_utc))return false;
   deadline=NPEarlierExit(CBDeadline(now),end_utc,InpBrokerCloseBufferMinutes);
   return true;
}
void MarkOverdue(const int k,const datetime now) {
   if(!NPExitOverdue(now,g_records[k].deadline))return;
   if(StringFind(g_records[k].integrity,"EXIT_DEADLINE_MISSED")<0) {
      if(g_records[k].integrity!="")g_records[k].integrity+="|";
      g_records[k].integrity+="EXIT_DEADLINE_MISSED";
      Audit(g_records[k].slot,now,"EXIT_DEADLINE_MISSED",Stamp(g_records[k].deadline));
   }
   Fail("Exit deadline missed; this run is invalid");
}
bool ClosePosition(const int s,const ulong ticket,const string reason) {
   int i=g_slots[s].active;
   datetime now;if(!Utc(TimeCurrent(),now))return false;
   if(i>=0) {
      if(g_records[i].closing||!NPRetryClose(now,g_records[i].last_close_attempt))return false;
      g_records[i].last_close_attempt=now;g_records[i].closing=true;
      g_records[i].exit_reason=reason;
      SaveState();
   }
   g_trade.SetExpertMagicNumber(Magic(s));
   bool sent=g_trade.PositionClose(ticket);
   if(i>=0)g_records[i].closing=false;
   if(!sent || (g_trade.ResultRetcode()!=TRADE_RETCODE_DONE && g_trade.ResultRetcode()!=TRADE_RETCODE_DONE_PARTIAL))
      {Audit(s,now,"CLOSE_PENDING",g_trade.ResultRetcodeDescription());return false;}
   return true;
}
void Reconcile(const int s,const datetime now) {
   int k=g_slots[s].active;if(k<0)return;
   if(g_records[k].status=="FINALIZED"){if(SaveState() && ExportTrades()){g_slots[s].active=-1;SaveState();}return;}
   if(g_slots[s].pending) {
      ulong pending_ticket=PositionFor(s);
      if(pending_ticket>0 && now>=g_records[k].deadline){MarkOverdue(k,now);ClosePosition(s,pending_ticket,"SESSION_CLOSE");}
      if(!HistorySelect(g_records[k].requested-1,TimeCurrent()+1))return;
      ulong pid=0,order=g_records[k].order;double volume=0,weighted=0;
      datetime first=0;long first_msc=0;
      for(int i=0;i<HistoryDealsTotal();i++) {
         ulong d=HistoryDealGetTicket(i);
         if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol || (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=Magic(s) ||
            HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
         ulong o=(ulong)HistoryDealGetInteger(d,DEAL_ORDER);
         if(order>0 ? o!=order : HistoryDealGetString(d,DEAL_COMMENT)!=g_records[k].id)continue;
         ulong p=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
         if(pid!=0 && pid!=p){Fail("Ambiguous entry positions");return;}
         pid=p;order=o;double v=HistoryDealGetDouble(d,DEAL_VOLUME);
         volume+=v;weighted+=v*HistoryDealGetDouble(d,DEAL_PRICE);
         datetime when=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
         if(first==0||when<first){first=when;first_msc=HistoryDealGetInteger(d,DEAL_TIME_MSC);}
      }
      if(pid==0 || volume<=0) {
         datetime request_utc=0;Utc(g_records[k].requested,request_utc);
         if(now-request_utc>30)Fail("Entry not authoritatively confirmed; order is never resent");
         return;
      }
      if(OrderSelect(order)||!HistoryOrderSelect(order))return;
      long state=HistoryOrderGetInteger(order,ORDER_STATE);
      if(state!=ORDER_STATE_FILLED&&state!=ORDER_STATE_CANCELED&&state!=ORDER_STATE_EXPIRED&&state!=ORDER_STATE_REJECTED)return;
      double expected=HistoryOrderGetDouble(order,ORDER_VOLUME_INITIAL)-HistoryOrderGetDouble(order,ORDER_VOLUME_CURRENT);
      if(MathAbs(volume-expected)>1e-8)return;
      g_records[k].position=pid;g_records[k].order=order;g_records[k].volume=volume;
      g_records[k].fill=weighted/volume;Utc(first,g_records[k].entry);
      g_records[k].entry_msc=(long)g_records[k].entry*1000+first_msc%1000;
      int side=1;
      double sl=RoundPrice(g_records[k].fill-side*g_records[k].requested_distance);
      double tp=RoundPrice(g_records[k].fill+InpTargetR*g_records[k].requested_distance);
      ulong ticket=PositionFor(s,pid);
      if(ticket>0) {
         double tol=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*0.51;
         if(MathAbs(PositionGetDouble(POSITION_SL)-sl)>tol || MathAbs(PositionGetDouble(POSITION_TP)-tp)>tol) {
            g_trade.SetExpertMagicNumber(Magic(s));
            g_trade.PositionModify(ticket,sl,tp);
            if(!PositionSelectByTicket(ticket)||MathAbs(PositionGetDouble(POSITION_SL)-sl)>tol||
               MathAbs(PositionGetDouble(POSITION_TP)-tp)>tol) {
               g_records[k].integrity="PROTECTION_RECONCILIATION_FAILED";
               ClosePosition(s,ticket,"PROTECTION_FAILURE");Fail("Cannot verify actual-fill SL/TP");return;
            }
         }
         g_records[k].sl=sl;g_records[k].tp=tp;
      } else if(g_records[k].integrity=="")g_records[k].integrity="CLOSED_BEFORE_PROTECTION_CONFIRMATION";
      if(!CashRisk(s,volume,g_records[k].fill,g_records[k].sl,g_records[k].risk_cash)) {
         Fail("Cannot calculate actual initial cash risk");return;
      }
      g_slots[s].pending=false;g_records[k].status="OPEN";
      SaveState();
      Audit(s,now,"ENTRY_CONFIRMED",StringFormat("position=%I64u SL=%.5f TP=%.5f",pid,g_records[k].sl,g_records[k].tp));
   }
   ulong ticket=PositionFor(s,g_records[k].position);
   if(ticket>0) {
      if(PositionGetInteger(POSITION_TYPE)!=POSITION_TYPE_BUY){Fail("Unexpected position direction");return;}
      if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && HistorySelectByPosition(g_records[k].position)) {
         for(int j=0;j<HistoryDealsTotal();j++) {
            ulong d=HistoryDealGetTicket(j);
            if(HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN && (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=Magic(s)) {
               Fail("Foreign entry merged into the compression netting position; manual reconciliation required");return;
            }
         }
      }
      if(!PositionSelectByTicket(ticket))return;
      double tol=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*0.51;
      if(MathAbs(PositionGetDouble(POSITION_SL)-g_records[k].sl)>tol || MathAbs(PositionGetDouble(POSITION_TP)-g_records[k].tp)>tol) {
         g_trade.SetExpertMagicNumber(Magic(s));g_trade.PositionModify(ticket,g_records[k].sl,g_records[k].tp);
         if(!PositionSelectByTicket(ticket) || MathAbs(PositionGetDouble(POSITION_SL)-g_records[k].sl)>tol || MathAbs(PositionGetDouble(POSITION_TP)-g_records[k].tp)>tol) {
            g_records[k].integrity="PROTECTION_RECONCILIATION_FAILED";
            ClosePosition(s,ticket,"PROTECTION_FAILURE");Fail("Cannot restore saved SL/TP");return;
         }
      }
      MarkOverdue(k,now);
      if(now>=g_records[k].deadline)ClosePosition(s,ticket,"SESSION_CLOSE");
      return;
   }
   if(!HistorySelectByPosition(g_records[k].position))return;
   double vin=0,vout=0,net=0;datetime last=0;long last_msc=0;string reason=g_records[k].exit_reason;
   for(int j=0;j<HistoryDealsTotal();j++) {
      ulong d=HistoryDealGetTicket(j);long e=HistoryDealGetInteger(d,DEAL_ENTRY);
      net+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+
           HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);
      if(e==DEAL_ENTRY_IN)vin+=HistoryDealGetDouble(d,DEAL_VOLUME);
      if(e==DEAL_ENTRY_OUT||e==DEAL_ENTRY_OUT_BY) {
         vout+=HistoryDealGetDouble(d,DEAL_VOLUME);long ms=HistoryDealGetInteger(d,DEAL_TIME_MSC);
         if(ms>=last_msc) {
            last=(datetime)HistoryDealGetInteger(d,DEAL_TIME);last_msc=ms;
            long r=HistoryDealGetInteger(d,DEAL_REASON);
            if(r==DEAL_REASON_SL)reason="SL";else if(r==DEAL_REASON_TP)reason="TP";
         }
      }
      if(e==DEAL_ENTRY_INOUT){Fail("Netting reversal cannot represent independent strategies");return;}
   }
   if(vin<=0||MathAbs(vin-vout)>1e-8)return;
   Utc(last,g_records[k].exit);g_records[k].exit_msc=(long)g_records[k].exit*1000+last_msc%1000;
   MarkOverdue(k,g_records[k].exit);
   g_records[k].net=net;g_records[k].status="FINALIZED";g_records[k].exit_reason=reason;
   g_cash[s]+=net;g_r[s]+=net/g_records[k].risk_cash;
   g_slots[s].last_exit_minute=g_records[k].exit-g_records[k].exit%60;
   Audit(s,now,"EXIT",reason+" netR="+Number(net/g_records[k].risk_cash));
   if(!SaveState() || !ExportTrades())return; // Keep the record recoverable until its report is durable.
   g_slots[s].active=-1;
   SaveState();
}
bool DailyEntryAllowed(const int s,const datetime now) {
   if(!InpOneTradePerDay)return true;
   datetime wall=now;
   datetime start=wall-wall%86400;
   // Query broker history on every eligible entry: survives restarts and also
   // catches trades opened while this instance was detached. Partial fills
   // consume the same day's allowance; exits and rejected orders do not.
   if(!HistorySelect(NPToServer(start,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds)-1,TimeCurrent()+1)) {
      Audit(s,now,"SKIP","daily entry history unavailable");return false;
   }
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong d=HistoryDealGetTicket(i);
      if(d==0){Audit(s,now,"SKIP","daily entry history incomplete");return false;}
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol ||
         (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=Magic(s))continue;
      long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_IN && entry!=DEAL_ENTRY_INOUT)continue;
      datetime utc=0;
      if(!Utc((datetime)HistoryDealGetInteger(d,DEAL_TIME),utc)) {
         Audit(s,now,"SKIP","daily entry time ambiguous");return false;
      }
      if(NPDay(utc)==NPDay(wall)) {
         Audit(s,now,"SKIP","one trade per UTC day reached");return false;
      }
   }
   return true;
}
void Enter(const int s,const datetime now) {
   datetime when=g_slots[s].signal_time;
   if(when<=g_slots[s].seen_signal)return;
   g_slots[s].seen_signal=when;
   if(!Enabled(s)||!g_slots[s].signal||g_failed)return;
   if(now<when||now-when>InpMaxEntryDelaySeconds){Audit(s,now,"SKIP","late signal");return;}
   if(!CBEntryWindow(now))return;
   if(g_slots[s].active>=0 || PositionFor(s)>0){Audit(s,now,"SKIP","strategy already occupied");return;}
   if(now-now%60<=g_slots[s].last_exit_minute)return;
   if(!EntryOwnershipClear()){Audit(s,now,"SKIP","symbol has a conflicting position/order");return;}
   datetime deadline;
   if(!ExitDeadline(now,deadline)){Audit(s,now,"SKIP","broker session schedule unavailable");return;}
   if(now>=deadline){Audit(s,now,"SKIP","broker session exit cutoff reached");return;}
   if(!DailyEntryAllowed(s,now))return;
   MqlTick q;if(!SymbolInfoTick(_Symbol,q)||q.ask<=q.bid||q.bid<=0)return;
   double spread=q.ask-q.bid;
   if(spread>InpMaxSpreadPriceUnits){Audit(s,now,"SKIP","spread exceeds price-unit cap");return;}
   double distance=g_slots[s].signal_atr*InpStopATR;
   if(distance<=3*spread)return;
   int side=1;
   double entry=q.ask,sl=RoundPrice(entry-side*distance);
   double tp=RoundPrice(entry+InpTargetR*distance);
   double minimum=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if((q.bid-sl)<minimum || (tp-q.bid<minimum)) {
      Audit(s,now,"SKIP","broker stop-distance rule");return;
   }
   double unitrisk=0;if(!CashRisk(s,1,entry,sl,unitrisk))return;
   double cash=InpCashRisk;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double volume=MathFloor((cash/unitrisk)/step+1e-10)*step;
   volume=NormalizeDouble(MathMin(volume,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)),8);
   if(volume<vmin){Audit(s,now,"SKIP","risk below minimum lot");return;}
   MqlTradeRequest req={};MqlTradeResult result={};MqlTradeCheckResult check={};
   req.action=TRADE_ACTION_DEAL;req.symbol=_Symbol;req.magic=Magic(s);
   req.type=ORDER_TYPE_BUY;req.volume=volume;req.price=entry;req.sl=sl;req.tp=tp;
   req.deviation=(ulong)MathCeil(InpMaxDeviationPriceUnits/_Point);
   long flags=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((flags&SYMBOL_FILLING_FOK)!=0)req.type_filling=ORDER_FILLING_FOK;
   else if((flags&SYMBOL_FILLING_IOC)!=0)req.type_filling=ORDER_FILLING_IOC;
   else if(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE)!=SYMBOL_TRADE_EXECUTION_MARKET)req.type_filling=ORDER_FILLING_RETURN;
   else {Audit(s,now,"SKIP","unsupported filling policy");return;}
   int n=ArraySize(g_records);
   req.comment="CB1_"+IntegerToString((long)now)+"_"+IntegerToString(n);
   if(!OrderCheck(req,check)){Audit(s,now,"ORDER_CHECK_REJECTED",check.comment);return;}
   ArrayResize(g_records,n+1);ZeroMemory(g_records[n]);
   g_records[n].report_id=g_run+"_"+req.comment;
   g_records[n].id=req.comment;g_records[n].strategy=Strategy(s);g_records[n].slot=s;
   g_records[n].requested=TimeCurrent();g_records[n].status="UNCONFIRMED";
   g_records[n].sl=sl;g_records[n].tp=tp;g_records[n].requested_distance=distance;
   g_records[n].requested_risk=cash;g_records[n].deadline=deadline;
   Audit(s,now,"EXIT_DEADLINE",Stamp(deadline));
   g_slots[s].active=n;g_slots[s].pending=true; // Reserve before submission, never resend.
   if(!SaveState())return; // Durable intent BEFORE submission. Never resend on restart.
   bool ok=OrderSend(req,result);g_records[n].order=result.order;
   SaveState();
   if(!ok || (result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_PLACED &&
              result.retcode!=TRADE_RETCODE_DONE_PARTIAL)) {
      g_records[n].integrity="ORDER_SEND_UNCONFIRMED";Fail("OrderSend result "+IntegerToString((int)result.retcode));
   }
   Reconcile(s,now);
}
void Equity(const datetime now) {
   double cash[1],rr[1];int open[1];
   for(int s=0;s<1;s++) {
      cash[s]=g_cash[s];rr[s]=g_r[s];open[s]=0;
      int i=g_slots[s].active;ulong ticket=PositionFor(s);
      if(ticket>0 && i>=0 && g_records[i].risk_cash>0) {
         double floating=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
         // Include paid entry fees in marked equity; do not double-count position swap.
         if(HistorySelectByPosition(g_records[i].position))
            for(int j=0;j<HistoryDealsTotal();j++){
               ulong d=HistoryDealGetTicket(j);
               floating+=HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_FEE);
               long edge=HistoryDealGetInteger(d,DEAL_ENTRY);
               if(edge==DEAL_ENTRY_OUT||edge==DEAL_ENTRY_OUT_BY)
                  floating+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP);
            }
         cash[s]+=floating;rr[s]+=floating/g_records[i].risk_cash;open[s]=1;
      }
   }
   double total=cash[0];g_equity_peak=MathMax(g_equity_peak,total);
   g_equity_dd=MathMax(g_equity_dd,g_equity_peak-total);
   datetime minute=now-now%60;
   if(g_equity!=INVALID_HANDLE&&minute!=g_equity_minute) {
      g_equity_minute=minute;
      FileWrite(g_equity,g_run,Stamp(now),Number(rr[0]),Number(total),open[0],g_failed);
   }
}
bool ExportTrades() {
   if(!InpExportCsv)return true;
   int h=FileOpen(g_report_base+"_Trades_T.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(h==INVALID_HANDLE){Fail("Cannot export trade ledger");return false;}
   ResetLastError();
   FileWrite(h,"schema_version","trade_id","strategy","config_hash","symbol","direction",
      "fill_time","exit_time","net_profit","actual_initial_cash_risk","trade_status","run_id",
      "entry_msc","exit_msc","position_id","volume","fill_price","initial_sl","initial_tp","net_r","exit_reason","integrity_flags");
   for(int i=0;i<ArraySize(g_records);i++) {
      FileWrite(h,"E2_JOURNAL_V1",g_records[i].report_id,g_records[i].strategy,g_config,_Symbol,
         "LONG",Stamp(g_records[i].entry),Stamp(g_records[i].exit),
         g_records[i].status=="FINALIZED"?Number(g_records[i].net):"",
         g_records[i].risk_cash>0?Number(g_records[i].risk_cash):"",g_records[i].status,g_run,
         g_records[i].entry_msc,g_records[i].exit_msc,g_records[i].position,g_records[i].volume,
         g_records[i].fill,g_records[i].sl,g_records[i].tp,
         g_records[i].status=="FINALIZED"&&g_records[i].risk_cash>0?Number(g_records[i].net/g_records[i].risk_cash):"",
         g_records[i].exit_reason,g_records[i].integrity);
   }
   FileFlush(h);int error=GetLastError();FileClose(h);
   if(error!=0){Fail("Trade export write failed");return false;}
   return true;
}
int OnInit() {
   if(InpBrokerClock==NP_CLOCK_UNSET || InpBrokerWinterUtcOffsetSeconds<-50400 ||
      InpBrokerWinterUtcOffsetSeconds>50400 || InpBrokerWinterUtcOffsetSeconds%60!=0) {
      Print("[CB] Set the historical broker clock explicitly; see docs/COMPRESSION_TESTING.md.");return INIT_PARAMETERS_INCORRECT;
   }
   if(InpATRLength<1||InpChannelBars<2||InpChannelBars>500||
      InpCompressionBars<2||InpCompressionBars>1000||InpCompressionRatio<=0||InpCompressionRatio>=1||
      InpCashRisk<=0||InpStopATR<=0||InpTargetR<=0||
      InpBrokerCloseBufferMinutes<1||InpBrokerCloseBufferMinutes>120||InpMaxSpreadPriceUnits<=0||InpMaxDeviationPriceUnits<0||InpMaxEntryDelaySeconds<0||
      InpMagic==0||InpATRLength>1000)return INIT_PARAMETERS_INCORRECT;
   if(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)<=0||SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)<=0)return INIT_FAILED;
   datetime now;if(!Utc(TimeCurrent(),now))return INIT_FAILED;
   for(int s=0;s<1;s++){
      ZeroMemory(g_slots[s]);CBReset(g_slots[s].indicators);g_slots[s].active=-1;
      g_cash[s]=0;g_r[s]=0;
   }
   string canonical="CB_V1_M30_AUTO|"+IntegerToString((int)InpBrokerClock)+"|"+IntegerToString(InpBrokerWinterUtcOffsetSeconds)+"|"+IntegerToString(InpATRLength)+"|"+IntegerToString(InpChannelBars)+"|"+IntegerToString(InpCompressionBars)+"|"+Number(InpCompressionRatio)+"|"+Number(InpStopATR)+"|"+Number(InpTargetR)+"|"+Number(InpCashRisk)+"|"+Number(InpMaxSpreadPriceUnits)+"|"+Number(InpMaxDeviationPriceUnits)+"|"+IntegerToString(InpMaxEntryDelaySeconds)+"|"+IntegerToString(InpBrokerCloseBufferMinutes);
   canonical+="|one_trade_per_day="+IntegerToString(InpOneTradePerDay?1:0);
   g_config=Hash(canonical);
   g_run="CB_"+g_config+"_"+IntegerToString((long)TimeLocal())+"_"+StringFormat("%I64u",GetTickCount64())+"_"+StringFormat("%I64u",GetMicrosecondCount());
   if(InpExportCsv) {
      if(!E2ReportFolder("CompressionBreakout",g_report_folder))return INIT_FAILED;
      string base=g_report_folder+"\\"+E2ReportBase(_Symbol,g_run);
      bool available=false;
      for(int attempt=0;attempt<100;attempt++) {
         g_report_base=base+(attempt==0?"":"_"+IntegerToString(attempt));
         if(!FileIsExist(g_report_base+"_Trades_T.csv",FILE_COMMON) &&
            !FileIsExist(g_report_base+"_Signals_S.csv",FILE_COMMON) &&
            !FileIsExist(g_report_base+"_Equity_E.csv",FILE_COMMON) &&
            !FileIsExist(g_report_base+"_Settings.txt",FILE_COMMON)){available=true;break;}
      }
      if(!available){Print("[CB] Report filename namespace exhausted.");return INIT_FAILED;}
      g_signals=FileOpen(g_report_base+"_Signals_S.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
      g_equity=FileOpen(g_report_base+"_Equity_E.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
      if(g_signals==INVALID_HANDLE||g_equity==INVALID_HANDLE)return INIT_FAILED;
      FileWrite(g_signals,"schema_version","run_id","strategy","time_utc","event","detail");
      FileWrite(g_equity,"run_id","time_utc","equity_r","equity_cash","open_positions","run_failed");
      int h=FileOpen(g_report_base+"_Settings.txt",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
      if(h!=INVALID_HANDLE){FileWriteString(h,canonical+"\r\nsymbol="+_Symbol+"\r\nclock=UTC in reports\r\n");FileClose(h);}
   }
   g_trade.SetAsyncMode(false);g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints((ulong)MathCeil(InpMaxDeviationPriceUnits/_Point));
   if(!InitializeState())return INIT_FAILED;
   Reconcile(0,now);
   if(!g_failed)Feed(TimeCurrent(),now);
   if(!EventSetTimer(1)){Print("[CB] Cannot start exit timer.");return INIT_FAILED;}
   g_test_from=now;g_ready=true;
   Print("[CB] compression run ",g_run,". M1-derived UTC bars. Settings: ",canonical);
   return INIT_SUCCEEDED;
}
void OnTick() {
   if(!g_ready)return;
   datetime now;if(!Utc(TimeCurrent(),now))return;g_test_until=now;
   for(int s=0;s<1;s++)Reconcile(s,now);
   if(!g_failed && Feed(TimeCurrent(),now))for(int s=0;s<1;s++)Enter(s,now);
   SaveState();
   Equity(now);
}
void OnTimer() {
   if(!g_ready)return;
   datetime now;if(!Utc(TimeCurrent(),now))return;
   for(int s=0;s<1;s++)Reconcile(s,now);
   SaveState();
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res) {
   if(!g_ready)return;
   datetime now;if(!Utc(TimeCurrent(),now))return;
   for(int s=0;s<1;s++)Reconcile(s,now);
   SaveState();
}
double OnTester() {
   // End-of-test liquidation is explicitly marked; it is not a strategy exit.
   datetime now;if(!Utc(TimeCurrent(),now))return -1e100;
   for(int s=0;s<1;s++) {
      Reconcile(s,now);ulong ticket=PositionFor(s);
      if(ticket>0) {
         int i=g_slots[s].active;if(i>=0)g_records[i].integrity="END_OF_TEST_LIQUIDATION";
         ClosePosition(s,ticket,"END_OF_TEST");Reconcile(s,now);
      }
   }
   Equity(now);
   return g_failed?-1e100:g_r[0];
}
void OnDeinit(const int reason) {
   EventKillTimer();
   if(g_ready){
      datetime now;if(Utc(TimeCurrent(),now))for(int s=0;s<1;s++)Reconcile(s,now);
      ExportTrades();
      SaveState();
      Print("[CB] Closed net R=",g_r[0]," tick-observed cash DD=",g_equity_dd,
         " failed=",g_failed,". CSV: Common Files / ",g_report_folder);
   }
   if(g_signals!=INVALID_HANDLE){FileFlush(g_signals);FileClose(g_signals);}
   if(g_equity!=INVALID_HANDLE){FileFlush(g_equity);FileClose(g_equity);}
   if(g_instance_lock!=INVALID_HANDLE){FileClose(g_instance_lock);g_instance_lock=INVALID_HANDLE;}
}

#endif
