#!/usr/bin/env python3
"""Bind professions, recipes, shops and fishing to preserved Godot methods without running either engine.

The recorded generator results are explicit inputs of the fishing cases. The
contract proves exact decisions, prices, timers and saved state at that boundary;
it does not claim Unity implements Godot's random generator.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

from record_migration_professions import normalize_exact_mirrors
from record_migration_inventory_state import validate_float64_bits

ROOT = Path(__file__).resolve().parents[1]
PHASE = 17
CONTRACT = 'migration/phase-17/source-contracts.json'
ORACLE = 'migration/phase-17/professions-oracle.json'
ASSETS = 'unity/Assets/BlueMapProfessions'
ORACLE_RESOURCE = ASSETS + '/Runtime/Model/Resources/BlueMapProfessionsOracle.json'
CATALOG_RESOURCE = ASSETS + '/Runtime/Model/Resources/BlueMapProfessionsCatalog.json'
ROUTE_CONTROLLER = 'unity/Assets/BlueMapRoute/Runtime/Session/ProfessionsRouteController.cs'
SOURCE_MANIFEST = 'migration/reference/source-manifest.json'
RECORDERS = ('tools/migration_professions_export.gd', 'tools/record_migration_professions.py',
             'tools/migration_progression_export.gd', 'tools/migration_inventory_export.gd',
             'tools/migration_route_export.gd')
SOURCE_PATHS = (
    'scripts/core/professions.gd', 'scripts/core/craft_journal.gd', 'scripts/core/craft_identity.gd',
    'scripts/core/forage_catalog.gd', 'scripts/core/stockroom.gd', 'scripts/core/living_world.gd',
    'scripts/core/equipment.gd', 'scripts/core/game_state.gd', 'scripts/data/items.gd', 'scripts/data/shops.gd',
    'scripts/data/ext/beroepen.gd', 'scripts/data/ext/craft_progression.gd', 'scripts/data/ext/flower_species.gd',
    'scripts/data/ext/forest_food_species.gd', 'scripts/data/ext/meer_vis.gd', 'scripts/data/ext/meer_logic.gd',
    'scripts/data/ext/uiterlijk.gd', 'scripts/data/ext/uitrusting.gd', 'scripts/data/orchard_catalog.gd',
    'scripts/entities/resource_node.gd', 'scripts/entities/craft_notes.gd', 'scripts/entities/meer_visplek.gd',
    'scripts/ui/crafting_ui.gd', 'scripts/ui/shop_ui.gd', 'scripts/ui/fishing_ui.gd', 'scripts/ui/fishing_reel.gd',
    'scripts/maps/registry.gd',
)
CASE_FIELDS = {'id', 'initial', 'initialExact', 'initialOrdered', 'operations', 'operationsExact',
               'operationsOrdered', 'results', 'resultsExact', 'expected', 'expectedExact'}
# Every family must stay represented; a silently dropped family is a coverage loss.
REQUIRED_FAMILIES = {
    'threshold': 14, 'skill': 200, 'record': 10, 'normalize': 24, 'dynamic': 10, 'gather': 140, 'craft': 300,
    'source': 100, 'recipes': 40, 'goal': 7, 'learn': 4, 'identity': 17, 'shop': 60, 'golden': 23, 'fish': 100,
    'sell': 6, 'reel': 40, 'fishing': 15,
}
REQUIRED_CATALOGS = {'skills', 'text', 'recipes', 'resources', 'placements', 'mapResources', 'dynamicLimits', 'notes',
                     'shops', 'consumables', 'items', 'mapNames', 'foragePlaces', 'orchard', 'fishing', 'colors',
                     'icons', 'harvestRange', 'maxLevel', 'maxXp'}
RANDOM_BOUNDARY = 'recorded-generator-results-are-explicit-inputs'


class ProfessionsDataError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ProfessionsDataError(message)


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
        raise ProfessionsDataError('Invalid JSON document: ' + name) from error


def runtime_catalog(oracle: dict) -> bytes:
    """The small catalog ordinary play loads; the full oracle is used by the equivalence proof only."""
    catalog = {'schema': 'bluemap.professions.runtime-catalog.v1', 'personalSavesUsed': False,
               'engineVersion': oracle['engineVersion'], 'orders': oracle['orders'],
               'newGame': oracle['newGame'], 'catalogsOrdered': oracle['catalogsOrdered']}
    return (json.dumps(catalog, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8')


def asset_files(root: Path) -> list[str]:
    base = root / ASSETS
    require(base.is_dir(), 'Unity professions assets are missing')
    names = sorted(path.relative_to(root).as_posix() for path in base.rglob('*') if path.is_file())
    return names + [ROUTE_CONTROLLER, ROUTE_CONTROLLER + '.meta']


def validate_oracle(oracle: dict) -> dict:
    require(isinstance(oracle, dict) and oracle.get('schema') == 'bluemap.professions.source-oracle.v1'
            and oracle.get('personalSavesUsed') is False and oracle.get('engineVersion') == '4.4.1-stable (official)'
            and oracle.get('randomBoundary') == RANDOM_BOUNDARY
            and oracle.get('float64Encoding') == 'ieee754-binary64-little-endian-hex',
            'Professions oracle identity, privacy or encoding differs')
    try:
        normalize_exact_mirrors(oracle)
        exact_values = validate_float64_bits(oracle)
    except (ValueError, KeyError, TypeError) as error:
        raise ProfessionsDataError('Invalid exact/ordered professions mirrors: ' + str(error)) from error
    catalogs = oracle.get('catalogs')
    require(isinstance(catalogs, dict) and REQUIRED_CATALOGS <= set(catalogs), 'Professions catalogs are missing')
    require(len(catalogs['skills']) == 7 and catalogs['maxLevel'] == 10 and catalogs['maxXp'] == 1350,
            'The seven original professions or their limits differ')
    cases = oracle.get('cases')
    require(isinstance(cases, list) and bool(cases), 'Professions cases are missing')
    ids, families, operations = set(), Counter(), 0
    for case in cases:
        require(isinstance(case, dict) and set(case) == CASE_FIELDS, 'Malformed professions case')
        require(isinstance(case['id'], str) and case['id'] not in ids, 'Duplicate professions case')
        require(isinstance(case['operations'], list) and bool(case['operations'])
                and len(case['operations']) == len(case['results']) == len(case['resultsExact']),
                'Professions operation/result coverage differs: ' + case['id'])
        for result in case['results']:
            require(isinstance(result, dict) and set(result) == {'value', 'toasts'}
                    and isinstance(result['toasts'], list), 'Professions result must carry its notices')
        ids.add(case['id'])
        families[case['id'].split('-')[0]] += 1
        operations += len(case['operations'])
    for family, minimum in REQUIRED_FAMILIES.items():
        require(families[family] >= minimum, 'Professions case family lost coverage: ' + family)
    require(set(families) == set(REQUIRED_FAMILIES), 'Professions case families are missing or invented')
    # Each recipe, gathering resource and shop row keeps its own source case.
    for recipe in catalogs['recipes']:
        require('craft-valid-' + recipe in ids and 'craft-twice-' + recipe in ids, 'Recipe lost its source case: ' + recipe)
    for resource in catalogs['resources']:
        require('gather-ready-' + resource in ids, 'Resource lost its source case: ' + resource)
    for shop, data in catalogs['shops'].items():
        for index in range(len(data['items'])):
            require(f'shop-buy-{shop}-{index}' in ids and f'shop-poor-{shop}-{index}' in ids,
                    'Shop row lost its source case: ' + shop)
    methods = oracle.get('sourceMethods')
    require(isinstance(methods, list) and len(methods) == len(set(methods)) and len(methods) >= 50,
            'Source method list differs')
    return {'cases': len(cases), 'operations': operations, 'families': dict(sorted(families.items())),
            'exactFloat64Values': exact_values, 'recipes': len(catalogs['recipes']),
            'resources': len(catalogs['resources']), 'shops': len(catalogs['shops']),
            'shopRows': sum(len(data['items']) for data in catalogs['shops'].values()),
            'mapResources': sum(len(rows) for rows in catalogs['mapResources'].values()),
            'placedResources': sum(len(rows) for rows in catalogs['placements'].values()),
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
    return {'schema': 'bluemap.professions.source-contracts.v1', 'phase': PHASE,
            'engineVersion': oracle['engineVersion'], 'personalSavesUsed': False, 'randomBoundary': RANDOM_BOUNDARY,
            'oracle': {'path': ORACLE, 'sha256': sha256(oracle_bytes), 'bytes': len(oracle_bytes)},
            'coverage': coverage,
            'sources': source_hashes(root, oracle),
            'recorders': {name: sha256(read(root, name)) for name in RECORDERS},
            'unityAssets': {name: sha256(read(root, name)) for name in asset_files(root)}}


def check(root: Path = ROOT) -> dict:
    contract = build_contract(root)
    stored = document(root, CONTRACT)
    require(stored == contract, 'Professions source contract differs from the current sources, recorders or Unity assets')
    oracle_bytes = read(root, ORACLE)
    require(read(root, ORACLE_RESOURCE) == oracle_bytes, 'Unity professions oracle differs from the recorded source oracle')
    require(read(root, CATALOG_RESOURCE) == runtime_catalog(json.loads(oracle_bytes.decode('utf-8'))),
            'Unity professions catalog is not derived from the recorded source oracle')
    for name in asset_files(root):
        if name.endswith('.meta'):
            continue
        meta = root / (name + '.meta')
        require(meta.is_file() and 'guid: ' in meta.read_text(encoding='utf-8'), 'Unity asset has no metadata: ' + name)
    for owner in sorted({path.parent for path in (root / ASSETS).rglob('*')} | {root / ASSETS}):
        text = Path(str(owner) + '.meta').read_text(encoding='utf-8')
        require('folderAsset: yes' in text, 'Professions folder metadata differs')
    model = read(root, ASSETS + '/Runtime/Model/ProfessionsModel.cs').decode('utf-8')
    require('BlueMapProfessionsCatalog' in model and 'BlueMapProfessionsOracle' not in model,
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
    except (ProfessionsDataError, OSError, KeyError) as error:
        print('MIGRATION PROFESSIONS DATA FAILED:', error, file=sys.stderr)
        return 1
    if args.report:
        args.report.write_bytes((json.dumps({'schema': 1, 'success': True, 'phase': PHASE, 'oracle': contract['oracle'],
                                             'coverage': contract['coverage'], 'sources': len(contract['sources']),
                                             'unityAssets': len(contract['unityAssets'])}, indent=1, sort_keys=True) + '\n').encode('utf-8'))
    coverage = contract['coverage']
    print(f"MIGRATION PROFESSIONS DATA OK: {len(contract['sources'])} preserved sources; {coverage['cases']} cases; "
          f"{coverage['operations']} operations; {coverage['recipes']} recipes; {coverage['resources']} resources; "
          f"{coverage['shopRows']} shop rows")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
