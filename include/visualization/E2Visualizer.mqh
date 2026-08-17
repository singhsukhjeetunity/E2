#ifndef E2_VISUALIZATION_E2VISUALIZER_MQH
#define E2_VISUALIZATION_E2VISUALIZER_MQH

#include "..\\core\\E2Config.mqh"
#include "..\\reporting\\E2TradeReporter.mqh"
#include "..\\analysis\\E2H4RegimeEngine.mqh"
#include "..\\analysis\\E2H1ZoneEngine.mqh"

// Read-only visual audit. It consumes existing runtime metadata only.
class E2Visualizer
  {
private:
   E2Config m_config;
   E2Logger *m_logger;
   bool m_active,m_focus_missing_reported;
   long m_chart_id;
   bool m_h4rv2_has_state,m_h4rv2_last_eligible,m_h4rv2_last_overextended;
   E2RegimeType m_h4rv2_last_regime;
   datetime m_h4rv2_last_time;
   datetime m_h4rv2_active_h1,m_h4rv2_active_h2,m_h4rv2_active_l1,m_h4rv2_active_l2,m_h4rv2_active_break;
   E2H4BreakDirection m_h4rv2_active_break_direction;
   double m_h4rv2_last_ema20,m_h4rv2_last_ema50;
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
   void H4RegimeLabel(const string name,const datetime time,const double price,const string text,const color shade)
     { Label(Id("H4RV2_"+name),H4(),time,price,text,shade); }
   string H4Structure(const E2H4RegimeSwing &latest,const E2H4RegimeSwing &previous,const bool high) const
     { if(!latest.valid || !previous.valid)return("INVALID");if(latest.price==previous.price)return("EQ");if(high)return(latest.price>previous.price ? "HH" : "LH");return(latest.price>previous.price ? "HL" : "LL"); }
   string H4RegimeMarkerText(const E2RegimeType regime) const
     { if(regime==E2_REGIME_UPTREND)return("UP");if(regime==E2_REGIME_DOWNTREND)return("DOWN");if(regime==E2_REGIME_RANGE)return("RANGE");return("TRANS"); }
   void DeemphasizeH4RegimeSwing(const bool high,const datetime pivot_time)
     {
      if(pivot_time<=0)return;const string key=(high?"SWING_H_":"SWING_L_")+IntegerToString((int)pivot_time);const string marker=Id("H4RV2_"+key);
      ObjectDelete(m_chart_id,Id("H4RV2_"+key+"_LABEL"));ObjectDelete(m_chart_id,Id("H4RV2_"+key+"_KNOWN"));ObjectDelete(m_chart_id,Id("H4RV2_"+key+"_KNOWN_LABEL"));
      if(ObjectFind(m_chart_id,marker)>=0){ObjectSetInteger(m_chart_id,marker,OBJPROP_COLOR,clrDimGray);ObjectSetInteger(m_chart_id,marker,OBJPROP_WIDTH,1);}
     }
   void DeemphasizeH4RegimeBreak(void)
     {
      if(m_h4rv2_active_break<=0 || m_h4rv2_active_break_direction==E2_H4_BREAK_NONE)return;const string key="H4RV2_BREAK_"+(m_h4rv2_active_break_direction==E2_H4_BREAK_BULLISH?"B_":"S_")+IntegerToString((int)m_h4rv2_active_break);
      ObjectDelete(m_chart_id,Id(key+"_LABEL"));if(ObjectFind(m_chart_id,Id(key+"_MARK"))>=0)ObjectSetInteger(m_chart_id,Id(key+"_MARK"),OBJPROP_COLOR,clrDimGray);if(ObjectFind(m_chart_id,Id(key+"_LEVEL"))>=0){ObjectSetInteger(m_chart_id,Id(key+"_LEVEL"),OBJPROP_COLOR,clrDimGray);ObjectSetInteger(m_chart_id,Id(key+"_LEVEL"),OBJPROP_WIDTH,1);}
     }
   void DrawH4RegimePanel(const E2H4RegimeResult &r)
     {
      const string name=Id("H4RV2_PANEL");if(ObjectFind(m_chart_id,name)<0)ObjectCreate(m_chart_id,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(m_chart_id,name,OBJPROP_TIMEFRAMES,H4());ObjectSetInteger(m_chart_id,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(m_chart_id,name,OBJPROP_XDISTANCE,12);ObjectSetInteger(m_chart_id,name,OBJPROP_YDISTANCE,76);ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,clrLightSteelBlue);ObjectSetInteger(m_chart_id,name,OBJPROP_FONTSIZE,8);ObjectSetInteger(m_chart_id,name,OBJPROP_HIDDEN,false);
      const string highs=H4Structure(r.latest_swing_high,r.previous_swing_high,true),lows=H4Structure(r.latest_swing_low,r.previous_swing_low,false);const bool bull=(r.active_break_direction==E2_H4_BREAK_BULLISH),bear=(r.active_break_direction==E2_H4_BREAK_BEARISH);
      string text="E2 H4 REGIME V2\nREGIME: "+E2RegimeTypeName(r.regime)+"\nENTRY: "+(r.trend_overextended?"BLOCKED - OVEREXTENDED":(r.trend_entry_eligible?"ELIGIBLE":"N/A"))+"\nSTRUCTURE\nHighs: "+highs+" "+((highs=="HH"||highs=="LH")?"OK":"X")+"\nLows:  "+lows+" "+((lows=="HL"||lows=="LL")?"OK":"X")+"\nBreak: "+(bull?"BULL OK":(bear?"BEAR OK":"NONE"))+"\nTREND FILTERS\nEMA20 "+(r.ema20>r.ema50?">":"<=")+" EMA50\nEMA50 d5: "+DoubleToString(r.ema50-r.ema50_five_bars_ago,_Digits)+"\nADX: "+DoubleToString(r.adx,2)+" / 20\nExtension: "+DoubleToString(r.distance_close_to_ema20_atr,3)+" / 1.500 ATR\nATR: "+DoubleToString(r.atr,_Digits);
      if(r.range_valid)text+="\nR"+IntegerToString(r.active_range_id)+" U="+DoubleToString(r.range_upper_centre,_Digits)+" L="+DoubleToString(r.range_lower_centre,_Digits)+" H="+DoubleToString((r.range_upper_centre-r.range_lower_centre)/r.atr,2)+" ATR";ObjectSetString(m_chart_id,name,OBJPROP_TEXT,text);
     }
   void DrawH4RegimeSwing(const E2H4RegimeSwing &s,const string role)
     {
      if(!s.valid)return;const string key=(s.high?"SWING_H_":"SWING_L_")+IntegerToString((int)s.pivot_time);const color shade=(s.high?clrTomato:clrLimeGreen);
      Marker(Id("H4RV2_"+key),H4(),s.pivot_time,s.price,!s.high,shade);
      const string metadata="Type: "+(s.high?"Swing High":"Swing Low")+"\nPivot: "+TimeToString(s.pivot_time,TIME_DATE|TIME_MINUTES)+"\nKnown From: "+TimeToString(s.known_from_time,TIME_DATE|TIME_MINUTES)+"\nPrice: "+DoubleToString(s.price,_Digits);ObjectSetString(m_chart_id,Id("H4RV2_"+key),OBJPROP_TOOLTIP,metadata);ObjectSetInteger(m_chart_id,Id("H4RV2_"+key),OBJPROP_WIDTH,3);
      H4RegimeLabel(key+"_LABEL",s.pivot_time,s.price,role,shade);ObjectSetInteger(m_chart_id,Id("H4RV2_"+key+"_LABEL"),OBJPROP_FONTSIZE,9);ObjectSetString(m_chart_id,Id("H4RV2_"+key+"_LABEL"),OBJPROP_TOOLTIP,metadata);
      const string known=Id("H4RV2_"+key+"_KNOWN");if(Create(known,OBJ_VLINE,H4(),s.known_from_time,0.0)){ObjectSetInteger(m_chart_id,known,OBJPROP_COLOR,shade);ObjectSetInteger(m_chart_id,known,OBJPROP_STYLE,STYLE_DOT);}H4RegimeLabel(key+"_KNOWN_LABEL",s.known_from_time,s.price,"K",shade);ObjectSetString(m_chart_id,Id("H4RV2_"+key+"_KNOWN_LABEL"),OBJPROP_TOOLTIP,metadata);
     }
   void DrawH4RegimeBreak(const E2H4RegimeResult &r)
     {
      if(r.active_break_direction==E2_H4_BREAK_NONE || r.breakout_time<=0)return;const bool bull=(r.active_break_direction==E2_H4_BREAK_BULLISH);const string key="H4RV2_BREAK_"+(bull?"B_":"S_")+IntegerToString((int)r.breakout_time);const color shade=(bull?clrDodgerBlue:clrOrangeRed);
      if(Create(Id(key+"_LEVEL"),OBJ_TREND,H4(),r.breakout_time,r.broken_swing_price,r.closed_h4_time,r.broken_swing_price)){ObjectSetInteger(m_chart_id,Id(key+"_LEVEL"),OBJPROP_COLOR,shade);ObjectSetInteger(m_chart_id,Id(key+"_LEVEL"),OBJPROP_STYLE,STYLE_DASH);ObjectSetInteger(m_chart_id,Id(key+"_LEVEL"),OBJPROP_RAY_RIGHT,false);}
      Marker(Id(key+"_MARK"),H4(),r.breakout_time,r.breakout_close,bull,shade);ObjectSetInteger(m_chart_id,Id(key+"_MARK"),OBJPROP_WIDTH,3);H4RegimeLabel(key+"_LABEL",r.breakout_time,r.breakout_close,(bull?"BULL BREAK ":"BEAR BREAK ")+"+"+DoubleToString(r.breakout_distance_atr,2)+" ATR",shade);
     }
   void DrawH4RegimeRange(const E2H4RegimeResult &r)
     {
      if(r.range_confirmation_time<=0 || (r.range_upper_boundary<=r.range_lower_boundary))return;const datetime end=(r.range_invalidation_time>0?r.range_invalidation_time:r.closed_h4_time);const string key="H4RV2_RANGE_"+IntegerToString((int)r.range_confirmation_time);
      const double levels[]={r.range_upper_boundary,r.range_lower_boundary,r.range_upper_centre,r.range_lower_centre};const string names[]={"UPPER","LOWER","UC","LC"};
      for(int i=0;i<ArraySize(levels);i++)if(Create(Id(key+"_"+names[i]),OBJ_TREND,H4(),r.range_confirmation_time,levels[i],end,levels[i])){ObjectSetInteger(m_chart_id,Id(key+"_"+names[i]),OBJPROP_COLOR,(i<2?clrMediumPurple:clrSlateGray));ObjectSetInteger(m_chart_id,Id(key+"_"+names[i]),OBJPROP_STYLE,(i<2?STYLE_SOLID:STYLE_DOT));ObjectSetInteger(m_chart_id,Id(key+"_"+names[i]),OBJPROP_RAY_RIGHT,false);}
      if(r.range_valid)H4RegimeLabel(key+"_LABEL",r.range_confirmation_time,r.range_upper_boundary,"R"+IntegerToString(r.active_range_id),clrMediumPurple);
     }
   void DrawH4RegimeEma(const E2H4RegimeResult &r)
     {
      if(m_h4rv2_last_time<=0)return;const string suffix=IntegerToString((int)r.closed_h4_time);
      if(Create(Id("H4RV2_EMA20_"+suffix),OBJ_TREND,H4(),m_h4rv2_last_time,m_h4rv2_last_ema20,r.closed_h4_time,r.ema20)){ObjectSetInteger(m_chart_id,Id("H4RV2_EMA20_"+suffix),OBJPROP_COLOR,clrGold);ObjectSetInteger(m_chart_id,Id("H4RV2_EMA20_"+suffix),OBJPROP_RAY_RIGHT,false);}
      if(Create(Id("H4RV2_EMA50_"+suffix),OBJ_TREND,H4(),m_h4rv2_last_time,m_h4rv2_last_ema50,r.closed_h4_time,r.ema50)){ObjectSetInteger(m_chart_id,Id("H4RV2_EMA50_"+suffix),OBJPROP_COLOR,clrDeepSkyBlue);ObjectSetInteger(m_chart_id,Id("H4RV2_EMA50_"+suffix),OBJPROP_RAY_RIGHT,false);}
     }
   void DrawPanel(const E2ReportEntryData &entry,const ulong position_id,const string result="",const double realized_r=0.0)
     {
      const string name=Id(Key(position_id)+"_PANEL");
      if(ObjectFind(m_chart_id,name)<0)ObjectCreate(m_chart_id,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(m_chart_id,name,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);ObjectSetInteger(m_chart_id,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(m_chart_id,name,OBJPROP_XDISTANCE,12);ObjectSetInteger(m_chart_id,name,OBJPROP_YDISTANCE,20);ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,clrWhite);ObjectSetInteger(m_chart_id,name,OBJPROP_FONTSIZE,9);ObjectSetInteger(m_chart_id,name,OBJPROP_HIDDEN,false);
      string text="E2-"+StringFormat("%I64u",position_id)+" "+entry.strategy_type+" "+entry.direction+"\nPlan "+entry.plan_id+"\nH1 "+entry.zone_id+" "+entry.zone_role+" V"+IntegerToString(entry.zone_visit)+"\nManagement "+entry.management_branch+"\nFill "+DoubleToString(entry.fill_price,_Digits)+"  SL "+DoubleToString(entry.stop_loss,_Digits)+"  TP "+DoubleToString(entry.take_profit,_Digits);
      if(result!="")text+="\n"+result+" "+DoubleToString(realized_r,2)+"R";
      ObjectSetString(m_chart_id,name,OBJPROP_TEXT,text);
     }
   void DrawTradeContext(const E2ReportEntryData &entry,const ulong position_id,const datetime end_time,const string result="",const double realized_r=0.0)
     {
      if(!m_config.visual_show_trades)return;const string key=Key(position_id);const bool up=(entry.direction=="LONG");
      if(m_config.visual_show_confirmations){Marker(Id(key+"_CONFIRM"),M15(),entry.confirmation_time,entry.fill_price,up,(up ? clrLimeGreen : clrRed));Label(Id(key+"_CONFIRM_LABEL"),M15(),entry.confirmation_time,entry.fill_price,"E2-"+StringFormat("%I64u",position_id)+"\nTCV2",clrWhite);}
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
   E2Visualizer(void):m_logger(NULL),m_active(false),m_focus_missing_reported(false),m_chart_id(0),m_h4rv2_has_state(false),m_h4rv2_last_eligible(false),m_h4rv2_last_overextended(false),m_h4rv2_last_regime(E2_REGIME_UNKNOWN),m_h4rv2_last_time(0),m_h4rv2_active_h1(0),m_h4rv2_active_h2(0),m_h4rv2_active_l1(0),m_h4rv2_active_l2(0),m_h4rv2_active_break(0),m_h4rv2_active_break_direction(E2_H4_BREAK_NONE),m_h4rv2_last_ema20(0.0),m_h4rv2_last_ema50(0.0) {}
   void Initialize(const E2Config &config,E2Logger &logger)
     {
      m_config=config;m_logger=&logger;m_chart_id=ChartID();m_active=(m_config.visual_mode_enabled && MQLInfoInteger(MQL_TESTER)!=0 && m_chart_id>=0);m_focus_missing_reported=false;ArrayResize(m_entries,0);
      m_h4rv2_has_state=false;m_h4rv2_last_time=0;m_h4rv2_active_h1=0;m_h4rv2_active_h2=0;m_h4rv2_active_l1=0;m_h4rv2_active_l2=0;m_h4rv2_active_break=0;m_h4rv2_active_break_direction=E2_H4_BREAK_NONE;m_h4rv2_last_ema20=0.0;m_h4rv2_last_ema50=0.0;
      if(m_logger!=NULL)m_logger.Debug("auditMode="+IntegerToString((int)m_config.visual_audit_mode)+", focusTradeId="+StringFormat("%I64u",m_config.visual_focus_trade_id)+", chartId="+StringFormat("%I64d",m_chart_id)+", H4/H1/M15 visibility enabled. Native MT5 timeframe selector is the audit switching mechanism.","Visualization");
      DrawAuditInstruction();
     }
   void UpdateH4RegimeV2(const E2H4RegimeResult &r)
     {
      if(!m_active || !m_config.visual_show_h4_regime_v2 || Period()!=PERIOD_H4 || !r.ready)return;
      DeemphasizeH4RegimeSwing(true,m_h4rv2_active_h1);DeemphasizeH4RegimeSwing(true,m_h4rv2_active_h2);DeemphasizeH4RegimeSwing(false,m_h4rv2_active_l1);DeemphasizeH4RegimeSwing(false,m_h4rv2_active_l2);if(r.active_break_direction!=m_h4rv2_active_break_direction || r.breakout_time!=m_h4rv2_active_break)DeemphasizeH4RegimeBreak();
      DrawH4RegimePanel(r);DrawH4RegimeSwing(r.latest_swing_high,"H1");DrawH4RegimeSwing(r.previous_swing_high,"H2");DrawH4RegimeSwing(r.latest_swing_low,"L1");DrawH4RegimeSwing(r.previous_swing_low,"L2");DrawH4RegimeBreak(r);DrawH4RegimeRange(r);DrawH4RegimeEma(r);
      if(!m_h4rv2_has_state || r.regime!=m_h4rv2_last_regime || r.trend_entry_eligible!=m_h4rv2_last_eligible || r.trend_overextended!=m_h4rv2_last_overextended){const string key="H4RV2_REGIME_"+IntegerToString((int)r.closed_h4_time);if(Create(Id(key),OBJ_VLINE,H4(),r.closed_h4_time,0.0)){ObjectSetInteger(m_chart_id,Id(key),OBJPROP_COLOR,clrDarkSlateGray);ObjectSetInteger(m_chart_id,Id(key),OBJPROP_STYLE,STYLE_DOT);}const string marker=(!m_h4rv2_has_state || r.regime!=m_h4rv2_last_regime ? H4RegimeMarkerText(r.regime) : (r.trend_overextended?"EXT":"ELIG"));H4RegimeLabel(key+"_LABEL",r.closed_h4_time,r.latest_close,marker,clrSilver);}
     m_h4rv2_has_state=true;m_h4rv2_last_regime=r.regime;m_h4rv2_last_eligible=r.trend_entry_eligible;m_h4rv2_last_overextended=r.trend_overextended;m_h4rv2_last_time=r.closed_h4_time;m_h4rv2_last_ema20=r.ema20;m_h4rv2_last_ema50=r.ema50;m_h4rv2_active_h1=r.latest_swing_high.pivot_time;m_h4rv2_active_h2=r.previous_swing_high.pivot_time;m_h4rv2_active_l1=r.latest_swing_low.pivot_time;m_h4rv2_active_l2=r.previous_swing_low.pivot_time;m_h4rv2_active_break=r.breakout_time;m_h4rv2_active_break_direction=r.active_break_direction;Refresh();
     }
   void UpdateH1ZoneV2(const E2H1ZoneV2Record &zones[],const datetime evaluation)
     {
      if(!m_active || !m_config.visual_show_h1_zone_v2 || Period()!=PERIOD_H1)return;
      for(int i=0;i<ArraySize(zones);i++)
        {
         const E2H1ZoneV2Record zone=zones[i];const string key=Id("H1ZV2_"+zone.zone_id);const datetime end=(zone.invalidation_time>0 ? zone.invalidation_time : evaluation);
         if(Create(key,OBJ_RECTANGLE,H1(),zone.creation_time,zone.lower,end,zone.upper))
           {ObjectSetInteger(m_chart_id,key,OBJPROP_COLOR,(zone.type==E2_H1_ZONE_V2_SUPPORT ? clrMediumSeaGreen : clrIndianRed));ObjectSetInteger(m_chart_id,key,OBJPROP_FILL,true);ObjectSetInteger(m_chart_id,key,OBJPROP_BACK,true);ObjectSetInteger(m_chart_id,key,OBJPROP_WIDTH,(zone.state==E2_H1_ZONE_V2_ACTIVE ? 2 : 1));ObjectSetString(m_chart_id,key,OBJPROP_TOOLTIP,"Zone: "+zone.zone_id+"\nType: "+E2H1ZoneV2TypeName(zone.type)+"\nCreated: "+TimeToString(zone.creation_time,TIME_DATE|TIME_MINUTES)+"\nP1: "+TimeToString(zone.source_pivot_1_time,TIME_DATE|TIME_MINUTES)+" known "+TimeToString(zone.source_pivot_1_known_from,TIME_DATE|TIME_MINUTES)+" departed "+TimeToString(zone.source_pivot_1_departure_confirmed_time,TIME_DATE|TIME_MINUTES)+"\nP2: "+TimeToString(zone.source_pivot_2_time,TIME_DATE|TIME_MINUTES)+" known "+TimeToString(zone.source_pivot_2_known_from,TIME_DATE|TIME_MINUTES)+" departed "+TimeToString(zone.source_pivot_2_departure_confirmed_time,TIME_DATE|TIME_MINUTES)+"\nState: "+E2H1ZoneV2StateName(zone.state));}
         Label(Id("H1ZV2_LABEL_"+zone.zone_id),H1(),zone.creation_time,zone.upper,"ZV2 "+E2H1ZoneV2TypeName(zone.type),zone.type==E2_H1_ZONE_V2_SUPPORT ? clrMediumSeaGreen : clrIndianRed);
         Marker(Id("H1ZV2_P1_"+zone.zone_id),H1(),zone.source_pivot_1_time,zone.source_pivot_1_price,zone.type==E2_H1_ZONE_V2_SUPPORT,clrSilver);Marker(Id("H1ZV2_P2_"+zone.zone_id),H1(),zone.source_pivot_2_time,zone.source_pivot_2_price,zone.type==E2_H1_ZONE_V2_SUPPORT,clrSilver);
         if(zone.invalidation_time>0)Marker(Id("H1ZV2_INVALID_"+zone.zone_id),H1(),zone.invalidation_time,zone.invalidation_close,zone.type==E2_H1_ZONE_V2_SUPPORT,clrOrange);
        }
      Refresh();
     }
   void UpdateM15ConfirmationV2(const E2M15ConfirmationResult &results[])
     {
      if(!m_active || !m_config.visual_show_m15_confirmation_v2 || Period()!=PERIOD_M15)return;
      for(int i=0;i<ArraySize(results);i++)
        {
         const E2M15ConfirmationResult result=results[i];if(!result.passed)continue;
         const bool bullish=(result.type==E2_RESEARCH_CONFIRMATION_BULLISH_MOMENTUM || result.type==E2_RESEARCH_CONFIRMATION_BULLISH_RANGE_REJECTION);const bool momentum=(result.type==E2_RESEARCH_CONFIRMATION_BULLISH_MOMENTUM || result.type==E2_RESEARCH_CONFIRMATION_BEARISH_MOMENTUM);const string compact=(momentum ? (bullish ? "MOM+" : "MOM-") : (bullish ? "REJ+" : "REJ-"));const string key=Id("M15CV2_"+result.zone_id+"_"+IntegerToString((int)result.candle_time)+"_"+IntegerToString((int)result.type));
         Marker(key,M15(),result.candle_time,(bullish ? result.low : result.high),bullish,(momentum ? clrDodgerBlue : clrMediumPurple));Label(key+"_LABEL",M15(),result.candle_time,(bullish ? result.low : result.high),compact,(momentum ? clrDodgerBlue : clrMediumPurple));
         const string tooltip="Type: "+E2ResearchConfirmationTypeName(result.type)+"\nCandle: "+TimeToString(result.candle_time,TIME_DATE|TIME_MINUTES)+"\nKnown From: "+TimeToString(result.known_from_time,TIME_DATE|TIME_MINUTES)+"\nZone: "+result.zone_id+" ["+DoubleToString(result.zone_lower,_Digits)+", "+DoubleToString(result.zone_upper,_Digits)+"]\nBody: "+DoubleToString(result.body,_Digits)+" Median: "+DoubleToString(result.median_body,_Digits)+" Mult: "+DoubleToString(result.body_multiplier,2)+"\nBody/Range: "+DoubleToString(result.body_range_ratio,2)+" CloseLoc: "+DoubleToString(result.close_location,2)+"\nPrev H/L: "+DoubleToString(result.previous_high,_Digits)+" / "+DoubleToString(result.previous_low,_Digits)+"\nWick Body/Range: "+DoubleToString(result.wick_body_ratio,2)+" / "+DoubleToString(result.wick_range_ratio,2)+"\nPass: direction="+(result.direction_pass?"yes":"no")+", body="+(result.body_multiplier_pass?"yes":"no")+", range="+(result.body_range_pass?"yes":"no")+", close="+(result.closing_location_pass?"yes":"no")+", prev="+(result.previous_break_pass?"yes":"no")+", zone="+(result.zone_edge_pass?"yes":"no")+", wick="+(result.wick_body_pass&&result.wick_range_pass?"yes":"no");
         ObjectSetString(m_chart_id,key,OBJPROP_TOOLTIP,tooltip);ObjectSetString(m_chart_id,key+"_LABEL",OBJPROP_TOOLTIP,tooltip);
        }
     }
   void UpdateTrendContinuationV2(const E2TrendContinuationCandidate &candidates[])
     {
      if(!m_active || !m_config.visual_show_trend_continuation_v2 || Period()!=PERIOD_M15)return;
      for(int i=0;i<ArraySize(candidates);i++){const E2TrendContinuationCandidate c=candidates[i];const bool up=(c.direction==E2_TC_LONG);const string key=Id("TCV2_"+c.candidate_id);Marker(key,M15(),c.candidate_time,(up?c.confirmation.low:c.confirmation.high),up,clrGold);Label(key+"_LABEL",M15(),c.candidate_time,(up?c.confirmation.low:c.confirmation.high),(up?"TC+":"TC-"),clrGold);ObjectSetString(m_chart_id,key,OBJPROP_TOOLTIP,"Candidate: "+c.candidate_id+"\nZone: "+c.source_zone_id+"\nBreakout: "+TimeToString(c.breakout_known_from_time,TIME_DATE|TIME_MINUTES)+"\nRetest: "+TimeToString(c.retest_time,TIME_DATE|TIME_MINUTES)+"\nConfirmation: "+TimeToString(c.candidate_known_from_time,TIME_DATE|TIME_MINUTES)+"\nAttempt: "+IntegerToString(c.attempt_number));}
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
