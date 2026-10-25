#ifndef E2_CORE_E2SYMBOLINFO_MQH
#define E2_CORE_E2SYMBOLINFO_MQH

#include "..\\reporting\\E2Logger.mqh"

struct E2SymbolSpecification
  {
   string            symbol;
   int               digits;
   double            point;
   double            pip_size;
   double            tick_size;
   double            tick_value;
   double            tick_value_profit;
   double            tick_value_loss;
   double            contract_size;
   double            volume_min;
   double            volume_max;
   double            volume_step;
   long              stops_level_points;
   ENUM_SYMBOL_TRADE_MODE trade_mode;
  };

// Pip convention: a 5- or 3-digit quote has ten points per pip; all other
// standard quote precisions use one point per pip. Tick size remains the
// authoritative executable-price increment.
class E2SymbolInfo
  {
private:
   E2SymbolSpecification m_specification;
   bool              m_initialized;
   E2Logger          *m_logger;

   void ReportError(const string message)
     {
      if(m_logger!=NULL)
         m_logger.Error(message,"SymbolInfo");
     }

   bool Validate(void)
     {
      if(m_specification.digits<0 || m_specification.point<=0.0 || m_specification.tick_size<=0.0)
        {
         ReportError("Invalid price specification for "+m_specification.symbol+".");
         return(false);
        }
      if(m_specification.volume_min<=0.0 || m_specification.volume_max<m_specification.volume_min || m_specification.volume_step<=0.0)
        {
         ReportError("Invalid volume specification for "+m_specification.symbol+".");
         return(false);
        }
      if(m_specification.tick_value<=0.0 && (m_specification.tick_value_profit<=0.0 || m_specification.tick_value_loss<=0.0))
        {
         ReportError("Usable tick-value data is unavailable for "+m_specification.symbol+".");
         return(false);
        }
      return(true);
     }

public:
                     E2SymbolInfo(void) : m_initialized(false),m_logger(NULL) {}

   bool              Initialize(const string symbol,E2Logger &logger)
     {
      m_logger=&logger;
      return(Refresh(symbol));
     }

   bool              Refresh(const string symbol)
     {
      m_initialized=false;
      if(symbol=="")
        {
         ReportError("Symbol specification requires a symbol name.");
         return(false);
        }

      m_specification.symbol=symbol;
      m_specification.digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      m_specification.point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      m_specification.pip_size=(m_specification.digits==3 || m_specification.digits==5) ? m_specification.point*10.0 : m_specification.point;
      m_specification.tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      m_specification.tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
      m_specification.tick_value_profit=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT);
      m_specification.tick_value_loss=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
      m_specification.contract_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
      m_specification.volume_min=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
      m_specification.volume_max=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
      m_specification.volume_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      m_specification.stops_level_points=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
      m_specification.trade_mode=(ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
      if(!Validate())
         return(false);

      m_initialized=true;
      return(true);
     }

   bool              IsInitialized(void) const { return(m_initialized); }
   E2SymbolSpecification Specification(void) const { return(m_specification); }
   double            PipSize(void) const { return(m_specification.pip_size); }

   double            NormalizePrice(const double raw_price) const
     {
      if(!m_initialized)
         return(0.0);
      return(NormalizeDouble(MathRound(raw_price/m_specification.tick_size)*m_specification.tick_size,m_specification.digits));
     }

   // Floors to the volume-step grid. Values below the broker minimum fail
   // instead of being rounded up and increasing future intended risk.
   bool              NormalizeVolume(const double raw_volume,double &normalized_volume) const
     {
      normalized_volume=0.0;
      if(!m_initialized || raw_volume<m_specification.volume_min)
         return(false);

      const double capped_volume=MathMin(raw_volume,m_specification.volume_max);
      const double steps=MathFloor((capped_volume-m_specification.volume_min)/m_specification.volume_step+1e-9);
      normalized_volume=m_specification.volume_min+steps*m_specification.volume_step;
      if(normalized_volume>m_specification.volume_max)
         normalized_volume=m_specification.volume_max;
      return(true);
     }
  };

#endif // E2_CORE_E2SYMBOLINFO_MQH
