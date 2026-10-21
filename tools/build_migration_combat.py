#!/usr/bin/env python3
"""Bind both original combat oracles to preserved definitions, loaded actors and native proof."""
from __future__ import annotations

import argparse
import hashlib
import importlib
import json
from pathlib import Path
import re
import struct

from build_migration_player import canonical, document, no_links
from build_migration_route import SAVE_FIELDS
from build_migration_progression import (PORTABLE_MANIFEST_SHA256, source_dictionary, dictionary_keys,
                                         portable_plain, balanced_dictionary, json_dictionary, check as check_progression)
from migration_data_codec import decode
from migration_world_data import decode_wire, WireDictionary, WireValue
from record_migration_inventory_state import normalize_exact_mirrors as normalize_pairs, validate_float64_bits
from verify_unity_package import COMBAT_DETAIL_CHECKS

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = 'migration/phase-14/source-contracts.json'
ASSETS = 'unity/Assets/BlueMapCombat'
ROUTE_ASSETS = ('unity/Assets/BlueMapRoute/Runtime/Session/CombatRouteController.cs',
                'unity/Assets/BlueMapRoute/Runtime/Session/CombatTraining.cs')
ORACLES = {
    'combat': ('migration/phase-14/combat-oracle.json',
               ASSETS + '/Runtime/Model/Resources/BlueMapCombatOracle.json', 'record_migration_combat'),
    'encounter': ('migration/phase-14/encounter-oracle.json',
                  ASSETS + '/Runtime/Encounter/Resources/BlueMapEncounterOracle.json', 'record_migration_encounter'),
}
REFERENCE_DIGESTS = {
    'migration/reference/source-manifest.json': '5300a24edd771f0c94566a3255fffa798a2daf654419960d22c3703d8533d5d6',
    'migration/reference/maps-inventory.json': '3b6e3818d720f501dbcce09252919f7c76f2814a651a5fba796a322767cfb207',
    'migration/world/index.json': 'd986a9a8ad3a03e2c5a5b9fb98e0622dbca76f950f52d35d756f611410af4743',
    'migration/portable/manifest.json': PORTABLE_MANIFEST_SHA256,
    'migration/phase-13/progression-oracle.json': '66a9c0b04ff396b2cf88138d378bceadfe0b76af0cfe7b7aeda533757ab8e31b',
}
RECORDERS = ('tools/migration_combat_export.gd', 'tools/record_migration_combat.py',
             'tools/migration_combat_player_fixture.gd',
             'tools/migration_encounter_export.gd', 'tools/record_migration_encounter.py',
             'tools/migration_progression_export.gd', 'tools/record_migration_progression.py',
             'tools/migration_inventory_export.gd', 'tools/record_migration_inventory_state.py',
             'tools/migration_route_export.gd', 'tools/migration_world_scenarios.gd')
COMBAT_FIELDS = {'id', 'initial', 'initialExact', 'initialOrdered', 'operations', 'operationsExact',
                 'operationsOrdered', 'results', 'resultsExact', 'expected', 'expectedExact',
                 'transient', 'transientExact', 'transientOrdered', 'initialPlayer', 'initialPlayerExact', 'initialPlayerOrdered'}
CONST_SOURCES = {name: 'scripts/entities/' + name + '.gd' for name in
                 ('player', 'arrow', 'projectile', 'guardian', 'combat_enemy', 'living_enemy',
                  'coastal_enemy', 'habitat_enemy', 'route_enemy', 'echo_enemy', 'guardian_pillar', 'guardian_shard')}
ACTOR_SCRIPTS = {'res://scripts/entities/enemy.gd', 'res://scripts/entities/guardian.gd'}
_SCENES = {}


class CombatDataError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise CombatDataError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read(root, name):
    require(isinstance(name, str) and name and not name.startswith(('/', '\\')) and '\\' not in name
            and '..' not in name.split('/'), 'Unsafe combat source path')
    path = Path(root) / name
    no_links(path)
    require(path.is_file() and path.stat().st_size <= 64 * 1024 * 1024, 'Missing/oversized combat source: ' + name)
    return path.read_bytes().replace(b'\r\n', b'\n')


def f32(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]


def actor_wire(value):
    if isinstance(value, WireDictionary):
        return {key: actor_wire(child) for key, child in value.items()}
    if isinstance(value, WireValue):
        require(value.type in ('Vector2', 'Vector2i', 'Color'), 'Unexpected original actor value type')
        return [int(part) for part in value.value] if value.type == 'Vector2i' else [f32(part) for part in value.value]
    if isinstance(value, list):
        return [actor_wire(child) for child in value]
    return value


def original_constants(root, path, declarations):
    """Read only source literals and already frozen complex values; never execute GDScript."""
    text = read(root, path).decode('utf-8')
    result = {}
    for match in re.finditer(r'^const\s+(\w+)(?:\s*:\s*[^=\n]+?)?\s*:?=\s*(.+)$', text, re.M):
        key, expression = match.groups()
        expression = expression.strip()
        if expression.startswith(('preload(', 'load(')):
            continue
        frozen = declarations.get(('res://' + path, key))
        if frozen is not None:
            result[key] = portable_plain(frozen)
            continue
        if expression.startswith('Color('):
            args = expression[6:expression.index(')')]
            values = json.loads('[' + args + ']')
            require(len(values) in (3, 4) and all(type(value) in (int, float) for value in values),
                    'Unsupported original Color literal: ' + path + '/' + key)
            result[key] = [f32(value) for value in [*values, 1.0][:4]]
        elif expression.startswith('Vector2('):
            args = expression[8:expression.index(')')]
            values = json.loads('[' + args + ']')
            require(len(values) == 2 and all(type(value) in (int, float) for value in values),
                    'Unsupported original Vector2 literal')
            result[key] = [f32(value) for value in values]
        else:
            value, _ = json.JSONDecoder().raw_decode(expression)
            require(type(value) in (str, int, float, bool, type(None)),
                    'Original complex constant has no frozen declaration: ' + path + '/' + key)
            result[key] = value
    return result


def actor_projection(raw):
    digest = sha(raw)
    if digest in _SCENES:
        return _SCENES[digest]
    value = document(raw, 'preserved actor scene')
    result = []
    for node in value['scene']:
        if node.get('script') not in ACTOR_SCRIPTS:
            continue
        fields = decode_wire(node['fields'])
        address = node['address']
        require(len(address) == 2 and address[0] == 'entities' and type(address[1]) is int,
                'Original actor address is incomplete')
        row = {'script': node['script'], 'kind': fields.get('kind'), 'uniqueFlag': fields.get('unique_flag'),
               'position': [float(part['value']) for part in node['localTransform']['origin']['values']],
               'hp': fields.get('hp'), 'maxHp': fields.get('max_hp'), 'radius': fields.get('radius'),
               'active': fields.get('active'), 'data': actor_wire(fields.get('data')),
               'obj': actor_wire(fields.get('obj')) if node['script'].endswith('/guardian.gd') else {},
               'practice': False, 'sourceAddress': [1, address[1]]}
        result.append(row)
    if len(_SCENES) >= 162:
        _SCENES.clear()
    _SCENES[digest] = result
    return result


def original_references(root):
    manifest = document(read(root, 'migration/portable/manifest.json'), 'immutable portable manifest')
    require(sha(read(root, 'migration/portable/manifest.json')) == PORTABLE_MANIFEST_SHA256,
            'Original portable manifest changed')
    documents = {row['path']: row for row in manifest['documents']}
    hashes, declarations, catalogs = [], {}, {}
    for relative, frozen in documents.items():
        if not relative.startswith('declarations/') and relative not in (
                'catalogs/enemies.json', 'catalogs/weapons.json', 'catalogs/gear.json'):
            continue
        path = 'migration/portable/' + relative
        raw = read(root, path)
        require(sha(raw) == frozen['sha256'] and len(raw) == frozen['bytes'], 'Frozen original definition changed: ' + relative)
        value = decode(document(raw, path))
        hashes.append({'path': path, 'sha256': sha(raw), 'bytes': len(raw)})
        if relative.startswith('declarations/'):
            for row in value:
                source = row['source']
                key = (source['path'], source['constant'])
                require(key not in declarations, 'Duplicate original declaration')
                declarations[key] = row['value']
        else:
            require(value['count'] == len(value['entries']), 'Original combat catalog incomplete')
            catalogs[relative.split('/')[-1][:-5]] = {row['id']: portable_plain(row['value']) for row in value['entries']}
    constants = {name: original_constants(root, path, declarations) for name, path in CONST_SOURCES.items()}
    techniques = portable_plain(declarations[('res://scripts/entities/combat_actions.gd', 'PROFILES')])
    order = dictionary_keys(source_dictionary(read(root, 'scripts/data/enemies.gd').decode('utf-8'), 'BASE_ENEMIES'))
    weapon_order = dictionary_keys(source_dictionary(read(root, 'scripts/data/items.gd').decode('utf-8'), 'BASE_WEAPONS'))
    content = read(root, 'scripts/data/content.gd').decode('utf-8')
    modules = re.findall(r'^\s*preload\("res://([^"\n]+)"\)', content, re.M)
    for path in modules:
        text = read(root, path).decode('utf-8')
        if re.search(r'^const\s+ENEMIES\s*:?=', text, re.M):
            order.extend(dictionary_keys(source_dictionary(text, 'ENEMIES')))
        if re.search(r'^const\s+WEAPONS\s*:?=', text, re.M):
            weapon_order.extend(dictionary_keys(source_dictionary(text, 'WEAPONS')))
    require(len(order) == len(set(order)) and set(order) == set(catalogs['enemies']),
            'Original merged enemy dictionary order differs')
    require(len(weapon_order) == len(set(weapon_order)) and set(weapon_order) == set(catalogs['weapons']),
            'Original weapon insertion order differs')
    over_tiles = list(constants['arrow']['OVER'])
    for path in modules:
        for tile in declarations.get(('res://' + path, 'ARROW_OVER'), []):
            if tile not in over_tiles:
                over_tiles.append(tile)
    combat_source = read(root, 'scripts/entities/combat_actions.gd').decode('utf-8')
    match = re.search(r'var result[^\n]*?(\{"name":"Precisieschot")', combat_source)
    require(match is not None, 'Original bow technique literal missing')
    bow_profile = json_dictionary(balanced_dictionary(combat_source, match.start(1)))
    style_source = read(root, 'scripts/entities/coastal_styles.gd').decode('utf-8')
    styles = {}
    for style in ('cw_anchor', 'cw_fan'):
        match = re.search(r'if mode\(bow\)=="' + style + r'":return (\{)', style_source)
        require(match is not None, 'Original coastal style missing')
        literal = balanced_dictionary(style_source, match.start(1))
        literal = re.sub(r'TranslationServer\.translate\(("(?:[^"\\]|\\.)*")\)', r'\1', literal)
        styles[style] = json_dictionary(literal)
    world = document(read(root, 'migration/world/index.json'), 'immutable world index')
    rows = world.get('snapshots')
    require(isinstance(rows, list) and len(rows) == 162 and len({row['mapId'] for row in rows}) == 37,
            'Original actor snapshot coverage differs')
    scenes = []
    for row in rows:
        raw = read(root, 'migration/world/' + row['path'])
        require(sha(raw) == row['sha256'] and len(raw) == row['bytes'], 'Original actor scene bytes differ')
        scenes.append({'map': row['mapId'], 'scenario': row['scenarioId'], 'actors': actor_projection(raw)})
    return {'catalogs': catalogs, 'constants': constants, 'techniques': techniques,
            'enemyOrder': order, 'weaponOrder': weapon_order, 'actors': scenes, 'declarations': declarations, 'hashes': hashes,
            'bowTechnique': bow_profile, 'coastalProfiles': styles, 'arrowOverTiles': over_tiles}


def check_extra_mirrors(case):
    rows = []
    for field in ('transient', 'initialPlayer'):
        rows.append({'initial': case[field], 'initialExact': case[field + 'Exact'], 'initialOrdered': case[field + 'Ordered'],
                     'operations': [], 'operationsExact': [], 'operationsOrdered': [], 'results': [], 'resultsExact': [],
                     'expected': {}, 'expectedExact': {}})
    return normalize_pairs({'orderedInputEncoding': 'dictionary-pairs-and-exact-f64-v1', 'cases': rows})


def expected_combat_case_ids(reference):
    """Require every weapon, cost boundary, state transition and geometry family."""
    ids = []
    for weapon in reference['weaponOrder']:
        ids.append('sword-combo-' + weapon)
        for bow in ('false', 'true'):
            ids.extend(('technique-profile-' + weapon + '-' + bow, 'technique-release-' + weapon + '-' + bow))
    ids.extend('sweep-stamina-' + str(n) for n in (0.0, 17.99, 18.0, 18.001, 100.0))
    ids.extend('technique-exhaustion-' + n for n in ('false', 'true'))
    ids.extend(f'style-{hand}-{bow}-{arrows}' for hand in ('gear_cw_anchor', 'gear_cw_fan', 'gear_pg_grip_plus')
               for bow in ('false', 'true') for arrows in (0, 2, 3, 8))
    ids.extend(f'hurt-{armor}-{amount}' for armor in ('', 'gear_iron_armor', 'gear_leather_armor')
               for amount in (-1, 0, 1, 2, 3, 8))
    ids.extend('invulnerability-' + str(n) for n in (0.0, 0.0001, 1.0))
    ids.extend('roll-safe-' + str(n) for n in (0.0, 0.059999, 0.06, 0.060001, 0.3))
    ids.extend('death-counter-' + str(n) for n in (0, 1, 2))
    ids.extend(('arena-intercepts-death', 'ordinary-bow-missing', 'ordinary-bow-0', 'ordinary-bow-1',
                'ordinary-bow-3', 'lent-arrows', 'precision-recheck-ammo', 'technique-map-cancel',
                'technique-menu-cancel', 'technique-device-cancel', 'style-removal-cancel', 'cover-blocks-sword'))
    for family, count in (('sword-geometry', 6), ('arrow-target', 12), ('arrow-armor', 30)):
        for _ in range(count):
            ids.append(family + '-' + str(len(ids)))
    ids.extend('arrow-flight-' + str(n) for n in (1.0, 8.0, 8.1, 12.0, 33.0, 280.0, 300.0))
    for _ in range(6):
        ids.append('breakable-geometry-' + str(len(ids)))
    ids.extend(f'new-game-plus-{ng}-{amount}' for ng in (0, 1, 2, 9) for amount in (1, 3, 22, 60, 180))
    ids.extend(('guardian-chest-0', 'guardian-chest-3', 'guardian-earned-reward-none',
                'guardian-earned-reward-active', 'guardian-earned-reward-done'))
    ids.extend(f'gear-combat-{hand}-{weapon}' for hand in
               ('gear_novice_gloves', 'gear_smith_gloves', 'gear_pg_grip', 'gear_pg_grip_plus')
               for weapon in reference['weaponOrder'])
    ids.extend('anchor-window-' + str(value) for value in (0.319999, 0.32, 0.320001))
    for _ in range(5):
        ids.append('anchor-angle-' + str(len(ids)))
    ids.extend('rejected-start-' + field for field in ('cooldown', 'bow_cooldown', 'roll_timer'))
    ids.extend(('committed-aim-stops-at-transition', 'future-profile-fields-retained'))
    for _ in range(5):
        ids.append('segment-distance-' + str(len(ids)))
    return ids


def combat_coverage(value, reference, root):
    require(set(value['catalogs']) == {'enemies', 'weapons', 'gear', 'techniques', 'bowTechnique', 'coastalProfiles',
            'player', 'arrow', 'projectile', 'guardian', 'aiConstants', 'loadedActors', 'enemyOrder',
            'projectileTraits', 'arrowOverTiles'}, 'Combat catalog set differs')
    recorder = importlib.import_module('record_migration_combat')
    normalized = recorder.normalize_exact_mirrors(value)
    catalogs = recorder.decode_ordered_input(value['catalogsOrdered'])
    for name in ('enemies', 'weapons', 'gear'):
        require(canonical(catalogs[name]) == canonical(reference['catalogs'][name]), 'Original combat catalog differs: ' + name)
    for name in ('player', 'arrow', 'projectile', 'guardian'):
        require(canonical(catalogs[name]) == canonical(reference['constants'][name]), 'Original combat constants differ: ' + name)
    require(canonical(catalogs['techniques']) == canonical(reference['techniques']), 'Original technique costs or geometry differ')
    for name in ('bowTechnique', 'coastalProfiles', 'arrowOverTiles'):
        require(canonical(catalogs[name]) == canonical(reference[name]), 'Original bow/style/source terrain differs: ' + name)
    require(canonical(catalogs['projectileTraits']) == canonical(reference['constants']['projectile']['TRAITS']),
            'Original projectile traits differ')
    require(catalogs['enemyOrder'] == reference['enemyOrder'] and list(catalogs['enemies']) == reference['enemyOrder'],
            'Original enemy insertion order differs')
    require(list(catalogs['weapons']) == reference['weaponOrder'], 'Original weapon dictionary order differs')
    require(canonical(sorted(catalogs['loadedActors'], key=lambda row: (row['map'], row['scenario']))) ==
            canonical(sorted(reference['actors'], key=lambda row: (row['map'], row['scenario']))),
            'Original loaded actor coverage, source address, placement, stats or state differs')
    expected_ai = {name: row for name, row in reference['constants'].items() if name not in ('player', 'arrow', 'projectile', 'guardian')}
    require(canonical(catalogs['aiConstants']) == canonical(expected_ai), 'Original AI helper constants differ')
    cases = value.get('cases')
    require(isinstance(cases, list) and cases and all(isinstance(row, dict) and set(row) == COMBAT_FIELDS for row in cases),
            'Complete combat transient/state observations required')
    ids = [row.get('id') for row in cases]
    require(all(isinstance(key, str) and re.fullmatch(r'[a-z0-9_.-]{1,140}', key) for key in ids)
            and len(ids) == len(set(ids)), 'Invalid or duplicate combat case ID')
    require(ids == expected_combat_case_ids(reference), 'Combat case families missing, reordered or invented')
    for case in cases:
        require(set(case['initial']) == set(case['expected']) == SAVE_FIELDS, 'Combat case lost original save fields')
        if case['id'] == 'future-profile-fields-retained':
            expected = {'large': 9007199254740993, 'nested': [None, True, '🌿']}
            require(case['initial']['flags'].get('future_combat') == case['expected']['flags'].get('future_combat') == expected,
                    'Future combat profile data or exact integer was lost')
        require(case['operations'] and len(case['operations']) == len(case['results']), 'Combat result coverage differs')
        check_extra_mirrors(case)
    return {'cases': len(cases), 'caseIds': ids, 'enemies': len(catalogs['enemies']), 'weapons': len(catalogs['weapons']),
            'loadedActorSnapshots': len(catalogs['loadedActors']),
            'loadedActors': sum(len(row['actors']) for row in catalogs['loadedActors']),
            'exactFloat64Values': validate_float64_bits(value), 'dictionaryInputOrderPreserved': True}


def encounter_coverage(value, reference, root):
    """Bind every AI family and projectile/component episode to the preserved original species."""
    recorder = importlib.import_module('record_migration_encounter')
    normalized = recorder.normalize_exact_mirrors(value)
    catalogs = recorder.decode_ordered_input(value['catalogsOrdered'])
    require(set(catalogs) == {'enemies', 'projectileTraits'}, 'Encounter catalogs are incomplete')
    require(canonical(catalogs['enemies']) == canonical(reference['catalogs']['enemies']),
            'Encounter original species or their stats/drops differ')
    require(list(catalogs['enemies']) == reference['enemyOrder'], 'Encounter original species order differs')
    require(canonical(catalogs['projectileTraits']) == canonical(reference['constants']['projectile']['TRAITS']),
            'Encounter original projectile traits differ')
    families = {}
    for kind in reference['enemyOrder']:
        behavior = reference['catalogs']['enemies'][kind]['behavior']
        if behavior != 'guardian' and behavior not in families:
            families[behavior] = kind
    require(value.get('families') == families, 'Original AI behavior families or representatives differ')
    cases = value.get('cases')
    require(isinstance(cases, list) and cases, 'Original encounter cases are missing')
    ids = [row.get('id') for row in cases]
    require(all(isinstance(key, str) and re.fullmatch(r'[a-z0-9_.-]{1,140}', key) for key in ids)
            and len(ids) == len(set(ids)), 'Invalid or duplicate encounter case ID')
    required = [prefix + kind for kind in reference['enemyOrder'] if kind != 'guardian'
                for prefix in ('hurt-', 'inactive-', 'death-', 'practice-')]
    required.extend('chase-' + kind for kind in ('slime', 'slime_blue', 'slime_red', 'slime_mini'))
    required.extend('acquire-' + family for family in families)
    required.extend('commit-' + kind for kind in ('bat', 'skeleton', 'slime_spitter', 'mage', 'golem'))
    required.extend('commit-' + family for family in families if family in {
        'cv_ram', 'cv_slinger', 'rf_ambush', 'rf_listen', 'lw_flank', 'echo_charge', 'echo_volley',
        'hb_root', 'hb_moth', 'ad_crab', 'ad_wisp', 'ad_keeper'})
    required.extend(('guard-front', 'guardian-protected-waking', 'guardian-protected-shift',
                     'guardian-charge-lock', 'guardian-slam', 'guardian-next-phase', 'guardian-recover'))
    # The fixture visits the three named special projectiles in its declared order;
    # their data still comes from the preserved original TRAITS dictionary.
    special_order = ('arcane_orb', 'prism_spark', 'cv_thorn')
    require(set(special_order) == set(reference['constants']['projectile']['TRAITS']),
            'Original special projectile set differs')
    projectile_order = [*reference['constants']['projectile']['FRAMES'], *special_order, 'guardian_shard']
    require(len(projectile_order) == len(set(projectile_order)), 'Original projectile family overlap differs')
    projectile_kinds = set(projectile_order)
    for kind in projectile_order:
        required.extend(('projectile-flight-' + kind, 'projectile-wall-' + kind))
        if kind in reference['constants']['projectile']['TRAITS']:
            required.append('projectile-sword-' + kind)
    required.extend(('arrow-launch-cover', 'arrow-flight-range',
                     'pillar-single-ring', 'pillar-rage-two-rings', 'pillar-cancel'))
    require(ids == required, 'Original encounter species/AI/projectile episode families missing, reordered or invented')
    policy = value.get('fixturePolicy')
    require(isinstance(policy, dict) and set(policy) == {'wander', 'lethalDrops', 'practice'}
            and all(isinstance(text, str) and text.strip() for text in policy.values()),
            'Explicit encounter RNG, lethal drop and practice fixture policies required')
    base_fields = {'id', 'kind', 'fixture', 'fixtureExact', 'fixtureOrdered', 'initial', 'initialExact',
                   'initialOrdered', 'operations', 'operationsExact', 'operationsOrdered',
                   'results', 'resultsExact', 'expected', 'expectedExact'}
    components = set()
    for case, normalized_case in zip(cases, normalized['cases'], strict=True):
        require(base_fields <= set(case) <= base_fields | {'projectile', 'component'},
                'Incomplete or unexpected encounter observation fields')
        require(case['operations'] and len(case['operations']) == len(case['results']),
                'Encounter operation/result observations incomplete')
        component = case.get('component', '')
        require(component in ('', 'pillar'), 'Unknown encounter component')
        if component == 'pillar':
            require(case['kind'] == 'guardian_pillar', 'Invented original pillar component')
            components.add('pillar')
        if case['kind'] in ('guardian', 'guardian_shard'):
            components.add('guardian' if case['kind'] == 'guardian' else 'shard')
        allowed_kinds = set(reference['catalogs']['enemies']) | projectile_kinds | {'player_arrow', 'guardian_shard', 'guardian_pillar'}
        require(case['kind'] in allowed_kinds, 'Invented encounter species or projectile')
        if 'projectile' in case:
            require(case['projectile'] is True and case['kind'] in projectile_kinds | {'player_arrow'}, 'Invalid projectile witness')
        fixture = {'orderedInputEncoding': 'dictionary-pairs-and-exact-f64-v1', 'cases': [{
            'initial': normalized_case['fixture'], 'initialExact': case['fixtureExact'], 'initialOrdered': case['fixtureOrdered'],
            'operations': [], 'operationsExact': [], 'operationsOrdered': [],
            'results': [], 'resultsExact': [], 'expected': {}, 'expectedExact': {}}]}
        normalize_pairs(fixture)
        if case['kind'] in reference['catalogs']['enemies'] and case['kind'] != 'guardian':
            require(case['fixture'].get('wander_timer') == 5.0 and case['fixture'].get('wander_dir') == [0.0, 0.0],
                    'Encounter random wandering must have explicit source fixture inputs')
        if case['id'].startswith(('death-', 'practice-')):
            practice = case['id'].startswith('practice-')
            require(case['fixture'].get('mode') == ('practice' if practice else 'lethal'),
                    'Encounter death/practice fixture mode differs')
            state = case['expected']
            source_drops = reference['catalogs']['enemies'][case['kind']]['drops']
            expected_drops = {}
            if not practice:
                for item, _chance, amount, *_tail in source_drops:
                    expected_drops[item] = expected_drops.get(item, 0) + amount
            require(state.get('dead') is True and state.get('kill_events') == 1
                    and state.get('unique_claimed') is True and state.get('drop_counts') == expected_drops,
                    'Original death callbacks, unique claim or controlled source drop counts differ')
            require(case['results'][-1] == case['expected'], 'Encounter final result/state differs')
            if not practice:
                require(len(case['results']) == 2 and case['results'][0] == case['results'][1],
                        'Repeated lethal hit must preserve the original unique reward')
    require(components == {'guardian', 'shard', 'pillar'}, 'Original guardian, shard or pillar episodes missing')
    return {'cases': len(cases), 'caseIds': ids, 'enemies': len(catalogs['enemies']), 'behaviorFamilies': len(families),
            'projectileKinds': len(projectile_kinds), 'components': sorted(components),
            'exactFloat64Values': validate_float64_bits(value), 'dictionaryInputOrderPreserved': True}


def asset_guids(root):
    base = Path(root) / ASSETS
    no_links(base); require(base.is_dir(), 'Native combat assets missing')
    rows, seen, covered_metadata = [], set(), set()
    for owner in [base, *sorted(path for path in base.rglob('*') if path.suffix != '.meta'),
                  *(Path(root) / path for path in ROUTE_ASSETS)]:
        no_links(owner)
        require(owner.exists(), 'Native combat asset is missing')
        meta = owner.with_name(owner.name + '.meta')
        text = read(root, meta.relative_to(root).as_posix()).decode('utf-8-sig')
        guids = re.findall(r'^guid: ([0-9a-f]{32})$', text, re.M)
        require(len(guids) == len(re.findall(r'^guid:', text, re.M)) == 1 and guids[0] not in seen,
                'Missing/duplicate combat asset GUID')
        require(('folderAsset: yes' in text) == owner.is_dir(), 'Combat folder metadata differs')
        covered_metadata.add(meta)
        seen.add(guids[0]); rows.append({'path': owner.relative_to(root).as_posix(), 'guid': guids[0]})
    require(all(meta.with_suffix('').exists() for meta in base.rglob('*.meta')), 'Orphan combat metadata')
    for meta in (Path(root) / 'unity/Assets').rglob('*.meta'):
        if meta in covered_metadata:
            continue
        no_links(meta)
        previous = re.findall(r'^guid: ([0-9a-f]{32})$', meta.read_text(encoding='utf-8-sig'), re.M)
        require(not seen.intersection(previous), 'Combat GUID collides with a preserved native asset')
    return rows


def build_contract(root=ROOT):
    root = Path(root)
    for name, digest in REFERENCE_DIGESTS.items():
        require(sha(read(root, name)) == digest, 'Previously verified reference changed: ' + name)
    previous = check_progression(root)
    baseline = document(read(root, 'migration/reference/source-manifest.json'), 'frozen original source')
    require(baseline['commit'] == 'a8a988be27835dec979d2523a3a85a34385eac54'
            and baseline['tree'] == '73ba02ea4db0a1c920360b6570f5209ccb970143', 'Original source identity changed')
    anchors = []
    for entry in baseline['files']:
        name = entry['path']
        if not name.startswith(('scripts/', 'scenes/')) or not name.endswith(('.gd', '.tscn')):
            continue
        raw = read(root, name)
        require(sha(raw) == entry['sha256'] and len(raw) == entry['bytes'], 'Original combat source changed: ' + name)
        anchors.append({'path': name, 'bytes': len(raw), 'sha256': sha(raw), 'gitBlob': entry['git_blob']})
    reference = original_references(root)
    oracles = {}
    for kind, (source, resource, recorder_name) in ORACLES.items():
        raw = read(root, source)
        value = document(raw, source)
        require(value.get('schema') == 'bluemap.' + kind + '.source-oracle.v1'
                and value.get('engineVersion') == '4.4.1-stable (official)'
                and value.get('personalSavesUsed') is False
                and value.get('float64Encoding') == 'ieee754-binary64-little-endian-hex'
                and value.get('orderedInputEncoding') == 'dictionary-pairs-and-exact-f64-v1',
                'Original oracle schema/engine/privacy/encoding differs: ' + kind)
        if kind == 'combat':
            require(set(value.get('newGame', {})) == SAVE_FIELDS, 'Oracle original new-game fields differ')
            require(canonical(value['newGame']) == canonical(document(read(root, 'migration/phase-13/progression-oracle.json'),
                    'previous original new-game defaults')['newGame']), 'Original new-game defaults changed')
        coverage = (combat_coverage if kind == 'combat' else encounter_coverage)(value, reference, root)
        paths = {entry['path'] for entry in anchors}
        methods = value.get('sourceMethods')
        require(isinstance(methods, list) and methods and len(methods) == len(set(methods)), 'Original source methods missing/duplicated')
        for method in methods:
            require(isinstance(method, str) and method.count('::') == 1, 'Invalid original source method')
            path, name = method.split('::')
            require(path in paths and re.search(r'\bfunc\s+' + re.escape(name) + r'\s*\(', read(root, path).decode('utf-8')),
                    'Unverified original combat method: ' + method)
        coverage['methods'] = methods
        require(read(root, resource) == raw, 'Native oracle differs from original methods: ' + kind)
        oracles[kind] = {'sourcePath': source, 'resourcePath': resource, 'sha256': sha(raw), 'bytes': len(raw), 'coverage': coverage}
    return {'schema': 'bluemap.combat.source-contracts.v1', 'phase': 14,
            'baselineCommit': baseline['commit'], 'baselineTree': baseline['tree'],
            'sourceAnchors': sorted(anchors, key=lambda row: row['path']), 'oracles': oracles,
            'frozenReferenceFiles': reference['hashes'] + [{'path': name, 'sha256': digest} for name, digest in REFERENCE_DIGESTS.items()],
            'previousProgressionContractSha256': sha(read(root, 'migration/phase-13/source-contracts.json')),
            'world': {'maps': 37, 'snapshots': 162, 'indexSha256': REFERENCE_DIGESTS['migration/world/index.json']},
            'recorders': [{'path': name, 'sha256': sha(read(root, name))} for name in RECORDERS],
            'assetGuids': asset_guids(root), 'requiredNativeChecks': sorted(COMBAT_DETAIL_CHECKS),
            'enginesStarted': False, 'personalSavesUsed': False}


def check(root=ROOT):
    value = build_contract(root)
    require(read(root, CONTRACT) == canonical(value), 'Stale/corrupt combat source contracts')
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
        require(not args.report.exists() and not args.report.resolve().is_relative_to(ROOT), 'Use fresh external evidence')
        args.report.parent.mkdir(parents=True, exist_ok=True); args.report.write_bytes(canonical({'success': True, **value}))
    print('MIGRATION COMBAT DATA OK:', len(value['sourceAnchors']), 'preserved sources;',
          ', '.join(kind + '=' + str(row['coverage']['cases']) for kind, row in value['oracles'].items()))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit('MIGRATION COMBAT DATA FAILED: ' + str(error))
