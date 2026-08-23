#ifndef E2_REPORTING_E2TRADEREPORTER_MQH
#define E2_REPORTING_E2TRADEREPORTER_MQH

#include "E2CsvExporter.mqh"
#include "..\\core\\E2TradeTypes.mqh"

struct E2ReportEntryData
  {
   string symbol,setup_id,signal_id,execution_id; E2TradeDirection direction;
   datetime signal_time,signal_known_from,request_time,entry_time;
   double requested_entry_price,fill_price,structural_stop_price,submitted_stop_price,take_profit_price,original_r_price,requested_risk_cash,actual_risk_cash,volume;
   ulong order_ticket,entry_deal;
  };

struct E2ReportedTrade
  {
   bool finalized,unresolved_reported; ulong position_id,entry_deal; E2ReportEntryData entry;
   datetime exit_time; double exit_volume,exit_value,profit,commission,swap,fee; string exit_reason;
  };

class E2TradeReporter
  {
private:
   ulong m_magic; E2Logger *m_logger; E2CsvExporter m_csv; E2ReportedTrade m_trades[]; ulong m_processed_exit_deals[];
   int m_completed,m_duplicate_entries,m_duplicate_finalized,m_foreign_deals,m_unregistered_exits,m_invalid_original_r,m_causality_violations;
   string m_run_id;
   int Find(const ulong position_id)const{for(int i=0;i<ArraySize(m_trades);i++)if(m_trades[i].position_id==position_id)return(i);return(-1);}
   bool Processed(const ulong deal)const{for(int i=0;i<ArraySize(m_processed_exit_deals);i++)if(m_processed_exit_deals[i]==deal)return(true);return(false);}
   void Remember(const ulong deal){int n=ArraySize(m_processed_exit_deals);ArrayResize(m_processed_exit_deals,n+1);m_processed_exit_deals[n]=deal;}
   bool PositionOpen(const ulong id)const{for(int i=0;i<PositionsTotal();i++){ulong ticket=PositionGetTicket(i);if(ticket>0&&(ulong)PositionGetInteger(POSITION_MAGIC)==m_magic&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==id)return(true);}return(false);}
   string Reason(const long value)const{if(value==DEAL_REASON_TP)return("TP");if(value==DEAL_REASON_SL)return("SL");if(value==DEAL_REASON_SO)return("STOP_OUT");if(value==DEAL_REASON_EXPERT)return("EXPERT");if(value==DEAL_REASON_CLIENT)return("CLIENT");return("OTHER");}
   string TimeText(const datetime value)const{return(value>0?TimeToString(value,TIME_DATE|TIME_SECONDS):"");}
   string Number(const double value,const int digits=8)const{return(DoubleToString(value,digits));}
   void WriteFinal(const E2ReportedTrade &trade)
     {
      const double net=trade.profit+trade.commission+trade.swap+trade.fee;
      const double realized_r=(trade.entry.actual_risk_cash>0.0?net/trade.entry.actual_risk_cash:0.0);
      const double exit_price=(trade.exit_volume>0.0?trade.exit_value/trade.exit_volume:0.0);
      if(trade.entry.original_r_price<=0.0||trade.entry.actual_risk_cash<=0.0)m_invalid_original_r++;
      string row[]={StringFormat("%I64u",trade.position_id),trade.entry.symbol,trade.entry.setup_id,trade.entry.signal_id,trade.entry.execution_id,E2TradeDirectionName(trade.entry.direction),TimeText(trade.entry.signal_time),TimeText(trade.entry.signal_known_from),TimeText(trade.entry.request_time),TimeText(trade.entry.entry_time),TimeText(trade.exit_time),Number(trade.entry.requested_entry_price),Number(trade.entry.fill_price),Number(trade.entry.structural_stop_price),Number(trade.entry.submitted_stop_price),Number(trade.entry.take_profit_price),Number(trade.entry.original_r_price),Number(trade.entry.requested_risk_cash,2),Number(trade.entry.actual_risk_cash,2),Number(trade.entry.volume,4),Number(exit_price),trade.exit_reason,Number(trade.profit,2),Number(trade.commission,2),Number(trade.swap,2),Number(trade.fee,2),Number(net,2),Number(realized_r,4),StringFormat("%I64u",trade.entry.order_ticket),StringFormat("%I64u",trade.entry.entry_deal)};
      if(m_csv.IsInitialized())m_csv.WriteRow(row);m_completed++;
     }
   void FinalizeIfClosed(const int index)
     {
      if(index<0||index>=ArraySize(m_trades)||m_trades[index].finalized||PositionOpen(m_trades[index].position_id))return;
      if(m_trades[index].exit_time<=0||m_trades[index].exit_volume<=0.0||m_trades[index].exit_reason=="")return;
      for(int i=0;i<ArraySize(m_trades);i++)if(i!=index&&m_trades[i].finalized&&m_trades[i].position_id==m_trades[index].position_id){m_duplicate_finalized++;return;}
      m_trades[index].finalized=true;WriteFinal(m_trades[index]);
     }
public:
   E2TradeReporter(void):m_magic(0),m_logger(NULL),m_completed(0),m_duplicate_entries(0),m_duplicate_finalized(0),m_foreign_deals(0),m_unregistered_exits(0),m_invalid_original_r(0),m_causality_violations(0),m_run_id(""){}
   bool Initialize(const bool csv_enabled,const ulong magic,const string symbol,E2Logger &logger)
     {
      m_magic=magic;m_logger=&logger;ArrayResize(m_trades,0);ArrayResize(m_processed_exit_deals,0);m_completed=0;m_duplicate_entries=0;m_duplicate_finalized=0;m_foreign_deals=0;m_unregistered_exits=0;m_invalid_original_r=0;m_causality_violations=0;
      m_run_id=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);StringReplace(m_run_id,".","");StringReplace(m_run_id,":","");StringReplace(m_run_id," ","_");
      if(!csv_enabled)return(true);if(!m_csv.Initialize("E2_trades_"+symbol+"_"+m_run_id+".csv",logger))return(false);
      string header[]={"position_id","symbol","setup_id","signal_id","execution_id","direction","signal_time","signal_known_from","request_time","entry_time","exit_time","requested_entry","actual_fill","structural_stop","submitted_stop","take_profit","original_r_price","requested_risk_cash","actual_risk_cash","volume","exit_price","exit_reason","profit","commission","swap","fees","net_profit","realized_r","order_ticket","entry_deal"};return(m_csv.WriteHeader(header));
     }
   bool CaptureEntry(const E2ReportEntryData &source)
     {
      if(source.entry_deal==0||!HistoryDealSelect(source.entry_deal))return(false);const ulong id=(ulong)HistoryDealGetInteger(source.entry_deal,DEAL_POSITION_ID);if(id==0)return(false);if(Find(id)>=0){m_duplicate_entries++;return(false);}
      E2ReportedTrade trade;ZeroMemory(trade);trade.position_id=id;trade.entry_deal=source.entry_deal;trade.entry=source;trade.entry.entry_time=(datetime)HistoryDealGetInteger(source.entry_deal,DEAL_TIME);trade.entry.fill_price=HistoryDealGetDouble(source.entry_deal,DEAL_PRICE);
      if(trade.entry.signal_known_from<=0||trade.entry.request_time<trade.entry.signal_known_from||trade.entry.entry_time<trade.entry.request_time)m_causality_violations++;
      int n=ArraySize(m_trades);ArrayResize(m_trades,n+1);m_trades[n]=trade;return(true);
     }
   void OnDeal(const ulong deal)
     {
      if(deal==0||Processed(deal)||!HistoryDealSelect(deal))return;if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=m_magic){m_foreign_deals++;return;}
      const long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);if(entry!=DEAL_ENTRY_OUT&&entry!=DEAL_ENTRY_OUT_BY)return;const int index=Find((ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID));if(index<0){m_unregistered_exits++;return;}if(m_trades[index].finalized)return;Remember(deal);
      const double volume=HistoryDealGetDouble(deal,DEAL_VOLUME);m_trades[index].exit_time=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);m_trades[index].exit_volume+=volume;m_trades[index].exit_value+=volume*HistoryDealGetDouble(deal,DEAL_PRICE);m_trades[index].profit+=HistoryDealGetDouble(deal,DEAL_PROFIT);m_trades[index].commission+=HistoryDealGetDouble(deal,DEAL_COMMISSION);m_trades[index].swap+=HistoryDealGetDouble(deal,DEAL_SWAP);m_trades[index].fee+=HistoryDealGetDouble(deal,DEAL_FEE);m_trades[index].exit_reason=Reason(HistoryDealGetInteger(deal,DEAL_REASON));FinalizeIfClosed(index);
     }
   void Reconcile(void){if(!HistorySelect(0,TimeCurrent()))return;for(int i=0;i<HistoryDealsTotal();i++)OnDeal(HistoryDealGetTicket(i));for(int i=0;i<ArraySize(m_trades);i++)FinalizeIfClosed(i);}
   int UnknownE2Positions(const string symbol)const{int count=0;for(int i=0;i<PositionsTotal();i++){ulong ticket=PositionGetTicket(i);if(ticket<=0||(ulong)PositionGetInteger(POSITION_MAGIC)!=m_magic||PositionGetString(POSITION_SYMBOL)!=symbol)continue;if(Find((ulong)PositionGetInteger(POSITION_IDENTIFIER))<0)count++;}return(count);}
   int RegisteredCount(void)const{return(ArraySize(m_trades));} int FinalizedCount(void)const{return(m_completed);} int DuplicateExecutionIds(void)const{return(m_duplicate_entries);} int DuplicateFinalizedTrades(void)const{return(m_duplicate_finalized);} int CausalityViolations(void)const{return(m_causality_violations);} int InvalidOriginalR(void)const{return(m_invalid_original_r);}
   string RunId(void)const{return(m_run_id);} void Close(void){m_csv.Close();}
  };
#endif
