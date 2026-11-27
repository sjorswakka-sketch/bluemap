#!/usr/bin/env python3
"""Bind farming, irrigation, production and the water types to preserved Godot methods without running either engine.

The contract proves exact work reasons, irrigation, growth on active time, yields and saved state.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

from record_migration_farm import normalize_exact_mirrors
from record_migration_inventory_state import validate_float64_bits

ROOT = Path(__file__).resolve().parents[1]
PHASE = 19
CONTRACT = 'migration/phase-19/source-contracts.json'
ORACLE = 'migration/phase-19/farm-oracle.json'
ASSETS = 'unity/Assets/BlueMapFarm'
ORACLE_RESOURCE = ASSETS + '/Runtime/Model/Resources/BlueMapFarmOracle.json'
CATALOG_RESOURCE = ASSETS + '/Runtime/Model/Resources/BlueMapFarmCatalog.json'
ROUTE_CONTROLLER = 'unity/Assets/BlueMapRoute/Runtime/Session/FarmRouteController.cs'
SOURCE_MANIFEST = 'migration/reference/source-manifest.json'
RECORDERS = ('tools/migration_farm_export.gd', 'tools/record_migration_farm.py', 'tools/migration_home_export.gd',
             'tools/record_migration_home.py', 'tools/migration_progression_export.gd', 'tools/migration_inventory_export.gd',
             'tools/migration_route_export.gd')
SOURCE_PATHS = (
    'scripts/core/homestead.gd', 'scripts/core/orchard.gd', 'scripts/core/garden_feedback.gd', 'scripts/core/water_features.gd',
    'scripts/core/garden_art.gd', 'scripts/core/orchard_art.gd', 'scripts/core/water_art.gd', 'scripts/core/yard.gd',
    'scripts/core/stockroom.gd', 'scripts/core/professions.gd', 'scripts/core/game_state.gd',
    'scripts/data/orchard_catalog.gd', 'scripts/data/homestead_maps.gd', 'scripts/data/water_layouts.gd',
    'scripts/data/yard_catalog.gd', 'scripts/data/tiles.gd', 'scripts/data/items.gd', 'scripts/data/ext/homestead.gd',
    'scripts/data/ext/orchard.gd', 'scripts/maps/village.gd', 'scripts/maps/registry.gd',
    'scripts/entities/homestead.gd', 'scripts/entities/home_station.gd', 'scripts/entities/orchard_tree.gd',
    'scripts/entities/water_scenery.gd',
    'scripts/ui/home_ui.gd', 'scripts/ui/orchard_ui.gd', 'scripts/ui/orchard_card.gd', 'scripts/ui/workplace_card.gd',
)
CASE_FIELDS = {'id', 'initial', 'initialExact', 'initialOrdered', 'operations', 'operationsExact',
               'operationsOrdered', 'results', 'resultsExact', 'expected', 'expectedExact'}
# Every family must stay represented; a silently dropped family is a coverage loss.
REQUIRED_FAMILIES = {
    'act-sweep': 20, 'advance-field': 2, 'advance-jobs': 1, 'animal-drop': 1, 'animal-drops': 2,
    'apple-limit': 1, 'apple-orchard': 1, 'buy-away': 1, 'buy-full': 1, 'buy-none': 1,
    'buy-poor': 1, 'buy-rich': 1, 'canopy-moved': 1, 'canopy-yard': 1, 'farm-cell': 1,
    'farm-defaults': 1, 'farm-garden': 1, 'farm-legacy': 1, 'farm-normalize': 22, 'flower-count': 2,
    'guide-steps': 1, 'guide-wet': 1, 'harvest-all': 5, 'harvest-reasons': 1, 'honey-covered': 1,
    'honey-far': 1, 'honey-full': 1, 'honey-stored': 1, 'honey-wild': 1, 'irrigation-empty': 1,
    'irrigation-field': 1, 'irrigation-island': 1, 'irrigation-line': 1, 'irrigation-north': 1, 'irrigation-ring': 1,
    'irrigation-west': 1, 'job-away': 5, 'job-chest': 5, 'job-collect': 10, 'job-compost': 1,
    'job-future': 1, 'job-hive': 1, 'job-poor': 5, 'job-wine_a': 1, 'job-wine_b': 1,
    'job-wrong': 5, 'life-apple': 1, 'life-berry': 1, 'life-carrot': 1, 'life-dry': 8,
    'life-flower': 1, 'life-grape': 1, 'life-mint': 1, 'life-pumpkin': 1, 'life-rosemary': 1,
    'life-tight': 8, 'starter-ended': 1, 'starter-forest': 1, 'starter-full': 1, 'starter-player_home': 1,
    'starter-supplies': 1, 'starter-village': 1, 'status-away': 1, 'status-blocked': 1, 'status-empty': 30,
    'status-field': 30, 'status-full': 1, 'status-locked': 1, 'status-no': 2, 'status-reach': 1,
    'status-tilled': 30, 'water-describe': 37, 'water-near': 12, 'water-types': 1, 'wild-grapes': 2,
}
REQUIRED_CATALOGS = {'farm', 'water'}


class FarmDataError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise FarmDataError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(data: bytes) -> bytes:
    """Git may check text out with CRLF on Windows; contracts bind the LF bytes."""
    return data.replace(b'\r\n', b'\n')


def read(root: Path, name: str) -> bytes:
    path = root / name
    require(path.is_file() and not path.is_symlink(), 'Missing or linked migration input: ' + name)
    return canonical(path.read_bytes())


def document(root: Path, name: str):
    try:
        return json.loads(read(root, name).decode('utf-8-sig'))
    except (UnicodeError, ValueError) as error:
        raise FarmDataError('Invalid JSON document: ' + name) from error


def runtime_catalog(oracle: dict) -> bytes:
    """The small catalog ordinary play loads; the full oracle is used by the equivalence proof only."""
    catalog = {'schema': 'bluemap.farm.runtime-catalog.v1', 'personalSavesUsed': False,
               'engineVersion': oracle['engineVersion'], 'orders': oracle['orders'],
               'newGame': oracle['newGame'], 'catalogsOrdered': oracle['catalogsOrdered']}
    return (json.dumps(catalog, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8')


def asset_files(root: Path) -> list[str]:
    base = root / ASSETS
    require(base.is_dir(), 'Unity farm assets are missing')
    names = sorted(path.relative_to(root).as_posix() for path in base.rglob('*') if path.is_file())
    return names + [ROUTE_CONTROLLER, ROUTE_CONTROLLER + '.meta']


def validate_oracle(oracle: dict) -> dict:
    require(isinstance(oracle, dict) and oracle.get('schema') == 'bluemap.farm.source-oracle.v1'
            and oracle.get('personalSavesUsed') is False and oracle.get('engineVersion') == '4.4.1-stable (official)'
            and oracle.get('float64Encoding') == 'ieee754-binary64-little-endian-hex',
            'Farm oracle identity, privacy or encoding differs')
    try:
        normalize_exact_mirrors(oracle)
        exact_values = validate_float64_bits(oracle)
    except (ValueError, KeyError, TypeError) as error:
        raise FarmDataError('Invalid exact/ordered farm mirrors: ' + str(error)) from error
    catalogs = oracle.get('catalogs')
    require(isinstance(catalogs, dict) and REQUIRED_CATALOGS <= set(catalogs), 'Farm catalogs are missing')
    farm, water = catalogs['farm'], catalogs['water']
    require(len(farm['crops']) == 8 and len(farm['jobs']) == 3 and farm['garden'] == [4, 29, 31, 12]
            and len(farm['sources']) > 50 and len(farm['seedBook']) == 8,
            'The original crops, jobs, garden or brook differ')
    require(len(water['types']) == 10 and len(water['maps']) == 37 and len(water['maps']['village']['rows']) == 44,
            'The original water types or maps differ')
    require(isinstance(oracle.get('fixtures'), dict) and all(name.startswith('@') for name in oracle['fixtures']),
            'Named farm fixtures are missing')
    cases = oracle.get('cases')
    require(isinstance(cases, list) and bool(cases), 'Farm cases are missing')
    ids, families, operations = set(), Counter(), 0
    for case in cases:
        require(isinstance(case, dict) and set(case) == CASE_FIELDS, 'Malformed farm case')
        require(isinstance(case['id'], str) and case['id'] not in ids, 'Duplicate farm case')
        require(isinstance(case['operations'], list) and bool(case['operations'])
                and len(case['operations']) == len(case['results']) == len(case['resultsExact']),
                'Farm operation/result coverage differs: ' + case['id'])
        ids.add(case['id'])
        families['-'.join(case['id'].split('-')[:2])] += 1
        operations += len(case['operations'])
    for family, minimum in REQUIRED_FAMILIES.items():
        require(families[family] >= minimum, 'Farm case family lost coverage: ' + family)
    require(set(families) == set(REQUIRED_FAMILIES), 'Farm case families are missing or invented')
    # Every crop, job and map keeps its own source case.
    for crop in farm['crops']:
        require({'life-' + crop, 'life-dry-' + crop, 'life-tight-' + crop, 'status-tilled-yard-' + crop} <= ids,
                'Crop lost its source case: ' + crop)
    for job in list(farm['jobs']) + ['hive']:
        require({'job-' + job, 'job-chest-' + job, 'job-collect-full-' + job} <= ids, 'Production lost its source case: ' + job)
    for name in water['maps']:
        require('water-describe-' + name in ids, 'Map lost its water description: ' + name)
    methods = oracle.get('sourceMethods')
    require(isinstance(methods, list) and len(methods) == len(set(methods)) and len(methods) >= 40,
            'Source method list differs')
    return {'cases': len(cases), 'operations': operations, 'families': dict(sorted(families.items())),
            'exactFloat64Values': exact_values, 'crops': len(farm['crops']), 'jobs': len(farm['jobs']),
            'waterTypes': len(water['types']), 'waterMaps': len(water['maps']),
            'sourceMethods': sorted(methods)}


def source_hashes(root: Path, oracle: dict) -> dict:
    manifest = document(root, SOURCE_MANIFEST)
    preserved = {row['path']: row['sha256'] for row in manifest['files']} if isinstance(manifest.get('files'), list) else None
    names = sorted(set(SOURCE_PATHS) | {method.split('::')[0] for method in oracle['sourceMethods']})
    result = {}
    for name in names:
        digest = sha256(read(root, name))
        if preserved is not None:
            require(preserved.get(name) == digest, 'Original source differs from the preserved reference: ' + name)
        result[name] = digest
    return result


def build_contract(root: Path = ROOT) -> dict:
    oracle_bytes = read(root, ORACLE)
    oracle = json.loads(oracle_bytes.decode('utf-8'))
    coverage = validate_oracle(oracle)
    return {'schema': 'bluemap.farm.source-contracts.v1', 'phase': PHASE,
            'engineVersion': oracle['engineVersion'], 'personalSavesUsed': False,
            'oracle': {'path': ORACLE, 'sha256': sha256(oracle_bytes), 'bytes': len(oracle_bytes)},
            'coverage': coverage,
            'sources': source_hashes(root, oracle),
            'recorders': {name: sha256(read(root, name)) for name in RECORDERS},
            'unityAssets': {name: sha256(read(root, name)) for name in asset_files(root)}}


def check(root: Path = ROOT) -> dict:
    contract = build_contract(root)
    stored = document(root, CONTRACT)
    require(stored == contract, 'Farm source contract differs from the current sources, recorders or Unity assets')
    oracle_bytes = read(root, ORACLE)
    require(read(root, ORACLE_RESOURCE) == oracle_bytes, 'Unity farm oracle differs from the recorded source oracle')
    require(read(root, CATALOG_RESOURCE) == runtime_catalog(json.loads(oracle_bytes.decode('utf-8'))),
            'Unity farm catalog is not derived from the recorded source oracle')
    for name in asset_files(root):
        if name.endswith('.meta'):
            continue
        meta = root / (name + '.meta')
        require(meta.is_file() and 'guid: ' in meta.read_text(encoding='utf-8'), 'Unity asset has no metadata: ' + name)
    for owner in sorted({path.parent for path in (root / ASSETS).rglob('*')} | {root / ASSETS}):
        text = Path(str(owner) + '.meta').read_text(encoding='utf-8')
        require('folderAsset: yes' in text, 'Farm folder metadata differs')
    model = read(root, ASSETS + '/Runtime/Model/FarmModel.cs').decode('utf-8')
    require('BlueMapFarmCatalog' in model and 'BlueMapFarmOracle' not in model,
            'Ordinary play must load the small catalog, never the full equivalence oracle')
    return contract


def write(root: Path = ROOT) -> dict:
    oracle_bytes = read(root, ORACLE)
    oracle = json.loads(oracle_bytes.decode('utf-8'))
    validate_oracle(oracle)
    (root / ORACLE_RESOURCE).write_bytes(oracle_bytes)
    (root / CATALOG_RESOURCE).write_bytes(runtime_catalog(oracle))
    contract = build_contract(root)
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
    except (FarmDataError, OSError, KeyError) as error:
        print('MIGRATION FARM DATA FAILED:', error, file=sys.stderr)
        return 1
    if args.report:
        args.report.write_bytes((json.dumps({'schema': 1, 'success': True, 'phase': PHASE, 'oracle': contract['oracle'],
                                             'coverage': contract['coverage'], 'sources': len(contract['sources']),
                                             'unityAssets': len(contract['unityAssets'])}, indent=1, sort_keys=True) + '\n').encode('utf-8'))
    coverage = contract['coverage']
    print(f"MIGRATION FARM DATA OK: {len(contract['sources'])} preserved sources; {coverage['cases']} cases; "
          f"{coverage['operations']} operations; {coverage['crops']} crops; {coverage['jobs']} jobs; "
          f"{coverage['waterTypes']} water types on {coverage['waterMaps']} maps")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
