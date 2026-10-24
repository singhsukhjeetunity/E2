#ifndef E2_SM_ENTRY_STATE
#define E2_SM_ENTRY_STATE
#include "..\\shared\\ReportFolders.mqh"
// One submission per NY day, durable BEFORE sending; uncertainty never expires.
struct SMState { int status,day; datetime submitted; ulong order; };
SMState sm_state;
string sm_state_base="";
int sm_lock=INVALID_HANDLE;
bool sm_state_ready=false;
datetime sm_reconcile_time=0;
uint SMHash(const string text) {
   uint h=2166136261;
   for(int i=0;i<StringLen(text);i++){h^=(uint)StringGetCharacter(text,i);h*=16777619;}
   return h;
}
string SMStatePayload(const SMState &s) {
   return sm_state_base+"|"+IntegerToString(s.status)+"|"+IntegerToString(s.day)+"|"+
      IntegerToString((long)s.submitted)+"|"+IntegerToString((long)s.order);
}
bool SMSaveState(const SMState &next) {
   if(!sm_state_ready)return false;
   if(MQLInfoInteger(MQL_TESTER)==0) {
      string payload=SMStatePayload(next),temp=sm_state_base+".tmp";
      int f=FileOpen(temp,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
      if(f==INVALID_HANDLE)return false;
      string text="E2_SM_ENTRY_V1\r\n"+payload+"\r\n"+StringFormat("%08X",SMHash(payload))+"\r\n";
      ResetLastError();uint written=FileWriteString(f,text);FileFlush(f);
      int error=GetLastError();FileClose(f);
      if(written!=StringLen(text)||error!=0||
         !FileMove(temp,FILE_COMMON,sm_state_base+".state",FILE_COMMON|FILE_REWRITE))return false;
   }
   sm_state=next;return true;
}
bool SMLoadState() {
   if(!FileIsExist(sm_state_base+".state",FILE_COMMON))return true;
   int f=FileOpen(sm_state_base+".state",FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(f==INVALID_HANDLE)return false;
   string schema=FileReadString(f),payload=FileReadString(f),checksum=FileReadString(f);
   FileClose(f);StringReplace(schema,"\r","");StringReplace(payload,"\r","");StringReplace(checksum,"\r","");
   string fields[];
   if(schema!="E2_SM_ENTRY_V1"||checksum!=StringFormat("%08X",SMHash(payload))||
      StringSplit(payload,'|',fields)!=5||fields[0]!=sm_state_base)return false;
   SMState next;ZeroMemory(next);
   next.status=(int)StringToInteger(fields[1]);next.day=(int)StringToInteger(fields[2]);
   next.submitted=(datetime)StringToInteger(fields[3]);next.order=(ulong)StringToInteger(fields[4]);
   if(next.status<0||next.status>2||(next.status>0&&(next.day<19700101||next.submitted<=0)))return false;
   sm_state=next;return true;
}
bool SMStateInit() {
   ZeroMemory(sm_state);sm_reconcile_time=0;
   if(MQLInfoInteger(MQL_TESTER)!=0){sm_state_ready=true;return true;}
   string folder;if(!E2ReportFolder("SessionMomentumEntry",folder))return false;
   sm_state_base=folder+"\\"+E2PathPart(AccountInfoString(ACCOUNT_SERVER))+"_"+
      IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+E2PathPart(_Symbol)+"_"+IntegerToString((long)InpMagic);
   sm_lock=FileOpen(sm_state_base+".lock",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(sm_lock==INVALID_HANDLE){Print("[SM] Duplicate instance or entry storage unavailable");return false;}
   sm_state_ready=SMLoadState();
   if(!sm_state_ready)Print("[SM] Corrupt/unreadable entry state: entries paused; exits remain active");
   return true;
}
void SMStateClose() {
   if(sm_lock!=INVALID_HANDLE){FileClose(sm_lock);sm_lock=INVALID_HANDLE;}
   sm_state_ready=false;
}
bool SMNoFill(const uint code) {
   return code==10004||code==10006||code==10007||(code>=10013&&code<=10022)||
      (code>=10024&&code<=10027)||code==10029||code==10030||(code>=10032&&code<=10046);
}
void SMReconcile(const bool force=false) {
   if(!sm_state_ready||sm_state.status!=1)return;
   datetime now=TimeCurrent();
   if(!force&&sm_reconcile_time>0&&now-sm_reconcile_time<1)return;
   sm_reconcile_time=now;
   if(!HistorySelect(sm_state.submitted,now+1))return;
   bool resolved=false;
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong d=HistoryDealGetTicket(i);long edge=HistoryDealGetInteger(d,DEAL_ENTRY);
      long side=HistoryDealGetInteger(d,DEAL_TYPE);
      if(d>0&&HistoryDealGetString(d,DEAL_SYMBOL)==_Symbol&&
         (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)==InpMagic&&
         HistoryDealGetInteger(d,DEAL_TIME)>=sm_state.submitted&&
         (edge==DEAL_ENTRY_IN||edge==DEAL_ENTRY_INOUT)&&(side==DEAL_TYPE_BUY||side==DEAL_TYPE_SELL)&&
         (sm_state.order==0||(ulong)HistoryDealGetInteger(d,DEAL_ORDER)==sm_state.order)){resolved=true;break;}
   }
   if(!resolved&&sm_state.order>0&&HistoryOrderSelect(sm_state.order)&&
      HistoryOrderGetString(sm_state.order,ORDER_SYMBOL)==_Symbol&&
      (ulong)HistoryOrderGetInteger(sm_state.order,ORDER_MAGIC)==InpMagic) {
      long status=HistoryOrderGetInteger(sm_state.order,ORDER_STATE);
      double initial=HistoryOrderGetDouble(sm_state.order,ORDER_VOLUME_INITIAL);
      resolved=(status==ORDER_STATE_CANCELED||status==ORDER_STATE_REJECTED||status==ORDER_STATE_EXPIRED)&&
         initial>0&&MathAbs(initial-HistoryOrderGetDouble(sm_state.order,ORDER_VOLUME_CURRENT))<1e-8;
   }
   if(resolved){SMState next=sm_state;next.status=2;SMSaveState(next);}
}
bool SMReserve(const int day) {
   SMReconcile(true);
   if(!sm_state_ready||sm_state.status==1||(sm_state.status==2&&sm_state.day>=day))return false;
   SMState next;ZeroMemory(next);next.status=1;next.day=day;next.submitted=TimeCurrent();
   return SMSaveState(next);
}
void SMResult(const uint code,const ulong order) {
   if(sm_state.status!=1)return;
   if(order>0){SMState next=sm_state;next.order=order;SMSaveState(next);}
   // Even a definite rejection consumes today's sole attempt; no retry storm.
   if(SMNoFill(code)){SMState next=sm_state;next.status=2;SMSaveState(next);}
   else SMReconcile(true);
}
#endif
