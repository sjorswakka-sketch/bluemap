#!/usr/bin/env python3
"""Bind original progression, gear, cosmetics and upgrades without starting an engine."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

from build_migration_player import canonical, document, no_links
from build_migration_route import SAVE_FIELDS
from build_migration_inventory_state import SOURCE_PATHS as INVENTORY_SOURCES
from migration_data_codec import decode
from record_migration_progression import normalize_exact_mirrors, validate_float64_bits, decode_ordered_input
from verify_unity_package import PROGRESSION_DETAIL_CHECKS

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = 'migration/phase-13/source-contracts.json'
ORACLE = 'migration/phase-13/progression-oracle.json'
RESOURCE = 'unity/Assets/BlueMapProgression/Runtime/Model/Resources/BlueMapProgressionOracle.json'
ASSETS = 'unity/Assets/BlueMapProgression'
PORTABLE_MANIFEST = 'migration/portable/manifest.json'
PORTABLE_MANIFEST_SHA256 = '0dd2d3ea38a30cde9ce449d460c4be6fef84d4023d883f96c88cc1e4a79d12ab'
REFERENCE_DIGESTS = {
    'migration/reference/source-manifest.json': '5300a24edd771f0c94566a3255fffa798a2daf654419960d22c3703d8533d5d6',
    'migration/reference/maps-inventory.json': '3b6e3818d720f501dbcce09252919f7c76f2814a651a5fba796a322767cfb207',
    'migration/world/index.json': 'd986a9a8ad3a03e2c5a5b9fb98e0622dbca76f950f52d35d756f611410af4743',
    'migration/phase-12/inventory-state-oracle.json': 'cad64e70a727a50bb86ccecb082dd98936c69f5b77d6d5a2faf64e0f5478d75e',
}
CATALOGS = {
    'gear_slots': 'gearSlots', 'gear': 'gear', 'clothing_slots': 'clothingSlots',
    'clothes': 'clothing', 'hair_m': 'hairM', 'hair_v': 'hairV', 'hair_colors': 'hairColors',
    'eye_colors': 'eyeColors', 'eye_styles': 'eyes', 'dye_colors': 'dyeColors',
    'genders': 'genders', 'weapons': 'weapons', 'professions': 'skills', 'recipes': 'recipes',
    'shops': 'shops', 'talks': 'dialogues', 'quests': 'quests',
}
GEAR_SOURCE = 'scripts/data/ext/uitrusting.gd'
LOOK_SOURCE = 'scripts/data/ext/uiterlijk.gd'
JOBS_SOURCE = 'scripts/data/ext/beroepen.gd'
ORDER_SOURCES = {
    'gearSlots': (GEAR_SOURCE, 'SLOTS'), 'gear': (GEAR_SOURCE, 'ITEMS'),
    'bonusLimits': ('scripts/core/equipment.gd', 'BONUS_LIMITS'),
    'clothingSlots': (LOOK_SOURCE, 'CLOTHING_SLOTS'), 'clothing': (LOOK_SOURCE, 'ITEMS'),
    'hairM': (LOOK_SOURCE, 'HAIR_M'), 'hairV': (LOOK_SOURCE, 'HAIR_V'),
    'eyes': (LOOK_SOURCE, 'EYES'), 'genders': (LOOK_SOURCE, 'GENDERS'),
    'skills': (JOBS_SOURCE, 'SKILLS'), 'recipes': (JOBS_SOURCE, 'RECIPES'),
}
SOURCE_PATHS = (*INVENTORY_SOURCES, 'scripts/core/progression.gd', 'scripts/core/appearance.gd',
    'scripts/core/character_draw.gd', 'scripts/core/appearance_draw.gd', 'scripts/core/art.gd',
    'scripts/core/character_layers.gd', 'scripts/core/equipment_art.gd',
    'scripts/core/craft_journal.gd', 'scripts/ui/progression_page.gd', 'scripts/ui/equipment_page.gd',
    'scripts/ui/appearance_page.gd', 'scripts/ui/crafting_ui.gd')
RECORDERS = ('tools/migration_progression_export.gd', 'tools/record_migration_progression.py',
    'tools/migration_inventory_export.gd', 'tools/record_migration_inventory_state.py',
    'tools/migration_route_export.gd')
CASE_FIELDS = {'id', 'initial', 'initialExact', 'initialOrdered', 'operations', 'operationsExact',
               'operationsOrdered', 'results', 'resultsExact', 'expected', 'expectedExact'}
BASE_CASE_IDS = {
    'hero-multilevel-cap-repeat', 'hero-import-level-does-not-reward', 'quest-unknown',
    'gear-combined-caps', 'gear-capacity-no-refill', 'gear-normalize-invalid-owned',
    'gear-removal-reconcile', 'appearance-invalid-input', 'clothing-invalid-normalization',
    'weapon-original-earned-opcode',
    'appearance-preserve-extensions', 'clothing-persist-slot-dye-no-gameplay-bonus',
    'clothing-removal-reconcile',
}
SOURCE_METHODS = {
    'scripts/core/progression.gd::normalize', 'scripts/core/progression.gd::threshold',
    'scripts/core/progression.gd::level_for', 'scripts/core/progression.gd::progress',
    'scripts/core/progression.gd::enemy_xp', 'scripts/core/progression.gd::quest_xp',
    'scripts/core/game_state.gd::add_hero_xp', 'scripts/core/game_state.gd::register_kill',
    'scripts/core/game_state.gd::finish_quest', 'scripts/core/game_state.gd::set_weapon',
    'scripts/core/equipment.gd::normalize', 'scripts/core/equipment.gd::normalize_owned',
    'scripts/core/equipment.gd::equip', 'scripts/core/equipment.gd::unequip',
    'scripts/core/equipment.gd::reconcile', 'scripts/core/equipment.gd::bonus',
    'scripts/core/equipment.gd::preview_bonus', 'scripts/core/equipment.gd::comparison_text',
    'scripts/core/appearance.gd::normalize_appearance', 'scripts/core/appearance.gd::normalize_clothing',
    'scripts/core/appearance.gd::set_gender', 'scripts/core/appearance.gd::wear',
    'scripts/core/appearance.gd::dye', 'scripts/core/appearance.gd::reconcile',
    'scripts/core/appearance.gd::set_hair', 'scripts/core/appearance.gd::set_hair_color',
    'scripts/core/appearance.gd::set_eyes', 'scripts/core/appearance.gd::set_eye_color',
    'scripts/core/appearance.gd::worn', 'scripts/core/appearance.gd::owned_in_slot',
    'scripts/core/appearance.gd::unwear', 'scripts/core/equipment.gd::equipped',
    'scripts/core/equipment.gd::owned', 'scripts/core/equipment.gd::stats_text',
    'scripts/core/professions.gd::craft_reason', 'scripts/core/professions.gd::craft',
    'scripts/core/craft_journal.gd::crafted', 'scripts/core/stockroom.gd::consume',
    'scripts/ui/progression_page.gd::weapon_upgrade',
}


class ProgressionDataError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise ProgressionDataError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read(root, name):
    require(isinstance(name, str) and name and not name.startswith(('/', '\\')) and '\\' not in name
            and '..' not in name.split('/'), 'Unsafe progression source path')
    path = Path(root) / name
    no_links(path)
    require(path.is_file() and path.stat().st_size <= 64 * 1024 * 1024, 'Missing/oversized progression source: ' + name)
    return path.read_bytes().replace(b'\r\n', b'\n')


def balanced_dictionary(text, start):
    require(start < len(text) and text[start] == '{', 'Source dictionary start missing')
    depth, index = 0, start
    while index < len(text):
        char = text[index]
        if char == '#':
            index = text.find('\n', index)
            require(index >= 0, 'Unterminated source dictionary comment')
            continue
        if char == '"':
            _, used = json.JSONDecoder().raw_decode(text[index:])
            index += used
            continue
        if char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                return text[start:index + 1]
        index += 1
    raise ProgressionDataError('Unterminated original dictionary')


def source_dictionary(text, constant):
    match = re.search(r'^const\s+' + re.escape(constant) + r'\s*(?::\s*Dictionary)?\s*:?=\s*(\{)', text, re.M)
    require(match is not None, 'Original dictionary declaration missing: ' + constant)
    return balanced_dictionary(text, match.start(1))


def dictionary_keys(text):
    depth, brackets, index, keys = 0, 0, 0, []
    while index < len(text):
        char = text[index]
        if char == '#':
            end = text.find('\n', index)
            index = len(text) if end < 0 else end
            continue
        if char == '"':
            value, used = json.JSONDecoder().raw_decode(text[index:])
            end = index + used
            tail = text[end:].lstrip()
            if depth == 1 and brackets == 0 and tail.startswith(':'):
                require(value not in keys, 'Duplicate original dictionary key')
                keys.append(value)
            index = end
            continue
        depth += (char == '{') - (char == '}')
        brackets += (char == '[') - (char == ']')
        index += 1
    require(depth == brackets == 0 and keys, 'Invalid original dictionary key structure')
    return keys


def json_dictionary(text):
    parts, index = [], 0
    while index < len(text):
        char = text[index]
        if char == '"':
            _, used = json.JSONDecoder().raw_decode(text[index:])
            parts.append(text[index:index + used]); index += used
            continue
        if char == '#':
            end = text.find('\n', index)
            index = len(text) if end < 0 else end
            continue
        if char == ',' and text[index + 1:].lstrip().startswith(('}', ']')):
            index += 1
            continue
        parts.append(char); index += 1
    value = json.loads(''.join(parts))
    require(isinstance(value, dict), 'Expected original literal dictionary')
    return value


def portable_plain(value):
    if isinstance(value, dict):
        if value.get('$type') == 'Color':
            require(set(value) == {'$type', 'rgba'} and len(value['rgba']) == 4, 'Original Color encoding differs')
            return [struct.unpack('<f', struct.pack('<f', component))[0] for component in value['rgba']]
        return {key: portable_plain(child) for key, child in value.items()}
    if isinstance(value, list):
        return [portable_plain(child) for child in value]
    return value


def original_references(root):
    manifest_raw = read(root, PORTABLE_MANIFEST)
    require(sha(manifest_raw) == PORTABLE_MANIFEST_SHA256, 'Frozen original portable manifest changed')
    manifest = document(manifest_raw, PORTABLE_MANIFEST)
    files = {row['path']: row for row in manifest['documents']}
    catalogs, hashes = {}, [{'path': PORTABLE_MANIFEST, 'sha256': sha(manifest_raw), 'bytes': len(manifest_raw)}]
    for name, target in CATALOGS.items():
        relative = 'catalogs/' + name + '.json'
        raw = read(root, 'migration/portable/' + relative)
        frozen = files[relative]
        require(sha(raw) == frozen['sha256'] and len(raw) == frozen['bytes'], 'Frozen original catalog changed: ' + name)
        value = decode(document(raw, relative))
        require(isinstance(value, dict) and value['count'] == len(value['entries']), 'Incomplete original catalog')
        rows = value['entries']
        require(len({row['id'] for row in rows}) == len(rows), 'Duplicate original catalog ID')
        catalogs[target] = ([portable_plain(row['value']) for row in sorted(rows, key=lambda row: row['source_index'])]
                            if rows and 'source_index' in rows[0] else
                            {row['id']: portable_plain(row['value']) for row in rows})
        hashes.append({'path': 'migration/portable/' + relative, 'sha256': sha(raw), 'bytes': len(raw)})
    sources = {name: read(root, name).decode('utf-8') for name in {*[row[0] for row in ORDER_SOURCES.values()],
               'scripts/core/progression.gd', 'scripts/data/items.gd', 'scripts/data/ext/diepte.gd'}}
    catalogs['bonusLimits'] = json_dictionary(source_dictionary(sources['scripts/core/equipment.gd'], 'BONUS_LIMITS'))
    catalogs['enemyXp'] = json_dictionary(source_dictionary(sources['scripts/core/progression.gd'], 'ENEMY_XP'))
    catalogs['stationText'] = json_dictionary(source_dictionary(sources[JOBS_SOURCE], 'TEXT'))
    catalogs['upgradeRecipes'] = {key: value for key, value in catalogs['recipes'].items() if 'upgrade_from' in value}
    catalogs['weaponUpgrades'] = {}
    for previous, target in (('wood', 'iron'), ('iron', 'crystal')):
        actions = catalogs['dialogues']['greta_' + target + '_ask']['choices'][0]['do']
        cost = {'from': previous, 'target': target, 'coins': 0, 'materials': {}, 'actions': actions, 'speaker': 'greta'}
        for action in actions:
            if action[0] == 'coins':
                cost['coins'] = -action[1]
            elif action[0] == 'take':
                cost['materials'][action[1]] = action[2] if len(action) > 2 else 1
        catalogs['weaponUpgrades'][target] = cost
    catalogs['weaponUpgrades']['star'] = {'from': 'crystal', 'target': 'star', 'kind': 'guardian_reward',
        'requiredFlag': 'guardian_defeated', 'coins': 0, 'materials': {}}
    orders = {key: dictionary_keys(source_dictionary(sources[path], constant))
              for key, (path, constant) in ORDER_SOURCES.items()}
    orders['upgradeRecipes'] = [key for key in orders['recipes'] if key in catalogs['upgradeRecipes']]
    orders['weapons'] = dictionary_keys(source_dictionary(sources['scripts/data/items.gd'], 'BASE_WEAPONS')) + dictionary_keys(
        source_dictionary(sources['scripts/data/ext/diepte.gd'], 'WEAPONS'))
    gear_body = source_dictionary(sources[GEAR_SOURCE], 'ITEMS')
    bonus_orders = {}
    for key in catalogs['gear']:
        match = re.search('"' + re.escape(key) + r'"\s*:\s*(\{)', gear_body)
        require(match is not None, 'Original gear declaration missing')
        item = balanced_dictionary(gear_body, match.start(1))
        bonus = re.search(r'"bonuses"\s*:\s*(\{)', item)
        bonus_orders[key] = dictionary_keys(balanced_dictionary(item, bonus.start(1))) if bonus else []
    return {'catalogs': catalogs, 'orders': orders, 'bonusOrders': bonus_orders, 'hashes': hashes}


def expected_case_ids(catalogs):
    ids = set(BASE_CASE_IDS)
    ids.update('hero-threshold-' + str(level) for level in range(-1, 12))
    ids.update('hero-normalize-' + str(index) for index in range(13, 28))
    ids.update(f'hero-boundary-{level}-{offset}' for level in range(1, 11) for offset in (-1, 0, 1))
    ids.update('enemy-' + kind + '-' + area for kind in [*catalogs['enemyXp'], 'future_enemy'] for area in ('forest', 'arena'))
    ids.update('quest-' + key for key in catalogs['quests'])
    ids.update('gear-' + ownership + '-' + key for key in catalogs['gear'] for ownership in ('owned', 'unowned'))
    ids.update('gear-whole-set-preview-' + key for key in catalogs['gear'])
    ids.update('hair-' + key for gender in ('hairM', 'hairV') for key in catalogs[gender])
    ids.update('hair-color-' + str(index) for index in range(-1, len(catalogs['hairColors']) + 1))
    ids.update('eyes-' + key for key in catalogs['eyes'])
    ids.update('eye-color-' + str(index) for index in range(-1, len(catalogs['eyeColors']) + 1))
    ids.update('clothing-' + ownership + '-' + key for key in catalogs['clothing'] for ownership in ('owned', 'unowned'))
    for key, recipe in catalogs['upgradeRecipes'].items():
        ids.update('upgrade-' + reason + '-' + key for reason in ('worn', 'unworn', 'locked', 'lowlevel', 'missing', 'full'))
        if 'station' in recipe:
            ids.add('upgrade-station-' + key)
        else:
            ids.update('upgrade-' + distance + '-' + kind + '-' + key
                       for distance in ('local', 'remote') for kind in ('home', 'coast'))
    ids.update('weapon-path-' + key for key in catalogs['weapons'])
    ids.update('weapon-original-actions-' + key for key in ('iron', 'crystal'))
    ids.update('weapon-conditions-' + target + '-' + kind for target in ('iron', 'crystal')
               for kind in ('none', 'coins', 'gel', 'shard'))
    return ids


def oracle_coverage(value, reference, root):
    require(value.get('schema') == 'bluemap.progression.source-oracle.v1' and value.get('personalSavesUsed') is False
            and value.get('float64Encoding') == 'ieee754-binary64-little-endian-hex'
            and value.get('orderedInputEncoding') == 'dictionary-pairs-and-exact-f64-v1',
            'Progression oracle identity, privacy or encoding differs')
    try:
        normalize_exact_mirrors(value)
        exact_count = validate_float64_bits(value)
        catalogs = decode_ordered_input(value['catalogsOrdered'])
    except (ValueError, TypeError, KeyError, OverflowError) as error:
        raise ProgressionDataError('Invalid exact/ordered progression mirrors: ' + str(error)) from error
    require(canonical(catalogs) == canonical(reference['catalogs']), 'Original progression catalog values or IDs differ')
    require(value.get('orders') == reference['orders'] and value.get('bonusOrders') == reference['bonusOrders'],
            'Original dictionary order or gear bonus order differs')
    for key, order in reference['orders'].items():
        require(list(catalogs[key]) == order, 'Lossless catalog order differs: ' + key)
    for key, order in reference['bonusOrders'].items():
        require(list(catalogs['gear'][key].get('bonuses', {})) == order, 'Lossless gear bonus order differs')
    require(isinstance(value.get('newGame'), dict) and set(value['newGame']) == SAVE_FIELDS, 'New-game fields incomplete')
    previous = document(read(root, 'migration/phase-12/inventory-state-oracle.json'), 'previous original new-game defaults')
    require(canonical(value['newGame']) == canonical(previous['newGame']), 'Original new-game defaults changed')
    cases = value.get('cases')
    require(isinstance(cases, list) and cases and all(isinstance(case, dict) and set(case) == CASE_FIELDS for case in cases),
            'Incomplete progression behavior observations')
    ids = [case['id'] for case in cases]
    require(all(isinstance(key, str) and re.fullmatch(r'[a-z0-9_-]{1,120}', key) for key in ids)
            and len(ids) == len(set(ids)) and set(ids) == expected_case_ids(catalogs),
            'Progression case families are missing, duplicated or invented')
    for case in cases:
        require(set(case['initial']) == set(case['expected']) == SAVE_FIELDS,
                'Original progression save fields missing')
        require(isinstance(case['operations'], list) and case['operations']
                and len(case['operations']) == len(case['results']), 'Progression operation/result coverage differs')
    methods = value.get('sourceMethods')
    require(isinstance(methods, list) and methods and len(methods) == len(set(methods))
            and SOURCE_METHODS <= set(methods), 'Source methods missing/duplicated')
    for method in methods:
        require(isinstance(method, str) and method.count('::') == 1, 'Malformed source method')
        path, name = method.split('::')
        require(path in SOURCE_PATHS and re.search(r'\bfunc\s+' + re.escape(name) + r'\s*\(', read(root, path).decode('utf-8')),
                'Unverified original source method: ' + method)
    return {'cases': len(cases), 'caseIds': sorted(ids), 'methods': sorted(methods), 'gear': len(catalogs['gear']),
        'gearSlots': len(catalogs['gearSlots']), 'clothing': len(catalogs['clothing']),
        'clothingSlots': len(catalogs['clothingSlots']), 'hairStyles': len(catalogs['hairM']) + len(catalogs['hairV']),
        'eyeStyles': len(catalogs['eyes']), 'hairColors': len(catalogs['hairColors']),
        'eyeColors': len(catalogs['eyeColors']), 'dyeColors': len(catalogs['dyeColors']),
        'weapons': len(catalogs['weapons']), 'gearUpgradeRecipes': len(catalogs['upgradeRecipes']),
        'weaponUpgradeRoutes': len(catalogs['weaponUpgrades']), 'quests': len(catalogs['quests']),
        'exactFloat64Values': exact_count, 'dictionaryInputOrderPreserved': True}


def asset_guids(root):
    base = Path(root) / ASSETS
    no_links(base); require(base.is_dir(), 'Native progression assets missing')
    rows, seen = [], set()
    for owner in [base, *sorted(path for path in base.rglob('*') if path.suffix != '.meta')]:
        no_links(owner)
        text = read(root, owner.with_name(owner.name + '.meta').relative_to(root).as_posix()).decode('utf-8-sig')
        found = re.findall(r'^guid: ([0-9a-f]{32})$', text, re.M)
        require(len(found) == len(re.findall(r'^guid:', text, re.M)) == 1 and found[0] not in seen,
                'Missing or duplicate progression asset GUID')
        require(('folderAsset: yes' in text) == owner.is_dir(), 'Progression folder metadata differs')
        seen.add(found[0]); rows.append({'path': owner.relative_to(root).as_posix(), 'guid': found[0]})
    require(all(meta.with_suffix('').exists() for meta in base.rglob('*.meta')), 'Orphan progression metadata')
    return rows


def build_contract(root=ROOT):
    root = Path(root)
    for name, digest in REFERENCE_DIGESTS.items():
        require(sha(read(root, name)) == digest, 'Previously verified reference changed: ' + name)
    baseline = document(read(root, 'migration/reference/source-manifest.json'), 'frozen original manifest')
    require(baseline['commit'] == 'a8a988be27835dec979d2523a3a85a34385eac54'
            and baseline['tree'] == '73ba02ea4db0a1c920360b6570f5209ccb970143', 'Original source identity changed')
    entries = {row['path']: row for row in baseline['files']}
    maps = document(read(root, 'migration/reference/maps-inventory.json'), 'frozen original maps')['maps']
    paths = sorted({*SOURCE_PATHS, *(row['base_source'].removeprefix('res://') for row in maps),
                    *(name for name in entries if name.startswith('scripts/data/') and name.endswith('.gd'))})
    anchors = []
    for name in paths:
        frozen, raw = entries[name], read(root, name)
        require(sha(raw) == frozen['sha256'] and len(raw) == frozen['bytes'], 'Preserved progression source changed: ' + name)
        anchors.append({'path': name, 'bytes': len(raw), 'sha256': sha(raw), 'gitBlob': frozen['git_blob']})
    reference = original_references(root)
    raw = read(root, ORACLE)
    coverage = oracle_coverage(document(raw, ORACLE), reference, root)
    require(read(root, RESOURCE) == raw, 'Native progression oracle differs from original observations')
    world_raw = read(root, 'migration/world/index.json')
    world = document(world_raw, 'preserved world descriptors')
    require(len({row['mapId'] for row in world.get('snapshots', [])}) == 37
            and len(world.get('snapshots', [])) == 162, 'Original world descriptor coverage differs')
    return {'schema': 'bluemap.progression.source-contracts.v1', 'phase': 13,
        'baselineCommit': baseline['commit'], 'baselineTree': baseline['tree'],
        'textEncoding': 'UTF-8; CRLF normalized to LF as in committed Git text', 'sourceAnchors': anchors,
        'oracle': {'sourcePath': ORACLE, 'resourcePath': RESOURCE, 'sha256': sha(raw), 'bytes': len(raw), 'coverage': coverage},
        'frozenReferenceFiles': reference['hashes'] + [{'path': name, 'sha256': digest}
                               for name, digest in REFERENCE_DIGESTS.items()],
        'originalDictionaryOrders': reference['orders'],
        'world': {'indexSha256': sha(world_raw), 'maps': 37, 'snapshots': 162,
                  'verifiedBy': 'migration/phase-11/source-contracts.json'},
        'recorders': [{'path': name, 'sha256': sha(read(root, name))} for name in RECORDERS],
        'assetGuids': asset_guids(root), 'requiredNativeChecks': sorted(PROGRESSION_DETAIL_CHECKS),
        'enginesStarted': False, 'personalSavesUsed': False}


def check(root=ROOT):
    value = build_contract(root)
    require(read(Path(root), CONTRACT) == canonical(value), 'Stale/corrupt progression source contracts')
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
        require(not args.report.exists() and not args.report.resolve().is_relative_to(ROOT), 'Use new external evidence path')
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(canonical({'success': True, **value}))
    print('MIGRATION PROGRESSION DATA OK:', len(value['sourceAnchors']), 'preserved sources,',
          value['oracle']['coverage']['cases'], 'original cases')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit('MIGRATION PROGRESSION DATA FAILED: ' + str(error))
