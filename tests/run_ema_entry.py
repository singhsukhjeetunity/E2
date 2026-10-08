"""Exercise actual entry code: durability precedes send and no pending resend."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'strategies/EMAPullback/EMAEngine.mqh').read_text()
with tempfile.TemporaryDirectory() as tmp:
    p=Path(tmp)
    (p/'ema_entry.mqh').write_text(s[s.index('bool DefiniteRejection('):s.index('void Equity(')])
    clock=(root/'strategies/EMAPullback/SessionClock.mqh').read_text()
    deadline=clock[clock.index('bool NPExitOverdue('):clock.index('bool NPRetryClose(')]
    (p/'ema_deadline.mqh').write_text(deadline+s[s.index('void MarkOverdue('):s.index('bool ClosePosition(')])
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',tmp,str(root/'tests/ema_entry.cpp'),'-o',str(p/'test')],check=True)
    subprocess.run([str(p/'test')],check=True)
