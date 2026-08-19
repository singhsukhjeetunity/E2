#ifndef E2_RISK_E2POSITIONSIZER_MQH
#define E2_RISK_E2POSITIONSIZER_MQH

#include "..\\core\\E2Config.mqh"
#include "..\\core\\E2SymbolInfo.mqh"
#include "..\\core\\E2AccountInfo.mqh"

enum E2TradeDirection
  {
   E2_DIRECTION_BUY,
   E2_DIRECTION_SELL
  };

enum E2SizingStatus
  {
   E2_SIZING_VALID,
   E2_SIZING_INVALID_INPUT,
   E2_SIZING_INVALID_STOP,
   E2_SIZING_ACCOUNT_DATA_UNAVAILABLE,
   E2_SIZING_SYMBOL_DATA_UNAVAILABLE,
   E2_SIZING_CALCULATION_FAILED,
   E2_SIZING_VOLUME_BELOW_MINIMUM,
   E2_SIZING_VOLUME_ABOVE_MAXIMUM,
   E2_SIZING_RISK_EXCEEDS_LIMIT
  };

struct E2PositionSizingResult
  {
   E2SizingStatus    status;
   double            volume;
   double            raw_volume;
   double            target_risk_money;
   double            actual_risk_money;
   double            actual_risk_percent;
   double            risk_base_value;
   double            stop_distance_price;
   double            stop_distance_pips;
   double            monetary_loss_per_lot;
  };
struct E2RiskModeVerification
  {int trades_sized,fixed_cash_requests,balance_percent_requests,invalid_risk_requests,non_positive_balance,risk_mode_mismatch,invalid_volume_after_sizing;double requested_min,requested_max,requested_sum,original_min,original_max;};

string E2SizingStatusName(const E2SizingStatus status)
  {
   switch(status)
     {
      case E2_SIZING_VALID:                    return("VALID");
      case E2_SIZING_INVALID_INPUT:            return("INVALID_INPUT");
      case E2_SIZING_INVALID_STOP:             return("INVALID_STOP");
      case E2_SIZING_ACCOUNT_DATA_UNAVAILABLE: return("ACCOUNT_DATA_UNAVAILABLE");
      case E2_SIZING_SYMBOL_DATA_UNAVAILABLE:  return("SYMBOL_DATA_UNAVAILABLE");
      case E2_SIZING_VOLUME_BELOW_MINIMUM:     return("VOLUME_BELOW_MINIMUM");
      case E2_SIZING_VOLUME_ABOVE_MAXIMUM:     return("VOLUME_ABOVE_MAXIMUM");
      case E2_SIZING_RISK_EXCEEDS_LIMIT:       return("RISK_EXCEEDS_LIMIT");
      default:                                  return("CALCULATION_FAILED");
     }
  }

class E2PositionSizer
  {
private:
   E2SymbolInfo      *m_symbol_info;
   E2AccountInfo     *m_account_info;
   E2Logger          *m_logger;
   E2RiskMode        m_risk_mode;
   double            m_fixed_cash_risk,m_balance_risk_percent;
   E2RiskModeVerification m_verify;

   void ResetResult(E2PositionSizingResult &result)
     {
      result.status=E2_SIZING_CALCULATION_FAILED;
      result.volume=0.0;
      result.raw_volume=0.0;
      result.target_risk_money=0.0;
      result.actual_risk_money=0.0;
      result.actual_risk_percent=0.0;
      result.risk_base_value=0.0;
      result.stop_distance_price=0.0;
      result.stop_distance_pips=0.0;
      result.monetary_loss_per_lot=0.0;
     }

   void ReportDebug(const string message) const
     {
      if(m_logger!=NULL)
         m_logger.Debug(message,"PositionSizer");
     }

   bool CalculateLoss(const string symbol,const E2TradeDirection direction,const double volume,const double entry_price,const double stop_price,double &loss)
     {
      double profit=0.0;
      const ENUM_ORDER_TYPE order_type=(direction==E2_DIRECTION_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      ResetLastError();
      if(!OrderCalcProfit(order_type,symbol,volume,entry_price,stop_price,profit))
        {
         ReportDebug("OrderCalcProfit failed (error "+IntegerToString(GetLastError())+").");
         return(false);
        }

      loss=MathAbs(profit);
      return(loss>0.0);
     }

public:
                     E2PositionSizer(void) : m_symbol_info(NULL),m_account_info(NULL),m_logger(NULL),m_risk_mode(E2_RISK_FIXED_CASH),m_fixed_cash_risk(0.0),m_balance_risk_percent(0.0) {ZeroMemory(m_verify);}

   void              Initialize(const E2Config &configuration,E2SymbolInfo &symbol_info,E2AccountInfo &account_info,E2Logger &logger)
     {
      m_symbol_info=&symbol_info;
      m_account_info=&account_info;
      m_logger=&logger;
      m_risk_mode=configuration.risk_mode;
      m_fixed_cash_risk=configuration.fixed_cash_risk;
      m_balance_risk_percent=configuration.balance_risk_percent;
      ZeroMemory(m_verify);
     }

   bool              CalculateRequestedRisk(const string symbol,const E2TradeDirection direction,const double entry_price,const double stop_price,E2PositionSizingResult &result,const bool record=false)
     {
      ResetResult(result);
      if(m_symbol_info==NULL || m_account_info==NULL || entry_price<=0.0 || stop_price<=0.0)
        {
         result.status=E2_SIZING_INVALID_INPUT;
         return(false);
        }

      if(!m_symbol_info.IsInitialized() || m_symbol_info.Specification().symbol!=symbol)
         if(!m_symbol_info.Refresh(symbol))
           {
            result.status=E2_SIZING_SYMBOL_DATA_UNAVAILABLE;
            return(false);
           }

      if(!m_account_info.Refresh())
        {
         result.status=E2_SIZING_ACCOUNT_DATA_UNAVAILABLE;
         return(false);
        }

      E2SymbolSpecification specification=m_symbol_info.Specification();
      if((direction==E2_DIRECTION_BUY && stop_price>=entry_price) ||
         (direction==E2_DIRECTION_SELL && stop_price<=entry_price))
        {
         result.status=E2_SIZING_INVALID_STOP;
         return(false);
        }

      result.stop_distance_price=MathAbs(entry_price-stop_price);
      result.stop_distance_pips=result.stop_distance_price/specification.pip_size;
      if(result.stop_distance_price+1e-12<specification.tick_size)
        {
         result.status=E2_SIZING_INVALID_STOP;
         return(false);
        }

      result.risk_base_value=AccountInfoDouble(ACCOUNT_BALANCE);
      if(result.risk_base_value<=0.0)
        {
         result.status=E2_SIZING_ACCOUNT_DATA_UNAVAILABLE;
         return(false);
        }
      result.target_risk_money=(m_risk_mode==E2_RISK_FIXED_CASH ? m_fixed_cash_risk : result.risk_base_value*m_balance_risk_percent/100.0);
      if(!MathIsValidNumber(result.target_risk_money)||result.target_risk_money<=0.0)
        {
         result.status=E2_SIZING_INVALID_INPUT;
         return(false);
        }

      if(!CalculateLoss(symbol,direction,1.0,entry_price,stop_price,result.monetary_loss_per_lot))
        {
         result.status=E2_SIZING_CALCULATION_FAILED;
         return(false);
        }

      result.raw_volume=result.target_risk_money/result.monetary_loss_per_lot;
      if(result.raw_volume<specification.volume_min)
        {
         result.status=E2_SIZING_VOLUME_BELOW_MINIMUM;
         return(false);
        }
      if(result.raw_volume>specification.volume_max)
        {
         result.status=E2_SIZING_VOLUME_ABOVE_MAXIMUM;
         return(false);
        }
      if(!m_symbol_info.NormalizeVolume(result.raw_volume,result.volume))
        {
         result.status=E2_SIZING_VOLUME_BELOW_MINIMUM;
         return(false);
        }

      if(!CalculateLoss(symbol,direction,result.volume,entry_price,stop_price,result.actual_risk_money))
        {
         result.status=E2_SIZING_CALCULATION_FAILED;
         return(false);
        }
      const double tolerance=MathMax(0.00000001,result.target_risk_money*0.00000001);
      while(result.actual_risk_money>result.target_risk_money+tolerance)
        {
         result.volume-=specification.volume_step;
         if(result.volume<specification.volume_min)
           {
            result.status=E2_SIZING_RISK_EXCEEDS_LIMIT;
            return(false);
           }
         if(!CalculateLoss(symbol,direction,result.volume,entry_price,stop_price,result.actual_risk_money))
           {
            result.status=E2_SIZING_CALCULATION_FAILED;
            return(false);
           }
        }

      result.actual_risk_percent=result.actual_risk_money/result.risk_base_value*100.0;
      if(record){m_verify.trades_sized++;if(m_risk_mode==E2_RISK_FIXED_CASH)m_verify.fixed_cash_requests++;else if(m_risk_mode==E2_RISK_BALANCE_PERCENT)m_verify.balance_percent_requests++;m_verify.requested_sum+=result.target_risk_money;if(m_verify.trades_sized==1){m_verify.requested_min=result.target_risk_money;m_verify.requested_max=result.target_risk_money;}else{m_verify.requested_min=MathMin(m_verify.requested_min,result.target_risk_money);m_verify.requested_max=MathMax(m_verify.requested_max,result.target_risk_money);}}
      result.status=E2_SIZING_VALID;
      return(true);
     }

   // The historical name remains only to keep planning call sites source-compatible.
   // Risk is always resolved from the configured mode and current account balance.
   bool              CalculateFixedInitialBalance(const string symbol,const E2TradeDirection direction,const double entry_price,const double stop_price,const double initial_balance,E2PositionSizingResult &result)
     {
      return(CalculateRequestedRisk(symbol,direction,entry_price,stop_price,result,false));
     }
   void RecordOriginalRiskCash(const double value){if(!MathIsValidNumber(value)||value<=0.0){m_verify.invalid_risk_requests++;return;}if(m_verify.original_min<=0.0){m_verify.original_min=value;m_verify.original_max=value;}else{m_verify.original_min=MathMin(m_verify.original_min,value);m_verify.original_max=MathMax(m_verify.original_max,value);}}
   E2RiskModeVerification Verification()const{return(m_verify);}

  };

#endif // E2_RISK_E2POSITIONSIZER_MQH
