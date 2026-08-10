//+------------------------------------------------------------------+
//|                                                           E2.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "include\\core\\E2Config.mqh"

E2Config g_configuration;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   E2LoadConfiguration(g_configuration);

   string validation_reason;
   if(!E2ValidateConfiguration(g_configuration,validation_reason))
     {
      Print("E2 configuration error: ",validation_reason);
      return(INIT_PARAMETERS_INCORRECT);
     }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
