#!/usr/bin/env python3
"""Bind the special areas and challenges to the preserved Godot sources without running either engine.

Phase 20 ports object scripts whose rules are short flag and quest sequences. They are bound here by
source hash and by the native checks that exercise them; there is no recorded oracle for this phase.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PHASE = 20
CONTRACT = 'migration/phase-20/source-contracts.json'
ASSETS = 'unity/Assets/BlueMapAreas'
SESSION = 'unity/Assets/BlueMapRoute/Runtime/Session/'
CONTROLLERS = tuple(SESSION + name for name in ('AreasRouteController.cs', 'ArenaRouteController.cs',
                                                'CoastRouteController.cs', 'BowRouteController.cs'))
SOURCE_MANIFEST = 'migration/reference/source-manifest.json'
SOURCE_PATHS = (
    'scripts/core/living_world.gd', 'scripts/core/regional_adventures.gd', 'scripts/core/marsh_waterworks.gd',
    'scripts/core/coastal_adventures.gd', 'scripts/core/coastal_home.gd', 'scripts/core/coastal_region.gd',
    'scripts/core/tides.gd', 'scripts/data/arena.gd', 'scripts/data/ext/arena.gd', 'scripts/data/ext/boog.gd',
    'scripts/data/ext/coast.gd', 'scripts/data/ext/coastal_region.gd', 'scripts/data/ext/living.gd',
    'scripts/data/ext/regional.gd', 'scripts/data/living_maps.gd', 'scripts/data/regional_maps.gd',
    'scripts/entities/living_object.gd', 'scripts/entities/regional_object.gd', 'scripts/entities/regional_adventures.gd',
    'scripts/entities/echo_trial.gd', 'scripts/entities/water_scenery.gd', 'scripts/entities/arena_master.gd',
    'scripts/entities/arena_gong.gd', 'scripts/entities/arena_board.gd', 'scripts/entities/coastal_adventure.gd',
    'scripts/entities/coastal_adventure_director.gd', 'scripts/entities/coastal_workstation.gd',
    'scripts/entities/shooting_range.gd', 'scripts/entities/target.gd', 'scripts/entities/arrow.gd',
    'scripts/ui/coastal_adventure_ui.gd', 'scripts/ui/coastal_home_ui.gd', 'scripts/ui/coast_atlas.gd',
)
# Every conversation action that used to end in a "later phase" notice now has an owner.
EXTERNAL_ACTIONS = ('living', 'regional', 'arena_enter', 'arena_cancel', 'arena_forfeit', 'ce_sail', 'rg_routes',
                    'rg_atlas', 'boog_range_start')
TARGET_KINDS = ('living_object', 'regional_object', 'echo_trial', 'arena_gong', 'arena_board', 'coastal_adventure')


class AreasDataError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise AreasDataError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read(root: Path, name: str) -> bytes:
    path = root / name
    require(path.is_file() and not path.is_symlink(), 'Missing or linked migration input: ' + name)
    return path.read_bytes().replace(b'\r\n', b'\n')


def asset_files(root: Path) -> list[str]:
    base = root / ASSETS
    require(base.is_dir(), 'Unity areas assets are missing')
    names = sorted(path.relative_to(root).as_posix() for path in base.rglob('*') if path.is_file())
    return names + [name + suffix for name in CONTROLLERS for suffix in ('', '.meta')]


def native_checks(root: Path) -> list[str]:
    runner = read(root, ASSETS + '/Runtime/Probes/AreasProbeRunner.cs').decode('utf-8')
    names = re.findall(r'[cC]heck\("(areas_[a-z0-9_]+)"', runner)
    require(len(names) == len(set(names)) and len(names) >= 18, 'Native areas checks are missing or duplicated')
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


def validate_wiring(root: Path) -> None:
    session = ''.join(read(root, name).decode('utf-8') for name in CONTROLLERS)
    controller = read(root, SESSION + 'RouteWorldController.cs').decode('utf-8')
    story = read(root, SESSION + 'StoryRouteController.cs').decode('utf-8')
    for action in EXTERNAL_ACTIONS:
        require('"' + action + '"' in session, 'Conversation action has no owner: ' + action)
    for handler in ('HandleAreaExternal', 'HandleArenaExternal', 'HandleServiceExternal'):
        require(handler + '(' in story, 'Conversation actions are not routed: ' + handler)
    for kind in TARGET_KINDS:
        require('"' + kind + '"' in controller, 'World object is not a target: ' + kind)
    for tick in ('TickAreas(delta)', 'TickArena(delta)', 'TickCoast(delta)', 'TickBow(delta)'):
        require(tick in controller, 'Area loop is not ticked: ' + tick)


def build_contract(root: Path = ROOT) -> dict:
    validate_wiring(root)
    return {'schema': 'bluemap.areas.source-contracts.v1', 'phase': PHASE, 'personalSavesUsed': False,
            'recordedOracle': False,
            'coverage': {'nativeChecks': native_checks(root), 'externalActions': list(EXTERNAL_ACTIONS),
                         'targetKinds': list(TARGET_KINDS), 'sources': len(SOURCE_PATHS)},
            'sources': source_hashes(root),
            'unityAssets': {name: sha256(read(root, name)) for name in asset_files(root)}}


def check(root: Path = ROOT) -> dict:
    contract = build_contract(root)
    stored = json.loads(read(root, CONTRACT).decode('utf-8'))
    require(stored == contract, 'Areas source contract differs from the current sources or Unity assets')
    for name in asset_files(root):
        if not name.endswith('.meta'):
            meta = root / (name + '.meta')
            require(meta.is_file() and 'guid: ' in meta.read_text(encoding='utf-8'), 'Unity asset has no metadata: ' + name)
    return contract


def write(root: Path = ROOT) -> dict:
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
    except (AreasDataError, OSError, KeyError, ValueError) as error:
        print('MIGRATION AREAS DATA FAILED:', error, file=sys.stderr)
        return 1
    if args.report:
        args.report.write_bytes((json.dumps({'schema': 1, 'success': True, 'phase': PHASE, 'coverage': contract['coverage'],
                                             'unityAssets': len(contract['unityAssets'])}, indent=1, sort_keys=True) + '\n').encode('utf-8'))
    coverage = contract['coverage']
    print(f"MIGRATION AREAS DATA OK: {coverage['sources']} preserved sources; {len(coverage['nativeChecks'])} native checks; "
          f"{len(coverage['externalActions'])} conversation actions; {len(coverage['targetKinds'])} object kinds")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
