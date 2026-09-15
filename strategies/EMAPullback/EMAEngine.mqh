#ifndef EMA_RESEARCH_ENGINE_MQH
#define EMA_RESEARCH_ENGINE_MQH
#include <Trade/Trade.mqh>
#include "EMACore.mqh"
#include "SessionClock.mqh"
#include "..\\shared\\ReportFolders.mqh"

input group "Historical broker time"
input NPClockMode InpBrokerClock=NP_CLOCK_UNSET;
input int InpBrokerWinterUtcOffsetSeconds=0;
input datetime InpIndicatorSeedUtc=D'2022.01.01 00:00';
input group "Strategy settings"
input int InpATRLength=14;
input int InpEMAFast=20;
input int InpEMASlow=50;
input double InpEMAStopATR=3.0;
input double InpEMATargetR=0.5;
input group "Risk and identification"
input double InpEMACashRisk=1000.0;
input ulong InpEMAMagic=2026091402;
input group "Execution and reporting"
input int InpBrokerCloseBufferMinutes=5; // Exit before the active broker session ends
input double InpMaxSpreadPriceUnits=4.0;
input double InpMaxDeviationPriceUnits=0.5;
input int InpMaxEntryDelaySeconds=5;
input bool InpExportCsv=true;

struct NPRecord {
   string id,strategy,status,integrity,exit_reason;
   int slot;
   ulong order,position;
   datetime requested,entry,exit,deadline,last_close_attempt;
   bool closing;
   long entry_msc,exit_msc;
   double volume,fill,sl,tp,risk_cash,net,requested_distance,requested_risk;
};
struct NPSlot {
   NPState indicators;
   NPBar forming;
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
int g_session_day=0,g_session_count=0,g_signals=INVALID_HANDLE,g_equity=INVALID_HANDLE;
string g_run,g_config,g_report_folder,g_report_base;
bool g_ready=false,g_failed=false,g_seeded=false;
double g_cash[1],g_r[1];
double g_equity_peak=0,g_equity_dd=0;

bool Enabled(const int s) {return s==0;}
int PeriodMinutes(const int s) {return 30;}
ulong Magic(const int s) {return InpEMAMagic;}
string Strategy(const int s) {return "NP_EMA_M30_LONG";}
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
   if(!g_failed)Print("[NP][FAILED] ",why,". New entries stopped; existing positions still managed.");
   g_failed=true;
}
bool Utc(const datetime server,datetime &utc) {
   if(NPToUtc(server,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds,utc))return true;
   Fail("Uncovered or ambiguous broker timestamp");return false;
}
void Audit(const int slot,const datetime utc,const string event,const string detail) {
   Print("[NP][",Strategy(slot),"] ",event," ",detail);
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
void FinalBar(const int s) {
   if(!g_slots[s].has_bar)return;
   double atr=0;
   bool signal=NPConsume(g_slots[s].indicators,g_slots[s].forming,PeriodMinutes(s),
      InpATRLength,InpEMAFast,InpEMASlow,atr);
   g_slots[s].signal=signal;
   g_slots[s].signal_time=(datetime)(g_slots[s].forming.start+PeriodMinutes(s)*60);
   g_slots[s].signal_atr=atr;g_slots[s].has_bar=false;
}
void Minute(const MqlRates &r) {
   datetime utc=0;if(!Utc(r.time,utc))return;
   if(utc<InpIndicatorSeedUtc)return;
   if(g_last_utc_minute>0 && utc<=g_last_utc_minute){Fail("Duplicate or backward UTC M1 history");return;}
   g_last_utc_minute=utc;
   datetime wall=NPNy(utc);int day=NPDay(wall);
   if(day!=g_session_day){g_session_day=day;g_session_count=0;}
   MqlDateTime t;TimeToStruct(wall,t);int minute=t.hour*60+t.min,close=NPCloseMinute(utc);
   if(close>0 && minute>=570 && minute<close)g_session_count++;
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
bool Feed(const datetime server_now,const datetime utc_now) {
   datetime stop=server_now-server_now%60-1;
   datetime start=g_seeded?g_last_server_minute+60:NPToServer(InpIndicatorSeedUtc,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds);
   if(stop>=start) {
      MqlRates m[];ArraySetAsSeries(m,false);
      ResetLastError();int n=CopyRates(_Symbol,PERIOD_M1,start,stop,m);
      if(n<0) {
         // Never advance the cursor after an unsuccessful history read.
         Audit(0,utc_now,"M1_HISTORY_NOT_READY",IntegerToString(GetLastError()));
         return false;
      }
      if(n>0 && g_last_utc_minute==0) {
         datetime first_utc=0;if(!Utc(m[0].time,first_utc))return false;
         if(first_utc>InpIndicatorSeedUtc+7*86400) {
            Fail("M1 seed history is truncated; load history or explicitly choose a later seed");return false;
         }
         Audit(0,utc_now,"FIRST_M1_UTC",Stamp(first_utc));
      }
      for(int i=0;i<n;i++){
         Minute(m[i]);g_last_server_minute=m[i].time;
         if(g_failed)return false;
      }
      // Also move the read cursor through known empty ranges without inventing bars.
      if(n>=0) {
         g_last_server_minute=stop-stop%60;g_seeded=true;
      }
   }
   for(int s=0;s<1;s++)
      if(g_slots[s].has_bar && g_slots[s].forming.start+PeriodMinutes(s)*60<=(long)utc_now)FinalBar(s);
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
   deadline=NPEarlierExit(NPDeadline(now),end_utc,InpBrokerCloseBufferMinutes);
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
   if(g_slots[s].pending) {
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
      double tp=RoundPrice(g_records[k].fill+InpEMATargetR*g_records[k].requested_distance);
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
      Audit(s,now,"ENTRY_CONFIRMED",StringFormat("position=%I64u SL=%.5f TP=%.5f",pid,g_records[k].sl,g_records[k].tp));
   }
   ulong ticket=PositionFor(s,g_records[k].position);
   if(ticket>0) {
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
   g_slots[s].active=-1;
}
void Enter(const int s,const datetime now) {
   datetime when=g_slots[s].signal_time;
   if(when<=g_slots[s].seen_signal)return;
   g_slots[s].seen_signal=when;
   if(!Enabled(s)||!g_slots[s].signal||g_failed)return;
   if(now<when||now-when>InpMaxEntryDelaySeconds){Audit(s,now,"SKIP","late signal");return;}
   int close=NPCloseMinute(now);if(close<0){Fail("Calendar covers 2022-2026 only");return;}
   MqlDateTime nt;TimeToStruct(NPNy(now),nt);int minute=nt.hour*60+nt.min;
   if(close==0||minute<600||minute>=close-30)return;
   if(g_session_day!=NPDay(NPNy(now)) || g_session_count<0.95*(minute-570)) {
      Audit(s,now,"SKIP","incomplete observed cash-session M1 data");return;
   }
   if(g_slots[s].active>=0 || PositionFor(s)>0){Audit(s,now,"SKIP","strategy already occupied");return;}
   if(now-now%60<=g_slots[s].last_exit_minute)return;
   datetime deadline;
   if(!ExitDeadline(now,deadline)){Audit(s,now,"SKIP","broker session schedule unavailable");return;}
   if(now>=deadline){Audit(s,now,"SKIP","broker session exit cutoff reached");return;}
   MqlTick q;if(!SymbolInfoTick(_Symbol,q)||q.ask<=q.bid||q.bid<=0)return;
   double spread=q.ask-q.bid;
   if(spread>InpMaxSpreadPriceUnits){Audit(s,now,"SKIP","spread exceeds price-unit cap");return;}
   double distance=g_slots[s].signal_atr*InpEMAStopATR;
   if(distance<3*spread || (InpEMATargetR*distance<=2*spread))return;
   int side=1;
   double entry=q.ask,sl=RoundPrice(entry-side*distance);
   double tp=RoundPrice(entry+InpEMATargetR*distance);
   double minimum=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if((q.bid-sl)<minimum || (tp-q.bid<minimum)) {
      Audit(s,now,"SKIP","broker stop-distance rule");return;
   }
   double unitrisk=0;if(!CashRisk(s,1,entry,sl,unitrisk))return;
   double cash=InpEMACashRisk;
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
   req.comment="NP1_"+IntegerToString((long)now)+"_"+IntegerToString(n);
   if(!OrderCheck(req,check)){Audit(s,now,"ORDER_CHECK_REJECTED",check.comment);return;}
   ArrayResize(g_records,n+1);ZeroMemory(g_records[n]);
   g_records[n].id=req.comment;g_records[n].strategy=Strategy(s);g_records[n].slot=s;
   g_records[n].requested=TimeCurrent();g_records[n].status="UNCONFIRMED";
   g_records[n].sl=sl;g_records[n].tp=tp;g_records[n].requested_distance=distance;
   g_records[n].requested_risk=cash;g_records[n].deadline=deadline;
   Audit(s,now,"EXIT_DEADLINE",Stamp(deadline));
   g_slots[s].active=n;g_slots[s].pending=true; // Reserve before submission, never resend.
   bool ok=OrderSend(req,result);g_records[n].order=result.order;
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
void ExportTrades() {
   if(!InpExportCsv)return;
   int h=FileOpen(g_report_base+"_Trades_T.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(h==INVALID_HANDLE){Print("[NP] Cannot export trade ledger: ",GetLastError());return;}
   FileWrite(h,"schema_version","trade_id","strategy","config_hash","symbol","direction",
      "fill_time","exit_time","net_profit","actual_initial_cash_risk","trade_status","run_id",
      "entry_msc","exit_msc","position_id","volume","fill_price","initial_sl","initial_tp","net_r","exit_reason","integrity_flags");
   for(int i=0;i<ArraySize(g_records);i++) {
      FileWrite(h,"E2_JOURNAL_V1",g_run+"_"+g_records[i].id,g_records[i].strategy,g_config,_Symbol,
         "LONG",Stamp(g_records[i].entry),Stamp(g_records[i].exit),
         g_records[i].status=="FINALIZED"?Number(g_records[i].net):"",
         g_records[i].risk_cash>0?Number(g_records[i].risk_cash):"",g_records[i].status,g_run,
         g_records[i].entry_msc,g_records[i].exit_msc,g_records[i].position,g_records[i].volume,
         g_records[i].fill,g_records[i].sl,g_records[i].tp,
         g_records[i].status=="FINALIZED"&&g_records[i].risk_cash>0?Number(g_records[i].net/g_records[i].risk_cash):"",
         g_records[i].exit_reason,g_records[i].integrity);
   }
   FileFlush(h);FileClose(h);
}
int OnInit() {
   if(!MQLInfoInteger(MQL_TESTER)){Print("[NP] Strategy Tester only. Live and demo chart attachment refused.");return INIT_FAILED;}
   if(InpBrokerClock==NP_CLOCK_UNSET || InpBrokerWinterUtcOffsetSeconds<-50400 ||
      InpBrokerWinterUtcOffsetSeconds>50400 || InpBrokerWinterUtcOffsetSeconds%60!=0) {
      Print("[NP] Set the historical broker clock explicitly; see docs/EMA_TESTING.md.");return INIT_PARAMETERS_INCORRECT;
   }
   if(InpATRLength<1||InpEMAFast<1||InpEMASlow<=InpEMAFast||
      InpEMACashRisk<=0||InpEMAStopATR<=0||InpEMATargetR<=0||
      InpBrokerCloseBufferMinutes<1||InpBrokerCloseBufferMinutes>120||InpMaxSpreadPriceUnits<=0||InpMaxDeviationPriceUnits<0||InpMaxEntryDelaySeconds<0||
      InpEMAMagic==0||InpIndicatorSeedUtc<D'2022.01.01')return INIT_PARAMETERS_INCORRECT;
   if(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)<=0||SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)<=0)return INIT_FAILED;
   datetime now;if(!Utc(TimeCurrent(),now))return INIT_FAILED;
   MqlDateTime initial;TimeToStruct(now,initial);
   if(initial.year<2022||initial.year>2026){Print("[NP] Calendar supports 2022-2026.");return INIT_PARAMETERS_INCORRECT;}
   for(int s=0;s<1;s++){
      ZeroMemory(g_slots[s]);NPReset(g_slots[s].indicators);g_slots[s].active=-1;
      if(Enabled(s)&&PositionFor(s)>0){Print("[NP] Unexpected pre-existing research position.");return INIT_FAILED;}
      g_cash[s]=0;g_r[s]=0;
   }
   string canonical="EMA_V3|"+IntegerToString((int)InpBrokerClock)+"|"+IntegerToString(InpBrokerWinterUtcOffsetSeconds)+"|"+IntegerToString((long)InpIndicatorSeedUtc)+"|"+IntegerToString(InpATRLength)+"|"+IntegerToString(InpEMAFast)+"|"+IntegerToString(InpEMASlow)+"|"+Number(InpEMAStopATR)+"|"+Number(InpEMATargetR)+"|"+Number(InpEMACashRisk)+"|"+Number(InpMaxSpreadPriceUnits)+"|"+Number(InpMaxDeviationPriceUnits)+"|"+IntegerToString(InpMaxEntryDelaySeconds)+"|"+IntegerToString(InpBrokerCloseBufferMinutes);
   g_config=Hash(canonical);
   g_run="NP_"+g_config+"_"+IntegerToString((long)TimeLocal())+"_"+StringFormat("%I64u",GetTickCount64())+"_"+StringFormat("%I64u",GetMicrosecondCount());
   if(InpExportCsv) {
      if(!E2ReportFolder("EMAPullback",g_report_folder))return INIT_FAILED;
      string base=g_report_folder+"\\"+E2ReportBase(_Symbol,g_run);
      bool available=false;
      for(int attempt=0;attempt<100;attempt++) {
         g_report_base=base+(attempt==0?"":"_"+IntegerToString(attempt));
         if(!FileIsExist(g_report_base+"_Trades_T.csv",FILE_COMMON) &&
            !FileIsExist(g_report_base+"_Signals_S.csv",FILE_COMMON) &&
            !FileIsExist(g_report_base+"_Equity_E.csv",FILE_COMMON) &&
            !FileIsExist(g_report_base+"_Settings.txt",FILE_COMMON)){available=true;break;}
      }
      if(!available){Print("[NP] Report filename namespace exhausted.");return INIT_FAILED;}
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
   if(!Feed(TimeCurrent(),now) && g_failed)return INIT_FAILED;
   for(int s=0;s<1;s++)g_slots[s].seen_signal=g_slots[s].signal_time;
   if(!EventSetTimer(1)){Print("[NP] Cannot start exit timer.");return INIT_FAILED;}
   g_test_from=now;g_ready=true;
   Print("[NP] Research run ",g_run,". M1-derived UTC bars. Settings: ",canonical);
   return INIT_SUCCEEDED;
}
void OnTick() {
   if(!g_ready)return;
   datetime now;if(!Utc(TimeCurrent(),now))return;g_test_until=now;
   for(int s=0;s<1;s++)Reconcile(s,now);
   if(!g_failed && Feed(TimeCurrent(),now))for(int s=0;s<1;s++)Enter(s,now);
   Equity(now);
}
void OnTimer() {
   if(!g_ready)return;
   datetime now;if(!Utc(TimeCurrent(),now))return;
   for(int s=0;s<1;s++)Reconcile(s,now);
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res) {
   if(!g_ready)return;
   datetime now;if(!Utc(TimeCurrent(),now))return;
   for(int s=0;s<1;s++)Reconcile(s,now);
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
      Print("[NP] Closed net R=",g_r[0]," tick-observed cash DD=",g_equity_dd,
         " failed=",g_failed,". CSV: Common Files / ",g_report_folder);
   }
   if(g_signals!=INVALID_HANDLE){FileFlush(g_signals);FileClose(g_signals);}
   if(g_equity!=INVALID_HANDLE){FileFlush(g_equity);FileClose(g_equity);}
}

#endif
