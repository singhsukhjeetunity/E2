#ifndef E2_VISUALIZATION_E2VISUALIZER_MQH
#define E2_VISUALIZATION_E2VISUALIZER_MQH

#include "..\\core\\E2Config.mqh"
#include "..\\analysis\\E2ZoneAnalyzer.mqh"
#include "..\\strategy\\E2StrategyAnalyzer.mqh"
#include "..\\reporting\\E2TradeReporter.mqh"

// Read-only visual audit. It consumes existing runtime metadata only.
class E2Visualizer
  {
private:
   E2Config m_config;
   E2Logger *m_logger;
   bool m_active,m_has_trend,m_focus_missing_reported;
   long m_chart_id;
   E2TrendState m_last_trend;
   E2Zone m_latest_zones[];
   E2ReportEntryData m_entries[];

   string Id(const string value) const { return("E2VIS_"+value); }
   long H4(void) const { return(OBJ_PERIOD_H4); }
   long H1(void) const { return(OBJ_PERIOD_H1); }
   long M15(void) const { return(OBJ_PERIOD_M15); }
   long TradeFrames(void) const { return(OBJ_PERIOD_H1|OBJ_PERIOD_M15); }
   bool IsStrategyAudit(void) const { return(m_config.visual_audit_mode==E2_VISUAL_STRATEGY_AUDIT); }
   bool IsSingleTrade(void) const { return(m_config.visual_audit_mode==E2_VISUAL_SINGLE_TRADE); }
   bool MatchesFocus(const ulong position_id) const { return(!IsSingleTrade() || (m_config.visual_focus_trade_id>0 && position_id==m_config.visual_focus_trade_id)); }
   string Key(const ulong position_id) const { return("TRADE_E2_"+StringFormat("%I64u",position_id)); }
   bool Create(const string name,const ENUM_OBJECT type,const long frames,const datetime t1,const double p1,const datetime t2=0,const double p2=0.0)
     {
      if(ObjectFind(m_chart_id,name)<0 && !ObjectCreate(m_chart_id,name,type,0,t1,p1,t2,p2)) return(false);
      ObjectMove(m_chart_id,name,0,t1,p1);if(t2>0)ObjectMove(m_chart_id,name,1,t2,p2);ObjectSetInteger(m_chart_id,name,OBJPROP_TIMEFRAMES,frames);ObjectSetInteger(m_chart_id,name,OBJPROP_HIDDEN,false);return(ObjectFind(m_chart_id,name)>=0);
     }
   void Label(const string name,const long frames,const datetime time,const double price,const string text,const color shade)
     {
      if(!Create(name,OBJ_TEXT,frames,time,price))return;
      ObjectSetString(m_chart_id,name,OBJPROP_TEXT,text);ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,shade);ObjectSetInteger(m_chart_id,name,OBJPROP_FONTSIZE,8);ObjectSetInteger(m_chart_id,name,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
     }
   void Marker(const string name,const long frames,const datetime time,const double price,const bool up,const color shade)
     {
      if(!Create(name,up ? OBJ_ARROW_BUY : OBJ_ARROW_SELL,frames,time,price))return;
      ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,shade);ObjectSetInteger(m_chart_id,name,OBJPROP_WIDTH,2);
     }
   void Refresh(void) const { ChartRedraw(m_chart_id); }
   void DrawAuditInstruction(void)
     {
      if(!m_active)return;
      const string name=Id("AUDIT_VIEW_INSTRUCTION");
      if(ObjectFind(m_chart_id,name)<0)ObjectCreate(m_chart_id,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(m_chart_id,name,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);ObjectSetInteger(m_chart_id,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(m_chart_id,name,OBJPROP_XDISTANCE,12);ObjectSetInteger(m_chart_id,name,OBJPROP_YDISTANCE,44);ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,clrLightSteelBlue);ObjectSetInteger(m_chart_id,name,OBJPROP_FONTSIZE,8);ObjectSetInteger(m_chart_id,name,OBJPROP_HIDDEN,false);ObjectSetString(m_chart_id,name,OBJPROP_TEXT,"Audit views: use MT5 timeframe selector on this chart - H4=WHY | H1=WHERE | M15=WHEN");
     }
   int FindZone(const int zone_id) const { for(int i=0;i<ArraySize(m_latest_zones);i++)if(m_latest_zones[i].id==zone_id)return(i);return(-1); }
   string ConfirmationText(const E2ReportEntryData &entry) const
     {
      string text="";
      if(entry.confirmation_engulfing!="NO")text="ENG";
      if(entry.confirmation_pin!="NO")text+=(text=="" ? "PIN" : "+PIN");
      if(entry.confirmation_momentum!="NO")text+=(text=="" ? "MOM" : "+MOM");
      if(entry.confirmation_previous_break!="NO")text+=(text=="" ? "PREV" : "+PREV");
      return(text=="" ? "CONF" : text);
     }
   void DrawPanel(const E2ReportEntryData &entry,const ulong position_id,const string result="",const double realized_r=0.0)
     {
      const string name=Id(Key(position_id)+"_PANEL");
      if(ObjectFind(m_chart_id,name)<0)ObjectCreate(m_chart_id,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(m_chart_id,name,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);ObjectSetInteger(m_chart_id,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(m_chart_id,name,OBJPROP_XDISTANCE,12);ObjectSetInteger(m_chart_id,name,OBJPROP_YDISTANCE,20);ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,clrWhite);ObjectSetInteger(m_chart_id,name,OBJPROP_FONTSIZE,9);ObjectSetInteger(m_chart_id,name,OBJPROP_HIDDEN,false);
      string text="E2-"+StringFormat("%I64u",position_id)+" "+entry.direction+"\nH4 "+entry.trend+"  ADX "+DoubleToString(entry.adx,2)+" / "+DoubleToString(m_config.adx_minimum_threshold,2)+"\nH1 Z"+IntegerToString(entry.zone_id)+" "+entry.zone_role+"  V"+IntegerToString(entry.zone_visit)+"\nM15 "+ConfirmationText(entry)+"\nFill "+DoubleToString(entry.fill_price,_Digits)+"  SL "+DoubleToString(entry.stop_loss,_Digits)+"  TP "+DoubleToString(entry.take_profit,_Digits);
      if(result!="")text+="\n"+result+" "+DoubleToString(realized_r,2)+"R";
      ObjectSetString(m_chart_id,name,OBJPROP_TEXT,text);
     }
   void DrawTradeZone(const E2ReportEntryData &entry,const ulong position_id,const datetime end_time)
     {
      const int index=FindZone(entry.zone_id);if(index<0)return;const E2Zone zone=m_latest_zones[index];const string key=Id(Key(position_id)+"_ZONE");const datetime start=(zone.state==E2_ZONE_ROLE_REVERSED_ACTIVE && zone.reversal_time>0 ? zone.reversal_time : (zone.activation_time>0 ? zone.activation_time : zone.known_from_time));
      if(!Create(key,OBJ_RECTANGLE,H1(),start,zone.lower,end_time,zone.upper))return;
      ObjectSetInteger(m_chart_id,key,OBJPROP_COLOR,(zone.type==E2_ZONE_SUPPORT ? clrLimeGreen : clrRed));ObjectSetInteger(m_chart_id,key,OBJPROP_FILL,true);ObjectSetInteger(m_chart_id,key,OBJPROP_BACK,true);ObjectSetInteger(m_chart_id,key,OBJPROP_WIDTH,2);
      Label(Id(Key(position_id)+"_ZONE_LABEL"),H1(),start,zone.upper,"Z"+IntegerToString(zone.id)+" "+E2ZoneTypeName(zone.type)+"\n"+IntegerToString(zone.touches)+" touches",clrWhite);
     }
   void DrawTradeContext(const E2ReportEntryData &entry,const ulong position_id,const datetime end_time,const string result="",const double realized_r=0.0)
     {
      if(!m_config.visual_show_trades)return;const string key=Key(position_id);const bool up=(entry.direction=="LONG");
      DrawTradeZone(entry,position_id,end_time);
      if(m_config.visual_show_confirmations){Marker(Id(key+"_CONFIRM"),M15(),entry.confirmation_time,entry.fill_price,up,(up ? clrLimeGreen : clrRed));Label(Id(key+"_CONFIRM_LABEL"),M15(),entry.confirmation_time,entry.fill_price,"E2-"+StringFormat("%I64u",position_id)+"\n"+ConfirmationText(entry),clrWhite);}
      // A compact E2 context marker complements rather than duplicates MT5 deal arrows.
      Label(Id(key+"_ENTRY"),TradeFrames(),entry.entry_time,entry.fill_price,"E2-"+StringFormat("%I64u",position_id)+" "+entry.direction,clrDodgerBlue);
      if(Create(Id(key+"_SL"),OBJ_TREND,TradeFrames(),entry.entry_time,entry.stop_loss,end_time,entry.stop_loss)){ObjectSetInteger(m_chart_id,Id(key+"_SL"),OBJPROP_COLOR,clrRed);ObjectSetInteger(m_chart_id,Id(key+"_SL"),OBJPROP_WIDTH,2);ObjectSetInteger(m_chart_id,Id(key+"_SL"),OBJPROP_RAY_RIGHT,false);}
      if(Create(Id(key+"_TP"),OBJ_TREND,TradeFrames(),entry.entry_time,entry.take_profit,end_time,entry.take_profit)){ObjectSetInteger(m_chart_id,Id(key+"_TP"),OBJPROP_COLOR,clrLimeGreen);ObjectSetInteger(m_chart_id,Id(key+"_TP"),OBJPROP_WIDTH,2);ObjectSetInteger(m_chart_id,Id(key+"_TP"),OBJPROP_RAY_RIGHT,false);}
      if(result!="")Label(Id(key+"_RESULT"),TradeFrames(),end_time,(result=="TP" ? entry.take_profit : entry.stop_loss),result+" "+DoubleToString(realized_r,2)+"R",clrGold);
      DrawPanel(entry,position_id,result,realized_r);
     }
   void RemoveEntryProvisionalObjects(const ulong entry_deal)
     {
      const string key=Id(Key(entry_deal));
      const string suffix[]={"_PANEL","_ZONE","_ZONE_LABEL","_CONFIRM","_CONFIRM_LABEL","_ENTRY","_SL","_TP","_RESULT"};
      for(int i=0;i<ArraySize(suffix);i++)ObjectDelete(m_chart_id,key+suffix[i]);
     }
public:
   E2Visualizer(void):m_logger(NULL),m_active(false),m_has_trend(false),m_focus_missing_reported(false),m_chart_id(0),m_last_trend(E2_TREND_UNKNOWN) {}
   void Initialize(const E2Config &config,E2Logger &logger)
     {
      m_config=config;m_logger=&logger;m_chart_id=ChartID();m_active=(m_config.visual_mode_enabled && MQLInfoInteger(MQL_TESTER)!=0 && m_chart_id>=0);m_has_trend=false;m_focus_missing_reported=false;ArrayResize(m_latest_zones,0);ArrayResize(m_entries,0);
      if(m_logger!=NULL)m_logger.Debug("auditMode="+IntegerToString((int)m_config.visual_audit_mode)+", focusTradeId="+StringFormat("%I64u",m_config.visual_focus_trade_id)+", chartId="+StringFormat("%I64d",m_chart_id)+", H4/H1/M15 visibility enabled. Native MT5 timeframe selector is the audit switching mechanism.","Visualization");
      DrawAuditInstruction();
     }
   void UpdateZones(const E2Zone &zones[],const datetime evaluation)
     {
      if(!m_active)return;ArrayResize(m_latest_zones,ArraySize(zones));for(int i=0;i<ArraySize(zones);i++)m_latest_zones[i]=zones[i];
      if(!IsStrategyAudit() || !m_config.visual_show_zones)return;
      for(int i=0;i<ArraySize(zones);i++)
        {
         if(!zones[i].actionable)continue;const string key=Id("AUDIT_ZONE_"+IntegerToString(zones[i].id)+"_"+IntegerToString((int)zones[i].known_from_time));const datetime start=(zones[i].state==E2_ZONE_ROLE_REVERSED_ACTIVE && zones[i].reversal_time>0 ? zones[i].reversal_time : (zones[i].activation_time>0 ? zones[i].activation_time : zones[i].known_from_time));
         if(Create(key,OBJ_RECTANGLE,H1(),start,zones[i].lower,evaluation,zones[i].upper)){ObjectSetInteger(m_chart_id,key,OBJPROP_COLOR,(zones[i].type==E2_ZONE_SUPPORT ? clrSeaGreen : clrFireBrick));ObjectSetInteger(m_chart_id,key,OBJPROP_FILL,true);ObjectSetInteger(m_chart_id,key,OBJPROP_BACK,true);ObjectSetInteger(m_chart_id,key,OBJPROP_WIDTH,1);Label(Id("AUDIT_ZONE_LABEL_"+IntegerToString(zones[i].id)+"_"+IntegerToString((int)zones[i].known_from_time)),H1(),start,zones[i].upper,"Z"+IntegerToString(zones[i].id)+" "+E2ZoneTypeName(zones[i].type),clrSilver);}
        }
     }
   void UpdateTrend(const E2StrategyResult &result,const double threshold)
     {
      if(!m_active || !m_config.visual_show_trend_panel)return;
      if(IsSingleTrade())return;
      const string panel=Id("TREND_PANEL");if(ObjectFind(m_chart_id,panel)<0)ObjectCreate(m_chart_id,panel,OBJ_LABEL,0,0,0);ObjectSetInteger(m_chart_id,panel,OBJPROP_TIMEFRAMES,H4());ObjectSetInteger(m_chart_id,panel,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(m_chart_id,panel,OBJPROP_XDISTANCE,12);ObjectSetInteger(m_chart_id,panel,OBJPROP_YDISTANCE,20);ObjectSetInteger(m_chart_id,panel,OBJPROP_COLOR,clrYellow);ObjectSetInteger(m_chart_id,panel,OBJPROP_FONTSIZE,10);ObjectSetString(m_chart_id,panel,OBJPROP_TEXT,"E2 H4 "+E2TrendStateName(result.trend_state)+" | ADX "+DoubleToString(result.adx_value,2)+" / "+DoubleToString(threshold,2));
      if(!m_has_trend || result.trend_state!=m_last_trend){const string marker=Id("REGIME_"+IntegerToString((int)result.trend_closed_h4_time));if(Create(marker,OBJ_VLINE,H4(),result.trend_closed_h4_time,0.0)){ObjectSetInteger(m_chart_id,marker,OBJPROP_COLOR,clrDimGray);ObjectSetInteger(m_chart_id,marker,OBJPROP_STYLE,STYLE_DOT);}m_last_trend=result.trend_state;m_has_trend=true;}
     }
   void MarkCandidate(const E2StrategyResult &result,const MqlRates &candle,const string rejection="")
     {
      if(!m_active || !IsStrategyAudit())return;
      if(rejection!="" && !m_config.visual_show_rejected_candidates)return;
      if(rejection!="")Label(Id("REJECT_"+IntegerToString((int)result.confirmation_candle_time)+"_"+rejection),M15(),result.confirmation_candle_time,(result.signal==E2_SIGNAL_LONG ? candle.low : candle.high),"REJ "+rejection,clrOrange);
      else if(m_config.visual_show_confirmations)Marker(Id("AUDIT_CONFIRM_"+IntegerToString((int)result.confirmation_candle_time)),M15(),result.confirmation_candle_time,(result.signal==E2_SIGNAL_LONG ? candle.low : candle.high),result.signal==E2_SIGNAL_LONG,clrSilver);
     }
   void DrawEntry(const E2ReportEntryData &entry)
     {
      if(!m_active)return;int n=ArraySize(m_entries);ArrayResize(m_entries,n+1);m_entries[n]=entry;
      if(IsSingleTrade())return; // Position identity is authoritative at finalization.
      DrawTradeContext(entry,entry.entry_deal,TimeCurrent());Refresh();
     }
   void DrawFinal(const E2ReportedTrade &trade)
     {
      if(!m_active || !trade.finalized)return;
      if(IsSingleTrade() && !MatchesFocus(trade.position_id))return;
      const double net=trade.profit+trade.commission+trade.swap+trade.fee;const double r=(trade.entry.planned_risk>0.0 ? net/trade.entry.planned_risk : 0.0);
      RemoveEntryProvisionalObjects(trade.entry_deal);
      DrawTradeContext(trade.entry,trade.position_id,trade.exit_time,trade.exit_reason,r);Refresh();
     }
   void ReportFocusNotFound(void)
     {
      if(!m_active || !IsSingleTrade() || m_config.visual_focus_trade_id==0 || m_focus_missing_reported)return;
      m_focus_missing_reported=true;if(m_logger!=NULL)m_logger.Warning("SINGLE_TRADE focus id="+StringFormat("%I64u",m_config.visual_focus_trade_id)+" was not found in finalized reporter records; no unrelated trade context was drawn.","Visualization");
     }
   void Cleanup(void)
     {
      if(!m_active || !m_config.visual_cleanup_on_deinit)return;for(int i=ObjectsTotal(m_chart_id,0,-1)-1;i>=0;i--){string name=ObjectName(m_chart_id,i,0,-1);if(StringFind(name,"E2VIS_")==0)ObjectDelete(m_chart_id,name);}Refresh();
     }
  };

#endif // E2_VISUALIZATION_E2VISUALIZER_MQH
