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
bool E2ReportFolder(const string strategy,string &folder) {
   folder="E2\\"+strategy;
   return E2EnsureReportDirectory("E2") && E2EnsureReportDirectory(folder);
}
string E2ReportBase(const string symbol,const string run) {
   string mode=MQLInfoInteger(MQL_TESTER)?"Test":(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO?"Demo":"Live");
   return "E2_"+E2PathPart(symbol)+"_"+mode+"_"+StringFormat("%I64d",AccountInfoInteger(ACCOUNT_LOGIN))+"_"+run;
}
string E2UniqueReportRun(const string run) {
   return run+"_"+StringFormat("%I64u",GetTickCount64())+"_"+StringFormat("%I64u",GetMicrosecondCount());
}
#endif
