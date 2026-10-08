"""Package all four EAs and dependencies; source only, never an EX5 claim."""
import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True)
args = parser.parse_args()
output = Path(args.output)
output.parent.mkdir(parents=True, exist_ok=True)
strategy = root / 'strategies'
files = sorted(p for p in strategy.rglob('*') if p.suffix in ('.mq5', '.mqh'))
assert sum(p.suffix == '.mq5' for p in files) == 4
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for file in files:
        archive.write(file, 'MQL5/Experts/E2/' + file.relative_to(strategy).as_posix())
    archive.write(root / 'docs/LIVE_RECOVERY_UPDATE.md', 'INSTALL.md')
    archive.write(root / 'presets/EURJPYGotobi_50p_configurable.set',
                  'MQL5/Presets/E2/EURJPYGotobi_50p_configurable.set')
with ZipFile(output) as archive:
    assert archive.testzip() is None
print(output)
