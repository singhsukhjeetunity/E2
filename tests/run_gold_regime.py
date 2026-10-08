"""Exercise actual Gold replay/filter/engine code across restart, without MT5."""
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
folder = root / 'strategies/GoldSessionFade/include/strategy'
def portable(text):
    text = re.sub(r'^#include.*$', '', text, flags=re.M)
    for kind in ('E2XauRegimeObservation', 'MqlRates', 'E2Candidate', 'double'):
        text = re.sub(rf'{kind} ([a-z_]+)\[\];', rf'std::vector<{kind}> \1;', text)
    text = text.replace('E2Candidate &out[]', 'std::vector<E2Candidate> &out')
    for pointer in ('m_logger', 'm_time', 'm_weekend'):
        text = text.replace(pointer + '.', pointer + '->')
    return text
with tempfile.TemporaryDirectory() as tmp:
    p = Path(tmp)
    (p / 'gold_regime.mqh').write_text(portable((folder / 'E2XauRegimeFilter.mqh').read_text()))
    (p / 'gold_engine.mqh').write_text(portable((folder / 'E2XauSessionFadeEngine.mqh').read_text()))
    binary = p / 'test'
    subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', '-I', tmp,
                    str(root / 'tests/gold_regime.cpp'), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
