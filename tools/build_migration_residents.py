#!/usr/bin/env python3
"""Bind resident behavior to preserved Godot methods without running either engine.

Motion recordings expose random draws and collision resolution as explicit external
inputs. The contract proves exact decisions, routes and timers at that boundary;
it does not claim Unity implements Godot's random generator or physics solver.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import importlib
import json
from pathlib import Path
import re
import struct

from build_migration_player import canonical, document, no_links
from build_migration_route import SAVE_FIELDS
from build_migration_story import (CASE_FIELDS, REFERENCE_DIGESTS, declared_array,
    plain_world, check as check_story)
from migration_world_data import decode_wire
from record_migration_inventory_state import decode_ordered_input
from verify_unity_package import RESIDENTS_DETAIL_CHECKS

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = 'migration/phase-16/source-contracts.json'
ASSETS = 'unity/Assets/BlueMapResidents'
MOTION_ORACLE = 'migration/phase-16/motion-oracle.json'
SOCIAL_ORACLE = 'migration/phase-16/social-oracle.json'
MOTION_RESOURCE = ASSETS + '/Runtime/Motion/Resources/BlueMapResidentMotionOracle.json'
MOTION_CATALOG = ASSETS + '/Runtime/Motion/Resources/BlueMapResidentMotionCatalog.json'
SOCIAL_RESOURCE = ASSETS + '/Runtime/Social/Resources/BlueMapResidentSocialOracle.json'
SOCIAL_CATALOG = ASSETS + '/Runtime/Social/Resources/BlueMapResidentSocialCatalog.json'
RECORDERS = ('tools/migration_resident_motion_export.gd',
    'tools/migration_resident_motion_fixture.gd', 'tools/record_migration_resident_motion.py',
    'tools/migration_resident_social_export.gd', 'tools/record_migration_resident_social.py')
RESIDENT_SCRIPTS = {'res://scripts/entities/' + name + '.gd' for name in (
    'npc', 'route_npc', 'coast_resident', 'village_opening', 'village_actor',
    'lake_supper', 'supper_actor', 'supper_object', 'world_memory', 'memory_actor', 'memory_book')}
MOTION_METHODS = {'scripts/core/npc_roam.gd::safe', 'scripts/core/npc_roam.gd::update',
    'scripts/entities/village_actor.gd::route', 'scripts/entities/village_actor.gd::_physics_process',
    'scripts/entities/supper_actor.gd::route', 'scripts/entities/supper_actor.gd::_physics_process',
    'scripts/entities/memory_actor.gd::route', 'scripts/entities/memory_actor.gd::_physics_process',
    'scripts/entities/world_memory.gd::walk_path', 'scripts/entities/world_memory.gd::safe_spawn',
    'scripts/entities/lake_supper.gd::walk_path',
    'scripts/core/character_draw.gd::direction', 'scripts/core/character_draw.gd::frame'}
SOCIAL_METHODS = {'scripts/core/world_memory.gd::enabled', 'scripts/core/world_memory.gd::resting',
    'scripts/core/world_memory.gd::name_for', 'scripts/core/world_memory.gd::introduction',
    'scripts/core/world_memory.gd::activity', 'scripts/core/world_memory.gd::connection',
    'scripts/core/world_memory.gd::lines', 'scripts/core/world_memory.gd::meet',
    'scripts/core/world_memory.gd::news', 'scripts/core/daynight.gd::phase_at',
    'scripts/core/daynight.gd::raining', 'scripts/core/living_world.gd::migrate',
    'scripts/core/lake_supper.gd::inputs', 'scripts/core/lake_supper.gd::cook_reason',
    'scripts/core/lake_supper.gd::cook', 'scripts/core/lake_supper.gd::tracker',
    'scripts/core/lake_supper.gd::conversation', 'scripts/core/lake_supper.gd::action',
    'scripts/entities/supper_object.gd::interact', 'scripts/entities/supper_object.gd::weave',
    'scripts/entities/supper_object.gd::share', 'scripts/entities/supper_object.gd::_process',
    'scripts/entities/memory_actor.gd::interact', 'scripts/entities/memory_book.gd::interact'}
_LOADED_RESIDENT_CACHE = {}


class ResidentsDataError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise ResidentsDataError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read(root, name):
    require(isinstance(name, str) and name and not name.startswith(('/', '\\'))
            and '\\' not in name and '..' not in name.split('/'), 'Unsafe resident source path')
    path = Path(root) / name
    no_links(path)
    require(path.is_file() and path.stat().st_size <= 64 * 1024 * 1024,
            'Missing/oversized resident source: ' + name)
    return path.read_bytes().replace(b'\r\n', b'\n')


def original_catalogs(root=ROOT):
    """Read JSON-compatible constants from unchanged source, independently of the oracle."""
    source = read(root, 'scripts/core/world_memory.gd').decode('utf-8')
    start = re.search(r'^const PLACES\s*:=\s*', source, re.M)
    require(start is not None, 'Missing original resident places')
    places, _ = json.JSONDecoder().raw_decode(source[start.end():])
    require(isinstance(places, dict) and len(places) == 8, 'Original resident role coverage differs')
    for role, row in places.items():
        require(isinstance(role, str) and set(row) == {'map', 'flag', 'work', 'rest', 'frame'}
                and row['work'] and row['rest'], 'Malformed original resident place')
    dishes = declared_array(read(root, 'scripts/core/lake_supper.gd').decode('utf-8'), 'DISHES')
    require(dishes == ['ls_chowder', 'ls_broth'], 'Original supper dishes differ')
    return {'places': places, 'dishes': dishes}


def source_methods(root, methods, required):
    require(isinstance(methods, list) and all(isinstance(method, str) for method in methods)
            and len(methods) == len(set(methods)) and required <= set(methods),
            'Original resident source methods omitted/duplicated')
    for method in methods:
        require(method.count('::') == 1, 'Malformed resident source method')
        path, name = method.split('::')
        require(path.startswith('scripts/') and re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name)
                and re.search(r'\bfunc\s+' + re.escape(name) + r'\s*\(', read(root, path).decode('utf-8')),
                'Unverified original resident source method: ' + method)


def case_ids(rows):
    require(isinstance(rows, list) and rows, 'Original resident cases missing')
    ids = [row.get('id') for row in rows]
    require(all(isinstance(name, str) and re.fullmatch(r'[a-z0-9_-]{1,160}', name) for name in ids)
            and len(ids) == len(set(ids)), 'Invalid/duplicate original resident case identity')
    return ids


def motion_plain(value):
    """Decode exact typed witnesses for source-constant comparisons only."""
    if isinstance(value, dict):
        if set(value) == {'$v2'}:
            return list(struct.unpack('<ff', bytes.fromhex(value['$v2'])))
        if set(value) == {'$f64'}:
            return struct.unpack('<d', bytes.fromhex(value['$f64']))[0]
        return {key: motion_plain(child) for key, child in value.items()}
    if isinstance(value, list):
        return [motion_plain(child) for child in value]
    return value


def motion_coverage(value, original, root=ROOT):
    recorder = importlib.import_module('record_migration_resident_motion')
    recorder.validate_document(value)
    require(value.get('engineVersion') == '4.4.1-stable (official)', 'Original motion engine differs')
    require(value.get('randomPolicy') == 'original global random draws are explicit exogenous inputs; no cross-engine RNG sequence claim'
            and value.get('physicsPolicy') == 'original collision-resolved position and velocity are explicit external boundaries; route, velocity, timers and decisions replay exactly',
            'Resident motion external boundary policy differs')
    require(canonical(motion_plain(value.get('catalog'))) == canonical({'places': original['places']}),
            'Original resident motion catalog changed')
    ids = case_ids(value['cases'])
    source_methods(root, value.get('sourceMethods'), MOTION_METHODS)
    families = Counter(row['kind'] for row in value['cases'])
    return {'cases': len(ids), 'caseIds': ids, 'families': dict(sorted(families.items())),
            'sourceMethods': value['sourceMethods'], 'roles': len(original['places']),
            'exactNumericValues': recorder.validate_numeric_witnesses(value),
            'comparisonPolicy': recorder.COMPARISON_POLICY,
            'randomDrawsAreExternalInputs': True, 'collisionResolutionIsExternalInput': True}


def validate_social_observations(rows, normalized_rows):
    require(len(rows) == len(normalized_rows), 'Resident social normalized case count differs')
    for row, exact_row in zip(rows, normalized_rows, strict=True):
        require(set(row) == CASE_FIELDS and set(row['initial']) == set(row['expected']) == SAVE_FIELDS,
                'Resident social save state fields differ')
        observations = exact_row['observations']
        require(row['operations'] and len(row['operations']) == len(row['results']) == len(observations),
                'Resident social per-operation observations missing')
        previous_events = []
        for observation in observations:
            require(isinstance(observation, dict) and set(observation) == {'state', 'view', 'events'}
                    and set(observation['state']) == SAVE_FIELDS and isinstance(observation['view'], dict)
                    and isinstance(observation['events'], list), 'Resident social actuator/state/event evidence missing')
            require(observation['events'][:len(previous_events)] == previous_events,
                    'Resident social signal ordering is not cumulative')
            previous_events = observation['events']
        require(observations[-1]['state'] == exact_row['expected'], 'Resident social final observation/state differs')


def social_coverage(value, original, root=ROOT):
    recorder = importlib.import_module('record_migration_resident_social')
    normalized = recorder.validate_document(value)
    require(value.get('engineVersion') == '4.4.1-stable (official)'
            and value.get('float64Encoding') == 'ieee754-binary64-little-endian-hex'
            and value.get('orderedInputEncoding') == 'dictionary-pairs-and-exact-f64-v1',
            'Original resident social engine/encoding differs')
    catalogs = decode_ordered_input(value['catalogsOrdered'])
    roles = catalogs.get('roles')
    require(isinstance(roles, dict) and set(roles) == set(original['places']), 'Original resident social roles differ')
    for role, row in original['places'].items():
        require(all(roles[role].get(key) == child for key, child in row.items()),
                'Original resident social place changed: ' + role)
    require(set(value['newGame']) == SAVE_FIELDS
            and value['newGame'] == document(read(root, 'migration/phase-13/progression-oracle.json'),
                                             'original resident new game')['newGame'],
            'Original resident new-game fields/defaults differ')
    ids = case_ids(value['cases'])
    required = {'memory-' + locale + '-' + role for locale in ('nl', 'en') for role in original['places']}
    required.update(prefix + locale for locale in ('nl', 'en') for prefix in (
        'memory-all-', 'basket-', 'basket-no-rod-', 'basket-noisy-', 'net-', 'kitchen-context-', 'net-xp-level-'))
    required.update(prefix + locale + '-' + dish for locale in ('nl', 'en') for dish in original['dishes']
                    for prefix in ('cook-gates-', 'meal-', 'repeat-cook-'))
    required.add('recovery-tracker')
    require(required <= set(ids), 'Original resident social core case families omitted')
    for prefix in ('clock-', 'legacy-', 'opening-', 'connection-', 'village-director-', 'memory-book-', 'memory-actor-'):
        require(any(name.startswith(prefix) for name in ids), 'Original resident social family omitted: ' + prefix)
    validate_social_observations(value['cases'], normalized['cases'])
    source_methods(root, value.get('sourceMethods'), SOCIAL_METHODS)
    return {'cases': len(ids), 'caseIds': ids, 'roles': len(roles), 'dishes': original['dishes'],
            'sourceMethods': value['sourceMethods'], 'saveFields': sorted(SAVE_FIELDS),
            'exactFloat64Values': recorder.validate_float64_bits(value),
            'dictionaryInputOrderPreserved': True, 'cumulativeOrderedSignals': True}


def validate_runtime_catalog(value, ordered_catalogs, digest):
    require(isinstance(value, dict) and set(value) == {'schema', 'sourceOracleSha256', 'personalSavesUsed', 'catalogsOrdered'}
            and value['schema'] == 'bluemap.resident-social.catalog.v1' and value['personalSavesUsed'] is False,
            'Bounded resident runtime catalog schema/privacy differs')
    require(value['sourceOracleSha256'] == digest, 'Resident runtime catalog source hash differs')
    require(canonical(value['catalogsOrdered']) == canonical(ordered_catalogs),
            'Resident runtime catalog is not the exact lossless original catalog projection')


def validate_motion_catalog(value, source_catalog):
    require(isinstance(value, dict) and set(value) == {'schema', 'catalog'}
            and value['schema'] == 'bluemap.resident-motion.catalog.v1', 'Bounded resident motion catalog schema differs')
    require(canonical(value['catalog']) == canonical(source_catalog),
            'Resident motion catalog is not the exact original catalog projection')


def loaded_residents(root=ROOT):
    """Keep original actor/director identities and positions in every loaded variant."""
    world = document(read(root, 'migration/world/index.json'), 'frozen loaded resident world')
    require(len(world['snapshots']) == 162 and len({row['mapId'] for row in world['snapshots']}) == 37,
            'Original loaded resident world coverage incomplete')
    result = []
    for row in world['snapshots']:
        raw = read(root, 'migration/world/' + row['path'])
        digest = sha(raw)
        require(digest == row['sha256'] and len(raw) == row['bytes'], 'Original loaded resident scene changed')
        if digest not in _LOADED_RESIDENT_CACHE:
            nodes = []
            for node in document(raw, row['path'])['scene']:
                if node.get('script') not in RESIDENT_SCRIPTS:
                    continue
                fields = decode_wire(node['fields'])
                selected = {key: plain_world(fields[key]) for key in (
                    'obj', 'data', 'kind', 'id', 'role', 'key', 'npc_id', 'exists_if', 'conditions',
                    'actions', 'roam_anchor', 'route_key', 'rest', 'evening') if key in fields}
                nodes.append({'address': node['address'], 'script': node['script'], 'fields': selected,
                    'position': [float(part['value']) for part in node['localTransform']['origin']['values']]})
            _LOADED_RESIDENT_CACHE[digest] = nodes
        result.append({'map': row['mapId'], 'scenario': row['scenarioId'], 'snapshotSha256': digest,
                       'objects': _LOADED_RESIDENT_CACHE[digest]})
    return result


def asset_guids(root=ROOT):
    base = Path(root) / ASSETS
    no_links(base)
    require(base.is_dir(), 'Native resident assets missing')
    result, seen, covered = [], set(), set()
    for owner in [base, *sorted(path for path in base.rglob('*') if path.suffix != '.meta')]:
        no_links(owner)
        meta = owner.with_name(owner.name + '.meta')
        text = read(root, meta.relative_to(root).as_posix()).decode('utf-8-sig')
        found = re.findall(r'^guid: ([0-9a-f]{32})$', text, re.M)
        require(len(found) == len(re.findall(r'^guid:', text, re.M)) == 1 and found[0] not in seen,
                'Missing/duplicate resident asset GUID: ' + owner.relative_to(root).as_posix())
        require(('folderAsset: yes' in text) == owner.is_dir(), 'Resident folder metadata differs')
        seen.add(found[0]); covered.add(meta)
        result.append({'path': owner.relative_to(root).as_posix(), 'guid': found[0]})
    require(all(meta.with_suffix('').exists() for meta in base.rglob('*.meta')), 'Orphan resident metadata')
    for meta in (Path(root) / 'unity/Assets').rglob('*.meta'):
        if meta not in covered:
            no_links(meta)
            require(not seen.intersection(re.findall(r'^guid: ([0-9a-f]{32})$', meta.read_text(encoding='utf-8-sig'), re.M)),
                    'Resident GUID collides with preserved native asset')
    return result


def build_contract(root=ROOT):
    root = Path(root)
    require(RESIDENTS_DETAIL_CHECKS, 'Resident callback contract is not frozen')
    for name, digest in REFERENCE_DIGESTS.items():
        require(sha(read(root, name)) == digest, 'Previously verified reference changed: ' + name)
    check_story(root)
    baseline = document(read(root, 'migration/reference/source-manifest.json'), 'original frozen resident source')
    require(baseline['commit'] == 'a8a988be27835dec979d2523a3a85a34385eac54'
            and baseline['tree'] == '73ba02ea4db0a1c920360b6570f5209ccb970143', 'Original resident source identity changed')
    anchors = []
    for entry in baseline['files']:
        name = entry['path']
        if not name.startswith(('scripts/', 'scenes/')) or not name.endswith(('.gd', '.tscn')):
            continue
        raw = read(root, name)
        require(sha(raw) == entry['sha256'] and len(raw) == entry['bytes'], 'Original resident source changed: ' + name)
        anchors.append({'path': name, 'bytes': len(raw), 'sha256': sha(raw), 'gitBlob': entry['git_blob']})
    original = original_catalogs(root)
    motion_raw, social_raw = read(root, MOTION_ORACLE), read(root, SOCIAL_ORACLE)
    motion, social = document(motion_raw, MOTION_ORACLE), document(social_raw, SOCIAL_ORACLE)
    motion_summary, social_summary = motion_coverage(motion, original, root), social_coverage(social, original, root)
    require(read(root, MOTION_RESOURCE) == motion_raw and read(root, SOCIAL_RESOURCE) == social_raw,
            'Native resident oracle differs from original methods')
    catalog_raw = read(root, SOCIAL_CATALOG)
    validate_runtime_catalog(document(catalog_raw, SOCIAL_CATALOG), social['catalogsOrdered'], sha(social_raw))
    motion_catalog_raw = read(root, MOTION_CATALOG)
    validate_motion_catalog(document(motion_catalog_raw, MOTION_CATALOG), motion['catalog'])
    loaded = loaded_residents(root)
    return {'schema': 'bluemap.residents.source-contracts.v1', 'phase': 16,
        'baselineCommit': baseline['commit'], 'baselineTree': baseline['tree'], 'sourceAnchors': anchors,
        'motion': {'sourcePath': MOTION_ORACLE, 'resourcePath': MOTION_RESOURCE, 'sha256': sha(motion_raw),
                   'bytes': len(motion_raw), 'coverage': motion_summary},
        'social': {'sourcePath': SOCIAL_ORACLE, 'resourcePath': SOCIAL_RESOURCE, 'sha256': sha(social_raw),
                   'bytes': len(social_raw), 'coverage': social_summary},
        'runtimeCatalog': {'path': SOCIAL_CATALOG, 'sha256': sha(catalog_raw), 'bytes': len(catalog_raw),
                           'sourceOracleSha256': sha(social_raw), 'purpose': 'Lossless resident gameplay catalog; full oracle loaded only for native equivalence proof'},
        'motionCatalog': {'path': MOTION_CATALOG, 'sha256': sha(motion_catalog_raw), 'bytes': len(motion_catalog_raw),
                          'sourceOracleSha256': sha(motion_raw), 'purpose': 'Exact original route places; full motion oracle loaded only for native equivalence proof'},
        'originalResidentCatalogs': original, 'loadedResidentObjects': loaded,
        'world': {'maps': 37, 'snapshots': len(loaded), 'loadedObjects': sum(len(row['objects']) for row in loaded),
                  'indexSha256': REFERENCE_DIGESTS['migration/world/index.json']},
        'previousStoryContractSha256': sha(read(root, 'migration/phase-15/source-contracts.json')),
        'frozenReferenceFiles': [{'path': name, 'sha256': digest} for name, digest in REFERENCE_DIGESTS.items()],
        'recorders': [{'path': name, 'sha256': sha(read(root, name))} for name in RECORDERS],
        'assetGuids': asset_guids(root), 'requiredNativeChecks': sorted(RESIDENTS_DETAIL_CHECKS),
        'enginesStarted': False, 'personalSavesUsed': False}


def check(root=ROOT):
    value = build_contract(root)
    require(read(root, CONTRACT) == canonical(value), 'Stale/corrupt resident source contracts')
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    value = check() if args.check else build_contract()
    if not args.check:
        target = ROOT / CONTRACT
        no_links(target); target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(canonical(value))
    if args.report:
        no_links(args.report)
        require(not args.report.exists() and not args.report.resolve().is_relative_to(ROOT), 'Use fresh external resident evidence')
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(canonical({'success': True, **value}))
    print('MIGRATION RESIDENTS DATA OK:', len(value['sourceAnchors']), 'preserved sources;',
          value['motion']['coverage']['cases'], 'motion;', value['social']['coverage']['cases'], 'social cases')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit('MIGRATION RESIDENTS DATA FAILED: ' + str(error))
