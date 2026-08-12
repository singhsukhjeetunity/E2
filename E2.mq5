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
#include "include\\execution\\Execution.mqh"

E2Config g_configuration;
E2Environment g_environment;
E2Logger g_logger;
E2CsvExporter g_csv_exporter;
E2MarketData g_market_data;
E2TrendAnalyzer g_trend_analyzer;
E2ZoneAnalyzer g_zone_analyzer;
E2ConfirmationAnalyzer g_confirmation_analyzer;
E2SymbolInfo g_symbol_info;
E2AccountInfo g_account_info;
E2PositionSizer g_position_sizer;
E2TradePlanner g_trade_planner;
E2OrderExecutor g_order_executor;
E2PositionGuard g_position_guard;
E2PositionManager g_position_manager;
E2ExecutionSafety g_execution_safety;
ulong g_diagnostic_tick_count=0;
bool g_execution_test_attempted=false;
bool g_trend_diagnostic_completed=false;
datetime g_last_trend_readiness_diagnostic_bar=0;
datetime g_last_zone_diagnostic_day=0;
datetime g_last_confirmation_diagnostic_candle=0;

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

void E2RunTrendDiagnostic(void)
  {
   if(g_environment.IsOptimization() || !g_logger.IsDebugEnabled() || g_trend_diagnostic_completed)
      return;

   const datetime throttle_bar=iTime(_Symbol,PERIOD_H1,0);
   if(throttle_bar<=0 || throttle_bar==g_last_trend_readiness_diagnostic_bar)
      return;
   g_last_trend_readiness_diagnostic_bar=throttle_bar;

   const datetime evaluation_time=TimeCurrent();
   E2TrendResult result;
   if(g_trend_analyzer.Evaluate(_Symbol,evaluation_time,result))
     {
      g_logger.Debug("Evaluation="+TimeToString(evaluation_time,TIME_DATE|TIME_MINUTES)+", closedH4="+TimeToString(result.closed_bar_time,TIME_DATE|TIME_MINUTES)+", trend="+E2TrendStateName(result.state)+", ADX="+(result.adx_available ? DoubleToString(result.adx_value,2) : "disabled")+", threshold="+DoubleToString(g_configuration.adx_minimum_threshold,2)+", pass="+E2YesNo(result.adx_passed)+", high="+E2StructureLabelName(result.latest_high_label)+", low="+E2StructureLabelName(result.latest_low_label)+", pivots="+IntegerToString(result.confirmed_pivot_count)+".","Trend");
      g_trend_diagnostic_completed=true;
     }
   else
      g_logger.Debug("Not ready: "+result.readiness_reason+" Evaluation="+TimeToString(evaluation_time,TIME_DATE|TIME_MINUTES)+", closedH4="+(result.closed_bar_time>0 ? TimeToString(result.closed_bar_time,TIME_DATE|TIME_MINUTES) : "unresolved")+", H4bars="+IntegerToString(result.h4_available_bars)+", ADXrequiredBars="+IntegerToString(result.adx_required_bars)+", pivots="+IntegerToString(result.confirmed_pivot_count)+".","Trend");
  }

void E2RunZoneDiagnostic(void)
  {
   if(g_environment.IsOptimization() || !g_logger.IsDebugEnabled()) return;
   datetime bar=iTime(_Symbol,g_configuration.zone_timeframe,0);
   MqlDateTime parts; TimeToStruct(bar,parts); parts.hour=0; parts.min=0; parts.sec=0;
   const datetime day=StructToTime(parts);
   if(bar<=0 || day==g_last_zone_diagnostic_day) return;
   g_last_zone_diagnostic_day=day;
   E2Zone zones[]; int candidates=0;
   if(!g_zone_analyzer.Evaluate(_Symbol,TimeCurrent(),zones,candidates)){g_logger.Debug("Evaluation unavailable.","Zones");return;}
   int raw_active=0,awaiting=0,reversed=0,invalid=0,actionable=0;
   for(int i=0;i<ArraySize(zones);i++){if(zones[i].state==E2_ZONE_ACTIVE)raw_active++;else if(zones[i].state==E2_ZONE_BROKEN_AWAITING_RETEST)awaiting++;else if(zones[i].state==E2_ZONE_ROLE_REVERSED_ACTIVE)reversed++;else if(zones[i].state==E2_ZONE_INVALIDATED)invalid++;if(zones[i].actionable)actionable++;}
   g_logger.Debug("Evaluation="+TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES)+", candidates="+IntegerToString(candidates)+", rawActive="+IntegerToString(raw_active)+", awaitingRetest="+IntegerToString(awaiting)+", reversed="+IntegerToString(reversed)+", invalidated="+IntegerToString(invalid)+", actionable="+IntegerToString(actionable)+", duplicatesSuppressed="+IntegerToString(raw_active+reversed-actionable)+".","ZonesSnapshot");
   E2SymbolSpecification spec=g_symbol_info.Specification();
   for(int i=0;i<ArraySize(zones);i++) if(zones[i].actionable) g_logger.Debug("id="+IntegerToString(zones[i].id)+", role="+E2ZoneTypeName(zones[i].type)+", originRole="+E2ZoneTypeName(zones[i].origin_type)+", lower="+DoubleToString(zones[i].lower,spec.digits)+", upper="+DoubleToString(zones[i].upper,spec.digits)+", center="+DoubleToString(zones[i].center,spec.digits)+", touches="+IntegerToString(zones[i].touches)+", origin="+TimeToString(zones[i].origin_time,TIME_DATE|TIME_MINUTES)+", knownFrom="+TimeToString(zones[i].known_from_time,TIME_DATE|TIME_MINUTES)+", lastTouch="+TimeToString(zones[i].last_touch_time,TIME_DATE|TIME_MINUTES)+", state="+E2ZoneStateName(zones[i].state)+".","ZonesSnapshot");
  }

void E2RunConfirmationDiagnostic(void)
  {
   if(g_environment.IsOptimization() || !g_logger.IsDebugEnabled()) return;
   const datetime evaluation_time=TimeCurrent();
   MqlRates closed;
   if(!g_market_data.GetClosedBarAsOf(_Symbol,g_configuration.confirmation_timeframe,evaluation_time,closed)) return;
   if(closed.time==g_last_confirmation_diagnostic_candle) return;
   g_last_confirmation_diagnostic_candle=closed.time;
   E2ConfirmationResult result;
   if(!g_confirmation_analyzer.Evaluate(_Symbol,evaluation_time,result))
     {
      g_logger.Debug("Not ready: reason="+result.reason+", Evaluation="+TimeToString(evaluation_time,TIME_DATE|TIME_MINUTES)+", candle="+(result.candle_time>0 ? TimeToString(result.candle_time,TIME_DATE|TIME_MINUTES) : "unresolved")+", required="+IntegerToString(result.required_bars)+", available="+IntegerToString(result.available_bars)+".","Confirmation");
      return;
     }
   if(result.readiness==E2_CONFIRMATION_NO_CONFIRMATIONS_ENABLED)
      return;
   if(result.readiness!=E2_CONFIRMATION_VALID || result.direction!=E2_CONFIRMATION_NONE || result.directional_conflict)
      g_logger.Debug("Evaluation="+TimeToString(evaluation_time,TIME_DATE|TIME_MINUTES)+", candle="+(result.candle_time>0 ? TimeToString(result.candle_time,TIME_DATE|TIME_MINUTES) : "n/a")+", direction="+E2ConfirmationDirectionName(result.direction)+", bullishPassed="+IntegerToString(result.bullish_passed)+", bearishPassed="+IntegerToString(result.bearish_passed)+", engulfing="+E2ConfirmationDirectionName(result.engulfing)+", pin="+E2ConfirmationDirectionName(result.pin_bar)+", momentum="+E2ConfirmationDirectionName(result.momentum)+", previousBreak="+E2ConfirmationDirectionName(result.previous_break)+", readiness="+E2ConfirmationReadinessName(result.readiness)+", conflict="+E2YesNo(result.directional_conflict)+".","Confirmation");
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

void E2RunExecutionTestHarness(void)
  {
   if(!g_configuration.execution_test_enabled || g_execution_test_attempted)
      return;

   if(!g_symbol_info.IsInitialized() || !g_account_info.IsInitialized())
     {
      g_logger.Warning("Execution test cannot run because symbol/account data is unavailable.","Execution");
      g_execution_test_attempted=true;
      return;
     }

   E2AccountSpecification account=g_account_info.Specification();
   if(!g_environment.IsTester() && account.trade_mode!=ACCOUNT_TRADE_MODE_DEMO)
     {
      g_logger.Warning("Execution test is restricted to Strategy Tester or demo accounts.","Execution");
      g_execution_test_attempted=true;
      return;
     }

   g_execution_test_attempted=true;
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
   intent.strategy_id="execution_test";
   intent.setup_time=TimeCurrent();
   intent.reason_tag="explicit test harness";
   E2TradePlan plan;
   if(!g_trade_planner.CreatePlan(intent,plan))
     {
      g_trade_planner.LogDiagnostic(plan);
      return;
     }
   E2ExecutionResult result;
   if(g_order_executor.Execute(plan,"E2 execution test",result))
     {
      E2ExecutionResult duplicate_result;
      g_order_executor.Execute(plan,"E2 execution test duplicate",duplicate_result);
     }
  }
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   E2LoadConfiguration(g_configuration);
   g_environment.Initialize();
   g_diagnostic_tick_count=0;
   g_execution_test_attempted=false;
   g_trend_diagnostic_completed=false;
   g_last_trend_readiness_diagnostic_bar=0;
   g_last_zone_diagnostic_day=0;
   g_last_confirmation_diagnostic_candle=0;
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
   g_position_guard.Initialize(g_configuration,g_logger);
   g_position_manager.Initialize(g_configuration,g_logger);
   g_execution_safety.Initialize(g_configuration,g_logger);
   g_order_executor.Initialize(g_configuration,g_symbol_info,g_account_info,g_position_guard,g_position_manager,g_execution_safety,g_logger);
   g_market_data.Initialize(g_configuration,g_logger);
   g_trend_analyzer.Initialize(g_configuration,g_market_data,g_logger);
   g_zone_analyzer.Initialize(g_configuration,g_market_data,g_symbol_info);
   g_confirmation_analyzer.Initialize(g_configuration,g_market_data);
   E2LogStartupDiagnostics();
   E2RunMarketDataStartupDiagnostic();
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
   g_position_manager.Refresh();
   E2RunTrendDiagnostic();
   E2RunZoneDiagnostic();
   E2RunConfirmationDiagnostic();
   E2RunExecutionTestHarness();
  }
//+------------------------------------------------------------------+
