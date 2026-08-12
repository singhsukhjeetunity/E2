#ifndef E2_REPORTING_E2BACKTESTSUMMARY_MQH
#define E2_REPORTING_E2BACKTESTSUMMARY_MQH

#include "..\\core\\E2Config.mqh"
#include "E2TradeReporter.mqh"

// End-of-run research metrics are intentionally calculated from the reporter's
// authoritative finalized records only. They do not model price, equity, or P&L.
class E2BacktestSummary
  {
private:
   E2CsvExporter m_csv;
   E2Logger *m_logger;
   E2Config m_config;
   string m_symbol,m_run_id;
   datetime m_test_start;
   double m_initial_balance;
   bool m_initialized;

   string F(const double value,const int digits=4) const { return(DoubleToString(value,digits)); }
   string BoolText(const bool value) const { return(value ? "true" : "false"); }
   string TimeText(const datetime value) const { return(value>0 ? TimeToString(value,TIME_DATE|TIME_SECONDS) : "NA"); }
   string TimeframeText(const ENUM_TIMEFRAMES timeframe) const
     {
      string name=EnumToString(timeframe);
      StringReplace(name,"PERIOD_","");
      return(name);
     }
   string Median(double &values[],const int digits=4) const
     {
      const int count=ArraySize(values);
      if(count==0) return("NA");
      ArraySort(values);
      const double median=(count%2==1 ? values[count/2] : (values[count/2-1]+values[count/2])/2.0);
      return(F(median,digits));
     }
   bool Earlier(const E2ReportedTrade &left,const E2ReportedTrade &right) const
     {
      if(left.exit_time!=right.exit_time) return(left.exit_time<right.exit_time);
      return(left.position_id<right.position_id);
     }
   void SortChronologically(E2ReportedTrade &trades[]) const
     {
      for(int i=1;i<ArraySize(trades);i++)
        {
         E2ReportedTrade value=trades[i]; int j=i-1;
         while(j>=0 && !Earlier(trades[j],value)) { trades[j+1]=trades[j]; j--; }
         trades[j+1]=value;
        }
     }
public:
   E2BacktestSummary(void):m_logger(NULL),m_symbol(""),m_run_id(""),m_test_start(0),m_initial_balance(0.0),m_initialized(false) {}
   bool Initialize(const bool csv_enabled,const E2Config &config,const string symbol,const string run_id,E2Logger &logger)
     {
      m_csv.Close(); m_logger=&logger; m_config=config; m_symbol=symbol; m_run_id=run_id;
      m_test_start=TimeCurrent(); m_initial_balance=AccountInfoDouble(ACCOUNT_BALANCE); m_initialized=true;
      if(!csv_enabled) return(true);
      if(!m_csv.Initialize("E2_summary_"+symbol+"_"+run_id+".csv",logger)) return(false);
      string header[]={"symbol","run_id","test_start","test_end","trades","wins","losses","breakeven","win_rate_pct","gross_profit","gross_loss","net_profit","net_r","average_r","median_r","average_win_r","average_loss_r","best_trade_r","worst_trade_r","profit_factor","expectancy_r","max_consecutive_wins","max_consecutive_losses","max_drawdown_r","max_drawdown_r_percent","average_holding_minutes","median_holding_minutes","long_trades","short_trades","long_net_r","short_net_r","open_or_unresolved","tp_count","sl_count","other_exit_count","london_trades","london_net_r","london_win_rate_pct","new_york_trades","new_york_net_r","new_york_win_rate_pct","overlap_trades","overlap_net_r","average_entry_adx","median_entry_adx","initial_deposit","final_balance","final_equity","absolute_net_change","return_percent","finalized_trade_net_profit","account_net_change","reconciliation_difference","trend_timeframe","zone_timeframe","confirmation_timeframe","swing_sensitivity","trend_structure_lookback_bars","adx_enabled","adx_period","adx_minimum_threshold","minimum_zone_touches","zone_lookback_bars","zone_tolerance_pips","zone_merge_tolerance_pips","stop_loss_zone_buffer_pips","confirmation_engulfing_enabled","confirmation_pin_bar_enabled","confirmation_momentum_enabled","confirmation_previous_break_enabled","risk_percent","reward_risk_target","risk_base","london_session_enabled","new_york_session_enabled","london_session_hours","new_york_session_hours","broker_utc_offset_hours","news_filter_enabled","news_buffer_before_minutes","news_buffer_after_minutes","news_high_impact_only","max_spread_pips","expert_magic_number"};
      return(m_csv.WriteHeader(header));
     }
   void Finalize(const bool tester,E2ReportedTrade &trades[],const int unresolved)
     {
      if(!tester || !m_initialized) return;
      const double epsilon=0.00000001;
      SortChronologically(trades);
      const int count=ArraySize(trades);
      int wins=0,losses=0,breakeven=0,longs=0,shorts=0,tp=0,sl=0,other=0,london=0,newyork=0,overlap=0;
      int consecutive_wins=0,consecutive_losses=0,max_wins=0,max_losses=0,london_wins=0,newyork_wins=0;
      double gross_profit=0.0,gross_loss=0.0,net_profit=0.0,net_r=0.0,long_r=0.0,short_r=0.0,london_r=0.0,newyork_r=0.0,overlap_r=0.0,win_r=0.0,loss_r=0.0,best_r=0.0,worst_r=0.0;
      double r_values[],holding_values[],adx_values[]; ArrayResize(r_values,count);ArrayResize(holding_values,count);ArrayResize(adx_values,count);
      double cumulative_r=0.0,peak_r=0.0,max_dd_r=0.0,max_dd_percent=0.0; bool has_positive_peak=false,r_drawdown_percent_available=true;
      for(int i=0;i<count;i++)
        {
         const double net=trades[i].profit+trades[i].commission+trades[i].swap+trades[i].fee;
         const double r=(trades[i].entry.planned_risk>0.0 ? net/trades[i].entry.planned_risk : 0.0);
         const double holding=(trades[i].exit_time>trades[i].entry.entry_time ? (double)(trades[i].exit_time-trades[i].entry.entry_time)/60.0 : 0.0);
         r_values[i]=r; holding_values[i]=holding; adx_values[i]=trades[i].entry.adx;
         net_profit+=net; net_r+=r;
         if(net>0.0) gross_profit+=net; else if(net<0.0) gross_loss-=net;
         if(i==0) {best_r=r;worst_r=r;} else {if(r>best_r)best_r=r;if(r<worst_r)worst_r=r;}
         if(r>epsilon) {wins++;win_r+=r;consecutive_wins++;consecutive_losses=0;if(consecutive_wins>max_wins)max_wins=consecutive_wins;}
         else if(r<-epsilon) {losses++;loss_r+=r;consecutive_losses++;consecutive_wins=0;if(consecutive_losses>max_losses)max_losses=consecutive_losses;}
         else {breakeven++;consecutive_wins=0;consecutive_losses=0;}
         if(trades[i].entry.direction=="LONG") {longs++;long_r+=r;} else if(trades[i].entry.direction=="SHORT") {shorts++;short_r+=r;}
         if(trades[i].exit_reason=="TP")tp++; else if(trades[i].exit_reason=="SL")sl++; else other++;
         if(trades[i].entry.session=="LONDON") {london++;london_r+=r;if(r>epsilon)london_wins++;}
         else if(trades[i].entry.session=="NEW_YORK") {newyork++;newyork_r+=r;if(r>epsilon)newyork_wins++;}
         else if(trades[i].entry.session=="LONDON_NEW_YORK_OVERLAP") {overlap++;overlap_r+=r;}
         cumulative_r+=r;
         if(cumulative_r>peak_r) {peak_r=cumulative_r;if(peak_r>epsilon)has_positive_peak=true;}
         if(has_positive_peak && cumulative_r<=0.0) r_drawdown_percent_available=false;
         const double drawdown=peak_r-cumulative_r;
         if(drawdown>max_dd_r)max_dd_r=drawdown;
         if(has_positive_peak && peak_r>epsilon) {const double percent=drawdown*100.0/peak_r;if(percent>max_dd_percent)max_dd_percent=percent;}
        }
      const double final_balance=AccountInfoDouble(ACCOUNT_BALANCE),final_equity=AccountInfoDouble(ACCOUNT_EQUITY),account_net=final_balance-m_initial_balance;
      const string average_r=(count>0 ? F(net_r/count) : "NA"), median_r=Median(r_values);
      double holding_sum=0.0,adx_sum=0.0; for(int i=0;i<count;i++){holding_sum+=holding_values[i];adx_sum+=adx_values[i];}
      const string average_holding=(count>0 ? F(holding_sum/count,2) : "NA");
      const string pf=(gross_loss>epsilon ? F(gross_profit/gross_loss) : (gross_profit>epsilon ? "INF" : "NA"));
      string row[]={m_symbol,m_run_id,TimeText(m_test_start),TimeText(TimeCurrent()),IntegerToString(count),IntegerToString(wins),IntegerToString(losses),IntegerToString(breakeven),F(count>0 ? wins*100.0/count : 0.0,2),F(gross_profit,2),F(gross_loss,2),F(net_profit,2),F(net_r),average_r,median_r,(wins>0 ? F(win_r/wins) : "NA"),(losses>0 ? F(loss_r/losses) : "NA"),(count>0 ? F(best_r) : "NA"),(count>0 ? F(worst_r) : "NA"),pf,average_r,IntegerToString(max_wins),IntegerToString(max_losses),F(max_dd_r),(has_positive_peak && r_drawdown_percent_available ? F(max_dd_percent,2) : "NA"),average_holding,Median(holding_values,2),IntegerToString(longs),IntegerToString(shorts),F(long_r),F(short_r),IntegerToString(unresolved),IntegerToString(tp),IntegerToString(sl),IntegerToString(other),IntegerToString(london),F(london_r),(london>0 ? F(london_wins*100.0/london,2) : "NA"),IntegerToString(newyork),F(newyork_r),(newyork>0 ? F(newyork_wins*100.0/newyork,2) : "NA"),IntegerToString(overlap),F(overlap_r),(count>0 ? F(adx_sum/count,2) : "NA"),Median(adx_values,2),F(m_initial_balance,2),F(final_balance,2),F(final_equity,2),F(account_net,2),(m_initial_balance!=0.0 ? F(account_net*100.0/m_initial_balance,4) : "NA"),F(net_profit,2),F(account_net,2),F(account_net-net_profit,2),TimeframeText(m_config.trend_timeframe),TimeframeText(m_config.zone_timeframe),TimeframeText(m_config.confirmation_timeframe),IntegerToString(m_config.swing_sensitivity),IntegerToString(m_config.trend_structure_lookback_bars),BoolText(m_config.adx_enabled),IntegerToString(m_config.adx_period),F(m_config.adx_minimum_threshold,2),IntegerToString(m_config.minimum_zone_touches),IntegerToString(m_config.zone_lookback_bars),F(m_config.zone_tolerance_pips,2),F(m_config.zone_merge_tolerance_pips,2),F(m_config.stop_loss_zone_buffer_pips,2),BoolText(m_config.enable_engulfing_confirmation),BoolText(m_config.enable_pin_bar_confirmation),BoolText(m_config.enable_momentum_candle_confirmation),BoolText(m_config.enable_break_previous_candle_confirmation),F(m_config.risk_percent,4),F(m_config.reward_risk_target,4),IntegerToString((int)m_config.risk_base),BoolText(m_config.enable_london_session),BoolText(m_config.enable_new_york_session),IntegerToString(m_config.london_session_start_hour)+"-"+IntegerToString(m_config.london_session_end_hour),IntegerToString(m_config.new_york_session_start_hour)+"-"+IntegerToString(m_config.new_york_session_end_hour),IntegerToString(m_config.broker_utc_offset_hours),BoolText(m_config.news_filter_enabled),IntegerToString(m_config.high_impact_buffer_before_minutes),IntegerToString(m_config.high_impact_buffer_after_minutes),BoolText(m_config.news_high_impact_only),F(m_config.max_spread_pips,2),StringFormat("%I64u",m_config.expert_magic_number)};
      if(m_csv.IsInitialized() && !m_csv.WriteRow(row) && m_logger!=NULL) m_logger.Warning("Backtest summary CSV row could not be written.","Reporting");
      if(m_logger!=NULL) m_logger.Info("Trades="+IntegerToString(count)+", Wins="+IntegerToString(wins)+", Losses="+IntegerToString(losses)+", BE="+IntegerToString(breakeven)+", WinRate="+F(count>0 ? wins*100.0/count : 0.0,2)+"%, NetR="+F(net_r,2)+", AvgR="+(count>0 ? F(net_r/count,3) : "NA")+", PF="+pf+", MaxDDR="+F(max_dd_r,2)+", NetProfit="+F(net_profit,2)+", OpenOrUnresolved="+IntegerToString(unresolved)+".","RESULT");
     }
   void Close(void) { m_csv.Close(); m_initialized=false; }
  };

#endif // E2_REPORTING_E2BACKTESTSUMMARY_MQH
