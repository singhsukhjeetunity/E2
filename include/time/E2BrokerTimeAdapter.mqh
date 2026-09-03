#ifndef E2_BROKER_TIME_ADAPTER_MQH
#define E2_BROKER_TIME_ADAPTER_MQH
#include "E2LondonTime.mqh"
#include "..\\reporting\\E2Logger.mqh"

class E2BrokerTimeAdapter
{
private:
   datetime m_from,m_until,m_at[];
   int m_offset[];
   bool m_ready;
   string m_id,m_server,m_mode,m_source,m_digest,m_error;
   E2Logger *m_logger;
   bool Integer(const string text,long &value)
   {
      int n=StringLen(text);if(n==0)return(false);
      for(int i=0;i<n;i++){ushort ch=StringGetCharacter(text,i);if(i==0&&ch==45&&n>1)continue;if(ch<48||ch>57)return(false);}
      value=StringToInteger(text);return(IntegerToString(value)==text);
   }
   bool Error(const string reason)
   {m_ready=false;if(m_error!=reason&&m_logger!=NULL)m_logger.Error(reason,"BROKER_TIME");m_error=reason;return(false);}
public:
   E2BrokerTimeAdapter(void):m_from(0),m_until(0),m_ready(false),m_logger(NULL){}
   string Digest()const{return(m_digest);}
   string Failure()const{return(m_error);}
   datetime CoverageStart()const{return(m_from);}
   datetime CoverageEnd()const{return(m_until);}
   bool Initialize(const string file,const string actual_server,const bool tester,E2Logger &logger)
   {
      m_logger=&logger;m_ready=false;m_error="";m_digest="";m_id="";m_server="";m_mode="";m_source="";
      ArrayResize(m_at,0);ArrayResize(m_offset,0);m_from=0;m_until=0;
      if(file=="")return(Error("PROFILE_REQUIRED: no broker policy inferred."));
      int h=FileOpen(file,FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
      if(h==INVALID_HANDLE)return(Error("PROFILE_OPEN_FAILED: "+file));
      int seen=0;long initial=0,test_only=0;bool bad=false;
      while(!FileIsEnding(h))
      {
         string line=FileReadString(h);StringTrimLeft(line);StringTrimRight(line);
         if(line==""||StringSubstr(line,0,1)=="#")continue;
         int eq=StringFind(line,"=");if(eq<1){bad=true;break;}
         string key=StringSubstr(line,0,eq),value=StringSubstr(line,eq+1);int bit=0;long number=0;
         if(key=="schema_version"){bit=1;if(value!="1")bad=true;}
         else if(key=="profile_id"){bit=2;m_id=value;}
         else if(key=="expected_server"){bit=4;m_server=value;}
         else if(key=="mode"){bit=8;m_mode=value;}
         else if(key=="valid_from_utc"){bit=16;if(!Integer(value,number))bad=true;m_from=(datetime)number;}
         else if(key=="valid_until_utc"){bit=32;if(!Integer(value,number))bad=true;m_until=(datetime)number;}
         else if(key=="initial_offset_seconds"){bit=64;if(!Integer(value,initial))bad=true;}
         else if(key=="source_reference"){bit=128;m_source=value;}
         else if(key=="test_only"){bit=256;if(!Integer(value,test_only)||(test_only!=0&&test_only!=1))bad=true;}
         else if(key=="transition")
         {
            string parts[];long instant=0,offset=0;
            if(StringSplit(value,',',parts)!=2||!Integer(parts[0],instant)||!Integer(parts[1],offset)||offset < -50400||offset>50400||offset%60!=0){bad=true;break;}
            int n=ArraySize(m_at);ArrayResize(m_at,n+1);ArrayResize(m_offset,n+1);m_at[n]=(datetime)instant;m_offset[n]=(int)offset;
         }
         else {bad=true;break;}
         if(bit>0){if((seen&bit)!=0)bad=true;seen|=bit;}
         if(bad)break;
      }
      FileClose(h);
      if(bad||seen!=511||m_id==""||m_source==""||m_server==""||m_server!=actual_server)return(Error("PROFILE_INVALID_OR_SERVER_MISMATCH"));
      if(test_only==1&&!tester)return(Error("TEST_ONLY_PROFILE_FORBIDDEN_IN_LIVE"));
      if(m_from<E2_LONDON_FROM||m_until>E2_LONDON_UNTIL||m_until<=m_from)return(Error("PROFILE_COVERAGE_INVALID_OR_OUTSIDE_PINNED_LONDON_DATA"));
      if(initial < -50400||initial>50400||initial%60!=0)return(Error("PROFILE_OFFSET_INVALID"));
      int n=ArraySize(m_at);
      if((m_mode!="FIXED_OFFSET"&&m_mode!="UTC_TRANSITIONS")||(m_mode=="FIXED_OFFSET"&&n!=0)||(m_mode=="UTC_TRANSITIONS"&&n==0))return(Error("PROFILE_MODE_TRANSITIONS_INCONSISTENT"));
      datetime previous=m_from;int previous_offset=(int)initial;
      string canonical="schema=1|"+m_id+"|"+m_server+"|"+m_mode+"|"+IntegerToString((long)m_from)+"|"+IntegerToString((long)m_until)+"|"+IntegerToString(initial)+"|test="+IntegerToString(test_only)+"|"+E2_LONDON_DATA_ID;
      for(int i=0;i<n;i++)
      {
         if(m_at[i]<=previous||m_at[i]>=m_until||m_offset[i]==previous_offset)return(Error("PROFILE_TRANSITIONS_UNORDERED_OR_INVALID"));
         previous=m_at[i];previous_offset=m_offset[i];canonical+="|"+IntegerToString((long)m_at[i])+","+IntegerToString(m_offset[i]);
      }
      // Prepend initial segment; all segments are UTC half-open intervals.
      ArrayResize(m_at,n+1);ArrayResize(m_offset,n+1);
      for(int i=n;i>0;i--){m_at[i]=m_at[i-1];m_offset[i]=m_offset[i-1];}
      m_at[0]=m_from;m_offset[0]=(int)initial;
      uchar bytes[],key[],hash[];int length=StringToCharArray(canonical,bytes,0,WHOLE_ARRAY,CP_UTF8);
      if(length>0)ArrayResize(bytes,length-1);
      if(CryptEncode(CRYPT_HASH_SHA256,bytes,key,hash)<=0)return(Error("PROFILE_DIGEST_FAILED"));
      for(int i=0;i<ArraySize(hash);i++)m_digest+=StringFormat("%02X",(uint)hash[i]);
      m_ready=true;
      logger.Info("profile="+m_id+", server="+m_server+", mode="+m_mode+", initialOffsetSeconds="+IntegerToString(initial)+", transitions="+IntegerToString(n)+", validFromUTC="+TimeToString(m_from,TIME_DATE|TIME_SECONDS)+", validUntilUTC="+TimeToString(m_until,TIME_DATE|TIME_SECONDS)+", testOnly="+IntegerToString(test_only)+", source="+m_source+", digest="+m_digest+", londonData="+E2_LONDON_DATA_ID+".","BROKER_TIME");
      return(true);
   }
   bool ServerToUtc(const datetime server,datetime &utc)const
   {
      utc=0;if(!m_ready)return(false);int matches=0;
      for(int i=0;i<ArraySize(m_at);i++)
      {
         datetime candidate=server-m_offset[i],end=(i+1<ArraySize(m_at)?m_at[i+1]:m_until);
         if(candidate>=m_at[i]&&candidate<end){utc=candidate;matches++;}
      }
      if(matches!=1){utc=0;return(false);}return(true);
   }
   bool UtcToServer(const datetime utc,datetime &server)const
   {
      server=0;if(!m_ready||utc<m_from||utc>=m_until)return(false);
      for(int i=ArraySize(m_at)-1;i>=0;i--)if(utc>=m_at[i]){server=utc+m_offset[i];return(true);}
      return(false);
   }
   bool London(const datetime server,datetime &local)const
   {datetime utc;local=0;return(ServerToUtc(server,utc)&&E2UtcToLondon(utc,local));}
   bool Day(const datetime server,int &day)const
   {datetime local;day=0;if(!London(server,local))return(false);day=E2CalendarDay(local);return(day>0);}
   bool ValidateNow(const datetime server)
   {datetime local;if(!London(server,local))return(Error("PROFILE_CURRENT_TIMESTAMP_UNCOVERED_OR_AMBIGUOUS"));return(true);}
};
#endif
