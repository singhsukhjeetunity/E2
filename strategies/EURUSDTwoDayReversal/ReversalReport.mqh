#ifndef E2_REVERSAL_REPORT_MQH
#define E2_REVERSAL_REPORT_MQH
#include "..\\shared\\ReportFolders.mqh"

string g_reportBase="",g_reportRun="",g_reportHash="";
int g_equityFile=INVALID_HANDLE,g_signalFile=INVALID_HANDLE;
datetime g_equityMinute=0;
datetime g_reportStartTime=0;

string RStamp(const datetime time) {
   if(time<=0)return "";
   string value=TimeToString(time,TIME_DATE|TIME_SECONDS);
   StringReplace(value,".","-");return value;
}
string RNumber(const double value) {return DoubleToString(value,8);}
string RId(const ulong value) {return StringFormat("%I64u",value);}
uint RHash(const string value) {
   uint hash=2166136261;
   for(int i=0;i<StringLen(value);i++){hash^=(uint)StringGetCharacter(value,i);hash*=16777619;}
   return hash;
}
string RConfig() {
   return "EURUSD_2DAY_RESEARCH_V1|"+_Symbol+"|BROKER_D1|"+
      IntegerToString((int)InpUseMomentumFilter)+"|"+IntegerToString(InpMomentumSessions)+"|"+RNumber(InpMaxAbsMomentumPercent)+"|"+
      IntegerToString((int)InpUseEfficiencyFilter)+"|"+IntegerToString(InpEfficiencySessions)+"|"+RNumber(InpMaxEfficiencyRatio)+"|"+
      IntegerToString((int)InpSkipSundayDailyBars)+"|"+IntegerToString(InpATRSessionPeriod)+"|"+RNumber(InpStopATRMultiple)+"|"+
      RNumber(InpTargetR)+"|"+IntegerToString(InpMaxHoldingSessions)+"|"+IntegerToString((int)InpOneTradePerSession)+"|"+
      IntegerToString((int)InpRiskMode)+"|"+RNumber(InpFixedCashRisk)+"|"+RNumber(InpBalanceRiskPercent)+"|"+
      RNumber(InpMaxSpreadPips)+"|"+IntegerToString(InpDeviationBrokerPoints)+"|"+RNumber(InpMarginBuffer)+"|"+
      IntegerToString((int)InpBrokerClockVerified)+"|"+IntegerToString((int)InpBrokerClockMode)+"|"+
      IntegerToString(InpServerUTCOffsetWinterHours)+"|"+IntegerToString(InpServerUTCOffsetSummerHours)+"|"+RId(InpMagic);
}
void RSignal(const datetime time,const string event,const string detail) {
   if(g_signalFile==INVALID_HANDLE)return;
   FileWrite(g_signalFile,"E2_JOURNAL_V1",g_reportRun,"EURUSD_TWO_DAY_REVERSAL",RStamp(ServerToUTC(time)),event,detail);
   FileFlush(g_signalFile);
}
bool ROpenReports() {
   if(!InpExportCsv)return true;
   string folder;
   if(!E2ReportFolder("EURUSDTwoDayReversal",folder))return false;
   string config=RConfig();g_reportHash=StringFormat("%08X",RHash(config));
   string stamp=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
   StringReplace(stamp,".","");StringReplace(stamp,":","");StringReplace(stamp," ","-");
   g_reportRun=E2UniqueReportRun("2DR_"+stamp+"_"+g_reportHash);
   string base=folder+"\\"+E2ReportBase(_Symbol,g_reportRun);
   bool found=false;
   for(int n=0;n<1000;n++) {
      g_reportBase=base+(n==0?"":"_"+IntegerToString(n));
      if(!FileIsExist(g_reportBase+"_Trades_T.csv",FILE_COMMON)&&
         !FileIsExist(g_reportBase+"_Signals_S.csv",FILE_COMMON)&&
         !FileIsExist(g_reportBase+"_Equity_E.csv",FILE_COMMON)&&
         !FileIsExist(g_reportBase+"_Settings.txt",FILE_COMMON)){found=true;break;}
   }
   if(!found)return false;
   g_signalFile=FileOpen(g_reportBase+"_Signals_S.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   g_equityFile=FileOpen(g_reportBase+"_Equity_E.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   int settings=FileOpen(g_reportBase+"_Settings.txt",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(g_signalFile==INVALID_HANDLE||g_equityFile==INVALID_HANDLE||settings==INVALID_HANDLE) {
      if(settings!=INVALID_HANDLE)FileClose(settings);
      return false;
   }
   FileWrite(g_signalFile,"schema_version","run_id","strategy","time_utc","event","detail");
   FileWrite(g_equityFile,"run_id","time_utc","equity_r","equity_cash","open_positions","run_failed");
   FileWriteString(settings,"schema_version=E2_JOURNAL_V1\r\nrun_id="+g_reportRun+"\r\nconfig_hash="+g_reportHash+
      "\r\nmode="+(MQLInfoInteger(MQL_TESTER)?"TESTER":"LIVE")+"\r\nconfig="+config+
      "\r\nclock=UTC in CSV when profile resolves; D1 sessions remain broker-defined\r\nresearch_assumptions=all filter parameters and exits; not a reproduction of source performance\r\n");
   FileClose(settings);g_reportStartTime=TimeCurrent();
   RSignal(TimeCurrent(),"RUN_START","broker clock verified="+IntegerToString((int)InpBrokerClockVerified));
   return true;
}
void REquity(const datetime server) {
   if(g_equityFile==INVALID_HANDLE||server<=0)return;
   datetime minute=server-server%60;if(minute==g_equityMinute)return;g_equityMinute=minute;
   int open=0;double equity=0;
   for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic){open++;equity+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);}}
   // Discover this run's owned position IDs from entry deals. Exit deal magic
   // may belong to a manual close or PortfolioGuard, so never filter exits by magic.
   ulong owned[];
   bool history_ok=HistorySelect(0,server+1);
   if(history_ok) {
      for(int i=0;i<HistoryDealsTotal();i++) {
         ulong deal=HistoryDealGetTicket(i);
         if(deal==0||HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol||
            (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic)continue;
         long edge=HistoryDealGetInteger(deal,DEAL_ENTRY);
         if(edge!=DEAL_ENTRY_IN&&edge!=DEAL_ENTRY_INOUT)continue;
         ulong id=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
         bool recovered=false;
         for(int r=0;r<ArraySize(g_recoveredIds);r++)if(g_recoveredIds[r]==id){recovered=true;break;}
         if(!recovered&&(datetime)HistoryDealGetInteger(deal,DEAL_TIME)<g_reportStartTime)continue;
         int n=ArraySize(owned);ArrayResize(owned,n+1);owned[n]=id;
      }
      for(int i=0;i<HistoryDealsTotal();i++) {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0||HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol||
         (datetime)HistoryDealGetInteger(deal,DEAL_TIME)<g_reportStartTime)continue;
      ulong id=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      bool ours=false;
      for(int p=0;p<ArraySize(owned);p++)if(owned[p]==id){ours=true;break;}
      if(!ours)continue;
      equity+=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_COMMISSION)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_FEE);
      }
   }
   // R is blank because multiple fills can have different initial risks.
   FileWrite(g_equityFile,g_reportRun,RStamp(ServerToUTC(server)),"",RNumber(equity),open,history_ok?0:1);
   FileFlush(g_equityFile);
}
bool RPositionOpen(const ulong id) {
   for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==id)return true;}
   return false;
}
void RExportTrades() {
   if(!InpExportCsv||g_reportBase=="")return;
   // Preserve the last good CSV if the broker history is temporarily unavailable.
   if(!HistorySelect(0,TimeCurrent()+86400)){Print("[2DR] Trade history unavailable");return;}
   int file=FileOpen(g_reportBase+"_Trades_T.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(file==INVALID_HANDLE){Print("[2DR] Trade CSV open failed error=",GetLastError());return;}
   FileWrite(file,"schema_version","trade_id","strategy","config_hash","symbol","direction","fill_time","exit_time","net_profit","actual_initial_cash_risk","trade_status","run_id","entry_msc","exit_msc","position_id","volume","fill_price","initial_sl","initial_tp","net_r","exit_reason","integrity_flags","gross_profit","commission","swap","fee");
   ulong ids[];
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong deal=HistoryDealGetTicket(i);if(deal==0||HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol||(ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic)continue;
      long edge=HistoryDealGetInteger(deal,DEAL_ENTRY);if(edge!=DEAL_ENTRY_IN&&edge!=DEAL_ENTRY_INOUT)continue;
      bool recovered=false;
      ulong position=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      for(int r=0;r<ArraySize(g_recoveredIds);r++)if(g_recoveredIds[r]==position){recovered=true;break;}
      if(!recovered&&(datetime)HistoryDealGetInteger(deal,DEAL_TIME)<g_reportStartTime)continue;
      ulong id=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);bool seen=false;
      for(int j=0;j<ArraySize(ids);j++)if(ids[j]==id){seen=true;break;}
      if(!seen){int n=ArraySize(ids);ArrayResize(ids,n+1);ids[n]=id;}
   }
   for(int p=0;p<ArraySize(ids);p++) {
      ulong id=ids[p];double volume=0,weighted=0,risk=0,gross=0,commission=0,swap=0,fee=0,sl=0,tp=0;
      datetime entry=0,exit=0;long entryMs=0,exitMs=0,direction=-1;string reason="OTHER",flags="NONE";
      double exited=0;
      for(int j=0;j<HistoryDealsTotal();j++) {
         ulong deal=HistoryDealGetTicket(j);if(deal==0||(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID)!=id)continue;
         long edge=HistoryDealGetInteger(deal,DEAL_ENTRY),ms=HistoryDealGetInteger(deal,DEAL_TIME_MSC);
         double amount=HistoryDealGetDouble(deal,DEAL_VOLUME),price=HistoryDealGetDouble(deal,DEAL_PRICE);
         gross+=HistoryDealGetDouble(deal,DEAL_PROFIT);commission+=HistoryDealGetDouble(deal,DEAL_COMMISSION);
         swap+=HistoryDealGetDouble(deal,DEAL_SWAP);fee+=HistoryDealGetDouble(deal,DEAL_FEE);
         if(edge==DEAL_ENTRY_IN||edge==DEAL_ENTRY_INOUT) {
            if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic)flags="EXTERNAL_POSITION_ENTRY";
            direction=HistoryDealGetInteger(deal,DEAL_TYPE);volume+=amount;weighted+=amount*price;
            if(entryMs==0||ms<entryMs){entryMs=ms;entry=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);}
            ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
            double fillStop=HistoryOrderGetDouble(order,ORDER_SL),fillTp=HistoryOrderGetDouble(order,ORDER_TP);
            if(fillStop>0&&fillTp>0){sl=fillStop;tp=fillTp;double loss=0;
               ENUM_ORDER_TYPE side=(direction==DEAL_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
               if(OrderCalcProfit(side,_Symbol,amount,price,fillStop,loss)&&loss<0)risk-=loss;
               else flags="INITIAL_RISK_UNAVAILABLE";
            } else flags="INITIAL_STOP_UNAVAILABLE";
         }
         if(edge==DEAL_ENTRY_OUT||edge==DEAL_ENTRY_OUT_BY||edge==DEAL_ENTRY_INOUT) {
            exited+=amount;if(ms>=exitMs){exitMs=ms;exit=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
               ENUM_DEAL_REASON why=(ENUM_DEAL_REASON)HistoryDealGetInteger(deal,DEAL_REASON);
               reason=(why==DEAL_REASON_SL?"SL":(why==DEAL_REASON_TP?"TP":(why==DEAL_REASON_SO?"SO":(why==DEAL_REASON_EXPERT?"EXPERT":"OTHER"))));}
         }
      }
      bool finalized=(volume>0&&exited>=volume-1e-8&&!RPositionOpen(id));
      double net=gross+commission+swap+fee;
      string status=finalized?"FINALIZED":"OPEN";
      FileWrite(file,"E2_JOURNAL_V1","2DR|"+StringFormat("%I64d",AccountInfoInteger(ACCOUNT_LOGIN))+"|"+RId(id),
         "EURUSD_TWO_DAY_REVERSAL",g_reportHash,_Symbol,direction==DEAL_TYPE_BUY?"LONG":"SHORT",
         RStamp(ServerToUTC(entry)),finalized?RStamp(ServerToUTC(exit)):"",finalized?RNumber(net):"",
         risk>0&&flags=="NONE"?RNumber(risk):"",status,g_reportRun,entryMs,finalized?exitMs:0,RId(id),
         RNumber(volume),volume>0?RNumber(weighted/volume):"",sl>0?RNumber(sl):"",tp>0?RNumber(tp):"",
         finalized&&risk>0&&flags=="NONE"?RNumber(net/risk):"",finalized?reason:"",flags,
         finalized?RNumber(gross):"",finalized?RNumber(commission):"",finalized?RNumber(swap):"",finalized?RNumber(fee):"");
   }
   FileFlush(file);FileClose(file);
}
void RCloseReports() {
   if(!InpExportCsv)return;
   REquity(TimeCurrent());RExportTrades();
   if(g_signalFile!=INVALID_HANDLE){FileClose(g_signalFile);g_signalFile=INVALID_HANDLE;}
   if(g_equityFile!=INVALID_HANDLE){FileClose(g_equityFile);g_equityFile=INVALID_HANDLE;}
}
#endif
