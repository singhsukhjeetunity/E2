#property strict
#property description "TEST ONLY: no orders; synthetic adapter and London range assertions."
#include "..\\include\\strategy\\E2LondonBreakoutEngine.mqh"
#include "..\\include\\reporting\\E2TradeReporter.mqh"
int failures=0,checks=0;
void Check(const bool ok,const string name){checks++;if(!ok){failures++;Print("[LRB_SELFTEST_FAIL] ",name);}}
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   E2Logger logger;logger.Initialize(true,false);
   E2BrokerTimeAdapter fixed,trans,bad;datetime utc,local;
   string base="E2\\Tests\\LondonSprint1\\";
   Check(!bad.Initialize("","E2_TEST_ONLY",true,logger),"missing_profile_rejected");
   Check(!bad.Initialize(base+"fixed.profile","WRONG_SERVER",true,logger),"wrong_server_rejected");
   Check(!bad.Initialize(base+"fixed.profile","E2_TEST_ONLY",false,logger),"test_profile_live_rejected");
   Check(fixed.Initialize(base+"fixed.profile","E2_TEST_ONLY",true,logger),"fixed_load");
   Check(trans.Initialize(base+"transitions.profile","E2_TEST_ONLY",true,logger),"transitions_load");
   Check(fixed.Digest()!=trans.Digest(),"policy_digest_sensitive");
   Check(fixed.ServerToUtc(D'2024.01.02 08:00',utc)&&utc==D'2024.01.02 08:00',"fixed_identity");
   Check(!fixed.ServerToUtc(D'2022.12.31 23:59:59',utc),"lower_coverage_rejected");
   Check(!fixed.ServerToUtc(D'2025.01.01 00:00',utc),"upper_coverage_exclusive");
   Check(trans.ServerToUtc(D'2024.03.31 02:59:59',utc)&&utc==D'2024.03.31 00:59:59',"pre_transition");
   Check(trans.ServerToUtc(D'2024.03.31 04:00',utc)&&utc==D'2024.03.31 01:00',"post_transition");
   Check(!trans.ServerToUtc(D'2024.03.31 03:30',utc),"spring_gap_rejected");
   Check(!trans.ServerToUtc(D'2024.10.27 03:30',utc),"autumn_overlap_rejected");
   Check(E2UtcToLondon(D'2024.03.31 00:59:59',local)&&local==D'2024.03.31 00:59:59',"London_pre_BST");
   Check(E2UtcToLondon(D'2024.03.31 01:00',local)&&local==D'2024.03.31 02:00',"London_BST_start");
   Check(E2UtcToLondon(D'2024.10.27 00:59:59',local)&&local==D'2024.10.27 01:59:59',"London_pre_GMT");
   Check(E2UtcToLondon(D'2024.10.27 01:00',local)&&local==D'2024.10.27 01:00',"London_GMT_start");
   Check(!E2UtcToLondon(D'1995.12.31 23:59:59',local),"London_unsupported_history");
   Check(trans.London(D'2024.07.01 03:00',local)&&local==D'2024.07.01 01:00',"composed_server_UTC_London");
   E2BrokerTimeAdapter different;
   Check(different.Initialize(base+"different_dst.profile","E2_TEST_ONLY",true,logger),"different_broker_DST_load");
   Check(different.London(D'2024.03.20 11:00',local)&&local==D'2024.03.20 08:00',"broker_DST_before_UK");
   Check(different.London(D'2024.10.30 11:00',local)&&local==D'2024.10.30 08:00',"broker_DST_after_UK");
   Check(!bad.Initialize(base+"unordered.profile","E2_TEST_ONLY",true,logger)&&bad.Failure()=="PROFILE_TRANSITIONS_UNORDERED_OR_INVALID","unordered_transitions_rejected");
   Check(fixed.ServerToUtc(D'2023.01.01',utc)&&utc==D'2023.01.01',"coverage_start_inclusive");
   Check(fixed.ServerToUtc(D'2024.12.31 23:59:59',utc),"coverage_last_second");
   int d1,d2;
   Check(trans.Day(D'2024.01.02 23:55',d1)&&trans.Day(D'2024.01.03 00:05',d2)&&d1==d2&&d1==20240102,"server_midnight_not_London_midnight");
   E2Config c;E2LoadConfiguration(c);E2LondonRange range;range.Initialize(c);
   datetime day=D'2024.01.02 00:00';E2TradeDirection direction;
   for(int i=0;i<95;i++)range.Observe(day+i*300,1.10,1.09);
   Check(!range.Frozen(),"not_frozen_before_last_range_close");
   range.Observe(day+95*300,1.10,1.09);
   Check(range.Frozen()&&range.Valid(),"freeze_at_0800_after_0755_close");
   range.Observe(day+8*3600,1.20,1.00);
   Check(range.High()==1.10&&range.Low()==1.09,"0800_bar_not_in_range");
   Check(!range.Signal(day+8*3600,1.10,direction),"strict_close_not_touch");
   Check(!range.Signal(day+8*3600,1.095,direction),"wick_only_no_signal");
   Check(range.Signal(day+8*3600,1.11,direction)&&direction==E2_DIRECTION_LONG,"long_continuation");
   Check(range.Signal(day+8*3600,1.08,direction)&&direction==E2_DIRECTION_SHORT,"short_continuation");
   Check(!range.Signal(day+12*3600,1.11,direction),"breakout_end_excluded");
   Check(!range.Signal(day+7*3600,1.11,direction),"before_breakout_excluded");
   range.Observe(day+86400,1.3,1.2);
   Check(!range.Frozen()&&range.Day()==20240103,"new_London_day_reset");
   range.Observe(day+86400+8*3600,1.4,1.1);
   Check(!range.Valid()&&!range.Signal(day+86400+8*3600,1.5,direction),"incomplete_range_rejected");
   // Replay at every possible range-building restart boundary, on winter and
   // summer weekdays and weekdays adjacent to the two UK transition weekends.
   datetime dates[]={D'2024.01.03',D'2024.07.03',D'2024.03.29',D'2024.04.01',D'2024.10.25',D'2024.10.28'};
   for(int dt=0;dt<ArraySize(dates);dt++)
   {
      for(int split=1;split<=96;split++)
      {
         E2LondonRange uninterrupted,restarted;uninterrupted.Initialize(c);restarted.Initialize(c);
         for(int i=0;i<split;i++)uninterrupted.Observe(dates[dt]+i*300,1.10+i*0.00001,1.09-i*0.00001);
         for(int i=0;i<split;i++)restarted.Observe(dates[dt]+i*300,1.10+i*0.00001,1.09-i*0.00001);
         Check(uninterrupted.StateFingerprint()==restarted.StateFingerprint(),"partial_range_restart_identical");
         for(int i=split;i<96;i++){uninterrupted.Observe(dates[dt]+i*300,1.10+i*0.00001,1.09-i*0.00001);restarted.Observe(dates[dt]+i*300,1.10+i*0.00001,1.09-i*0.00001);}
         Check(restarted.Valid()&&restarted.Frozen()&&restarted.High()==1.10095&&restarted.Low()==1.08905,"range_max_min_after_restart");
         string state=restarted.StateFingerprint();restarted.Observe(dates[dt]+12*3600,9,0.01);
         Check(state==restarted.StateFingerprint(),"frozen_range_immutable");
      }
   }
   // Hash smoke tests exercise the production serializer without emitting CSVs.
   c.csv_export_enabled=false;c.time_policy_digest=fixed.Digest();
   E2TradeReporter report;report.Initialize(c,"EURUSD",logger);string hash=report.ConfigHash();
   E2Config variant=c;variant.range_end+=5;report.Initialize(variant,"EURUSD",logger);Check(report.ConfigHash()!=hash,"range_config_hash");
   variant=c;variant.time_policy_digest=trans.Digest();report.Initialize(variant,"EURUSD",logger);Check(report.ConfigHash()!=hash,"time_profile_config_hash");
   variant=c;variant.stop_mode=ATR;report.Initialize(variant,"EURUSD",logger);Check(report.ConfigHash()!=hash,"stop_mode_hash");
   Print("[LRB_SELFTEST] checks=",checks,", failures=",failures,", testOnly=1, ordersSubmitted=0");
   return(failures==0?INIT_SUCCEEDED:INIT_FAILED);
}
void OnTick(){}
double OnTester(){return((double)failures);}
