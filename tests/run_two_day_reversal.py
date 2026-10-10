"""Portable tests of production signal math and EA runtime with simulated MT5 APIs.

This does not compile MQL5 or establish trading performance.
"""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ENTRY = ROOT / "strategies/EURUSDTwoDayReversal/EURUSD_Two_Day_Reversal.mq5"
with tempfile.TemporaryDirectory() as folder:
    dest = Path(folder)
    core_binary = dest / "core"
    subprocess.run(["g++", "-std=c++17", "-Wall", "-Wextra", "-Werror",
                    str(ROOT / "tests/two_day_reversal_core.cpp"), "-o", str(core_binary)], check=True)
    subprocess.run([str(core_binary)], check=True)
    source = ENTRY.read_text()
    report = (ENTRY.parent / "ReversalReport.mqh").read_text()
    report = re.sub(r'^#include.*\n', '', report, flags=re.M)
    source = source.replace('#include "ReversalReport.mqh"', report)
    source = re.sub(r'^#property.*\n|^input group.*\n', '', source, flags=re.M)
    source = re.sub(r'^#include.*\n', '', source, flags=re.M)
    source = re.sub(r'^input ', '', source, flags=re.M)
    source = re.sub(r'\b(MqlRates|ulong|string) (\w+)\[\]', r'std::vector<\1> \2', source)
    (dest / "runtime.mqh").write_text(source)
    runtime_binary = dest / "runtime"
    subprocess.run(["g++", "-std=c++17", "-Wall", "-Wextra", "-Werror",
                    "-Wno-unused-parameter", "-Wno-misleading-indentation",
                    "-I", str(dest), str(ROOT / "tests/two_day_reversal_runtime.cpp"),
                    "-o", str(runtime_binary)], check=True)
    subprocess.run([str(runtime_binary)], check=True)
