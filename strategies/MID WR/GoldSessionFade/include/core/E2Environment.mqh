#ifndef E2_CORE_E2ENVIRONMENT_MQH
#define E2_CORE_E2ENVIRONMENT_MQH

// Captures MT5 runtime context for diagnostics without changing application
// behavior between terminal, tester, and optimization execution.
class E2Environment
  {
private:
   bool              m_is_tester;
   bool              m_is_optimization;

public:
                     E2Environment(void) : m_is_tester(false),m_is_optimization(false) {}

   void              Initialize(void)
     {
      m_is_tester=(MQLInfoInteger(MQL_TESTER)!=0);
      m_is_optimization=(MQLInfoInteger(MQL_OPTIMIZATION)!=0);
     }

   bool              IsTester(void) const
     {
      return(m_is_tester);
     }

   bool              IsOptimization(void) const
     {
      return(m_is_optimization);
     }

   bool              IsLiveOrDemoTerminal(void) const
     {
      return(!m_is_tester);
     }

   string            Name(void) const
     {
      if(m_is_optimization)
         return("Optimization");
      if(m_is_tester)
         return("Strategy Tester");
      return("Terminal");
     }
  };

#endif // E2_CORE_E2ENVIRONMENT_MQH
