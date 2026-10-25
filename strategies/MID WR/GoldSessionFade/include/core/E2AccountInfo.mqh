#ifndef E2_CORE_E2ACCOUNTINFO_MQH
#define E2_CORE_E2ACCOUNTINFO_MQH

#include "..\\reporting\\E2Logger.mqh"

struct E2AccountSpecification
  {
   long              login;
   string            currency;
   double            balance;
   double            equity;
   double            free_margin;
   long              leverage;
   ENUM_ACCOUNT_TRADE_MODE trade_mode;
  };

class E2AccountInfo
  {
private:
   E2AccountSpecification m_specification;
   bool              m_initialized;
   E2Logger          *m_logger;

   void ReportError(const string message)
     {
      if(m_logger!=NULL)
         m_logger.Error(message,"AccountInfo");
     }

public:
                     E2AccountInfo(void) : m_initialized(false),m_logger(NULL) {}

   bool              Initialize(E2Logger &logger)
     {
      m_logger=&logger;
      return(Refresh());
     }

   bool              Refresh(void)
     {
      m_initialized=false;
      m_specification.login=AccountInfoInteger(ACCOUNT_LOGIN);
      m_specification.currency=AccountInfoString(ACCOUNT_CURRENCY);
      m_specification.balance=AccountInfoDouble(ACCOUNT_BALANCE);
      m_specification.equity=AccountInfoDouble(ACCOUNT_EQUITY);
      m_specification.free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      m_specification.leverage=AccountInfoInteger(ACCOUNT_LEVERAGE);
      m_specification.trade_mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
      if(m_specification.currency=="" || m_specification.balance<0.0 || m_specification.equity<0.0 || m_specification.free_margin<0.0 || m_specification.leverage<=0)
        {
         ReportError("Invalid account specification.");
         return(false);
        }

      m_initialized=true;
      return(true);
     }

   bool              IsInitialized(void) const { return(m_initialized); }
   E2AccountSpecification Specification(void) const { return(m_specification); }
   double            Balance(void) const { return(m_specification.balance); }
   double            Equity(void) const { return(m_specification.equity); }
   double            FreeMargin(void) const { return(m_specification.free_margin); }
  };

#endif // E2_CORE_E2ACCOUNTINFO_MQH
