#ifndef E2_VISUALIZATION_E2VISUALIZER_MQH
#define E2_VISUALIZATION_E2VISUALIZER_MQH

#include "..\\core\\E2Config.mqh"
#include "..\\analysis\\E2ZoneAnalyzer.mqh"
#include "..\\strategy\\E2StrategyAnalyzer.mqh"
#include "..\\reporting\\E2TradeReporter.mqh"

// Read-only Strategy Tester chart overlay. No strategy component reads it.
class E2Visualizer
  {
private:
   E2Config m_config;
   E2Logger *m_logger;
   bool m_active,m_logged_zone_update;
   datetime m_last_zone_update;
   long m_chart_id;
   string m_reported_kinds[];
   string Id(const string value) const { return("E2VIS_"+value); }
   string ErrorText(const int error) const { return(error==0 ? "none" : (error==4202 ? "object does not exist" : (error==4204 ? "object already exists" : "MT5 chart-object API error"))); }
   bool Reported(const string kind) const { for(int i=0;i<ArraySize(m_reported_kinds);i++)if(m_reported_kinds[i]==kind)return(true);return(false); }
   void ReportCreate(const string kind,const string name,const ENUM_OBJECT type,const bool ok)
     {
      if(Reported(kind)) return;
      int n=ArraySize(m_reported_kinds);ArrayResize(m_reported_kinds,n+1);m_reported_kinds[n]=kind;
      if(m_logger==NULL) return;
      if(ok) m_logger.Debug("first "+kind+" object created: name='"+name+"', type="+IntegerToString((int)type)+", chartId="+StringFormat("%I64d",m_chart_id)+", find="+IntegerToString(ObjectFind(m_chart_id,name))+".","Visualization");
      else m_logger.Warning("first "+kind+" object failed: name='"+name+"', type="+IntegerToString((int)type)+", chartId="+StringFormat("%I64d",m_chart_id)+", error="+IntegerToString(GetLastError())+" ("+ErrorText(GetLastError())+").","Visualization");
     }
   bool Create(const string kind,const string name,const ENUM_OBJECT type,const datetime t1,const double p1,const datetime t2=0,const double p2=0.0)
     {
      bool ok=true;
      if(ObjectFind(m_chart_id,name)<0)
        {
         ResetLastError();
         ok=ObjectCreate(m_chart_id,name,type,0,t1,p1,t2,p2);
         ReportCreate(kind,name,type,ok);
        }
      if(!ok || ObjectFind(m_chart_id,name)<0) return(false);
      ObjectMove(m_chart_id,name,0,t1,p1); if(t2>0) ObjectMove(m_chart_id,name,1,t2,p2); return(true);
     }
   void Text(const string kind,const string name,const datetime time,const double price,const string value,const color shade) { if(Create(kind,name,OBJ_TEXT,time,price)){ObjectSetString(m_chart_id,name,OBJPROP_TEXT,value);ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,shade);ObjectSetInteger(m_chart_id,name,OBJPROP_FONTSIZE,9);ObjectSetInteger(m_chart_id,name,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);ObjectSetInteger(m_chart_id,name,OBJPROP_HIDDEN,false);} }
   void Arrow(const string kind,const string name,const datetime time,const double price,const bool up,const color shade) { if(Create(kind,name,up ? OBJ_ARROW_BUY : OBJ_ARROW_SELL,time,price)){ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,shade);ObjectSetInteger(m_chart_id,name,OBJPROP_WIDTH,3);ObjectSetInteger(m_chart_id,name,OBJPROP_HIDDEN,false);} }
   string TradeKey(const ulong entry_deal) const { return("D"+StringFormat("%I64u",entry_deal)); }
   double ExitPrice(const E2ReportedTrade &trade) const { return(trade.exit_volume>0.0 ? trade.exit_value/trade.exit_volume : 0.0); }
   void Refresh(void) const { if(m_chart_id>=0) ChartRedraw(m_chart_id); }
public:
   E2Visualizer(void):m_logger(NULL),m_active(false),m_logged_zone_update(false),m_last_zone_update(0),m_chart_id(0) {}
   void Initialize(const E2Config &config,E2Logger &logger)
     {
      m_config=config;m_logger=&logger;m_chart_id=ChartID();m_last_zone_update=0;m_logged_zone_update=false;ArrayResize(m_reported_kinds,0);
      const bool tester=(MQLInfoInteger(MQL_TESTER)!=0),visual_mode=(MQLInfoInteger(MQL_VISUAL_MODE)!=0);
      // MQL_VISUAL_MODE is diagnostic only: Tester chart-object access is the
      // capability required by this overlay, and some tester agents report the
      // visual-mode property inconsistently during EA initialization.
      m_active=(m_config.visual_mode_enabled && tester && m_chart_id>=0);
      if(m_logger!=NULL) m_logger.Debug("requested="+(m_config.visual_mode_enabled ? "yes" : "no")+", tester="+(tester ? "yes" : "no")+", visualMode="+(visual_mode ? "yes" : "no")+", active="+(m_active ? "yes" : "no")+", chartId="+StringFormat("%I64d",m_chart_id)+".","Visualization");
     }
   bool IsActive(void) const { return(m_active); }
   void UpdateZones(const E2Zone &zones[],const datetime evaluation)
     {
      if(!m_active || !m_config.visual_show_zones || evaluation==m_last_zone_update) return;
      m_last_zone_update=evaluation; int actionable=0;for(int z=0;z<ArraySize(zones);z++)if(zones[z].actionable)actionable++;
      if(!m_logged_zone_update && m_logger!=NULL){m_logger.Debug("zonesReceived="+IntegerToString(ArraySize(zones))+", actionable="+IntegerToString(actionable)+", chartId="+StringFormat("%I64d",m_chart_id)+".","Visualization");m_logged_zone_update=true;}
      for(int i=0;i<ArraySize(zones);i++)
        {
         const string base="ZONE_"+IntegerToString(zones[i].id)+"_"+IntegerToString((int)zones[i].known_from_time),active_name=Id(base+"_ACTIVE"),reversed_name=Id(base+"_REV");
         if(zones[i].state==E2_ZONE_BROKEN_AWAITING_RETEST && zones[i].break_time>0 && ObjectFind(m_chart_id,active_name)>=0)ObjectMove(m_chart_id,active_name,1,zones[i].break_time,zones[i].upper);
         if(zones[i].state==E2_ZONE_INVALIDATED){if(ObjectFind(m_chart_id,reversed_name)>=0)ObjectMove(m_chart_id,reversed_name,1,evaluation,zones[i].upper);else if(ObjectFind(m_chart_id,active_name)>=0)ObjectMove(m_chart_id,active_name,1,evaluation,zones[i].upper);continue;}
         if(!zones[i].actionable) continue;
         const bool reversed=(zones[i].state==E2_ZONE_ROLE_REVERSED_ACTIVE);if(reversed && zones[i].reversal_time>0 && ObjectFind(m_chart_id,active_name)>=0)ObjectMove(m_chart_id,active_name,1,zones[i].reversal_time,zones[i].upper);
         const string key=base+(reversed ? "_REV" : "_ACTIVE");const datetime start=(reversed && zones[i].reversal_time>0 ? zones[i].reversal_time : (zones[i].activation_time>0 ? zones[i].activation_time : zones[i].known_from_time));
         if(!Create("ZONE",Id(key),OBJ_RECTANGLE,start,zones[i].lower,evaluation,zones[i].upper)) continue;
         ObjectSetInteger(m_chart_id,Id(key),OBJPROP_COLOR,(reversed ? clrOrange : (zones[i].type==E2_ZONE_SUPPORT ? clrLimeGreen : clrRed)));ObjectSetInteger(m_chart_id,Id(key),OBJPROP_FILL,true);ObjectSetInteger(m_chart_id,Id(key),OBJPROP_BACK,false);ObjectSetInteger(m_chart_id,Id(key),OBJPROP_WIDTH,2);ObjectSetInteger(m_chart_id,Id(key),OBJPROP_HIDDEN,false);
         Text("ZONE",Id(key+"_LABEL"),start,zones[i].upper,"Z"+IntegerToString(zones[i].id)+" "+E2ZoneTypeName(zones[i].type)+(reversed ? " REV" : ""),clrWhite);
        }
      Refresh();
     }
   void UpdateTrend(const E2StrategyResult &result,const double threshold)
     {
      if(!m_active || !m_config.visual_show_trend_panel) return;
      const string name=Id("TREND_PANEL");bool ok=true;if(ObjectFind(m_chart_id,name)<0){ResetLastError();ok=ObjectCreate(m_chart_id,name,OBJ_LABEL,0,0,0);ReportCreate("TREND_PANEL",name,OBJ_LABEL,ok);}if(!ok || ObjectFind(m_chart_id,name)<0)return;
      ObjectSetInteger(m_chart_id,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(m_chart_id,name,OBJPROP_XDISTANCE,12);ObjectSetInteger(m_chart_id,name,OBJPROP_YDISTANCE,24);ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,clrYellow);ObjectSetInteger(m_chart_id,name,OBJPROP_FONTSIZE,11);ObjectSetInteger(m_chart_id,name,OBJPROP_HIDDEN,false);ObjectSetString(m_chart_id,name,OBJPROP_TEXT,"E2 H4 "+E2TrendStateName(result.trend_state)+" | ADX "+DoubleToString(result.adx_value,2)+" / "+DoubleToString(threshold,2));Refresh();
     }
   void MarkCandidate(const E2StrategyResult &result,const MqlRates &candle,const string rejection="")
     {
      if(!m_active)return;const bool up=(result.signal==E2_SIGNAL_LONG);const string base="CAND_"+IntegerToString((int)result.confirmation_candle_time);
      if(m_config.visual_show_confirmations){Arrow("CONFIRMATION",Id(base),result.confirmation_candle_time,(up ? candle.low : candle.high),up,(up ? clrLimeGreen : clrRed));Text("CONFIRMATION",Id(base+"_TXT"),result.confirmation_candle_time,(up ? candle.low : candle.high),(up ? "BULL" : "BEAR")+" "+TimeToString(result.confirmation_candle_time,TIME_MINUTES),clrWhite);}
      if(rejection!="" && m_config.visual_show_rejected_candidates)Text("CONFIRMATION",Id(base+"_REJ_"+rejection),result.confirmation_candle_time,(up ? candle.low : candle.high),"REJECTED "+rejection,clrOrange);Refresh();
     }
   void DrawEntry(const E2ReportEntryData &entry)
     {
      if(!m_active || !m_config.visual_show_trades)return;const bool up=(entry.direction=="LONG");const string key=TradeKey(entry.entry_deal);
      Arrow("ENTRY",Id("ENTRY_"+key),entry.entry_time,entry.fill_price,up,(up ? clrDodgerBlue : clrMagenta));Text("ENTRY",Id("ENTRYTXT_"+key),entry.entry_time,entry.fill_price,entry.direction+" deal="+StringFormat("%I64u",entry.entry_deal)+" Z"+IntegerToString(entry.zone_id)+" V"+IntegerToString(entry.zone_visit)+" "+entry.session+" OPEN",clrWhite);
      if(Create("SL_TP",Id("SL_"+key),OBJ_TREND,entry.entry_time,entry.stop_loss,TimeCurrent(),entry.stop_loss)){ObjectSetInteger(m_chart_id,Id("SL_"+key),OBJPROP_COLOR,clrRed);ObjectSetInteger(m_chart_id,Id("SL_"+key),OBJPROP_WIDTH,2);ObjectSetInteger(m_chart_id,Id("SL_"+key),OBJPROP_RAY_RIGHT,false);}
      if(Create("SL_TP",Id("TP_"+key),OBJ_TREND,entry.entry_time,entry.take_profit,TimeCurrent(),entry.take_profit)){ObjectSetInteger(m_chart_id,Id("TP_"+key),OBJPROP_COLOR,clrLimeGreen);ObjectSetInteger(m_chart_id,Id("TP_"+key),OBJPROP_WIDTH,2);ObjectSetInteger(m_chart_id,Id("TP_"+key),OBJPROP_RAY_RIGHT,false);}Refresh();
     }
   void DrawFinal(const E2ReportedTrade &trade)
     {
      if(!m_active || !m_config.visual_show_trades || !trade.finalized)return;const string key=TradeKey(trade.entry_deal);const double exit_price=ExitPrice(trade),net=trade.profit+trade.commission+trade.swap+trade.fee,r=(trade.entry.planned_risk>0.0 ? net/trade.entry.planned_risk : 0.0);
      Arrow("EXIT",Id("EXIT_"+key),trade.exit_time,exit_price,(trade.entry.direction!="LONG"),clrGold);Text("EXIT",Id("EXITTXT_"+key),trade.exit_time,exit_price,"E2-"+StringFormat("%I64u",trade.position_id)+" "+trade.exit_reason+" "+DoubleToString(r,2)+"R",clrGold);
      ObjectMove(m_chart_id,Id("SL_"+key),1,trade.exit_time,trade.entry.stop_loss);ObjectMove(m_chart_id,Id("TP_"+key),1,trade.exit_time,trade.entry.take_profit);Text("ENTRY",Id("ENTRYTXT_"+key),trade.entry.entry_time,trade.entry.fill_price,trade.entry.direction+" E2-"+StringFormat("%I64u",trade.position_id)+" Z"+IntegerToString(trade.entry.zone_id)+" V"+IntegerToString(trade.entry.zone_visit)+" "+trade.entry.session,clrWhite);Refresh();
     }
   void Cleanup(void)
     {
      if(!m_active || !m_config.visual_cleanup_on_deinit)return;for(int i=ObjectsTotal(m_chart_id,0,-1)-1;i>=0;i--){string name=ObjectName(m_chart_id,i,0,-1);if(StringFind(name,"E2VIS_")==0)ObjectDelete(m_chart_id,name);}Refresh();
     }
  };

#endif // E2_VISUALIZATION_E2VISUALIZER_MQH
