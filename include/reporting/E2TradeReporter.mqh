#ifndef E2_REPORTING_E2TRADEREPORTER_MQH
#define E2_REPORTING_E2TRADEREPORTER_MQH
#include "E2CsvExporter.mqh"
#include "..\\strategy\\E2ADXBBTypes.mqh"
class E2TradeReporter
  {
private:ulong m_magic;bool m_csv_enabled;E2Logger *m_logger;E2ADXBBPositionMetadata m_positions[];bool m_finalized[];int m_duplicates,m_duplicate_finals,m_causality;
   int FindPosition(const ulong id)const{for(int i=0;i<ArraySize(m_positions);i++)if(m_positions[i].position_id==id)return(i);return(-1);}
public:
   E2TradeReporter(void):m_magic(0),m_csv_enabled(false),m_logger(NULL),m_duplicates(0),m_duplicate_finals(0),m_causality(0){}
   bool Initialize(const bool csv_enabled,const ulong magic,const string symbol,E2Logger &logger){m_csv_enabled=csv_enabled;m_magic=magic;m_logger=&logger;ArrayResize(m_positions,0);ArrayResize(m_finalized,0);m_duplicates=0;m_duplicate_finals=0;m_causality=0;logger.Info("ADXBB lifecycle reporting initialized for "+symbol+"; final CSV schema remains deferred.","Reporting");return(true);}
   bool Register(const E2ADXBBPositionMetadata &m){if(FindPosition(m.position_id)>=0){m_duplicates++;return(false);}int n=ArraySize(m_positions);ArrayResize(m_positions,n+1);ArrayResize(m_finalized,n+1);m_positions[n]=m;m_finalized[n]=false;if(m.entry_time<m.signal_time)m_causality++;return(true);}
   void Reconcile(){if(!HistorySelect(0,TimeCurrent()))return;for(int i=0;i<ArraySize(m_positions);i++){if(m_finalized[i])continue;bool open=false;for(int p=0;p<PositionsTotal();p++){ulong t=PositionGetTicket(p);if(t>0&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==m_positions[i].position_id){open=true;break;}}if(open)continue;double pnl=0.0;datetime exit_time=0;for(int d=0;d<HistoryDealsTotal();d++){ulong deal=HistoryDealGetTicket(d);if(deal==0||(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID)!=m_positions[i].position_id)continue;ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);if(e==DEAL_ENTRY_OUT||e==DEAL_ENTRY_OUT_BY){pnl+=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_COMMISSION);exit_time=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);}}if(exit_time>0){m_finalized[i]=true;double realized_r=(m_positions[i].actual_risk_cash>0.0?pnl/m_positions[i].actual_risk_cash:0.0);if(m_logger!=NULL)m_logger.Info("executionId="+m_positions[i].execution_id+", pnl="+DoubleToString(pnl,2)+", realizedR="+DoubleToString(realized_r,4)+".","TradeFinalized");}}}
   int UnknownE2Positions(const string symbol)const{int count=0;for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t<=0||(ulong)PositionGetInteger(POSITION_MAGIC)!=m_magic||PositionGetString(POSITION_SYMBOL)!=symbol)continue;if(FindPosition((ulong)PositionGetInteger(POSITION_IDENTIFIER))<0)count++;}return(count);}
   bool IsFinalizedPosition(const ulong position_id)const{int i=FindPosition(position_id);return(i>=0&&m_finalized[i]);}
   int RegisteredCount(void)const{return(ArraySize(m_positions));}int FinalizedCount(void)const{int n=0;for(int i=0;i<ArraySize(m_finalized);i++)if(m_finalized[i])n++;return(n);}int DuplicateExecutionIds(void)const{return(m_duplicates);}int DuplicateFinalizedTrades(void)const{return(m_duplicate_finals);}int CausalityViolations(void)const{return(m_causality);}bool CsvEnabled(void)const{return(m_csv_enabled);}void Close(void){Reconcile();}
  };
#endif
