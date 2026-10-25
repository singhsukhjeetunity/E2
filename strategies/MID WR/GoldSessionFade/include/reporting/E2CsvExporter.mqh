#ifndef E2_REPORTING_E2CSVEXPORTER_MQH
#define E2_REPORTING_E2CSVEXPORTER_MQH

#include "E2Logger.mqh"

// Files are created under the terminal common-files directory when FILE_COMMON
// is used, allowing the same exporter to work in live terminals and testers.
// CSV access is shared so repeated tester runs and other reporting consumers do
// not retain an exclusive lock on the output file.
class E2CsvExporter
  {
private:
   int               m_handle;
   bool              m_initialized;
   string            m_file_name;
   E2Logger          *m_logger;

   void ReportError(const string message)
     {
      if(m_logger!=NULL)
         m_logger.Error(message,"CSV");
     }

   string EscapeValue(const string value)
     {
      string escaped=value;
      StringReplace(escaped,"\r"," ");
      StringReplace(escaped,"\n"," ");
      StringReplace(escaped,"\"","\"\"");
      return("\""+escaped+"\"");
     }

   bool WriteValues(const string &values[])
     {
      if(!m_initialized || m_handle==INVALID_HANDLE)
        {
         ReportError("CSV write requested before initialization.");
         return(false);
        }

      string line="";
      const int value_count=ArraySize(values);
      for(int index=0; index<value_count; index++)
        {
         if(index>0)
            line+=",";
         line+=EscapeValue(values[index]);
        }
      line+="\r\n";

      ResetLastError();
      const uint written=FileWriteString(m_handle,line);
      if(written!=(uint)StringLen(line))
        {
         ReportError("CSV write failed for '"+m_file_name+"' (error "+IntegerToString(GetLastError())+").");
         return(false);
        }

      FileFlush(m_handle);
      return(true);
     }

public:
                     E2CsvExporter(void) : m_handle(INVALID_HANDLE),m_initialized(false),m_file_name(""),m_logger(NULL) {}

   bool              Initialize(const string file_name,E2Logger &logger)
     {
      m_logger=&logger;

      // Always release a prior handle before opening. This makes repeated EA
      // initialization and Strategy Tester runs independent of stale state.
      Close();

      if(file_name=="")
        {
         ReportError("CSV initialization requires a file name.");
         return(false);
        }

      ResetLastError();
      m_handle=FileOpen(file_name,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(m_handle==INVALID_HANDLE)
        {
         const int error_code=GetLastError();
         ReportError("Unable to open CSV file '"+file_name+"' (error "+IntegerToString(error_code)+").");
         return(false);
        }

      m_file_name=file_name;
      m_initialized=true;
      return(true);
     }

   bool              WriteHeader(const string &columns[])
     {
      return(WriteValues(columns));
     }

   bool              WriteRow(const string &values[])
     {
      return(WriteValues(values));
     }

   void              Close(void)
     {
      if(m_handle!=INVALID_HANDLE)
         FileClose(m_handle);

      m_handle=INVALID_HANDLE;
      m_initialized=false;
      m_file_name="";
     }

   bool              IsInitialized(void) const
     {
      return(m_initialized);
     }
  };

#endif // E2_REPORTING_E2CSVEXPORTER_MQH
