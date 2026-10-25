int main() {
 auto reset=[&](){
   if(sm_ema!=INVALID_HANDLE)OnDeinit(0);
   mock_files.clear();mock_handles.clear();mock_read_cursor.clear();mock_file_fail=false;mock_move_fail=false;
   test_positions.clear();test_deals.clear();test_deal_orders.clear();test_active_orders.clear();test_order_history.clear();
   test_tester=1;test_sends=0;test_retcode=TRADE_RETCODE_DONE;test_send_ok=true;test_defer_fill=false;
   test_order_rejected=false;test_on_send=nullptr;test_history_ok=true;test_guard=true;
   InpTrailingMethod=E2_TRAIL_EMA;InpTrailingATRPeriod=14;InpTrailingATRMultiplier=2;test_atr=.5;test_atr_ok=true;test_atr_bars=120;test_atr_calls=0;
   test_modify_ok=true;test_modifies=0;test_ema=100;test_ema_bars=120;test_buffer_ok=true;test_indicator_ok=true;
   test_free=100000;test_balance=100000;test_min_lot=.01;test_mode=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   _Symbol="NAS100";_Point=.01;_Digits=2;
   InpExportCsv=false;InpCloseAtSessionEnd=true;InpSessionCloseNYHour=16;InpSessionCloseNYMinute=0;
   InpBrokerClockVerified=true;InpBrokerClock=NP_FIXED_UTC_OFFSET;
   InpServerUTCOffsetWinterHours=0;InpServerUTCOffsetSummerHours=0;
   InpRiskMode=SM_FIXED_CASH;InpFixedCashRisk=1000;InpMaxSpreadIndexPoints=10;
   test_now=NPDate(2026,10,19,13,35);test_tick={101,101.1,test_now};
   test_m30={{test_now-300,99,102,98,101}};
   sm_cached_bar=0;sm_cached_ema=0;sm_last_close_try=0;sm_last_modify_try=0;sm_block_log=0;
   g_reportBase="";g_signalFile=INVALID_HANDLE;g_equityFile=INVALID_HANDLE;g_equityMinute=0;
   assert(OnInit()==INIT_SUCCEEDED);
 };
 // Level close, not crossover or candle color; exact equality skips.
 assert(SMDirection(101,100)==1&&SMDirection(99,100)==-1&&SMDirection(100,100)==0);
 assert(SMDirection(0,100)==0&&SMDirection(100,NAN)==0);
 assert(SMStop(1,100.027,.01,2)==100.02&&SMStop(-1,100.027,.01,2)==100.03);
 assert(!SMTightens(1,100,99)&&!SMTightens(-1,100,101));
 // Winter/summer opening, DST mismatch weeks and exact completion/window bounds.
 assert(SMWindow(NPDate(2026,1,5,14,35),NPDate(2026,1,5,14,30)));
 assert(SMWindow(NPDate(2026,7,6,13,35),NPDate(2026,7,6,13,30)));
 assert(SMWindow(NPDate(2026,3,9,13,35),NPDate(2026,3,9,13,30)));
 assert(!SMWindow(NPDate(2026,7,6,13,34),NPDate(2026,7,6,13,30)));
 assert(!SMWindow(NPDate(2026,7,6,13,36),NPDate(2026,7,6,13,30)));
 assert(!SMWindow(NPDate(2026,7,4,13,35),NPDate(2026,7,4,13,30)));
 assert(!SMWindow(NPDate(2026,12,25,14,35),NPDate(2026,12,25,14,30)));
 datetime utc=0;
 assert(!NPProfileToUtc(NPDate(2026,10,25,3,30),NP_EU_SEASONAL,7200,10800,utc));
 // Real broker clock conversion, including US/EU mismatch.
 reset();InpBrokerClock=NP_EU_SEASONAL;InpServerUTCOffsetWinterHours=2;InpServerUTCOffsetSummerHours=3;
 assert(SMUtc(NPDate(2026,3,9,15,35),utc)&&utc==NPDate(2026,3,9,13,35));
 InpBrokerClock=NP_FIXED_UTC_OFFSET;InpServerUTCOffsetWinterHours=0;
 OnTick();assert(test_sends==1&&test_positions.size()==1&&test_positions[0].kind==0);
 assert(test_positions[0].target==0&&test_positions[0].stop==100&&sm_state.status==2);
 double loss=0;OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,test_positions[0].lots,101.1,100,loss);
 assert(-loss<=1000.01&&-loss>980);
 OnTick();assert(test_sends==1);test_positions.clear();test_deals.clear();
 OnTick();assert(test_sends==1); // Manual close + missing history still cannot reenter.
 reset();test_m30[0].close=99;test_tick={99,99.1,test_now};OnTick();
 assert(test_sends==1&&test_positions[0].kind==1&&test_positions[0].stop==100&&test_positions[0].target==0);
 reset();test_m30[0].close=100;OnTick();assert(test_sends==0);
 reset();test_now+=60;test_tick.time=test_now;OnTick();assert(test_sends==0);
 reset();OnTimer();assert(test_sends==0); // Timer must never place entries.
 reset();test_ema_bars=119;OnTick();assert(test_sends==0);
 reset();test_buffer_ok=false;OnTick();assert(test_sends==0);
 reset();test_guard=false;OnTick();assert(test_sends==0);
 reset();test_history_ok=false;OnTick();assert(test_sends==0);
 reset();InpBrokerClockVerified=false;OnTick();assert(test_sends==0);
 reset();test_tick.ask=120;OnTick();assert(test_sends==0);
 reset();test_tick.time-=20;OnTick();assert(test_sends==0);
 reset();test_tick={99,99.1,test_now};OnTick();assert(test_sends==0); // Buy signal, EMA above market.
 reset();test_free=0;OnTick();assert(test_sends==0);
 reset();InpFixedCashRisk=.001;OnTick();assert(test_sends==0); // Never round risk up to min lot.
 // Netting rejects foreign symbol exposure; hedging never modifies foreign positions.
 reset();test_mode=0;test_positions.push_back({800,123,_Symbol,test_now,90,1});OnTick();assert(test_sends==0);
 reset();test_positions.push_back({800,123,_Symbol,test_now,90,1});OnTick();assert(test_sends==1);
 assert(test_positions[0].stop==90);
 // Long ratchet and rejected modify retry; no loosening even if EMA falls.
 reset();OnTick();test_now+=300;test_tick={103,103.1,test_now};test_m30.push_back({test_now-300,101,104,100,103});
 test_ema=101;test_modify_ok=false;OnTick();assert(test_positions[0].stop==100);
 test_modify_ok=true;test_now++;test_tick.time=test_now;OnTick();assert(test_positions[0].stop==101&&test_modifies==1);
 test_ema=100.5;test_now++;test_tick.time=test_now;OnTick();assert(test_positions[0].stop==101);
 test_ema=104;test_now++;test_tick.time=test_now;OnTick();assert(test_positions.empty()); // Stop passed quote => market exit.
 reset();test_m30[0].close=99;test_tick={99,99.1,test_now};OnTick();
 test_now+=300;test_tick={97,97.1,test_now};test_m30.push_back({test_now-300,99,100,96,97});test_ema=99;
 OnTick();assert(test_positions[0].stop==99);
 test_ema=99.5;test_now++;test_tick.time=test_now;OnTick();assert(test_positions[0].stop==99);
 // Entry faults / guard lock cannot disable timed exits.
 reset();OnTick();sm_state_ready=false;test_guard=false;test_buffer_ok=false;
 test_now=NPDate(2026,10,19,20,0);test_tick={103,103.1,test_now};OnTimer();assert(test_positions.empty());
 reset();InpCloseAtSessionEnd=false;OnTick();test_buffer_ok=false;
 test_now=NPDate(2026,10,20,1,0);test_tick.time=test_now;OnTimer();assert(test_positions.size()==1);
 // Missed close recovered next day; early close calendar and custom time.
 assert(SMDeadline(NPDate(2026,11,27,14,35),960)==NPDate(2026,11,27,18,0));
 assert(SMDeadline(NPDate(2026,10,19,13,35),900)==NPDate(2026,10,19,19,0));
 InpCloseAtSessionEnd=true;OnTimer();assert(test_positions.empty());
 // Crash/restart durable reservation, duplicate instances and ambiguous midnight.
 reset();SMStateClose();test_tester=0;assert(SMStateInit());
 int owner=sm_lock;assert(!SMStateInit());sm_lock=owner;sm_state_ready=true;
 test_defer_fill=true;bool nested=false;test_on_send=[&](){SMAttempt(test_now);nested=test_sends>1;};
 OnTick();assert(test_sends==1&&!nested&&sm_state.status==1);
 SMStateClose();assert(SMStateInit());OnTick();assert(test_sends==1&&sm_state.status==1);
 test_now+=86400;test_tick.time=test_now;test_m30={{test_now-300,99,102,98,101}};OnTick();assert(test_sends==1);
 // Broker late partial fill consumes prior day, allowing only a genuinely new day.
 test_deals.push_back({1,InpMagic,_Symbol,sm_state.submitted,DEAL_ENTRY_IN,DEAL_TYPE_BUY,100,.1,101,100,0});
 test_deal_orders[1]=sm_state.order;SMReconcile(true);assert(sm_state.status==2);
 test_defer_fill=false;OnTick();assert(test_sends==2);
 // Fail-closed storage BEFORE broker send.
 reset();SMStateClose();test_tester=0;assert(SMStateInit());mock_move_fail=true;
 OnTick();assert(test_sends==0);mock_move_fail=false;OnTick();assert(test_sends==1);
 // Known rejection consumes one attempt; timeout remains unresolved across restart.
 reset();test_defer_fill=true;test_send_ok=false;test_retcode=10006;OnTick();OnTick();
 assert(test_sends==1&&sm_state.status==2);
 reset();test_defer_fill=true;test_send_ok=false;test_retcode=TRADE_RETCODE_TIMEOUT;OnTick();OnTick();
 assert(test_sends==1&&sm_state.status==1);
 // ATR selection changes trailing only: the opening signal/initial stop stay EMA12.
 reset();OnDeinit(0);InpTrailingMethod=E2_TRAIL_ATR;assert(OnInit()==INIT_SUCCEEDED&&sm_atr==2);
 assert(test_atr_calls==1);OnTick();assert(test_sends==1&&test_positions[0].stop==100);
 test_now+=300;test_tick={103,103.1,test_now};test_m30.push_back({test_now-300,101,104,100,103});
 test_atr=.5;OnTick();assert(test_positions[0].stop==102&&test_positions[0].target==0);
 test_atr=2;test_now++;test_tick.time=test_now;OnTick();assert(test_positions[0].stop==102);
 test_atr_bars=0;test_now++;test_tick.time=test_now;OnTick();assert(test_positions[0].stop==102);
 int released=test_releases;OnDeinit(0);assert(sm_ema==INVALID_HANDLE&&sm_atr==INVALID_HANDLE&&test_releases==released+2);
 reset();OnDeinit(0);InpTrailingMethod=E2_TRAIL_ATR;assert(OnInit()==INIT_SUCCEEDED);
 test_m30[0].close=99;test_tick={99,99.1,test_now};OnTick();assert(test_positions[0].stop==100);
 test_now+=300;test_tick={97,97.1,test_now};test_m30.push_back({test_now-300,99,100,96,97});
 test_atr=.5;OnTick();assert(test_positions[0].stop==98);
 test_atr=0;test_now++;test_tick.time=test_now;OnTick();assert(test_positions[0].stop==98);
 reset();OnDeinit(0);InpTrailingMethod=E2_TRAIL_ATR;test_atr_ok=false;
 assert(OnInit()==INIT_FAILED&&sm_ema==INVALID_HANDLE&&sm_atr==INVALID_HANDLE);
 reset();OnDeinit(0);InpTrailingMethod=E2_TRAIL_ATR;InpTrailingATRMultiplier=0;
 assert(OnInit()==INIT_PARAMETERS_INCORRECT);
 // Actual research exporter supports no TP and initial stop risk for both sides.
 reset();InpExportCsv=true;assert(SMOpenReports());OnTick();
 test_positions.clear();test_now+=60;
 test_deals.push_back({2,0,_Symbol,test_now,DEAL_ENTRY_OUT,DEAL_TYPE_SELL,100,
    test_deals[0].volume,102,0,0,100,-2,0,-1,DEAL_REASON_EXPERT});
 SMExportTrades();
 auto rows=mock_files[g_reportBase+"_Trades_T.csv"];
 assert(rows.size()==2&&rows[1][10]=="FINALIZED"&&rows[1][25]=="-1.00000000");
 assert(rows[1][9]!=""&&rows[1][19]!=""&&rows[1][18].empty());
 OnDeinit(0);
 std::cout<<"Session Momentum complete source: bidirectional opening signal, DST, stops, risk, guard, exits, duplicate/restart protection and zero-TP reports passed\n";
}
