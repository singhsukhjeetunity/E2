"""Compile production rules/runtime through a small portable API shim; no MT5 claims."""
from pathlib import Path
import re
import subprocess
import tempfile
import sys

test_root = Path(__file__).resolve().parent
root = test_root.parents[1] / "strategies" / "EURJPYGotobi"
sys.path.insert(0, str(test_root.parents[1]))
from journal.model import parse_csv

def portable(text):
    text = re.sub(r'^#property.*\n', '', text, flags=re.M)
    text = re.sub(r'^input group.*\n', '', text, flags=re.M)
    text = text.replace('input ', '').replace('#include <Trade/Trade.mqh>', '')
    text = re.sub(r'const RCBar &([a-z_]+)\[\]', r'const std::vector<RCBar> &\1', text)
    text = re.sub(r'RCBar &([a-z_]+)\[\]', r'std::vector<RCBar> &\1', text)
    text = re.sub(r'(RCBar|MqlRates|RCReportTrade|RCEntryRisk) ([a-z_]+)\[\];', r'std::vector<\1> \2;', text)
    return text

with tempfile.TemporaryDirectory() as directory:
    tmp = Path(directory)
    (tmp / 'include').mkdir()
    for file in (root / 'include').glob('*.mqh'):
        (tmp / 'include' / file.name).write_text(portable(file.read_text()))
    for entry in sorted(root.glob('*.mq5')):
        target = tmp / (entry.stem + '.cpp')
        target.write_text('#include "' + str(test_root / 'platform.hpp') + '"\n' +
                          portable(entry.read_text()) + '\n#include "' +
                          str(test_root / 'checks.hpp') + '"\n')
        binary = tmp / entry.stem
        # MQL event hooks may legitimately leave one parameter unused.
        subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', '-Wno-unused-parameter',
                        str(target), '-o', str(binary)], check=True)
        ledger = tmp / 'actual-export.csv'
        subprocess.run([str(binary), str(ledger)], check=True)
        imported = parse_csv(ledger.read_bytes(), {'id': 'portable', 'kind': 'Backtest'})
        assert not imported['errors'], imported['errors']
        assert len(imported['rows']) == 1
        assert imported['rows'][0]['net'] == 89 and imported['rows'][0]['r'] == .89
        print('Actual EA finalized CSV imports into the E2 Journal with reconciled profit and R.')
        print(entry.name + ': portable signal, clock, risk, ownership and recovery checks passed')
