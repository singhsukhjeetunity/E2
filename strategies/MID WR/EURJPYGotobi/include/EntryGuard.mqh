#ifndef RC_ENTRY_GUARD_MQH
#define RC_ENTRY_GUARD_MQH
#include "..\\..\\..\\shared\\ReportFolders.mqh"

// One writer across charts and MT5 terminals sharing Common Files. Never release
// an ambiguous entry just because a timeout, restart or midnight has occurred.
struct RCEntryState { int status; datetime event,day,submitted; ulong order; };
RCEntryState rc_entry_state;
string rc_entry_base="";
int rc_entry_lock=INVALID_HANDLE;
bool rc_entry_ready=false;
datetime rc_entry_last_check=0,rc_entry_last_warning=0;

void RCEWarn(const string message) {
   datetime now=TimeCurrent();
   if(rc_entry_last_warning==0||now-rc_entry_last_warning>=60) {
      Print(RC_NAME," [ENTRY_BLOCK] ",message);rc_entry_last_warning=now;
   }
}
uint RCEHash(const string value) {
   uint hash=2166136261;
   for(int i=0;i<StringLen(value);i++){hash^=(uint)StringGetCharacter(value,i);hash*=16777619;}
   return hash;
}
string RCEPayload(const RCEntryState &state) {
   return rc_entry_base+"|"+IntegerToString(state.status)+"|"+IntegerToString((long)state.event)+
      "|"+IntegerToString((long)state.day)+"|"+IntegerToString((long)state.submitted)+
      "|"+IntegerToString((long)state.order);
}
bool RCESave(const RCEntryState &next) {
   if(!rc_entry_ready)return false;
   if(MQLInfoInteger(MQL_TESTER)==0) {
      string payload=RCEPayload(next),temp=rc_entry_base+".tmp";
      int f=FileOpen(temp,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
      if(f==INVALID_HANDLE){RCEWarn("Cannot reserve entry on disk; no order sent");return false;}
      ResetLastError();
      uint written=FileWriteString(f,"GOTOBI_ENTRY_V1\r\n"+payload+"\r\n"+
         StringFormat("%08X",RCEHash(payload))+"\r\n");
      FileFlush(f);int error=GetLastError();FileClose(f);
      if(written==0||error!=0||!FileMove(temp,FILE_COMMON,rc_entry_base+".state",FILE_COMMON|FILE_REWRITE)) {
         RCEWarn("Entry state write failed; reservation remains blocked");return false;
      }
   }
   rc_entry_state=next;return true;
}
bool RCELoad() {
   if(!FileIsExist(rc_entry_base+".state",FILE_COMMON))return true;
   int f=FileOpen(rc_entry_base+".state",FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(f==INVALID_HANDLE)return false;
   string schema=FileReadString(f),payload=FileReadString(f),checksum=FileReadString(f);
   FileClose(f);StringReplace(schema,"\r","");StringReplace(payload,"\r","");StringReplace(checksum,"\r","");
   string fields[];
   if(schema!="GOTOBI_ENTRY_V1"||checksum!=StringFormat("%08X",RCEHash(payload))||
      StringSplit(payload,'|',fields)!=6||fields[0]!=rc_entry_base)return false;
   RCEntryState saved;
   saved.status=(int)StringToInteger(fields[1]);saved.event=(datetime)StringToInteger(fields[2]);
   saved.day=(datetime)StringToInteger(fields[3]);saved.submitted=(datetime)StringToInteger(fields[4]);
   saved.order=(ulong)StringToInteger(fields[5]);
   if(saved.status<0||saved.status>2)return false;
   if(saved.status>0&&(saved.event<=0||saved.day<=0||saved.submitted<=0))return false;
   rc_entry_state=saved;return true;
}
void RCEClose() {
   if(rc_entry_lock!=INVALID_HANDLE){FileClose(rc_entry_lock);rc_entry_lock=INVALID_HANDLE;}
   rc_entry_ready=false;
}
bool RCEInit() {
   ZeroMemory(rc_entry_state);rc_entry_last_check=0;rc_entry_last_warning=0;
   if(MQLInfoInteger(MQL_TESTER)!=0){rc_entry_ready=true;return true;}
   string folder;
   if(!E2ReportFolder("GotobiEntry",folder))return false;
   rc_entry_base=folder+"\\"+E2PathPart(AccountInfoString(ACCOUNT_SERVER))+"_"+
      IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+E2PathPart(_Symbol)+"_"+IntegerToString((long)InpMagic);
   rc_entry_lock=FileOpen(rc_entry_base+".lock",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(rc_entry_lock==INVALID_HANDLE) {
      Print(RC_NAME," [DUPLICATE_INSTANCE_OR_STORAGE] Entry lock unavailable for ",rc_entry_base,
         ". Check other charts/terminals using the same account, symbol and magic.");return false;
   }
   rc_entry_ready=RCELoad();
   if(!rc_entry_ready)RCEWarn("Unreadable/corrupt entry state; entries paused, existing exits remain active");
   return true;
}
bool RCEDefiniteNoFill(const uint code) {
   // Explicit broker refusals. Generic ERROR, TIMEOUT, CONNECTION, LOCKED,
   // PLACED and unknown codes are deliberately absent.
   return code==10004||code==10006||code==10007||
      (code>=10013&&code<=10022)||(code>=10024&&code<=10027)||
      code==10029||code==10030||(code>=10032&&code<=10046);
}
bool RCEReconcile(const bool force=false) {
   if(!rc_entry_ready)return false;
   if(rc_entry_state.status!=1)return true;
   datetime now=TimeCurrent();
   if(!force&&rc_entry_last_check>0&&now-rc_entry_last_check<1)return false;
   rc_entry_last_check=now;
   if(!HistorySelect(rc_entry_state.submitted,now+1))return false;
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong d=HistoryDealGetTicket(i);
      if(d==0||HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol||
         (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic)continue;
      long edge=HistoryDealGetInteger(d,DEAL_ENTRY),type=HistoryDealGetInteger(d,DEAL_TYPE);
      if((edge==DEAL_ENTRY_IN||edge==DEAL_ENTRY_INOUT)&&(type==DEAL_TYPE_BUY||type==DEAL_TYPE_SELL)&&
         HistoryDealGetInteger(d,DEAL_TIME)>=rc_entry_state.submitted&&
         (rc_entry_state.order==0||(ulong)HistoryDealGetInteger(d,DEAL_ORDER)==rc_entry_state.order)) {
         RCEntryState filled=rc_entry_state;filled.status=2;return RCESave(filled);
      }
   }
   // A terminal zero-fill order is evidence; simply seeing no deals is not.
   if(rc_entry_state.order>0&&HistoryOrderSelect(rc_entry_state.order)&&
      HistoryOrderGetString(rc_entry_state.order,ORDER_SYMBOL)==_Symbol&&
      (ulong)HistoryOrderGetInteger(rc_entry_state.order,ORDER_MAGIC)==InpMagic) {
      long state=HistoryOrderGetInteger(rc_entry_state.order,ORDER_STATE);
      double initial=HistoryOrderGetDouble(rc_entry_state.order,ORDER_VOLUME_INITIAL);
      double remaining=HistoryOrderGetDouble(rc_entry_state.order,ORDER_VOLUME_CURRENT);
      if((state==ORDER_STATE_CANCELED||state==ORDER_STATE_REJECTED||state==ORDER_STATE_EXPIRED)&&
         initial>0&&MathAbs(initial-remaining)<1e-8) {
         RCEntryState empty;ZeroMemory(empty);return RCESave(empty);
      }
   }
   RCEWarn("Unresolved order submission; awaiting broker fill or terminal zero-fill evidence");return false;
}
bool RCEReserve(const datetime utc,const datetime session_start,const datetime unique_since) {
   if(!rc_entry_ready||!RCEReconcile(true))return false;
   datetime event=unique_since>0?unique_since:(InpOneEntryPerDay?session_start:utc);
   if(rc_entry_state.status==2&&(rc_entry_state.event==event||
      (InpOneEntryPerDay&&rc_entry_state.day==session_start)))return false;
   if(RCHasOwn()||(unique_since>0&&RCEnteredSince(unique_since))||
      (InpOneEntryPerDay&&RCEnteredSince(session_start)))return false;
   for(int i=OrdersTotal()-1;i>=0;i--)if(OrderGetTicket(i)>0&&OrderGetString(ORDER_SYMBOL)==_Symbol&&
      (ulong)OrderGetInteger(ORDER_MAGIC)==InpMagic)return false;
   RCEntryState reserved;ZeroMemory(reserved);
   reserved.status=1;reserved.event=event;reserved.day=session_start;reserved.submitted=TimeCurrent();
   return RCESave(reserved); // Must be durable before Buy/Sell can execute.
}
void RCEResult(const bool sent,const uint code,const ulong order) {
   if(rc_entry_state.status!=1)return;
   if(order>0){RCEntryState known=rc_entry_state;known.order=order;RCESave(known);}
   if(!(sent&&(code==TRADE_RETCODE_DONE||code==TRADE_RETCODE_DONE_PARTIAL))&&RCEDefiniteNoFill(code)) {
      RCEntryState empty;ZeroMemory(empty);RCESave(empty);return;
   }
   RCEReconcile(true);
}
#endif
