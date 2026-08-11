#ifndef E2_REPORTING_E2LOGGER_MQH
#define E2_REPORTING_E2LOGGER_MQH

// Centralized, platform-native logging for both the Strategy Tester and
// demo/live terminals. Messages are written to the relevant MT5 log.
class E2Logger
  {
private:
   bool              m_enabled;
   bool              m_debug_enabled;

   void Write(const string level,const string message,const string module="")
     {
      if(!m_enabled)
         return;

      string prefix="[E2]["+level+"]["+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+"]["+_Symbol+"]";
      if(module!="")
         prefix+="["+module+"]";

      Print(prefix+" "+message);
     }

public:
                     E2Logger(void) : m_enabled(false),m_debug_enabled(false) {}

   void              Initialize(const bool enabled,const bool debug_enabled)
     {
      m_enabled=enabled;
     m_debug_enabled=debug_enabled;
     }

   bool              IsDebugEnabled(void) const
     {
      return(m_enabled && m_debug_enabled);
     }

   void              Info(const string message,const string module="")
     {
      Write("INFO",message,module);
     }

   void              Debug(const string message,const string module="")
     {
      if(m_debug_enabled)
         Write("DEBUG",message,module);
     }

   void              Warning(const string message,const string module="")
     {
      Write("WARNING",message,module);
     }

   void              Error(const string message,const string module="")
     {
      Write("ERROR",message,module);
     }
  };

#endif // E2_REPORTING_E2LOGGER_MQH
