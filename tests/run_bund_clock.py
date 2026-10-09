"""Compile and exercise the Bund EA's exact clock implementation through C++."""
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
source=(root/"strategies/BundDonchian/Bund_Donchian_Breakout.mq5").read_text()
calendar=source[source.index("datetime DayStart("):source.index('#include "BundReport.mqh"')]
assert "datetime ServerToUTC(" in calendar
with tempfile.TemporaryDirectory() as folder:
    path=Path(folder)
    (path/"nq_calendar.mqh").write_text(calendar)
    subprocess.run(["g++","-std=c++17","-Wall","-Wextra","-Werror","-I",folder,
                    str(root/"tests/nq_orb_clock.cpp"),"-o",str(path/"bund_clock")],check=True)
    subprocess.run([str(path/"bund_clock")],check=True)
print("Bund actual-source DST/clock checks passed")
