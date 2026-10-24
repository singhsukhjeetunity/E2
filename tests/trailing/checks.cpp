#include "platform.hpp"
int main(){
 auto reset=[](){
  E2TrailShutdown();positions.clear();requests.clear();closes.clear();
  InpUseEMATrailingStop=true;InpTrailingEMAPeriod=12;InpTrailingTimeframe=PERIOD_M5;
  indicator_ok=true;rates_ok=true;buffer_ok=true;bars_calculated=200;
  send_ok=true;send_code=TRADE_RETCODE_DONE;close_ok=true;tick_size=.01;
  stop_level=0;freeze_level=0;now=1800000000;bar_time=now-300;value=100;
  quote={110,110.1,now};indicator_calls=0;_Period=PERIOD_M5;
  assert(E2TrailInit(420611));
 };
 // OFF path never creates an indicator, fetches data, trades or changes hashes.
 reset();E2TrailShutdown();indicator_calls=0;InpUseEMATrailingStop=false;
 InpTrailingEMAPeriod=-1;assert(E2TrailInit(420611)&&indicator_calls==0&&E2TrailDigest()=="");
 positions={{1,420611,_Symbol,POSITION_TYPE_BUY,90,120}};E2TrailRun();
 assert(requests.empty()&&closes.empty()&&positions[0].sl==90);
 // Enabled host magic scopes: original target and initial risk reference remain untouched.
 const ulong magics[]={2026001,2026091703,420603,420605,420609};
 for(auto magic:magics){
  reset();assert(E2TrailInit(magic));
  positions={{1,magic,_Symbol,POSITION_TYPE_BUY,90,120},{2,magic+1,_Symbol,POSITION_TYPE_BUY,80,130},
             {3,magic,"FOREIGN",POSITION_TYPE_BUY,70,140}};
  E2TrailRun();assert(requests.size()==1&&requests[0].position==1);
  assert(positions[0].sl==100&&positions[0].tp==120&&positions[1].sl==80&&positions[2].sl==70);
  value=99;now++;quote.time=now;E2TrailRun();assert(requests.size()==1&&positions[0].sl==100);
  // Restart: the live broker stop is the ratchet floor; it never resets to initial SL.
  E2TrailShutdown();assert(E2TrailInit(magic));now++;quote.time=now;E2TrailRun();
  assert(positions[0].sl==100&&requests.size()==1);
 }
 reset();positions={{1,420611,_Symbol,POSITION_TYPE_SELL,120,80}};
 quote={90,90.1,now};value=100.022;E2TrailRun();assert(positions[0].sl==100.03&&positions[0].tp==80);
 value=101;now++;quote.time=now;E2TrailRun();assert(requests.size()==1);
 value=99.002;now++;quote.time=now;E2TrailRun();assert(positions[0].sl==99.01);
 // Profit already beyond EMA: market close is delegated to host lifecycle; retry safely.
 reset();positions={{1,420611,_Symbol,POSITION_TYPE_BUY,90,120}};value=111;close_ok=false;
 E2TrailRun();assert(closes.size()==1&&requests.empty()&&positions.size()==1);
 E2TrailRun();assert(closes.size()==1);
 now+=5;quote.time=now;close_ok=true;E2TrailRun();assert(closes.size()==2&&positions.empty());
 reset();positions={{1,420611,_Symbol,POSITION_TYPE_SELL,120,80}};quote={90,90.1,now};value=89;
 E2TrailRun();assert(positions.empty()&&closes.size()==1);
 // No loosening, even when EMA/price are beyond an already tighter broker stop.
 reset();positions={{1,420611,_Symbol,POSITION_TYPE_BUY,105,120}};value=100;quote={99,99.1,now};
 E2TrailRun();assert(requests.empty()&&closes.empty()&&positions[0].sl==105);
 // Stops/freeze constraints hold existing SL, then retry on later valid quotes.
 reset();positions={{1,420611,_Symbol,POSITION_TYPE_BUY,90,0}};value=109.9;freeze_level=20;
 E2TrailRun();assert(requests.empty()&&positions[0].sl==90);
 freeze_level=0;now++;quote.time=now;E2TrailRun();assert(positions[0].sl==109.9&&positions[0].tp==0);
 reset();positions={{1,420611,_Symbol,POSITION_TYPE_BUY,90,120}};send_ok=false;
 E2TrailRun();assert(requests.size()==1&&positions[0].sl==90);
 E2TrailRun();assert(requests.size()==1);
 now++;quote.time=now;send_ok=true;E2TrailRun();assert(requests.size()==2&&positions[0].sl==100);
 // Missing/unready/forming/stale data cannot alter protection.
 for(int scenario=0;scenario<7;scenario++){
  reset();positions={{1,420611,_Symbol,POSITION_TYPE_BUY,90,120}};
  if(scenario==0)buffer_ok=false;
  if(scenario==1)rates_ok=false;
  if(scenario==2)bars_calculated=12;
  if(scenario==3)bar_time=now;
  if(scenario==4)bar_time=now-600;
  if(scenario==5)value=NAN;
  if(scenario==6)quote.time=now-16;
  E2TrailRun();assert(requests.empty()&&closes.empty()&&positions[0].sl==90);
 }
 // Period/timeframe inputs, invalid values and release lifecycle.
 reset();InpTrailingEMAPeriod=20;InpTrailingTimeframe=PERIOD_CURRENT;_Period=PERIOD_H1;
 assert(E2TrailInit(420611)&&last_period==20&&last_tf==PERIOD_H1);
 assert(E2TrailDigest().find("trail_timeframe=60")!=string::npos);
 E2TrailShutdown();assert(e2trail_handle==INVALID_HANDLE);
 InpTrailingEMAPeriod=0;assert(!E2TrailInit(420611));InpTrailingEMAPeriod=1001;assert(!E2TrailInit(420611));
 InpTrailingEMAPeriod=12;indicator_ok=false;assert(!E2TrailInit(420611));
 // Gold/Compression recovery accept tighter stops ONLY while enabled, never wider/missing.
 reset();assert(E2TrailStopOK(1,90,100,.005)&&E2TrailStopOK(-1,110,100,.005));
 assert(!E2TrailStopOK(1,90,80,.005)&&!E2TrailStopOK(-1,110,120,.005)&&!E2TrailStopOK(1,90,0,.005));
 InpUseEMATrailingStop=false;assert(!E2TrailStopOK(1,90,100,.005)&&E2TrailStopOK(1,90,90,.005));
 E2TrailShutdown();
 std::cout<<"EMA overlay: five strategy scopes, both sides, disabled baseline, TP preservation, ratchet/restart, completed bars, quote/freeze/retry, host close and recovery checks passed\n";
}
