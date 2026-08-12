#ifndef E2_STRATEGY_E2SETUPTRACKER_MQH
#define E2_STRATEGY_E2SETUPTRACKER_MQH
#include "..\\analysis\\E2ZoneAnalyzer.mqh"
enum E2SetupState { E2_SETUP_INACTIVE,E2_SETUP_ARMED,E2_SETUP_CONSUMED };
enum E2SetupEvent { E2_SETUP_EVENT_NONE,E2_SETUP_EVENT_ARMED,E2_SETUP_EVENT_CONSUMED,E2_SETUP_EVENT_RESET };
struct E2SetupRecord { string symbol; int zone_id; E2ZoneType role; E2SetupState state; datetime last_candle; int visit; };
struct E2SetupTransition { int zone_id; E2ZoneType role; E2SetupEvent event; datetime candle; int visit; };
string E2SetupEventName(E2SetupEvent event){return(event==E2_SETUP_EVENT_ARMED?"ARMED":(event==E2_SETUP_EVENT_CONSUMED?"CONSUMED":(event==E2_SETUP_EVENT_RESET?"RESET":"NONE")));}
class E2SetupTracker
 {private:E2SetupRecord m_records[];
 int Find(const string symbol,const int id,const E2ZoneType role)const{for(int i=0;i<ArraySize(m_records);i++)if(m_records[i].symbol==symbol&&m_records[i].zone_id==id&&m_records[i].role==role)return(i);return(-1);}
 void Event(E2SetupTransition &events[],const E2SetupRecord &record,const E2SetupEvent event,const datetime candle)const{int n=ArraySize(events);ArrayResize(events,n+1);events[n].zone_id=record.zone_id;events[n].role=record.role;events[n].event=event;events[n].candle=candle;events[n].visit=record.visit;}
 public:E2SetupTracker(void){ArrayResize(m_records,0);}
 void Reset(void){ArrayResize(m_records,0);}
 void Update(const string symbol,const MqlRates &candle,const E2Zone &zones[],E2SetupTransition &events[]){ArrayResize(events,0);for(int i=0;i<ArraySize(zones);i++){if(!zones[i].actionable)continue;int at=Find(symbol,zones[i].id,zones[i].type);if(at<0){at=ArraySize(m_records);ArrayResize(m_records,at+1);m_records[at].symbol=symbol;m_records[at].zone_id=zones[i].id;m_records[at].role=zones[i].type;m_records[at].state=E2_SETUP_INACTIVE;m_records[at].visit=0;}if(m_records[at].last_candle==candle.time)continue;m_records[at].last_candle=candle.time;bool overlaps=(candle.low<=zones[i].upper&&candle.high>=zones[i].lower);if(overlaps&&m_records[at].state==E2_SETUP_INACTIVE){m_records[at].state=E2_SETUP_ARMED;m_records[at].visit++;Event(events,m_records[at],E2_SETUP_EVENT_ARMED,candle.time);}else if(!overlaps&&m_records[at].state!=E2_SETUP_INACTIVE){m_records[at].state=E2_SETUP_INACTIVE;Event(events,m_records[at],E2_SETUP_EVENT_RESET,candle.time);}}}
 bool IsEligible(const string symbol,const int id,const E2ZoneType role)const{int at=Find(symbol,id,role);return(at>=0&&m_records[at].state==E2_SETUP_ARMED);}
 bool Consume(const string symbol,const int id,const E2ZoneType role,const datetime candle,E2SetupTransition &event){int at=Find(symbol,id,role);if(at<0||m_records[at].state!=E2_SETUP_ARMED)return(false);m_records[at].state=E2_SETUP_CONSUMED;event.zone_id=id;event.role=role;event.event=E2_SETUP_EVENT_CONSUMED;event.candle=candle;event.visit=m_records[at].visit;return(true);} };
#endif
