"""Build the MT5 source-install ZIP, with immutable trading-code verification."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
BASELINE = '57e808d7a36ca05a40b38f6bef60940d76f0f28b'
COMPONENTS = {
    'Gold': 'GoldSessionFade/XAU_Session_Fade.mq5',
    'Compression': 'CompressionBreakout/Compression_Breakout_Long.mq5',
    'Gotobi': 'EURJPYGotobi/EURJPY_Gotobi.mq5',
    'ORB': 'NQOpeningRange/NQ_Opening_Range.mq5',
    'BTC': 'BTCMomentumPullback/BTCUSD_Momentum_Pullback.mq5',
    'PortfolioGuard': 'PortfolioGuard/E2_PortfolioGuard.mq5',
}

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def build(destination):
    guard_path = 'strategies/PortfolioGuard/E2_PortfolioGuard.mq5'
    old_guard = git('show', BASELINE + ':' + guard_path).decode()
    new_guard = (ROOT / guard_path).read_text()
    for name in ['PGWrite', 'PGFieldsPresent', 'PGExistingDayValid', 'PGFloor',
                 'PGWarn', 'PGSetDay', 'PGCloseAccountPositions', 'PGRun']:
        pattern = r'(?:bool|double|void) ' + name + r'\([^\n]*\)\n\{.*?\n\}'
        if re.search(pattern, old_guard, re.S).group() != re.search(pattern, new_guard, re.S).group():
            raise RuntimeError('Guard risk function differs from baseline: ' + name)
    files = git('ls-files', '-z', 'strategies').decode().strip('\0').split('\0')
    content = {}
    for name in files:
        p = ROOT / name
        data = p.read_bytes()
        if p.suffix in ('.mq5', '.mqh') and not name.startswith('strategies/PortfolioGuard/'):
            original = git('show', BASELINE + ':' + name)
            if data != original:
                raise RuntimeError('Trading/shared code differs from baseline: ' + name)
        content['MQL5/Experts/E2/' + name] = data
    for name in ['README.md', 'docs/INSTALLATION.md', 'docs/releases/E2-Ultron.md']:
        text = (ROOT / name).read_text()
        # Install ZIP places strategy sources under the actual MT5 folder tree.
        text = text.replace('](strategies/', '](MQL5/Experts/E2/strategies/')
        text = text.replace('](../strategies/', '](../MQL5/Experts/E2/strategies/')
        content[name] = text.encode()
    versions = {}
    for name, path in COMPONENTS.items():
        match = re.search(r'#property\s+version\s+"([^"]+)"', (ROOT/'strategies'/path).read_text())
        if not match:
            raise RuntimeError('Missing source version: ' + path)
        versions[name] = match.group(1)
    manifest = {
        'release': 'E2-Ultron', 'commit': git('rev-parse', 'HEAD').decode().strip(),
        'trading_baseline': BASELINE, 'source_only': True, 'versions': versions,
        'files_sha256': {name: digest(data) for name, data in sorted(content.items())},
    }
    content['MANIFEST.json'] = (json.dumps(manifest, indent=2, sort_keys=True)+'\n').encode()
    destination.mkdir(parents=True, exist_ok=True)
    archive = destination/'E2-Ultron-source.zip'
    with ZipFile(archive, 'w', compression=ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in sorted(content.items()):
            info = ZipInfo('E2-Ultron/' + name, date_time=(2026, 10, 18, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, data, compresslevel=9)
    with ZipFile(archive) as z:
        assert z.testzip() is None
        assert len(z.namelist()) == len(content)
        for name, data in content.items():
            assert z.read('E2-Ultron/' + name) == data
    (destination/'SHA256SUMS.txt').write_text(digest(archive.read_bytes())+'  '+archive.name+'\n')
    print(f'Verified {len(content)} files; trading code matches {BASELINE[:7]}; source-only ZIP ready.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    build(parser.parse_args().output.resolve())
