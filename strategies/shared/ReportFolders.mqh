#ifndef E2_REPORT_FOLDERS_MQH
#define E2_REPORT_FOLDERS_MQH
string E2PathPart(const string value) {
   // Encode punctuation (including underscores) so different broker symbols
   // cannot collapse to the same folder. Prefix avoids Windows device names.
   string out="v-";
   for(int i=0;i<StringLen(value);i++) {
      ushort c=StringGetCharacter(value,i);
      if((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='-')out+=StringSubstr(value,i,1);
      else out+="_"+StringFormat("%04X",(uint)c);
   }
   return out;
}
bool E2EnsureReportDirectory(const string folder) {
   ResetLastError();
   if(FolderCreate(folder,FILE_COMMON))return true;
   int error=GetLastError();
   // FileIsExist distinguishes an existing directory from a file blocking it.
   ResetLastError();FileIsExist(folder,FILE_COMMON);
   if(GetLastError()==ERR_FILE_IS_DIRECTORY)return true;
   Print("[E2] Report directory failed: ",folder," error=",error);return false;
}
bool E2ReportFolder(const string strategy,const string symbol,string &run,string &folder) {
   string mode=MQLInfoInteger(MQL_TESTER)?"Backtests":(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"Demo":"Live");
   string account=E2PathPart(AccountInfoString(ACCOUNT_SERVER))+"_"+StringFormat("%I64d",AccountInfoInteger(ACCOUNT_LOGIN));
   string parts[]={"E2","Reports",mode,account,strategy,E2PathPart(symbol)};
   folder="";
   for(int i=0;i<ArraySize(parts);i++) {
      if(i>0)folder+="\\";
      folder+=parts[i];
      if(!E2EnsureReportDirectory(folder))return false;
   }
   // Reserve a NEW run directory; parallel/repeated tests never reuse a ledger.
   string base=folder;
   for(int attempt=0;attempt<100;attempt++) {
      string id=run+(attempt==0?"":"_"+IntegerToString(attempt));
      string candidate=base+"\\"+id;
      ResetLastError();
      if(FolderCreate(candidate,FILE_COMMON)){run=id;folder=candidate;return true;}
      ResetLastError();FileIsExist(candidate,FILE_COMMON);
      if(GetLastError()!=ERR_FILE_IS_DIRECTORY){Print("[E2] Cannot reserve report run: ",candidate);return false;}
   }
   Print("[E2] Run directory namespace exhausted: ",base);return false;
}
string E2UniqueReportRun(const string run) {
   return run+"_"+StringFormat("%I64u",GetTickCount64())+"_"+StringFormat("%I64u",GetMicrosecondCount());
}
#endif
