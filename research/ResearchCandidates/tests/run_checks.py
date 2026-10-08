"""Compile production rules/runtime through a small portable API shim; no MT5 claims."""
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]

def portable(text):
    text = re.sub(r'^#property.*\n', '', text, flags=re.M)
    text = re.sub(r'^input group.*\n', '', text, flags=re.M)
    text = text.replace('input ', '').replace('#include <Trade/Trade.mqh>', '')
    text = re.sub(r'const RCBar &([a-z_]+)\[\]', r'const std::vector<RCBar> &\1', text)
    text = re.sub(r'RCBar &([a-z_]+)\[\]', r'std::vector<RCBar> &\1', text)
    text = re.sub(r'(RCBar|MqlRates) ([a-z_]+)\[\];', r'std::vector<\1> \2;', text)
    return text

with tempfile.TemporaryDirectory() as directory:
    tmp = Path(directory)
    (tmp / 'include').mkdir()
    for file in (root / 'include').glob('*.mqh'):
        (tmp / 'include' / file.name).write_text(portable(file.read_text()))
    for entry in sorted(root.glob('*.mq5')):
        target = tmp / (entry.stem + '.cpp')
        target.write_text('#include "' + str(root / 'tests/platform.hpp') + '"\n' +
                          portable(entry.read_text()) + '\n#include "' +
                          str(root / 'tests/checks.hpp') + '"\n')
        binary = tmp / entry.stem
        # MQL event hooks may legitimately leave one parameter unused.
        subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', '-Wno-unused-parameter',
                        str(target), '-o', str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
        print(entry.name + ': portable signal, clock, risk, ownership and recovery checks passed')
