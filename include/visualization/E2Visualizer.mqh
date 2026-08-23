#ifndef E2_VISUALIZATION_E2VISUALIZER_MQH
#define E2_VISUALIZATION_E2VISUALIZER_MQH
#include "..\\core\\E2Config.mqh"
#include "..\\reporting\\E2Logger.mqh"
class E2Visualizer
  {
private: E2Config m_config; E2Logger *m_logger; long m_chart; bool m_active;
public: E2Visualizer(void):m_logger(NULL),m_chart(0),m_active(false){}
   void Initialize(const E2Config &config,E2Logger &logger){m_config=config;m_logger=&logger;m_chart=ChartID();m_active=(config.visual_mode_enabled&&MQLInfoInteger(MQL_TESTER)!=0&&m_chart>=0);}
   void Cleanup(void){if(!m_active||!m_config.visual_cleanup_on_deinit)return;for(int i=ObjectsTotal(m_chart,0,-1)-1;i>=0;i--){string name=ObjectName(m_chart,i,0,-1);if(StringFind(name,"E2VIS_")==0)ObjectDelete(m_chart,name);}ChartRedraw(m_chart);}
  };
#endif
