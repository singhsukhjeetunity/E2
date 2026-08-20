//+------------------------------------------------------------------+
//|                                               E2NewsExporter.mq5 |
//| Deterministic native-MT5 calendar export for E2 Strategy Tester. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property version   "2.02"
#property script_show_inputs

input group "=== UTC COVERAGE ==="
input datetime InpStartDateUtc = D'2024.01.01 00:00';
input datetime InpEndDateUtc = D'2024.12.31 23:59';
input int InpCalendarServerUtcOffsetHours = 2; // Current E2 research offset; verify server time minus UTC before export.

input group "=== CURRENCIES ==="
input bool InpIncludeEUR = true;
input bool InpIncludeUSD = true;
input bool InpIncludeGBP = false;
input bool InpIncludeJPY = false;
input bool InpIncludeCHF = false;
input bool InpIncludeCAD = false;
input bool InpIncludeAUD = false;
input bool InpIncludeNZD = false;

input group "=== IMPORTANCE ==="
input bool InpIncludeLowImpact = false;
input bool InpIncludeMediumImpact = false;
input bool InpIncludeHighImpact = true;

input group "=== OUTPUT ==="
input string InpOutputFileName = "E2_news_events.csv";
input bool InpOverwriteExisting = true;

struct E2ExportRecord
  {
   datetime time_utc;
   string currency;
   string impact;
   string title;
   ulong event_id;
   ulong value_id;
  };

struct E2EventCacheEntry
  {
   ulong event_id;
   MqlCalendarEvent event;
   string currency;
   bool valid;
  };

struct E2CountryCacheEntry
  {
   ulong country_id;
   string currency;
   bool valid;
  };

struct E2ExportDiagnostics
  {
   long events_fetched;
   long currency_matched;
   long importance_matched;
   long duplicates_suppressed;
   long invalid_events_skipped;
  };

struct E2SchemaDiagnostics
  {
   int expected_columns;
   long rows_validated;
   long invalid_column_count;
   long invalid_timestamp_count;
   long invalid_currency_count;
   long invalid_importance_count;
   long duplicate_identity_count;
   long sort_violations;
   long row_count_mismatch;
   long meta_errors;
  };

E2ExportRecord g_records[];
E2EventCacheEntry g_event_cache[];
E2CountryCacheEntry g_country_cache[];
E2ExportDiagnostics g_export;
E2SchemaDiagnostics g_schema;
datetime g_start_utc=0,g_end_utc=0;
bool g_done_emitted=false;

string Trim(const string value)
  {
   string result=value;
   StringTrimLeft(result);
   StringTrimRight(result);
   return(result);
  }

string Upper(const string value)
  {
   string result=value;
   StringToUpper(result);
   return(result);
  }

datetime MinuteFloor(const datetime value)
  {
   const long raw=(long)value;
   return((datetime)(raw-(raw%60)));
  }

string UtcText(const datetime value)
  {
   return(TimeToString(value,TIME_DATE|TIME_MINUTES));
  }

bool ParseUtc(const string text,datetime &value)
  {
   const string normalized=Trim(text);
   if(StringLen(normalized)!=16)return(false);
   value=StringToTime(normalized);
   return(value>0 && UtcText(value)==normalized);
  }

string AsciiSafe(const string value)
  {
   string result="";
   for(int i=0;i<StringLen(value);i++)
     {
      const uint character=StringGetCharacter(value,i);
      if(character>=32 && character<=126 && character!=34 && character!=44 && character!=92)result+=ShortToString((ushort)character);
      else result+=StringFormat("\\u%04X",character);
     }
   return(result);
  }

bool IsKnownCurrency(const string currency)
  {
   return(currency=="EUR"||currency=="USD"||currency=="GBP"||currency=="JPY"||currency=="CHF"||currency=="CAD"||currency=="AUD"||currency=="NZD");
  }

bool IsSelectedCurrency(const string currency)
  {
   if(currency=="EUR")return(InpIncludeEUR);
   if(currency=="USD")return(InpIncludeUSD);
   if(currency=="GBP")return(InpIncludeGBP);
   if(currency=="JPY")return(InpIncludeJPY);
   if(currency=="CHF")return(InpIncludeCHF);
   if(currency=="CAD")return(InpIncludeCAD);
   if(currency=="AUD")return(InpIncludeAUD);
   if(currency=="NZD")return(InpIncludeNZD);
   return(false);
  }

void AddSelectedCurrency(string &values[],const string currency,const bool enabled)
  {
   if(!enabled)return;
   const int count=ArraySize(values);
   ArrayResize(values,count+1);
   values[count]=currency;
  }

void SelectedCurrencies(string &values[])
  {
   ArrayResize(values,0);
   AddSelectedCurrency(values,"EUR",InpIncludeEUR);
   AddSelectedCurrency(values,"USD",InpIncludeUSD);
   AddSelectedCurrency(values,"GBP",InpIncludeGBP);
   AddSelectedCurrency(values,"JPY",InpIncludeJPY);
   AddSelectedCurrency(values,"CHF",InpIncludeCHF);
   AddSelectedCurrency(values,"CAD",InpIncludeCAD);
   AddSelectedCurrency(values,"AUD",InpIncludeAUD);
   AddSelectedCurrency(values,"NZD",InpIncludeNZD);
  }

string Join(const string &values[],const string separator)
  {
   string result="";
   for(int i=0;i<ArraySize(values);i++)result+=(i==0?"":separator)+values[i];
   return(result);
  }

string ImportanceMask(void)
  {
   string values[];
   ArrayResize(values,0);
   if(InpIncludeLowImpact){int n=ArraySize(values);ArrayResize(values,n+1);values[n]="LOW";}
   if(InpIncludeMediumImpact){int n=ArraySize(values);ArrayResize(values,n+1);values[n]="MEDIUM";}
   if(InpIncludeHighImpact){int n=ArraySize(values);ArrayResize(values,n+1);values[n]="HIGH";}
   return(Join(values,"|"));
  }

bool MapImportance(const ENUM_CALENDAR_EVENT_IMPORTANCE importance,string &text,bool &selected)
  {
   selected=false;
   if(importance==CALENDAR_IMPORTANCE_LOW){text="LOW";selected=InpIncludeLowImpact;return(true);}
   if(importance==CALENDAR_IMPORTANCE_MODERATE){text="MEDIUM";selected=InpIncludeMediumImpact;return(true);}
   if(importance==CALENDAR_IMPORTANCE_HIGH){text="HIGH";selected=InpIncludeHighImpact;return(true);}
   text="";
   return(false);
  }

int FindCountry(const ulong country_id)
  {
   for(int i=0;i<ArraySize(g_country_cache);i++)if(g_country_cache[i].country_id==country_id)return(i);
   return(-1);
  }

bool ResolveCountry(const ulong country_id,string &currency)
  {
   const int cached=FindCountry(country_id);
   if(cached>=0){currency=g_country_cache[cached].currency;return(g_country_cache[cached].valid);}
   E2CountryCacheEntry entry;
   ZeroMemory(entry);
   entry.country_id=country_id;
   MqlCalendarCountry country;
   ResetLastError();
   entry.valid=CalendarCountryById((long)country_id,country);
   if(entry.valid)entry.currency=Upper(Trim(country.currency));
   const int count=ArraySize(g_country_cache);
   ArrayResize(g_country_cache,count+1);
   g_country_cache[count]=entry;
   currency=entry.currency;
   return(entry.valid);
  }

int FindEvent(const ulong event_id)
  {
   for(int i=0;i<ArraySize(g_event_cache);i++)if(g_event_cache[i].event_id==event_id)return(i);
   return(-1);
  }

bool ResolveEvent(const ulong event_id,MqlCalendarEvent &event,string &currency)
  {
   const int cached=FindEvent(event_id);
   if(cached>=0){event=g_event_cache[cached].event;currency=g_event_cache[cached].currency;return(g_event_cache[cached].valid);}
   E2EventCacheEntry entry;
   ZeroMemory(entry);
   entry.event_id=event_id;
   ResetLastError();
   entry.valid=CalendarEventById(event_id,entry.event);
   if(entry.valid)entry.valid=ResolveCountry(entry.event.country_id,entry.currency);
   const int count=ArraySize(g_event_cache);
   ArrayResize(g_event_cache,count+1);
   g_event_cache[count]=entry;
   event=entry.event;
   currency=entry.currency;
   return(entry.valid);
  }

bool DuplicateIdentity(const E2ExportRecord &candidate)
  {
   for(int i=0;i<ArraySize(g_records);i++)
      if(g_records[i].event_id==candidate.event_id && g_records[i].value_id==candidate.value_id && g_records[i].time_utc==candidate.time_utc)return(true);
   return(false);
  }

void AppendRecord(const E2ExportRecord &record)
  {
   const int count=ArraySize(g_records);
   ArrayResize(g_records,count+1);
   g_records[count]=record;
  }

bool ComesAfter(const E2ExportRecord &left,const E2ExportRecord &right)
  {
   if(left.time_utc!=right.time_utc)return(left.time_utc>right.time_utc);
   const int currency_compare=StringCompare(left.currency,right.currency);
   if(currency_compare!=0)return(currency_compare>0);
   if(left.value_id!=right.value_id)return(left.value_id>right.value_id);
   if(left.event_id!=right.event_id)return(left.event_id>right.event_id);
   return(StringCompare(left.title,right.title)>0);
  }

void SortRecords(void)
  {
   for(int i=1;i<ArraySize(g_records);i++)
     {
      const E2ExportRecord key=g_records[i];
      int j=i-1;
      while(j>=0 && ComesAfter(g_records[j],key)){g_records[j+1]=g_records[j];j--;}
      g_records[j+1]=key;
     }
  }

void PrintExportError(const string reason,const string details)
  {
   Print("[E2_NEWS_EXPORT_ERROR] reason="+reason+(details==""?"":", "+details));
  }

bool FetchCurrency(const string requested_currency,const datetime server_from,const datetime server_to,string &failure_reason)
  {
   MqlCalendarValue values[];
   ResetLastError();
   const int count=CalendarValueHistory(values,server_from,server_to,"",requested_currency);
   const int calendar_error=GetLastError();
   Print("[E2_NEWS_CALENDAR] currency="+requested_currency+", queryStartServer="+UtcText(server_from)+", queryEndServer="+UtcText(server_to)+", calendarResult="+IntegerToString(count)+", lastError="+IntegerToString(calendar_error));
   if(count<=0)
     {
      failure_reason=(count<0?"CALENDAR_QUERY_FAILED":"CALENDAR_QUERY_EMPTY");
      PrintExportError(failure_reason,"currency="+requested_currency+", calendarResult="+IntegerToString(count)+", lastError="+IntegerToString(calendar_error));
      return(false);
     }
   g_export.events_fetched+=count;
   for(int i=0;i<count;i++)
     {
      const MqlCalendarValue value=values[i];
      if(value.id==0||value.event_id==0||value.time<=0){g_export.invalid_events_skipped++;continue;}
      MqlCalendarEvent event;
      string currency="";
      if(!ResolveEvent(value.event_id,event,currency)){g_export.invalid_events_skipped++;continue;}
      if(currency!=requested_currency||!IsKnownCurrency(currency)||!IsSelectedCurrency(currency))continue;
      g_export.currency_matched++;
      string importance="";
      bool importance_selected=false;
      if(!MapImportance(event.importance,importance,importance_selected)){g_export.invalid_events_skipped++;continue;}
      if(!importance_selected)continue;
      g_export.importance_matched++;
      if(event.time_mode!=CALENDAR_TIMEMODE_DATETIME){g_export.invalid_events_skipped++;continue;}
      const string base_title=Trim(event.name);
      if(base_title==""){g_export.invalid_events_skipped++;continue;}
      const datetime raw_utc=(datetime)((long)value.time-InpCalendarServerUtcOffsetHours*3600);
      const datetime time_utc=MinuteFloor(raw_utc);
      if(time_utc<g_start_utc||time_utc>g_end_utc){g_export.invalid_events_skipped++;continue;}
      E2ExportRecord record;
      record.time_utc=time_utc;
      record.currency=currency;
      record.impact=importance;
      record.event_id=value.event_id;
      record.value_id=value.id;
      record.title=AsciiSafe(base_title)+" [MT5_EVENT_ID="+StringFormat("%I64u",record.event_id)+";MT5_VALUE_ID="+StringFormat("%I64u",record.value_id)+"]";
      if(DuplicateIdentity(record)){g_export.duplicates_suppressed++;continue;}
      AppendRecord(record);
     }
   return(true);
  }

bool ValidOutputFileName(const string file_name)
  {
   const string value=Trim(file_name);
   return(value!="" && StringFind(value,"..")<0 && StringFind(value,"\\")<0 && StringFind(value,"/")<0 && StringFind(value,":")<0);
  }

string CommonPath(const string file_name)
  {
   return(TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+file_name);
  }

bool WriteDataset(const string file_name,string &failure_reason)
  {
   const int flags=FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ;
   ResetLastError();
   const int handle=FileOpen(file_name,flags,',');
   if(handle==INVALID_HANDLE)
     {
      const int file_error=GetLastError();
      failure_reason="FILE_OPEN_WRITE_FAILED";
      PrintExportError(failure_reason,"filename="+file_name+", flags="+IntegerToString(flags)+", lastError="+IntegerToString(file_error));
      return(false);
     }
   bool ok=(FileWrite(handle,"record_type","event_time_utc","currency","impact","event_name","coverage_start_utc","coverage_end_utc")>0);
   ok=ok && (FileWrite(handle,"META","","","","",UtcText(g_start_utc),UtcText(g_end_utc))>0);
   for(int i=0;i<ArraySize(g_records)&&ok;i++)
      ok=(FileWrite(handle,"EVENT",UtcText(g_records[i].time_utc),g_records[i].currency,g_records[i].impact,g_records[i].title,"","")>0);
   const int write_error=GetLastError();
   FileFlush(handle);
   FileClose(handle);
   if(!ok)
     {
      failure_reason="FILE_WRITE_FAILED";
      PrintExportError(failure_reason,"filename="+file_name+", flags="+IntegerToString(flags)+", lastError="+IntegerToString(write_error));
     }
   return(ok);
  }

bool CompositeSeen(const string &seen[],const string value)
  {
   for(int i=0;i<ArraySize(seen);i++)if(seen[i]==value)return(true);
   return(false);
  }

bool ValidateDataset(const string file_name,string &failure_reason)
  {
   ZeroMemory(g_schema);
   g_schema.expected_columns=7;
   ResetLastError();
   const int handle=FileOpen(file_name,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',');
   if(handle==INVALID_HANDLE)
     {
      const int file_error=GetLastError();
      g_schema.invalid_column_count++;
      failure_reason="FILE_OPEN_VALIDATE_FAILED";
      PrintExportError(failure_reason,"filename="+file_name+", flags="+IntegerToString(FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ)+", lastError="+IntegerToString(file_error));
      return(false);
     }
   string header[7];
   for(int i=0;i<7;i++)header[i]=FileReadString(handle);
   if(header[0]!="record_type"||header[1]!="event_time_utc"||header[2]!="currency"||header[3]!="impact"||header[4]!="event_name"||header[5]!="coverage_start_utc"||header[6]!="coverage_end_utc"||(!FileIsLineEnding(handle)&&!FileIsEnding(handle)))g_schema.invalid_column_count++;
   bool meta_found=false;
   int record_index=0;
   string seen[];
   ArrayResize(seen,0);
   while(!FileIsEnding(handle))
     {
      string field[7];
      for(int i=0;i<7;i++)field[i]=FileReadString(handle);
      if(!FileIsLineEnding(handle)&&!FileIsEnding(handle)){g_schema.invalid_column_count++;break;}
      const string type=Upper(Trim(field[0]));
      if(type=="META")
        {
         datetime start=0,end=0;
         if(meta_found||!ParseUtc(field[5],start)||!ParseUtc(field[6],end)||start!=g_start_utc||end!=g_end_utc)g_schema.meta_errors++;
         meta_found=true;
         continue;
        }
      if(type!="EVENT"){g_schema.invalid_column_count++;continue;}
      g_schema.rows_validated++;
      datetime time_utc=0;
      if(!ParseUtc(field[1],time_utc)||time_utc<g_start_utc||time_utc>g_end_utc)g_schema.invalid_timestamp_count++;
      const string currency=Upper(Trim(field[2]));
      if(!IsKnownCurrency(currency)||!IsSelectedCurrency(currency))g_schema.invalid_currency_count++;
      const string importance=Upper(Trim(field[3]));
      if((importance!="LOW"&&importance!="MEDIUM"&&importance!="HIGH")||(importance=="LOW"&&!InpIncludeLowImpact)||(importance=="MEDIUM"&&!InpIncludeMediumImpact)||(importance=="HIGH"&&!InpIncludeHighImpact))g_schema.invalid_importance_count++;
      const string identity=IntegerToString((int)time_utc)+"|"+currency+"|"+importance+"|"+field[4];
      if(CompositeSeen(seen,identity))g_schema.duplicate_identity_count++;else{int n=ArraySize(seen);ArrayResize(seen,n+1);seen[n]=identity;}
      if(record_index>=ArraySize(g_records)||time_utc!=g_records[record_index].time_utc||currency!=g_records[record_index].currency||importance!=g_records[record_index].impact||field[4]!=g_records[record_index].title)g_schema.sort_violations++;
      record_index++;
     }
   FileClose(handle);
   if(!meta_found)g_schema.meta_errors++;
   if(record_index!=ArraySize(g_records))g_schema.row_count_mismatch++;
   const long errors=g_schema.invalid_column_count+g_schema.invalid_timestamp_count+g_schema.invalid_currency_count+g_schema.invalid_importance_count+g_schema.duplicate_identity_count+g_schema.sort_violations+g_schema.row_count_mismatch+g_schema.meta_errors;
   if(errors==0)return(true);
   failure_reason="POST_WRITE_VALIDATION_FAILED";
   PrintExportError(failure_reason,"validationErrors="+StringFormat("%I64d",errors));
   return(false);
  }

long ValidationErrors(void)
  {
   return(g_schema.invalid_column_count+g_schema.invalid_timestamp_count+g_schema.invalid_currency_count+g_schema.invalid_importance_count+g_schema.duplicate_identity_count+g_schema.sort_violations+g_schema.row_count_mismatch+g_schema.meta_errors);
  }

void PrintSummary(const string currencies,const string output_file)
  {
   const string first=(ArraySize(g_records)>0?UtcText(g_records[0].time_utc):"NA");
   const string last=(ArraySize(g_records)>0?UtcText(g_records[ArraySize(g_records)-1].time_utc):"NA");
   Print("[E2_NEWS_EXPORT] start="+UtcText(g_start_utc)+", end="+UtcText(g_end_utc)+", currencies="+currencies+", importanceMask="+ImportanceMask()+", eventsFetched="+StringFormat("%I64d",g_export.events_fetched)+", currencyMatched="+StringFormat("%I64d",g_export.currency_matched)+", importanceMatched="+StringFormat("%I64d",g_export.importance_matched)+", eventsExported="+IntegerToString(ArraySize(g_records))+", duplicatesSuppressed="+StringFormat("%I64d",g_export.duplicates_suppressed)+", invalidEventsSkipped="+StringFormat("%I64d",g_export.invalid_events_skipped)+", outputFile="+CommonPath(output_file)+", validationErrors="+StringFormat("%I64d",ValidationErrors())+", firstEventTime="+first+", lastEventTime="+last);
   Print("[E2_NEWS_SCHEMA_VERIFY] expectedColumns="+IntegerToString(g_schema.expected_columns)+", rowsValidated="+StringFormat("%I64d",g_schema.rows_validated)+", invalidColumnCount="+StringFormat("%I64d",g_schema.invalid_column_count)+", invalidTimestampCount="+StringFormat("%I64d",g_schema.invalid_timestamp_count)+", invalidCurrencyCount="+StringFormat("%I64d",g_schema.invalid_currency_count)+", invalidImportanceCount="+StringFormat("%I64d",g_schema.invalid_importance_count)+", duplicateIdentityCount="+StringFormat("%I64d",g_schema.duplicate_identity_count)+", sortViolations="+StringFormat("%I64d",g_schema.sort_violations)+", rowCountMismatch="+StringFormat("%I64d",g_schema.row_count_mismatch)+", metaErrors="+StringFormat("%I64d",g_schema.meta_errors));
  }

void PrintStart(const string currencies,const string output_file)
  {
   const string importance=(ImportanceMask()==""?"NONE":ImportanceMask());
   Print("[E2_NEWS_EXPORT_START] start="+UtcText(g_start_utc)+", end="+UtcText(g_end_utc)+", currencies="+(currencies==""?"NONE":currencies)+", impactLevels="+importance+", outputFile="+(output_file==""?"<empty>":output_file)+", overwrite="+(InpOverwriteExisting?"true":"false")+", serverUtcOffsetHours="+IntegerToString(InpCalendarServerUtcOffsetHours));
  }

void PrintPath(const string output_file)
  {
   const string common_path=TerminalInfoString(TERMINAL_COMMONDATA_PATH);
   Print("[E2_NEWS_EXPORT_PATH] commonDataPath="+common_path+", relativeFile=Files\\"+output_file+", effectiveFile="+CommonPath(output_file));
  }

void PrintDone(const bool success,const string reason,const string output_file)
  {
   if(g_done_emitted)return;
   g_done_emitted=true;
   const string effective_file=(output_file==""?"NA":CommonPath(output_file));
   if(success)
      Print("[E2_NEWS_EXPORT_DONE] status=SUCCESS, eventsExported="+IntegerToString(ArraySize(g_records))+", validationErrors="+StringFormat("%I64d",ValidationErrors())+", outputFile="+effective_file);
   else
      Print("[E2_NEWS_EXPORT_DONE] status=FAIL, reason="+(reason==""?"UNSPECIFIED_FAILURE":reason)+", eventsExported="+IntegerToString(ArraySize(g_records))+", validationErrors="+StringFormat("%I64d",ValidationErrors())+", outputFile="+effective_file);
  }

bool RunExporter(const string &currencies[],const string output_file,string &failure_reason)
  {
   if((bool)MQLInfoInteger(MQL_TESTER))
     {
      failure_reason="RUN_OUTSIDE_STRATEGY_TESTER";
      PrintExportError(failure_reason,"");
      return(false);
     }
   if(g_start_utc<=0||g_end_utc<g_start_utc)
     {
      failure_reason="INVALID_DATE_RANGE";
      PrintExportError(failure_reason,"");
      return(false);
     }
   if(InpCalendarServerUtcOffsetHours<-14||InpCalendarServerUtcOffsetHours>14)
     {
      failure_reason="INVALID_SERVER_UTC_OFFSET";
      PrintExportError(failure_reason,"serverUtcOffsetHours="+IntegerToString(InpCalendarServerUtcOffsetHours));
      return(false);
     }
   if(!InpIncludeLowImpact&&!InpIncludeMediumImpact&&!InpIncludeHighImpact)
     {
      failure_reason="NO_IMPORTANCE_SELECTED";
      PrintExportError(failure_reason,"");
      return(false);
     }
   if(!ValidOutputFileName(output_file))
     {
      failure_reason="INVALID_OUTPUT_FILENAME";
      PrintExportError(failure_reason,"outputFile="+(output_file==""?"<empty>":output_file));
      return(false);
     }
   if(ArraySize(currencies)==0)
     {
      failure_reason="NO_CURRENCIES_SELECTED";
      PrintExportError(failure_reason,"");
      return(false);
     }
   PrintPath(output_file);
   if(!InpOverwriteExisting&&FileIsExist(output_file,FILE_COMMON))
     {
      failure_reason="OUTPUT_EXISTS_OVERWRITE_DISABLED";
      PrintExportError(failure_reason,"outputFile="+CommonPath(output_file));
      return(false);
     }
   const datetime server_from=(datetime)((long)g_start_utc+InpCalendarServerUtcOffsetHours*3600);
   const datetime server_to=(datetime)((long)g_end_utc+InpCalendarServerUtcOffsetHours*3600+60);
   for(int i=0;i<ArraySize(currencies);i++)if(!FetchCurrency(currencies[i],server_from,server_to,failure_reason))return(false);
   SortRecords();
   if(ArraySize(g_records)==0)
     {
      failure_reason="NO_MATCHING_EVENTS";
      PrintExportError(failure_reason,"eventsFetched="+StringFormat("%I64d",g_export.events_fetched)+", importanceMask="+ImportanceMask());
      return(false);
     }
   if(!WriteDataset(output_file,failure_reason))return(false);
   const bool valid=ValidateDataset(output_file,failure_reason);
   PrintSummary(Join(currencies,"|"),output_file);
   return(valid);
  }

void OnStart(void)
  {
   ArrayResize(g_records,0);
   ArrayResize(g_event_cache,0);
   ArrayResize(g_country_cache,0);
   ZeroMemory(g_export);
   ZeroMemory(g_schema);
   g_done_emitted=false;
   g_start_utc=MinuteFloor(InpStartDateUtc);
   g_end_utc=MinuteFloor(InpEndDateUtc);
   string currencies[];
   SelectedCurrencies(currencies);
   const string currencies_text=Join(currencies,"|");
   const string output_file=Trim(InpOutputFileName);
   PrintStart(currencies_text,output_file);
   string failure_reason="";
   const bool success=RunExporter(currencies,output_file,failure_reason);
   PrintDone(success,failure_reason,output_file);
  }
