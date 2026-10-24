"""Portable tests of production signal math and EA runtime with simulated MT5 APIs.

This does not compile MQL5 or establish trading performance.
"""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ENTRY = ROOT / "strategies/BTCMomentumPullback/BTCUSD_Momentum_Pullback.mq5"
with tempfile.TemporaryDirectory() as folder:
    dest = Path(folder)
    core = (ENTRY.parent / "MomentumCore.mqh").read_text().replace("const double &values[]", "const std::vector<double> &values")
    (dest / "core.mqh").write_text(core)
    core_binary = dest / "core"
    subprocess.run(["g++", "-std=c++17", "-Wall", "-Wextra", "-Werror",
                    "-I", str(dest), str(ROOT / "tests/btc_momentum_core.cpp"), "-o", str(core_binary)], check=True)
    subprocess.run([str(core_binary)], check=True)
    trail=(ROOT/"strategies/shared/EMATrailing.mqh").read_text()
    trail=re.sub(r'^input group.*\n', '', trail, flags=re.M)
    trail=re.sub(r'^input ', '', trail, flags=re.M)
    trail=re.sub(r'\b(E2TrailAttempt|MqlRates|double) (\w+)\[\];',r'std::vector<\1> \2;',trail)
    (dest/"trailing.mqh").write_text(trail)
    source = ENTRY.read_text()
    report = (ENTRY.parent / "MomentumReport.mqh").read_text()
    report = re.sub(r'^#include.*\n', '', report, flags=re.M)
    source = source.replace('#include "MomentumReport.mqh"', report)
    source = re.sub(r'^#property.*\n|^input group.*\n', '', source, flags=re.M)
    source = re.sub(r'^#include.*\n', '', source, flags=re.M)
    source = '#include "'+str(ROOT/'tests/trailing/btc_api.hpp')+'"\n#include "trailing.mqh"\n'+source
    source = re.sub(r'^input ', '', source, flags=re.M)
    source = re.sub(r'\b(MqlRates|ulong|string|double|datetime) (\w+)\[\]', r'std::vector<\1> \2', source)
    (dest / "runtime.mqh").write_text(source)
    runtime_binary = dest / "runtime"
    subprocess.run(["g++", "-std=c++17", "-Wall", "-Wextra", "-Werror",
                    "-Wno-unused-parameter", "-Wno-misleading-indentation",
                    "-I", str(dest), str(ROOT / "tests/btc_momentum_runtime.cpp"),
                    "-o", str(runtime_binary)], check=True)
    subprocess.run([str(runtime_binary)], check=True)
