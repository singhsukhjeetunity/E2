#ifndef E2_REPORTING_E2TRADEREPORTER_MQH
#define E2_REPORTING_E2TRADEREPORTER_MQH

#include "E2CsvExporter.mqh"

struct E2ReportEntryData
  {
   string symbol,direction,strategy_type,candidate_id,plan_id,zone_id,target_zone_id,zone_role,management_branch,session;
   int zone_visit;
   datetime signal_time,confirmation_time,entry_time;
   double adx,planned_entry,fill_price,stop_loss,take_profit,stop_pips,planned_rr,volume,equity,target_risk,planned_risk,planned_risk_pct;
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
   int m_completed,m_wins,m_losses,m_breakeven;
   double m_net_profit,m_net_r;
   string m_run_id;

   int Find(const ulong position_id) const { for(int i=0;i<ArraySize(m_open);i++) if(m_open[i].position_id==position_id) return(i); return(-1); }
   bool ExitDealProcessed(const ulong deal) const { for(int i=0;i<ArraySize(m_processed_exit_deals);i++) if(m_processed_exit_deals[i]==deal) return(true); return(false); }
   void MarkExitDealProcessed(const ulong deal) { int n=ArraySize(m_processed_exit_deals);ArrayResize(m_processed_exit_deals,n+1);m_processed_exit_deals[n]=deal; }
   string TimeText(const datetime value) const { return(value>0 ? TimeToString(value,TIME_DATE|TIME_SECONDS) : ""); }
   string Number(const double value,const int digits=8) const { return(DoubleToString(value,digits)); }
   string ExitReason(const long reason) const { if(reason==DEAL_REASON_TP)return("TP"); if(reason==DEAL_REASON_SL)return("SL"); if(reason==DEAL_REASON_SO)return("STOP_OUT"); if(reason==DEAL_REASON_CLIENT)return("CLIENT"); if(reason==DEAL_REASON_MOBILE)return("MOBILE"); if(reason==DEAL_REASON_WEB)return("WEB"); if(reason==DEAL_REASON_EXPERT)return("EXPERT"); if(reason==DEAL_REASON_VMARGIN)return("VMARGIN"); if(reason==DEAL_REASON_SPLIT)return("SPLIT"); if(reason==DEAL_REASON_CORPORATE_ACTION)return("CORPORATE_ACTION"); return("OTHER_"+IntegerToString((int)reason)); }
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
      string row[]={"E2-"+StringFormat("%I64u",trade.position_id),trade.entry.symbol,trade.entry.strategy_type,trade.entry.candidate_id,trade.entry.plan_id,trade.entry.direction,trade.entry.zone_id,trade.entry.target_zone_id,trade.entry.zone_role,IntegerToString(trade.entry.zone_visit),trade.entry.management_branch,TimeText(trade.entry.signal_time),TimeText(trade.entry.confirmation_time),TimeText(trade.entry.entry_time),TimeText(trade.exit_time),trade.entry.session,Number(trade.entry.planned_entry),Number(trade.entry.fill_price),Number(trade.entry.stop_loss),Number(trade.entry.take_profit),Number(trade.entry.stop_pips,2),Number(trade.entry.planned_rr,2),Number(trade.entry.volume,4),Number(trade.entry.equity,2),Number(trade.entry.target_risk,2),Number(trade.entry.planned_risk,2),Number(trade.entry.planned_risk_pct,4),Number(exit_price),trade.exit_reason,Number(trade.profit,2),Number(trade.commission,2),Number(trade.swap,2),Number(trade.fee,2),Number(net,2),Number(realized_r,4),IntegerToString((int)holding)};
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
   E2TradeReporter(void):m_magic(0),m_logger(NULL),m_completed(0),m_wins(0),m_losses(0),m_breakeven(0),m_net_profit(0.0),m_net_r(0.0),m_run_id("") {}
   bool Initialize(const bool csv_enabled,const ulong magic,const string symbol,E2Logger &logger)
     {
      m_magic=magic;m_logger=&logger;ArrayResize(m_open,0);ArrayResize(m_processed_exit_deals,0);m_completed=0;m_wins=0;m_losses=0;m_breakeven=0;m_net_profit=0.0;m_net_r=0.0;
      m_run_id=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);StringReplace(m_run_id,".","");StringReplace(m_run_id,":","");StringReplace(m_run_id," ","_");
      if(!csv_enabled)return(true);
      if(!m_csv.Initialize("E2_trades_"+symbol+"_"+m_run_id+".csv",logger)) return(false);
      string header[]={"trade_id","symbol","strategy_type","candidate_id","plan_id","direction","source_zone_id","target_zone_id","zone_role","zone_visit","management_branch","signal_time","confirmation_time","entry_time","exit_time","session","planned_entry","fill_price","stop_loss","take_profit","stop_pips","planned_rr","volume","equity_at_entry","target_risk","planned_actual_risk","planned_risk_pct","exit_price","exit_reason","gross_profit","commission","swap","fees","net_profit","realized_r","holding_minutes"};
      return(m_csv.WriteHeader(header));
     }
   void CaptureEntry(const E2ReportEntryData &entry)
     {
      if(entry.entry_deal==0 || !HistorySelect(0,TimeCurrent()) || !HistoryDealSelect(entry.entry_deal)) { if(m_logger!=NULL)m_logger.Warning("Unable to capture entry deal for trade reporting.","TradeReporter"); return; }
      const ulong position_id=(ulong)HistoryDealGetInteger(entry.entry_deal,DEAL_POSITION_ID);
      if(position_id==0 || Find(position_id)>=0)return;
      E2ReportedTrade trade;ZeroMemory(trade);trade.position_id=position_id;trade.entry_deal=entry.entry_deal;trade.entry=entry;trade.entry.entry_time=(datetime)HistoryDealGetInteger(entry.entry_deal,DEAL_TIME);trade.entry.fill_price=HistoryDealGetDouble(entry.entry_deal,DEAL_PRICE);trade.profit=HistoryDealGetDouble(entry.entry_deal,DEAL_PROFIT);trade.commission=HistoryDealGetDouble(entry.entry_deal,DEAL_COMMISSION);trade.swap=HistoryDealGetDouble(entry.entry_deal,DEAL_SWAP);trade.fee=HistoryDealGetDouble(entry.entry_deal,DEAL_FEE);
      int n=ArraySize(m_open);ArrayResize(m_open,n+1);m_open[n]=trade;
     }
   void OnDeal(const ulong deal_ticket)
     {
      if(deal_ticket==0 || ExitDealProcessed(deal_ticket) || !HistoryDealSelect(deal_ticket))return;
      if((ulong)HistoryDealGetInteger(deal_ticket,DEAL_MAGIC)!=m_magic)return;
      const long entry=(long)HistoryDealGetInteger(deal_ticket,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY)return;
      int index=Find((ulong)HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID));if(index<0 || m_open[index].finalized)return;
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
