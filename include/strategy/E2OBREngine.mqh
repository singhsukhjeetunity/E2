#ifndef E2_STRATEGY_E2OBRENGINE_MQH
#define E2_STRATEGY_E2OBRENGINE_MQH

#include "E2OBRTypes.mqh"
#include "..\\core\\E2Config.mqh"
#include "..\\analysis\\E2MarketData.mqh"

class E2OBREngine
  {
private:
   E2Config m_config; E2MarketData *m_market; E2Logger *m_logger; string m_symbol;
   int m_atr_handle,m_adx_handle; datetime m_last_processed_bar; string m_day; bool m_day_dst,m_day_had_post_or;
   E2OBROpeningRange m_range; bool m_slots[4]; double m_frozen_high,m_frozen_low; string m_candidate_ids[];
   E2OBRVerification m_verify;E2OBRTimeVerification m_time_verify;E2OBRWeekdayVerification m_weekday_verify;E2OBRSessionVerification m_session_verify;E2OBRSuppressedSignal m_suppressed[];

   datetime LastSundayUtc(const int year,const int month)const
     {
      MqlDateTime p;ZeroMemory(p);p.year=year;p.mon=month+1;p.day=1;if(month==12){p.year=year+1;p.mon=1;}datetime first_next=StructToTime(p);datetime last=first_next-86400;MqlDateTime q;TimeToStruct(last,q);return(last-q.day_of_week*86400);
     }
   datetime NthSundayUtc(const int year,const int month,const int nth)const{MqlDateTime p;ZeroMemory(p);p.year=year;p.mon=month;p.day=1;datetime first=StructToTime(p);MqlDateTime q;TimeToStruct(first,q);return(first+((7-q.day_of_week)%7+(nth-1)*7)*86400);}
   bool LondonDstAtUtc(const datetime utc)const
     {
      MqlDateTime p;TimeToStruct(utc,p);const datetime start=LastSundayUtc(p.year,3)+3600;const datetime finish=LastSundayUtc(p.year,10)+3600;return(utc>=start&&utc<finish);
     }
   bool NewYorkDstAtUtc(const datetime utc)const{MqlDateTime p;TimeToStruct(utc,p);datetime start=NthSundayUtc(p.year,3,2)+7*3600,finish=NthSundayUtc(p.year,11,1)+6*3600;return(utc>=start&&utc<finish);}
   string SessionName(void)const{return(m_config.obr_session==E2_OBR_SESSION_NEW_YORK?"NEW_YORK":"LONDON");}string SessionTimezone(void)const{return(m_config.obr_session==E2_OBR_SESSION_NEW_YORK?"America/New_York":"Europe/London");}int SessionStartMinute(void)const{return(m_config.obr_session==E2_OBR_SESSION_NEW_YORK?570:480);}int SessionEndMinute(void)const{return(SessionStartMinute()+60);}
   datetime ServerToUtc(const datetime server)const
     {
      datetime utc=server-m_config.obr_server_utc_offset_standard_hours*3600;
      if(m_config.obr_server_uses_european_dst&&LondonDstAtUtc(utc))utc=server-m_config.obr_server_utc_offset_summer_hours*3600;
      return(utc);
     }
   datetime ServerToSession(const datetime server,bool &dst)const
     {
      const datetime utc=ServerToUtc(server);if(m_config.obr_session==E2_OBR_SESSION_NEW_YORK){dst=NewYorkDstAtUtc(utc);return(utc+(dst?-4:-5)*3600);}dst=LondonDstAtUtc(utc);return(utc+(dst?3600:0));
     }
   string DayId(const datetime london)const
     {
      MqlDateTime p;TimeToStruct(london,p);return(StringFormat("%04d%02d%02d",p.year,p.mon,p.day));
     }
   bool ValidBar(const MqlRates &bar)const{return(bar.time>0&&MathIsValidNumber(bar.high)&&MathIsValidNumber(bar.low)&&MathIsValidNumber(bar.close)&&bar.high>=bar.low&&bar.high>0.0&&bar.low>0.0);}
   void ResetRange(const string day,const bool dst)
     {
      if(m_day!=""&&m_day==day)m_time_verify.day_reset_violations++;
      if(m_day!=""&&!m_range.complete&&m_day_had_post_or)m_verify.opening_ranges_incomplete++;
      ZeroMemory(m_range);ArrayInitialize(m_slots,false);m_range.symbol=m_symbol;m_range.london_day=day;m_range.session=SessionName();m_day=day;m_day_dst=dst;m_day_had_post_or=false;m_frozen_high=0.0;m_frozen_low=0.0;m_verify.london_days_observed++;m_session_verify.session_days_observed++;if(dst)m_time_verify.bst_days++;else m_time_verify.gmt_days++;
     }
   bool SeenCandidate(const string id)const{for(int i=0;i<ArraySize(m_candidate_ids);i++)if(m_candidate_ids[i]==id)return(true);return(false);}
   void RememberCandidate(const string id){int n=ArraySize(m_candidate_ids);ArrayResize(m_candidate_ids,n+1);m_candidate_ids[n]=id;}
   void AppendCandidate(E2OBRCandidate &values[],const E2OBRCandidate &candidate)const{int n=ArraySize(values);ArrayResize(values,n+1);values[n]=candidate;}
   void AppendSuppressed(const E2OBRSuppressedSignal &value){int n=ArraySize(m_suppressed);ArrayResize(m_suppressed,n+1);m_suppressed[n]=value;}
   string WeekdayName(const int day)const{if(day==0)return("SUN");if(day==1)return("MON");if(day==2)return("TUE");if(day==3)return("WED");if(day==4)return("THU");if(day==5)return("FRI");if(day==6)return("SAT");return("INVALID");}
   bool WeekdayEnabled(const int day)const{if(day==1)return(m_config.obr_trade_monday);if(day==2)return(m_config.obr_trade_tuesday);if(day==3)return(m_config.obr_trade_wednesday);if(day==4)return(m_config.obr_trade_thursday);if(day==5)return(m_config.obr_trade_friday);return(false);}
   void RecordOtherwiseValid(const int day,const bool enabled){m_weekday_verify.otherwise_valid_signals_checked++;if(day==1)m_weekday_verify.monday_otherwise_valid++;else if(day==2)m_weekday_verify.tuesday_otherwise_valid++;else if(day==3)m_weekday_verify.wednesday_otherwise_valid++;else if(day==4)m_weekday_verify.thursday_otherwise_valid++;else if(day==5)m_weekday_verify.friday_otherwise_valid++;if(enabled){m_weekday_verify.enabled_weekday_candidates++;return;}m_weekday_verify.total_disabled_weekday_suppressed++;if(day==1)m_weekday_verify.monday_suppressed++;else if(day==2)m_weekday_verify.tuesday_suppressed++;else if(day==3)m_weekday_verify.wednesday_suppressed++;else if(day==4)m_weekday_verify.thursday_suppressed++;else if(day==5)m_weekday_verify.friday_suppressed++;}
   bool IndicatorValue(const int handle,const int buffer,const datetime bar_time,double &value)const
     {
      value=0.0;const int shift=iBarShift(m_symbol,PERIOD_M15,bar_time,true);if(shift<1)return(false);double values[1];if(CopyBuffer(handle,buffer,shift,1,values)!=1||!MathIsValidNumber(values[0])||values[0]<=0.0)return(false);value=values[0];return(true);
     }
   void CandidateLog(const E2OBRCandidate &c)const
     {
      if(m_logger==NULL||!m_config.debug_mode)return;m_logger.Debug("id="+c.candidate_id+", londonDay="+c.london_day+", direction="+E2TradeDirectionName(c.direction)+", breakout="+TimeToString(c.breakout_candle_time,TIME_DATE|TIME_MINUTES)+", OR="+DoubleToString(c.or_low,_Digits)+".."+DoubleToString(c.or_high,_Digits)+", close="+DoubleToString(c.breakout_close,_Digits)+", ATR="+DoubleToString(c.atr,_Digits)+", ADX="+DoubleToString(c.adx,4)+", OR_ATR="+DoubleToString(c.or_size_atr_ratio,4)+", gapATR="+DoubleToString(c.breakout_distance_atr_ratio,4)+".","OBR_CANDIDATE");
     }
   void RejectionLog(const MqlRates &bar,const string reason,const E2TradeDirection direction,const double atr,const double adx,const double or_ratio,const double gap_ratio)const
     {
      if(m_logger==NULL||!m_config.debug_mode)return;m_logger.Debug("londonDay="+m_day+", direction="+E2TradeDirectionName(direction)+", breakout="+TimeToString(bar.time,TIME_DATE|TIME_MINUTES)+", reason="+reason+", OR="+DoubleToString(m_range.low,_Digits)+".."+DoubleToString(m_range.high,_Digits)+", close="+DoubleToString(bar.close,_Digits)+", ATR="+DoubleToString(atr,_Digits)+", ADX="+DoubleToString(adx,4)+", OR_ATR="+DoubleToString(or_ratio,4)+", gapATR="+DoubleToString(gap_ratio,4)+".","OBR_REJECT");
     }
   void ProcessBar(const MqlRates &bar,E2OBRCandidate &new_candidates[])
     {
      if(!ValidBar(bar))return;bool dst=false;const datetime session_local=ServerToSession(bar.time,dst);MqlDateTime lp;TimeToStruct(session_local,lp);const string day=DayId(session_local);
      if(m_day!=day){if(m_day!=""&&dst!=m_day_dst)m_time_verify.dst_transition_observations++;ResetRange(day,dst);}
      const int minute=lp.hour*60+lp.min;const datetime known_from=bar.time+PeriodSeconds(PERIOD_M15);
      const int session_start=SessionStartMinute(),session_end=SessionEndMinute();if(minute>=session_start&&minute<session_end)
        {
         if(lp.sec!=0||lp.min%15!=0){m_time_verify.invalid_or_bars++;m_session_verify.or_start_violations++;return;}const int slot=(minute-session_start)/15;if(slot<0||slot>3){m_time_verify.invalid_or_bars++;m_session_verify.or_bar_count_violations++;return;}
         if(!m_slots[slot])
           {
            if(m_range.frozen){m_time_verify.or_mutation_violations++;return;}m_slots[slot]=true;m_range.bars_collected++;if(m_range.bars_collected==1){m_range.high=bar.high;m_range.low=bar.low;m_range.start_time=bar.time;}else{m_range.high=MathMax(m_range.high,bar.high);m_range.low=MathMin(m_range.low,bar.low);}if(slot==3)m_range.end_time=known_from;
           }
         if(m_range.bars_collected==4&&!m_range.frozen)
           {
            if(!(m_slots[0]&&m_slots[1]&&m_slots[2]&&m_slots[3])||known_from<bar.time+900){m_verify.causality_violations++;return;}m_range.complete=true;m_range.frozen=true;m_range.known_from=known_from;m_frozen_high=m_range.high;m_frozen_low=m_range.low;m_verify.opening_ranges_complete++;
           }
         return;
        }
      if(minute<session_end)return;m_day_had_post_or=true;if(!m_range.frozen)return;
      if(m_range.high!=m_frozen_high||m_range.low!=m_frozen_low){m_time_verify.or_mutation_violations++;m_range.high=m_frozen_high;m_range.low=m_frozen_low;}
      if(bar.time<m_range.known_from){m_verify.causality_violations++;return;}m_verify.breakout_eligible_candles++;
      double atr=0.0,adx=0.0;if(!IndicatorValue(m_atr_handle,0,bar.time,atr)||!IndicatorValue(m_adx_handle,0,bar.time,adx))return;
      const bool adx_ok=(adx>=m_config.obr_minimum_adx);if(adx_ok)m_verify.adx_pass++;const double or_size=m_range.high-m_range.low;const bool range_ok=(or_size>=m_config.obr_minimum_range_atr*atr);if(range_ok)m_verify.range_size_pass++;
      E2TradeDirection direction=E2_DIRECTION_NONE;double distance=0.0;if(bar.close>m_range.high){direction=E2_DIRECTION_LONG;distance=bar.close-m_range.high;m_verify.long_close_breakouts++;if(distance<=m_config.obr_maximum_breakout_gap_atr*atr)m_verify.long_gap_pass++;}else if(bar.close<m_range.low){direction=E2_DIRECTION_SHORT;distance=m_range.low-bar.close;m_verify.short_close_breakouts++;if(distance<=m_config.obr_maximum_breakout_gap_atr*atr)m_verify.short_gap_pass++;}else return;
      const bool gap_ok=(distance<=m_config.obr_maximum_breakout_gap_atr*atr);if(!adx_ok||!range_ok||!gap_ok){string reason="";if(!adx_ok)reason="ADX";if(!range_ok)reason+=(reason==""?"":"+")+"OR_SIZE";if(!gap_ok)reason+=(reason==""?"":"+")+"OVEREXTENDED";RejectionLog(bar,reason,direction,atr,adx,or_size/atr,distance/atr);return;}
      const bool weekday_enabled=WeekdayEnabled(lp.day_of_week);RecordOtherwiseValid(lp.day_of_week,weekday_enabled);if(!weekday_enabled){E2OBRSuppressedSignal suppressed;ZeroMemory(suppressed);suppressed.symbol=m_symbol;suppressed.london_day=m_day;suppressed.london_weekday=WeekdayName(lp.day_of_week);suppressed.session=SessionName();suppressed.direction=direction;suppressed.breakout_time=bar.time;suppressed.or_high=m_range.high;suppressed.or_low=m_range.low;suppressed.breakout_close=bar.close;suppressed.atr=atr;suppressed.adx=adx;suppressed.or_atr=or_size/atr;suppressed.gap_atr=distance/atr;AppendSuppressed(suppressed);RejectionLog(bar,"DISABLED_WEEKDAY",direction,atr,adx,or_size/atr,distance/atr);return;}E2OBRCandidate candidate;ZeroMemory(candidate);candidate.symbol=m_symbol;candidate.london_day=m_day;candidate.session=SessionName();candidate.direction=direction;candidate.breakout_candle_time=bar.time;candidate.breakout_known_from=known_from;candidate.candidate_known_from=known_from;candidate.candidate_id="OBR_"+m_symbol+"_"+m_day+"_"+IntegerToString((int)bar.time)+"_"+E2TradeDirectionName(direction);candidate.or_high=m_range.high;candidate.or_low=m_range.low;candidate.or_start=m_range.start_time;candidate.or_end=m_range.end_time;candidate.or_known_from=m_range.known_from;candidate.breakout_close=bar.close;candidate.atr=atr;candidate.adx=adx;candidate.or_size=or_size;candidate.or_size_atr_ratio=or_size/atr;candidate.breakout_distance=distance;candidate.breakout_distance_atr_ratio=distance/atr;
      if(candidate.candidate_known_from<known_from||candidate.or_known_from>bar.time){m_verify.causality_violations++;return;}if(SeenCandidate(candidate.candidate_id)){m_verify.duplicate_candidates++;return;}RememberCandidate(candidate.candidate_id);AppendCandidate(new_candidates,candidate);m_verify.total_candidates++;if(direction==E2_DIRECTION_LONG)m_verify.long_candidates++;else m_verify.short_candidates++;CandidateLog(candidate);
     }
public:
   E2OBREngine(void):m_market(NULL),m_logger(NULL),m_symbol(""),m_atr_handle(INVALID_HANDLE),m_adx_handle(INVALID_HANDLE),m_last_processed_bar(0),m_day(""),m_day_dst(false),m_day_had_post_or(false),m_frozen_high(0.0),m_frozen_low(0.0){ZeroMemory(m_range);ZeroMemory(m_verify);ZeroMemory(m_time_verify);ZeroMemory(m_weekday_verify);ZeroMemory(m_session_verify);ArrayInitialize(m_slots,false);ArrayResize(m_suppressed,0);}
   bool Initialize(const string symbol,const E2Config &config,E2MarketData &market,E2Logger &logger)
     {
      m_symbol=symbol;m_config=config;m_market=&market;m_logger=&logger;m_atr_handle=iATR(symbol,PERIOD_M15,config.obr_atr_length);m_adx_handle=iADX(symbol,PERIOD_M15,config.obr_adx_length);if(m_atr_handle==INVALID_HANDLE||m_adx_handle==INVALID_HANDLE)return(false);m_last_processed_bar=0;m_day="";ArrayResize(m_candidate_ids,0);ArrayResize(m_suppressed,0);ZeroMemory(m_verify);ZeroMemory(m_time_verify);ZeroMemory(m_weekday_verify);ZeroMemory(m_session_verify);m_session_verify.selected_session=SessionName();m_weekday_verify.monday_enabled=config.obr_trade_monday;m_weekday_verify.tuesday_enabled=config.obr_trade_tuesday;m_weekday_verify.wednesday_enabled=config.obr_trade_wednesday;m_weekday_verify.thursday_enabled=config.obr_trade_thursday;m_weekday_verify.friday_enabled=config.obr_trade_friday;return(true);
     }
   void Shutdown(void){if(m_atr_handle!=INVALID_HANDLE)IndicatorRelease(m_atr_handle);if(m_adx_handle!=INVALID_HANDLE)IndicatorRelease(m_adx_handle);m_atr_handle=INVALID_HANDLE;m_adx_handle=INVALID_HANDLE;}
   bool Evaluate(E2OBRCandidate &new_candidates[])
     {
      ArrayResize(new_candidates,0);ArrayResize(m_suppressed,0);if(!m_config.obr_enabled)return(true);MqlRates latest;if(m_market==NULL||!m_market.GetClosedBar(m_symbol,PERIOD_M15,0,latest))return(false);if(latest.time<=m_last_processed_bar)return(true);
      MqlRates bars[];ArraySetAsSeries(bars,false);const datetime from=(m_last_processed_bar>0?m_last_processed_bar+1:latest.time-36*3600);const int copied=CopyRates(m_symbol,PERIOD_M15,from,latest.time,bars);if(copied<=0)return(false);const bool reconstructing=(m_last_processed_bar==0);
      for(int i=0;i<copied;i++){if(bars[i].time<=m_last_processed_bar||bars[i].time>latest.time)continue;ProcessBar(bars[i],new_candidates);m_last_processed_bar=bars[i].time;}
      if(reconstructing){if(m_range.complete)m_time_verify.or_reconstruction_successes++;else{bool dst=false;datetime local=ServerToSession(latest.time,dst);MqlDateTime p;TimeToStruct(local,p);if(p.hour*60+p.min>=SessionEndMinute())m_time_verify.or_reconstruction_failures++;}}
      return(true);
     }
   string SessionDayAtServerTime(const datetime server)const{bool dst=false;return(DayId(ServerToSession(server,dst)));}int SessionMinuteAtServerTime(const datetime server)const{bool dst=false;MqlDateTime p;TimeToStruct(ServerToSession(server,dst),p);return(p.hour*60+p.min);}string SessionNameValue(void)const{return(SessionName());}
   string ProductionTimeDiagnostic(const datetime server)const{bool dst=false;datetime utc=ServerToUtc(server),local=ServerToSession(server,dst);MqlDateTime p;TimeToStruct(local,p);int start=SessionStartMinute();p.hour=start/60;p.min=start%60;p.sec=0;datetime local_or=StructToTime(p);int market_offset=(m_config.obr_session==E2_OBR_SESSION_NEW_YORK?(dst?-4:-5):(dst?1:0));datetime or_utc=local_or-market_offset*3600;int broker_offset=m_config.obr_server_utc_offset_standard_hours;if(m_config.obr_server_uses_european_dst&&LondonDstAtUtc(or_utc))broker_offset=m_config.obr_server_utc_offset_summer_hours;datetime or_server=or_utc+broker_offset*3600;return("selectedSession="+SessionName()+", sessionTimezone="+SessionTimezone()+", OR="+StringFormat("%02d:%02d-%02d:%02d",start/60,start%60,SessionEndMinute()/60,SessionEndMinute()%60)+", serverTime="+TimeToString(server,TIME_DATE|TIME_SECONDS)+", interpretedUtc="+TimeToString(utc,TIME_DATE|TIME_SECONDS)+", sessionLocalTime="+TimeToString(local,TIME_DATE|TIME_SECONDS)+", sessionUtcOffsetHours="+IntegerToString(market_offset)+", brokerUtcOffsetHours="+IntegerToString(broker_offset)+", brokerStandardOffset="+IntegerToString(m_config.obr_server_utc_offset_standard_hours)+", brokerSummerOffset="+IntegerToString(m_config.obr_server_utc_offset_summer_hours)+", europeanDstSwitch="+IntegerToString((int)m_config.obr_server_uses_european_dst)+", sessionOrServerStart="+TimeToString(or_server,TIME_DATE|TIME_MINUTES)+", sessionOrServerEnd="+TimeToString(or_server+3600,TIME_DATE|TIME_MINUTES));}
   void CopySuppressedSignals(E2OBRSuppressedSignal &values[])const{int n=ArraySize(m_suppressed);ArrayResize(values,n);for(int i=0;i<n;i++)values[i]=m_suppressed[i];}E2OBROpeningRange CurrentRange(void)const{return(m_range);}E2OBRVerification Verification(void)const{return(m_verify);}E2OBRTimeVerification TimeVerification(void)const{return(m_time_verify);}E2OBRWeekdayVerification WeekdayVerification(void)const{return(m_weekday_verify);}E2OBRSessionVerification SessionVerification(void)const{E2OBRSessionVerification v=m_session_verify;v.opening_ranges_complete=m_verify.opening_ranges_complete;v.opening_ranges_incomplete=m_verify.opening_ranges_incomplete;v.or_bar_count_violations=m_time_verify.invalid_or_bars;v.or_mutation_violations=m_time_verify.or_mutation_violations;v.dst_transition_observations=m_time_verify.dst_transition_observations;return(v);}
  };
#endif
