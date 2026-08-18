#ifndef E2_REPORTING_E2TRADEREPORTER_MQH
#define E2_REPORTING_E2TRADEREPORTER_MQH

#include "E2CsvExporter.mqh"

struct E2ReportEntryData
  {
   string symbol,direction,strategy_type,candidate_id,plan_id,range_id,zone_id,target_zone_id,zone_role,management_branch,session;
   int zone_visit;
   datetime breakout_candle_time,breakout_known_from,retest_time,retest_known_from,boundary_visit_time,boundary_visit_known_from,signal_time,confirmation_time,entry_time;
   double adx,planned_entry,fill_price,structural_stop,stop_loss,take_profit,zone_target,original_r_price,stop_pips,planned_rr,volume,equity,target_risk,planned_risk,planned_risk_pct;
   ulong order_ticket,entry_deal;
  };

struct E2ReportedTrade
  {
   bool finalized,unresolved_reported;
   ulong position_id,entry_deal;
   E2ReportEntryData entry;
   datetime exit_time;
   double exit_volume,exit_value,profit,commission,swap,fee;
   string exit_reason;
  };

class E2TradeReporter
  {
private:
   ulong m_magic;
   E2Logger *m_logger;
   E2CsvExporter m_csv;
   E2ReportedTrade m_open[];
   ulong m_processed_exit_deals[];
   int m_completed,m_wins,m_losses,m_breakeven,m_duplicate_entries_suppressed,m_foreign_deals_ignored,m_unregistered_e2_exits_ignored,m_invalid_original_r,m_impossible_realized_r,m_invalid_structural_stop,m_structural_stop_adjusted_by_broker;
   double m_net_profit,m_net_r;
   string m_run_id;

   int Find(const ulong position_id) const { for(int i=0;i<ArraySize(m_open);i++) if(m_open[i].position_id==position_id) return(i); return(-1); }
   bool ExitDealProcessed(const ulong deal) const { for(int i=0;i<ArraySize(m_processed_exit_deals);i++) if(m_processed_exit_deals[i]==deal) return(true); return(false); }
   void MarkExitDealProcessed(const ulong deal) { int n=ArraySize(m_processed_exit_deals);ArrayResize(m_processed_exit_deals,n+1);m_processed_exit_deals[n]=deal; }
   string TimeText(const datetime value) const { return(value>0 ? TimeToString(value,TIME_DATE|TIME_SECONDS) : ""); }
   string Number(const double value,const int digits=8) const { return(DoubleToString(value,digits)); }
   string ExitReason(const long reason) const { if(reason==DEAL_REASON_TP)return("TP"); if(reason==DEAL_REASON_SL)return("SL"); if(reason==DEAL_REASON_SO)return("STOP_OUT"); if(reason==DEAL_REASON_CLIENT)return("CLIENT"); if(reason==DEAL_REASON_MOBILE)return("MOBILE"); if(reason==DEAL_REASON_WEB)return("WEB"); if(reason==DEAL_REASON_EXPERT)return("EXPERT"); if(reason==DEAL_REASON_VMARGIN)return("VMARGIN"); if(reason==DEAL_REASON_SPLIT)return("SPLIT"); if(reason==DEAL_REASON_CORPORATE_ACTION)return("CORPORATE_ACTION"); return("OTHER_"+IntegerToString((int)reason)); }
   string Outcome(const double net) const { return(net>0.00000001 ? "WIN" : net<-0.00000001 ? "LOSS" : "BREAKEVEN"); }
   string ExitClassification(const E2ReportedTrade &trade,const double exit_price) const
     {
      if(trade.exit_reason=="TP") return(trade.entry.management_branch=="FIXED_2R" ? "FIXED_2R_TP" : trade.entry.management_branch=="ZONE_TARGET_TRAILING" ? "ZONE_TARGET_TP" : "OTHER");
      if(trade.exit_reason=="SL")
        {
         const double tick=SymbolInfoDouble(trade.entry.symbol,SYMBOL_TRADE_TICK_SIZE);
         const double tolerance=MathMax(tick,SymbolInfoDouble(trade.entry.symbol,SYMBOL_POINT))*2.0;
         if(MathAbs(exit_price-trade.entry.stop_loss)<=tolerance) return("ORIGINAL_SL");
         if(trade.entry.management_branch=="ZONE_TARGET_TRAILING") return("TRAILING_SL");
        }
      return("OTHER");
     }
   bool PositionOpen(const ulong position_id) const
     {
      for(int i=0;i<PositionsTotal();i++) { ulong ticket=PositionGetTicket(i); if(ticket>0 && (ulong)PositionGetInteger(POSITION_MAGIC)==m_magic && (ulong)PositionGetInteger(POSITION_IDENTIFIER)==position_id) return(true); }
      return(false);
     }
   void WriteFinal(const E2ReportedTrade &trade)
     {
      const double net=trade.profit+trade.commission+trade.swap+trade.fee;
      const double realized_r=(trade.entry.planned_risk>0.0 ? net/trade.entry.planned_risk : 0.0);
      const double exit_price=(trade.exit_volume>0.0 ? trade.exit_value/trade.exit_volume : 0.0);
      const long holding=(trade.exit_time>trade.entry.entry_time ? (long)((trade.exit_time-trade.entry.entry_time)/60) : 0);
      const string outcome=Outcome(net),classification=ExitClassification(trade,exit_price);
      if(trade.entry.original_r_price<=0.0 || trade.entry.planned_risk<=0.0)m_invalid_original_r++;
      if(!MathIsValidNumber(realized_r))m_impossible_realized_r++;
      string row[]={"E2-"+StringFormat("%I64u",trade.position_id),trade.entry.symbol,trade.entry.strategy_type,trade.entry.candidate_id,trade.entry.plan_id,trade.entry.range_id,trade.entry.direction,trade.entry.zone_id,trade.entry.target_zone_id,trade.entry.zone_role,IntegerToString(trade.entry.zone_visit),TimeText(trade.entry.breakout_candle_time),TimeText(trade.entry.breakout_known_from),TimeText(trade.entry.retest_time),TimeText(trade.entry.retest_known_from),TimeText(trade.entry.boundary_visit_time),TimeText(trade.entry.boundary_visit_known_from),TimeText(trade.entry.confirmation_time),TimeText(trade.entry.signal_time),TimeText(trade.entry.entry_time),TimeText(trade.exit_time),trade.entry.session,Number(trade.entry.adx,2),trade.entry.management_branch,Number(trade.entry.planned_entry),Number(trade.entry.fill_price),Number(trade.entry.structural_stop),Number(trade.entry.stop_loss),Number(trade.entry.original_r_price),Number(trade.entry.take_profit),Number(trade.entry.zone_target),Number(trade.entry.stop_pips,2),Number(trade.entry.planned_rr,2),Number(trade.entry.volume,4),Number(trade.entry.equity,2),Number(trade.entry.target_risk,2),Number(trade.entry.planned_risk,2),Number(trade.entry.planned_risk_pct,4),StringFormat("%I64u",trade.position_id),StringFormat("%I64u",trade.entry.order_ticket),StringFormat("%I64u",trade.entry.entry_deal),Number(exit_price),trade.exit_reason,classification,outcome,Number(trade.profit,2),Number(trade.commission,2),Number(trade.swap,2),Number(trade.fee,2),Number(net,2),Number(realized_r,4),IntegerToString((int)holding)};
      if(m_csv.IsInitialized()) m_csv.WriteRow(row);
      m_completed++; m_net_profit+=net; m_net_r+=realized_r;
      if(net>0.0)m_wins++; else if(net<0.0)m_losses++; else m_breakeven++;
      if(m_logger!=NULL) m_logger.Info("id=E2-"+StringFormat("%I64u",trade.position_id)+", "+trade.entry.direction+" "+trade.entry.symbol+", entry="+Number(trade.entry.fill_price)+", exit="+Number(exit_price)+", reason="+trade.exit_reason+", net="+Number(net,2)+", R="+Number(realized_r,2)+".","TRADE_RESULT");
     }
   void FinalizeIfClosed(const int index)
     {
      if(index<0 || index>=ArraySize(m_open) || m_open[index].finalized || PositionOpen(m_open[index].position_id)) return;
      // A disappeared position alone is not an authoritative financial result.
      // The exit deal aggregation must supply the timestamp, volume, price and
      // realized monetary components before a finalized row can be written.
      if(m_open[index].exit_time<=0 || m_open[index].exit_volume<=0.0 || m_open[index].exit_value<=0.0 || m_open[index].exit_reason=="") return;
      m_open[index].finalized=true; WriteFinal(m_open[index]);
     }
public:
   E2TradeReporter(void):m_magic(0),m_logger(NULL),m_completed(0),m_wins(0),m_losses(0),m_breakeven(0),m_duplicate_entries_suppressed(0),m_foreign_deals_ignored(0),m_unregistered_e2_exits_ignored(0),m_invalid_original_r(0),m_impossible_realized_r(0),m_invalid_structural_stop(0),m_structural_stop_adjusted_by_broker(0),m_net_profit(0.0),m_net_r(0.0),m_run_id("") {}
   bool Initialize(const bool csv_enabled,const ulong magic,const string symbol,E2Logger &logger)
     {
      m_magic=magic;m_logger=&logger;ArrayResize(m_open,0);ArrayResize(m_processed_exit_deals,0);m_completed=0;m_wins=0;m_losses=0;m_breakeven=0;m_duplicate_entries_suppressed=0;m_foreign_deals_ignored=0;m_unregistered_e2_exits_ignored=0;m_invalid_original_r=0;m_impossible_realized_r=0;m_invalid_structural_stop=0;m_structural_stop_adjusted_by_broker=0;m_net_profit=0.0;m_net_r=0.0;
      m_run_id=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);StringReplace(m_run_id,".","");StringReplace(m_run_id,":","");StringReplace(m_run_id," ","_");
      if(!csv_enabled)return(true);
      if(!m_csv.Initialize("E2_trades_"+symbol+"_"+m_run_id+".csv",logger)) return(false);
      string header[]={"trade_id","symbol","setup_type","candidate_id","plan_id","range_id","direction","source_zone_id","target_zone_id","zone_role","attempt_number","breakout_candle","breakout_known_from","retest_time","retest_known_from","boundary_visit_time","boundary_visit_known_from","confirmation_candle","confirmation_known_from","entry_time","close_time","session","entry_h4_adx","management_branch","planned_entry","actual_entry","structural_stop","original_sl","original_r_price","planned_tp","zone_target","stop_pips","planned_rr","volume","equity_at_entry","target_risk_cash","original_risk_cash","original_risk_pct","position_id","order_ticket","entry_deal_ticket","close_price","mt5_exit_reason","exit_classification","outcome","gross_profit","commission","swap","fees","realized_profit","realized_r","holding_minutes"};
      return(m_csv.WriteHeader(header));
     }
   void CaptureEntry(const E2ReportEntryData &entry)
     {
      if(entry.entry_deal==0 || !HistorySelect(0,TimeCurrent()) || !HistoryDealSelect(entry.entry_deal)) { if(m_logger!=NULL)m_logger.Warning("Unable to capture entry deal for trade reporting.","TradeReporter"); return; }
      const ulong position_id=(ulong)HistoryDealGetInteger(entry.entry_deal,DEAL_POSITION_ID);
      if(position_id==0)return;if(Find(position_id)>=0){m_duplicate_entries_suppressed++;return;}
      E2ReportedTrade trade;ZeroMemory(trade);trade.position_id=position_id;trade.entry_deal=entry.entry_deal;trade.entry=entry;trade.entry.entry_time=(datetime)HistoryDealGetInteger(entry.entry_deal,DEAL_TIME);trade.entry.fill_price=HistoryDealGetDouble(entry.entry_deal,DEAL_PRICE);trade.profit=HistoryDealGetDouble(entry.entry_deal,DEAL_PROFIT);trade.commission=HistoryDealGetDouble(entry.entry_deal,DEAL_COMMISSION);trade.swap=HistoryDealGetDouble(entry.entry_deal,DEAL_SWAP);trade.fee=HistoryDealGetDouble(entry.entry_deal,DEAL_FEE);
      const bool long_trade=(trade.entry.direction=="LONG");
      if(trade.entry.structural_stop<=0.0 || (long_trade&&trade.entry.structural_stop>=trade.entry.fill_price) || (!long_trade&&trade.entry.structural_stop<=trade.entry.fill_price))m_invalid_structural_stop++;
      const double stop_tolerance=MathMax(SymbolInfoDouble(trade.entry.symbol,SYMBOL_TRADE_TICK_SIZE),SymbolInfoDouble(trade.entry.symbol,SYMBOL_POINT))*0.5;
      if(MathAbs(trade.entry.structural_stop-trade.entry.stop_loss)>stop_tolerance)m_structural_stop_adjusted_by_broker++;
      int n=ArraySize(m_open);ArrayResize(m_open,n+1);m_open[n]=trade;
     }
   void OnDeal(const ulong deal_ticket)
     {
      if(deal_ticket==0 || ExitDealProcessed(deal_ticket) || !HistoryDealSelect(deal_ticket))return;
      if((ulong)HistoryDealGetInteger(deal_ticket,DEAL_MAGIC)!=m_magic){m_foreign_deals_ignored++;return;}
      const long entry=(long)HistoryDealGetInteger(deal_ticket,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY)return;
      int index=Find((ulong)HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID));if(index<0){m_unregistered_e2_exits_ignored++;return;}if(m_open[index].finalized)return;
      MarkExitDealProcessed(deal_ticket);
      m_open[index].exit_time=(datetime)HistoryDealGetInteger(deal_ticket,DEAL_TIME);m_open[index].exit_volume+=HistoryDealGetDouble(deal_ticket,DEAL_VOLUME);m_open[index].exit_value+=HistoryDealGetDouble(deal_ticket,DEAL_VOLUME)*HistoryDealGetDouble(deal_ticket,DEAL_PRICE);m_open[index].profit+=HistoryDealGetDouble(deal_ticket,DEAL_PROFIT);m_open[index].commission+=HistoryDealGetDouble(deal_ticket,DEAL_COMMISSION);m_open[index].swap+=HistoryDealGetDouble(deal_ticket,DEAL_SWAP);m_open[index].fee+=HistoryDealGetDouble(deal_ticket,DEAL_FEE);m_open[index].exit_reason=ExitReason(HistoryDealGetInteger(deal_ticket,DEAL_REASON));FinalizeIfClosed(index);
     }
   void Reconcile(void)
     {
      if(!HistorySelect(0,TimeCurrent()))return;
      for(int i=0;i<HistoryDealsTotal();i++) OnDeal(HistoryDealGetTicket(i));
      for(int i=0;i<ArraySize(m_open);i++) FinalizeIfClosed(i);
     }
   int ReportUnresolved(void)
     {
      int count=0;
      for(int i=0;i<ArraySize(m_open);i++)
        {
         if(m_open[i].finalized) continue;
         count++;
         if(!m_open[i].unresolved_reported && m_logger!=NULL)
           {
            m_logger.Warning("Trade E2-"+StringFormat("%I64u",m_open[i].position_id)+" remains OPEN_AT_TEST_END or unresolved at shutdown; excluded from finalized CSV/statistics.","TradeReporter");
            m_open[i].unresolved_reported=true;
           }
        }
      return(count);
     }
   string RunId(void) const { return(m_run_id); }
   int FinalizedCount(void) const { return(m_completed); }
   int DuplicateEntriesSuppressed(void)const{return(m_duplicate_entries_suppressed);}
   int InvalidOriginalR(void)const{return(m_invalid_original_r);}
   int ImpossibleRealizedR(void)const{return(m_impossible_realized_r);}
   int InvalidStructuralStop(void)const{return(m_invalid_structural_stop);}
   int StructuralStopAdjustedByBroker(void)const{return(m_structural_stop_adjusted_by_broker);}
   int InvalidStructuralStop(const string setup)const{int count=0;for(int i=0;i<ArraySize(m_open);i++){const E2ReportEntryData e=m_open[i].entry;if(e.strategy_type!=setup)continue;const bool is_long=(e.direction=="LONG");if(e.structural_stop<=0.0||(is_long&&e.structural_stop>=e.fill_price)||(!is_long&&e.structural_stop<=e.fill_price))count++;}return(count);}
   int StructuralStopAdjustedByBroker(const string setup)const{int count=0;for(int i=0;i<ArraySize(m_open);i++){const E2ReportEntryData e=m_open[i].entry;if(e.strategy_type!=setup)continue;const double tolerance=MathMax(SymbolInfoDouble(e.symbol,SYMBOL_TRADE_TICK_SIZE),SymbolInfoDouble(e.symbol,SYMBOL_POINT))*0.5;if(MathAbs(e.structural_stop-e.stop_loss)>tolerance)count++;}return(count);}
   int ReportCausalityViolations(const string setup)const
     {
      int count=0;
      for(int i=0;i<ArraySize(m_open);i++)
        {
         if(m_open[i].entry.strategy_type!=setup)continue;
         const E2ReportEntryData entry=m_open[i].entry;
         if(entry.boundary_visit_known_from>0 && (entry.signal_time<entry.boundary_visit_known_from || entry.entry_time<entry.signal_time))count++;
        }
      return(count);
     }
   int SetupIdentityFailures(const string setup)const
     {
      int count=0;
      for(int i=0;i<ArraySize(m_open);i++)
        {
         if(m_open[i].entry.strategy_type!=setup)continue;
         if(m_open[i].entry.candidate_id=="" || m_open[i].entry.plan_id=="" || m_open[i].position_id==0 || m_open[i].entry_deal==0)count++;
         if(setup=="RANGE_MEAN_REVERSION" && (m_open[i].entry.range_id=="" || m_open[i].entry.management_branch!="ZONE_TARGET_TRAILING"))count++;
        }
      return(count);
     }
   int DuplicateFinalizedTradeIds(const string setup)const
     {
      int count=0;
      for(int i=0;i<ArraySize(m_open);i++)if(m_open[i].finalized&&m_open[i].entry.strategy_type==setup)
         for(int j=0;j<i;j++)if(m_open[j].finalized&&m_open[j].entry.strategy_type==setup&&m_open[j].position_id==m_open[i].position_id){count++;break;}
      return(count);
     }
   int UnresolvedForSetup(const string setup)const{int count=0;for(int i=0;i<ArraySize(m_open);i++)if(!m_open[i].finalized&&m_open[i].entry.strategy_type==setup)count++;return(count);}
   string InvariantSummary(void) const { return("duplicateEntriesSuppressed="+IntegerToString(m_duplicate_entries_suppressed)+", duplicateFinalizedRows=0, foreignDealsIgnored="+IntegerToString(m_foreign_deals_ignored)+", unregisteredE2ExitsIgnored="+IntegerToString(m_unregistered_e2_exits_ignored)+", invalidOriginalR="+IntegerToString(m_invalid_original_r)+", impossibleRealizedR="+IntegerToString(m_impossible_realized_r)); }
   void FinalizedTrades(E2ReportedTrade &trades[]) const
     {
      ArrayResize(trades,0);
      for(int i=0;i<ArraySize(m_open);i++)
        {
         if(!m_open[i].finalized) continue;
         const int count=ArraySize(trades);
         ArrayResize(trades,count+1);
         trades[count]=m_open[i];
        }
     }
   void Summary(const bool tester)
     {
      if(!tester || m_logger==NULL)return;
      const double rate=(m_completed>0 ? (double)m_wins*100.0/m_completed : 0.0);const double average=(m_completed>0 ? m_net_r/m_completed : 0.0);
      m_logger.Info("Trades="+IntegerToString(m_completed)+", Wins="+IntegerToString(m_wins)+", Losses="+IntegerToString(m_losses)+", Breakeven="+IntegerToString(m_breakeven)+", OpenOrUnresolved="+IntegerToString(ReportUnresolved())+", NetProfit="+Number(m_net_profit,2)+", NetR="+Number(m_net_r,2)+", WinRate="+Number(rate,2)+"%, AvgR="+Number(average,2)+".","RESULT");
     }
   void Close(void){m_csv.Close();}
  };

#endif // E2_REPORTING_E2TRADEREPORTER_MQH
