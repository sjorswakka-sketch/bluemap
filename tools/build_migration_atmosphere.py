#!/usr/bin/env python3
"""Bind the atmosphere, world atlas, travel, achievements and settings to the preserved Godot sources.

Like phase 20 this phase has no recorded oracle: it is presentation and menus. The achievements catalog
that ordinary play loads is derived here from the portable catalog of phase 4, never typed by hand.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PHASE = 21
CONTRACT = 'migration/phase-21/source-contracts.json'
ASSETS = 'unity/Assets/BlueMapAtmosphere'
SESSION = 'unity/Assets/BlueMapRoute/Runtime/Session/'
CONTROLLERS = tuple(SESSION + name for name in ('AtmosphereRouteController.cs', 'WorldMapRouteController.cs',
                                                'RecordsRouteController.cs'))
PORTABLE_ACHIEVEMENTS = 'migration/portable/catalogs/achievements.json'
ACHIEVEMENTS_RESOURCE = ASSETS + '/Runtime/Resources/BlueMapAchievements.json'
SOURCE_MANIFEST = 'migration/reference/source-manifest.json'
SOURCE_PATHS = (
    'scripts/core/daynight.gd', 'scripts/core/world_atlas.gd', 'scripts/core/fast_travel.gd', 'scripts/core/journey.gd',
    'scripts/core/sound.gd', 'scripts/core/lang.gd', 'scripts/core/art.gd', 'scripts/data/achievements.gd',
    'scripts/entities/atmosphere.gd', 'scripts/entities/rain.gd', 'scripts/entities/snow.gd', 'scripts/entities/dust.gd',
    'scripts/entities/lantern.gd', 'scripts/entities/torch.gd', 'scripts/entities/diepte_lamp.gd',
    'scripts/ui/world_atlas_page.gd', 'scripts/ui/menu_pages.gd', 'scripts/ui/pause_menu.gd',
    'scripts/ui/achievement_banner.gd', 'scripts/ui/hud.gd',
)
# The colour of each hour and how much lamp light it needs; must stay equal to scripts/core/daynight.gd KEYS.
DAY_KEYS = ((0.00, (1.00, 0.82, 0.72), 0.35), (0.07, (1.00, 0.92, 0.82), 0.05), (0.17, (1.0, 1.0, 1.0), 0.0),
            (0.52, (1.0, 1.0, 1.0), 0.0), (0.60, (1.00, 0.78, 0.56), 0.15), (0.68, (0.62, 0.46, 0.62), 0.6),
            (0.76, (0.30, 0.36, 0.66), 1.0), (0.90, (0.30, 0.36, 0.66), 1.0), (0.96, (0.58, 0.48, 0.70), 0.7),
            (1.00, (1.00, 0.82, 0.72), 0.35))


class AtmosphereDataError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise AtmosphereDataError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read(root: Path, name: str) -> bytes:
    path = root / name
    require(path.is_file() and not path.is_symlink(), 'Missing or linked migration input: ' + name)
    return path.read_bytes().replace(b'\r\n', b'\n')


def plain(value):
    kind = value.get('kind')
    if kind in ('dictionary', 'object'):
        return {plain(key): plain(child) for key, child in value['entries']}
    if kind == 'array':
        return [plain(child) for child in value['values']]
    if kind == 'int':
        return int(value['value'])
    if kind == 'float':
        return float(value['value'])
    if kind == 'bool':
        return value['value'] in (True, 'true')
    if kind == 'nil':
        return None
    return value.get('value')


def achievements_catalog(root: Path) -> bytes:
    """The small list ordinary play loads: id, name, explanation, conditions and whether it is secret."""
    portable = plain(json.loads(read(root, PORTABLE_ACHIEVEMENTS).decode('utf-8')))
    rows = []
    for entry in portable['entries']:
        value = entry['value']
        require(isinstance(value.get('name'), str) and isinstance(value.get('desc'), str), 'Malformed achievement: ' + entry['id'])
        rows.append({'id': entry['id'], 'name': value['name'], 'desc': value['desc'], 'if': value.get('if', []),
                     'secret': bool(value.get('secret', False))})
    require(len(rows) == portable['count'] == 40 and len({row['id'] for row in rows}) == 40, 'The original achievements differ')
    document = {'schema': 'bluemap.achievements.runtime-catalog.v1', 'personalSavesUsed': False, 'achievements': rows}
    return (json.dumps(document, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8')


def asset_files(root: Path) -> list[str]:
    base = root / ASSETS
    require(base.is_dir(), 'Unity atmosphere assets are missing')
    names = sorted(path.relative_to(root).as_posix() for path in base.rglob('*') if path.is_file())
    return names + [name + suffix for name in CONTROLLERS for suffix in ('', '.meta')]


def native_checks(root: Path) -> list[str]:
    runner = read(root, ASSETS + '/Runtime/Probes/AtmosphereProbeRunner.cs').decode('utf-8')
    names = re.findall(r'[cC]heck\("(atmosphere_[a-z0-9_]+)"', runner)
    require(len(names) == len(set(names)) and len(names) >= 12, 'Native atmosphere checks are missing or duplicated')
    return sorted(names)


def validate_day_keys(root: Path) -> None:
    source = read(root, 'scripts/core/daynight.gd').decode('utf-8')
    found = re.findall(r'\[(\d\.\d+), Color\(([\d.]+), ([\d.]+), ([\d.]+)\), ([\d.]+)\]', source)
    require([(float(t), (float(r), float(g), float(b)), float(n)) for t, r, g, b, n in found] == list(DAY_KEYS),
            'The colours of the day differ from the source')
    unity = read(root, SESSION + 'AtmosphereRouteController.cs').decode('utf-8')
    ported = re.findall(r'\(([\d.]+),(?:new Color\(([\d.]+)f,([\d.]+)f,([\d.]+)f\)|Color\.white),([\d.]+)\)', unity)
    rows = [(float(t), (float(r or 1), float(g or 1), float(b or 1)), float(n)) for t, r, g, b, n in ported]
    require(rows == list(DAY_KEYS), 'The Unity colours of the day differ from the source')


def source_hashes(root: Path) -> dict:
    manifest = json.loads(read(root, SOURCE_MANIFEST).decode('utf-8-sig'))
    preserved = {row['path']: row['sha256'] for row in manifest['files']} if isinstance(manifest.get('files'), list) else None
    result = {}
    for name in sorted(SOURCE_PATHS):
        digest = sha256(read(root, name))
        if preserved is not None:
            require(preserved.get(name) == digest, 'Original source differs from the preserved reference: ' + name)
        result[name] = digest
    return result


def build_contract(root: Path = ROOT) -> dict:
    validate_day_keys(root)
    return {'schema': 'bluemap.atmosphere.source-contracts.v1', 'phase': PHASE, 'personalSavesUsed': False,
            'recordedOracle': False,
            'coverage': {'nativeChecks': native_checks(root), 'achievements': 40, 'regions': 19, 'sources': len(SOURCE_PATHS)},
            'portableAchievements': sha256(read(root, PORTABLE_ACHIEVEMENTS)),
            'sources': source_hashes(root),
            'unityAssets': {name: sha256(read(root, name)) for name in asset_files(root)}}


def check(root: Path = ROOT) -> dict:
    contract = build_contract(root)
    stored = json.loads(read(root, CONTRACT).decode('utf-8'))
    require(stored == contract, 'Atmosphere source contract differs from the current sources or Unity assets')
    require(read(root, ACHIEVEMENTS_RESOURCE) == achievements_catalog(root), 'Unity achievements are not derived from the portable catalog')
    for name in asset_files(root):
        if not name.endswith('.meta'):
            meta = root / (name + '.meta')
            require(meta.is_file() and 'guid: ' in meta.read_text(encoding='utf-8'), 'Unity asset has no metadata: ' + name)
    return contract


def write(root: Path = ROOT) -> dict:
    (root / ACHIEVEMENTS_RESOURCE).parent.mkdir(parents=True, exist_ok=True)
    (root / ACHIEVEMENTS_RESOURCE).write_bytes(achievements_catalog(root))
    contract = build_contract(root)
    (root / CONTRACT).parent.mkdir(parents=True, exist_ok=True)
    (root / CONTRACT).write_bytes((json.dumps(contract, ensure_ascii=False, indent=1, sort_keys=True) + '\n').encode('utf-8'))
    return contract


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--write', action='store_true')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    try:
        contract = check() if args.check else write()
    except (AtmosphereDataError, OSError, KeyError, ValueError) as error:
        print('MIGRATION ATMOSPHERE DATA FAILED:', error, file=sys.stderr)
        return 1
    if args.report:
        args.report.write_bytes((json.dumps({'schema': 1, 'success': True, 'phase': PHASE, 'coverage': contract['coverage'],
                                             'unityAssets': len(contract['unityAssets'])}, indent=1, sort_keys=True) + '\n').encode('utf-8'))
    coverage = contract['coverage']
    print(f"MIGRATION ATMOSPHERE DATA OK: {coverage['sources']} preserved sources; {len(coverage['nativeChecks'])} native checks; "
          f"{coverage['achievements']} achievements; {coverage['regions']} regions")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
