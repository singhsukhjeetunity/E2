#ifndef E2_PORTFOLIO_JOURNAL_MQH
#define E2_PORTFOLIO_JOURNAL_MQH
#include "..\\shared\\ReportFolders.mqh"

// Reporting only. This module must never place/cancel orders or write guard globals.
input group "=== SHARED LIVE TRADE JOURNAL ==="
input bool InpLiveJournalEnabled=true;
input int InpJournalRefreshSeconds=60; // periodic reconciliation, including missed transactions
input ulong InpJournalGoldMagic=2026001;
input ulong InpJournalCompressionMagic=2026091703;
input ulong InpJournalGotobiMagic=420603;
input ulong InpJournalORBMagic=420605;
input ulong InpJournalBTCMagic=420609;

struct PGJRisk { ulong deal,position; double cash,sl,tp; };
struct PGJPending { ulong deal; datetime queued; };
struct PGJRow {
   ulong id,magic; string strategy,symbol; long direction,entry_ms,exit_ms,reason;
   double volume,exited,entry_value,exit_value,risk,sl,tp,gross,commission,swap,fee;
   bool bad,risk_ok;
};
PGJRisk pgj_risks[];
PGJPending pgj_pending[];
ulong pgj_previous[];
string pgj_base="";
int pgj_lock=INVALID_HANDLE;
bool pgj_active=false,pgj_dirty=true,pgj_risk_dirty=false;
datetime pgj_last_scan=0,pgj_last_attempt=0,pgj_last_warning=0;

void PGJWarn(const string message) {
   datetime now=TimeLocal();
   if(pgj_last_warning==0||now-pgj_last_warning>=60) {
      Print("[E2 PortfolioJournal] ",message,"; daily loss guard remains independent.");
      pgj_last_warning=now;
   }
}
string PGJName(const ulong magic) {
   if(magic==0)return "";
   if(magic==InpJournalGoldMagic)return "XAU_SESSION_FADE";
   if(magic==InpJournalCompressionMagic)return "CB_COMPRESSION_M30_LONG";
   if(magic==InpJournalGotobiMagic)return "EURJPY_GOTOBI";
   if(magic==InpJournalORBMagic)return "NQ_OPENING_RANGE";
   if(magic==InpJournalBTCMagic)return "BTC_MOMENTUM_PULLBACK";
   return "";
}
string PGJN(const double value) {return DoubleToString(value,8);}
string PGJStamp(const long ms) {
   if(ms<=0)return "";
   string s=TimeToString((datetime)(ms/1000),TIME_DATE|TIME_SECONDS);
   StringReplace(s,".","-");return s;
}
int PGJRiskIndex(const ulong deal) {
   for(int i=0;i<ArraySize(pgj_risks);i++)if(pgj_risks[i].deal==deal)return i;
   return -1;
}
// Entry callbacks only select one deal and capture cash risk; disk/history scans
// run on the timer AFTER PGRun. Old conversions are never reconstructed as live risk.
bool PGJCapture(const ulong deal) {
   if(!pgj_active||deal==0||PGJRiskIndex(deal)>=0)return true;
   if(!HistoryDealSelect(deal))return false;
   long type=HistoryDealGetInteger(deal,DEAL_TYPE);
   if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN||
      (type!=DEAL_TYPE_BUY&&type!=DEAL_TYPE_SELL)||
      PGJName((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC))=="")return true;
   datetime filled=(datetime)HistoryDealGetInteger(deal,DEAL_TIME),now=TimeCurrent();
   if(filled<=0||now<filled)return false;
   if(now-filled>15)return true;
   string symbol=HistoryDealGetString(deal,DEAL_SYMBOL);
   double price=HistoryDealGetDouble(deal,DEAL_PRICE),volume=HistoryDealGetDouble(deal,DEAL_VOLUME);
   double sl=HistoryDealGetDouble(deal,DEAL_SL),tp=HistoryDealGetDouble(deal,DEAL_TP),loss=0;
   if(price<=0||volume<=0||sl<=0||!MathIsValidNumber(sl)||
      !OrderCalcProfit(type==DEAL_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL,symbol,volume,price,sl,loss)||
      !MathIsValidNumber(loss)||loss>=0)return false;
   int n=ArraySize(pgj_risks);ArrayResize(pgj_risks,n+1);
   pgj_risks[n].deal=deal;pgj_risks[n].position=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   pgj_risks[n].cash=-loss;pgj_risks[n].sl=sl;pgj_risks[n].tp=tp;
   pgj_risk_dirty=true;
   return true;
}
bool PGJLoadRisks() {
   if(!FileIsExist(pgj_base+"_risk.dat",FILE_COMMON))return true;
   int f=FileOpen(pgj_base+"_risk.dat",FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(f==INVALID_HANDLE)return false;
   bool ok=FileReadString(f)=="E2_PG_RISK_V1"&&FileIsLineEnding(f);
   while(ok&&!FileIsEnding(f)) {
      string id=FileReadString(f);if(id==""&&FileIsEnding(f))break;
      PGJRisk item;
      item.deal=(ulong)StringToInteger(id);item.position=(ulong)StringToInteger(FileReadString(f));
      item.cash=StringToDouble(FileReadString(f));item.sl=StringToDouble(FileReadString(f));
      string tp=FileReadString(f);item.tp=StringToDouble(tp);
      ok=item.deal>0&&item.position>0&&MathIsValidNumber(item.cash)&&item.cash>0&&
         MathIsValidNumber(item.sl)&&item.sl>0&&MathIsValidNumber(item.tp)&&item.tp>=0&&
         tp!=""&&FileIsLineEnding(f)&&PGJRiskIndex(item.deal)<0;
      if(ok){int n=ArraySize(pgj_risks);ArrayResize(pgj_risks,n+1);pgj_risks[n]=item;}
   }
   FileClose(f);return ok;
}
bool PGJSaveRisks() {
   if(!pgj_risk_dirty)return true;
   string temp=pgj_base+"_risk.tmp";
   int f=FileOpen(temp,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(f==INVALID_HANDLE)return false;
   ResetLastError();bool ok=FileWrite(f,"E2_PG_RISK_V1")>0;
   for(int i=0;i<ArraySize(pgj_risks);i++)
      if(FileWrite(f,StringFormat("%I64u",pgj_risks[i].deal),StringFormat("%I64u",pgj_risks[i].position),
         PGJN(pgj_risks[i].cash),PGJN(pgj_risks[i].sl),PGJN(pgj_risks[i].tp))==0)ok=false;
   FileFlush(f);if(GetLastError()!=0)ok=false;FileClose(f);
   if(!ok||!FileMove(temp,FILE_COMMON,pgj_base+"_risk.dat",FILE_COMMON|FILE_REWRITE))return false;
   pgj_risk_dirty=false;return true;
}
// Remember IDs already published. Temporarily shortened broker history must not
// replace a previously complete journal with a truncated snapshot after restart.
bool PGJLoadPrevious() {
   if(!FileIsExist(pgj_base+"_Trades.csv",FILE_COMMON))return true;
   int f=FileOpen(pgj_base+"_Trades.csv",FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(f==INVALID_HANDLE)return false;
   int row=0;bool ok=true;
   while(!FileIsEnding(f)&&ok) {
      string fields[];
      do {
         string value=FileReadString(f);int n=ArraySize(fields);ArrayResize(fields,n+1);fields[n]=value;
      } while(!FileIsLineEnding(f)&&!FileIsEnding(f));
      if(ArraySize(fields)==1&&fields[0]==""&&FileIsEnding(f))break;
      if(ArraySize(fields)!=30){ok=false;break;}
      if(row==0)ok=fields[0]=="schema_version"&&fields[14]=="position_id";
      else {
         ulong id=(ulong)StringToInteger(fields[14]);
         ok=fields[0]=="E2_PORTFOLIO_JOURNAL_V1"&&id>0;
         if(ok){int n=ArraySize(pgj_previous);ArrayResize(pgj_previous,n+1);pgj_previous[n]=id;}
      }
      row++;
   }
   FileClose(f);return ok&&row>0;
}
int PGJFind(const ulong &ids[],const ulong id) {
   int lo=0,hi=ArraySize(ids)-1;
   while(lo<=hi){int mid=(lo+hi)/2;if(ids[mid]==id)return mid;if(ids[mid]<id)lo=mid+1;else hi=mid-1;}
   return -1;
}
bool PGJOpen(const ulong id) {
   for(int i=0;i<PositionsTotal();i++)if(PositionGetTicket(i)>0&&
      (ulong)PositionGetInteger(POSITION_IDENTIFIER)==id)return true;
   return false;
}
bool PGJBefore(const PGJRow &a,const PGJRow &b) {
   return a.exit_ms<b.exit_ms||(a.exit_ms==b.exit_ms&&a.id<b.id);
}
void PGJSort(const PGJRow &rows[],int &order[],const int left,const int right) {
   int i=left,j=right;PGJRow pivot=rows[order[(left+right)/2]];
   while(i<=j){while(PGJBefore(rows[order[i]],pivot))i++;while(PGJBefore(pivot,rows[order[j]]))j--;
      if(i<=j){int t=order[i];order[i]=order[j];order[j]=t;i++;j--;}}
   if(left<j)PGJSort(rows,order,left,j);if(i<right)PGJSort(rows,order,i,right);
}
bool PGJExport() {
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)||!HistorySelect(0,TimeCurrent()+1))return false;
   int total=HistoryDealsTotal();ulong deals[];ulong ids[];
   ArrayResize(deals,total);
   for(int i=0;i<total;i++) {
      ulong d=HistoryDealGetTicket(i);if(d==0)return false;deals[i]=d;
      long type=HistoryDealGetInteger(d,DEAL_TYPE),edge=HistoryDealGetInteger(d,DEAL_ENTRY);
      ulong id=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if(id>0&&(type==DEAL_TYPE_BUY||type==DEAL_TYPE_SELL)&&
         (edge==DEAL_ENTRY_IN||edge==DEAL_ENTRY_INOUT)&&
         PGJName((ulong)HistoryDealGetInteger(d,DEAL_MAGIC))!="") {
         int n=ArraySize(ids);ArrayResize(ids,n+1);ids[n]=id;
      }
   }
   ArraySort(ids);int unique=0;
   for(int i=0;i<ArraySize(ids);i++)if(i==0||ids[i]!=ids[i-1])ids[unique++]=ids[i];
   ArrayResize(ids,unique);
   PGJRow rows[];ArrayResize(rows,unique);
   for(int i=0;i<unique;i++){ZeroMemory(rows[i]);rows[i].id=ids[i];rows[i].direction=-1;rows[i].risk_ok=true;}
   for(int i=0;i<total;i++) {
      ulong d=deals[i];int k=PGJFind(ids,(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID));if(k<0)continue;
      PGJRow row=rows[k];long edge=HistoryDealGetInteger(d,DEAL_ENTRY),type=HistoryDealGetInteger(d,DEAL_TYPE);
      row.gross+=HistoryDealGetDouble(d,DEAL_PROFIT);row.commission+=HistoryDealGetDouble(d,DEAL_COMMISSION);
      row.swap+=HistoryDealGetDouble(d,DEAL_SWAP);row.fee+=HistoryDealGetDouble(d,DEAL_FEE);
      if(type==DEAL_TYPE_BUY||type==DEAL_TYPE_SELL) {
         double v=HistoryDealGetDouble(d,DEAL_VOLUME),price=HistoryDealGetDouble(d,DEAL_PRICE);
         long ms=HistoryDealGetInteger(d,DEAL_TIME_MSC);string symbol=HistoryDealGetString(d,DEAL_SYMBOL);
         if(edge==DEAL_ENTRY_IN||edge==DEAL_ENTRY_INOUT) {
            ulong magic=(ulong)HistoryDealGetInteger(d,DEAL_MAGIC);
            if(row.volume>0&&(row.magic!=magic||row.direction!=type||row.symbol!=symbol))row.bad=true;
            if(row.volume==0){row.magic=magic;row.strategy=PGJName(magic);row.symbol=symbol;row.direction=type;}
            row.volume+=v;row.entry_value+=v*price;
            if(row.entry_ms==0||ms<row.entry_ms){row.entry_ms=ms;row.sl=HistoryDealGetDouble(d,DEAL_SL);row.tp=HistoryDealGetDouble(d,DEAL_TP);}
            int risk=PGJRiskIndex(d);
            if(risk>=0&&pgj_risks[risk].position==row.id)row.risk+=pgj_risks[risk].cash;
            else row.risk_ok=false;
         }
         if(edge==DEAL_ENTRY_OUT||edge==DEAL_ENTRY_OUT_BY||edge==DEAL_ENTRY_INOUT) {
            row.exited+=v;row.exit_value+=v*price;
            if(ms>=row.exit_ms){row.exit_ms=ms;row.reason=HistoryDealGetInteger(d,DEAL_REASON);}
         }
         if(edge==DEAL_ENTRY_INOUT)row.bad=true;
      }
      rows[k]=row;
   }
   int order[];ulong published[];
   for(int i=0;i<unique;i++) {
      if(rows[i].volume<=0||rows[i].exit_ms<=0||PGJOpen(rows[i].id))continue;
      if(!rows[i].bad&&MathAbs(rows[i].volume-rows[i].exited)>1e-8)continue;
      int n=ArraySize(order);ArrayResize(order,n+1);order[n]=i;
      ArrayResize(published,n+1);published[n]=rows[i].id;
   }
   ArraySort(published);
   for(int i=0;i<ArraySize(pgj_previous);i++)if(PGJFind(published,pgj_previous[i])<0) {
      PGJWarn("History missing a previously published closed position; preserving CSV");return false;
   }
   if(ArraySize(order)>1)PGJSort(rows,order,0,ArraySize(order)-1);
   string temp=pgj_base+"_Trades.tmp";
   int f=FileOpen(temp,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(f==INVALID_HANDLE)return false;
   ResetLastError();
   bool ok=FileWrite(f,"schema_version","trade_id","strategy","symbol","direction","fill_time","exit_time",
      "net_profit","actual_initial_cash_risk","trade_status","account_login","account_server","entry_msc","exit_msc",
      "position_id","magic","volume","fill_price","exit_price","initial_sl","initial_tp","net_r","exit_reason",
      "integrity_flags","gross_profit","commission","swap","fee","time_basis","risk_basis")>0;
   for(int i=0;i<ArraySize(order);i++) {
      PGJRow row=rows[order[i]];double net=row.gross+row.commission+row.swap+row.fee;
      bool valid=row.risk_ok&&row.risk>0&&!row.bad;
      string flags=row.bad?"MIXED_OR_REVERSED_POSITION":(valid?"NONE":"INITIAL_RISK_UNAVAILABLE");
      string why=row.reason==DEAL_REASON_SL?"SL":(row.reason==DEAL_REASON_TP?"TP":
         (row.reason==DEAL_REASON_SO?"SO":(row.reason==DEAL_REASON_EXPERT?"EXPERT":"OTHER")));
      if(FileWrite(f,"E2_PORTFOLIO_JOURNAL_V1",AccountInfoString(ACCOUNT_SERVER)+"|"+
         StringFormat("%I64d",AccountInfoInteger(ACCOUNT_LOGIN))+"|"+StringFormat("%I64u",row.id),
         row.bad?"MIXED_E2_POSITION":row.strategy,row.symbol,row.bad?"MIXED":(row.direction==DEAL_TYPE_BUY?"LONG":"SHORT"),
         PGJStamp(row.entry_ms),PGJStamp(row.exit_ms),PGJN(net),valid?PGJN(row.risk):"",row.bad?"INVALID":"FINALIZED",
         StringFormat("%I64d",AccountInfoInteger(ACCOUNT_LOGIN)),AccountInfoString(ACCOUNT_SERVER),row.entry_ms,row.exit_ms,
         StringFormat("%I64u",row.id),StringFormat("%I64u",row.magic),PGJN(row.volume),PGJN(row.entry_value/row.volume),
         row.exited>0?PGJN(row.exit_value/row.exited):"",row.sl>0?PGJN(row.sl):"",row.tp>0?PGJN(row.tp):"",
         valid?PGJN(net/row.risk):"",why,flags,PGJN(row.gross),PGJN(row.commission),PGJN(row.swap),PGJN(row.fee),
         "BROKER_SERVER",valid?"LIVE_ENTRY_SNAPSHOT":"UNAVAILABLE")==0)ok=false;
   }
   FileFlush(f);if(GetLastError()!=0)ok=false;FileClose(f);
   if(!ok||!FileMove(temp,FILE_COMMON,pgj_base+"_Trades.csv",FILE_COMMON|FILE_REWRITE))return false;
   ArrayCopy(pgj_previous,published);return true;
}
void PGJInit() {
   if(!InpLiveJournalEnabled||MQLInfoInteger(MQL_TESTER)!=0)return;
   ulong magics[]={InpJournalGoldMagic,InpJournalCompressionMagic,InpJournalGotobiMagic,InpJournalORBMagic,InpJournalBTCMagic};
   bool valid=InpJournalRefreshSeconds>=5&&InpJournalRefreshSeconds<=3600;
   for(int i=0;i<ArraySize(magics);i++)for(int j=i+1;j<ArraySize(magics);j++)
      if(magics[i]>0&&magics[i]==magics[j])valid=false;
   if(!valid){PGJWarn("Invalid journal refresh/magic configuration; journal disabled");return;}
   string folder;if(!E2ReportFolder("Portfolio",folder)){PGJWarn("Journal folder unavailable");return;}
   pgj_base=folder+"\\E2_"+E2PathPart(AccountInfoString(ACCOUNT_SERVER))+"_"+
      StringFormat("%I64d",AccountInfoInteger(ACCOUNT_LOGIN));
   pgj_lock=FileOpen(pgj_base+".lock",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(pgj_lock==INVALID_HANDLE){PGJWarn("Journal writer already active or storage inaccessible");return;}
   if(!PGJLoadRisks()||!PGJLoadPrevious()) {
      PGJWarn("Unreadable/corrupt existing journal or risk cache; preserving files");FileClose(pgj_lock);pgj_lock=INVALID_HANDLE;return;
   }
   pgj_active=true;pgj_dirty=true;
   Print("[E2 PortfolioJournal] Shared live journal: Common\\Files\\",pgj_base,"_Trades.csv");
}
void PGJTimer() {
   if(!pgj_active)return;
   datetime now=TimeLocal();
   int pending=0;
   for(int i=0;i<ArraySize(pgj_pending);i++) {
      if(PGJCapture(pgj_pending[i].deal))continue;
      if(now-pgj_pending[i].queued<=15)pgj_pending[pending++]=pgj_pending[i];
      else PGJWarn("Entry risk snapshot unavailable; affected trade will have blank R");
   }
   ArrayResize(pgj_pending,pending);
   if(now-pgj_last_attempt<5)return;
   if(!pgj_dirty&&!pgj_risk_dirty&&now-pgj_last_scan<InpJournalRefreshSeconds)return;
   pgj_last_attempt=now;
   if(!PGJSaveRisks()||!PGJExport()){PGJWarn("Journal update failed; will retry");return;}
   pgj_dirty=false;pgj_last_scan=now;
}
void PGJTransaction(const MqlTradeTransaction &trans) {
   if(!pgj_active)return;
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD&&!PGJCapture(trans.deal)) {
      bool seen=false;
      for(int i=0;i<ArraySize(pgj_pending);i++)if(pgj_pending[i].deal==trans.deal){seen=true;break;}
      if(!seen&&ArraySize(pgj_pending)<1024) {
         int n=ArraySize(pgj_pending);ArrayResize(pgj_pending,n+1);
         pgj_pending[n].deal=trans.deal;pgj_pending[n].queued=TimeLocal();
      }
   }
   // Also refresh edits/deletions/corrections and fees attached after closing.
   pgj_dirty=true;
}
void PGJClose() {
   if(pgj_active&&!PGJSaveRisks())PGJWarn("Risk cache save failed during shutdown");
   if(pgj_lock!=INVALID_HANDLE){FileClose(pgj_lock);pgj_lock=INVALID_HANDLE;}
   pgj_active=false;
}
#endif
