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
   Check(!bad.Initialize("","E2_TEST_ONLY",true,99,logger),"missing_tester_profile_rejected");
   Check(fixed.Initialize(base+"fixed.profile","E2_TEST_ONLY",true,logger),"fixed_load");
   Check(trans.Initialize(base+"transitions.profile","E2_TEST_ONLY",true,logger),"transitions_load");
   E2BrokerTimeAdapter mqresearch;
   Check(mqresearch.Initialize(base+"metaquotes_demo_eurusd_us_dst_2020_2026_research.profile","MetaQuotes-Demo",true,logger),"MetaQuotes_research_profile_load");
   Check(!mqresearch.Authoritative()&&mqresearch.Mode()=="UTC_TRANSITIONS","MetaQuotes_research_profile_nonauthoritative");
   Check(mqresearch.ServerToUtc(D'2024.03.10 08:59:59',utc)&&utc==D'2024.03.10 06:59:59',"MetaQuotes_2024_US_DST_pre_start");
   Check(mqresearch.ServerToUtc(D'2024.03.10 10:00:00',utc)&&utc==D'2024.03.10 07:00:00',"MetaQuotes_2024_US_DST_post_start");
   Check(!mqresearch.ServerToUtc(D'2024.03.10 09:30:00',utc),"MetaQuotes_2024_US_DST_spring_gap_rejected");
   datetime server_boundary;
   Check(mqresearch.UtcToServer(D'2024.11.03 05:59:59',server_boundary)&&server_boundary==D'2024.11.03 08:59:59',"MetaQuotes_2024_US_DST_pre_end");
   Check(mqresearch.ServerToUtc(D'2024.11.03 08:00:00',utc)==false,"MetaQuotes_2024_US_DST_overlap_rejected");
   Check(mqresearch.ServerToUtc(D'2024.11.03 09:00:00',utc)&&utc==D'2024.11.03 07:00:00',"MetaQuotes_2024_US_DST_post_end");
   Check(fixed.Digest()!=trans.Digest(),"policy_digest_sensitive");
   E2BrokerTimeAdapter assumed,assumed2,conflict;
   Check(assumed.Initialize("","MetaQuotes-Demo",true,2,logger)&&!assumed.Authoritative()&&assumed.Mode()=="TESTER_ASSUMED_FIXED_OFFSET","tester_assumed_offset");
   Check(StringFind(assumed.Digest(),"NONAUTHORITATIVE_ASSUMED_2H_")==0,"assumed_digest_label");
   Check(assumed2.Initialize("","MetaQuotes-Demo",true,3,logger)&&assumed2.Digest()!=assumed.Digest(),"assumed_offset_hash_sensitive");
   Check(!conflict.Initialize(base+"fixed.profile","E2_TEST_ONLY",true,2,logger),"profile_assumption_conflict_rejected");
   E2BrokerTimeAdapter builtin,builtin_bad_server,builtin_bad_symbol,builtin_assumed,explicit_override;
   Check(builtin.Initialize("","MetaQuotes-Demo","EURUSD",true,99,logger)&&!builtin.Authoritative(),"MetaQuotes_builtin_exact_match");
   Check(builtin.Digest()==mqresearch.Digest(),"MetaQuotes_builtin_external_digest_equivalence");
   Check(StringFind(builtin.Description(),"TESTER_BUILTIN_PROFILE|")==0,"MetaQuotes_builtin_mode");
   Check(!builtin_bad_server.Initialize("","Other-Demo","EURUSD",true,99,logger),"MetaQuotes_builtin_other_server_rejected");
   Check(!builtin_bad_symbol.Initialize("","MetaQuotes-Demo","GBPUSD",true,99,logger),"MetaQuotes_builtin_other_symbol_rejected");
   Check(builtin_assumed.Initialize("","MetaQuotes-Demo","EURUSD",true,2,logger)&&builtin_assumed.Mode()=="TESTER_ASSUMED_FIXED_OFFSET","MetaQuotes_explicit_assumed_precedes_builtin");
   Check(explicit_override.Initialize(base+"metaquotes_demo_eurusd_us_dst_2020_2026_research.profile","MetaQuotes-Demo","EURUSD",true,99,logger)&&StringFind(explicit_override.Description(),"TESTER_PROFILE|")==0,"MetaQuotes_explicit_profile_precedes_builtin");
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
   E2BrokerTimeAdapter live;datetime live_local,live_utc;
   Check(live.InitializeLiveObservedForTest("SYNTHETIC_LIVE",D'2024.01.15 14:00',D'2024.01.15 12:00',logger)&&live.Mode()=="LIVE_AUTO"&&live.CurrentOffset()==7200,"live_winter_offset");
   Check(live.GetLondonDateTime(D'2024.01.15 14:00',live_local)&&live_local==D'2024.01.15 12:00',"live_winter_London");
   Check(live.GetLondonDateTime(D'2024.07.15 14:00',live_local)&&live_local==D'2024.07.15 13:00',"live_summer_London");
   int revision=live.Revision();
   Check(live.ObserveLiveForTest(D'2024.03.10 04:00',D'2024.03.10 01:00')&&live.CurrentOffset()==10800&&live.Revision()==revision+1,"broker_change_independent_of_London");
   Check(live.ServerToUtc(D'2024.03.10 04:30',live_utc)&&live_utc==D'2024.03.10 01:30',"post_change_mapping");
   Check(!live.ObserveLiveForTest(D'2024.03.10 20:01',D'2024.03.10 01:00')&&!live.Ready(),"invalid_live_offset_blocks");
   Check(live.ObserveLiveForTest(D'2024.03.10 04:01',D'2024.03.10 01:01')&&live.Ready()&&live.Revision()==revision+1,"live_offset_recovers_atomically");
   E2BrokerTimeAdapter midnight;
   Check(midnight.InitializeLiveObservedForTest("SYNTHETIC_LIVE",D'2024.01.02 23:30',D'2024.01.02 21:30',logger),"midnight_live_init");
   int london_before,london_after;
   Check(midnight.Day(D'2024.01.02 23:30',london_before)&&midnight.ObserveLiveForTest(D'2024.01.03 01:30',D'2024.01.02 22:30')&&midnight.Day(D'2024.01.03 01:30',london_after)&&london_before==london_after,"offset_change_near_London_midnight_continuity");
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
   Check(E2TradeDirectionAllowed(BOTH,E2_DIRECTION_LONG)&&E2TradeDirectionAllowed(BOTH,E2_DIRECTION_SHORT),"direction_BOTH_allows_both");
   Check(E2TradeDirectionAllowed(LONG_ONLY,E2_DIRECTION_LONG)&&!E2TradeDirectionAllowed(LONG_ONLY,E2_DIRECTION_SHORT),"direction_LONG_ONLY_gate_before_planner");
   Check(E2TradeDirectionAllowed(SHORT_ONLY,E2_DIRECTION_SHORT)&&!E2TradeDirectionAllowed(SHORT_ONLY,E2_DIRECTION_LONG),"direction_SHORT_ONLY_gate_before_planner");
   Check(E2RangeWidthFilterPass(false,ATR_NORMALIZED,0.0,0.0,1.5,2.0),"range_filter_disabled_preserves_baseline");
   Check(!E2RangeWidthFilterPass(true,ATR_NORMALIZED,0.0,1.499999,1.5,2.0),"range_bucket_lower_reject");
   Check(E2RangeWidthFilterPass(true,ATR_NORMALIZED,0.0,1.5,1.5,2.0),"range_bucket_1_5_in_second_bucket");
   Check(!E2RangeWidthFilterPass(true,ATR_NORMALIZED,0.0,2.0,1.5,2.0),"range_bucket_upper_exclusive");
   E2Config filtered_config=c;filtered_config.range_width_filter_enabled=true;filtered_config.range_width_filter_mode=ATR_NORMALIZED;filtered_config.min_range_width=1.5;filtered_config.max_range_width=2.0;
   E2LondonRange filtered_before,filtered_after;filtered_before.Initialize(filtered_config);filtered_after.Initialize(filtered_config);
   for(int i=0;i<96;i++){double hi=1.10000,lo=1.09840;filtered_before.Observe(day+i*300,hi,lo,0.0001,0.0010);filtered_after.Observe(day+i*300,hi,lo,0.0001,0.0010);}
   Check(filtered_before.Frozen()&&MathAbs(filtered_before.AtrReference()-0.0010)<1e-10&&MathAbs(filtered_before.WidthAtr()-1.6)<1e-10&&filtered_before.FilterPass(),"range_metric_frozen_completed_H1_ATR_reference");
   Check(filtered_before.StateFingerprint()==filtered_after.StateFingerprint(),"range_filter_restart_state_identical");
   E2TradeDirection filtered_direction;Check(filtered_before.Signal(day+8*3600,1.101,filtered_direction)&&filtered_direction==E2_DIRECTION_LONG,"range_filter_pass_allows_signal");
   filtered_config.min_range_width=2.0;filtered_config.max_range_width=2.5;E2LondonRange filtered_reject;filtered_reject.Initialize(filtered_config);
   for(int i=0;i<96;i++)filtered_reject.Observe(day+i*300,1.10000,1.09840,0.0001,0.0010);
   Check(!filtered_reject.FilterPass()&&!filtered_reject.Signal(day+8*3600,1.101,filtered_direction),"range_filter_rejected_day_emits_no_candidate_before_daily_lock");
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
   E2Config opposite_stop=c;opposite_stop.stop_mode=OPPOSITE_RANGE;report.Initialize(opposite_stop,"EURUSD",logger);string opposite_stop_hash=report.ConfigHash();
   E2Config atr_stop=c;atr_stop.stop_mode=ATR;report.Initialize(atr_stop,"EURUSD",logger);string atr_stop_hash=report.ConfigHash();
   Check(opposite_stop_hash!=atr_stop_hash,"stop_mode_hash");
   E2Config both_direction=c;both_direction.trade_direction=BOTH;report.Initialize(both_direction,"EURUSD",logger);string both_direction_hash=report.ConfigHash();
   E2Config long_direction=c;long_direction.trade_direction=LONG_ONLY;report.Initialize(long_direction,"EURUSD",logger);string long_direction_hash=report.ConfigHash();
   E2Config short_direction=c;short_direction.trade_direction=SHORT_ONLY;report.Initialize(short_direction,"EURUSD",logger);string short_direction_hash=report.ConfigHash();
   Check(both_direction_hash!=long_direction_hash&&both_direction_hash!=short_direction_hash&&long_direction_hash!=short_direction_hash,"trade_direction_hashes_distinct");
   E2Config range_filter_variant=c;range_filter_variant.range_width_filter_enabled=!c.range_width_filter_enabled;report.Initialize(range_filter_variant,"EURUSD",logger);Check(report.ConfigHash()!=hash,"range_filter_enabled_hash");
   range_filter_variant=c;range_filter_variant.range_width_filter_mode=(c.range_width_filter_mode==PIPS?ATR_NORMALIZED:PIPS);report.Initialize(range_filter_variant,"EURUSD",logger);Check(report.ConfigHash()!=hash,"range_filter_mode_hash");
   range_filter_variant=c;range_filter_variant.min_range_width+=0.5;report.Initialize(range_filter_variant,"EURUSD",logger);Check(report.ConfigHash()!=hash,"range_filter_min_hash");
   range_filter_variant=c;range_filter_variant.max_range_width-=0.5;report.Initialize(range_filter_variant,"EURUSD",logger);Check(report.ConfigHash()!=hash,"range_filter_max_hash");
   variant=c;variant.time_policy_digest=assumed.Digest();variant.time_policy_description=assumed.Description();report.Initialize(variant,"EURUSD",logger);Check(report.ConfigHash()!=hash,"assumed_offset_config_hash");
   Print("[LRB_SELFTEST] checks=",checks,", failures=",failures,", testOnly=1, ordersSubmitted=0");
   return(failures==0?INIT_SUCCEEDED:INIT_FAILED);
}
void OnTick(){}
double OnTester(){return((double)failures);}
