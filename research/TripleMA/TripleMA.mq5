#property strict
#property version "0.10"
#property description "Triple MA filtered crossover research. STRATEGY TESTER ONLY."

#include <Trade/Trade.mqh>
#include "..\\..\\include\\core\\E2SymbolInfo.mqh"
#include "..\\..\\include\\reporting\\E2CsvExporter.mqh"
#include "TripleMACore.mqh"

enum TripleMAStopMode { TRIPLE_MA_ATR=0,TRIPLE_MA_FIXED_POINTS=1 };
enum TripleMARiskMode { TRIPLE_MA_FIXED_CASH=0,TRIPLE_MA_BALANCE_PERCENT=1 };
input group "=== TRIPLE MA RESEARCH: UNOPTIMISED DEFAULTS ==="
input int InpFastMA=10;
input int InpMediumMA=20;
input int InpSlowMA=50;
input ENUM_MA_METHOD InpMAMethod=MODE_EMA;
input ENUM_APPLIED_PRICE InpMAPrice=PRICE_CLOSE;
input bool InpAllowLong=true;
input bool InpAllowShort=true;
input group "=== FIXED EXIT AT ENTRY ==="
input TripleMAStopMode InpStopMode=TRIPLE_MA_ATR;
input int InpATRLength=14;
input double InpATRMultiplier=2.0;
input double InpFixedStopPoints=200.0;
input double InpTargetR=1.0;
input group "=== RESEARCH RISK ==="
input TripleMARiskMode InpRiskMode=TRIPLE_MA_FIXED_CASH;
input double InpFixedCashRisk=100.0;
input double InpBalanceRiskPercent=0.5;
input ulong InpMagicNumber=2026002;
input group "=== EXECUTION / REPORTING ==="
input double InpMaxSpreadPoints=40.0; // Broker POINTS, not pips
input uint InpDeviationPoints=20;
input int InpMaxEntryDelaySeconds=10; // First available tick, within this window
input bool InpWeekendFlat=true;
input int InpMinutesBeforeFridayClose=30;
input bool InpCsvExport=true;
input bool InpLogSignals=true;
input string InpRunLabel=""; // Optional label; each run also receives a unique ID

struct TripleMASignalRow
  {string id,status,reason;datetime time;int direction;double fp,mp,fc,mc,sc,atr;};
struct TripleMATradeRow
  {
   int signal_index,direction;ulong order,position;datetime requested,opened,closed;
   double requested_volume,volume,fill,sl,tp,fill_target,risk,exit_price,gross,commission,swap,fee;
   string status,reason,comment;bool registered,finalized,protection_ok;
  };
CTrade g_trade;
E2Logger g_logger;
E2SymbolInfo g_symbol;
TripleMASignalRow g_signals[];
TripleMATradeRow g_trades[];
int g_fast=INVALID_HANDLE,g_medium=INVALID_HANDLE,g_slow=INVALID_HANDLE,g_atr=INVALID_HANDLE;
int g_pending=-1,g_active=-1,g_errors=0;
datetime g_bar=0,g_started=0,g_last_close_attempt=0,g_last_alert=0;
string g_run,g_config,g_file_token;
bool g_ready=false,g_reconciling=false;

string TMTime(const datetime value){string s=TimeToString(value,TIME_DATE|TIME_SECONDS);StringReplace(s,".","-");return(s);}
string TMNumber(const double value){return(DoubleToString(value,10));}
string TMDirection(const int direction){return(direction==1?"LONG":"SHORT");}
void TMError(const string message)
  {if(TimeCurrent()-g_last_alert>=30){Print("[TripleMA][ERROR] ",message);g_last_alert=TimeCurrent();}}
void TMOutcome(const int index,const string status,const string reason)
  {g_signals[index].status=status;g_signals[index].reason=reason;if(InpLogSignals)Print("[TripleMA] ",g_signals[index].id," ",status," ",reason);}

// The cutoff uses the symbol's broker-server Friday session schedule. There is
// no clock-based entry session and no guessed UTC offset in this strategy.
bool TMWeekendBlocked()
  {
   if(!InpWeekendFlat)return(false);
   MqlDateTime tm;if(!TimeToStruct(TimeCurrent(),tm))return(true);
   if(tm.day_of_week==0||tm.day_of_week==6)return(true);
   if(tm.day_of_week!=5)return(false);
   int seconds=tm.hour*3600+tm.min*60+tm.sec,end_seconds=-1;
   for(uint i=0;i<32;i++)
     {
      datetime from=0,to=0;if(!SymbolInfoSessionTrade(_Symbol,FRIDAY,i,from,to))break;
      int first=(int)((long)from%86400),last=(int)((long)to%86400);
      if(last<=first)last+=86400;
      end_seconds=MathMax(end_seconds,last);
     }
   if(end_seconds<0){TMError("Friday schedule unavailable; block entries and attempt to flatten.");return(true);}
   return(seconds>=end_seconds-InpMinutesBeforeFridayClose*60);
  }

ulong TMSelectPosition(const ulong identifier)
  {
   for(int i=0;i<PositionsTotal();i++)
     {ulong ticket=PositionGetTicket(i);if(ticket>0&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==identifier&&
       (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(ticket);}
   return(0);
  }

bool TMOrderFinished(const ulong order)
  {
   if(order==0||OrderSelect(order))return(false);
   if(!HistoryOrderSelect(order))return(false);
   ENUM_ORDER_STATE state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(order,ORDER_STATE);
   return(state==ORDER_STATE_FILLED||state==ORDER_STATE_CANCELED||state==ORDER_STATE_REJECTED||state==ORDER_STATE_EXPIRED);
  }

void TMReconcile()
  {
   if(!g_ready||g_reconciling||g_active<0)return;
   g_reconciling=true;
   datetime history_start=(datetime)MathMax((long)g_started,(long)g_trades[g_active].requested-1);
   if(!HistorySelect(history_start,TimeCurrent()+1)){g_reconciling=false;return;}
   // Only the newest record can be active: entries are blocked until it is
   // finalized. Do not rescan every historical trade on every simulated tick.
   for(int i=g_active;i<ArraySize(g_trades);i++)
     {
      if(g_trades[i].finalized)continue;
      TripleMATradeRow t=g_trades[i];
      if(!t.registered)
        {
         double total=0,weighted=0;ulong pid=0,order=t.order;datetime first=0;
         for(int j=0;j<HistoryDealsTotal();j++)
           {
            ulong deal=HistoryDealGetTicket(j);if(deal==0)continue;
            if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagicNumber||HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol||
               (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
            if((ENUM_DEAL_TYPE)HistoryDealGetInteger(deal,DEAL_TYPE)!=(t.direction==1?DEAL_TYPE_BUY:DEAL_TYPE_SELL))continue;
            ulong deal_order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
            if(order>0&&deal_order!=order)continue;
            if(order==0&&(HistoryDealGetString(deal,DEAL_COMMENT)!=t.comment||HistoryDealGetInteger(deal,DEAL_TIME)<t.requested))continue;
            ulong deal_pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
            if(pid>0&&pid!=deal_pid){TMError("Ambiguous entry position; trading remains blocked.");g_reconciling=false;return;}
            pid=deal_pid;order=deal_order;
            double volume=HistoryDealGetDouble(deal,DEAL_VOLUME);total+=volume;weighted+=volume*HistoryDealGetDouble(deal,DEAL_PRICE);
            datetime dt=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);if(first==0||dt<first)first=dt;
           }
         // HistoryOrderSelect can change the selected order list, not deal history.
         if(total<=0||!TMOrderFinished(order))continue;
         double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
         double filled_order=HistoryOrderGetDouble(order,ORDER_VOLUME_INITIAL)-HistoryOrderGetDouble(order,ORDER_VOLUME_CURRENT);
         if(MathAbs(total-filled_order)>step*0.01||total>t.requested_volume+step*0.01)continue;
         t.order=order;t.position=pid;t.volume=total;t.fill=weighted/total;t.opened=first;
         t.fill_target=g_symbol.NormalizePrice(TripleMATarget(t.direction,t.fill,t.sl,InpTargetR));
         double profit=0;
         if(!TripleMAProtectionValid(t.direction,t.fill,t.sl,t.fill_target)||!OrderCalcProfit(t.direction==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,t.volume,t.fill,t.sl,profit)||profit>=0)
           {TMError("Invalid actual fill/risk; trading remains blocked.");g_reconciling=false;return;}
         t.risk=-profit;t.registered=true;t.status="OPEN";
         TMOutcome(t.signal_index,"EXECUTED","ENTRY_CONFIRMED");
        }
      ulong ticket=TMSelectPosition(t.position);
      if(ticket>0)
        {
         double tolerance=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*0.1;
         if(!t.protection_ok)
           {
            if(MathAbs(PositionGetDouble(POSITION_SL)-t.sl)>tolerance||MathAbs(PositionGetDouble(POSITION_TP)-t.fill_target)>tolerance)
               g_trade.PositionModify(ticket,t.sl,t.fill_target);
            ticket=TMSelectPosition(t.position);
            if(ticket>0)t.protection_ok=(MathAbs(PositionGetDouble(POSITION_SL)-t.sl)<=tolerance&&MathAbs(PositionGetDouble(POSITION_TP)-t.fill_target)<=tolerance);
            if(t.protection_ok)
              {t.tp=t.fill_target;if(g_pending==i)g_pending=-1;Print("[TripleMA][PROTECTED] position=",t.position," fill=",t.fill," SL=",t.sl," TP=",t.tp);}
            else TMError("Waiting for broker confirmation of fill-based SL/TP; no new entry.");
           }
         g_trades[i]=t;continue;
        }
      // A fast SL/TP can close the position before its entry callback arrives.
      double exits=0,exit_weight=0;t.gross=0;t.commission=0;t.swap=0;t.fee=0;
      for(int j=0;j<HistoryDealsTotal();j++)
        {
         ulong deal=HistoryDealGetTicket(j);if(deal==0||(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID)!=t.position)continue;
         t.gross+=HistoryDealGetDouble(deal,DEAL_PROFIT);t.commission+=HistoryDealGetDouble(deal,DEAL_COMMISSION);
         t.swap+=HistoryDealGetDouble(deal,DEAL_SWAP);t.fee+=HistoryDealGetDouble(deal,DEAL_FEE);
         ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
         if(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY)
           {
            double volume=HistoryDealGetDouble(deal,DEAL_VOLUME);exits+=volume;exit_weight+=volume*HistoryDealGetDouble(deal,DEAL_PRICE);
            datetime dt=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);if(dt>=t.closed)
              {
               t.closed=dt;ENUM_DEAL_REASON reason=(ENUM_DEAL_REASON)HistoryDealGetInteger(deal,DEAL_REASON);
               if(reason==DEAL_REASON_SL)t.reason="SL";else if(reason==DEAL_REASON_TP)t.reason="TP";
               else if(t.reason!="WEEKEND_FLAT")t.reason="OTHER_OR_TEST_END";
              }
           }
        }
      if(t.closed>0&&MathAbs(exits-t.volume)<=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)*0.01)
        {t.exit_price=exit_weight/exits;t.status="FINALIZED";t.finalized=true;if(g_pending==i)g_pending=-1;g_active=-1;}
      g_trades[i]=t;
     }
   g_reconciling=false;
  }

void TMFlattenWeekend()
  {
   if(!TMWeekendBlocked()||TimeCurrent()==g_last_close_attempt)return;
   g_last_close_attempt=TimeCurrent();
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0||(ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber||PositionGetString(POSITION_SYMBOL)!=_Symbol)continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      for(int j=0;j<ArraySize(g_trades);j++)if(g_trades[j].position==pid)g_trades[j].reason="WEEKEND_FLAT";
      if(!g_trade.PositionClose(ticket)||g_trade.ResultRetcode()!=TRADE_RETCODE_DONE)TMError("Weekend close not confirmed; will retry while ticks/time advance.");
     }
  }

void TMEnter(const int signal_index)
  {
   TripleMASignalRow s=g_signals[signal_index];
   if((s.direction==1&&!InpAllowLong)||(s.direction==-1&&!InpAllowShort)){TMOutcome(signal_index,"SAFETY_REJECTED","DIRECTION_DISABLED");return;}
   if(TMWeekendBlocked()){TMOutcome(signal_index,"SAFETY_REJECTED","WEEKEND_CUTOFF");return;}
   if(g_active>=0||g_pending>=0||PositionsTotal()>0||OrdersTotal()>0){TMOutcome(signal_index,"POSITION_REJECTED","POSITION_ORDER_OR_CONFIRMATION_PENDING");return;}
   if(!g_symbol.Refresh(_Symbol)){TMOutcome(signal_index,"SAFETY_REJECTED","SYMBOL_DATA");return;}
   MqlTick quote;E2SymbolSpecification spec=g_symbol.Specification();
   if(!SymbolInfoTick(_Symbol,quote)||quote.ask<=0||quote.bid<=0||quote.ask<quote.bid||TimeCurrent()-quote.time>10||quote.time>TimeCurrent())
     {TMOutcome(signal_index,"SAFETY_REJECTED","QUOTE_UNAVAILABLE_OR_STALE");return;}
   if((quote.ask-quote.bid)/spec.point>InpMaxSpreadPoints){TMOutcome(signal_index,"SAFETY_REJECTED","SPREAD");return;}
   double entry=(s.direction==1?quote.ask:quote.bid);
   double distance=(InpStopMode==TRIPLE_MA_ATR?s.atr*InpATRMultiplier:InpFixedStopPoints*spec.point);
   double minimum=(MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))+1)*spec.point;
   double raw_sl=(s.direction==1?MathMin(entry-distance,quote.bid-minimum):MathMax(entry+distance,quote.ask+minimum));
   double sl=NormalizeDouble((s.direction==1?MathFloor(raw_sl/spec.tick_size):MathCeil(raw_sl/spec.tick_size))*spec.tick_size,spec.digits);
   double tp=g_symbol.NormalizePrice(TripleMATarget(s.direction,entry,sl,InpTargetR));
   if(!TripleMAProtectionValid(s.direction,entry,sl,tp)||(s.direction==1?tp-quote.bid:quote.ask-tp)<minimum)
     {TMOutcome(signal_index,"SIZING_REJECTED","INVALID_OR_TOO_CLOSE_SL_TP");return;}
   double requested=(InpRiskMode==TRIPLE_MA_FIXED_CASH?InpFixedCashRisk:AccountInfoDouble(ACCOUNT_BALANCE)*InpBalanceRiskPercent/100.0);
   ENUM_ORDER_TYPE type=(s.direction==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double loss=0,volume=0,actual=0,margin=0;
   if(!OrderCalcProfit(type,_Symbol,spec.volume_min,entry,sl,loss)||loss>=0||!g_symbol.NormalizeVolume(requested/(-loss/spec.volume_min),volume)||
      !OrderCalcProfit(type,_Symbol,volume,entry,sl,actual)||!TripleMARiskWithinBudget(-actual,requested))
     {TMOutcome(signal_index,"SIZING_REJECTED","RISK_OR_MINIMUM_LOT");return;}
   if(!OrderCalcMargin(type,_Symbol,volume,entry,margin)||margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {TMOutcome(signal_index,"SIZING_REJECTED","INSUFFICIENT_MARGIN");return;}
   TripleMATradeRow t;ZeroMemory(t);t.signal_index=signal_index;t.direction=s.direction;t.sl=sl;t.tp=tp;
   t.requested=TimeCurrent();t.requested_volume=volume;t.status="PENDING";t.comment="TMA_"+IntegerToString(signal_index);
   int n=ArraySize(g_trades);ArrayResize(g_trades,n+1);g_trades[n]=t;g_pending=n;g_active=n;
   // Never submit a second order to resolve an uncertain result. Both protection
   // prices are part of this initial request, before deal history is consulted.
   bool sent=(s.direction==1?g_trade.Buy(volume,_Symbol,entry,sl,tp,t.comment):g_trade.Sell(volume,_Symbol,entry,sl,tp,t.comment));
   uint code=g_trade.ResultRetcode();g_trades[n].order=g_trade.ResultOrder();
   if(code==TRADE_RETCODE_DONE||code==TRADE_RETCODE_DONE_PARTIAL||code==TRADE_RETCODE_PLACED)
      TMOutcome(signal_index,"OTHER_REJECTED","AWAITING_ENTRY_CONFIRMATION");
   else if(code==TRADE_RETCODE_TIMEOUT||code==TRADE_RETCODE_CONNECTION||code==0||g_trade.ResultOrder()>0||g_trade.ResultDeal()>0)
      {TMOutcome(signal_index,"OTHER_REJECTED","UNCERTAIN_ORDER_RESULT");TMError("Uncertain entry; no resubmission and no new entries.");}
   else
     {g_pending=-1;g_active=-1;g_trades[n].finalized=true;g_trades[n].status="REJECTED";TMOutcome(signal_index,"EXECUTION_FAILED","RETCODE_"+IntegerToString(code));}
   if(!sent)Print("[TripleMA] send result: ",g_trade.ResultRetcodeDescription());
   TMReconcile();
  }

void OnTick()
  {
   if(!g_ready)return;
   TMReconcile();TMFlattenWeekend();TMReconcile();
   datetime current=iTime(_Symbol,_Period,0);if(current<=0||current==g_bar)return;
   if(TimeCurrent()-current>InpMaxEntryDelaySeconds){g_bar=current;return;}
   int seconds=PeriodSeconds(_Period);
   if(iTime(_Symbol,_Period,1)+seconds!=current){g_bar=current;return;}
   if(BarsCalculated(g_fast)<InpSlowMA+2||BarsCalculated(g_medium)<InpSlowMA+2||BarsCalculated(g_slow)<InpSlowMA+2)return;
   double fast[2],medium[2],slow[1],atr[1];
   // Fixed arrays use physical order: shift 2 first, shift 1 second.
   if(CopyBuffer(g_fast,0,1,2,fast)!=2||CopyBuffer(g_medium,0,1,2,medium)!=2||CopyBuffer(g_slow,0,1,1,slow)!=1)return;
   atr[0]=0;
   if(InpStopMode==TRIPLE_MA_ATR&&(CopyBuffer(g_atr,0,1,1,atr)!=1||atr[0]<=0||!MathIsValidNumber(atr[0])))return;
   for(int i=0;i<2;i++)if(!MathIsValidNumber(fast[i])||!MathIsValidNumber(medium[i])||fast[i]==EMPTY_VALUE||medium[i]==EMPTY_VALUE)return;
   if(!MathIsValidNumber(slow[0])||slow[0]==EMPTY_VALUE)return;
   g_bar=current;
   int direction=TripleMASignal(fast[0],medium[0],fast[1],medium[1],slow[0]);if(direction==0)return;
   TripleMASignalRow s;ZeroMemory(s);s.time=iTime(_Symbol,_Period,1);s.direction=direction;
   s.id="TRIPLE_MA|"+_Symbol+"|"+EnumToString(_Period)+"|"+IntegerToString((long)s.time)+"|"+TMDirection(direction);
   s.fp=fast[0];s.mp=medium[0];s.fc=fast[1];s.mc=medium[1];s.sc=slow[0];s.atr=atr[0];
   s.status="OTHER_REJECTED";s.reason="OUTCOME_PENDING";
   int n=ArraySize(g_signals);ArrayResize(g_signals,n+1);g_signals[n]=s;TMEnter(n);
  }
void OnTimer(){if(g_ready){TMReconcile();TMFlattenWeekend();}}
void OnTradeTransaction(const MqlTradeTransaction &transaction,const MqlTradeRequest &request,const MqlTradeResult &result)
  {if(g_ready&&(transaction.type==TRADE_TRANSACTION_DEAL_ADD||transaction.type==TRADE_TRANSACTION_HISTORY_ADD))TMReconcile();}

void TMExport()
  {
   if(!InpCsvExport||MQLInfoInteger(MQL_OPTIMIZATION))return;
   FolderCreate("E2\\Reports\\TripleMA",FILE_COMMON);
   string filename="E2\\Reports\\TripleMA\\E2_TripleMA_"+g_config+"_"+g_file_token;
   string base=filename;int suffix=0;
   while(FileIsExist(filename+"_S.csv",FILE_COMMON)||FileIsExist(filename+"_T.csv",FILE_COMMON))filename=base+"_"+IntegerToString(++suffix);
   // File names are private to each test run; the explicit run_id is in both CSVs.
   E2CsvExporter signals,trades;
   if(signals.Initialize(filename+"_S.csv",g_logger))
     {
      string header[]={"schema_version","run_id","config_hash","candidate_id","strategy","symbol","timeframe","direction","signal_bar_time","candidate_status","candidate_reason","fast_previous","medium_previous","fast_current","medium_current","slow_current","atr"};
      if(!signals.WriteHeader(header))g_errors++;
      for(int i=0;i<ArraySize(g_signals);i++)
        {TripleMASignalRow s=g_signals[i];string row[]={"E2_JOURNAL_V1",g_run,g_config,s.id,"TRIPLE_MA",_Symbol,EnumToString(_Period),TMDirection(s.direction),TMTime(s.time),s.status,s.reason,TMNumber(s.fp),TMNumber(s.mp),TMNumber(s.fc),TMNumber(s.mc),TMNumber(s.sc),TMNumber(s.atr)};if(!signals.WriteRow(row))g_errors++;}
      signals.Close();
     }
   else g_errors++;
   if(trades.Initialize(filename+"_T.csv",g_logger))
     {
      string header[]={"schema_version","run_id","config_hash","trade_id","candidate_id","strategy","symbol","timeframe","direction","fill_time","exit_time","net_profit","actual_initial_cash_risk","trade_status","gross_profit","commission","swap","fee","realized_r","submitted_initial_sl","submitted_tp","actual_fill","filled_volume","exit_price","exit_reason","integrity_flags"};
      if(!trades.WriteHeader(header))g_errors++;
      for(int i=0;i<ArraySize(g_trades);i++)
        {
         TripleMATradeRow t=g_trades[i];if(t.status!="FINALIZED")continue;
         double net=t.gross+t.commission+t.swap+t.fee;
         string row[]={"E2_JOURNAL_V1",g_run,g_config,StringFormat("%I64u",t.position),g_signals[t.signal_index].id,"TRIPLE_MA",_Symbol,EnumToString(_Period),TMDirection(t.direction),TMTime(t.opened),TMTime(t.closed),TMNumber(net),TMNumber(t.risk),"FINALIZED",TMNumber(t.gross),TMNumber(t.commission),TMNumber(t.swap),TMNumber(t.fee),TMNumber(net/t.risk),TMNumber(t.sl),TMNumber(t.tp),TMNumber(t.fill),TMNumber(t.volume),TMNumber(t.exit_price),t.reason,(t.protection_ok?"NONE":"CLOSED_BEFORE_PROTECTION_VERIFIED")};
         if(!trades.WriteRow(row))g_errors++;
        }
      trades.Close();
     }
   else g_errors++;
   Print("[TripleMA][CSV] ",filename,"_S.csv / _T.csv; write_errors=",g_errors);
  }

int OnInit()
  {
   // Research authorization is for historical testing, not live order placement.
   if(!MQLInfoInteger(MQL_TESTER)){Print("[TripleMA] Research EA: Strategy Tester only. No demo/live chart trading.");return(INIT_FAILED);}
   if(PeriodSeconds(_Period)<300||InpFastMA<1||InpFastMA>=InpMediumMA||InpMediumMA>=InpSlowMA||InpSlowMA>2000||InpATRLength<1||InpATRLength>2000||
      !MathIsValidNumber(InpATRMultiplier)||InpATRMultiplier<=0||!MathIsValidNumber(InpFixedStopPoints)||InpFixedStopPoints<=0||
      !MathIsValidNumber(InpTargetR)||InpTargetR<=0||!MathIsValidNumber(InpFixedCashRisk)||InpFixedCashRisk<=0||
      !MathIsValidNumber(InpBalanceRiskPercent)||InpBalanceRiskPercent<=0||InpBalanceRiskPercent>100||InpMagicNumber==0||InpMagicNumber==2026001||
      !MathIsValidNumber(InpMaxSpreadPoints)||InpMaxSpreadPoints<=0||InpMaxEntryDelaySeconds<0||InpMaxEntryDelaySeconds>=PeriodSeconds(_Period)||
      InpMinutesBeforeFridayClose<1||InpMinutesBeforeFridayClose>1440||(!InpAllowLong&&!InpAllowShort)||
      (InpStopMode!=TRIPLE_MA_ATR&&InpStopMode!=TRIPLE_MA_FIXED_POINTS)||(InpRiskMode!=TRIPLE_MA_FIXED_CASH&&InpRiskMode!=TRIPLE_MA_BALANCE_PERCENT)||
      InpMAMethod<MODE_SMA||InpMAMethod>MODE_LWMA||InpMAPrice<PRICE_CLOSE||InpMAPrice>PRICE_WEIGHTED||StringLen(InpRunLabel)>40)
      {Print("[TripleMA] Invalid inputs. Require 0 < fast < medium < slow, M5+, positive risk/stops/TP and distinct magic.");return(INIT_PARAMETERS_INCORRECT);}
   g_logger.Initialize(true,false);if(!g_symbol.Initialize(_Symbol,g_logger))return(INIT_FAILED);
   g_fast=iMA(_Symbol,_Period,InpFastMA,0,InpMAMethod,InpMAPrice);
   g_medium=iMA(_Symbol,_Period,InpMediumMA,0,InpMAMethod,InpMAPrice);
   g_slow=iMA(_Symbol,_Period,InpSlowMA,0,InpMAMethod,InpMAPrice);
   if(InpStopMode==TRIPLE_MA_ATR)g_atr=iATR(_Symbol,_Period,InpATRLength);
   if(g_fast==INVALID_HANDLE||g_medium==INVALID_HANDLE||g_slow==INVALID_HANDLE||(InpStopMode==TRIPLE_MA_ATR&&g_atr==INVALID_HANDLE))return(INIT_FAILED);
   g_trade.SetExpertMagicNumber(InpMagicNumber);g_trade.SetDeviationInPoints(InpDeviationPoints);g_trade.SetAsyncMode(false);
   if(!g_trade.SetTypeFillingBySymbol(_Symbol))return(INIT_FAILED);
   string settings=StringFormat("TRIPLE_MA_V1|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%.10f|%.10f|%.10f|%d|%.10f|%.10f|%I64u|%.10f|%u|%d|%d|%d",
      _Symbol,(int)_Period,InpFastMA,InpMediumMA,InpSlowMA,(int)InpMAMethod,(int)InpMAPrice,(int)InpAllowLong,(int)InpAllowShort,(int)InpStopMode,InpATRLength,
      InpATRMultiplier,InpFixedStopPoints,InpTargetR,(int)InpRiskMode,InpFixedCashRisk,InpBalanceRiskPercent,InpMagicNumber,InpMaxSpreadPoints,InpDeviationPoints,InpMaxEntryDelaySeconds,(int)InpWeekendFlat,InpMinutesBeforeFridayClose);
   g_config=StringFormat("%08X",TripleMAHash(settings));g_started=TimeCurrent();
   g_file_token=StringFormat("%08X",TripleMAHash(TerminalInfoString(TERMINAL_DATA_PATH)))+"_"+IntegerToString((long)TimeLocal())+"_"+IntegerToString((long)GetTickCount64())+"_"+IntegerToString((long)GetMicrosecondCount());
   g_run=TMTime(g_started)+"_"+g_config+"_"+g_file_token+"_"+InpRunLabel;
   g_bar=iTime(_Symbol,_Period,0);g_ready=true;
   if(!EventSetTimer(1)){g_ready=false;return(INIT_FAILED);}
   Print("[TripleMA][CONFIG] ",settings," run_id=",g_run);
   if(MQLInfoInteger(MQL_OPTIMIZATION)&&InpCsvExport)Print("[TripleMA] CSV export disabled during optimization; rerun an individual test for reports.");
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_ready)
     {
      TMReconcile();int closed=0,open=0;
      for(int i=0;i<ArraySize(g_trades);i++){if(g_trades[i].status=="FINALIZED")closed++;else if(!g_trades[i].finalized)open++;}
      TMExport();Print("[TripleMA][SUMMARY] candidates=",ArraySize(g_signals)," finalized=",closed," open_or_unresolved=",open," csv_errors=",g_errors);
     }
   g_ready=false;
   if(g_fast!=INVALID_HANDLE)IndicatorRelease(g_fast);if(g_medium!=INVALID_HANDLE)IndicatorRelease(g_medium);
   if(g_slow!=INVALID_HANDLE)IndicatorRelease(g_slow);if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr);
  }
