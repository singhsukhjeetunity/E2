"""Run production reporting code with simulated MT5 APIs; not a native MQL compile."""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'strategies/PortfolioGuard/PortfolioJournal.mqh').read_text()
source=re.sub(r'^#include.*\n|^input group.*\n','',source,flags=re.M)
source=re.sub(r'^input ','',source,flags=re.M)
source=re.sub(r'const (PGJRow|ulong) &(\w+)\[\]',r'const std::vector<\1> &\2',source)
source=re.sub(r'int &(\w+)\[\]',r'std::vector<int> &\1',source)
source=re.sub(r'\b(PGJRisk|PGJPending|PGJRow|ulong|int|string) (\w+)\[\]',r'std::vector<\1> \2',source)
with tempfile.TemporaryDirectory() as folder:
    p=Path(folder)
    (p/'journal.mqh').write_text(source)
    binary=p/'journal'
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',
                    '-Wno-misleading-indentation','-fsanitize=undefined,address','-g',
                    '-I',str(p),str(ROOT/'tests/portfolio_journal_runtime.cpp'),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
