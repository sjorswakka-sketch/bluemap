#!/usr/bin/env python3
"""Bind the ending, New Game+ and the way back to Godot to the preserved sources and the recorded return oracle.

The return oracle (tools/record_migration_return.py) holds, for each of the 24 recorded original saves, the hash of
the save Unity writes back and the state the real Godot 4.4.1 reached from exactly those bytes. This tool keeps the
copy ordinary play loads equal to it, and writes the reading guide that maps all 86 original test suites to the phase
that ported their subject.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PHASE = 22
CONTRACT = 'migration/phase-22/source-contracts.json'
ORACLE = 'migration/phase-22/export-oracle.json'
SAVE_ORACLE = 'migration/phase-09/save-oracle.json'
COVERAGE = 'migration/phase-22/COVERAGE.md'
BASELINE = 'migration/reference/godot-test-baseline.json'
ASSETS = 'unity/Assets/BlueMapCompletion'
ORACLE_RESOURCE = ASSETS + '/Runtime/Resources/BlueMapExportOracle.json'
SESSION = 'unity/Assets/BlueMapRoute/Runtime/Session/'
CONTROLLERS = (SESSION + 'CompletionRouteController.cs',)
SOURCE_MANIFEST = 'migration/reference/source-manifest.json'
SOURCE_PATHS = ('scripts/core/game_state.gd', 'scripts/ui/ending.gd', 'scripts/data/credits.gd', 'scripts/ui/title.gd',
                'scripts/world.gd', 'scripts/entities/enemy.gd', 'scripts/ui/menu_ui.gd')
# Which migration phase ported the subject of each original suite. A reading guide by subject: it does not claim that
# every Godot assertion was run again in Unity.
SUITES = {
    'smoke_test': (4, 5, 7), 'playthrough_test': (15, 22), 'access_points_test': (11,), 'access_storage_life_test': (11, 12),
    'adventure_integration_test': (15,), 'aim_animation_test': (8, 14), 'arena_test': (20,), 'audio_release_test': (6,),
    'boog_test': (14, 20), 'buildings_test': (6, 10), 'character_art_test': (6, 13), 'chest_loot_test': (12,),
    'coast_expedition_test': (20,), 'coast_roundtrip_test': (20,), 'coastal_adventures_test': (20,), 'coastal_combat_test': (14, 20),
    'coastal_home_test': (12, 20), 'coastal_region_test': (11, 20), 'coastal_style_prototype_test': (6,), 'coastal_styles_test': (6,),
    'combat_variety_test': (14,), 'controls_test': (8,), 'craft_progression_test': (17,), 'dagritme_test': (16, 21),
    'dauwbos_alchemie_test': (17,), 'dauwbos_route_test': (11,), 'diepte_test': (11, 20), 'doorgangen_test': (11,),
    'dorst_test': (11, 14, 20), 'echo_test': (20,), 'entry_width_test': (5, 11), 'equipment_test': (13,), 'equipment_ui_test': (13,),
    'first_route_test': (10, 16), 'flower_species_test': (19,), 'forage_locations_test': (17,), 'forest_food_species_test': (19,),
    'fountain_test': (5, 15), 'garden_phase1_test': (19,), 'gebieden_route_test': (11,), 'habitat_test': (14,),
    'homestead_test': (18, 19), 'ijsdal_test': (20,), 'kruipmoeras_test': (20,), 'lake_supper_test': (16,), 'living_combat_test': (14,),
    'living_world_test': (16,), 'loot_resource_test': (12,), 'meer_test': (11, 17), 'menu_polis_test': (21,), 'mountain_test': (20,),
    'movement_test': (8,), 'notifications_waterworks_test': (12, 20), 'opening_test': (16,), 'orchard_test': (19,), 'orchard_ui_test': (19,),
    'personal_home_test': (18,), 'personal_home_ui_test': (18,), 'polish_regression_test': (10, 21), 'professions_test': (17,),
    'progression_test': (13,), 'progression_ui_test': (13,), 'regional_test': (20,), 'release_ui_test': (21, 22), 'route_width_test': (5, 11),
    'samen_test': (14, 20, 21), 'stock_ui_test': (12,), 'stockroom_test': (12,), 'taal_test': (6, 21), 'tides_test': (11, 20),
    'ui_navigation_test': (12, 13, 21), 'uiterlijk_test': (13,), 'vegetation_access_test': (11,), 'vijanden_test': (14,),
    'visual_upgrade_test': (6,), 'water_features_test': (19,), 'wereld_test': (21,), 'whole_adventure_test': (15, 22),
    'winter_greens_test': (19,), 'work_together_test': (16,), 'workplace_ui_test': (17,), 'world_atlas_test': (21,),
    'world_memory_test': (16,), 'world_space_test': (5,), 'yard_test': (18,), 'yard_ui_test': (18,),
}
# How each phase was proven: 'opname' = replayed against a recorded Godot oracle, 'direct' = ported from the hashed
# sources and proven by native checks only.
RECORDED = {4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19}
DIRECT = {20, 21}


class CompletionDataError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise CompletionDataError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read(root: Path, name: str) -> bytes:
    path = root / name
    require(path.is_file() and not path.is_symlink(), 'Missing or linked migration input: ' + name)
    return path.read_bytes().replace(b'\r\n', b'\n')


def oracle(root: Path) -> dict:
    data = json.loads(read(root, ORACLE).decode('utf-8'))
    source = json.loads(read(root, SAVE_ORACLE).decode('utf-8'))
    require(data.get('schema') == 'bluemap.persistence.export.source-oracle.v1' and data.get('personalSavesUsed') is False
            and data.get('engineVersion') == source.get('engineVersion'), 'Unknown return oracle')
    require(data.get('sourceHashes') == source.get('sourceHashes'), 'Return oracle was recorded against other save sources')
    ids = [case['id'] for case in source['cases']]
    require([row['id'] for row in data['cases']] == ids and len(ids) == 24, 'Return oracle must cover the 24 recorded saves in order')
    for row in data['cases']:
        require(set(row) == {'id', 'sha256', 'godotAccepted', 'godotStateEqualsOriginal', 'expected', 'useLoadPosition'},
                'Malformed return case: ' + row['id'])
        require(row['godotAccepted'] is True and row['godotStateEqualsOriginal'] is True and row['useLoadPosition'] is True
                and re.fullmatch('[0-9a-f]{64}', row['sha256']) is not None and len(row['expected']) == 34,
                'Godot did not reach the same progress: ' + row['id'])
    return data


def asset_files(root: Path) -> list[str]:
    base = root / ASSETS
    require(base.is_dir(), 'Unity completion assets are missing')
    names = sorted(path.relative_to(root).as_posix() for path in base.rglob('*') if path.is_file())
    return names + [name + suffix for name in CONTROLLERS for suffix in ('', '.meta')]


def native_checks(root: Path, ids: list[str]) -> list[str]:
    runner = read(root, ASSETS + '/Runtime/Probes/CompletionProbeRunner.cs').decode('utf-8')
    export = read(root, ASSETS + '/Runtime/Export/LegacyExportChecks.cs').decode('utf-8')
    names = re.findall(r'[cC]heck\("(completion_[a-z0-9_]+)"', runner)
    fixed = re.findall(r'check\("(completion_export_[a-z0-9_]+)"[,)]', export)
    require('"completion_export_roundtrip_" + id' in export and '"completion_export_godot_loaded_" + id' in export,
            'Per-save return checks are missing')
    names += fixed + ['completion_export_roundtrip_' + i for i in ids] + ['completion_export_godot_loaded_' + i for i in ids]
    require(len(names) == len(set(names)) and len(names) == 62, 'Native completion checks are missing or duplicated')
    return sorted(names)


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


def validate_rules(root: Path) -> None:
    """The numbers of New Game+ and the credits stay those of the source."""
    source = read(root, 'scripts/core/game_state.gd').decode('utf-8')
    for rule in ('const NG_START_COINS := 100', 'const NG_HP_PER_ROUND := 0.5', 'const NG_COIN_FACTOR := 1.5'):
        require(rule in source, 'Original New Game+ rule moved: ' + rule)
    unity = read(root, CONTROLLERS[0]).decode('utf-8')
    require('NgStartCoins=100' in unity, 'Unity New Game+ start coins differ')
    credits = re.findall(r'\["(title|heading|text|)", "([^"]*)"\]', read(root, 'scripts/data/credits.gd').decode('utf-8'))
    panel = read(root, ASSETS + '/Runtime/UI/EndingPanel.cs').decode('utf-8')
    ported = re.findall(r'\("(title|heading|text|)","([^"]*)"\)', panel)
    require(len(credits) == 30 and ported == credits, 'The credits differ from the source')
    ending = read(root, 'scripts/ui/ending.gd').decode('utf-8')
    for line in re.findall(r'tr\("((?:[^"\\]|\\.)*)"\)', ending.split('pages = [')[1].split(']\n\tSound')[0]):
        require('"' + line + '"' in panel, 'An epilogue line is missing: ' + line[:40])


def suites(root: Path) -> list[dict]:
    baseline = json.loads(read(root, BASELINE).decode('utf-8'))
    names = baseline['suites']
    require(len(names) == 86 and set(names) == set(SUITES) and baseline.get('passed') == 86, 'The 86 original suites are not all placed')
    rows = []
    for name in names:
        phases = SUITES[name]
        require(all(4 <= phase <= 22 for phase in phases) and list(phases) == sorted(phases), 'Bad phase for ' + name)
        require((root / 'tests' / (name + '.gd')).is_file(), 'Original suite is gone: ' + name)
        proof = 'opname' if all(phase in RECORDED for phase in phases) else 'direct' if all(phase in DIRECT or phase == 22 for phase in phases) else 'gemengd'
        rows.append({'suite': name, 'phases': list(phases), 'proof': proof})
    return rows


def coverage_text(root: Path) -> bytes:
    rows = suites(root)
    labels = {'opname': 'Godot-opname nagespeeld', 'direct': 'rechtstreeks overgezet, controles in de speler', 'gemengd': 'deels opname, deels rechtstreeks'}
    lines = ['# Fase 22 — de 86 oorspronkelijke testsuites naast de Unity-port', '',
             'Dit is een **leeswijzer per onderwerp**. Voor elke Godot-testsuite staat hier in welke migratiefase het onderwerp',
             'van die suite is overgezet en hoe die fase is bewezen. Het is geen bewering dat elke afzonderlijke Godot-controle',
             'opnieuw in Unity is uitgevoerd: de 86 suites zelf blijven ongewijzigd bij de Godot-bron en slagen daar.', '',
             '- **Godot-opname nagespeeld**: de fase speelt opgenomen gedrag van de echte Godot 4.4.1 exact na in het Unity-model.',
             '- **rechtstreeks overgezet**: de fase is uit de op hash bewaakte bron overgezet en alleen in de Windows-speler gecontroleerd.', '',
             '| Suite | Fase(s) | Bewijs |', '|---|---|---|']
    for row in rows:
        links = ', '.join(f'[{phase}](../phase-{phase:02d}/README.md)' for phase in row['phases'])
        lines.append(f"| `{row['suite']}` | {links} | {labels[row['proof']]} |")
    counts = {key: sum(row['proof'] == key for row in rows) for key in labels}
    lines += ['', f"Totaal: {len(rows)} suites; {counts['opname']} op een Godot-opname, {counts['direct']} rechtstreeks, {counts['gemengd']} gemengd.", '']
    return '\n'.join(lines).encode('utf-8')


def build_contract(root: Path = ROOT) -> dict:
    data = oracle(root)
    validate_rules(root)
    ids = [row['id'] for row in data['cases']]
    return {'schema': 'bluemap.completion.source-contracts.v1', 'phase': PHASE, 'personalSavesUsed': False,
            'recordedOracle': True,
            'coverage': {'nativeChecks': native_checks(root, ids), 'returnCases': len(ids), 'suites': len(suites(root)),
                         'sources': len(SOURCE_PATHS), 'credits': 30},
            'returnOracle': sha256(read(root, ORACLE)), 'saveOracle': sha256(read(root, SAVE_ORACLE)),
            'coverageGuide': sha256(coverage_text(root)),
            'sources': source_hashes(root),
            'unityAssets': {name: sha256(read(root, name)) for name in asset_files(root)}}


def check(root: Path = ROOT) -> dict:
    contract = build_contract(root)
    stored = json.loads(read(root, CONTRACT).decode('utf-8'))
    require(stored == contract, 'Completion source contract differs from the current sources or Unity assets')
    require(read(root, ORACLE_RESOURCE) == read(root, ORACLE), 'Unity return oracle is not the recorded one')
    require(read(root, COVERAGE) == coverage_text(root), 'The suite reading guide is out of date')
    for name in asset_files(root):
        if not name.endswith('.meta'):
            meta = root / (name + '.meta')
            require(meta.is_file() and 'guid: ' in meta.read_text(encoding='utf-8'), 'Unity asset has no metadata: ' + name)
    return contract


def write(root: Path = ROOT) -> dict:
    (root / ORACLE_RESOURCE).parent.mkdir(parents=True, exist_ok=True)
    (root / ORACLE_RESOURCE).write_bytes(read(root, ORACLE))
    (root / COVERAGE).write_bytes(coverage_text(root))
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
    except (CompletionDataError, OSError, KeyError, ValueError) as error:
        print('MIGRATION COMPLETION DATA FAILED:', error, file=sys.stderr)
        return 1
    if args.report:
        args.report.write_bytes((json.dumps({'schema': 1, 'success': True, 'phase': PHASE, 'coverage': contract['coverage'],
                                             'unityAssets': len(contract['unityAssets'])}, indent=1, sort_keys=True) + '\n').encode('utf-8'))
    coverage = contract['coverage']
    print(f"MIGRATION COMPLETION DATA OK: {coverage['sources']} preserved sources; {len(coverage['nativeChecks'])} native checks; "
          f"{coverage['returnCases']} saves returned to Godot; {coverage['suites']} original suites placed")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
