"""Compile production compression rules, feed, entries and recovery with deterministic APIs."""
from pathlib import Path
import subprocess,tempfile,random,math
root=Path(__file__).resolve().parents[1]
s=(root/'strategies/CompressionBreakout/CompressionEngine.mqh').read_text()
def compile_run(p,name,code):
    f=p/(name+'.cpp');f.write_text(code)
    binary=p/name
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',str(p),str(f),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
def absolute_includes(code):
    return code.replace('"../strategies/', '"'+str(root/'strategies')+'/')
with tempfile.TemporaryDirectory() as tmp:
    p=Path(tmp)
    # Exact entry and daily-limit code; simulate terminal restarts with retained broker deals.
    (p/'ema_entry.mqh').write_text(s[s.index('bool DailyEntryAllowed('):s.index('void Equity(')])
    h=(root/'tests/ema_entry.cpp').read_text()
    for a,b in [('InpEMAStopATR','InpStopATR'),('InpEMATargetR','InpTargetR'),('InpEMACashRisk','InpCashRisk')]:h=h.replace(a,b)
    h=h.replace('bool Enabled(int){','bool CBEntryWindow(datetime){return true;}\nbool Enabled(int){').replace('Next NY date','Next UTC date').replace('EMA durable','Compression daily limit and durable')
    compile_run(p,'entry',absolute_includes(h))
    # Exact recovery implementation: new scope, restart/partial intent, ownership and durable writes.
    storage=s[s.index('string Hash('):s.index('void Fail(')]+s[s.index('int StateFlags('):s.index('void FinalBar(')]
    (p/'ema_storage_under_test.mqh').write_text(storage)
    h=(root/'tests/ema_runtime.cpp').read_text().replace('InpEMAMagic','InpMagic').replace('EMA warm-up','Compression warm-up')
    compile_run(p,'runtime',absolute_includes(h))
    # Exact minute feed and bootstrap: replace only API scaffolding and indicator names.
    (p/'ema_slot.mqh').write_text(s[s.index('struct NPSlot'):s.index('NPSlot g_slots')])
    feed=s[s.index('void FinalBar'):s.index('// Resolve the session')].replace('MqlRates m[];','std::vector<MqlRates> m;')
    (p/'ema_feed.mqh').write_text(feed)
    (p/'ema_warmup_size.mqh').write_text('')
    h=(root/'tests/ema_warmup.cpp').read_text().replace('../strategies/EMAPullback/EMACore.mqh','../strategies/CompressionBreakout/CompressionCore.mqh')
    h=h.replace('InpEMAFast=20,InpEMASlow=50','InpChannelBars=20,InpCompressionBars=100; double InpCompressionRatio=0.8').replace('NPReset(','CBReset(')
    h=h.replace('indicators.count>=1000','indicators.count>=599').replace('31440','18000').replace('EMA warm','Compression warm')
    compile_run(p,'feed',absolute_includes(h))
    # Compile clock from the production source, adapting only its include separator for Linux.
    clock=(root/'strategies/CompressionBreakout/CompressionClock.mqh').read_text().replace('"..\\\\EMAPullback\\\\SessionClock.mqh"','"'+str(root/'strategies/EMAPullback/SessionClock.mqh')+'"')
    (p/'compression_clock.mqh').write_text(clock)
    prefix=(root/'tests/ema_core.cpp').read_text().split('#include "../strategies/EMAPullback/EMACore.mqh"')[0]
    checks='''
#include "compression_clock.mqh"
int main(){
 assert(CBEntryWindow(NPDate(2025,1,9,6))); // US equity holiday is NOT an FX exclusion.
 assert(!CBEntryWindow(NPDate(2025,1,9,5,59)));
 assert(!CBEntryWindow(NPDate(2025,1,9,20)));
 assert(!CBEntryWindow(NPDate(2025,1,11,12)));
 assert(CBEntryWindow(NPDate(2027,1,4,12))); // No hard-coded calendar expiry.
 assert(CBDeadline(NPDate(2025,1,9,19))==NPDate(2025,1,9,21,45));
 assert(CBDeadline(NPDate(2025,7,9,19))==NPDate(2025,7,9,20,45));
 assert(CBDeadline(NPDate(2025,7,9,6))==NPDate(2025,7,9,14));
 assert(CBDeadline(NPDate(2025,3,7,19))==NPDate(2025,3,7,21,45));
 assert(CBDeadline(NPDate(2025,3,10,19))==NPDate(2025,3,10,20,45));
 assert(NPEarlierExit(CBDeadline(NPDate(2025,7,9,19)),NPDate(2025,7,9,20),5)==NPDate(2025,7,9,19,55));
}
'''
    compile_run(p,'clock',prefix+checks)
    # Streaming signal runner compared below with an independent batch formula.
    runner='''
#include <iostream>
#include <iomanip>
#include "CORE"
int main(){CBState s;CBReset(s);CBBar b;double a;std::cout<<std::setprecision(17);
 while(std::cin>>b.start>>b.open>>b.high>>b.low>>b.close>>b.minutes){bool hit=CBConsume(s,b,30,14,20,100,0.8,a);std::cout<<hit<<" "<<a<<"\\n";}}
'''.replace('CORE',str(root/'strategies/CompressionBreakout/CompressionCore.mqh'))
    f=p/'signal.cpp';f.write_text(runner);binary=p/'signal'
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(f),'-o',str(binary)],check=True)
    rng=random.Random(20260917);bars=[];close=100
    for i in range(6000):
        vol=1 if i%250<150 else .08
        op=close;close+=rng.gauss(.01,vol);hi=max(op,close)+rng.random()*vol;lo=min(op,close)-rng.random()*vol
        bars.append((i*1800,op,hi,lo,close,29 if i%71==0 else 30))
    text=''.join(' '.join(map(str,b))+'\n' for b in bars)
    actual=[line.split() for line in subprocess.check_output([str(binary)],input=text,text=True).splitlines()]
    atrs=[];hits=0
    for i,b in enumerate(bars):
        tr=b[2]-b[3] if not i else max(b[2]-b[3],abs(b[2]-bars[i-1][4]),abs(b[3]-bars[i-1][4]))
        a=tr if not i else atrs[-1]*13/14+tr/14;atrs.append(a)
        hit=i>=299 and b[5]==30 and b[4]>max(x[2] for x in bars[i-20:i]) and bars[i-1][4]<=max(x[2] for x in bars[i-21:i-1]) and atrs[i-1]<.8*sum(atrs[i-100:i])/100
        assert int(actual[i][0])==int(hit),(i,'signal mismatch')
        assert math.isclose(float(actual[i][1]),a,rel_tol=1e-12,abs_tol=1e-12),(i,'ATR mismatch')
        hits+=hit
    assert hits>10,hits
    print(f'Compression batch/streaming parity: {len(bars)} bars, {hits} signals; execution, restart, daily-limit and clock checks passed.')
