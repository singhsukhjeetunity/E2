#ifndef E2_STRATEGY_E2OBRRECOVERY_MQH
#define E2_STRATEGY_E2OBRRECOVERY_MQH

#include "E2OBRTypes.mqh"
#include "..\\core\\E2Config.mqh"
#include "..\\reporting\\E2Logger.mqh"

class E2OBRRecovery
  {
private:
   E2Config m_config; string m_symbol,m_file,m_locked_days[]; E2Logger *m_logger; E2OBRRecoveryVerification m_verify;
   bool LockedCached(const string day)const{for(int i=0;i<ArraySize(m_locked_days);i++)if(m_locked_days[i]==day)return(true);return(false);}
   void CacheLock(const string day){if(LockedCached(day))return;int n=ArraySize(m_locked_days);ArrayResize(m_locked_days,n+1);m_locked_days[n]=day;}
   bool PositionOpen(const ulong id)const{for(int i=0;i<PositionsTotal();i++){ulong ticket=PositionGetTicket(i);if(ticket>0&&(ulong)PositionGetInteger(POSITION_MAGIC)==m_config.expert_magic_number&&PositionGetString(POSITION_SYMBOL)==m_symbol&&(id==0||(ulong)PositionGetInteger(POSITION_IDENTIFIER)==id))return(true);}return(false);}
public:
   E2OBRRecovery(void):m_symbol(""),m_file(""),m_logger(NULL){ZeroMemory(m_verify);}
   void Initialize(const string symbol,const E2Config &config,E2Logger &logger)
     {m_symbol=symbol;m_config=config;m_logger=&logger;m_file="E2_OBR_STATE_"+StringFormat("%I64u",config.expert_magic_number)+"_"+symbol+".csv";StringReplace(m_file,"/","_");StringReplace(m_file,"\\","_");ArrayResize(m_locked_days,0);ZeroMemory(m_verify);m_verify.initializations++;}
   bool DayConsumed(const string day)
     {
      if(LockedCached(day))return(true);if(!HistorySelect(TimeCurrent()-7*86400,TimeCurrent()))return(false);int matches=0;
      const string prefix="E2OBR|"+day;for(int i=0;i<HistoryDealsTotal();i++){ulong deal=HistoryDealGetTicket(i);if(deal==0||(ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=m_config.expert_magic_number||HistoryDealGetString(deal,DEAL_SYMBOL)!=m_symbol||HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;if(StringFind(HistoryDealGetString(deal,DEAL_COMMENT),prefix)==0)matches++;}
      if(matches>0){CacheLock(day);m_verify.day_lock_recoveries++;if(matches>1)m_verify.duplicate_day_entry_violations++;return(true);}return(false);
     }
   void RecordSuccessfulEntry(const string day){CacheLock(day);}
   void RecordORRecovery(const bool success){if(success)m_verify.or_recovery_successes++;else m_verify.or_recovery_failures++;}
   bool Save(const E2OBRPositionMetadata &m)
     {
      int h=FileOpen(m_file,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');if(h==INVALID_HANDLE)return(false);
      uint written=FileWrite(h,"E2_OBR_STATE_V1",StringFormat("%I64u",m.position_id),StringFormat("%I64u",m.order_ticket),StringFormat("%I64u",m.entry_deal),m.candidate_id,m.execution_id,m.london_day,m.symbol,IntegerToString((int)m.direction),IntegerToString((int)m.breakout_time),IntegerToString((int)m.entry_time),DoubleToString(m.or_high,16),DoubleToString(m.or_low,16),DoubleToString(m.frozen_atr,16),DoubleToString(m.frozen_adx,16),DoubleToString(m.fill_price,16),DoubleToString(m.structural_stop,16),DoubleToString(m.submitted_stop,16),DoubleToString(m.original_r_price,16),DoubleToString(m.target_price,16),DoubleToString(m.requested_risk_cash,16),DoubleToString(m.actual_risk_cash,16),DoubleToString(m.volume,16));FileFlush(h);FileClose(h);return(written>0);
     }
   bool Load(E2OBRPositionMetadata &m)
     {
      ZeroMemory(m);int h=FileOpen(m_file,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',');if(h==INVALID_HANDLE)return(false);string schema=FileReadString(h);if(schema!="E2_OBR_STATE_V1"){FileClose(h);m_verify.metadata_recovery_failures++;return(false);}
      m.position_id=(ulong)StringToInteger(FileReadString(h));m.order_ticket=(ulong)StringToInteger(FileReadString(h));m.entry_deal=(ulong)StringToInteger(FileReadString(h));m.candidate_id=FileReadString(h);m.execution_id=FileReadString(h);m.london_day=FileReadString(h);m.symbol=FileReadString(h);m.direction=(E2TradeDirection)StringToInteger(FileReadString(h));m.breakout_time=(datetime)StringToInteger(FileReadString(h));m.entry_time=(datetime)StringToInteger(FileReadString(h));m.or_high=StringToDouble(FileReadString(h));m.or_low=StringToDouble(FileReadString(h));m.frozen_atr=StringToDouble(FileReadString(h));m.frozen_adx=StringToDouble(FileReadString(h));m.fill_price=StringToDouble(FileReadString(h));m.structural_stop=StringToDouble(FileReadString(h));m.submitted_stop=StringToDouble(FileReadString(h));m.original_r_price=StringToDouble(FileReadString(h));m.target_price=StringToDouble(FileReadString(h));m.requested_risk_cash=StringToDouble(FileReadString(h));m.actual_risk_cash=StringToDouble(FileReadString(h));m.volume=StringToDouble(FileReadString(h));FileClose(h);
      m.valid=(m.position_id>0&&m.entry_deal>0&&m.candidate_id!=""&&m.london_day!=""&&m.symbol==m_symbol&&m.direction!=E2_DIRECTION_NONE&&m.fill_price>0.0&&m.submitted_stop>0.0&&m.original_r_price>0.0&&m.target_price>0.0&&m.volume>0.0);if(!m.valid){m_verify.metadata_recovery_failures++;return(false);}
      const double expected=MathAbs(m.fill_price-m.submitted_stop);if(MathAbs(expected-m.original_r_price)>MathMax(1e-10,SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE)*0.5)){m_verify.original_r_recovery_violations++;return(false);}CacheLock(m.london_day);if(PositionOpen(m.position_id))m_verify.open_position_recoveries++;return(true);
     }
   bool HasOwnedOpenPosition(void)const{return(PositionOpen(0));}
   void ClearIfNoOpenPosition(void){if(!HasOwnedOpenPosition())FileDelete(m_file,FILE_COMMON);}
   E2OBRRecoveryVerification Verification(void)const{return(m_verify);}
  };
#endif
