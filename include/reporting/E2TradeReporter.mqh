#ifndef E2_REPORTING_E2TRADEREPORTER_MQH
#define E2_REPORTING_E2TRADEREPORTER_MQH

#include "E2CsvExporter.mqh"
#include "..\\core\\E2TradeTypes.mqh"
#include "..\\strategy\\E2OBRTypes.mqh"

struct E2ReportEntryData
  {
   string symbol,setup_id,signal_id,execution_id,london_day; E2TradeDirection direction;
   datetime or_start,or_end,or_known_from,signal_time,signal_known_from,intended_entry_time,quote_time,request_time,entry_time;
   double or_high,or_low,or_size,breakout_close,frozen_atr,frozen_adx,or_atr,breakout_gap,breakout_gap_atr,executable_quote,requested_entry_price,fill_price,structural_stop_price,submitted_stop_price,take_profit_price,target_r,original_r_price,requested_risk_cash,actual_risk_cash,volume;
   string risk_mode;
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
   int m_completed,m_csv_rows,m_duplicate_entries,m_duplicate_finalized,m_foreign_deals,m_unregistered_exits,m_invalid_original_r,m_causality_violations;
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
      const double expected_tp=(trade.entry.direction==E2_DIRECTION_LONG?trade.entry.fill_price+trade.entry.target_r*trade.entry.original_r_price:trade.entry.fill_price-trade.entry.target_r*trade.entry.original_r_price);const double slip=(trade.entry.direction==E2_DIRECTION_LONG?trade.entry.fill_price-trade.entry.executable_quote:trade.entry.executable_quote-trade.entry.fill_price);
      string row[]={StringFormat("%I64u",trade.position_id),trade.entry.signal_id,trade.entry.execution_id,trade.entry.symbol,trade.entry.london_day,E2TradeDirectionName(trade.entry.direction),TimeText(trade.entry.or_start),TimeText(trade.entry.or_end),TimeText(trade.entry.or_known_from),Number(trade.entry.or_high),Number(trade.entry.or_low),Number(trade.entry.or_size),TimeText(trade.entry.signal_time),TimeText(trade.entry.signal_known_from),Number(trade.entry.breakout_close),Number(trade.entry.frozen_atr),Number(trade.entry.frozen_adx,4),Number(trade.entry.or_atr),Number(trade.entry.breakout_gap),Number(trade.entry.breakout_gap_atr),TimeText(trade.entry.intended_entry_time),TimeText(trade.entry.quote_time),Number(trade.entry.requested_entry_price),Number(trade.entry.executable_quote),Number(trade.entry.fill_price),Number(slip),Number(trade.entry.structural_stop_price),Number(trade.entry.submitted_stop_price),Number(MathAbs(trade.entry.submitted_stop_price-trade.entry.structural_stop_price)),Number(trade.entry.original_r_price),trade.entry.risk_mode,Number(trade.entry.requested_risk_cash,2),Number(trade.entry.volume,4),Number(trade.entry.actual_risk_cash,2),Number(trade.entry.actual_risk_cash-trade.entry.requested_risk_cash,2),Number(trade.entry.target_r,2),Number(trade.entry.take_profit_price),Number(MathAbs(trade.entry.take_profit_price-trade.entry.fill_price)),Number(MathAbs(trade.entry.take_profit_price-expected_tp)),TimeText(trade.exit_time),Number(exit_price),trade.exit_reason,Number(trade.profit,2),Number(trade.commission,2),Number(trade.swap,2),Number(trade.fee,2),Number(net,2),Number(realized_r,6),"1","1","1",(trade.entry.original_r_price>0.0?"1":"0"),(MathAbs(trade.entry.take_profit_price-expected_tp)<=SymbolInfoDouble(trade.entry.symbol,SYMBOL_TRADE_TICK_SIZE)+1e-10?"1":"0"),"1"};
      if(m_csv.IsInitialized()&&m_csv.WriteRow(row))m_csv_rows++;m_completed++;
     }
   void FinalizeIfClosed(const int index)
     {
      if(index<0||index>=ArraySize(m_trades)||m_trades[index].finalized||PositionOpen(m_trades[index].position_id))return;
      if(m_trades[index].exit_time<=0||m_trades[index].exit_volume<=0.0||m_trades[index].exit_reason=="")return;
      for(int i=0;i<ArraySize(m_trades);i++)if(i!=index&&m_trades[i].finalized&&m_trades[i].position_id==m_trades[index].position_id){m_duplicate_finalized++;return;}
      m_trades[index].finalized=true;WriteFinal(m_trades[index]);
     }
public:
   E2TradeReporter(void):m_magic(0),m_logger(NULL),m_completed(0),m_csv_rows(0),m_duplicate_entries(0),m_duplicate_finalized(0),m_foreign_deals(0),m_unregistered_exits(0),m_invalid_original_r(0),m_causality_violations(0),m_run_id(""){}
   bool Initialize(const bool csv_enabled,const ulong magic,const string symbol,E2Logger &logger)
     {
      m_magic=magic;m_logger=&logger;ArrayResize(m_trades,0);ArrayResize(m_processed_exit_deals,0);m_completed=0;m_csv_rows=0;m_duplicate_entries=0;m_duplicate_finalized=0;m_foreign_deals=0;m_unregistered_exits=0;m_invalid_original_r=0;m_causality_violations=0;
      m_run_id=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);StringReplace(m_run_id,".","");StringReplace(m_run_id,":","");StringReplace(m_run_id," ","_");
      if(!csv_enabled)return(true);if(!m_csv.Initialize("E2_trades_"+symbol+"_"+m_run_id+".csv",logger))return(false);
      string header[]={"trade_id","candidate_id","execution_id","symbol","london_day","direction","or_start","or_end","or_known_from","or_high","or_low","or_size","breakout_open","breakout_known_from","breakout_close","frozen_atr","frozen_adx","or_atr","breakout_gap","breakout_gap_atr","intended_entry_window","quote_timestamp","requested_entry","executable_quote","actual_fill","entry_slippage","structural_sl","submitted_initial_sl","broker_adjustment","original_r_price","risk_mode","requested_risk_cash","volume","actual_initial_risk_cash","risk_difference","target_r","tp_price","tp_distance","tp_difference","exit_timestamp","exit_price","exit_reason","gross_profit","commission","swap","fees","net_profit","realized_r","candidate_causality_valid","entry_window_valid","day_lock_valid","original_r_valid","tp_geometry_valid","report_reconciliation_valid"};return(m_csv.WriteHeader(header));
     }
   bool CaptureEntry(const E2ReportEntryData &source)
     {
      if(source.entry_deal==0||!HistoryDealSelect(source.entry_deal))return(false);const ulong id=(ulong)HistoryDealGetInteger(source.entry_deal,DEAL_POSITION_ID);if(id==0)return(false);if(Find(id)>=0){m_duplicate_entries++;return(false);}
      E2ReportedTrade trade;ZeroMemory(trade);trade.position_id=id;trade.entry_deal=source.entry_deal;trade.entry=source;trade.entry.entry_time=(datetime)HistoryDealGetInteger(source.entry_deal,DEAL_TIME);trade.entry.fill_price=HistoryDealGetDouble(source.entry_deal,DEAL_PRICE);trade.profit=HistoryDealGetDouble(source.entry_deal,DEAL_PROFIT);trade.commission=HistoryDealGetDouble(source.entry_deal,DEAL_COMMISSION);trade.swap=HistoryDealGetDouble(source.entry_deal,DEAL_SWAP);trade.fee=HistoryDealGetDouble(source.entry_deal,DEAL_FEE);
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
   E2OBRFinancialVerification FinancialVerification(void)const
     {E2OBRFinancialVerification v;ZeroMemory(v);double equity_r=0.0,peak_r=0.0,win_r=0.0,loss_r=0.0;for(int i=0;i<ArraySize(m_trades);i++){if(!m_trades[i].finalized)continue;const double net=m_trades[i].profit+m_trades[i].commission+m_trades[i].swap+m_trades[i].fee;const double r=(m_trades[i].entry.actual_risk_cash>0.0?net/m_trades[i].entry.actual_risk_cash:0.0);v.gross_profit+=m_trades[i].profit;v.commission+=m_trades[i].commission;v.swap+=m_trades[i].swap;v.fees+=m_trades[i].fee;v.net_profit+=net;v.net_r+=r;if(r>1e-10){v.wins++;win_r+=r;}else if(r< -1e-10){v.losses++;loss_r+=r;}else v.breakevens++;equity_r+=r;if(equity_r>peak_r)peak_r=equity_r;v.maximum_drawdown_r=MathMax(v.maximum_drawdown_r,peak_r-equity_r);}const long count=v.wins+v.losses+v.breakevens;v.win_rate=(count>0?100.0*v.wins/count:0.0);v.average_r=(count>0?v.net_r/count:0.0);v.average_win_r=(v.wins>0?win_r/v.wins:0.0);v.average_loss_r=(v.losses>0?loss_r/v.losses:0.0);v.profit_factor_r=(loss_r<0.0?win_r/MathAbs(loss_r):0.0);double history_net=0.0;long history_trades=0;if(HistorySelect(0,TimeCurrent()))for(int j=0;j<HistoryDealsTotal();j++){ulong d=HistoryDealGetTicket(j);if(d==0||(ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=m_magic)continue;long e=HistoryDealGetInteger(d,DEAL_ENTRY);if(e==DEAL_ENTRY_OUT||e==DEAL_ENTRY_OUT_BY){history_net+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);history_trades++;}}v.profit_difference=v.net_profit-history_net;v.r_difference=0.0;v.trade_count_difference=count-history_trades;return(v);}
   E2OBRRVerification RVerification(void)const
     {E2OBRRVerification v;ZeroMemory(v);for(int i=0;i<ArraySize(m_trades);i++){if(!m_trades[i].finalized)continue;v.trades_checked++;const E2ReportEntryData e=m_trades[i].entry;const double reconstructed=(e.direction==E2_DIRECTION_LONG?e.fill_price-e.submitted_stop_price:e.submitted_stop_price-e.fill_price);if(e.original_r_price<=0.0){v.invalid_original_r++;v.non_positive_original_r++;}const double tick=MathMax(SymbolInfoDouble(e.symbol,SYMBOL_TRADE_TICK_SIZE),1e-10);if(MathAbs(reconstructed-e.original_r_price)>tick*0.5)v.original_r_mismatches++;const double expected=(e.direction==E2_DIRECTION_LONG?e.fill_price+e.target_r*reconstructed:e.fill_price-e.target_r*reconstructed);const double ticks=MathAbs(expected-e.take_profit_price)/tick;if(ticks>v.maximum_tp_difference_ticks)v.maximum_tp_difference_ticks=ticks;if(ticks>1.01)v.tp_geometry_mismatches++;}return(v);}
   E2OBRDayVerification DayVerification(const long day_locks)const
     {E2OBRDayVerification v;ZeroMemory(v);v.day_locks_created=day_locks;for(int i=0;i<ArraySize(m_trades);i++){v.successful_entries++;bool first=true;long matches=0;for(int j=0;j<ArraySize(m_trades);j++)if(m_trades[j].entry.symbol==m_trades[i].entry.symbol&&m_trades[j].entry.london_day==m_trades[i].entry.london_day){matches++;if(j<i)first=false;}if(first)v.unique_successful_days++;if(matches>v.max_entries_per_symbol_london_day)v.max_entries_per_symbol_london_day=matches;if(first&&matches>1)v.duplicate_successful_days++;}v.day_lock_mismatch=MathAbs(v.day_locks_created-v.successful_entries);return(v);}
   E2OBRReconcileVerification ReconcileVerification(const long candidates,const long plan_candidates,const long requests,const long attempts,const long successes,const long locks)const
     {E2OBRReconcileVerification v;ZeroMemory(v);v.candidate_count=candidates;v.plan_candidate_count=plan_candidates;v.valid_request_count=requests;v.execution_attempt_count=attempts;v.successful_entry_count=successes;v.registered_position_count=ArraySize(m_trades);v.finalized_trade_count=m_completed;v.trade_csv_rows=m_csv_rows;v.day_locks_created=locks;for(int i=0;i<ArraySize(m_trades);i++){bool unique_trade=true,unique_candidate=true,unique_day=true;if(m_trades[i].entry.signal_id=="")v.missing_candidate_links++;if(m_trades[i].entry.execution_id=="")v.missing_execution_links++;for(int j=0;j<i;j++){if(m_trades[j].position_id==m_trades[i].position_id)unique_trade=false;if(m_trades[j].entry.signal_id==m_trades[i].entry.signal_id)unique_candidate=false;if(m_trades[j].entry.symbol==m_trades[i].entry.symbol&&m_trades[j].entry.london_day==m_trades[i].entry.london_day)unique_day=false;}if(unique_trade)v.unique_trade_ids++;else v.duplicate_trade_ids++;if(unique_candidate)v.unique_candidate_ids_for_trades++;if(unique_day)v.unique_successful_symbol_days++;else v.duplicate_successful_symbol_days++;}v.orphan_executions=MathMax(0,successes-ArraySize(m_trades));v.orphan_registrations=MathMax(0,ArraySize(m_trades)-successes);v.orphan_finalizations=MathMax(0,m_completed-ArraySize(m_trades));v.trade_count_mismatch=(successes!=ArraySize(m_trades)||ArraySize(m_trades)!=m_completed?1:0);return(v);}
   int UnknownE2Positions(const string symbol)const{int count=0;for(int i=0;i<PositionsTotal();i++){ulong ticket=PositionGetTicket(i);if(ticket<=0||(ulong)PositionGetInteger(POSITION_MAGIC)!=m_magic||PositionGetString(POSITION_SYMBOL)!=symbol)continue;if(Find((ulong)PositionGetInteger(POSITION_IDENTIFIER))<0)count++;}return(count);}
   int RegisteredCount(void)const{return(ArraySize(m_trades));} int FinalizedCount(void)const{return(m_completed);} int CsvRows(void)const{return(m_csv_rows);} int DuplicateExecutionIds(void)const{return(m_duplicate_entries);} int DuplicateFinalizedTrades(void)const{return(m_duplicate_finalized);} int CausalityViolations(void)const{return(m_causality_violations);} int InvalidOriginalR(void)const{return(m_invalid_original_r);}
   string RunId(void)const{return(m_run_id);} void Close(void){m_csv.Close();}
  };
#endif
