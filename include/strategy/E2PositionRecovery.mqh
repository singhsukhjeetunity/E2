#ifndef E2_STRATEGY_POSITION_RECOVERY_MQH
#define E2_STRATEGY_POSITION_RECOVERY_MQH
#include "E2StrategyTypes.mqh"
#include "..\\core\\E2Config.mqh"
#include "..\\reporting\\E2Logger.mqh"
#include "..\\execution\\E2PositionGuard.mqh"
#include "..\\time\\E2BrokerTimeAdapter.mqh"


class E2PositionRecovery
  {
private:
   ulong m_magic,m_active_position_id;string m_symbol,m_file;bool m_one_per_day,m_is_tester;E2Logger *m_logger;E2BrokerTimeAdapter *m_time;E2RecoveryVerification m_verify;E2DayVerification m_day;E2DayRecoveryDiagnostics m_day_diag;E2RecoveryDiagnostics m_diag;
   string SafeSymbol()const{string s=m_symbol;StringReplace(s,".","_");StringReplace(s,"#","_");return(s);}
   string BrokerDate(const datetime value)const{datetime local;if(m_time==NULL||!m_time.London(value,local))return("");string s=TimeToString(local,TIME_DATE);StringReplace(s,".","-");return(s);}
   void Fail(const string reason){m_diag.recovery_failure_reason=reason;m_verify.recovery_failures++;if(m_logger!=NULL)m_logger.Error("reason="+reason+", expected="+m_diag.state_file_expected+", found="+m_diag.state_file_found+".","Recovery");}
   bool OwnedPosition(ulong &identifier,ulong &ticket,E2TradeDirection &direction,double &entry,double &sl,double &tp,double &volume)const
     {identifier=0;ticket=0;direction=E2_DIRECTION_NONE;entry=0.0;sl=0.0;tp=0.0;volume=0.0;for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==m_symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==m_magic){ticket=t;identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);direction=((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?E2_DIRECTION_LONG:E2_DIRECTION_SHORT);entry=PositionGetDouble(POSITION_PRICE_OPEN);sl=PositionGetDouble(POSITION_SL);tp=PositionGetDouble(POSITION_TP);volume=PositionGetDouble(POSITION_VOLUME);return(true);}}return(false);}
   bool ExitDealExists(const ulong position_id)const{if(!HistorySelect(0,TimeCurrent()))return(false);for(int i=HistoryDealsTotal()-1;i>=0;i--){ulong d=HistoryDealGetTicket(i);if(d==0||(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID)!=position_id)continue;ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);if(e==DEAL_ENTRY_OUT||e==DEAL_ENTRY_OUT_BY)return(true);}return(false);}
   bool ReadField(const int h,string &value,int &fields){if(FileIsEnding(h))return(false);value=FileReadString(h);fields++;m_diag.fields_read=fields;return(true);}
   int StorageFlag()const{return(m_is_tester?0:FILE_COMMON);}
   bool StateExists()const{return(FileIsExist(m_file,StorageFlag()));}
   bool DeleteState()const{return(FileDelete(m_file,StorageFlag()));}
   bool Parse(const int h,E2PositionMetadata &m)
     {string f;int fields=0;ZeroMemory(m);if(!ReadField(h,f,fields)||f!="E2STATE1"){m_diag.recovery_failure_reason="STATE_SCHEMA_MISMATCH";return(false);}if(!ReadField(h,f,fields)||f!="E2"){m_diag.recovery_failure_reason="STATE_SCHEMA_MISMATCH";return(false);}if(!ReadField(h,f,fields))return(false);ulong row_magic=(ulong)StringToInteger(f);m_diag.magic_match=(int)(row_magic==m_magic);if(!ReadField(h,m.candidate_id,fields)||!ReadField(h,m.execution_id,fields)||!ReadField(h,m.symbol,fields))return(false);if(!ReadField(h,f,fields))return(false);m.direction=(E2TradeDirection)StringToInteger(f);if(!ReadField(h,f,fields))return(false);m.signal_time=(datetime)StringToInteger(f);if(!ReadField(h,f,fields))return(false);m.entry_time=(datetime)StringToInteger(f);if(!ReadField(h,f,fields))return(false);m.entry_deal=(ulong)StringToInteger(f);if(!ReadField(h,f,fields))return(false);m.position_id=(ulong)StringToInteger(f);if(!ReadField(h,f,fields))return(false);m.position_ticket=(ulong)StringToInteger(f);if(!ReadField(h,f,fields))return(false);m.volume=StringToDouble(f);if(!ReadField(h,f,fields))return(false);m.fill_price=StringToDouble(f);if(!ReadField(h,f,fields))return(false);m.submitted_stop=StringToDouble(f);if(!ReadField(h,f,fields))return(false);m.original_r=StringToDouble(f);if(!ReadField(h,f,fields))return(false);m.target_r=StringToDouble(f);if(!ReadField(h,f,fields))return(false);m.target_price=StringToDouble(f);if(!ReadField(h,f,fields))return(false);m.requested_risk_cash=StringToDouble(f);if(!ReadField(h,f,fields))return(false);m.actual_risk_cash=StringToDouble(f);
if(!ReadField(h,f,fields))return(false);m.london_day=(int)StringToInteger(f);
if(!ReadField(h,f,fields))return(false);m.range_start_london=(datetime)StringToInteger(f);
if(!ReadField(h,f,fields))return(false);m.range_end_london=(datetime)StringToInteger(f);
if(!ReadField(h,f,fields))return(false);m.range_high=StringToDouble(f);
if(!ReadField(h,f,fields))return(false);m.range_low=StringToDouble(f);
if(!ReadField(h,f,fields))return(false);m.signal_close=StringToDouble(f);
if(!ReadField(h,f,fields))return(false);m.breakout_distance=StringToDouble(f);
if(!ReadField(h,m.time_policy_digest,fields))return(false);
 m_diag.expected_fields=28;m_diag.rows_read=1;if(fields!=m_diag.expected_fields){m_diag.recovery_failure_reason="STATE_ROW_PARSE_FAILED";return(false);}m_diag.valid_rows_parsed=1;return(true);}
public:
   E2PositionRecovery(void):m_magic(0),m_active_position_id(0),m_symbol(""),m_file(""),m_one_per_day(false),m_is_tester(false),m_logger(NULL),m_time(NULL){ZeroMemory(m_verify);ZeroMemory(m_day);ZeroMemory(m_day_diag);ZeroMemory(m_diag);}
   bool Initialize(const E2Config &c,const string symbol,const bool is_tester,E2BrokerTimeAdapter &time,E2Logger &logger,E2PositionMetadata &recovered,bool &has_recovered)
     {m_time=&time;m_magic=c.expert_magic_number;m_symbol=symbol;m_one_per_day=c.one_trade_per_day;m_is_tester=is_tester;m_logger=&logger;m_active_position_id=0;ZeroMemory(m_verify);ZeroMemory(m_day);ZeroMemory(m_day_diag);ZeroMemory(m_diag);m_day.enabled=(int)m_one_per_day;m_file="E2_STATE_"+StringFormat("%I64u",m_magic)+"_"+SafeSymbol()+".csv";m_diag.state_file_expected=(m_is_tester?"TESTER_AGENT\\MQL5\\Files\\"+m_file:TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+m_file);logger.Info("runtime="+(m_is_tester?"TESTER":"TERMINAL")+", storage="+(m_is_tester?"LOCAL":"COMMON")+", file="+m_file+".","E2_RECOVERY_STORAGE");ZeroMemory(recovered);has_recovered=false;
      ulong live_id=0,live_ticket=0;E2TradeDirection live_direction=E2_DIRECTION_NONE;double live_entry=0.0,live_sl=0.0,live_tp=0.0,live_volume=0.0;const bool open=OwnedPosition(live_id,live_ticket,live_direction,live_entry,live_sl,live_tp,live_volume);if(open)m_verify.startup_open_positions++;
      if(!StateExists()){if(open)Fail("STATE_FILE_NOT_FOUND");else if(m_is_tester)logger.Info("reason=NEW_TEST_RUN, action=LOCAL_SANDBOX_EMPTY.","E2_RECOVERY_TESTER_RESET");return(!open);}m_diag.state_file_found=m_diag.state_file_expected;ResetLastError();int h=FileOpen(m_file,FILE_READ|FILE_CSV|FILE_ANSI|StorageFlag(),';');m_diag.file_open_error=GetLastError();if(h==INVALID_HANDLE){Fail("STATE_FILE_OPEN_FAILED");return(false);}m_diag.file_open_success=1;m_diag.rows_read=1;m_diag.expected_fields=20;bool parsed=Parse(h,recovered);FileClose(h);if(!parsed){if(m_diag.recovery_failure_reason=="")m_diag.recovery_failure_reason="STATE_ROW_PARSE_FAILED";Fail(m_diag.recovery_failure_reason);return(false);}
      m_diag.symbol_match=(int)(recovered.symbol==m_symbol);m_diag.position_identifier_match=(int)(open&&recovered.position_id==live_id);m_diag.position_ticket_match=(int)(open&&recovered.position_ticket==live_ticket);m_diag.direction_match=(int)(open&&recovered.direction==live_direction);m_diag.entry_deal_resolved=(int)(recovered.entry_deal>0&&HistoryDealSelect(recovered.entry_deal));m_diag.fill_valid=(int)(recovered.fill_price>0.0&&MathIsValidNumber(recovered.fill_price));m_diag.initial_sl_valid=(int)(recovered.submitted_stop>0.0&&MathIsValidNumber(recovered.submitted_stop));m_diag.original_r_valid=(int)(recovered.original_r>0.0&&MathIsValidNumber(recovered.original_r));m_diag.target_r_valid=(int)(recovered.target_r>0.0&&MathIsValidNumber(recovered.target_r));m_diag.tp_valid=(int)(recovered.target_price>0.0&&MathIsValidNumber(recovered.target_price));
      if(!open){if(ExitDealExists(recovered.position_id)){DeleteState();m_verify.states_cleared++;return(true);}if(m_is_tester){const ulong stale_position_id=recovered.position_id;if(!DeleteState()){Fail("STATE_FILE_DELETE_FAILED");return(false);}m_verify.states_cleared++;m_diag.recovery_failure_reason="NONE";logger.Info("reason=NO_MATCHING_POSITION_RECORD, action=DELETE_STALE_LOCAL_STATE, positionId="+StringFormat("%I64u",stale_position_id)+".","E2_RECOVERY_TESTER_RESET");ZeroMemory(recovered);has_recovered=false;return(true);}m_verify.orphan_states++;Fail("NO_MATCHING_POSITION_RECORD");return(false);}E2SymbolSpecification spec;double tick=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE);double tol=MathMax(1e-10,tick*1e-6);
      if(!m_diag.magic_match){Fail("MAGIC_MISMATCH");return(false);}if(!m_diag.symbol_match){Fail("SYMBOL_MISMATCH");return(false);}if(!m_diag.position_identifier_match){Fail("POSITION_ID_MISMATCH");return(false);}if(!m_diag.direction_match){Fail("DIRECTION_MISMATCH");return(false);}if(!m_diag.entry_deal_resolved){Fail("ENTRY_DEAL_NOT_FOUND");return(false);}if(!m_diag.fill_valid||MathAbs(recovered.fill_price-live_entry)>tol){Fail("INVALID_FILL");return(false);}m_diag.sl_comparisons_performed++;if(!m_diag.initial_sl_valid||MathAbs(recovered.submitted_stop-live_sl)>tol){m_diag.sl_mismatches++;Fail("INVALID_INITIAL_SL");return(false);}m_diag.original_r_comparisons_performed++;if(!m_diag.original_r_valid||MathAbs(recovered.original_r-MathAbs(recovered.fill_price-recovered.submitted_stop))>tol){m_diag.original_r_mismatches++;Fail("INVALID_ORIGINAL_R");return(false);}if(!m_diag.target_r_valid){Fail("INVALID_TARGET_R");return(false);}m_diag.tp_comparisons_performed++;if(!m_diag.tp_valid||MathAbs(recovered.target_price-live_tp)>tol){m_diag.tp_mismatches++;Fail("INVALID_TP");return(false);}if(recovered.volume<=0.0||MathAbs(recovered.volume-live_volume)>1e-10){Fail("OTHER");return(false);}
      has_recovered=true;m_active_position_id=recovered.position_id;m_verify.states_loaded++;m_diag.selected_recovery_record=recovered.execution_id;m_diag.recovery_failure_reason="NONE";return(true);}
   bool Save(const E2PositionMetadata &m)
     {ResetLastError();int h=FileOpen(m_file,FILE_WRITE|FILE_CSV|FILE_ANSI|StorageFlag(),';');if(h==INVALID_HANDLE){Fail("STATE_FILE_OPEN_FAILED");return(false);}uint written=FileWrite(h,"E2STATE1","E2",StringFormat("%I64u",m_magic),m.candidate_id,m.execution_id,m.symbol,IntegerToString((int)m.direction),IntegerToString((long)m.signal_time),IntegerToString((long)m.entry_time),StringFormat("%I64u",m.entry_deal),StringFormat("%I64u",m.position_id),StringFormat("%I64u",m.position_ticket),DoubleToString(m.volume,8),DoubleToString(m.fill_price,16),DoubleToString(m.submitted_stop,16),DoubleToString(m.original_r,16),DoubleToString(m.target_r,16),DoubleToString(m.target_price,16),DoubleToString(m.requested_risk_cash,8),DoubleToString(m.actual_risk_cash,8),IntegerToString(m.london_day),IntegerToString((long)m.range_start_london),IntegerToString((long)m.range_end_london),DoubleToString(m.range_high,16),DoubleToString(m.range_low,16),DoubleToString(m.signal_close,16),DoubleToString(m.breakout_distance,16),m.time_policy_digest);FileFlush(h);FileClose(h);if(written==0){Fail("STATE_ROW_PARSE_FAILED");return(false);}m_active_position_id=m.position_id;m_verify.states_saved++;return(true);}
   void Reconcile(const bool finalized){if(finalized&&m_active_position_id>0&&StateExists()){if(DeleteState()){m_verify.states_cleared++;m_active_position_id=0;}}}
   // Deal history is authoritative. A failed scan blocks entry; it never grants a free day.
   bool DayConsumed(const datetime server)
   {
      if(!m_one_per_day)return(false);
      int target=0;datetime local,utc;
      if(m_time==NULL||!m_time.Day(server,target)||!m_time.London(server,local)||!m_time.ServerToUtc(server,utc))
         {m_day.daily_lock_failure_reason="TIME_POLICY_UNAVAILABLE";return(true);}
      datetime midnight=E2LocalMidnight(local);
      // Require the entire London calendar day within declared timezone coverage.
      if(utc-((long)local-(long)midnight)-3600<m_time.CoverageStart())
         {m_day.daily_lock_failure_reason="DAY_HISTORY_OUTSIDE_PROFILE";return(true);}
      m_day.history_range_start=MathMax(0,server-3*86400);
      m_day.history_range_end=TimeCurrent()+1;
      if(!HistorySelect(m_day.history_range_start,m_day.history_range_end))
         {m_day.daily_lock_failure_reason="HISTORY_SELECT_FAILED";return(true);}
      int same=0,owned=0,scanned=0;
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong d=HistoryDealGetTicket(i);if(d==0)continue;scanned++;
         if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=m_magic||HistoryDealGetString(d,DEAL_SYMBOL)!=m_symbol||
            (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
         // Reuse canonical symbol+magic ownership, including legacy recovered trades.
         datetime tm=(datetime)HistoryDealGetInteger(d,DEAL_TIME);int day=0;
         // Entries older than the possible target day cannot consume it.
         if(tm<server-2*86400)continue;
         if(!m_time.Day(tm,day)){m_day.daily_lock_failure_reason="DEAL_TIME_UNMAPPABLE";return(true);}
         owned++;if(day==target)same++;
      }
      m_day.entry_deals_scanned=scanned;m_day.owned_entry_deals_found=owned;
      m_day.today_owned_entry_deals_found=same;m_day.daily_lock_recovered=(int)(same>0);
      m_day.daily_lock_failure_reason=(same>0?"NONE":"NO_ENTRY_FOR_LONDON_DAY");
      if(same>0)m_day.history_locks_found++;
      return(same>0);
   }
   bool ReconstructDayLock(const ulong entry_deal,const datetime fallback_time){return(DayConsumed(TimeCurrent()));}
   void AuditDayEntries()
   {
      m_day.max_entries_per_symbol_day=0;m_day.duplicate_day_entry_violations=0;m_day.day_mapping_violations=0;
      if(m_time==NULL||!HistorySelect(0,TimeCurrent()+1)){m_day.day_mapping_violations++;return;}
      int days[],counts[];ulong positions[];
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong d=HistoryDealGetTicket(i);
         if(d==0||(ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=m_magic||HistoryDealGetString(d,DEAL_SYMBOL)!=m_symbol||
            (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
         datetime tm=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
         if(tm<m_time.CoverageStart()-50400)continue;
         int day=0;if(!m_time.Day(tm,day)){m_day.day_mapping_violations++;continue;}
         ulong position=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);bool seen=false;
         for(int j=0;j<ArraySize(positions);j++)if(positions[j]==position){seen=true;break;}
         if(seen)continue;int pn=ArraySize(positions);ArrayResize(positions,pn+1);positions[pn]=position;
         int index=-1;for(int j=0;j<ArraySize(days);j++)if(days[j]==day){index=j;break;}
         if(index<0){index=ArraySize(days);ArrayResize(days,index+1);ArrayResize(counts,index+1);days[index]=day;counts[index]=0;}
         counts[index]++;m_day.max_entries_per_symbol_day=MathMax(m_day.max_entries_per_symbol_day,counts[index]);
      }
      if(m_one_per_day)for(int i=0;i<ArraySize(counts);i++)if(counts[i]>1)m_day.duplicate_day_entry_violations+=counts[i]-1;
   }
   void RecordLock(){if(m_one_per_day)m_day.locks_created++;}void RecordSuppressed(){m_day.candidates_suppressed++;}
   bool StateFileExists()const{return(StateExists());}ulong ActivePositionId()const{return(m_active_position_id);}E2RecoveryVerification Verification()const{return(m_verify);}E2DayVerification DayVerification()const{return(m_day);}E2DayRecoveryDiagnostics DayRecoveryDiagnostics()const{return(m_day_diag);}E2RecoveryDiagnostics Diagnostics()const{return(m_diag);}
  };
#endif
