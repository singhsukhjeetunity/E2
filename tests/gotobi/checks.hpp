int main(int argc,char **argv) {
   // Verified configuration, unique magic and parameter rejection.
   assert(OnInit()==INIT_PARAMETERS_INCORRECT);
   InpBrokerClockVerified=true;assert(OnInit()==INIT_SUCCEEDED);
   assert(InpMagic>=420601&&InpMagic<=420605);
   InpFixedCashRisk=0;assert(OnInit()==INIT_PARAMETERS_INCORRECT);InpFixedCashRisk=1000;
   InpBalanceRiskPercent=0;assert(OnInit()==INIT_SUCCEEDED); // Inactive percent does not disable cash mode.
   InpRiskMode=E2_RISK_BALANCE_PERCENT;assert(OnInit()==INIT_PARAMETERS_INCORRECT);
   InpBalanceRiskPercent=.23;InpFixedCashRisk=0;assert(OnInit()==INIT_SUCCEEDED);
   InpRiskMode=(E2RiskMode)2;assert(OnInit()==INIT_PARAMETERS_INCORRECT);
   InpRiskMode=E2_RISK_FIXED_CASH;InpFixedCashRisk=1000;
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
   if(argc>1) {
      std::ofstream ledger(argv[1]);
      for(const auto &row:rows) {
         for(size_t i=0;i<row.size();i++) {
            if(i)ledger<<',';
            ledger<<'"';
            for(char c:row[i]){if(c=='"')ledger<<'"';ledger<<c;}
            ledger<<'"';
         }
         ledger<<'\n';
      }
      assert(ledger.good());
   }
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
   InpRiskMode=E2_RISK_FIXED_CASH;InpFixedCashRisk=100;InpOneEntryPerDay=true;InpFridayFlat=false;InpMaxSpreadPoints=30;
   InpBalanceRiskPercent=99;test_balance=200000; // Cash sizing ignores the inactive percent and account balance.
   datetime now=RCDate(2025,10,8,12);test_now=now;
   test_positions.push_back({9,999,"TEST",now,90,.01});
   test_mode=0;assert(!RCEnter(1,1,0,now)); // Netting ownership conflict.
   test_mode=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   assert(RCEnter(1,1,0,now));assert(test_positions.size()==2);
   assert(test_positions.back().stop>0&&test_positions.back().lots<=.10);
   assert(test_positions.back().lots>=.09);
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
   assert(RCEInit()); // Independent historical fixture / fresh tester run.
   test_positions.clear();test_deals.clear();InpATRPeriod=3;InpStopATR=1;
   InpOneEntryPerDay=true;InpFridayFlat=false;InpMaximumHoldingDays=5;
   InpSessionOpenMinute=0;InpSessionCloseMinute=1320;
   test_now=RCDate(2025,10,8,12);rc_last_minute=test_now;
   rc_count=30;rc_days.resize(rc_count);
   for(int i=0;i<rc_count;i++)rc_days[i]={test_now-(rc_count-i)*86400,100,102,98,100,1320};
   rc_ready=true;rc_cache_key=RCDayKey(test_now)*2;
   test_tick={100,100.02};rc_last_bid=100;
   test_now=RCDate(2025,7,3,15,55);_Point=.001;_Digits=3;test_tick={160,160.01};
   InpRiskMode=E2_RISK_BALANCE_PERCENT;InpFixedCashRisk=9999;InpBalanceRiskPercent=.23;
   test_balance=100000;test_cash=50000; // Percentage follows balance, not floating equity or inactive cash input.
   OnTick();assert(test_positions.size()==1&&test_deals.back().type==DEAL_TYPE_BUY);
   auto live_entry=test_positions.back();
   double planned_loss=1000*live_entry.lots*(test_tick.ask-live_entry.stop);
   assert(planned_loss<=230+1e-8&&planned_loss>=225-1e-8); // Lot rounding stays within percentage budget.
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   assert(test_tick.ask-live_entry.stop>=.50-1e-8&&test_tick.ask-live_entry.stop<=.50+tick_size+1e-8);
   // Existing execution computes target from rounded stop distance (4R), then rounds target outward.
   assert(live_entry.target-test_tick.ask>=2.00-1e-8&&live_entry.target-test_tick.ask<=2.00+5*tick_size+1e-8);
   test_now=RCDate(2025,7,4,0,55);rc_last_close_attempt=0;OnTick();
   assert(test_positions.empty());

   // Predeclared timing variants: no early entry, one successful entry at the configured time.
   for(int entry_minute:{940,970}) {
      assert(RCEInit()); // Each timing variant is a separate tester run.
      InpEntryUTCMinute=entry_minute;assert(RCValidate());
      test_deals.clear();test_positions.clear();
      test_now=RCDate(2025,7,3)+entry_minute*60-1;OnTick();assert(test_positions.empty());
      test_balance=200000;
      test_now++;OnTick();assert(test_positions.size()==1);
      auto scaled=test_positions.back();
      double scaled_loss=1000*scaled.lots*(test_tick.ask-scaled.stop);
      assert(scaled_loss<=460+1e-8&&scaled_loss>=454-1e-8);
      RCCloseOwn();OnTick();assert(test_positions.empty()); // Signal cannot re-enter.
   }
   InpEntryUTCMinute=1440;assert(!RCValidate());InpEntryUTCMinute=955;
   // Live entry-reservation fixtures. Persisted files survive the memory resets.
   auto fresh_entry_case=[&](){
      RCEClose();test_tester=0;mock_file_fail=false;mock_move_fail=false;
      mock_files.clear();mock_handles.clear();mock_read_cursor.clear();
      test_positions.clear();test_deals.clear();test_deal_orders.clear();
      test_active_orders.clear();test_order_history.clear();test_on_send=nullptr;
      test_history_ok=true;test_defer_fill=false;test_send_ok=true;test_order_rejected=false;
      test_retcode=TRADE_RETCODE_DONE;test_sends=0;test_next_order=1000;test_login=42;test_server="Broker";
      _Symbol="EURJPY";_Point=.001;_Digits=3;test_tick={177.65,177.66};
      InpBrokerDST=RC_FIXED;InpBrokerWinterUTCMinutes=0;InpBrokerSummerUTCMinutes=0;
      InpSessionDST=RC_FIXED;InpSessionWinterUTCMinutes=0;
      InpRiskMode=E2_RISK_FIXED_CASH;InpFixedCashRisk=420;InpOneEntryPerDay=true;
      InpFridayFlat=false;InpMaxSpreadPoints=30;test_min_lot=.01;
      test_now=RCDate(2026,10,19,15,55);rc_trade.SetExpertMagicNumber(InpMagic);
      assert(RCEInit());
   };
   auto enter_event=[&](){return RCEnter(1,.5,4,RCNow(),RCDate(2026,10,19,15,55));};
   fresh_entry_case();
   int owner=rc_entry_lock;string owner_base=rc_entry_base;assert(owner!=INVALID_HANDLE);
   assert(!RCEInit()); // Second chart/terminal sharing Common Files is rejected.
   rc_entry_lock=owner;rc_entry_base=owner_base;rc_entry_ready=true;
   // Reentrant/concurrent attempt while the first broker request is in flight.
   test_defer_fill=true;bool nested=false;
   test_on_send=[&](){nested=enter_event();};
   assert(enter_event());assert(!nested&&test_sends==1&&rc_entry_state.status==1);
   assert(!enter_event()&&test_sends==1);
   RCEClose();assert(RCEInit());assert(!enter_event()&&test_sends==1); // Same pending order after restart.
   test_now+=86400;assert(!enter_event()&&test_sends==1); // Midnight never releases ambiguity.
   // An unconfirmed TIMEOUT with no cached fill cannot generate a second request.
   fresh_entry_case();test_defer_fill=true;test_send_ok=false;test_retcode=TRADE_RETCODE_TIMEOUT;
   assert(!enter_event()&&test_sends==1&&rc_entry_state.status==1);
   test_history_ok=false;test_now++;assert(!enter_event()&&test_sends==1);
   test_history_ok=true;RCEClose();assert(RCEInit());assert(!enter_event()&&test_sends==1);
   // Late partial fill proves the entry, even if its position has already closed.
   ulong order=rc_entry_state.order;
   test_deals.push_back({1,InpMagic,_Symbol,test_now,DEAL_ENTRY_IN,DEAL_TYPE_BUY,800,.1,177.66,177.16,179.66});
   test_deal_orders[1]=order;assert(RCEReconcile(true)&&rc_entry_state.status==2);
   test_deals.clear();test_deal_orders.clear();InpOneEntryPerDay=false;
   RCEClose();assert(RCEInit());assert(!enter_event()&&test_sends==1); // Durable consumed-event marker.
   // Fresh UTC date after a confirmed fill may submit its own new event.
   test_now+=86400;test_retcode=TRADE_RETCODE_DONE;test_send_ok=true;test_defer_fill=false;
   assert(RCEnter(1,.5,4,RCNow(),RCNow())&&test_sends==2);
   // Definite broker rejection is zero-fill evidence and permits a safe retry.
   fresh_entry_case();test_send_ok=false;test_retcode=10006;
   assert(!enter_event()&&test_sends==1&&rc_entry_state.status==0);
   test_send_ok=true;test_retcode=TRADE_RETCODE_DONE;
   assert(enter_event()&&test_sends==2&&rc_entry_state.status==2);
   // Accepted PLACED: canceled with full unfilled volume unlocks; partial fills do not.
   fresh_entry_case();test_defer_fill=true;test_retcode=TRADE_RETCODE_PLACED;
   assert(!enter_event()&&rc_entry_state.status==1);
   order=rc_entry_state.order;
   test_order_history.push_back({order,InpMagic,_Symbol,ORDER_STATE_CANCELED,.1,.05});
   assert(!RCEReconcile(true)&&rc_entry_state.status==1);
   test_order_history.back().remaining=.1;
   assert(RCEReconcile(true)&&rc_entry_state.status==0);
   // Storage failure before submission: no Buy/Sell; restoring storage allows retry.
   fresh_entry_case();mock_file_fail=true;assert(!enter_event()&&test_sends==0);
   mock_file_fail=false;mock_move_fail=true;assert(!enter_event()&&test_sends==0);
   mock_move_fail=false;assert(enter_event()&&test_sends==1);
   // Lost post-send state writes recover the pre-send reservation and broker fill.
   fresh_entry_case();test_on_send=[&](){mock_move_fail=true;};
   assert(enter_event()&&test_sends==1&&rc_entry_state.status==1);
   RCCloseOwn();mock_move_fail=false;RCEClose();assert(RCEInit());
   assert(RCEReconcile(true)&&rc_entry_state.status==2);assert(!enter_event()&&test_sends==1);
   // Active pending orders and corrupt state cannot open another position.
   fresh_entry_case();test_active_orders.push_back({900,InpMagic,_Symbol,ORDER_STATE_PLACED,.1,.1});
   assert(!enter_event()&&test_sends==0);test_active_orders.clear();
   string state_path=rc_entry_base+".state";RCEClose();mock_files[state_path]={{"CORRUPT"}};
   assert(RCEInit()&&!rc_entry_ready);assert(!enter_event()&&test_sends==0);
   test_positions.push_back({800,InpMagic,_Symbol,test_now,0,.1});rc_last_close_attempt=0;
   RCManage(RCNow());assert(test_positions.empty()); // Entry fault never disables exits.
   // Independent accounts / magic mappings do not share a lock or consumed slot.
   fresh_entry_case();owner=rc_entry_lock;owner_base=rc_entry_base;
   test_login=43;assert(RCEInit()&&rc_entry_base!=owner_base);RCEClose();
   rc_entry_lock=owner;rc_entry_base=owner_base;rc_entry_ready=true;RCEClose();
   // Strategy Tester has no shared disk state; each run starts clean.
   test_tester=1;size_t disk_count=mock_files.size();assert(RCEInit());
   assert(rc_entry_state.status==0&&rc_entry_lock==INVALID_HANDLE&&mock_files.size()==disk_count);
   std::cout<<"Gotobi duplicate entry: exclusive writer, pre-send persistence, delayed fills, timeouts, restart, rollover, zero-fill rejection and independent exits passed\n";
   std::cout<<RC_NAME<<": checks OK\n";
}
