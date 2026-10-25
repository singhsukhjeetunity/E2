"""Compile the actual shared EMA overlay with deterministic MT5 APIs."""
from pathlib import Path
import re
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[2]
source=(ROOT/"strategies/shared/EMATrailing.mqh").read_text()
source=re.sub(r'^input group.*\n','',source,flags=re.M)
source=re.sub(r'^input ','',source,flags=re.M)
source=re.sub(r'\b(E2TrailAttempt|MqlRates|double) (\w+)\[\];',r'std::vector<\1> \2;',source)
with tempfile.TemporaryDirectory() as directory:
    p=Path(directory)
    (p/"trailing.mqh").write_text(source)
    method=(ROOT/"strategies/shared/TrailingMethod.mqh").read_text()
    method=re.sub(r'^input group.*\n|^input ', '', method, flags=re.M)
    (p/"TrailingMethod.mqh").write_text(method)
    for name in ("checks.cpp","platform.hpp"):
        (p/name).write_text((ROOT/"tests/trailing"/name).read_text())
    binary=p/"checks"
    subprocess.run(["g++","-std=c++17","-Wall","-Wextra","-Werror",
                    "-fsanitize=address,undefined","-g","-I",str(p),str(p/"checks.cpp"),"-o",str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
