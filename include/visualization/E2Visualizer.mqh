#ifndef E2_VISUALIZATION_E2VISUALIZER_MQH
#define E2_VISUALIZATION_E2VISUALIZER_MQH
#include "..\\core\\E2Config.mqh"
#include "..\\reporting\\E2Logger.mqh"
#include "..\\strategy\\E2OBRTypes.mqh"
class E2Visualizer
  {
private: E2Config m_config; E2Logger *m_logger; long m_chart; bool m_active;
public: E2Visualizer(void):m_logger(NULL),m_chart(0),m_active(false){}
   void Initialize(const E2Config &config,E2Logger &logger){m_config=config;m_logger=&logger;m_chart=ChartID();m_active=(config.visual_mode_enabled&&MQLInfoInteger(MQL_TESTER)!=0&&m_chart>=0);}
   void UpdateOBR(const E2OBROpeningRange &range,const E2OBRCandidate &candidates[])
     {
      if(!m_active||Period()!=PERIOD_M15)return;
      if(range.frozen)
        {
         const string key="E2VIS_OBR_"+range.london_day;const datetime right=TimeCurrent();
         if(ObjectFind(m_chart,key+"_WINDOW")<0&&ObjectCreate(m_chart,key+"_WINDOW",OBJ_RECTANGLE,0,range.start_time,range.high,range.end_time,range.low)){ObjectSetInteger(m_chart,key+"_WINDOW",OBJPROP_COLOR,clrSlateGray);ObjectSetInteger(m_chart,key+"_WINDOW",OBJPROP_FILL,true);ObjectSetInteger(m_chart,key+"_WINDOW",OBJPROP_BACK,true);}
         if(ObjectFind(m_chart,key+"_HIGH")<0)ObjectCreate(m_chart,key+"_HIGH",OBJ_TREND,0,range.known_from,range.high,right,range.high);else ObjectSetInteger(m_chart,key+"_HIGH",OBJPROP_TIME,1,right);
         if(ObjectFind(m_chart,key+"_LOW")<0)ObjectCreate(m_chart,key+"_LOW",OBJ_TREND,0,range.known_from,range.low,right,range.low);else ObjectSetInteger(m_chart,key+"_LOW",OBJPROP_TIME,1,right);
         ObjectSetInteger(m_chart,key+"_HIGH",OBJPROP_COLOR,clrDodgerBlue);ObjectSetInteger(m_chart,key+"_HIGH",OBJPROP_RAY_RIGHT,true);ObjectSetInteger(m_chart,key+"_LOW",OBJPROP_COLOR,clrDodgerBlue);ObjectSetInteger(m_chart,key+"_LOW",OBJPROP_RAY_RIGHT,true);
        }
      for(int i=0;i<ArraySize(candidates);i++)
        {
         const E2OBRCandidate c=candidates[i];const string name="E2VIS_"+c.candidate_id;if(ObjectFind(m_chart,name)>=0)continue;const bool up=(c.direction==E2_DIRECTION_LONG);if(ObjectCreate(m_chart,name,OBJ_ARROW,0,c.breakout_candle_time,c.breakout_close)){ObjectSetInteger(m_chart,name,OBJPROP_ARROWCODE,up?233:234);ObjectSetInteger(m_chart,name,OBJPROP_COLOR,up?clrLimeGreen:clrTomato);ObjectSetString(m_chart,name,OBJPROP_TOOLTIP,c.candidate_id+"\nADX="+DoubleToString(c.adx,3)+" OR/ATR="+DoubleToString(c.or_size_atr_ratio,3)+" gap/ATR="+DoubleToString(c.breakout_distance_atr_ratio,3));}
        }
      ChartRedraw(m_chart);
     }
   void DrawOBRExecution(const E2OBRPositionMetadata &m)
     {
      if(!m_active||Period()!=PERIOD_M15||!m.valid)return;const string key="E2VIS_EXEC_"+m.execution_id;if(ObjectFind(m_chart,key+"_ENTRY")<0&&ObjectCreate(m_chart,key+"_ENTRY",OBJ_ARROW,0,m.entry_time,m.fill_price)){ObjectSetInteger(m_chart,key+"_ENTRY",OBJPROP_ARROWCODE,m.direction==E2_DIRECTION_LONG?233:234);ObjectSetInteger(m_chart,key+"_ENTRY",OBJPROP_COLOR,clrGold);}
      datetime right=m.entry_time+PeriodSeconds(PERIOD_M15)*8;if(ObjectFind(m_chart,key+"_SL")<0&&ObjectCreate(m_chart,key+"_SL",OBJ_TREND,0,m.entry_time,m.submitted_stop,right,m.submitted_stop)){ObjectSetInteger(m_chart,key+"_SL",OBJPROP_COLOR,clrRed);ObjectSetInteger(m_chart,key+"_SL",OBJPROP_RAY_RIGHT,true);}if(ObjectFind(m_chart,key+"_TP")<0&&ObjectCreate(m_chart,key+"_TP",OBJ_TREND,0,m.entry_time,m.target_price,right,m.target_price)){ObjectSetInteger(m_chart,key+"_TP",OBJPROP_COLOR,clrLimeGreen);ObjectSetInteger(m_chart,key+"_TP",OBJPROP_RAY_RIGHT,true);}ChartRedraw(m_chart);
     }
   void Cleanup(void){if(!m_active||!m_config.visual_cleanup_on_deinit)return;for(int i=ObjectsTotal(m_chart,0,-1)-1;i>=0;i--){string name=ObjectName(m_chart,i,0,-1);if(StringFind(name,"E2VIS_")==0)ObjectDelete(m_chart,name);}ChartRedraw(m_chart);}
  };
#endif
