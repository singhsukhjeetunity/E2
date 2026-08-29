#ifndef E2_REPORTING_E2TRADEREPORTER_MQH
#define E2_REPORTING_E2TRADEREPORTER_MQH

#include "E2CsvExporter.mqh"

// Strategy-neutral reporting boundary retained for the strategy-free core.
// Sprint 1 intentionally creates no strategy or trade CSV.
class E2TradeReporter
  {
private:
   ulong m_magic;
   bool m_csv_enabled;
public:
   E2TradeReporter(void):m_magic(0),m_csv_enabled(false){}
   bool Initialize(const bool csv_enabled,const ulong magic,const string symbol,E2Logger &logger)
     {m_csv_enabled=csv_enabled;m_magic=magic;logger.Info("Generic reporting foundation initialized for "+symbol+"; strategy CSV production is inactive.","Reporting");return(true);}
   void Reconcile(void){}
   int UnknownE2Positions(const string symbol)const
     {int count=0;for(int i=0;i<PositionsTotal();i++){ulong ticket=PositionGetTicket(i);if(ticket<=0||(ulong)PositionGetInteger(POSITION_MAGIC)!=m_magic||PositionGetString(POSITION_SYMBOL)!=symbol)continue;count++;}return(count);}
   int RegisteredCount(void)const{return(0);}
   int FinalizedCount(void)const{return(0);}
   int DuplicateExecutionIds(void)const{return(0);}
   int DuplicateFinalizedTrades(void)const{return(0);}
   int CausalityViolations(void)const{return(0);}
   bool CsvEnabled(void)const{return(m_csv_enabled);}
   void Close(void){}
  };

#endif
