#ifndef E2_FILTERS_E2NEWSFILTER_MQH
#define E2_FILTERS_E2NEWSFILTER_MQH

#include "..\\core\\E2Config.mqh"
#include "..\\reporting\\E2Logger.mqh"

// FILE_COMMON dataset schema (comma-delimited, UTF-8/ANSI text):
// record_type,event_time_utc,currency,impact,event_name,coverage_start_utc,coverage_end_utc
// META,,,,,YYYY.MM.DD HH:MI,YYYY.MM.DD HH:MI
// EVENT,YYYY.MM.DD HH:MI,USD,HIGH,Event name,,
// Exactly one META row is required. EVENT timestamps must lie within its
// inclusive coverage range. The dataset contains scheduled calendar metadata
// only; actual, forecast, revised, and surprise values are intentionally absent.

enum E2NewsImpact { E2_NEWS_IMPACT_LOW,E2_NEWS_IMPACT_MEDIUM,E2_NEWS_IMPACT_HIGH };
enum E2NewsReason { E2_NEWS_FILTER_DISABLED,E2_NEWS_VALID_NO_RELEVANT_NEWS,E2_NEWS_BLOCKED_HIGH_IMPACT_NEWS,E2_NEWS_DATA_UNAVAILABLE,E2_NEWS_DATA_OUT_OF_RANGE,E2_NEWS_DATA_INVALID,E2_NEWS_CURRENCY_RESOLUTION_FAILED,E2_NEWS_TIME_CONVERSION_FAILED };

string E2NewsImpactName(const E2NewsImpact impact){return(impact==E2_NEWS_IMPACT_HIGH ? "HIGH" : (impact==E2_NEWS_IMPACT_MEDIUM ? "MEDIUM" : "LOW"));}
string E2NewsReasonName(const E2NewsReason reason){switch(reason){case E2_NEWS_FILTER_DISABLED:return("NEWS_FILTER_DISABLED");case E2_NEWS_VALID_NO_RELEVANT_NEWS:return("VALID_NO_RELEVANT_NEWS");case E2_NEWS_BLOCKED_HIGH_IMPACT_NEWS:return("BLOCKED_HIGH_IMPACT_NEWS");case E2_NEWS_DATA_UNAVAILABLE:return("NEWS_DATA_UNAVAILABLE");case E2_NEWS_DATA_OUT_OF_RANGE:return("NEWS_DATA_OUT_OF_RANGE");case E2_NEWS_DATA_INVALID:return("NEWS_DATA_INVALID");case E2_NEWS_CURRENCY_RESOLUTION_FAILED:return("CURRENCY_RESOLUTION_FAILED");default:return("TIME_CONVERSION_FAILED");}}

struct E2NewsEvent { datetime time_utc; string currency; E2NewsImpact impact; string name; };
struct E2NewsResult
  {
   bool ready,eligible,enabled,relevant_event_found;
   datetime evaluation_time,evaluation_utc,event_time_utc,blackout_start_utc,blackout_end_utc;
   string base_currency,quote_currency,event_currency,event_name;
   E2NewsImpact event_impact;
   int minutes_before,minutes_after;
   E2NewsReason reason;
  };

class E2NewsFilter
  {
private:
   E2Config m_configuration;
   bool m_initialized,m_dataset_valid;
   E2NewsReason m_load_reason;
   datetime m_coverage_start_utc,m_coverage_end_utc;
   E2NewsEvent m_events[];
   E2Logger *m_logger;

   string Trim(const string value) const { string result=value; StringTrimLeft(result); StringTrimRight(result); return(result); }
   string Upper(const string value) const { string result=value; StringToUpper(result); return(result); }
   string ExpectedCommonPath(void) const
     {
      string path=TerminalInfoString(TERMINAL_COMMONDATA_PATH);
      return(path+"\\Files\\"+m_configuration.news_data_file);
     }
   string FileOpenErrorDescription(const int error_code) const
     {
      if(error_code==5004) return("cannot open file");
      if(error_code==5002) return("file does not exist or cannot be opened");
      if(error_code==5011) return("file is incompatible with the requested flags");
      return("MT5 file API error");
     }
   bool IsKnownCurrency(const string currency) const
     {
      const string known=",USD,EUR,GBP,JPY,CHF,AUD,NZD,CAD,SEK,NOK,DKK,PLN,CZK,HUF,TRY,ZAR,MXN,BRL,HKD,SGD,CNH,CNY,INR,KRW,THB,ILS,RUB,";
      return(StringFind(known,","+currency+",")>=0);
     }
   bool ParseImpact(const string text,E2NewsImpact &impact) const
     {
      const string value=Upper(Trim(text));
      if(value=="HIGH"){impact=E2_NEWS_IMPACT_HIGH;return(true);} if(value=="MEDIUM"){impact=E2_NEWS_IMPACT_MEDIUM;return(true);} if(value=="LOW"){impact=E2_NEWS_IMPACT_LOW;return(true);} return(false);
     }
   bool ParseUtc(const string text,datetime &value) const
     {
      const string normalized=Trim(text);
      if(StringLen(normalized)!=16) return(false);
      value=StringToTime(normalized);
      return(value>0 && TimeToString(value,TIME_DATE|TIME_MINUTES)==normalized);
     }
   bool ParsePair(const string symbol,string &base,string &quote) const
     {
      const string upper=Upper(symbol);
      for(int i=0;i<=StringLen(upper)-6;i++)
        {
         base=StringSubstr(upper,i,3); quote=StringSubstr(upper,i+3,3);
         if(IsKnownCurrency(base) && IsKnownCurrency(quote) && base!=quote) return(true);
        }
      base=""; quote=""; return(false);
     }
   bool IsDuplicate(const E2NewsEvent &candidate) const
     {
      for(int i=0;i<ArraySize(m_events);i++) if(m_events[i].time_utc==candidate.time_utc && m_events[i].currency==candidate.currency && m_events[i].impact==candidate.impact && m_events[i].name==candidate.name) return(true);
      return(false);
     }
   void SortEvents(void)
     {
      for(int i=1;i<ArraySize(m_events);i++){E2NewsEvent key=m_events[i];int j=i-1;while(j>=0 && (m_events[j].time_utc>key.time_utc || (m_events[j].time_utc==key.time_utc && (m_events[j].currency>key.currency || (m_events[j].currency==key.currency && m_events[j].name>key.name))))){m_events[j+1]=m_events[j];j--;}m_events[j+1]=key;}
     }
   int LowerBound(const datetime time_utc) const
     {
      int left=0,right=ArraySize(m_events);while(left<right){int middle=(left+right)/2;if(m_events[middle].time_utc<time_utc)left=middle+1;else right=middle;}return(left);
     }
   bool LoadDataset(void)
     {
      ArrayResize(m_events,0);m_dataset_valid=false;m_load_reason=E2_NEWS_DATA_UNAVAILABLE;m_coverage_start_utc=0;m_coverage_end_utc=0;
      if(StringLen(Trim(m_configuration.news_data_file))==0){m_load_reason=E2_NEWS_DATA_INVALID;return(false);}
      if(m_logger!=NULL) m_logger.Info("Loading FILE_COMMON news CSV: filename='"+m_configuration.news_data_file+"', expectedPath='"+ExpectedCommonPath()+"'.","News");
      ResetLastError();
      const int handle=FileOpen(m_configuration.news_data_file,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',');
      if(handle==INVALID_HANDLE)
        {
         const int error_code=GetLastError();
         if(m_logger!=NULL) m_logger.Error("News CSV open failed: filename='"+m_configuration.news_data_file+"', expectedPath='"+ExpectedCommonPath()+"', error="+IntegerToString(error_code)+" ("+FileOpenErrorDescription(error_code)+").","News");
         return(false);
        }
      string header[7];for(int i=0;i<7;i++)header[i]=FileReadString(handle);
      if(header[0]!="record_type" || header[1]!="event_time_utc" || header[2]!="currency" || header[3]!="impact" || header[4]!="event_name" || header[5]!="coverage_start_utc" || header[6]!="coverage_end_utc" || (!FileIsLineEnding(handle) && !FileIsEnding(handle))){FileClose(handle);m_load_reason=E2_NEWS_DATA_INVALID;return(false);}
      bool meta_found=false;
      while(!FileIsEnding(handle))
        {
         string field[7];for(int i=0;i<7;i++)field[i]=FileReadString(handle);
         if(!FileIsLineEnding(handle) && !FileIsEnding(handle)){FileClose(handle);m_load_reason=E2_NEWS_DATA_INVALID;return(false);}
         const string record=Upper(Trim(field[0]));
         if(record=="META")
           {
            if(meta_found || !ParseUtc(field[5],m_coverage_start_utc) || !ParseUtc(field[6],m_coverage_end_utc) || m_coverage_start_utc>m_coverage_end_utc){FileClose(handle);m_load_reason=E2_NEWS_DATA_INVALID;return(false);} meta_found=true;
           }
         else if(record=="EVENT")
           {
            E2NewsEvent event;event.currency=Upper(Trim(field[2]));event.name=Trim(field[4]);
            if(!ParseUtc(field[1],event.time_utc) || !IsKnownCurrency(event.currency) || event.name=="" || !ParseImpact(field[3],event.impact)){FileClose(handle);m_load_reason=E2_NEWS_DATA_INVALID;return(false);}
            if(!IsDuplicate(event)){int size=ArraySize(m_events);ArrayResize(m_events,size+1);m_events[size]=event;}
           }
         else {FileClose(handle);m_load_reason=E2_NEWS_DATA_INVALID;return(false);}
        }
      FileClose(handle);
      if(!meta_found){m_load_reason=E2_NEWS_DATA_INVALID;return(false);}
      for(int i=0;i<ArraySize(m_events);i++)if(m_events[i].time_utc<m_coverage_start_utc || m_events[i].time_utc>m_coverage_end_utc){m_load_reason=E2_NEWS_DATA_INVALID;return(false);}
      SortEvents();m_dataset_valid=true;
      if(m_logger!=NULL) m_logger.Info("News CSV loaded: filename='"+m_configuration.news_data_file+"', validEvents="+IntegerToString(ArraySize(m_events))+", coverageStart="+TimeToString(m_coverage_start_utc,TIME_DATE|TIME_MINUTES)+", coverageEnd="+TimeToString(m_coverage_end_utc,TIME_DATE|TIME_MINUTES)+".","News");
      return(true);
     }
   void Reset(E2NewsResult &result,const datetime source_time) const
     {
      ZeroMemory(result);result.evaluation_time=source_time;result.enabled=m_configuration.news_filter_enabled;result.minutes_before=m_configuration.high_impact_buffer_before_minutes;result.minutes_after=m_configuration.high_impact_buffer_after_minutes;result.reason=E2_NEWS_DATA_UNAVAILABLE;
     }
public:
   E2NewsFilter(void):m_initialized(false),m_dataset_valid(false),m_load_reason(E2_NEWS_DATA_UNAVAILABLE),m_coverage_start_utc(0),m_coverage_end_utc(0),m_logger(NULL){}
   void Initialize(const E2Config &configuration,E2Logger &logger){m_configuration=configuration;m_logger=&logger;m_initialized=true;if(!m_configuration.news_filter_enabled){m_dataset_valid=false;m_load_reason=E2_NEWS_FILTER_DISABLED;return;}LoadDataset();}
   bool IsDatasetValid(void) const{return(m_dataset_valid);}
   E2NewsReason LoadReason(void) const{return(m_load_reason);}
   datetime CoverageStartUtc(void) const{return(m_coverage_start_utc);}
   datetime CoverageEndUtc(void) const{return(m_coverage_end_utc);}
   int EventCount(void) const{return(ArraySize(m_events));}
   bool Evaluate(const string symbol,const datetime source_time,E2NewsResult &result) const
     {
      Reset(result,source_time);if(!m_initialized)return(false);
      if(!result.enabled){result.ready=true;result.eligible=true;result.reason=E2_NEWS_FILTER_DISABLED;return(true);}
      if(!ParsePair(symbol,result.base_currency,result.quote_currency)){result.reason=E2_NEWS_CURRENCY_RESOLUTION_FAILED;return(true);}
      if(m_configuration.broker_utc_offset_hours < -14 || m_configuration.broker_utc_offset_hours > 14 || source_time<=0){result.reason=E2_NEWS_TIME_CONVERSION_FAILED;return(true);}
      result.evaluation_utc=source_time;result.evaluation_utc-=m_configuration.broker_utc_offset_hours*3600;
      if(result.evaluation_utc<=0){result.reason=E2_NEWS_TIME_CONVERSION_FAILED;return(true);}
      if(!m_dataset_valid){result.reason=m_load_reason;return(true);}
      if(result.evaluation_utc<m_coverage_start_utc || result.evaluation_utc>m_coverage_end_utc){result.reason=E2_NEWS_DATA_OUT_OF_RANGE;return(true);}
      result.ready=true;
      const datetime first=result.evaluation_utc-m_configuration.high_impact_buffer_after_minutes*60;
      const datetime last=result.evaluation_utc+m_configuration.high_impact_buffer_before_minutes*60;
      for(int i=LowerBound(first);i<ArraySize(m_events) && m_events[i].time_utc<=last;i++)
        {
         const E2NewsEvent event=m_events[i];
         if((event.currency!=result.base_currency && event.currency!=result.quote_currency) || (m_configuration.news_high_impact_only && event.impact!=E2_NEWS_IMPACT_HIGH)) continue;
         result.relevant_event_found=true;result.event_currency=event.currency;result.event_name=event.name;result.event_impact=event.impact;result.event_time_utc=event.time_utc;result.blackout_start_utc=event.time_utc-m_configuration.high_impact_buffer_before_minutes*60;result.blackout_end_utc=event.time_utc+m_configuration.high_impact_buffer_after_minutes*60;result.reason=E2_NEWS_BLOCKED_HIGH_IMPACT_NEWS;return(true);
        }
      result.ready=true;result.eligible=true;result.reason=E2_NEWS_VALID_NO_RELEVANT_NEWS;return(true);
     }
  };

#endif // E2_FILTERS_E2NEWSFILTER_MQH
