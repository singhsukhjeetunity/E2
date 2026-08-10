//+------------------------------------------------------------------+
//|                                                           E2.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "include\\core\\E2Config.mqh"
#include "include\\reporting\\Reporting.mqh"

E2Config g_configuration;
E2Logger g_logger;
E2CsvExporter g_csv_exporter;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   E2LoadConfiguration(g_configuration);
   g_logger.Initialize(g_configuration.logging_enabled,g_configuration.debug_mode);
   g_logger.Info("E2 initialization started.","Lifecycle");

   string validation_reason;
   if(!E2ValidateConfiguration(g_configuration,validation_reason))
     {
      g_logger.Error("Configuration validation failed: "+validation_reason,"Lifecycle");
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_logger.Info("Configuration validated.","Lifecycle");
   g_logger.Debug("Debug logging is enabled.","Lifecycle");

   if(g_configuration.csv_export_enabled)
     {
      if(g_csv_exporter.Initialize("E2_startup.csv",g_logger))
        {
         string header[] = {"event","time","symbol","message"};
         if(!g_csv_exporter.WriteHeader(header))
           {
            g_logger.Warning("CSV export disabled for this run after header write failure.","Lifecycle");
            g_csv_exporter.Close();
           }
         else
           {
            string startup_row[] = {"startup",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),_Symbol,"E2 reporting initialized"};
            if(!g_csv_exporter.WriteRow(startup_row))
              {
               g_logger.Warning("CSV export disabled for this run after startup-row write failure.","Lifecycle");
               g_csv_exporter.Close();
              }
           }
        }
      else
        {
         g_logger.Warning("CSV export disabled for this run because initialization failed.","Lifecycle");
        }
     }

   g_logger.Info("Reporting initialized.","Lifecycle");
   g_logger.Info("E2 initialized successfully.","Lifecycle");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_csv_exporter.Close();
   g_logger.Info("E2 deinitialized (reason "+IntegerToString(reason)+").","Lifecycle");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
