"""Compile and execute the actual MQL calendar functions with a C++ shim."""
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
SOURCE=(ROOT/"strategies/NQOpeningRange/NQ_Opening_Range.mq5").read_text()
start=SOURCE.index("datetime DayStart(")
end=SOURCE.index("double TickRound(")
calendar=SOURCE[start:end]
assert "datetime ServerToNY(" in calendar
with tempfile.TemporaryDirectory() as folder:
    dest=Path(folder)
    (dest/"nq_calendar.mqh").write_text(calendar)
    subprocess.run(
        ["g++","-std=c++17","-Wall","-Wextra","-Werror","-I",folder,
         str(ROOT/"tests/nq_orb_clock.cpp"),"-o",str(dest/"nq_clock")],
        check=True,
    )
    subprocess.run([str(dest/"nq_clock")],check=True)
print("NQ actual-source calendar tests passed")
