"""Compile exact production checkpoint/storage functions with deterministic APIs."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
source = (root / 'strategies/EMAPullback/EMAEngine.mqh').read_text()
code = source[source.index('string Hash('):source.index('void Fail(')]
code += source[source.index('int StateFlags('):source.index('void FinalBar(')]
with tempfile.TemporaryDirectory() as temp:
    path = Path(temp)
    (path / 'ema_storage_under_test.mqh').write_text(code)
    binary = path / 'ema-runtime'
    subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', '-I', temp,
                    str(root / 'tests/ema_runtime.cpp'), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
