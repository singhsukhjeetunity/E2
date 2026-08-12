#ifndef E2_EXECUTION_E2POSITIONMANAGER_MQH
#define E2_EXECUTION_E2POSITIONMANAGER_MQH

#include "..\\core\\E2Config.mqh"
struct E2ManagedPosition { string symbol; E2TradeDirection direction; ulong ticket; ulong magic; double volume; double open_price; double stop_loss; double take_profit; datetime open_time; };
class E2PositionManager
  { private: ulong m_magic; E2Logger *m_logger; E2ManagedPosition m_positions[];
    int Find(const ulong ticket) const { for(int i=0;i<ArraySize(m_positions);i++) if(m_positions[i].ticket==ticket) return(i); return(-1); }
    E2ManagedPosition Read(void){E2ManagedPosition p;p.symbol=PositionGetString(POSITION_SYMBOL);p.direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?E2_DIRECTION_BUY:E2_DIRECTION_SELL);p.ticket=PositionGetInteger(POSITION_TICKET);p.magic=PositionGetInteger(POSITION_MAGIC);p.volume=PositionGetDouble(POSITION_VOLUME);p.open_price=PositionGetDouble(POSITION_PRICE_OPEN);p.stop_loss=PositionGetDouble(POSITION_SL);p.take_profit=PositionGetDouble(POSITION_TP);p.open_time=(datetime)PositionGetInteger(POSITION_TIME);return(p); }
    public: E2PositionManager(void):m_magic(0),m_logger(NULL){}
    void Initialize(const E2Config &c,E2Logger &l){m_magic=c.expert_magic_number;m_logger=&l;Refresh();}
    bool Refresh(){E2ManagedPosition next[];for(int i=0;i<PositionsTotal();i++){ulong t=PositionGetTicket(i);if(t>0&&(ulong)PositionGetInteger(POSITION_MAGIC)==m_magic){int n=ArraySize(next);ArrayResize(next,n+1);next[n]=Read();}}
      for(int i=0;i<ArraySize(m_positions);i++){bool present=false;for(int j=0;j<ArraySize(next);j++)if(next[j].ticket==m_positions[i].ticket){present=true;break;}if(!present&&m_logger!=NULL)m_logger.Debug("Position closed/disappeared: ticket="+StringFormat("%I64u",m_positions[i].ticket)+".","PositionManager");}
      for(int i=0;i<ArraySize(next);i++){int previous=Find(next[i].ticket);if(previous<0&&m_logger!=NULL)m_logger.Debug("Recovered position: symbol="+next[i].symbol+", ticket="+StringFormat("%I64u",next[i].ticket)+", volume="+DoubleToString(next[i].volume,4)+".","PositionManager");else if(previous>=0&&(next[i].volume!=m_positions[previous].volume||next[i].stop_loss!=m_positions[previous].stop_loss||next[i].take_profit!=m_positions[previous].take_profit)&&m_logger!=NULL)m_logger.Debug("Position modified: ticket="+StringFormat("%I64u",next[i].ticket)+".","PositionManager");}
      ArrayResize(m_positions,ArraySize(next));for(int i=0;i<ArraySize(next);i++)m_positions[i]=next[i];return(true);}
    int CountPositions() const{return(ArraySize(m_positions));} bool HasPosition(const string s) const{for(int i=0;i<ArraySize(m_positions);i++)if(m_positions[i].symbol==s)return(true);return(false);} bool GetPosition(const string s,E2ManagedPosition &p) const{for(int i=0;i<ArraySize(m_positions);i++)if(m_positions[i].symbol==s){p=m_positions[i];return(true);}return(false);} };
#endif
