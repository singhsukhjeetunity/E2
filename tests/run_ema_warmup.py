"""Exercise production minute aggregation and async warm-up with synthetic history."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
s = (root / 'strategies/EMAPullback/EMAEngine.mqh').read_text()
code = s[s.index('struct NPSlot'):s.index('NPSlot g_slots')]
feed = s[s.index('void FinalBar'):s.index('// Resolve the session')]
feed = feed.replace('MqlRates m[];', 'std::vector<MqlRates> m;')
with tempfile.TemporaryDirectory() as tmp:
    p=Path(tmp)
    state = (root/'strategies/EMAPullback/EMAState.mqh').read_text()
    (p/'ema_warmup_size.mqh').write_text(state[state.index('int NPWarmupMinutes('):state.index('string NPEncode(')])
    (p/'ema_slot.mqh').write_text(code)
    (p/'ema_feed.mqh').write_text(feed)
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',tmp,
                    str(root/'tests/ema_warmup.cpp'),'-o',str(p/'test')],check=True)
    subprocess.run([str(p/'test')],check=True)
