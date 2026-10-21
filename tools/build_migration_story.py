#!/usr/bin/env python3
"""Bind original conversations, quest graphs and ordered consequences to frozen source.

This portable verifier executes neither engine and never opens a player save.
The separate recorder invokes the original methods in two UUID-isolated processes.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib
import json
from pathlib import Path
import re
import struct

from build_migration_player import canonical, document, no_links
from build_migration_route import SAVE_FIELDS
from build_migration_combat import check as check_combat
from migration_world_data import decode_wire, WireDictionary, WireValue
from record_migration_inventory_state import decode_ordered_input
from verify_unity_package import STORY_DETAIL_CHECKS

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = 'migration/phase-15/source-contracts.json'
ORACLE = 'migration/phase-15/story-oracle.json'
ASSETS = 'unity/Assets/BlueMapStory'
RESOURCE = ASSETS + '/Runtime/Model/Resources/BlueMapStoryOracle.json'
CATALOG_RESOURCE = ASSETS + '/Runtime/Model/Resources/BlueMapStoryCatalog.json'
RECORDERS = ('tools/migration_story_export.gd', 'tools/migration_story_dialogue_fixture.gd',
             'tools/record_migration_story.py', 'tools/migration_inventory_export.gd',
             'tools/record_migration_inventory_state.py', 'tools/migration_route_export.gd')
REFERENCE_DIGESTS = {
    'migration/reference/source-manifest.json': '5300a24edd771f0c94566a3255fffa798a2daf654419960d22c3703d8533d5d6',
    'migration/reference/maps-inventory.json': '3b6e3818d720f501dbcce09252919f7c76f2814a651a5fba796a322767cfb207',
    'migration/world/index.json': 'd986a9a8ad3a03e2c5a5b9fb98e0622dbca76f950f52d35d756f611410af4743',
    'migration/phase-10/route-oracle.json': 'fb1e18d6b60da6bc66ce8e01157d7cbe4e512d8326e196066b5f5d9d45ca4211',
    'migration/phase-13/progression-oracle.json': '66a9c0b04ff396b2cf88138d378bceadfe0b76af0cfe7b7aeda533757ab8e31b',
}
CONDITION_FIELDS = {'if', 'advance_if', 'exists_if', 'requires', 'block_if', 'open_if', 'conditions'}
CASE_FIELDS = {'id', 'initial', 'initialExact', 'initialOrdered', 'operations', 'operationsExact',
               'operationsOrdered', 'results', 'resultsExact', 'expected', 'expectedExact',
               'observations', 'observationsExact', 'observationsOrdered'}
SOURCE_METHODS = {'scripts/core/game_state.gd::run', 'scripts/core/game_state.gd::run_all',
    'scripts/core/game_state.gd::check', 'scripts/core/game_state.gd::check_all',
    'scripts/core/game_state.gd::start_quest', 'scripts/core/game_state.gd::set_quest_step',
    'scripts/core/game_state.gd::finish_quest', 'scripts/core/game_state.gd::_refresh_quests',
    'scripts/core/game_state.gd::quest_text', 'scripts/core/game_state.gd::tracked_text',
    'scripts/core/game_state.gd::fmt', 'scripts/entities/npc.gd::interact',
    'scripts/ui/dialogue_box.gd::start', 'scripts/ui/dialogue_box.gd::_finish_node',
    'scripts/ui/dialogue_box.gd::_choose', 'scripts/ui/dialogue_box.gd::_show_choices',
    'scripts/core/journey.gd::focus', 'scripts/core/journey.gd::toggle',
    'scripts/core/journey.gd::target', 'scripts/core/journey.gd::detail',
    'scripts/core/journey.gd::preparation', 'scripts/core/journey.gd::tracker'}
STORY_OBJECT_SCRIPTS = {'res://scripts/entities/' + name + '.gd' for name in (
    'npc', 'route_npc', 'trigger', 'opening_device', 'village_opening', 'route_object',
    'living_object', 'regional_object', 'regional_adventures', 'supper_object', 'supper_actor',
    'lake_supper', 'coastal_adventure', 'coastal_adventure_director', 'coast_resident',
    'arena_master', 'arena_gong', 'arena_board', 'shooting_range', 'work_together')}
_LOADED_STORY_CACHE = {}


class StoryDataError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise StoryDataError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read(root, name):
    require(isinstance(name, str) and name and not name.startswith(('/', '\\')) and '\\' not in name
            and '..' not in name.split('/'), 'Unsafe story source path')
    path = Path(root) / name
    no_links(path)
    require(path.is_file() and path.stat().st_size <= 64 * 1024 * 1024, 'Missing/oversized story source: ' + name)
    return path.read_bytes().replace(b'\r\n', b'\n')


def declared_array(source, key):
    match = re.search(r'^const\s+' + re.escape(key) + r'\s*(?::\s*Array[^=]*)?\s*:?=\s*(\[)', source, re.M)
    if not match:
        return []
    start = match.start(1)
    end = source.index(']', start)
    literal = '\n'.join(line.split('#', 1)[0] for line in source[start:end + 1].splitlines())
    value = json.loads(re.sub(r',\s*\]', ']', literal))
    require(isinstance(value, list) and all(isinstance(key, str) and key for key in value)
            and len(value) == len(set(value)), 'Invalid original declared story name array')
    return value


def source_opcodes(source, method, end_method):
    body = source[source.index('\nfunc ' + method + '('):source.index('\nfunc ' + end_method + '(')]
    return [name for match in re.finditer(r'^\t\t((?:"[^"]+"(?:,\s*)?)+):', body, re.M)
            for name in re.findall(r'"([^"]+)"', match.group(1))]


def registry_plain(value):
    """Match the recorder's documented plain projection of frozen map Variants."""
    if isinstance(value, dict):
        if value.get('$type') == 'Color':
            require(set(value) == {'$type', 'rgba'} and len(value['rgba']) == 4, 'Malformed original map Color')
            return [struct.unpack('<f', struct.pack('<f', part))[0] for part in value['rgba']]
        if value.get('$type') in ('Vector2', 'Vector2i'):
            require(set(value) == {'$type', 'value'} and len(value['value']) == 2, 'Malformed original map vector')
            return value['value']
        if value.get('$type') == 'Dictionary':
            require(set(value) == {'$type', 'entries'}, 'Malformed original map dictionary')
            result = {}
            for key, child in value['entries']:
                if isinstance(key, dict) and key.get('$type') == 'Vector2i':
                    key = '(' + ', '.join(str(part) for part in registry_plain(key)) + ')'
                require(isinstance(key, str) and key not in result, 'Unsupported/collapsed original map key')
                result[key] = registry_plain(child)
            return result
        require('$type' not in value, 'Unexpected original map Variant')
        return {key: registry_plain(child) for key, child in value.items()}
    if isinstance(value, list):
        return [registry_plain(child) for child in value]
    return value


def story_census(catalogs, maps, modules, base_actions, base_conditions):
    """Index actual condition/action sites and resolve every original graph reference."""
    usage = {'actions': [], 'conditions': [], 'formats': [], 'dialogueEdges': [],
             'questReferences': [], 'itemReferences': [], 'npcReferences': [], 'weaponReferences': []}
    actions = [*base_actions, *(key for row in modules for key in row['actions'])]
    conditions = [*base_conditions, *(key for row in modules for key in row['conditions'])]
    formats = ['crystals', 'gel', 'shards', 'coins', *(key for row in modules for key in row['formats'])]

    def condition(value, at):
        require(isinstance(value, list) and value and isinstance(value[0], str)
                and value[0] in conditions, 'Unknown/malformed original condition at ' + at)
        usage['conditions'].append({'location': at, 'value': value})
        if value[0] == 'any':
            for index, child in enumerate(value[1:], 1):
                condition(child, at + '/' + str(index))
        if value[0] in ('quest', 'step'):
            require(len(value) >= 2 and value[1] in catalogs['quests'], 'Unknown original condition quest')
            usage['questReferences'].append({'quest': value[1], 'location': at})
        if value[0] in ('has', 'lacks'):
            require(len(value) >= 2 and value[1] in catalogs['items'], 'Unknown original condition item')
            usage['itemReferences'].append({'item': value[1], 'location': at})
        if value[0] == 'weapon':
            require(len(value) >= 2 and value[1] in catalogs['weapons'], 'Unknown original condition weapon')
            usage['weaponReferences'].append({'weapon': value[1], 'location': at})

    def walk(value, at):
        if isinstance(value, dict):
            if value.get('type') == 'npc':
                require(value.get('id') in catalogs['npcs'], 'Unknown original map NPC')
                usage['npcReferences'].append({'npc': value['id'], 'location': at})
            for key, child in value.items():
                location = at + '/' + key
                if key in CONDITION_FIELDS and isinstance(child, list):
                    for index, item in enumerate(child):
                        condition(item, location + '/' + str(index))
                elif key == 'do':
                    require(isinstance(child, list), 'Malformed original action list')
                    for index, item in enumerate(child):
                        require(isinstance(item, list) and item and item[0] in actions,
                                'Unknown/malformed original action at ' + location)
                        usage['actions'].append({'location': location + '/' + str(index), 'value': item})
                        if item[0] in ('start_quest', 'quest_step', 'finish_quest'):
                            require(len(item) >= 2 and item[1] in catalogs['quests'], 'Unknown original action quest')
                            usage['questReferences'].append({'quest': item[1], 'location': location})
                        if item[0] == 'talk':
                            require(len(item) >= 2 and item[1] in catalogs['dialogues'], 'Unknown action dialogue')
                            usage['dialogueEdges'].append({'from': location, 'to': item[1]})
                        if item[0] in ('give', 'take', 'sell_all'):
                            require(len(item) >= 2 and item[1] in catalogs['items'], 'Unknown original action item')
                            usage['itemReferences'].append({'item': item[1], 'location': location})
                        if item[0] == 'weapon':
                            require(len(item) >= 2 and item[1] in catalogs['weapons'], 'Unknown original action weapon')
                            usage['weaponReferences'].append({'weapon': item[1], 'location': location})
                elif key in ('next', 'talk') and isinstance(child, str):
                    require(child in catalogs['dialogues'], 'Unknown original dialogue edge: ' + child)
                    usage['dialogueEdges'].append({'from': at, 'to': child})
                else:
                    walk(child, location)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, at + '/' + str(index))
        elif isinstance(value, str):
            for token in re.findall(r'\{([a-zA-Z0-9_]+)\}', value):
                require(token in formats, 'Unknown original story formatting token: ' + token)
                usage['formats'].append({'location': at, 'token': token})

    for kind in ('dialogues', 'npcs', 'quests'):
        walk(catalogs[kind], kind)
    walk(maps, 'maps')
    return {'catalogCounts': {key: len(catalogs[key]) for key in ('dialogues', 'npcs', 'quests')},
            'mapCount': len(maps), 'modules': modules, 'baseActions': base_actions,
            'baseConditions': base_conditions, 'actionNames': list(dict.fromkeys(actions)),
            'conditionNames': list(dict.fromkeys(conditions)), 'formatNames': list(dict.fromkeys(formats)), **usage}


def original_references(root):
    previous = document(read(root, 'migration/phase-10/route-oracle.json'), 'original story catalogs')['catalogs']
    catalogs = {key: copy.deepcopy(previous[key]) for key in ('dialogues', 'npcs', 'quests', 'items')}
    progression = document(read(root, 'migration/phase-13/progression-oracle.json'), 'original weapon definitions')
    catalogs['weapons'] = decode_ordered_input(progression['catalogsOrdered'])['weapons']
    # The preserved original getter enriches four final Greta greetings without
    # mutating TALKS. Bind the observable getter output, rather than its raw table.
    for key in ('greta_max', 'greta_star', 'greta_star_again', 'greta_done'):
        row = catalogs['dialogues'][key]
        if 'choices' not in row and 'next' not in row:
            row['choices'] = [{'text': 'Niets, bedankt.'},
                              {'text': 'Samen je werkbankklem afstellen.', 'do': [['wt_open', 'smith']]}]
    registry = document(read(root, 'migration/reference/maps-inventory.json'), 'original map registry')
    require(registry['map_count'] == len(registry['maps']) == 37, 'Original map registry incomplete')
    maps = {row['id']: registry_plain(row['registry_snapshot']) for row in registry['maps']}
    source = read(root, 'scripts/data/content.gd').decode('utf-8')
    block = source[source.index('const MODULES:'):source.index('## Voegt de woordenboeken')]
    paths = re.findall(r'preload\("res://([^"]+)"\)', '\n'.join(line.split('#', 1)[0] for line in block.splitlines()))
    require(len(paths) == len(set(paths)) == 37, 'Original Content module order differs')
    modules = []
    for path in paths:
        text = read(root, path).decode('utf-8')
        modules.append({'path': path, **{key.lower(): declared_array(text, key)
                                        for key in ('CONDITIONS', 'ACTIONS', 'FORMATS')}})
    state = read(root, 'scripts/core/game_state.gd').decode('utf-8')
    census = story_census(catalogs, maps, modules, source_opcodes(state, 'run', 'run_all'),
                         source_opcodes(state, 'check', 'check_all'))
    require(census['catalogCounts'] == {'dialogues': 244, 'npcs': 35, 'quests': 33}, 'Original story catalog IDs differ')
    return {'catalogs': catalogs, 'maps': maps, 'census': census}


def plain_world(value):
    if isinstance(value, WireDictionary):
        return {key: plain_world(child) for key, child in value.items()}
    if isinstance(value, WireValue):
        if value.type in ('Vector2', 'Vector2i', 'Color'):
            return list(value.value)
        return {'engineType': value.type, 'value': plain_world(value.value)}
    if isinstance(value, (list, tuple)):
        return [plain_world(child) for child in value]
    return value


def loaded_story_objects(root):
    """Preserve actual source-object identities across all observed map variants."""
    world = document(read(root, 'migration/world/index.json'), 'frozen loaded world')
    require(len(world['snapshots']) == 162 and len({row['mapId'] for row in world['snapshots']}) == 37,
            'Original loaded world coverage incomplete')
    result = []
    for row in world['snapshots']:
        digest = row['sha256']
        raw = read(root, 'migration/world/' + row['path'])
        require(sha(raw) == digest and len(raw) == row['bytes'], 'Original loaded story scene changed')
        if digest not in _LOADED_STORY_CACHE:
            snapshot = document(raw, row['path'])
            nodes = []
            for node in snapshot['scene']:
                if node.get('script') not in STORY_OBJECT_SCRIPTS:
                    continue
                fields = decode_wire(node['fields'])
                selected = {key: plain_world(fields[key]) for key in
                            ('obj', 'data', 'kind', 'id', 'key', 'npc_id', 'exists_if', 'conditions', 'actions')
                            if key in fields}
                nodes.append({'address': node['address'], 'script': node['script'], 'fields': selected,
                              'position': [float(part['value']) for part in node['localTransform']['origin']['values']]})
            _LOADED_STORY_CACHE[digest] = nodes
        result.append({'map': row['mapId'], 'scenario': row['scenarioId'],
                       'snapshotSha256': digest, 'objects': _LOADED_STORY_CACHE[digest]})
    return result


def oracle_coverage(value, reference, root):
    require(value.get('schema') == 'bluemap.story.source-oracle.v1'
            and value.get('engineVersion') == '4.4.1-stable (official)' and value.get('personalSavesUsed') is False
            and value.get('float64Encoding') == 'ieee754-binary64-little-endian-hex'
            and value.get('orderedInputEncoding') == 'dictionary-pairs-and-exact-f64-v1', 'Story oracle identity/privacy/encoding differs')
    recorder = importlib.import_module('record_migration_story')
    normalized = recorder.validate_document(value)
    catalogs = recorder.decode_ordered_input(value['catalogsOrdered'])
    for key, original in reference['catalogs'].items():
        require(canonical(catalogs.get(key)) == canonical(original), 'Original story catalog changed: ' + key)
    for key in ('modules', 'actionNames', 'conditionNames', 'formatNames'):
        require(catalogs.get(key) == reference['census'][key], 'Original Content dispatcher differs: ' + key)
    require(canonical(catalogs.get('maps')) == canonical(reference['maps']), 'Original story map registry changed')
    require(value.get('newGame') == document(read(root, 'migration/phase-13/progression-oracle.json'), 'original new game')['newGame']
            and set(value['newGame']) == SAVE_FIELDS, 'Original new-game fields/defaults differ')
    cases = value.get('cases')
    require(isinstance(cases, list) and cases and all(isinstance(case, dict) and set(case) == CASE_FIELDS for case in cases),
            'Story behavior observations incomplete')
    ids = [case['id'] for case in cases]
    require(all(isinstance(key, str) and re.fullmatch(r'[a-z0-9_-]{1,160}', key) for key in ids)
            and len(ids) == len(set(ids)), 'Invalid/duplicate original story cases')
    required = {'dialogue-node-' + key for key in catalogs['dialogues']}
    required.update('dialogue-choice-' + key + '-' + str(i) for key, row in catalogs['dialogues'].items()
                    for i in range(len(row.get('choices', []))))
    required.update('dialogue-branch-' + key + '-' + str(i) for key, row in catalogs['dialogues'].items()
                    for i in range(len(row.get('branch', []))))
    required.update('npc-rule-' + key + '-' + str(i) for key, row in catalogs['npcs'].items() for i in range(len(row['rules'])))
    required.update('quest-lifecycle-' + key for key in catalogs['quests'])
    required.update('quest-step-' + key + '-' + str(i) for key, row in catalogs['quests'].items() for i in range(len(row['steps'])))
    required.update('preparation-' + key for key in reference['maps'])
    require(required <= set(ids), 'Original dialogue, choice, branch, NPC, quest or map case family omitted')
    for case, observed in zip(cases, normalized['cases'], strict=True):
        require(set(case['initial']) == set(case['expected']) == SAVE_FIELDS, 'Story save state fields missing')
        ops, results, observations = case['operations'], case['results'], observed['observations']
        require(isinstance(ops, list) and ops and len(ops) == len(results) == len(observations), 'Story per-step evidence missing')
        previous_events = []
        for observation in observations:
            require(isinstance(observation, dict) and set(observation) == {'state', 'dialogue', 'events'}
                    and set(observation['state']) == SAVE_FIELDS and isinstance(observation['dialogue'], dict)
                    and isinstance(observation['events'], list), 'Incomplete original story transient/signal observation')
            require(observation['events'][:len(previous_events)] == previous_events, 'Source signal ordering is not cumulative')
            previous_events = observation['events']
        require(observations[-1]['state'] == observed['expected'], 'Story final observation/state differs')
    methods = value.get('sourceMethods')
    require(isinstance(methods, list) and len(methods) == len(set(methods)) and SOURCE_METHODS <= set(methods),
            'Original story methods omitted/duplicated')
    for method in methods:
        require(isinstance(method, str) and method.count('::') == 1, 'Malformed story source method')
        path, name = method.split('::')
        require(path.startswith('scripts/') and re.search(r'\bfunc\s+' + re.escape(name) + r'\s*\(', read(root, path).decode('utf-8')),
                'Unverified original story method: ' + method)
    objects = object_coverage(value, normalized, root)
    traversals = semantic_traversal_coverage(cases, catalogs)
    return {'cases': len(cases), 'caseIds': ids, 'methods': methods, **reference['census']['catalogCounts'],
            'maps': len(reference['maps']), 'modules': len(reference['census']['modules']),
            'actions': len(reference['census']['actionNames']), 'conditions': len(reference['census']['conditionNames']),
            'formats': len(reference['census']['formatNames']), 'exactFloat64Values': recorder.validate_float64_bits(value),
            'dictionaryInputOrderPreserved': True, **objects, **traversals}


def semantic_traversal_coverage(cases, catalogs):
    """A labeled fixture is coverage only when its intended source branch was visited."""
    rows = {row['id']: row for row in cases}
    choices, rules, contrasts = 0, 0, 0
    for key, node in catalogs['dialogues'].items():
        for index in range(len(node.get('choices', []))):
            row = rows.get('dialogue-choice-' + key + '-' + str(index))
            require(row is not None and row['results'][-1] is True, 'Intended original dialogue choice was not selected')
            choices += 1
    for key, node in catalogs['npcs'].items():
        for index, rule in enumerate(node['rules']):
            row = rows.get('npc-rule-' + key + '-' + str(index))
            require(row is not None and row['observations'][0]['dialogue']['id'] == rule['talk'],
                    'Intended original NPC rule was shadowed by a different greeting')
            rules += 1
    for row in cases:
        if not row['id'].startswith('condition-') or not row['operations']:
            continue
        op = row['operations'][0]
        if len(op) != 2 or op[0] != 'check' or len(op[1]) != 3 or op[1][0] != 'quest' or op[1][2] != 'none':
            continue
        expected = row['id'].endswith('-true')
        require(row['results'][0] is expected, 'Original quest-none positive/negative contexts lack outcome contrast')
        contrasts += 1
    require(contrasts % 2 == 0, 'Incomplete original quest-none condition pair')
    return {'actualDialogueChoiceTraversals': choices, 'actualNpcRuleTraversals': rules,
            'questNoneConditionContrastPairs': contrasts // 2,
            'externalConditionContexts': ['arena_fight', 'arena_free']}


def validate_runtime_catalog(value, ordered_catalogs, digest):
    require(isinstance(value, dict) and set(value) == {'schema', 'sourceOracleSha256', 'personalSavesUsed', 'catalogsOrdered'}
            and value['schema'] == 'bluemap.story.catalog.v1' and value['personalSavesUsed'] is False,
            'Bounded story runtime catalog schema/privacy differs')
    require(value['sourceOracleSha256'] == digest, 'Story runtime catalog source hash differs')
    require(canonical(value['catalogsOrdered']) == canonical(ordered_catalogs),
            'Story runtime catalog is not the exact lossless original catalog projection')


def object_coverage(value, normalized, root):
    """Bind genuine device/memorial/echo contexts, interruption and unique rewards."""
    expected = {
        'opening-grate-without-rake', 'opening-grate-work-and-repeat', 'opening-grate-movement-cancel',
        'opening-grate-attack-cancel', 'opening-wheel-locked', 'opening-wheel-once',
        'route-investigate-track', 'route-investigate-relief', 'route-investigate-journal',
        'route-memorial-guard', 'route-memorial-guide', 'route-memorial-far-context',
        'route-echo-rf_echo_begin', 'route-echo-rf_echo_mid', 'route-echo-rf_echo_end',
        'route-echo-noisy-cancel', 'route-echo-wrong-order'}
    rows = value.get('objectCases')
    require(isinstance(rows, list) and len(rows) == len(expected) and {row.get('id') for row in rows} == expected,
            'Original story object context/interruption/repeat families incomplete')
    loaded = loaded_story_objects(root)
    for row, exact_row in zip(rows, normalized['objectCases'], strict=True):
        require(set(row) == CASE_FIELDS | {'map', 'spec'} and isinstance(row['spec'], dict)
                and set(row['spec']) <= {'type', 'kind', 'id'}, 'Story source object fields incomplete')
        spec = row['spec']
        require(spec.get('type') in ('opening_device', 'route_object') and isinstance(spec.get('kind'), str),
                'Invented original story object')
        candidates = [node for snapshot in loaded if snapshot['map'] == row['map'] for node in snapshot['objects']
                      if node['script'] == 'res://scripts/entities/' + spec['type'] + '.gd']
        require(any(all(node['fields'].get('obj', {}).get(key, node['fields'].get(key)) == child
                        for key, child in spec.items() if key != 'type') for node in candidates),
                'Story object does not exist in actual original map variants')
        require(row['results'] == row['resultsExact'] == [] and row['operations']
                and len(row['operations']) == len(row['observations'])
                and all(op[0] in ('interact', 'action', 'close', 'player', 'tick') for op in row['operations']),
                'Story object per-step observations incomplete')
        require(set(row['initial']) == set(row['expected']) == SAVE_FIELDS, 'Story object save fields incomplete')
        previous_events = []
        for observation in exact_row['observations']:
            require(set(observation) == {'state', 'dialogue', 'events', 'actor'}
                    and set(observation['state']) == SAVE_FIELDS and isinstance(observation['events'], list),
                    'Story object state/dialogue/signal/timer evidence incomplete')
            actor = observation['actor']
            require(isinstance(actor, dict) and set(actor) == ({'working', 'progress'} if spec['type'] == 'opening_device'
                    else {'listening', 'progress', 'pulse'}), 'Story object source timers missing')
            require(observation['events'][:len(previous_events)] == previous_events, 'Story object signal order differs')
            previous_events = observation['events']
        require(exact_row['observations'][-1]['state'] == exact_row['expected'], 'Story object final state differs')
    methods = set(value['sourceMethods'])
    require({'scripts/entities/opening_device.gd::interact', 'scripts/entities/opening_device.gd::_process',
             'scripts/entities/route_object.gd::interact', 'scripts/entities/route_object.gd::remember',
             'scripts/entities/route_object.gd::_process'} <= methods, 'Actual original story actuators missing')
    return {'objectCases': len(rows), 'objectCaseIds': sorted(expected),
            'loadedStorySnapshots': len(loaded), 'loadedStoryObjects': sum(len(row['objects']) for row in loaded)}


def asset_guids(root):
    base = Path(root) / ASSETS
    no_links(base)
    require(base.is_dir(), 'Native story assets missing')
    result, seen, covered = [], set(), set()
    for owner in [base, *sorted(path for path in base.rglob('*') if path.suffix != '.meta')]:
        no_links(owner)
        meta = owner.with_name(owner.name + '.meta')
        text = read(root, meta.relative_to(root).as_posix()).decode('utf-8-sig')
        found = re.findall(r'^guid: ([0-9a-f]{32})$', text, re.M)
        require(len(found) == len(re.findall(r'^guid:', text, re.M)) == 1 and found[0] not in seen,
                'Missing/duplicate story asset GUID')
        require(('folderAsset: yes' in text) == owner.is_dir(), 'Story folder metadata differs')
        seen.add(found[0]); covered.add(meta)
        result.append({'path': owner.relative_to(root).as_posix(), 'guid': found[0]})
    require(all(meta.with_suffix('').exists() for meta in base.rglob('*.meta')), 'Orphan story metadata')
    for meta in (Path(root) / 'unity/Assets').rglob('*.meta'):
        if meta not in covered:
            no_links(meta)
            require(not seen.intersection(re.findall(r'^guid: ([0-9a-f]{32})$', meta.read_text(encoding='utf-8-sig'), re.M)),
                    'Story GUID collides with preserved native asset')
    return result


def build_contract(root=ROOT):
    root = Path(root)
    for name, digest in REFERENCE_DIGESTS.items():
        require(sha(read(root, name)) == digest, 'Previously verified reference changed: ' + name)
    check_combat(root)
    baseline = document(read(root, 'migration/reference/source-manifest.json'), 'original frozen source')
    require(baseline['commit'] == 'a8a988be27835dec979d2523a3a85a34385eac54'
            and baseline['tree'] == '73ba02ea4db0a1c920360b6570f5209ccb970143', 'Original source identity changed')
    anchors = []
    for entry in baseline['files']:
        name = entry['path']
        if not name.startswith(('scripts/', 'scenes/')) or not name.endswith(('.gd', '.tscn')):
            continue
        raw = read(root, name)
        require(sha(raw) == entry['sha256'] and len(raw) == entry['bytes'], 'Original story source changed: ' + name)
        anchors.append({'path': name, 'bytes': len(raw), 'sha256': sha(raw), 'gitBlob': entry['git_blob']})
    reference = original_references(root)
    raw = read(root, ORACLE)
    oracle = document(raw, ORACLE)
    coverage = oracle_coverage(oracle, reference, root)
    require(read(root, RESOURCE) == raw, 'Native story oracle differs from original methods')
    catalog_raw = read(root, CATALOG_RESOURCE)
    validate_runtime_catalog(document(catalog_raw, CATALOG_RESOURCE), oracle['catalogsOrdered'], sha(raw))
    return {'schema': 'bluemap.story.source-contracts.v1', 'phase': 15,
            'baselineCommit': baseline['commit'], 'baselineTree': baseline['tree'], 'sourceAnchors': anchors,
            'oracle': {'sourcePath': ORACLE, 'resourcePath': RESOURCE, 'sha256': sha(raw), 'bytes': len(raw), 'coverage': coverage},
            'runtimeCatalog': {'path': CATALOG_RESOURCE, 'sha256': sha(catalog_raw), 'bytes': len(catalog_raw),
                               'sourceOracleSha256': sha(raw),
                               'purpose': 'Lossless normal-dialogue catalog; complete oracle retained for separate native proof'},
            'originalStoryCensus': reference['census'],
            'loadedStoryObjects': loaded_story_objects(root),
            'frozenReferenceFiles': [{'path': name, 'sha256': digest} for name, digest in REFERENCE_DIGESTS.items()],
            'previousCombatContractSha256': sha(read(root, 'migration/phase-14/source-contracts.json')),
            'world': {'maps': 37, 'snapshots': 162, 'indexSha256': REFERENCE_DIGESTS['migration/world/index.json']},
            'recorders': [{'path': name, 'sha256': sha(read(root, name))} for name in RECORDERS],
            'assetGuids': asset_guids(root), 'requiredNativeChecks': sorted(STORY_DETAIL_CHECKS),
            'enginesStarted': False, 'personalSavesUsed': False}


def check(root=ROOT):
    value = build_contract(root)
    require(read(root, CONTRACT) == canonical(value), 'Stale/corrupt story source contracts')
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
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(canonical({'success': True, **value}))
    print('MIGRATION STORY DATA OK:', len(value['sourceAnchors']), 'preserved sources;', value['oracle']['coverage']['cases'], 'original cases')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit('MIGRATION STORY DATA FAILED: ' + str(error))
