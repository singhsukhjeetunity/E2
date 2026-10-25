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
LOW_WR_BASELINE = '48e4912acc2e8fe7039ff9448b7474f6436a6bda'
BTC_ENTRY = 'strategies/BTCMomentumPullback/BTCUSD_Momentum_Pullback.mq5'
BTC_OLD_SYMBOL_CHECK = '''   // Symbol suffixes are supported; prevent accidental attachment to a different currency pair.
   if(SymbolInfoString(_Symbol,SYMBOL_CURRENCY_BASE)!="BTC"||SymbolInfoString(_Symbol,SYMBOL_CURRENCY_PROFIT)!="USD") {
      Print("[BTCMP] This research EA requires a BTCUSD symbol.");return INIT_PARAMETERS_INCORRECT;
   }
'''
# Exact reviewed Gotobi v1.17 entry-reservation patch; all other strategy/shared
# sources remain checked against the original baseline below.
GOTOBI_PATCH_SHA256 = {
    'strategies/EURJPYGotobi/EURJPY_Gotobi.mq5':
        '945d0aaa63585ff5f15358f5b692a0e04bf756f85615b13429afe30bd38e61de',
    'strategies/EURJPYGotobi/include/Runtime.mqh':
        'f428ba3d4cd223f27da7609a9893d3c3039e683380e7c569e650e5d73cd9cc80',
    'strategies/EURJPYGotobi/include/EntryGuard.mqh':
        '01ae5963e447dd620cb4383d200007541fffdb09740a9061d6847e5512d7e24a',
}

COMPONENTS = {
    'Gold': 'MID WR/GoldSessionFade/XAU_Session_Fade.mq5',
    'Compression': 'MID WR/CompressionBreakout/Compression_Breakout_Long.mq5',
    'Gotobi': 'MID WR/EURJPYGotobi/EURJPY_Gotobi.mq5',
    'ORB': 'MID WR/NQOpeningRange/NQ_Opening_Range.mq5',
    'BTC': 'MID WR/BTCMomentumPullback/BTCUSD_Momentum_Pullback.mq5',
    'LOW WR': 'LOW WR/NAS100_Session_Momentum.mq5',
    'PortfolioGuard': 'PortfolioGuard/E2_PortfolioGuard.mq5',
}

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def historical_source(name, data):
    """Undo only the added MID WR path level for immutable-code comparisons."""
    if not name.startswith('strategies/MID WR/'):
        return name, data
    name = 'strategies/' + name[len('strategies/MID WR/'):]
    parent = '..' + chr(92)*2
    lines = data.decode().splitlines(keepends=True)
    for i, line in enumerate(lines):
        if line.startswith('#include "'+parent) and 'shared' in line:
            lines[i] = line.replace(parent, '', 1)
    return name, ''.join(lines).encode()

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
            if name.startswith('strategies/LOW WR/'):
                if data != git('show', LOW_WR_BASELINE + ':' + name):
                    raise RuntimeError('LOW WR differs from reviewed preset source: ' + name)
                content['MQL5/Experts/E2/' + name] = data
                continue
            original_name, checked_data = historical_source(name, data)
            if original_name in GOTOBI_PATCH_SHA256:
                if digest(checked_data) != GOTOBI_PATCH_SHA256[original_name]:
                    raise RuntimeError('Gotobi source differs from approved v1.17 patch: ' + name)
                content['MQL5/Experts/E2/' + name] = data
                continue
            original = git('show', BASELINE + ':' + original_name)
            if original_name == BTC_ENTRY:
                # Permit precisely the requested v0.14 attachment fix, not changes
                # to BTC's signals, sizing, exits, defaults or guard integration.
                text = original.decode()
                if text.count(BTC_OLD_SYMBOL_CHECK) != 1:
                    raise RuntimeError('Unexpected BTC baseline initialization')
                original = text.replace('#property version "0.13"', '#property version "0.14"', 1).replace(BTC_OLD_SYMBOL_CHECK, '', 1).encode()
            if checked_data != original:
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
        'authorized_code_changes': ['BTC v0.14: remove chart currency-metadata restriction',
                                    'Gotobi v1.17: durable entry reservation and exclusive instance lock',
                                    'MID WR: folder relocation and corresponding include paths only',
                                    'LOW WR: isolated research source and uploaded preset at ' + LOW_WR_BASELINE],
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
    print(f'Verified {len(content)} files; baseline {BASELINE[:7]} plus exact BTC symbol and Gotobi submission fixes; source-only ZIP ready.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    build(parser.parse_args().output.resolve())
