#!/usr/bin/env python3
"""Bind the house and yard designers to preserved Godot methods without running either engine.

The contract proves exact placement reasons, reachability, costs and saved state.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

from record_migration_home import normalize_exact_mirrors
from record_migration_inventory_state import validate_float64_bits

ROOT = Path(__file__).resolve().parents[1]
PHASE = 18
CONTRACT = 'migration/phase-18/source-contracts.json'
ORACLE = 'migration/phase-18/home-oracle.json'
ASSETS = 'unity/Assets/BlueMapHome'
ORACLE_RESOURCE = ASSETS + '/Runtime/Model/Resources/BlueMapHomeOracle.json'
CATALOG_RESOURCE = ASSETS + '/Runtime/Model/Resources/BlueMapHomeCatalog.json'
ROUTE_CONTROLLER = 'unity/Assets/BlueMapRoute/Runtime/Session/HomeRouteController.cs'
SOURCE_MANIFEST = 'migration/reference/source-manifest.json'
RECORDERS = ('tools/migration_home_export.gd', 'tools/record_migration_home.py', 'tools/record_migration_professions.py',
             'tools/migration_progression_export.gd', 'tools/migration_inventory_export.gd',
             'tools/migration_route_export.gd')
SOURCE_PATHS = (
    'scripts/core/personal_home.gd', 'scripts/core/yard.gd', 'scripts/core/stockroom.gd', 'scripts/core/game_state.gd',
    'scripts/core/house_art.gd', 'scripts/core/yard_art.gd', 'scripts/data/house_catalog.gd', 'scripts/data/yard_catalog.gd',
    'scripts/data/orchard_catalog.gd', 'scripts/data/tiles.gd', 'scripts/data/items.gd', 'scripts/data/homestead_maps.gd',
    'scripts/maps/player_home.gd', 'scripts/maps/village.gd', 'scripts/maps/registry.gd',
    'scripts/entities/home_station.gd', 'scripts/entities/house_furniture.gd', 'scripts/entities/personal_house.gd',
    'scripts/entities/yard_fence.gd', 'scripts/entities/yard_scenery.gd',
    'scripts/ui/home_ui.gd', 'scripts/ui/house_ui.gd', 'scripts/ui/house_plan.gd', 'scripts/ui/yard_ui.gd', 'scripts/ui/yard_plan.gd',
)
CASE_FIELDS = {'id', 'initial', 'initialExact', 'initialOrdered', 'operations', 'operationsExact',
               'operationsOrdered', 'results', 'resultsExact', 'expected', 'expectedExact'}
# Every family must stay represented; a silently dropped family is a coverage loss.
REQUIRED_FAMILIES = {
    'house-defaults': 1, 'house-normalize': 11, 'house-legacy': 1, 'house-place': 13, 'house-crowded': 5,
    'house-layout': 21, 'house-next': 26, 'house-make': 49, 'house-trophy': 2, 'house-player': 1, 'house-world': 6,
    'house-apply': 10, 'yard-defaults': 1, 'yard-place': 6, 'yard-station': 12, 'yard-piece': 14, 'yard-layout': 10,
    'yard-normalize': 8, 'yard-schema': 7, 'yard-work': 2, 'yard-actor': 1, 'yard-make': 23, 'yard-expand': 9,
    'yard-apply': 10,
}
REQUIRED_CATALOGS = {'house', 'yard', 'itemNames'}


class HomeDataError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise HomeDataError(message)


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
        raise HomeDataError('Invalid JSON document: ' + name) from error


def runtime_catalog(oracle: dict) -> bytes:
    """The small catalog ordinary play loads; the full oracle is used by the equivalence proof only."""
    catalog = {'schema': 'bluemap.home.runtime-catalog.v1', 'personalSavesUsed': False,
               'engineVersion': oracle['engineVersion'], 'orders': oracle['orders'],
               'newGame': oracle['newGame'], 'catalogsOrdered': oracle['catalogsOrdered']}
    return (json.dumps(catalog, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8')


def asset_files(root: Path) -> list[str]:
    base = root / ASSETS
    require(base.is_dir(), 'Unity home assets are missing')
    names = sorted(path.relative_to(root).as_posix() for path in base.rglob('*') if path.is_file())
    return names + [ROUTE_CONTROLLER, ROUTE_CONTROLLER + '.meta']


def validate_oracle(oracle: dict) -> dict:
    require(isinstance(oracle, dict) and oracle.get('schema') == 'bluemap.home.source-oracle.v1'
            and oracle.get('personalSavesUsed') is False and oracle.get('engineVersion') == '4.4.1-stable (official)'
            and oracle.get('float64Encoding') == 'ieee754-binary64-little-endian-hex',
            'Home oracle identity, privacy or encoding differs')
    try:
        normalize_exact_mirrors(oracle)
        exact_values = validate_float64_bits(oracle)
    except (ValueError, KeyError, TypeError) as error:
        raise HomeDataError('Invalid exact/ordered home mirrors: ' + str(error)) from error
    catalogs = oracle.get('catalogs')
    require(isinstance(catalogs, dict) and REQUIRED_CATALOGS <= set(catalogs), 'Home catalogs are missing')
    house, yard = catalogs['house'], catalogs['yard']
    require(len(house['pieces']) == 13 and house['maxPieces'] == 12 and house['room'] == [2, 2, 10, 10],
            'The original furniture pieces or room limits differ')
    require(len(yard['units']) == 4 and len(yard['pieces']) == 7 and len(yard['extensions']) == 2
            and yard['maxPaths'] == 80 and yard['maxFences'] == 40 and len(yard['rows']) == 44,
            'The original yard units, pieces or limits differ')
    require(isinstance(oracle.get('fixtures'), dict) and all(name.startswith('@') for name in oracle['fixtures']),
            'Named home fixtures are missing')
    cases = oracle.get('cases')
    require(isinstance(cases, list) and bool(cases), 'Home cases are missing')
    ids, families, operations = set(), Counter(), 0
    for case in cases:
        require(isinstance(case, dict) and set(case) == CASE_FIELDS, 'Malformed home case')
        require(isinstance(case['id'], str) and case['id'] not in ids, 'Duplicate home case')
        require(isinstance(case['operations'], list) and bool(case['operations'])
                and len(case['operations']) == len(case['results']) == len(case['resultsExact']),
                'Home operation/result coverage differs: ' + case['id'])
        ids.add(case['id'])
        families['-'.join(case['id'].split('-')[:2])] += 1
        operations += len(case['operations'])
    for family, minimum in REQUIRED_FAMILIES.items():
        require(families[family] >= minimum, 'Home case family lost coverage: ' + family)
    require(set(families) == set(REQUIRED_FAMILIES), 'Home case families are missing or invented')
    # Every furniture piece, yard part and work station keeps its own placement sweep.
    for piece in house['pieces']:
        require('house-place-' + piece in ids and 'house-make-stocked-' + piece in ids, 'Furniture lost its source case: ' + piece)
    for piece in yard['pieces']:
        require('yard-piece-' + piece + '-both' in ids, 'Yard part lost its source case: ' + piece)
    for unit in yard['units']:
        require('yard-station-' + unit + '-both' in ids, 'Work station lost its source case: ' + unit)
    for extension in yard['extensions']:
        require('yard-expand-' + extension in ids, 'Yard extension lost its source case: ' + extension)
    methods = oracle.get('sourceMethods')
    require(isinstance(methods, list) and len(methods) == len(set(methods)) and len(methods) >= 40,
            'Source method list differs')
    return {'cases': len(cases), 'operations': operations, 'families': dict(sorted(families.items())),
            'exactFloat64Values': exact_values, 'furniture': len(house['pieces']), 'yardPieces': len(yard['pieces']),
            'workStations': len(yard['units']), 'extensions': len(yard['extensions']),
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
    return {'schema': 'bluemap.home.source-contracts.v1', 'phase': PHASE,
            'engineVersion': oracle['engineVersion'], 'personalSavesUsed': False,
            'oracle': {'path': ORACLE, 'sha256': sha256(oracle_bytes), 'bytes': len(oracle_bytes)},
            'coverage': coverage,
            'sources': source_hashes(root, oracle),
            'recorders': {name: sha256(read(root, name)) for name in RECORDERS},
            'unityAssets': {name: sha256(read(root, name)) for name in asset_files(root)}}


def check(root: Path = ROOT) -> dict:
    contract = build_contract(root)
    stored = document(root, CONTRACT)
    require(stored == contract, 'Home source contract differs from the current sources, recorders or Unity assets')
    oracle_bytes = read(root, ORACLE)
    require(read(root, ORACLE_RESOURCE) == oracle_bytes, 'Unity home oracle differs from the recorded source oracle')
    require(read(root, CATALOG_RESOURCE) == runtime_catalog(json.loads(oracle_bytes.decode('utf-8'))),
            'Unity home catalog is not derived from the recorded source oracle')
    for name in asset_files(root):
        if name.endswith('.meta'):
            continue
        meta = root / (name + '.meta')
        require(meta.is_file() and 'guid: ' in meta.read_text(encoding='utf-8'), 'Unity asset has no metadata: ' + name)
    for owner in sorted({path.parent for path in (root / ASSETS).rglob('*')} | {root / ASSETS}):
        text = Path(str(owner) + '.meta').read_text(encoding='utf-8')
        require('folderAsset: yes' in text, 'Home folder metadata differs')
    model = read(root, ASSETS + '/Runtime/Model/HomeModel.cs').decode('utf-8')
    require('BlueMapHomeCatalog' in model and 'BlueMapHomeOracle' not in model,
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
    except (HomeDataError, OSError, KeyError) as error:
        print('MIGRATION HOME DATA FAILED:', error, file=sys.stderr)
        return 1
    if args.report:
        args.report.write_bytes((json.dumps({'schema': 1, 'success': True, 'phase': PHASE, 'oracle': contract['oracle'],
                                             'coverage': contract['coverage'], 'sources': len(contract['sources']),
                                             'unityAssets': len(contract['unityAssets'])}, indent=1, sort_keys=True) + '\n').encode('utf-8'))
    coverage = contract['coverage']
    print(f"MIGRATION HOME DATA OK: {len(contract['sources'])} preserved sources; {coverage['cases']} cases; "
          f"{coverage['operations']} operations; {coverage['furniture']} furniture pieces; {coverage['yardPieces']} yard parts; "
          f"{coverage['workStations']} work stations")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
