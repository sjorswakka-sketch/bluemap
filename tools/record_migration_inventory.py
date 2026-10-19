#!/usr/bin/env python3
"""Record phase-1 catalogs and registry snapshots in a verified disposable Godot copy.

No game source or actual saves are run or changed. These are NOT phase-5 runtime
exports: registry composition and legacy profession-node declarations are recorded
without simulating quest/getij states, world.load_map, physics or dynamic actors.

Usage: python tools/record_migration_inventory.py /path/to/godot [--check] [--keep]
Output: migration/reference/content-inventory.json and maps-inventory.json.
Complete execution/isolation evidence is always retained outside the source tree.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

ERROR = re.compile(r'SCRIPT ERROR|Parse Error|^ERROR:', re.MULTILINE)
FILES = ('content-inventory.json', 'maps-inventory.json')


def canonical(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + '\n').encode('utf8')


def validate(content, maps):
    assert content['schema'] == 'bluemap.migration.content-inventory.v1'
    assert not content['failures'], content['failures']
    assert maps['scope'] == 'registry_get_map_baseline_only'
    assert maps['not_phase5_runtime_export'] is True
    catalogs = content['catalogs']
    needed = {'items', 'weapons', 'quests', 'talks', 'enemies', 'npcs', 'shops',
              'achievements', 'recipes', 'professions', 'resources', 'gear',
              'gear_slots', 'clothes', 'clothing_slots', 'hair_m', 'hair_v',
              'eye_styles', 'genders', 'hair_colors', 'eye_colors', 'dye_colors',
              'consumables', 'map_markers', 'maps', 'tile_types', 'solid_tile_types',
              'sounds', 'music_tracks', 'conditions', 'actions', 'formats',
              'object_types', 'special_pickups'}
    assert needed <= catalogs.keys(), sorted(needed - catalogs.keys())
    ids = {}
    for name, catalog in catalogs.items():
        entries = catalog['entries']
        ids[name] = {entry['id'] for entry in entries}
        assert len(ids[name]) == len(entries) == catalog['count'], name
        assert all(entry['sources'] for entry in entries), 'unsourced IDs: ' + name
    assert {'npc', 'enemy', 'pickup', 'chest', 'portal', 'trigger'} <= ids['object_types']
    assert {'flag', 'no_flag', 'has', 'quest', 'step'} <= ids['conditions']
    assert {'give', 'take', 'set_flag', 'start_quest', 'finish_quest', 'boss_start', 'music', 'lock_arena'} <= ids['actions']
    assert {'coins', 'crystals', 'gel', 'shards'} <= ids['formats']
    assert ids['special_pickups'] == {'coin', 'heart'}
    assert ids['gear'] <= ids['items'] and ids['clothes'] <= ids['items']
    for entry in catalogs['recipes']['entries']:
        recipe = entry['value']
        assert recipe['output'] in ids['items'], entry['id']
        assert set(recipe.get('inputs', {})) <= ids['items'], entry['id']
        assert recipe['skill'] in ids['professions'], entry['id']
    for entry in catalogs['resources']['entries']:
        assert entry['value']['item'] in ids['items'], entry['id']
    assert ids['consumables'] <= ids['items']
    assert ids['maps'] == {row['id'] for row in maps['maps']}
    assert maps['map_count'] == len(maps['maps'])
    assert maps['tile_count'] == sum(row['width'] * row['height'] for row in maps['maps'])
    map_ids = ids['maps']
    explicit_resources = set()
    legacy_keys = set()
    for row in maps['maps']:
        snapshot = row['registry_snapshot']
        assert len(snapshot['rows']) == row['height']
        assert all(len(line) == row['width'] for line in snapshot['rows']), row['id']
        assert set(row['terrain_counts']) <= ids['tile_types'], row['id']
        assert sum(row['terrain_counts'].values()) == row['tile_count']
        assert len(row['object_slots']) == len(snapshot['objects'])
        for index, (slot, obj) in enumerate(zip(row['object_slots'], snapshot['objects'])):
            assert slot['index'] == index and slot['type'] == obj['type']
            assert slot['enabled'] == obj.get('enabled', True)
            assert slot['legacy_slot_key'] == f"{obj['type']}:{row['id']}:{index}"
            assert slot['legacy_slot_key'] not in legacy_keys
            legacy_keys.add(slot['legacy_slot_key'])
            assert obj['type'] in ids['object_types'], (row['id'], obj['type'])
            if obj['type'] == 'profession_resource':
                assert obj['kind'] in ids['resources']
                assert obj['id'] not in explicit_resources, obj['id']
                explicit_resources.add(obj['id'])
        for node in row['post_registry_legacy_resources']:
            assert node['id'] not in explicit_resources, node['id']
            assert node['value']['kind'] in ids['resources']
            explicit_resources.add(node['id'])
        assert all(edge['to'] in map_ids for edge in row['portal_edges'])
    assert maps['registry_object_slots'] == len(legacy_keys)
    assert maps['legacy_resource_count'] == sum(len(row['post_registry_legacy_resources']) for row in maps['maps'])
    if content['source_version'] == '0.34.0-preview':
        assert maps['map_count'] == 37 and maps['tile_count'] == 49758
        for name, count in [('tile_types', 80), ('hair_m', 45), ('hair_v', 45), ('clothes', 24), ('gear_slots', 5)]:
            assert catalogs[name]['count'] == count, (name, catalogs[name]['count'])
    return {'catalogs': len(catalogs), 'catalog_counts': {name: catalog['count'] for name, catalog in sorted(catalogs.items())},
            'declared_tables': len(content['declarations']), 'production_scripts': len(content['source_files']),
            'maps': maps['map_count'], 'tiles': maps['tile_count'], 'registry_slots': len(legacy_keys),
            'legacy_resources': maps['legacy_resource_count'], 'explicit_resource_ids': len(explicit_resources)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('godot', nargs='?', default='godot')
    parser.add_argument('--output-dir', type=Path, help='Reference folder; default migration/reference')
    parser.add_argument('--check', action='store_true', help='Compare to existing reference; never replace it')
    parser.add_argument('--keep', action='store_true', help='Retain the disposable project as well as logs')
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent
    engine = shutil.which(args.godot)
    if not engine:
        parser.error('Godot executable not found: ' + args.godot)
    destination = (args.output_dir or source / 'migration' / 'reference').resolve()
    task = Path(tempfile.mkdtemp(prefix='bluemap-migration-inventory-'))
    project = task / 'project'
    token = 'Bluemap-Codex-Tests-' + uuid.uuid4().hex
    user_dir = None
    succeeded = False
    receipt = {'kind': 'phase1_read_only_inventory', 'source_path': str(source), 'token': token,
               'project': str(project), 'destination': str(destination), 'check_only': args.check,
               'not_phase5_runtime_export': True}
    print('Inventory evidence:', task, flush=True)
    original_files = sorted([source / 'project.godot', *source.glob('scripts/**/*.gd'), *source.glob('scenes/**/*.tscn')])
    before = {str(p.relative_to(source)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest() for p in original_files}
    try:
        commit = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=source, capture_output=True, text=True)
        receipt['checkout_commit'] = commit.stdout.strip() if commit.returncode == 0 else None
        shutil.copytree(source, project, ignore=shutil.ignore_patterns('.git', '.godot', '.testdata', 'build', 'dist', '__pycache__'))
        settings = project / 'project.godot'
        text = settings.read_text(encoding='utf8')
        text = re.sub(r'^config/name=.*$', 'config/name=' + json.dumps(token), text, flags=re.MULTILINE)
        text = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n?', '', text, flags=re.MULTILINE)
        text = text.replace('[application]', '[application]\nconfig/use_custom_user_dir=false', 1)
        settings.write_text(text, encoding='utf8')
        probe = "\n".join([
            'extends SceneTree',
            'func _initialize():',
            "\tvar path:=OS.get_user_data_dir()",
            "\tprint(\"ISOLATED_USER_DIR=\"+path)",
            "\tquit(0 if path.replace(char(92), \"/\").get_file() == " + json.dumps(token) + " else 1)",
            '',
        ])
        (project / 'inventory_isolation_probe.gd').write_text(probe, encoding='utf8')
        env = dict(os.environ, BLUEMAP_LANG='nl')
        def run(label, arguments, marker=None):
            result = subprocess.run([str(Path(engine).resolve()), '--headless', '--path', str(project), *arguments],
                                    cwd=project, capture_output=True, text=True, encoding='utf8', errors='replace', timeout=600, env=env)
            log = result.stdout + result.stderr
            (task / (label + '.log')).write_text(log, encoding='utf8')
            if result.returncode or ERROR.search(log) or (marker and marker not in log):
                raise RuntimeError(label + ' failed:\n' + log[-14000:])
            return log
        run('import', ['--editor', '--import'])
        log = run('isolation', ['-s', 'res://inventory_isolation_probe.gd'])
        found = re.search(r'^ISOLATED_USER_DIR=(.+)$', log, re.MULTILINE)
        if not found or Path(found[1].strip()).name != token:
            raise RuntimeError('Could not verify the exact UUID save directory')
        user_dir = Path(found[1].strip())
        receipt['verified_user_dir'] = str(user_dir)
        print('Verified separate save directory:', user_dir, flush=True)
        runs = []
        for number in (1, 2):
            export = task / ('export-' + str(number))
            run('export-' + str(number), ['-s', 'res://tools/migration_inventory.gd', '--', '--output-dir', str(export)], 'MIGRATION INVENTORY OK')
            runs.append({name: json.loads((export / name).read_text(encoding='utf8')) for name in FILES})
        for name in FILES:
            assert canonical(runs[0][name]) == canonical(runs[1][name]), 'Non-repeatable inventory: ' + name
        summary = validate(runs[0][FILES[0]], runs[0][FILES[1]])
        # Original project settings are used for source identity; UUID settings never enter a reference.
        normalized = {str(p.relative_to(source)).replace('\\', '/'): hashlib.sha256(p.read_bytes().replace(b'\r\n', b'\n')).hexdigest() for p in original_files}
        fingerprint = hashlib.sha256(canonical(normalized)).hexdigest()
        after = {p.relative_to(source).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in original_files}
        assert before == after, 'Source game files changed during inventory recording'
        for name in FILES:
            payload = runs[0][name]
            payload['source_fingerprint'] = fingerprint
            payload['source_fingerprint_scope'] = 'LF-normalized UTF-8 project.godot + scripts/**/*.gd + scenes/**/*.tscn; assets and recovery are registered separately'
            blob = canonical(payload)
            target = destination / name
            if args.check:
                assert target.exists() and canonical(json.loads(target.read_text(encoding='utf8'))) == blob, 'Reference differs: ' + str(target)
            else:
                destination.mkdir(parents=True, exist_ok=True)
                target.write_bytes(blob)
            receipt.setdefault('outputs', {})[name] = {'sha256': hashlib.sha256(blob).hexdigest(), 'bytes': len(blob)}
        receipt.update({'success': True, 'repeatable_exports': 2, 'source_unchanged': True,
                        'source_fingerprint': fingerprint, 'summary': summary})
        print(json.dumps(summary, ensure_ascii=False, sort_keys=True), flush=True)
        print('MIGRATION INVENTORY CHECK OK' if args.check else 'MIGRATION INVENTORY RECORDED OK', flush=True)
        succeeded = True
        return 0
    except (AssertionError, RuntimeError, OSError, subprocess.SubprocessError) as exc:
        receipt.update({'success': False, 'error': str(exc)})
        print(str(exc), file=sys.stderr, flush=True)
        return 1
    finally:
        (task / 'receipt.json').write_bytes(canonical(receipt))
        print('Complete evidence retained:', task, flush=True)
        if succeeded and not args.keep:
            assert project.resolve().parent == task.resolve() and project.name == "project"
            shutil.rmtree(project)
        # Delete only the verified UUID directory, never a source or real save directory.
        if user_dir is not None and user_dir.name == token and user_dir.exists():
            shutil.rmtree(user_dir)


if __name__ == '__main__':
    sys.exit(main())
