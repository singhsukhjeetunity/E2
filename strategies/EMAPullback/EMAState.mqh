#ifndef EMA_STATE_MQH
#define EMA_STATE_MQH
struct NPRecord {
   string report_id,id,strategy,status,integrity,exit_reason;
   int slot;
   ulong order,position;
   datetime requested,entry,exit,deadline,last_close_attempt;
   bool closing;
   long entry_msc,exit_msc;
   double volume,fill,sl,tp,risk_cash,net,requested_distance,requested_risk;
};
struct NPCheckpoint {
   string scope,config;
   bool failed,active,pending;
   datetime last_exit;
   NPRecord record;
};
int NPWarmupMinutes(const int atr,const int fast,const int slow) {
   int longest=atr>slow?atr:slow;if(fast>longest)longest=fast;
   int bars=20*longest;if(bars<100)bars=100;
   return bars*30+1440; // 20 indicator periods plus one day of session coverage.
}
string NPEncode(const NPCheckpoint &c) {
   string p="EMA_STATE_V1";
   p+="\t"+c.scope;
   p+="\t"+c.config;
   p+="\t"+IntegerToString((long)c.failed);
   p+="\t"+IntegerToString((long)c.active);
   p+="\t"+IntegerToString((long)c.pending);
   p+="\t"+IntegerToString((long)c.last_exit);
   p+="\t"+c.record.report_id;
   p+="\t"+c.record.id;
   p+="\t"+c.record.strategy;
   p+="\t"+c.record.status;
   p+="\t"+c.record.integrity;
   p+="\t"+c.record.exit_reason;
   p+="\t"+IntegerToString((long)c.record.slot);
   p+="\t"+StringFormat("%I64u",c.record.order);
   p+="\t"+StringFormat("%I64u",c.record.position);
   p+="\t"+IntegerToString((long)c.record.requested);
   p+="\t"+IntegerToString((long)c.record.entry);
   p+="\t"+IntegerToString((long)c.record.exit);
   p+="\t"+IntegerToString((long)c.record.deadline);
   p+="\t"+IntegerToString((long)c.record.last_close_attempt);
   p+="\t"+IntegerToString((long)c.record.entry_msc);
   p+="\t"+IntegerToString((long)c.record.exit_msc);
   p+="\t"+DoubleToString(c.record.volume,16);
   p+="\t"+DoubleToString(c.record.fill,16);
   p+="\t"+DoubleToString(c.record.sl,16);
   p+="\t"+DoubleToString(c.record.tp,16);
   p+="\t"+DoubleToString(c.record.risk_cash,16);
   p+="\t"+DoubleToString(c.record.net,16);
   p+="\t"+DoubleToString(c.record.requested_distance,16);
   p+="\t"+DoubleToString(c.record.requested_risk,16);
   return p;
}
bool NPDecode(const string payload,NPCheckpoint &c) {
#ifdef __cplusplus
   std::vector<string> f;
#else
   string f[];
#endif
   if(StringSplit(payload,'\t',f)!=31 || f[0]!="EMA_STATE_V1")return false;
   c.scope=f[1];
   c.config=f[2];
   c.failed=(bool)StringToInteger(f[3]);
   c.active=(bool)StringToInteger(f[4]);
   c.pending=(bool)StringToInteger(f[5]);
   c.last_exit=(datetime)StringToInteger(f[6]);
   c.record.report_id=f[7];
   c.record.id=f[8];
   c.record.strategy=f[9];
   c.record.status=f[10];
   c.record.integrity=f[11];
   c.record.exit_reason=f[12];
   c.record.slot=(int)StringToInteger(f[13]);
   c.record.order=(ulong)StringToInteger(f[14]);
   c.record.position=(ulong)StringToInteger(f[15]);
   c.record.requested=(datetime)StringToInteger(f[16]);
   c.record.entry=(datetime)StringToInteger(f[17]);
   c.record.exit=(datetime)StringToInteger(f[18]);
   c.record.deadline=(datetime)StringToInteger(f[19]);
   c.record.last_close_attempt=(datetime)StringToInteger(f[20]);
   c.record.entry_msc=(long)StringToInteger(f[21]);
   c.record.exit_msc=(long)StringToInteger(f[22]);
   c.record.volume=StringToDouble(f[23]);
   c.record.fill=StringToDouble(f[24]);
   c.record.sl=StringToDouble(f[25]);
   c.record.tp=StringToDouble(f[26]);
   c.record.risk_cash=StringToDouble(f[27]);
   c.record.net=StringToDouble(f[28]);
   c.record.requested_distance=StringToDouble(f[29]);
   c.record.requested_risk=StringToDouble(f[30]);
   c.record.closing=false;
   if(c.last_exit<0 || (c.pending && !c.active))return false;
   if(c.active) {
      if(c.record.strategy!="NP_EMA_M30_LONG"||!MathIsValidNumber(c.record.net)||c.record.report_id==""||c.record.id==""||c.record.slot!=0||c.record.requested<=0||c.record.deadline<=0)return false;
      if(c.record.status!="UNCONFIRMED"&&c.record.status!="OPEN"&&c.record.status!="FINALIZED")return false;
      if(!MathIsValidNumber(c.record.requested_distance)||c.record.requested_distance<=0||
         !MathIsValidNumber(c.record.requested_risk)||c.record.requested_risk<=0)return false;
      if(!c.pending && (c.record.position==0||c.record.entry<=0||
         !MathIsValidNumber(c.record.risk_cash)||c.record.risk_cash<=0||
         !MathIsValidNumber(c.record.volume)||c.record.volume<=0||
         !MathIsValidNumber(c.record.fill)||c.record.fill<=0||
         !MathIsValidNumber(c.record.sl)||c.record.sl<=0||
         !MathIsValidNumber(c.record.tp)||c.record.tp<=0))return false;
   }
   return true;
}
#endif
