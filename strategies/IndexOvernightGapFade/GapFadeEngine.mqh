#ifndef E2_GAP_FADE_ENGINE_MQH
#define E2_GAP_FADE_ENGINE_MQH
#include <Trade/Trade.mqh>
#include "GapFadeCore.mqh"
#include "GapFadeClock.mqh"
#include "..\\shared\\ReportFolders.mqh"

enum GFExperimentMode { GF_FADE_1R=0, GF_RANDOM_DIRECTION_1R=1, GF_FADE_HOLD_TO_CLOSE=2 };
enum GFRiskMode { GF_RISK_EQUITY_PERCENT=0, GF_RISK_FIXED_CASH=1 };

input group "Historical broker time"
input NPClockMode InpBrokerClock=NP_CLOCK_UNSET;
input int InpBrokerWinterUtcOffsetSeconds=0;
input group "Research parameters"
input int InpATRLength=14;
input double InpMinGapATR=0.15;
input double InpMaxGapATR=1.00;
input double InpStopATR=0.35;
input GFExperimentMode InpExperiment=GF_FADE_1R;
input ulong InpRandomSeed=20261001;
input group "Risk and execution"
input GFRiskMode InpRiskMode=GF_RISK_EQUITY_PERCENT;
input double InpRiskPercent=0.50;
input double InpFixedCashRisk=500.0;
input double InpMaxSpreadPriceUnits=10.0;
input double InpMaxDeviationPriceUnits=1.0;
input int InpEntryWindowSeconds=10;
input ulong InpMagic=2026100201;
input group "Event exclusions"
input bool InpSkipHighImpactDays=true;
input string InpEventCsv="E2\\IndexOvernightGapFade\\US_HIGH_IMPACT_DATES.csv";
input group "Reporting"
input bool InpExportCsv=true;

CTrade g_trade;
int g_event_days[];
int g_processed_day=0;
bool g_ready=false;
datetime g_last_close_attempt=0;
int g_signals=INVALID_HANDLE;
string g_run,g_config,g_report_folder,g_report_base;

struct GFTradeRecord {
   string id,status,exit_reason,integrity;
   int day,side;
   ulong position;
   datetime entry,exit;
   long entry_msc,exit_msc;
   double volume,fill,sl,tp,requested_risk,risk_cash,net;
};
GFTradeRecord g_records[];

string GFStamp(const datetime t) {
   string x=TimeToString(t,TIME_DATE|TIME_SECONDS);StringReplace(x,".","-");return x;
}
string GFNumber(const double n) {return DoubleToString(n,10);}
string GFHash(const string value) {
   uint h=2166136261;
   for(int i=0;i<StringLen(value);i++){h^=(uint)StringGetCharacter(value,i);h*=16777619;}
   return StringFormat("%08X",h);
}
void GFSignalLog(const datetime utc,const string event,const string detail) {
   Print("[GF] ",event," ",detail);
   if(g_signals!=INVALID_HANDLE) {
      FileWrite(g_signals,"GF_SIGNAL_V1",g_run,"INDEX_GAP_FADE",GFStamp(utc),event,detail);
      FileFlush(g_signals);
   }
}
bool GFExportTrades() {
   if(!InpExportCsv)return true;
   int h=FileOpen(g_report_base+"_Trades_T.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(h==INVALID_HANDLE){Print("[GF] Cannot export trade CSV error=",GetLastError());return false;}
   FileWrite(h,"schema_version","trade_id","strategy","config_hash","symbol","direction",
      "fill_time","exit_time","net_profit","actual_initial_cash_risk","trade_status","run_id",
      "entry_msc","exit_msc","position_id","volume","fill_price","initial_sl","initial_tp","net_r","exit_reason","integrity_flags");
   for(int i=0;i<ArraySize(g_records);i++) {
      GFTradeRecord r=g_records[i];
      FileWrite(h,"E2_JOURNAL_V1",r.id,"INDEX_GAP_FADE",g_config,_Symbol,r.side>0?"LONG":"SHORT",
         GFStamp(r.entry),r.exit>0?GFStamp(r.exit):"",r.status=="FINALIZED"?GFNumber(r.net):"",
         r.risk_cash>0?GFNumber(r.risk_cash):"",r.status,g_run,r.entry_msc,r.exit_msc,r.position,
         r.volume,r.fill,r.sl,r.tp,r.status=="FINALIZED"&&r.risk_cash>0?GFNumber(r.net/r.risk_cash):"",
         r.exit_reason,r.integrity);
   }
   FileFlush(h);int error=GetLastError();FileClose(h);
   if(error!=0){Print("[GF] Trade CSV write failed error=",error);return false;}
   return true;
}
void GFRefreshTrades() {
   bool changed=false;
   for(int i=0;i<ArraySize(g_records);i++) {
      if(g_records[i].status=="FINALIZED"||g_records[i].position==0)continue;
      if(!HistorySelectByPosition(g_records[i].position))continue;
      double vin=0,vout=0,net=0;datetime last=0;long last_msc=0;string reason=g_records[i].exit_reason;
      for(int j=0;j<HistoryDealsTotal();j++) {
         ulong deal=HistoryDealGetTicket(j);long edge=HistoryDealGetInteger(deal,DEAL_ENTRY);
         double volume=HistoryDealGetDouble(deal,DEAL_VOLUME);
         net+=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_COMMISSION)+
              HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_FEE);
         if(edge==DEAL_ENTRY_IN)vin+=volume;
         if(edge==DEAL_ENTRY_OUT||edge==DEAL_ENTRY_OUT_BY) {
            vout+=volume;long msc=HistoryDealGetInteger(deal,DEAL_TIME_MSC);
            if(msc>=last_msc) {
               last_msc=msc;last=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
               long why=HistoryDealGetInteger(deal,DEAL_REASON);
               if(why==DEAL_REASON_SL)reason="SL";else if(why==DEAL_REASON_TP)reason="TP";
               else if(why==DEAL_REASON_EXPERT&&reason=="")reason="SESSION_CLOSE";
               else if(reason=="")reason="OTHER";
            }
         }
      }
      if(vin<=0||vout+1e-8<vin)continue;
      datetime exit_utc=0;if(!GFUtc(last,exit_utc))continue;
      g_records[i].exit=exit_utc;g_records[i].exit_msc=(long)exit_utc*1000+last_msc%1000;
      g_records[i].net=net;g_records[i].exit_reason=reason;g_records[i].status="FINALIZED";changed=true;
      GFSignalLog(exit_utc,"EXIT",g_records[i].id+" reason="+reason+" netR="+
         (g_records[i].risk_cash>0?GFNumber(net/g_records[i].risk_cash):"NA"));
   }
   if(changed)GFExportTrades();
}
bool GFUtc(const datetime server,datetime &utc) {
   return NPToUtc(server,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds,utc);
}
double GFRoundPrice(const double value) {
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return NormalizeDouble(MathRound(value/tick)*tick,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
}
bool GFHasOwnPosition(ulong &ticket) {
   ticket=0;
   for(int i=0;i<PositionsTotal();i++) {
      ulong t=PositionGetTicket(i);
      if(t>0 && PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic){ticket=t;return true;}
   }
   return false;
}
bool GFSymbolIsFree() {
   for(int i=0;i<PositionsTotal();i++) {
      ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol)return false;
   }
   for(int i=0;i<OrdersTotal();i++) {
      ulong t=OrderGetTicket(i);if(t>0&&OrderGetString(ORDER_SYMBOL)==_Symbol)return false;
   }
   return true;
}
bool GFLoadEvents() {
   ArrayResize(g_event_days,0);
   if(!InpSkipHighImpactDays)return true;
   int h=FileOpen(InpEventCsv,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(h==INVALID_HANDLE) {
      Print("[GF] Missing mandatory event file in Common Files: ",InpEventCsv);
      return false;
   }
   while(!FileIsEnding(h)) {
      string raw=FileReadString(h);
      if(FileIsEnding(h)&&raw=="")break;
      string event=FileReadString(h);
      StringTrimLeft(raw);StringTrimRight(raw);
      if(raw==""||StringFind(raw,"#")==0||raw=="date")continue;
      string digits=raw;StringReplace(digits,"-","");StringReplace(digits,".","");StringReplace(digits,"/","");
      int day=(int)StringToInteger(digits);
      if(day<20000101||day>20991231){FileClose(h);Print("[GF] Invalid event date: ",raw);return false;}
      int n=ArraySize(g_event_days);ArrayResize(g_event_days,n+1);g_event_days[n]=day;
   }
   FileClose(h);
   if(ArraySize(g_event_days)==0){Print("[GF] Event filter enabled but event CSV contains no dates.");return false;}
   Print("[GF] Loaded ",ArraySize(g_event_days)," FOMC/CPI/NFP exclusion rows.");
   return true;
}
bool GFBlockedDay(const int day) {
   for(int i=0;i<ArraySize(g_event_days);i++)if(g_event_days[i]==day)return true;
   return false;
}
bool GFSessionBar(const int day,GFDayBar &out) {
   datetime probe=GFNyBoundaryUtc(day,12,0);
   int close_minute=NPCloseMinute(probe);
   if(close_minute<=570)return false;
   datetime from_utc=GFNyBoundaryUtc(day,9,30);
   datetime to_utc=GFNyBoundaryUtc(day,close_minute/60,close_minute%60)-1;
   datetime from_server=NPToServer(from_utc,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds);
   datetime to_server=NPToServer(to_utc,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds);
   MqlRates rates[];ArraySetAsSeries(rates,false);
   int n=CopyRates(_Symbol,PERIOD_M1,from_server,to_server,rates);
   int expected=close_minute-570;
   if(n<expected-5)return false;
   bool found=false;double o=0,h=0,l=0,c=0;int first_minute=9999,last_minute=-1;
   for(int i=0;i<n;i++) {
      datetime utc=0;if(!GFUtc(rates[i].time,utc))return false;
      MqlDateTime t;TimeToStruct(NPNy(utc),t);
      int d=t.year*10000+t.mon*100+t.day,minute=t.hour*60+t.min;
      if(d!=day||minute<570||minute>=close_minute)continue;
      if(!found){o=rates[i].open;h=rates[i].high;l=rates[i].low;found=true;first_minute=minute;}
      h=MathMax(h,rates[i].high);l=MathMin(l,rates[i].low);c=rates[i].close;last_minute=minute;
   }
   if(!found||first_minute!=570||last_minute<close_minute-2)return false;
   out.day=day;out.open=o;out.high=h;out.low=l;out.close=c;return true;
}
bool GFHistory(const int today,GFDayBar &days[],double &atr,double &prior_close) {
   GFDayBar reverse[];ArrayResize(reverse,0);
   int target=InpATRLength+100; // Stabilize Wilder initialization before the decision day.
   int cursor=today;
   for(int scan=0;scan<500 && ArraySize(reverse)<target;scan++) {
      cursor=GFPreviousCalendarDay(cursor);GFDayBar b;
      if(GFSessionBar(cursor,b)){int n=ArraySize(reverse);ArrayResize(reverse,n+1);reverse[n]=b;}
   }
   int count=ArraySize(reverse);if(count<InpATRLength+1)return false;
   ArrayResize(days,count);
   for(int i=0;i<count;i++)days[i]=reverse[count-1-i];
   atr=GFWilderAtr(days,count,InpATRLength);prior_close=days[count-1].close;
   return atr>0;
}
bool GFFirstFive(const int day,double &bar_open,double &bar_close,double &cash_open) {
   datetime from_utc=GFNyBoundaryUtc(day,9,30),to_utc=GFNyBoundaryUtc(day,9,35)-1;
   MqlRates rates[];ArraySetAsSeries(rates,false);
   int n=CopyRates(_Symbol,PERIOD_M1,
      NPToServer(from_utc,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds),
      NPToServer(to_utc,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds),rates);
   int seen=0;
   for(int i=0;i<n;i++) {
      datetime utc=0;if(!GFUtc(rates[i].time,utc))return false;
      MqlDateTime t;TimeToStruct(NPNy(utc),t);
      if(t.year*10000+t.mon*100+t.day!=day||t.hour!=9||t.min<30||t.min>34)continue;
      if(seen==0){bar_open=rates[i].open;cash_open=rates[i].open;}
      bar_close=rates[i].close;seen++;
   }
   return seen==5;
}
bool GFTradedToday(const int day) {
   datetime start=GFNyBoundaryUtc(day,0,0),finish=GFNyBoundaryUtc(day,23,59)+60;
   if(!HistorySelect(NPToServer(start,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds),
                     NPToServer(finish,InpBrokerClock,InpBrokerWinterUtcOffsetSeconds)))return true;
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong d=HistoryDealGetTicket(i);
      if(HistoryDealGetString(d,DEAL_SYMBOL)==_Symbol &&
         (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)==InpMagic &&
         HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN)return true;
   }
   return false;
}
bool GFUnitRisk(const int side,const double entry,const double stop,double &cash) {
   double profit=0;
   ENUM_ORDER_TYPE type=side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   if(!OrderCalcProfit(type,_Symbol,1.0,entry,stop,profit))return false;
   cash=MathAbs(profit);return cash>0&&MathIsValidNumber(cash);
}
double GFVolume(const int side,const double entry,const double stop) {
   double unit=0;if(!GFUnitRisk(side,entry,stop,unit))return 0;
   double budget=GFRequestedCashRisk(AccountInfoDouble(ACCOUNT_EQUITY),InpRiskPercent,
      InpFixedCashRisk,InpRiskMode==GF_RISK_FIXED_CASH);
   if(budget<=0)return 0;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double volume=MathFloor((budget/unit)/step+1e-10)*step;
   volume=MathMin(volume,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX));
   if(volume<SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN))return 0;
   return NormalizeDouble(volume,8);
}
bool GFProtectionMatches(const ulong ticket,const double sl,const double tp) {
   if(!PositionSelectByTicket(ticket))return false;
   double tolerance=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*0.51;
   return MathAbs(PositionGetDouble(POSITION_SL)-sl)<=tolerance &&
          MathAbs(PositionGetDouble(POSITION_TP)-tp)<=tolerance;
}
void GFCloseAtDeadline(const datetime now) {
   ulong ticket=0;if(!GFHasOwnPosition(ticket))return;
   MqlDateTime t;TimeToStruct(NPNy(now),t);int minute=t.hour*60+t.min;
   int today=t.year*10000+t.mon*100+t.day;
   datetime opened_server=(datetime)PositionGetInteger(POSITION_TIME),opened_utc=0;
   if(!GFUtc(opened_server,opened_utc))return;
   MqlDateTime e;TimeToStruct(NPNy(opened_utc),e);int entry_day=e.year*10000+e.mon*100+e.day;
   int cash_close=NPCloseMinute(now),deadline=cash_close>0?cash_close-5:0;
   if(entry_day==today && deadline>0 && minute<deadline)return;
   if(g_last_close_attempt>0&&now-g_last_close_attempt<5)return;
   ulong position_id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   for(int i=0;i<ArraySize(g_records);i++)
      if(g_records[i].position==position_id&&g_records[i].status!="FINALIZED")g_records[i].exit_reason="SESSION_CLOSE";
   g_last_close_attempt=now;g_trade.SetExpertMagicNumber(InpMagic);
   if(!g_trade.PositionClose(ticket))Print("[GF] Close retry: ",g_trade.ResultRetcodeDescription());
}
void GFTryEntry(const datetime now) {
   MqlDateTime t;TimeToStruct(NPNy(now),t);int day=t.year*10000+t.mon*100+t.day;
   int second=t.hour*3600+t.min*60+t.sec;
   if(second<9*3600+35*60||second>9*3600+35*60+InpEntryWindowSeconds)return;
   if(g_processed_day==day)return;g_processed_day=day;
   if(NPCloseMinute(now)<=0){GFSignalLog(now,"SKIP","exchange closed day="+IntegerToString(day));return;}
   if(GFBlockedDay(day)){GFSignalLog(now,"SKIP","scheduled event day="+IntegerToString(day));return;}
   if(GFTradedToday(day)){GFSignalLog(now,"SKIP","daily limit day="+IntegerToString(day));return;}
   if(!GFSymbolIsFree()){GFSignalLog(now,"SKIP","symbol occupied day="+IntegerToString(day));return;}
   GFDayBar history[];double atr=0,prior_close=0;
   if(!GFHistory(day,history,atr,prior_close)){GFSignalLog(now,"SKIP","incomplete RTH ATR history day="+IntegerToString(day));return;}
   double first_open=0,first_close=0,cash_open=0;
   if(!GFFirstFive(day,first_open,first_close,cash_open)){GFSignalLog(now,"SKIP","incomplete 09:30 candle day="+IntegerToString(day));return;}
   int side=GFSignal(cash_open,prior_close,atr,InpMinGapATR,InpMaxGapATR,first_open,first_close);
   double gap_atr=MathAbs(cash_open-prior_close)/atr;
   if(side==0){GFSignalLog(now,"NO_SIGNAL","day="+IntegerToString(day)+" gapATR="+DoubleToString(gap_atr,4));return;}
   int fade_side=side;if(InpExperiment==GF_RANDOM_DIRECTION_1R)side=GFRandomSide(day,InpRandomSeed);
   GFSignalLog(now,"SETUP","day="+IntegerToString(day)+" gapATR="+DoubleToString(gap_atr,4)+
      " fadeSide="+IntegerToString(fade_side)+" tradedSide="+IntegerToString(side)+
      " firstOpen="+GFNumber(first_open)+" firstClose="+GFNumber(first_close));
   MqlTick q;if(!SymbolInfoTick(_Symbol,q)||q.ask<=q.bid||q.bid<=0)return;
   double spread=q.ask-q.bid;if(spread>InpMaxSpreadPriceUnits){GFSignalLog(now,"SKIP","spread="+GFNumber(spread));return;}
   double distance=atr*InpStopATR;
   double entry=side>0?q.ask:q.bid;
   double sizing_stop=GFRoundPrice(entry-side*distance);
   double sl=InpExperiment==GF_FADE_HOLD_TO_CLOSE?0:sizing_stop;
   double tp=InpExperiment==GF_FADE_HOLD_TO_CLOSE?0:GFRoundPrice(entry+side*distance);
   double minimum=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(sl>0&&((side>0?q.bid-sl:sl-q.ask)<minimum || (side>0?tp-q.bid:q.ask-tp)<minimum)) {
      GFSignalLog(now,"SKIP","broker stop-distance rule");return;
   }
   double volume=GFVolume(side,entry,sizing_stop);if(volume<=0){GFSignalLog(now,"SKIP","volume below broker minimum");return;}
   MqlTradeRequest req={};MqlTradeResult result={};MqlTradeCheckResult check={};
   req.action=TRADE_ACTION_DEAL;req.symbol=_Symbol;req.magic=InpMagic;req.volume=volume;
   req.type=side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;req.price=entry;req.sl=sl;req.tp=tp;
   req.deviation=(ulong)MathCeil(InpMaxDeviationPriceUnits/_Point);
   req.comment="GF_"+IntegerToString(day);
   long fill=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((fill&SYMBOL_FILLING_FOK)!=0)req.type_filling=ORDER_FILLING_FOK;
   else if((fill&SYMBOL_FILLING_IOC)!=0)req.type_filling=ORDER_FILLING_IOC;
   else req.type_filling=ORDER_FILLING_RETURN;
   if(!OrderCheck(req,check)){GFSignalLog(now,"ORDER_CHECK_REJECTED",check.comment);return;}
   if(!OrderSend(req,result)||(result.retcode!=TRADE_RETCODE_DONE&&result.retcode!=TRADE_RETCODE_DONE_PARTIAL)) {
      GFSignalLog(now,"ORDER_SEND_REJECTED",result.comment);return;
   }
   // Preserve exact 1:1 around the authoritative fill, including entry slippage.
   double fill_price=result.price>0?result.price:entry;
   ulong ticket=0;
   GFHasOwnPosition(ticket);
   ulong position_id=0;datetime entry_server=TimeCurrent();long entry_msc=(long)entry_server*1000;
   if(result.deal>0&&HistoryDealSelect(result.deal)) {
      position_id=(ulong)HistoryDealGetInteger(result.deal,DEAL_POSITION_ID);
      fill_price=HistoryDealGetDouble(result.deal,DEAL_PRICE);
      entry_server=(datetime)HistoryDealGetInteger(result.deal,DEAL_TIME);
      entry_msc=HistoryDealGetInteger(result.deal,DEAL_TIME_MSC);
   } else if(ticket>0&&PositionSelectByTicket(ticket))position_id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   datetime entry_utc=now;GFUtc(entry_server,entry_utc);
   double record_sl=InpExperiment==GF_FADE_HOLD_TO_CLOSE?sizing_stop:GFRoundPrice(fill_price-side*distance);
   double record_tp=InpExperiment==GF_FADE_HOLD_TO_CLOSE?0:GFRoundPrice(fill_price+side*distance);
   double actual_unit=0;GFUnitRisk(side,fill_price,record_sl,actual_unit);
   int record_index=ArraySize(g_records);ArrayResize(g_records,record_index+1);ZeroMemory(g_records[record_index]);
   g_records[record_index].id=g_run+"_GF_"+IntegerToString(day);
   g_records[record_index].status="OPEN";g_records[record_index].day=day;g_records[record_index].side=side;
   g_records[record_index].position=position_id;g_records[record_index].entry=entry_utc;
   g_records[record_index].entry_msc=(long)entry_utc*1000+entry_msc%1000;
   g_records[record_index].volume=volume;g_records[record_index].fill=fill_price;
   g_records[record_index].sl=InpExperiment==GF_FADE_HOLD_TO_CLOSE?0:record_sl;
   g_records[record_index].tp=record_tp;g_records[record_index].risk_cash=actual_unit*volume;
   g_records[record_index].requested_risk=GFRequestedCashRisk(AccountInfoDouble(ACCOUNT_EQUITY),
      InpRiskPercent,InpFixedCashRisk,InpRiskMode==GF_RISK_FIXED_CASH);
   if(InpExperiment==GF_FADE_HOLD_TO_CLOSE)g_records[record_index].integrity="HOLD_TO_CLOSE_NOMINAL_RISK";
   GFExportTrades();
   if(InpExperiment!=GF_FADE_HOLD_TO_CLOSE && GFHasOwnPosition(ticket)) {
      double actual_sl=GFRoundPrice(fill_price-side*distance);
      double actual_tp=GFRoundPrice(fill_price+side*distance);
      // The market request already carries protection. A second modification can
      // legitimately return NO_CHANGES, so verify the position before and after
      // attempting a modification instead of treating the method's bool as proof.
      if(!GFProtectionMatches(ticket,actual_sl,actual_tp)) {
         ResetLastError();
         bool sent=g_trade.PositionModify(ticket,actual_sl,actual_tp);
         uint retcode=g_trade.ResultRetcode();
         if(!GFProtectionMatches(ticket,actual_sl,actual_tp)) {
            g_records[record_index].integrity="PROTECTION_VERIFICATION_FAILED";
            g_records[record_index].exit_reason="PROTECTION_FAILURE";
            GFSignalLog(now,"PROTECTION_FAILURE","sent="+IntegerToString(sent?1:0)+
               " retcode="+IntegerToString((int)retcode)+" "+g_trade.ResultRetcodeDescription()+
               " lastError="+IntegerToString(GetLastError()));
            if(!g_trade.PositionClose(ticket))
               Print("[GF] EMERGENCY CLOSE FAILED retcode=",g_trade.ResultRetcode(),
                  " ",g_trade.ResultRetcodeDescription());
            GFRefreshTrades();GFExportTrades();
            return;
         }
      }
   }
   GFSignalLog(now,"ENTRY","tradeId="+g_records[record_index].id+" day="+IntegerToString(day)+
      " mode="+EnumToString(InpExperiment)+" fadeSide="+IntegerToString(fade_side)+
      " tradedSide="+IntegerToString(side)+" gapATR="+DoubleToString(gap_atr,4)+
      " ATR="+DoubleToString(atr,_Digits)+" spread="+DoubleToString(spread,_Digits)+
      " volume="+DoubleToString(volume,8));
}
int OnInit() {
   if(InpBrokerClock==NP_CLOCK_UNSET||InpBrokerWinterUtcOffsetSeconds<-50400||
      InpBrokerWinterUtcOffsetSeconds>50400||InpBrokerWinterUtcOffsetSeconds%60!=0||
      InpATRLength<2||InpATRLength>100||InpMinGapATR<0||InpMaxGapATR<=InpMinGapATR||
      InpStopATR<=0||InpRiskPercent<=0||InpRiskPercent>5||InpFixedCashRisk<=0||InpMaxSpreadPriceUnits<=0||
      InpMaxDeviationPriceUnits<0||InpEntryWindowSeconds<0||InpEntryWindowSeconds>55||InpMagic==0)
      return INIT_PARAMETERS_INCORRECT;
   datetime utc=0;if(!GFUtc(TimeCurrent(),utc))return INIT_FAILED;
   if(!GFLoadEvents())return INIT_FAILED;
   string canonical="GF_V1|"+IntegerToString((int)InpBrokerClock)+"|"+
      IntegerToString(InpBrokerWinterUtcOffsetSeconds)+"|"+IntegerToString(InpATRLength)+"|"+
      GFNumber(InpMinGapATR)+"|"+GFNumber(InpMaxGapATR)+"|"+GFNumber(InpStopATR)+"|"+
      IntegerToString((int)InpExperiment)+"|"+StringFormat("%I64u",InpRandomSeed)+"|"+
      IntegerToString((int)InpRiskMode)+"|"+GFNumber(InpRiskPercent)+"|"+GFNumber(InpFixedCashRisk)+"|"+
      GFNumber(InpMaxSpreadPriceUnits)+"|"+GFNumber(InpMaxDeviationPriceUnits)+"|"+
      IntegerToString(InpEntryWindowSeconds)+"|"+StringFormat("%I64u",InpMagic);
   g_config=GFHash(canonical);g_run=E2UniqueReportRun("GF_"+g_config+"_"+IntegerToString((long)TimeLocal()));
   if(InpExportCsv) {
      if(!E2ReportFolder("IndexOvernightGapFade",g_report_folder))return INIT_FAILED;
      g_report_base=g_report_folder+"\\"+E2ReportBase(_Symbol,g_run);
      g_signals=FileOpen(g_report_base+"_Signals_S.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
      if(g_signals==INVALID_HANDLE){Print("[GF] Cannot create signal CSV error=",GetLastError());return INIT_FAILED;}
      FileWrite(g_signals,"schema_version","run_id","strategy","time_utc","event","detail");FileFlush(g_signals);
      int settings=FileOpen(g_report_base+"_Settings.txt",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
      if(settings!=INVALID_HANDLE){FileWriteString(settings,canonical+"\r\nsymbol="+_Symbol+"\r\nclock=UTC in reports\r\n");FileClose(settings);}
      if(!GFExportTrades())return INIT_FAILED;
   }
   g_trade.SetExpertMagicNumber(InpMagic);g_trade.SetAsyncMode(false);g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints((ulong)MathCeil(InpMaxDeviationPriceUnits/_Point));
   if(!EventSetTimer(1))return INIT_FAILED;
   g_ready=true;
   GFSignalLog(utc,"READY","RTH ATR, New York clock, 09:35 entry; report="+g_report_base);
   return INIT_SUCCEEDED;
}
void GFRun() {
   if(!g_ready)return;datetime now=0;if(!GFUtc(TimeCurrent(),now))return;
   GFRefreshTrades();GFCloseAtDeadline(now);GFTryEntry(now);GFRefreshTrades();
}
void OnTick(){GFRun();}
void OnTimer(){GFRun();}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res){GFRefreshTrades();}
void OnDeinit(const int reason){EventKillTimer();GFRefreshTrades();GFExportTrades();if(g_signals!=INVALID_HANDLE){FileFlush(g_signals);FileClose(g_signals);g_signals=INVALID_HANDLE;}}

#endif
