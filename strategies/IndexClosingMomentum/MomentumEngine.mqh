#ifndef E2_INDEX_MOMENTUM_ENGINE_MQH
#define E2_INDEX_MOMENTUM_ENGINE_MQH
#include <Trade/Trade.mqh>
#include "MomentumCore.mqh"
#include "MomentumClock.mqh"
#include "..\\shared\\ReportFolders.mqh"

enum MFExperimentMode { MF_SIGNAL_1R=0, MF_RANDOM_DIRECTION_1R=1, MF_ALWAYS_LONG_1R=2, MF_SIGNAL_HOLD_CLOSE=3 };
enum MFRiskMode { MF_RISK_EQUITY_PERCENT=0, MF_RISK_FIXED_CASH=1 };

input group "Historical broker time"
input NPClockMode InpBrokerClock=NP_CLOCK_UNSET;
input int InpBrokerWinterUtcOffsetSeconds=0;
input group "Research parameters"
input int InpLookbackSessions=20;
input bool InpUseVolatilityFilter=false;
input double InpStopWindowFraction=0.75;
input MFExperimentMode InpExperiment=MF_SIGNAL_1R;
input ulong InpRandomSeed=20261002;
input group "Risk and execution"
input MFRiskMode InpRiskMode=MF_RISK_EQUITY_PERCENT;
input double InpRiskPercent=0.50;
input double InpFixedCashRisk=500.0;
input double InpMaxSpreadPriceUnits=10.0;
input double InpMaxDeviationPriceUnits=1.0;
input int InpEntryWindowSeconds=10;
input ulong InpMagic=2026100202;
input group "Reporting"
input bool InpExportCsv=true;

struct MFTradeRecord {
   string id,status,exit_reason,integrity;
   int day,side;
   ulong position;
   datetime entry,exit;
   long entry_msc,exit_msc;
   double volume,fill,sl,tp,risk_cash,gross,costs,net;
};

CTrade g_mf_trade;
MFTradeRecord g_mf_records[];
int g_mf_processed_day=0,g_mf_signals=INVALID_HANDLE;
bool g_mf_ready=false;
datetime g_mf_last_close_attempt=0;
string g_mf_run,g_mf_config,g_mf_report_folder,g_mf_report_base;

string MFStamp(const datetime t){if(t==0)return "";string x=TimeToString(t,TIME_DATE|TIME_SECONDS);StringReplace(x,".","-");return x;}
string MFNumber(const double n){return DoubleToString(n,10);}
string MFHash(const string value){uint h=2166136261;for(int i=0;i<StringLen(value);i++){h^=(uint)StringGetCharacter(value,i);h*=16777619;}return StringFormat("%08X",h);}
bool MFUtc(const datetime server,datetime &utc){return NPToUtc(server,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds,utc);}
double MFRoundPrice(const double value){double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);return NormalizeDouble(MathRound(value/tick)*tick,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));}

void MFLog(const datetime utc,const string event,const string detail) {
   Print("[MF] ",event," ",detail);
   if(g_mf_signals!=INVALID_HANDLE){FileWrite(g_mf_signals,"MF_SIGNAL_V1",g_mf_run,"INDEX_CLOSING_MOMENTUM",MFStamp(utc),event,detail);FileFlush(g_mf_signals);}
}
bool MFHasOwnPosition(ulong &ticket) {
   ticket=0;for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic){ticket=t;return true;}}return false;
}
bool MFSymbolFree() {
   for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol)return false;}
   for(int i=0;i<OrdersTotal();i++){ulong t=OrderGetTicket(i);if(t>0&&OrderGetString(ORDER_SYMBOL)==_Symbol)return false;}return true;
}
bool MFSessionBar(const int day,MFSession &out) {
   datetime probe=MFNyBoundaryUtc(day,12,0);int close_minute=NPCloseMinute(probe);if(close_minute<=600)return false;
   MqlRates rates[];ArraySetAsSeries(rates,false);
   int n=CopyRates(_Symbol,PERIOD_M1,
      NPToServer(MFNyBoundaryUtc(day,9,30),InpBrokerClock,InpBrokerWinterUtcOffsetSeconds),
      NPToServer(MFNyBoundaryUtc(day,close_minute/60,close_minute%60)-1,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds),rates);
   if(n<close_minute-570-5)return false;
   bool ten=false,last=false;double ten_price=0,closing_open=0,cash_close=0;
   for(int i=0;i<n;i++) {
      datetime utc=0;if(!MFUtc(rates[i].time,utc))return false;MqlDateTime t;TimeToStruct(NPNy(utc),t);
      int d=t.year*10000+t.mon*100+t.day,minute=t.hour*60+t.min;if(d!=day)continue;
      if(minute==599){ten_price=rates[i].close;ten=true;}
      if(minute==930&&close_minute==960)closing_open=rates[i].open;
      if(minute==close_minute-1){cash_close=rates[i].close;last=true;}
   }
   if(!ten||!last)return false;
   out.day=day;out.ten_price=ten_price;out.closing_open=closing_open;out.cash_close=cash_close;return true;
}
bool MFHistoryStats(const int today,double &prior_close,double &median_first,double &average_close_move) {
   MFSession reverse[];ArrayResize(reverse,0);int cursor=today,target=InpLookbackSessions+10;
   for(int scan=0;scan<500&&ArraySize(reverse)<target;scan++){
      cursor=MFPreviousCalendarDay(cursor);MFSession s;if(MFSessionBar(cursor,s)){int n=ArraySize(reverse);ArrayResize(reverse,n+1);reverse[n]=s;}
   }
   if(ArraySize(reverse)<InpLookbackSessions+1)return false;prior_close=reverse[0].cash_close;
   double returns[];ArrayResize(returns,InpLookbackSessions);average_close_move=0;
   int return_observations=0,closing_observations=0;
   for(int i=0;i<ArraySize(reverse)-1;i++){
      if(return_observations<InpLookbackSessions)
         returns[return_observations++]=MathAbs(reverse[i].ten_price/reverse[i+1].cash_close-1.0);
      if(closing_observations<InpLookbackSessions&&reverse[i].closing_open>0) {
         average_close_move+=MathAbs(reverse[i].cash_close-reverse[i].closing_open);closing_observations++;
      }
      if(return_observations>=InpLookbackSessions&&closing_observations>=InpLookbackSessions)break;
   }
   if(return_observations<InpLookbackSessions||closing_observations<InpLookbackSessions)return false;
   median_first=MFMedian(returns,InpLookbackSessions);average_close_move/=InpLookbackSessions;
   return prior_close>0&&average_close_move>0;
}
bool MFCurrentTenPrice(const int day,double &price) {
   MqlRates rates[];ArraySetAsSeries(rates,false);
   int n=CopyRates(_Symbol,PERIOD_M1,
      NPToServer(MFNyBoundaryUtc(day,9,59),InpBrokerClock,InpBrokerWinterUtcOffsetSeconds),
      NPToServer(MFNyBoundaryUtc(day,10,0)-1,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds),rates);
   for(int i=0;i<n;i++){datetime utc=0;if(!MFUtc(rates[i].time,utc))return false;MqlDateTime t;TimeToStruct(NPNy(utc),t);if(t.year*10000+t.mon*100+t.day==day&&t.hour==9&&t.min==59){price=rates[i].close;return true;}}
   return false;
}
bool MFTradedToday(const int day) {
   datetime start=MFNyBoundaryUtc(day,0,0),finish=MFNyBoundaryUtc(day,23,59)+60;
   if(!HistorySelect(NPToServer(start,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds),NPToServer(finish,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds)))return true;
   for(int i=0;i<HistoryDealsTotal();i++){ulong d=HistoryDealGetTicket(i);if(HistoryDealGetString(d,DEAL_SYMBOL)==_Symbol&&(ulong)HistoryDealGetInteger(d,DEAL_MAGIC)==InpMagic&&HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN)return true;}return false;
}
bool MFUnitRisk(const int side,const double entry,const double stop,double &cash) {
   double profit=0;if(!OrderCalcProfit(side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,1.0,entry,stop,profit))return false;
   cash=MathAbs(profit);return cash>0&&MathIsValidNumber(cash);
}
double MFVolume(const int side,const double entry,const double stop) {
   double unit=0;if(!MFUnitRisk(side,entry,stop,unit))return 0;
   double budget=MFRequestedCashRisk(AccountInfoDouble(ACCOUNT_EQUITY),InpRiskPercent,InpFixedCashRisk,InpRiskMode==MF_RISK_FIXED_CASH);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);if(budget<=0||step<=0)return 0;
   double volume=MathFloor((budget/unit)/step+1e-10)*step;volume=MathMin(volume,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX));
   if(volume<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN))return 0;return NormalizeDouble(volume,8);
}
bool MFProtectionMatches(const ulong ticket,const double sl,const double tp) {
   if(!PositionSelectByTicket(ticket))return false;double tol=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*0.51;
   return MathAbs(PositionGetDouble(POSITION_SL)-sl)<=tol&&MathAbs(PositionGetDouble(POSITION_TP)-tp)<=tol;
}

bool MFExportTrades() {
   if(!InpExportCsv)return true;
   int h=FileOpen(g_mf_report_base+"_Trades_T.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);if(h==INVALID_HANDLE)return false;
   FileWrite(h,"schema_version","trade_id","strategy","config_hash","symbol","direction","fill_time","exit_time","net_profit","actual_initial_cash_risk","trade_status","run_id","entry_msc","exit_msc","position_id","volume","fill_price","initial_sl","initial_tp","net_r","exit_reason","integrity_flags");
   for(int i=0;i<ArraySize(g_mf_records);i++){MFTradeRecord r=g_mf_records[i];FileWrite(h,"E2_JOURNAL_V1",r.id,"INDEX_CLOSING_MOMENTUM",g_mf_config,_Symbol,r.side>0?"LONG":"SHORT",MFStamp(r.entry),MFStamp(r.exit),r.status=="FINALIZED"?MFNumber(r.net):"",r.risk_cash>0?MFNumber(r.risk_cash):"",r.status,g_mf_run,r.entry_msc,r.exit_msc,r.position,r.volume,r.fill,r.sl,r.tp,r.status=="FINALIZED"&&r.risk_cash>0?MFNumber(r.net/r.risk_cash):"",r.exit_reason,r.integrity);}
   FileFlush(h);int error=GetLastError();FileClose(h);if(error!=0)return false;
   h=FileOpen(g_mf_report_base+"_Research_R.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);if(h==INVALID_HANDLE)return false;
   FileWrite(h,"run_id","trade_id","status","gross_profit","trading_costs","net_profit","gross_r","net_r");
   for(int i=0;i<ArraySize(g_mf_records);i++){MFTradeRecord r=g_mf_records[i];FileWrite(h,g_mf_run,r.id,r.status,r.status=="FINALIZED"?MFNumber(r.gross):"",r.status=="FINALIZED"?MFNumber(r.costs):"",r.status=="FINALIZED"?MFNumber(r.net):"",r.status=="FINALIZED"&&r.risk_cash>0?MFNumber(r.gross/r.risk_cash):"",r.status=="FINALIZED"&&r.risk_cash>0?MFNumber(r.net/r.risk_cash):"");}
   FileFlush(h);error=GetLastError();FileClose(h);return error==0;
}
void MFRefreshTrades() {
   bool changed=false;
   for(int i=0;i<ArraySize(g_mf_records);i++){
      if(g_mf_records[i].status=="FINALIZED"||g_mf_records[i].position==0||!HistorySelectByPosition(g_mf_records[i].position))continue;
      double vin=0,vout=0,gross=0,costs=0;datetime last=0;long last_msc=0;string reason=g_mf_records[i].exit_reason;
      for(int j=0;j<HistoryDealsTotal();j++){ulong d=HistoryDealGetTicket(j);long edge=HistoryDealGetInteger(d,DEAL_ENTRY);double v=HistoryDealGetDouble(d,DEAL_VOLUME);gross+=HistoryDealGetDouble(d,DEAL_PROFIT);costs+=HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);if(edge==DEAL_ENTRY_IN)vin+=v;if(edge==DEAL_ENTRY_OUT||edge==DEAL_ENTRY_OUT_BY){vout+=v;long ms=HistoryDealGetInteger(d,DEAL_TIME_MSC);if(ms>=last_msc){last_msc=ms;last=(datetime)HistoryDealGetInteger(d,DEAL_TIME);long why=HistoryDealGetInteger(d,DEAL_REASON);if(why==DEAL_REASON_SL)reason="SL";else if(why==DEAL_REASON_TP)reason="TP";else if(reason=="")reason=why==DEAL_REASON_EXPERT?"SESSION_CLOSE":"OTHER";}}}
      if(vin<=0||vout+1e-8<vin)continue;datetime exit_utc=0;if(!MFUtc(last,exit_utc))continue;
      g_mf_records[i].exit=exit_utc;g_mf_records[i].exit_msc=(long)exit_utc*1000+last_msc%1000;g_mf_records[i].gross=gross;g_mf_records[i].costs=costs;g_mf_records[i].net=gross+costs;g_mf_records[i].exit_reason=reason;g_mf_records[i].status="FINALIZED";changed=true;
      MFLog(exit_utc,"EXIT",g_mf_records[i].id+" reason="+reason+" grossR="+MFNumber(gross/g_mf_records[i].risk_cash)+" netR="+MFNumber((gross+costs)/g_mf_records[i].risk_cash));
   }
   if(changed)MFExportTrades();
}

void MFCloseAtCashClose(const datetime now) {
   ulong ticket=0;if(!MFHasOwnPosition(ticket))return;MqlDateTime t;TimeToStruct(NPNy(now),t);int minute=t.hour*60+t.min;
   datetime opened_server=(datetime)PositionGetInteger(POSITION_TIME),opened_utc=0;if(!MFUtc(opened_server,opened_utc))return;MqlDateTime e;TimeToStruct(NPNy(opened_utc),e);
   int today=t.year*10000+t.mon*100+t.day,entry_day=e.year*10000+e.mon*100+e.day;if(entry_day==today&&minute<960)return;
   if(g_mf_last_close_attempt>0&&now-g_mf_last_close_attempt<5)return;ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   for(int i=0;i<ArraySize(g_mf_records);i++)if(g_mf_records[i].position==pid&&g_mf_records[i].status!="FINALIZED")g_mf_records[i].exit_reason="SESSION_CLOSE";
   g_mf_last_close_attempt=now;g_mf_trade.SetExpertMagicNumber(InpMagic);if(!g_mf_trade.PositionClose(ticket))MFLog(now,"CLOSE_RETRY",g_mf_trade.ResultRetcodeDescription());
}

void MFTryEntry(const datetime now) {
   MqlDateTime t;TimeToStruct(NPNy(now),t);int day=t.year*10000+t.mon*100+t.day,second=t.hour*3600+t.min*60+t.sec;
   if(second<15*3600+30*60||second>15*3600+30*60+InpEntryWindowSeconds||g_mf_processed_day==day)return;g_mf_processed_day=day;
   if(NPCloseMinute(now)!=960){MFLog(now,"SKIP","not a full cash session day="+IntegerToString(day));return;}
   if(MFTradedToday(day)||!MFSymbolFree()){MFLog(now,"SKIP","daily limit or occupied symbol");return;}
   double prior_close=0,median_first=0,average_move=0,ten_price=0;
   if(!MFHistoryStats(day,prior_close,median_first,average_move)||!MFCurrentTenPrice(day,ten_price)){MFLog(now,"SKIP","incomplete causal history");return;}
   int signal=MFDirection(prior_close,ten_price);double first_return=ten_price/prior_close-1.0;
   if(signal==0){MFLog(now,"NO_SIGNAL","zero first-half-hour return");return;}
   if(InpUseVolatilityFilter&&MathAbs(first_return)<=median_first){MFLog(now,"SKIP","volatility filter current="+MFNumber(MathAbs(first_return))+" median="+MFNumber(median_first));return;}
   int side=signal;if(InpExperiment==MF_RANDOM_DIRECTION_1R)side=MFRandomSide(day,InpRandomSeed);else if(InpExperiment==MF_ALWAYS_LONG_1R)side=1;
   MFLog(now,"SETUP","day="+IntegerToString(day)+" signalSide="+IntegerToString(signal)+" tradedSide="+IntegerToString(side)+" firstReturn="+MFNumber(first_return)+" medianAbsReturn="+MFNumber(median_first)+" averageClosingMove="+MFNumber(average_move));
   MqlTick q;if(!SymbolInfoTick(_Symbol,q)||q.ask<=q.bid||q.bid<=0)return;double spread=q.ask-q.bid;if(spread>InpMaxSpreadPriceUnits){MFLog(now,"SKIP","spread cap");return;}
   double distance=average_move*InpStopWindowFraction,entry=side>0?q.ask:q.bid,sizing_stop=MFRoundPrice(entry-side*distance);
   double sl=InpExperiment==MF_SIGNAL_HOLD_CLOSE?0:sizing_stop,tp=InpExperiment==MF_SIGNAL_HOLD_CLOSE?0:MFRoundPrice(entry+side*distance);
   double minimum=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;if(sl>0&&((side>0?q.bid-sl:sl-q.ask)<minimum||(side>0?tp-q.bid:q.ask-tp)<minimum)){MFLog(now,"SKIP","broker stop-distance rule");return;}
   double volume=MFVolume(side,entry,sizing_stop);if(volume<=0){MFLog(now,"SKIP","volume below broker minimum");return;}
   MqlTradeRequest req={};MqlTradeResult result={};MqlTradeCheckResult check={};req.action=TRADE_ACTION_DEAL;req.symbol=_Symbol;req.magic=InpMagic;req.volume=volume;req.type=side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;req.price=entry;req.sl=sl;req.tp=tp;req.deviation=(ulong)MathCeil(InpMaxDeviationPriceUnits/_Point);req.comment="MF_"+IntegerToString(day);
   long fill=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);if((fill&SYMBOL_FILLING_FOK)!=0)req.type_filling=ORDER_FILLING_FOK;else if((fill&SYMBOL_FILLING_IOC)!=0)req.type_filling=ORDER_FILLING_IOC;else req.type_filling=ORDER_FILLING_RETURN;
   if(!OrderCheck(req,check)){MFLog(now,"ORDER_CHECK_REJECTED",check.comment);return;}if(!OrderSend(req,result)||(result.retcode!=TRADE_RETCODE_DONE&&result.retcode!=TRADE_RETCODE_DONE_PARTIAL)){MFLog(now,"ORDER_SEND_REJECTED",result.comment);return;}
   double fill_price=result.price>0?result.price:entry;ulong ticket=0;MFHasOwnPosition(ticket);ulong pid=0;datetime entry_server=TimeCurrent();long entry_msc=(long)entry_server*1000;
   if(result.deal>0&&HistoryDealSelect(result.deal)){pid=(ulong)HistoryDealGetInteger(result.deal,DEAL_POSITION_ID);fill_price=HistoryDealGetDouble(result.deal,DEAL_PRICE);entry_server=(datetime)HistoryDealGetInteger(result.deal,DEAL_TIME);entry_msc=HistoryDealGetInteger(result.deal,DEAL_TIME_MSC);}else if(ticket>0&&PositionSelectByTicket(ticket))pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   datetime entry_utc=now;MFUtc(entry_server,entry_utc);double record_sl=MFRoundPrice(fill_price-side*distance),record_tp=InpExperiment==MF_SIGNAL_HOLD_CLOSE?0:MFRoundPrice(fill_price+side*distance),unit=0;MFUnitRisk(side,fill_price,record_sl,unit);
   int k=ArraySize(g_mf_records);ArrayResize(g_mf_records,k+1);ZeroMemory(g_mf_records[k]);g_mf_records[k].id=g_mf_run+"_MF_"+IntegerToString(day);g_mf_records[k].status="OPEN";g_mf_records[k].day=day;g_mf_records[k].side=side;g_mf_records[k].position=pid;g_mf_records[k].entry=entry_utc;g_mf_records[k].entry_msc=(long)entry_utc*1000+entry_msc%1000;g_mf_records[k].volume=volume;g_mf_records[k].fill=fill_price;g_mf_records[k].sl=InpExperiment==MF_SIGNAL_HOLD_CLOSE?0:record_sl;g_mf_records[k].tp=record_tp;g_mf_records[k].risk_cash=unit*volume;if(InpExperiment==MF_SIGNAL_HOLD_CLOSE)g_mf_records[k].integrity="HOLD_TO_CLOSE_NOMINAL_RISK";MFExportTrades();
   if(InpExperiment!=MF_SIGNAL_HOLD_CLOSE&&MFHasOwnPosition(ticket)&&!MFProtectionMatches(ticket,record_sl,record_tp)){ResetLastError();bool sent=g_mf_trade.PositionModify(ticket,record_sl,record_tp);uint retcode=g_mf_trade.ResultRetcode();if(!MFProtectionMatches(ticket,record_sl,record_tp)){g_mf_records[k].integrity="PROTECTION_VERIFICATION_FAILED";g_mf_records[k].exit_reason="PROTECTION_FAILURE";MFLog(now,"PROTECTION_FAILURE","sent="+IntegerToString(sent?1:0)+" retcode="+IntegerToString((int)retcode)+" "+g_mf_trade.ResultRetcodeDescription()+" lastError="+IntegerToString(GetLastError()));g_mf_trade.PositionClose(ticket);MFRefreshTrades();MFExportTrades();return;}}
   MFLog(now,"ENTRY","tradeId="+g_mf_records[k].id+" mode="+EnumToString(InpExperiment)+" side="+IntegerToString(side)+" distance="+MFNumber(distance)+" volume="+DoubleToString(volume,8));
}

int OnInit() {
   if(InpBrokerClock==NP_CLOCK_UNSET||InpBrokerWinterUtcOffsetSeconds<-50400||InpBrokerWinterUtcOffsetSeconds>50400||InpBrokerWinterUtcOffsetSeconds%60!=0||InpLookbackSessions<2||InpLookbackSessions>200||InpStopWindowFraction<=0||InpRiskPercent<=0||InpRiskPercent>5||InpFixedCashRisk<=0||InpMaxSpreadPriceUnits<=0||InpMaxDeviationPriceUnits<0||InpEntryWindowSeconds<0||InpEntryWindowSeconds>55||InpMagic==0)return INIT_PARAMETERS_INCORRECT;
   datetime utc=0;if(!MFUtc(TimeCurrent(),utc))return INIT_FAILED;
   string canonical="MF_V1|"+IntegerToString((int)InpBrokerClock)+"|"+IntegerToString(InpBrokerWinterUtcOffsetSeconds)+"|"+IntegerToString(InpLookbackSessions)+"|"+IntegerToString(InpUseVolatilityFilter?1:0)+"|"+MFNumber(InpStopWindowFraction)+"|"+IntegerToString((int)InpExperiment)+"|"+StringFormat("%I64u",InpRandomSeed)+"|"+IntegerToString((int)InpRiskMode)+"|"+MFNumber(InpRiskPercent)+"|"+MFNumber(InpFixedCashRisk)+"|"+MFNumber(InpMaxSpreadPriceUnits)+"|"+MFNumber(InpMaxDeviationPriceUnits)+"|"+IntegerToString(InpEntryWindowSeconds)+"|"+StringFormat("%I64u",InpMagic);
   g_mf_config=MFHash(canonical);g_mf_run=E2UniqueReportRun("MF_"+g_mf_config+"_"+IntegerToString((long)TimeLocal()));
   if(InpExportCsv){if(!E2ReportFolder("IndexClosingMomentum",g_mf_report_folder))return INIT_FAILED;g_mf_report_base=g_mf_report_folder+"\\"+E2ReportBase(_Symbol,g_mf_run);g_mf_signals=FileOpen(g_mf_report_base+"_Signals_S.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);if(g_mf_signals==INVALID_HANDLE)return INIT_FAILED;FileWrite(g_mf_signals,"schema_version","run_id","strategy","time_utc","event","detail");int h=FileOpen(g_mf_report_base+"_Settings.txt",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);if(h!=INVALID_HANDLE){FileWriteString(h,canonical+"\r\nsymbol="+_Symbol+"\r\nclock=UTC in reports\r\n");FileClose(h);}if(!MFExportTrades())return INIT_FAILED;}
   g_mf_trade.SetExpertMagicNumber(InpMagic);g_mf_trade.SetAsyncMode(false);g_mf_trade.SetTypeFillingBySymbol(_Symbol);g_mf_trade.SetDeviationInPoints((ulong)MathCeil(InpMaxDeviationPriceUnits/_Point));if(!EventSetTimer(1))return INIT_FAILED;g_mf_ready=true;MFLog(utc,"READY","15:30 entry; 16:00 exit; report="+g_mf_report_base);return INIT_SUCCEEDED;
}
void MFRun(){if(!g_mf_ready)return;datetime now=0;if(!MFUtc(TimeCurrent(),now))return;MFRefreshTrades();MFCloseAtCashClose(now);MFTryEntry(now);MFRefreshTrades();}
void OnTick(){MFRun();}
void OnTimer(){MFRun();}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res){MFRefreshTrades();}
void OnDeinit(const int reason){EventKillTimer();MFRefreshTrades();MFExportTrades();if(g_mf_signals!=INVALID_HANDLE){FileFlush(g_mf_signals);FileClose(g_mf_signals);g_mf_signals=INVALID_HANDLE;}}

#endif
