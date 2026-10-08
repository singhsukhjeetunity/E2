"""Build the standalone MT5 source/preset installation zip (no EX5 claim)."""
import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True)
args = parser.parse_args()
output = Path(args.output)
output.parent.mkdir(parents=True, exist_ok=True)
strategy = root / 'strategies/EURJPYGotobi'
files = sorted(p for p in strategy.rglob('*') if p.suffix in ('.mq5', '.mqh'))
assert len([p for p in files if p.suffix == '.mq5']) == 1
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for file in files:
        archive.write(file, 'MQL5/Experts/E2/EURJPYGotobi/' + file.relative_to(strategy).as_posix())
    archive.write(root / 'presets/EURJPYGotobi_50p_023pct.set', 'MQL5/Presets/E2/EURJPYGotobi_50p_023pct.set')
    archive.write(root / 'docs/GOTOBI_INSTALL.md', 'INSTALL.md')
    archive.write(strategy / 'robustness/MONTE_CARLO_50.md', 'SIZING.md')
with ZipFile(output) as archive:
    assert archive.testzip() is None
print(output)
