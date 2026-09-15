#ifndef E2_ENTRY_LIFECYCLE_MQH
#define E2_ENTRY_LIFECYCLE_MQH

// Included after the EA globals. Only reconciliation is retried, never Buy/Sell.
E2PositionMetadata g_entry;
E2ExecutionResult g_entry_result;
bool g_entry_pending=false,g_entry_registered=false,g_entry_restarted=false;
datetime g_entry_requested=0;
double g_entry_requested_volume=0.0;
string g_entry_file,g_entry_comment;
ulong g_entry_retry_ms=0,g_entry_alert_ms=0;

void E2EntryAlert(const string reason)
  {
   ulong now=GetTickCount64();
   if(g_entry_alert_ms>0&&now-g_entry_alert_ms<30000)return;
   g_entry_alert_ms=now;
   // Protection errors must remain visible even with routine logging disabled.
   Print("[E2][ENTRY_PENDING] ",reason,"; new entries blocked; order=",g_entry_result.order_ticket);
  }

bool E2WriteEntryIntent()
  {
   // Local terminal storage separates accounts/servers and tester agents.
   string tmp=g_entry_file+".tmp";
   int h=FileOpen(tmp,FILE_WRITE|FILE_CSV|FILE_ANSI,';');
   if(h==INVALID_HANDLE)return(false);
   uint n=FileWrite(h,"E2_PENDING_V1",IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)),
      AccountInfoString(ACCOUNT_SERVER),StringFormat("%I64u",g_configuration.expert_magic_number),
      g_entry.symbol,g_entry.candidate_id,g_entry.execution_id,g_entry.time_policy_digest,g_entry_comment,
      IntegerToString((long)g_entry_requested),IntegerToString((long)g_entry.signal_time),
      DoubleToString(g_entry.submitted_stop,16),DoubleToString(g_entry.target_r,16),
      DoubleToString(g_entry.requested_risk_cash,16),DoubleToString(g_entry_requested_volume,16),
      IntegerToString(g_entry.rule_day),IntegerToString((long)g_entry.range_start_rule),IntegerToString((long)g_entry.range_end_rule),
      DoubleToString(g_entry.range_high,16),DoubleToString(g_entry.range_low,16),DoubleToString(g_entry.signal_close,16),
      DoubleToString(g_entry.extension_distance,16),StringFormat("%I64u",g_entry_result.order_ticket),"END");
   FileFlush(h);FileClose(h);
   return(n>0&&FileMove(tmp,0,g_entry_file,FILE_REWRITE));
  }

bool E2LoadEntryIntent()
  {
   string symbol=_Symbol;StringReplace(symbol,".","_");StringReplace(symbol,"#","_");
   g_entry_file="E2_PENDING_"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+
      StringFormat("%I64u",g_configuration.expert_magic_number)+"_"+symbol+".csv";
   if(!FileIsExist(g_entry_file))return(true);
   int h=FileOpen(g_entry_file,FILE_READ|FILE_CSV|FILE_ANSI,';');if(h==INVALID_HANDLE)return(false);
   string f[24];bool valid=true;
   for(int i=0;i<24;i++){if(FileIsEnding(h)){valid=false;break;}f[i]=FileReadString(h);}
   FileClose(h);
   if(!valid||f[0]!="E2_PENDING_V1"||f[23]!="END"||
      f[1]!=IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))||f[2]!=AccountInfoString(ACCOUNT_SERVER)||
      f[3]!=StringFormat("%I64u",g_configuration.expert_magic_number)||f[4]!=_Symbol||
      f[7]!=g_configuration.time_policy_digest||f[5]==""||f[6]==""||f[8]=="")return(false);
   ZeroMemory(g_entry);ZeroMemory(g_entry_result);
   g_entry.symbol=f[4];g_entry.candidate_id=f[5];g_entry.execution_id=f[6];g_entry.time_policy_digest=f[7];g_entry_comment=f[8];
   g_entry_requested=(datetime)StringToInteger(f[9]);g_entry.signal_time=(datetime)StringToInteger(f[10]);
   g_entry.submitted_stop=StringToDouble(f[11]);g_entry.target_r=StringToDouble(f[12]);
   g_entry.requested_risk_cash=StringToDouble(f[13]);g_entry_requested_volume=StringToDouble(f[14]);
   g_entry.rule_day=(int)StringToInteger(f[15]);g_entry.range_start_rule=(datetime)StringToInteger(f[16]);
   g_entry.range_end_rule=(datetime)StringToInteger(f[17]);g_entry.range_high=StringToDouble(f[18]);
   g_entry.range_low=StringToDouble(f[19]);g_entry.signal_close=StringToDouble(f[20]);g_entry.extension_distance=StringToDouble(f[21]);
   g_entry_result.order_ticket=(ulong)StringToInteger(f[22]);g_entry.direction=E2_DIRECTION_LONG;
   if(g_entry_requested<=0||g_entry.signal_time<=0||g_entry_requested<g_entry.signal_time||
      !MathIsValidNumber(g_entry.submitted_stop)||g_entry.submitted_stop<=0||
      !MathIsValidNumber(g_entry.target_r)||g_entry.target_r<=0||
      !MathIsValidNumber(g_entry.requested_risk_cash)||g_entry.requested_risk_cash<=0||
      !MathIsValidNumber(g_entry_requested_volume)||g_entry_requested_volume<=0)return(false);
   g_entry_pending=true;g_entry_restarted=true;
   Print("[E2][ENTRY_RECOVERY] Resuming durable entry intent; no order will be resent.");
   return(true);
  }

bool E2BeginEntry(const E2Candidate &c,const E2OrderRequest &r)
  {
   ZeroMemory(g_entry);ZeroMemory(g_entry_result);g_entry_registered=false;g_entry_restarted=false;
   g_entry_retry_ms=0;g_entry_alert_ms=0;
   g_entry.candidate_id=c.candidate_id;g_entry.execution_id=r.execution_id;g_entry.symbol=r.symbol;
   g_entry.direction=r.direction;g_entry.signal_time=r.signal_time;g_entry.submitted_stop=r.submitted_stop_price;
   g_entry.target_r=g_configuration.xau_target_r;g_entry.requested_risk_cash=r.requested_risk_cash;
   g_entry.rule_day=c.rule_day;g_entry.range_start_rule=c.range_start_rule;g_entry.range_end_rule=c.range_end_rule;
   g_entry.range_high=c.range_high;g_entry.range_low=c.range_low;g_entry.signal_close=c.signal_close;
   g_entry.extension_distance=c.extension_distance;g_entry.time_policy_digest=g_configuration.time_policy_digest;
   g_entry_requested=r.request_time;g_entry_requested_volume=r.volume;
   g_entry_comment="E2P"+IntegerToString((long)r.request_time)+"_"+StringFormat("%I64u",GetTickCount64()%100000000);
   if(!E2WriteEntryIntent()){E2EntryAlert("Cannot persist entry intent; order not sent");return(false);}
   g_entry_pending=true;return(true);
  }

void E2ClearEntryIntent()
  {
   if(FileIsExist(g_entry_file)&&!FileDelete(g_entry_file)){E2EntryAlert("Cannot clear reconciled intent");return;}
   g_entry_pending=false;
  }

void E2ReconcileEntry()
  {
   if(!g_entry_pending)return;
   ulong now=(MQLInfoInteger(MQL_TESTER)?(ulong)TimeCurrent()*1000:GetTickCount64());
   if(g_entry_retry_ms>0&&now-g_entry_retry_ms<1000)return;g_entry_retry_ms=now;
   if(!HistorySelect(g_entry_requested-60,TimeCurrent()+1)){E2EntryAlert("Waiting for deal history");return;}
   ulong order=g_entry_result.order_ticket,pid=0,first=0;
   double volume=0.0,weighted=0.0;datetime entry_time=0;
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong d=HistoryDealGetTicket(i);
      if(d==0||HistoryDealGetString(d,DEAL_SYMBOL)!=g_entry.symbol||
         (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=g_configuration.expert_magic_number||
         HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN||HistoryDealGetInteger(d,DEAL_TYPE)!=DEAL_TYPE_BUY||
         HistoryDealGetInteger(d,DEAL_TIME)<g_entry_requested)continue;
      ulong o=(ulong)HistoryDealGetInteger(d,DEAL_ORDER);
      if(order>0?o!=order:HistoryDealGetString(d,DEAL_COMMENT)!=g_entry_comment)continue;
      ulong position=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if(pid!=0&&position!=pid){E2EntryAlert("Ambiguous position evidence");return;}
      pid=position;order=o;double v=HistoryDealGetDouble(d,DEAL_VOLUME);
      volume+=v;weighted+=v*HistoryDealGetDouble(d,DEAL_PRICE);
      if(first==0||d<first){first=d;entry_time=(datetime)HistoryDealGetInteger(d,DEAL_TIME);}
     }
   if(first==0||volume<=0||pid==0){E2EntryAlert("Waiting for authoritative entry deal; order will not be resent");return;}
   // Wait until all partial fills of this immediate order are settled.
   if(OrderSelect(order)||!HistoryOrderSelect(order)){E2EntryAlert("Waiting for final order history");return;}
   long state=HistoryOrderGetInteger(order,ORDER_STATE);
   if(state!=ORDER_STATE_FILLED&&state!=ORDER_STATE_CANCELED&&state!=ORDER_STATE_REJECTED&&state!=ORDER_STATE_EXPIRED)
      {E2EntryAlert("Order is not terminal");return;}
   double expected=HistoryOrderGetDouble(order,ORDER_VOLUME_INITIAL)-HistoryOrderGetDouble(order,ORDER_VOLUME_CURRENT);
   if(MathAbs(volume-expected)>1e-8||volume>g_entry_requested_volume+1e-8){E2EntryAlert("Waiting for complete fill volume");return;}
   g_entry.entry_deal=first;g_entry.position_id=pid;g_entry.entry_time=entry_time;
   g_entry.volume=volume;g_entry.fill_price=weighted/volume;g_entry.original_r=g_entry.fill_price-g_entry.submitted_stop;
   if(g_entry.original_r<=0){E2EntryAlert("Invalid confirmed stop geometry");return;}
   g_entry.target_price=g_symbol_info.NormalizePrice(g_entry.fill_price+g_entry.original_r*g_entry.target_r);
   g_entry_result.order_ticket=order;g_entry_result.deal_ticket=first;
   bool open=false;
   for(int p=0;p<PositionsTotal();p++)
     {
      ulong t=PositionGetTicket(p);
      if(t==0||(ulong)PositionGetInteger(POSITION_IDENTIFIER)!=pid||PositionGetString(POSITION_SYMBOL)!=g_entry.symbol||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=g_configuration.expert_magic_number)continue;
      open=true;g_entry.position_ticket=t;
      double tol=SymbolInfoDouble(g_entry.symbol,SYMBOL_TRADE_TICK_SIZE)*0.5;
      if(MathAbs(PositionGetDouble(POSITION_VOLUME)-volume)>1e-8){E2EntryAlert("Position volume changed during confirmation");return;}
      if(MathAbs(PositionGetDouble(POSITION_SL)-g_entry.submitted_stop)>tol||
         MathAbs(PositionGetDouble(POSITION_TP)-g_entry.target_price)>tol)
        {
         uint rc=0;string desc;
         g_order_executor.AttachProtection(g_entry.symbol,pid,g_entry.submitted_stop,g_entry.target_price,rc,desc);
         if(!PositionSelectByTicket(t)||MathAbs(PositionGetDouble(POSITION_SL)-g_entry.submitted_stop)>tol||
            MathAbs(PositionGetDouble(POSITION_TP)-g_entry.target_price)>tol)
            {E2EntryAlert("Protection verification pending: "+IntegerToString((int)rc)+" "+desc);return;}
        }
      break;
     }
   if(!open)
     {
      // A fill may close before its confirmation callback. Require exit volume evidence.
      if(!HistorySelectByPosition(pid))return;double exits=0;
      for(int i=0;i<HistoryDealsTotal();i++){ulong d=HistoryDealGetTicket(i);long e=HistoryDealGetInteger(d,DEAL_ENTRY);if(e==DEAL_ENTRY_OUT||e==DEAL_ENTRY_OUT_BY)exits+=HistoryDealGetDouble(d,DEAL_VOLUME);}
      if(MathAbs(exits-volume)>1e-8){E2EntryAlert("Waiting for position or complete exit history");return;}
     }
   if(!g_position_sizer.CalculateActualRisk(g_entry.symbol,g_entry.direction,volume,g_entry.fill_price,g_entry.submitted_stop,g_entry.actual_risk_cash))
      {E2EntryAlert("Actual risk calculation unavailable");return;}
   if(!g_position_recovery.Save(g_entry)){E2EntryAlert("Recovery state persistence failed");return;}
   if(!g_entry_registered)
     {
      if(!g_trade_reporter.Register(g_entry,g_entry_restarted)){E2EntryAlert("Trade registration failed");return;}
      g_entry_registered=true;
      if(g_entry_restarted){g_recovered_positions_registered++;g_r_verify.recovered_positions_validated++;}
      else {g_new_positions_registered++;g_r_verify.new_positions_registered++;}
      g_position_sizer.RecordOriginalRiskCash(g_entry.actual_risk_cash);
      g_r_verify.targets_attached++;g_position_recovery.RecordLock();
      g_trade_reporter.RecordExecuted(g_entry.candidate_id,g_entry_result,g_entry);
      Print("[E2][ENTRY_CONFIRMED] position=",pid," fill=",g_entry.fill_price," SL=",g_entry.submitted_stop," TP=",g_entry.target_price);
     }
   E2ClearEntryIntent();
  }
#endif
