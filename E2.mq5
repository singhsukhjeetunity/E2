//+------------------------------------------------------------------+
//|                                                           E2.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "include\\core\\E2Config.mqh"
#include "include\\core\\Core.mqh"
#include "include\\core\\E2Environment.mqh"
#include "include\\reporting\\Reporting.mqh"
#include "include\\analysis\\Analysis.mqh"
#include "include\\risk\\Risk.mqh"

E2Config g_configuration;
E2Environment g_environment;
E2Logger g_logger;
E2CsvExporter g_csv_exporter;
E2MarketData g_market_data;
E2TrendAnalyzer g_trend_analyzer;
E2SymbolInfo g_symbol_info;
E2AccountInfo g_account_info;
E2PositionSizer g_position_sizer;
E2TradePlanner g_trade_planner;
ulong g_diagnostic_tick_count=0;

string E2TimeframeName(const ENUM_TIMEFRAMES timeframe)
  {
   string name=EnumToString(timeframe);
   StringReplace(name,"PERIOD_","");
   return(name);
  }

string E2YesNo(const bool value)
  {
   return(value ? "yes" : "no");
  }

void E2LogStartupDiagnostics(void)
  {
   if(g_environment.IsOptimization())
     {
      g_logger.Info("Optimization environment detected; detailed startup diagnostics suppressed.","Lifecycle");
      return;
     }

   g_logger.Info("Runtime: symbol="+_Symbol+", timeframe="+E2TimeframeName((ENUM_TIMEFRAMES)Period())+", environment="+g_environment.Name()+".","Lifecycle");
   g_logger.Info("Timeframes: trend="+E2TimeframeName(g_configuration.trend_timeframe)+", zone="+E2TimeframeName(g_configuration.zone_timeframe)+", confirmation="+E2TimeframeName(g_configuration.confirmation_timeframe)+".","Lifecycle");
   g_logger.Info("Flags: tester="+E2YesNo(g_environment.IsTester())+", optimization="+E2YesNo(g_environment.IsOptimization())+", trading="+E2YesNo(g_configuration.trading_enabled)+", logging="+E2YesNo(g_configuration.logging_enabled)+", csv="+E2YesNo(g_configuration.csv_export_enabled)+".","Lifecycle");
  }

void E2LogClosedBarDiagnostic(const string label,const ENUM_TIMEFRAMES timeframe,const datetime evaluation_time)
  {
   MqlRates bar;
   if(g_market_data.GetClosedBarAsOf(_Symbol,timeframe,evaluation_time,bar))
      g_logger.Debug(label+" closed bar as of "+TimeToString(evaluation_time,TIME_DATE|TIME_MINUTES)+": opened "+TimeToString(bar.time,TIME_DATE|TIME_MINUTES)+".","MarketData");
  }

void E2RunMarketDataStartupDiagnostic(void)
  {
   if(g_environment.IsOptimization())
      return;

   const datetime evaluation_time=TimeCurrent();
   E2LogClosedBarDiagnostic("Trend",g_market_data.TrendTimeframe(),evaluation_time);
   E2LogClosedBarDiagnostic("Zone",g_market_data.ZoneTimeframe(),evaluation_time);
   E2LogClosedBarDiagnostic("Confirmation",g_market_data.ConfirmationTimeframe(),evaluation_time);
  }

void E2RunTrendStartupDiagnostic(void)
  {
   if(g_environment.IsOptimization())
      return;

   E2TrendResult result;
   if(g_trend_analyzer.Evaluate(_Symbol,TimeCurrent(),result))
     {
      g_logger.Debug("Trend: "+E2TrendStateName(result.state)+", ADX: "+(result.adx_available ? DoubleToString(result.adx_value,2) : "unavailable")+", ADX pass: "+E2YesNo(result.adx_passed)+", structure: high="+E2StructureLabelName(result.latest_high_label)+", low="+E2StructureLabelName(result.latest_low_label)+", pivots="+IntegerToString(result.confirmed_pivot_count)+".","Trend");
     }
  }

void E2RunSpecificationStartupDiagnostic(void)
  {
   if(g_environment.IsOptimization())
      return;

   if(g_symbol_info.IsInitialized())
     {
      E2SymbolSpecification symbol=g_symbol_info.Specification();
      g_logger.Debug("Symbol: "+symbol.symbol+", digits="+IntegerToString(symbol.digits)+", point="+DoubleToString(symbol.point,symbol.digits)+", pip="+DoubleToString(symbol.pip_size,symbol.digits)+", tick size="+DoubleToString(symbol.tick_size,symbol.digits)+", tick value="+DoubleToString(symbol.tick_value,2)+", volume min="+DoubleToString(symbol.volume_min,2)+", max="+DoubleToString(symbol.volume_max,2)+", step="+DoubleToString(symbol.volume_step,2)+".","Specifications");
     }

   if(g_account_info.IsInitialized())
     {
      E2AccountSpecification account=g_account_info.Specification();
      g_logger.Debug("Account: currency="+account.currency+", balance="+DoubleToString(account.balance,2)+", equity="+DoubleToString(account.equity,2)+", free margin="+DoubleToString(account.free_margin,2)+", leverage="+IntegerToString((int)account.leverage)+".","Specifications");
     }
  }

void E2RunTradePlanningStartupDiagnostic(void)
  {
   if(g_environment.IsOptimization() || !g_logger.IsDebugEnabled() || !g_symbol_info.IsInitialized() || !g_account_info.IsInitialized())
      return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.ask<=0.0)
      return;

   E2SymbolSpecification specification=g_symbol_info.Specification();
   E2TradeIntent intent;
   intent.symbol=_Symbol;
   intent.direction=E2_DIRECTION_BUY;
   intent.entry_price=tick.ask;
   intent.stop_loss_price=g_symbol_info.NormalizePrice(intent.entry_price-specification.tick_size*100.0);
   intent.reward_risk_target=g_configuration.reward_risk_target;
   intent.strategy_id="diagnostic";
   intent.setup_time=TimeCurrent();
   intent.reason_tag="startup sample";

   E2TradePlan plan;
   g_trade_planner.CreatePlan(intent,plan);
   g_trade_planner.LogDiagnostic(plan);
  }
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   E2LoadConfiguration(g_configuration);
   g_environment.Initialize();
   g_diagnostic_tick_count=0;
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
   if(!g_symbol_info.Initialize(_Symbol,g_logger))
      g_logger.Warning("Symbol specification diagnostics are unavailable for this run.","Lifecycle");
   if(!g_account_info.Initialize(g_logger))
      g_logger.Warning("Account specification diagnostics are unavailable for this run.","Lifecycle");
   g_position_sizer.Initialize(g_configuration,g_symbol_info,g_account_info,g_logger);
   g_trade_planner.Initialize(g_symbol_info,g_position_sizer,g_logger);
   g_market_data.Initialize(g_configuration,g_logger);
   g_trend_analyzer.Initialize(g_configuration,g_market_data,g_logger);
   E2LogStartupDiagnostics();
   E2RunMarketDataStartupDiagnostic();
   E2RunTrendStartupDiagnostic();
   E2RunSpecificationStartupDiagnostic();
   E2RunTradePlanningStartupDiagnostic();

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
   g_trend_analyzer.Deinitialize();
   g_csv_exporter.Close();
   g_logger.Info("Run completed: symbol="+_Symbol+", environment="+g_environment.Name()+", ticks="+StringFormat("%I64u",g_diagnostic_tick_count)+", reason="+IntegerToString(reason)+".","Lifecycle");
   g_logger.Info("E2 deinitialized.","Lifecycle");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_diagnostic_tick_count++;
  }
//+------------------------------------------------------------------+
