"""Compile exact gold time helpers and range class; no MT5 installation needed."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
s = (root / 'strategies/GoldSessionFade/include/strategy/E2XauSessionFadeEngine.mqh').read_text()
with tempfile.TemporaryDirectory() as tmp:
    p = Path(tmp)
    (p / 'gold_range.mqh').write_text(s[s.index('class E2XauSessionRange'):s.index('class E2XauSessionFadeEngine')])
    subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', '-I', tmp,
                    str(root / 'tests/gold_clock.cpp'), '-o', str(p / 'test')], check=True)
    subprocess.run([str(p / 'test')], check=True)
