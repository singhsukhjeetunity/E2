"""Execute production MQL source with deterministic APIs; not a native MetaEditor compile."""
from pathlib import Path
import re
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[2]
EA=ROOT/"strategies/LOW WR"
def portable(text):
    text=re.sub(r'^#property.*\n|^input group.*\n', '', text, flags=re.M)
    text=re.sub(r'^input ', '', text, flags=re.M)
    text=text.replace('#include <Trade/Trade.mqh>', '')
    text='\n'.join(
        'bool E2PGCanEnter(){return test_guard;}' if 'PortfolioGate.mqh' in line else
        '' if 'ReportFolders.mqh' in line else
        '#include "SessionClock.mqh"' if 'SessionClock.mqh' in line else
        '#include "TrailingMethod.mqh"' if 'TrailingMethod.mqh' in line else line
        for line in text.splitlines())+'\n'
    return re.sub(r'\b(MqlRates|double|string|ulong) (\w+)\[\];',r'std::vector<\1> \2;',text)
platform=(ROOT/'tests/gotobi/platform.hpp').read_text()
platform=platform.replace('vsnprintf(buf,sizeof(buf),fmt,args);',
    'string format=fmt;auto pos=format.find("I64");if(pos!=string::npos)format.replace(pos,3,"l");vsnprintf(buf,sizeof(buf),format.c_str(),args);')
platform=platform.replace('struct MqlTick {double bid=100,ask=100.02;};',
                          'struct MqlTick {double bid=100,ask=100.02;datetime time=0;};')
platform=platform.replace('double target=0;};','double target=0;int kind=0;};')
platform=platform.replace('long long PositionGetInteger(int property)', 'long long legacyPositionGetInteger(int property)')
platform=platform.replace('double PositionGetDouble(int)', 'double legacyPositionGetDouble(int)')
platform=platform.replace('datetime iTime(const string&', 'datetime legacyITime(const string&')
platform=platform.replace('test_now,stop,lots,target});','test_now,stop,lots,target,side});')
platform=platform.replace('ticket,lots,test_tick.ask,stop,target});','ticket,lots,side==0?test_tick.ask:test_tick.bid,stop,target});')
platform=platform.replace('void SetTypeFillingBySymbol(const string&){}','bool SetTypeFillingBySymbol(const string&){return true;}')
platform=platform.replace('   bool PositionClose(ulong ticket,ulong)', '''   bool PositionModify(ulong ticket,double stop,double target) {
      extern bool test_modify_ok;extern int test_modifies;
      if(!test_modify_ok)return false;
      for(auto &p:test_positions)if(p.ticket==ticket){p.stop=stop;p.target=target;test_modifies++;return true;}
      return false;
   }
   bool PositionClose(ulong ticket,ulong)''')
# The legacy shim intentionally lacks M5; its generic closed-bar storage is test_m30.
platform=platform.replace('PeriodSeconds(frame)', '(frame==5?300:PeriodSeconds(frame))')
with tempfile.TemporaryDirectory() as folder:
    tmp=Path(folder)
    (tmp/'platform.hpp').write_text(platform)
    for name in ('NAS100_Session_Momentum.mq5','SessionCore.mqh','EntryState.mqh','SessionReport.mqh'):
        (tmp/name).write_text(portable((EA/name).read_text()))
    (tmp/'TrailingMethod.mqh').write_text(portable((EA/'TrailingMethod.mqh').read_text()))
    (tmp/'SessionClock.mqh').write_text((ROOT/'strategies/shared/SessionClock.mqh').read_text())
    prefix='#include "platform.hpp"\n'+(ROOT/'tests/session_momentum/platform_extra.hpp').read_text()
    prefix+='\n#define PositionGetInteger testPositionInteger\n#define PositionGetDouble testPositionValue\n#define iTime testITime\n'
    source=prefix+'\n#include "NAS100_Session_Momentum.mq5"\n'+(ROOT/'tests/session_momentum/checks.hpp').read_text()
    (tmp/'check.cpp').write_text(source)
    binary=tmp/'check'
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',
                    '-Wno-unused-parameter','-Wno-misleading-indentation','-Wno-sign-compare',
                    '-fsanitize=address,undefined','-g','-I',str(tmp),str(tmp/'check.cpp'),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
print('Session Momentum: production source signal, clock, risk, trailing, recovery and report checks passed')
