#ifndef RC_EXPORTS_MQH
#define RC_EXPORTS_MQH
#ifndef RC_REPORT_VERSION
#define RC_REPORT_VERSION "1.10"
#endif
// History is authoritative: aggregate every fill/partial exit by position ID.
struct RCReportTrade {
   ulong position;
   int direction;
   datetime opened,closed;
   long entry_msc,exit_msc;
   double volume,exited,entry_value,exit_value,sl,tp,risk;
   double profit,commission,swap,fee;
   bool risk_valid,unsupported;
   long reason;
};
// Capture account-currency risk at entry, not at test end with a different FX conversion.
struct RCEntryRisk {ulong deal;double cash;};
RCEntryRisk rc_entry_risks[];
void RCCaptureRisk(const ulong ticket) {
   if(ticket==0||!HistoryDealSelect(ticket))return;
   if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol||
      (ulong)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=InpMagic||
      HistoryDealGetInteger(ticket,DEAL_ENTRY)!=DEAL_ENTRY_IN)return;
   for(int i=0;i<ArraySize(rc_entry_risks);i++)if(rc_entry_risks[i].deal==ticket)return;
   long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
   if(type!=DEAL_TYPE_BUY&&type!=DEAL_TYPE_SELL)return;
   double loss=0,sl=HistoryDealGetDouble(ticket,DEAL_SL);
   if(sl<=0||!OrderCalcProfit(type==DEAL_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,
       HistoryDealGetDouble(ticket,DEAL_VOLUME),HistoryDealGetDouble(ticket,DEAL_PRICE),sl,loss)||loss>=0)return;
   RCEntryRisk item={};item.deal=ticket;item.cash=-loss;
   int n=ArraySize(rc_entry_risks);ArrayResize(rc_entry_risks,n+1);rc_entry_risks[n]=item;
}
double RCCapturedRisk(const ulong ticket) {
   for(int i=0;i<ArraySize(rc_entry_risks);i++)if(rc_entry_risks[i].deal==ticket)return rc_entry_risks[i].cash;
   return 0;
}
RCReportTrade rc_records[];
string rc_report_base="",rc_run="";
int rc_equity_file=INVALID_HANDLE;
datetime rc_export_last=0,rc_equity_last=0;
bool rc_export_dirty=true;
string RCNumber(const double value){return DoubleToString(value,8);}
string RCStamp(const datetime server) {
   if(server<=0)return "";
   datetime utc=0;
   if(!RCUtc(server,InpBrokerDST,InpBrokerWinterUTCMinutes,utc))return "";
   MqlDateTime d;TimeToStruct(utc,d);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",d.year,d.mon,d.day,d.hour,d.min,d.sec);
}
int RCRecordIndex(const ulong position) {
   for(int i=0;i<ArraySize(rc_records);i++)if(rc_records[i].position==position)return i;
   return -1;
}
bool RCExportTrades() {
   if(!InpExportCsv||rc_report_base=="")return true;
   if(!HistorySelect(0,TimeCurrent())){Print("CSV history unavailable: ",GetLastError());return false;}
   ArrayResize(rc_records,0);
   int total=HistoryDealsTotal();
   // First establish ownership from entry deals, not exit magic (manual closes can have magic 0).
   for(int i=0;i<total;i++) {
      ulong t=HistoryDealGetTicket(i);
      long type=HistoryDealGetInteger(t,DEAL_TYPE),entry=HistoryDealGetInteger(t,DEAL_ENTRY);
      if(HistoryDealGetString(t,DEAL_SYMBOL)!=_Symbol||(ulong)HistoryDealGetInteger(t,DEAL_MAGIC)!=InpMagic||
         (type!=DEAL_TYPE_BUY&&type!=DEAL_TYPE_SELL)||(entry!=DEAL_ENTRY_IN&&entry!=DEAL_ENTRY_INOUT))continue;
      ulong id=(ulong)HistoryDealGetInteger(t,DEAL_POSITION_ID);
      if(id==0||RCRecordIndex(id)>=0)continue;
      RCReportTrade row={};row.position=id;row.direction=type==DEAL_TYPE_BUY?1:-1;row.risk_valid=true;
      int n=ArraySize(rc_records);ArrayResize(rc_records,n+1);rc_records[n]=row;
   }
   for(int i=0;i<total;i++) {
      ulong t=HistoryDealGetTicket(i);
      int k=RCRecordIndex((ulong)HistoryDealGetInteger(t,DEAL_POSITION_ID));
      if(k<0)continue;
      RCReportTrade row=rc_records[k];
      long type=HistoryDealGetInteger(t,DEAL_TYPE),entry=HistoryDealGetInteger(t,DEAL_ENTRY);
      row.profit+=HistoryDealGetDouble(t,DEAL_PROFIT);
      row.commission+=HistoryDealGetDouble(t,DEAL_COMMISSION);
      row.swap+=HistoryDealGetDouble(t,DEAL_SWAP);
      row.fee+=HistoryDealGetDouble(t,DEAL_FEE);
      if(type==DEAL_TYPE_BUY||type==DEAL_TYPE_SELL) {
         double v=HistoryDealGetDouble(t,DEAL_VOLUME),price=HistoryDealGetDouble(t,DEAL_PRICE);
         datetime time=(datetime)HistoryDealGetInteger(t,DEAL_TIME);
         long msc=HistoryDealGetInteger(t,DEAL_TIME_MSC);
         if(entry==DEAL_ENTRY_IN) {
            if((ulong)HistoryDealGetInteger(t,DEAL_MAGIC)!=InpMagic||
               (type==DEAL_TYPE_BUY?1:-1)!=row.direction)row.unsupported=true;
            double sl=HistoryDealGetDouble(t,DEAL_SL),tp=HistoryDealGetDouble(t,DEAL_TP);
            if(row.opened==0||msc<row.entry_msc){row.opened=time;row.entry_msc=msc;row.sl=sl;row.tp=tp;}
            row.volume+=v;row.entry_value+=price*v;
            double risk=RCCapturedRisk(t);
            if(risk>0)row.risk+=risk;
            else row.risk_valid=false; // Old entries after restart have no authoritative conversion snapshot.
         } else if(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY) {
            row.exited+=v;row.exit_value+=price*v;
            if(msc>=row.exit_msc){row.closed=time;row.exit_msc=msc;row.reason=HistoryDealGetInteger(t,DEAL_REASON);}
         } else row.unsupported=true; // Reversals/merged positions cannot yield a clean strategy R.
      }
      rc_records[k]=row;
   }
   int h=FileOpen(rc_report_base+"_Trades_T.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(h==INVALID_HANDLE){Print("CSV trade file cannot open: ",GetLastError());return false;}
   ResetLastError();
   FileWrite(h,"schema_version","trade_id","strategy","config_hash","symbol","direction",
      "fill_time","exit_time","net_profit","actual_initial_cash_risk","trade_status","run_id",
      "entry_msc","exit_msc","position_id","volume","fill_price","initial_sl","initial_tp","net_r",
      "exit_reason","integrity_flags","exit_price","gross_profit","commission","swap","fee");
   for(int i=0;i<ArraySize(rc_records);i++) {
      RCReportTrade row=rc_records[i];
      bool closed=row.volume>0&&row.exited>=row.volume-0.00000001&&!row.unsupported;
      double net=row.profit+row.commission+row.swap+row.fee;
      bool valid=row.risk_valid&&row.risk>0&&!row.unsupported;
      string flags=row.unsupported?"MIXED_OR_REVERSED_POSITION":valid?"":"INITIAL_RISK_UNAVAILABLE";
      FileWrite(h,"E2_JOURNAL_V1",IntegerToString((long)row.position),RC_NAME,"",_Symbol,
         row.direction>0?"LONG":"SHORT",RCStamp(row.opened),closed?RCStamp(row.closed):"",
         closed?RCNumber(net):"",valid?RCNumber(row.risk):"",closed?"FINALIZED":row.unsupported?"INVALID":"OPEN",rc_run,
         row.entry_msc,closed?row.exit_msc:0,row.position,RCNumber(row.volume),
         row.volume>0?RCNumber(row.entry_value/row.volume):"",RCNumber(row.sl),RCNumber(row.tp),
         closed&&valid?RCNumber(net/row.risk):"",closed?IntegerToString(row.reason):"",flags,
         row.exited>0?RCNumber(row.exit_value/row.exited):"",RCNumber(row.profit),RCNumber(row.commission),
         RCNumber(row.swap),RCNumber(row.fee));
   }
   FileFlush(h);int error=GetLastError();FileClose(h);
   if(error!=0){Print("CSV trade write failed: ",error);return false;}
   rc_export_dirty=false;return true;
}
void RCExportEquity(const bool force=false) {
   if(rc_equity_file==INVALID_HANDLE)return;
   datetime now=TimeCurrent();
   if(!force&&rc_equity_last!=0&&now-rc_equity_last<60)return;
   ResetLastError();
   FileWrite(rc_equity_file,RCStamp(now),AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY),
      AccountInfoDouble(ACCOUNT_MARGIN_FREE),RC_NAME,_Symbol,InpMagic,rc_run);
   FileFlush(rc_equity_file);
   if(GetLastError()!=0)Print("CSV equity write failed: ",GetLastError());
   rc_equity_last=now;
}
void RCExportClose(){if(rc_equity_file!=INVALID_HANDLE){FileClose(rc_equity_file);rc_equity_file=INVALID_HANDLE;}}
void RCWriteStrategySettings(const int h);
bool RCExportSettings() {
   int h=FileOpen(rc_report_base+"_Settings.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(h==INVALID_HANDLE){Print("CSV settings file cannot open: ",GetLastError());return false;}
   ResetLastError();FileWrite(h,"setting","value");
   FileWrite(h,"strategy",RC_NAME);FileWrite(h,"symbol",_Symbol);FileWrite(h,"run_id",rc_run);
   FileWrite(h,"version",RC_REPORT_VERSION);
   FileWrite(h,"InpMagic",InpMagic);
   FileWrite(h,"InpRiskPercent",InpRiskPercent);
   FileWrite(h,"InpCashRisk",InpCashRisk);
   FileWrite(h,"InpMaxSpreadPoints",InpMaxSpreadPoints);
   FileWrite(h,"InpOneEntryPerDay",InpOneEntryPerDay);
   FileWrite(h,"InpBrokerClockVerified",InpBrokerClockVerified);
   FileWrite(h,"InpBrokerWinterUTCMinutes",InpBrokerWinterUTCMinutes);
   FileWrite(h,"InpBrokerDST",InpBrokerDST);
   FileWrite(h,"InpStopATR",InpStopATR);
   FileWrite(h,"InpTargetR",InpTargetR);
   FileWrite(h,"InpMaximumHoldingDays",InpMaximumHoldingDays);
   FileWrite(h,"InpFridayFlat",InpFridayFlat);
   FileWrite(h,"InpClosedDates",InpClosedDates);
   FileWrite(h,"InpEarlyCloseDates",InpEarlyCloseDates);
   FileWrite(h,"InpEarlyCloseMinute",InpEarlyCloseMinute);
   FileWrite(h,"InpSessionDST",InpSessionDST);
   FileWrite(h,"InpSessionWinterUTCMinutes",InpSessionWinterUTCMinutes);
   FileWrite(h,"InpSessionOpenMinute",InpSessionOpenMinute);
   FileWrite(h,"InpSessionCloseMinute",InpSessionCloseMinute);
   FileWrite(h,"InpDeviationPoints",InpDeviationPoints);
   FileWrite(h,"InpHistoryDays",InpHistoryDays);
   FileWrite(h,"InpMinimumMinuteCoverage",InpMinimumMinuteCoverage);
   FileWrite(h,"InpATRPeriod",InpATRPeriod);
   FileWrite(h,"InpFridayFlatUTCMinute",InpFridayFlatUTCMinute);
   FileWrite(h,"InpEntryGraceSeconds",InpEntryGraceSeconds);
   RCWriteStrategySettings(h);FileFlush(h);int error=GetLastError();FileClose(h);
   if(error!=0){Print("CSV settings write failed: ",error);return false;}return true;
}
bool RCExportInit() {
   if(!InpExportCsv)return true;
   RCExportClose();
   string mode=MQLInfoInteger(MQL_TESTER)?"Test":AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"Demo":"Live";
   string symbol=_Symbol;StringReplace(symbol,"/","_");StringReplace(symbol,"\\","_");StringReplace(symbol,":","_");
   string folder="E2\\ResearchCandidates\\"+IntegerToString((long)InpMagic)+"\\";
   // Monotonic microsecond token plus wall clock and collision check: no repeated-run overwrites.
   string token=IntegerToString((long)TimeLocal())+"_"+IntegerToString((long)GetMicrosecondCount());
   for(int i=0;i<1000;i++) {
      rc_run=token+"_"+IntegerToString(i);
      rc_report_base=folder+symbol+"_"+mode+"_"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+rc_run;
      if(!FileIsExist(rc_report_base+"_Trades_T.csv",FILE_COMMON)&&
         !FileIsExist(rc_report_base+"_Equity_E.csv",FILE_COMMON)&&
         !FileIsExist(rc_report_base+"_Settings.csv",FILE_COMMON))break;
      if(i==999){Print("CSV unique filename unavailable");rc_report_base="";return false;}
   }
   rc_equity_file=FileOpen(rc_report_base+"_Equity_E.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(rc_equity_file==INVALID_HANDLE){Print("CSV equity file cannot open: ",GetLastError());rc_report_base="";return false;}
   ResetLastError();
   FileWrite(rc_equity_file,"time_utc","balance","equity","free_margin","strategy","symbol","magic","run_id");
   FileFlush(rc_equity_file);
   if(GetLastError()!=0||!RCExportTrades()||!RCExportSettings()){RCExportClose();rc_report_base="";return false;}
   rc_equity_last=0;rc_export_last=0;RCExportEquity(true);
   Print("CSV reports: ",TerminalInfoString(TERMINAL_COMMONDATA_PATH),"\\Files\\",rc_report_base,"_Trades_T.csv");
   return true;
}
void RCExportTick() {
   if(!InpExportCsv||rc_report_base=="")return;
   RCExportEquity();
   if(rc_export_dirty&&(rc_export_last==0||TimeCurrent()-rc_export_last>=60)) {
      rc_export_last=TimeCurrent();RCExportTrades();
   }
}
#endif
