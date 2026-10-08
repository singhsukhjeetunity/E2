int main() {
   // Verified configuration, unique magic and parameter rejection.
   assert(OnInit()==INIT_PARAMETERS_INCORRECT);
   InpBrokerClockVerified=true;assert(OnInit()==INIT_SUCCEEDED);
   assert(InpMagic>=420601&&InpMagic<=420605);
   InpRiskPercent=-1;assert(OnInit()==INIT_PARAMETERS_INCORRECT);InpRiskPercent=.25;
   // CSV ownership, partial fills/exits, fee accounting, restart rebuild and no overwrite.
   InpBrokerDST=RC_FIXED;InpBrokerWinterUTCMinutes=0;
   test_now=RCDate(2025,10,8,12);
   test_deals={
      {1,InpMagic,"TEST",test_now-120,DEAL_ENTRY_IN,DEAL_TYPE_BUY,77,.04,100,99,0,0,-1,0,-.2},
      {2,InpMagic,"TEST",test_now-119,DEAL_ENTRY_IN,DEAL_TYPE_BUY,77,.06,100,99,0,0,-1.5,0,-.3},
      {3,0,"TEST",test_now-60,DEAL_ENTRY_OUT,DEAL_TYPE_SELL,77,.04,101,0,0,40,-1,-2,-.2},
      {4,999,"TEST",test_now-90,DEAL_ENTRY_IN,DEAL_TYPE_BUY,88,.1,100,99,0,0,-3,0,0}
   };
   RCCaptureRisk(1);RCCaptureRisk(2);
   assert(RCExportTrades());assert(rc_records.size()==1);
   auto path=rc_report_base+"_Trades_T.csv";
   auto rows=mock_files[path];assert(rows.size()==2&&rows[1][10]=="OPEN"&&rows[1][8].empty());
   test_deals.push_back({5,0,"TEST",test_now,DEAL_ENTRY_OUT,DEAL_TYPE_SELL,77,.06,101,0,0,60,-1.5,-3,-.3});
   assert(RCExportTrades());rows=mock_files[path];
   assert(rows.size()==2&&rows[1][10]=="FINALIZED");
   assert(std::abs(std::stod(rows[1][8])-89)<1e-9); // 100 gross - 5 commissions - 5 swap - 1 fees.
   assert(std::abs(std::stod(rows[1][9])-100)<1e-9&&std::abs(std::stod(rows[1][19])-.89)<1e-9);
   rc_records.clear();assert(RCExportTrades());assert(mock_files[path]==rows); // Idempotent history recovery.
   rc_entry_risks.clear();test_deals[0].sl=0;assert(RCExportTrades());rows=mock_files[path];
   assert(rows[1][9].empty()&&rows[1][19].empty()&&rows[1][21]=="INITIAL_RISK_UNAVAILABLE");
   string oldbase=rc_report_base;assert(RCExportInit());assert(rc_report_base!=oldbase);
   assert(mock_files.count(oldbase+"_Trades_T.csv"));
   RCExportClose();mock_file_fail=true;assert(!RCExportInit());mock_file_fail=false;
   InpExportCsv=false;auto count=mock_files.size();assert(RCExportInit());assert(mock_files.size()==count);
   InpExportCsv=true;assert(RCExportInit());test_deals.clear();
   // DST transition instants and ambiguous historical broker timestamps.
   assert(!RCDST(RCDate(2025,3,9,6,59),RC_US));
   assert(RCDST(RCDate(2025,3,9,7),RC_US));
   assert(!RCDST(RCDate(2025,11,2,6),RC_US));
   assert(!RCDST(RCDate(2025,3,30,0,59),RC_EU));
   assert(RCDST(RCDate(2025,3,30,1),RC_EU));
   datetime u=0;
   assert(!RCUtc(RCDate(2025,10,26,3,30),RC_EU,120,u));
   for(int mode=0;mode<=2;mode++)for(int month=1;month<=12;month++) {
      datetime instant=RCDate(2025,month,15,12);
      assert(RCUtc(RCWall(instant,(RCClock)mode,120),(RCClock)mode,120,u)&&u==instant);
   }
   assert(RCListed("20251008|20251225",RCDate(2025,10,8)));
   assert(!RCListed("20251008",RCDate(2025,10,9)));
   // Saturday 5th and Sunday 10th roll to Friday; no bogus Monday roll.
   assert(RCGotobi(RCDate(2025,4,4)));
   assert(RCGotobi(RCDate(2025,8,8)));
   assert(!RCGotobi(RCDate(2025,8,9)));
   assert(!RCGotobi(RCDate(2025,8,11)));
   // Exact published daily IBS band rules, flat-range handling and reclaim direction.
   std::vector<RCBar> bars(30);
   for(int i=0;i<30;i++)bars[i]={i*86400,100,102,98,100,390};
   bars.back()={29*86400,100,100,94,95,390};
   assert(RCPullback(bars,30,10,25,1,.3));
   auto flat=bars.back();flat.high=flat.low=flat.close=100;assert(RCIBS(flat)==.5);
   auto below=bars[0],above=bars[1];below.close=97;above.close=99;
   assert(RCReclaim(below,above,98,102)==1);
   below.close=103;above.close=101;assert(RCReclaim(below,above,98,102)==-1);
   assert(RCGapDirection(103,98,102)==-1);
   assert(RCGapDirection(97,98,102)==1);
   assert(RCGapDirection(102,98,102)==0); // Touch is not a genuine gap.
   assert(!RCRegime(bars,5,5,10,.35,1.5,4));
   assert(RCVolume(1,1000,.01,100,.01)==0);
   assert(std::abs(RCVolume(105,1000,.01,100,.01)-.10)<1e-12);
   // Broker history survives process-local reset; foreign positions are untouched.
   InpBrokerDST=RC_FIXED;InpBrokerWinterUTCMinutes=0;
   InpSessionDST=RC_FIXED;InpSessionWinterUTCMinutes=0;
   InpCashRisk=100;InpOneEntryPerDay=true;InpFridayFlat=false;InpMaxSpreadPoints=30;
   datetime now=RCDate(2025,10,8,12);test_now=now;
   test_positions.push_back({9,999,"TEST",now,90,.01});
   test_mode=0;assert(!RCEnter(1,1,0,now)); // Netting ownership conflict.
   test_mode=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   assert(RCEnter(1,1,0,now));assert(test_positions.size()==2);
   assert(test_positions.back().stop>0&&test_positions.back().lots<=.10);
   RCCloseOwn();assert(test_positions.size()==1&&test_positions[0].magic==999);
   rc_last_minute=0;rc_last_bid=0;assert(!RCEnter(1,1,0,now)); // Durable daily limit.
   InpOneEntryPerDay=false;assert(!RCEnter(1,1,0,now,now)); // Unique signal/fix limit.
   test_now=now+86400;
   test_min_lot=1;assert(!RCEnter(1,1,0,test_now));test_min_lot=.01;
   test_tick.ask=101;assert(!RCEnter(1,1,0,test_now));test_tick.ask=100.02;
   // An orphan position with no protective SL must be closed, leaving foreign ticket.
   test_positions.push_back({123,InpMagic,"TEST",test_now,0,.01});
   RCManage(test_now);assert(test_positions.size()==1&&test_positions[0].magic==999);
   // Minute loader excludes today's unfinished reference session and stale history.
   test_positions.clear();test_deals.clear();test_minutes.clear();rc_cache_key=0;
   InpSessionOpenMinute=600;InpSessionCloseMinute=660;InpATRPeriod=3;
   InpMinimumMinuteCoverage=.8;InpClosedDates="";InpEarlyCloseDates="";
   datetime first=RCDate(2025,9,1);
   for(int day=0;day<40;day++) {
      datetime date=first+day*86400;if(!RCWeekday(date))continue;
      for(int minute=600;minute<660;minute++)
         test_minutes.push_back({date+minute*60,100,102,98,100});
   }
   datetime day=RCDate(2025,10,8);test_now=day+630*60;
   assert(RCRefreshDays(test_now));
   assert(RCDay(rc_days.back().start)==day-86400);
   test_now=day+660*60;assert(RCRefreshDays(test_now));
   assert(RCDay(rc_days.back().start)==day);
   // Missing latest full session blocks signals instead of using yesterday's older bars.
   test_minutes.erase(std::remove_if(test_minutes.begin(),test_minutes.end(),[&](auto r){return RCDay(r.time)==day;}),test_minutes.end());
   rc_cache_key=0;assert(!RCRefreshDays(test_now));assert(!rc_ready);
   // Incremental rebuild equals a fresh full-window rebuild across DST and year boundaries.
   InpBrokerDST=RC_EU;InpBrokerWinterUTCMinutes=120;
   InpSessionDST=RC_US;InpSessionWinterUTCMinutes=-300;
   InpSessionOpenMinute=570;InpSessionCloseMinute=960;
   test_minutes.clear();rc_cache_key=0;rc_ready=false;rc_count=0;rc_days.clear();
   datetime origin=RCDate(2024,11,1);
   for(int d=0;d<200;d++) {
      datetime date=origin+d*86400;if(!RCWeekday(date))continue;
      // Include a missing holiday session to exercise failure/recovery.
      if(date==RCDate(2024,12,25))continue;
      for(int m=570;m<960;m++) {
         datetime instant=0;assert(RCUtc(date+m*60,RC_US,-300,instant));
         double value=100+d*.01+(m-570)*.001;
         test_minutes.push_back({RCServer(instant),value,value+.5,value-.5,value+.1});
      }
   }
   long incremental_rows=0,full_rows=0;
   for(int d=35;d<190;d++) {
      datetime date=origin+d*86400;if(!RCWeekday(date))continue;
      datetime instant=0;assert(RCUtc(date+960*60,RC_US,-300,instant));test_now=RCServer(instant);
      long before=test_copied_minutes;bool ok=RCRefreshDays(instant);
      incremental_rows+=test_copied_minutes-before;
      auto cached=rc_days;int cached_key=rc_cache_key;
      rc_cache_key=0;before=test_copied_minutes;bool fresh=RCRefreshDays(instant);
      full_rows+=test_copied_minutes-before;
      assert(ok==fresh&&cached.size()==rc_days.size());
      for(size_t i=0;i<cached.size();i++) {
         assert(cached[i].start==rc_days[i].start&&cached[i].minutes==rc_days[i].minutes);
         assert(cached[i].open==rc_days[i].open&&cached[i].high==rc_days[i].high&&
                cached[i].low==rc_days[i].low&&cached[i].close==rc_days[i].close);
      }
      rc_days=cached;rc_count=(int)cached.size();rc_cache_key=cached_key;rc_ready=ok;
   }
   assert(incremental_rows*20<full_rows);
   std::cout<<"M1 rows copied: incremental="<<incremental_rows<<" full="<<full_rows<<"\n";
   InpBrokerDST=RC_FIXED;InpBrokerWinterUTCMinutes=0;
   InpSessionDST=RC_FIXED;InpSessionWinterUTCMinutes=0;
   // Exercise each complete strategy through its actual OnTick entry point.
   test_positions.clear();test_deals.clear();InpATRPeriod=3;InpStopATR=1;
   InpOneEntryPerDay=true;InpFridayFlat=false;InpMaximumHoldingDays=5;
   InpSessionOpenMinute=0;InpSessionCloseMinute=1320;
   test_now=RCDate(2025,10,8,12);rc_last_minute=test_now;
   rc_count=30;rc_days.resize(rc_count);
   for(int i=0;i<rc_count;i++)rc_days[i]={test_now-(rc_count-i)*86400,100,102,98,100,1320};
   rc_ready=true;rc_cache_key=RCDayKey(test_now)*2;
   test_tick={100,100.02};rc_last_bid=100;
#if RC_DEFAULT_MAGIC == 420603
   test_now=RCDate(2025,7,3,15,55);_Point=.001;_Digits=3;test_tick={160,160.01};
   OnTick();assert(test_positions.size()==1&&test_deals.back().type==DEAL_TYPE_BUY);
   test_now=RCDate(2025,7,4,0,55);rc_last_close_attempt=0;OnTick();
   assert(test_positions.empty());
#elif RC_DEFAULT_MAGIC == 420604
   test_m15.clear();rc_last_minute=0;
   for(int i=0;i<5;i++)test_m15.push_back({test_now-(5-i)*900,100,102,96,100});
   test_m15[3].close=97;test_m15[4].close=99;
   OnTick();assert(test_positions.size()==1&&test_deals.back().type==DEAL_TYPE_BUY);
   RCCloseOwn();OnTick();assert(test_positions.empty()); // Same bar cannot re-enter.
#elif RC_DEFAULT_MAGIC == 420605
   InpSessionOpenMinute=600;InpEntryWindowMinutes=180;
   rc_session_open=103;rc_open_day=RCDay(test_now);test_m30.clear();
   for(int i=0;i<5;i++)test_m30.push_back({test_now-(5-i)*1800,100,104,99,101});
   rc_last_bid=99.01;test_tick={98.99,99.01};
   OnTick();assert(test_positions.size()==1&&test_deals.back().type==DEAL_TYPE_SELL);
#endif
   std::cout<<RC_NAME<<": checks OK\n";
}
