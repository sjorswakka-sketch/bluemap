#!/usr/bin/env python3
"""Record the original Godot player combat, projectiles and techniques methods twice in a verified isolated project."""
from __future__ import annotations

import argparse
import copy
from decimal import Decimal, ROUND_HALF_EVEN, ROUND_HALF_UP, localcontext
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import struct
import sys
import tempfile
import uuid

from migration_data_codec import canonical_bytes
from record_migration_world import ENGINE_VERSION, ERROR, fingerprint, first_differences, no_symlink

ROOT = Path(__file__).resolve().parents[1]
COMPARISON_POLICY = 'exact-f64-with-validated-godot-15-digit-mirrors-v1'
from record_migration_inventory_state import (decode_ordered_input, decode_float64_witness,
    validate_float64_bits, normalize_exact_mirrors as _normalize_cases)

def normalize_exact_mirrors(document):
    if document.get("float64Encoding") != "ieee754-binary64-little-endian-hex":
        raise ValueError("Missing exact combat Float64 encoding")
    result = _normalize_cases(document)
    synthetic = {'orderedInputEncoding': document['orderedInputEncoding'], 'cases': [{
        'id': 'catalogs', 'initial': document['catalogs'], 'initialExact': document['catalogsExact'],
        'initialOrdered': document['catalogsOrdered'], 'operations': [], 'operationsExact': [],
        'operationsOrdered': [], 'results': [], 'resultsExact': [], 'expected': {}, 'expectedExact': {}}]}
    result['catalogs'] = _normalize_cases(synthetic)['cases'][0]['initial']
    for index, row in enumerate(document['cases']):
        for field in ('transient', 'initialPlayer'):
            extra = {'orderedInputEncoding': document['orderedInputEncoding'], 'cases': [{
                'id': row['id'] + '/' + field, 'initial': row[field], 'initialExact': row[field + 'Exact'],
                'initialOrdered': row[field + 'Ordered'], 'operations': [], 'operationsExact': [],
                'operationsOrdered': [], 'results': [], 'resultsExact': [], 'expected': {}, 'expectedExact': {}}]}
            result['cases'][index][field] = _normalize_cases(extra)['cases'][0]['initial']
    return result

def validate_ordered_inputs(document):
    normalize_exact_mirrors(document)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('godot')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / 'migration/phase-14/combat-oracle.json')
    parser.add_argument('--evidence-dir', required=True, type=Path)
    args = parser.parse_args()
    task = Path(tempfile.mkdtemp(prefix='bluemap-combat-oracle-'))
    project = task / 'project'
    token = 'Bluemap-Codex-Tests-' + uuid.uuid4().hex
    before = fingerprint(ROOT)
    user_dir = None
    try:
        no_symlink(args.evidence_dir)
        no_symlink(args.output)
        if args.evidence_dir.exists() and any(args.evidence_dir.iterdir()):
            raise ValueError('Evidence directory must be new or empty')
        if args.evidence_dir.resolve().is_relative_to(ROOT.resolve()):
            raise ValueError('Evidence belongs outside the source repository')
        args.evidence_dir.mkdir(parents=True, exist_ok=True)
        engine = shutil.which(args.godot)
        if not engine:
            raise ValueError('Godot executable not found')
        version = subprocess.run([engine, '--version'], capture_output=True, text=True, timeout=30)
        if version.returncode or version.stdout.strip() != ENGINE_VERSION:
            raise ValueError('Requires exact Godot ' + ENGINE_VERSION)
        shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(
            '.git', '.godot', '.testdata', 'build', 'dist', '__pycache__', 'unity', 'migration'))
        settings = project / 'project.godot'
        text = settings.read_text(encoding='utf-8')
        text = re.sub(r'^config/name=.*$', 'config/name=' + json.dumps(token), text, flags=re.M)
        text = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n?', '', text, flags=re.M)
        text = text.replace('[application]', '[application]\nconfig/use_custom_user_dir=false', 1)
        settings.write_text(text, encoding='utf-8')
        probe = ('extends SceneTree\nfunc _initialize():\n\tvar p:=OS.get_user_data_dir()\n'
                 '\tprint("ISOLATED_USER_DIR="+p)\n\tquit(0 if p.replace(char(92),"/").get_file()==' + json.dumps(token) + ' else 1)\n')
        (project / 'route_isolation_probe.gd').write_text(probe, encoding='utf-8')

        def run(label, arguments, marker=None):
            process = subprocess.run([engine, '--headless', '--path', str(project), *arguments], cwd=project,
                                     capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=600,
                                     env=dict(os.environ, BLUEMAP_LANG='nl'))
            log = process.stdout + process.stderr
            (args.evidence_dir / (label + '.log')).write_text(log, encoding='utf-8')
            if process.returncode or ERROR.search(log) or (marker and marker not in log):
                raise ValueError(label + ' failed: ' + log[-10000:])
            return log

        run('import', ['--editor', '--import'])
        log = run('isolation', ['-s', 'res://route_isolation_probe.gd'])
        match = re.search(r'^ISOLATED_USER_DIR=(.+)$', log, re.M)
        if not match or Path(match[1].strip()).name != token:
            raise ValueError('Exact UUID isolation could not be verified')
        user_dir = Path(match[1].strip())
        outputs = []
        for number in (1, 2):
            path = args.evidence_dir / ('run-' + str(number) + '.json')
            run('run-' + str(number), ['-s', 'res://tools/migration_combat_export.gd', '--', '--output', str(path)], 'MIGRATION COMBAT EXPORT OK')
            outputs.append(canonical_bytes(json.loads(path.read_text(encoding='utf-8'))))
        if outputs[0] != outputs[1]:
            raise ValueError('Original engine oracle was not deterministic across two fresh processes')
        if fingerprint(ROOT) != before:
            raise ValueError('Original game source changed during recording')
        data = json.loads(outputs[0])
        if data['schema'] != 'bluemap.combat.source-oracle.v1' or not data['cases'] or not data['catalogs']['enemies']:
            raise ValueError('Combat oracle coverage changed')
        float64_values = validate_float64_bits(data)
        comparison = canonical_bytes(normalize_exact_mirrors(data))
        reference = None
        if args.check:
            reference = args.output.read_bytes().replace(b'\r\n', b'\n')
            normalized_reference = canonical_bytes(normalize_exact_mirrors(json.loads(reference)))
            if normalized_reference != comparison:
                difference = {'schema': 1, 'kind': 'frozen-reference-mismatch',
                              'referenceSha256': hashlib.sha256(reference).hexdigest(),
                              'actualSha256': hashlib.sha256(outputs[0]).hexdigest(),
                              'examples': first_differences(json.loads(reference), data, limit=20)}
                (args.evidence_dir / 'difference.json').write_bytes(canonical_bytes(difference))
                print('COMBAT REFERENCE DIFFERENCES ' + json.dumps(difference, ensure_ascii=False), flush=True)
                raise ValueError('Fresh original methods disagree with checked-in state oracle')
        else:
            if args.output.exists():
                raise ValueError('Never overwrite an existing oracle; use --check or an explicit fresh --output')
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_bytes(outputs[0])
        (args.evidence_dir / 'combat-oracle.json').write_bytes(outputs[0])
        receipt = {'schema': 1, 'success': True, 'engineVersion': ENGINE_VERSION, 'checkOnly': args.check,
                   'freshProcessRuns': 2, 'sourceUnchanged': True, 'personalSavesUsed': False,
                   'cases': len(data['cases']), 'enemies': len(data['catalogs']['enemies']), 'loadedSnapshots': len(data['catalogs']['loadedActors']), 'loadedActors': sum(len(row['actors']) for row in data['catalogs']['loadedActors']),
                   'exactFloat64Values': float64_values,
                   'sha256': hashlib.sha256(outputs[0]).hexdigest(),
                   'comparisonPolicy': COMPARISON_POLICY,
                   'exactComparisonSha256': hashlib.sha256(comparison).hexdigest(),
                   'referenceSha256': hashlib.sha256(reference).hexdigest() if reference is not None else None,
                   'sourceHashes': {name: digest for name, digest in before.items() if name in sorted({method.split('::')[0] for method in data['sourceMethods']} | {'scripts/entities/player.gd','scripts/entities/combat_actions.gd','scripts/entities/coastal_styles.gd','scripts/entities/enemy.gd','scripts/entities/guardian.gd','scripts/entities/guardian_shard.gd','scripts/entities/guardian_pillar.gd','scripts/entities/projectile.gd','scripts/entities/arrow.gd','scripts/data/enemies.gd','scripts/core/equipment.gd','scripts/core/appearance.gd','scripts/data/items.gd','scripts/data/ext/uitrusting.gd','scripts/data/ext/uiterlijk.gd','scripts/data/ext/beroepen.gd','scripts/data/shops.gd','scripts/data/dialogue.gd','scripts/ui/appearance_page.gd','scripts/ui/equipment_page.gd','scripts/ui/progression_page.gd','scripts/core/movement.gd'})}}
        (args.evidence_dir / 'receipt.json').write_bytes(canonical_bytes(receipt))
        print('MIGRATION COMBAT ORACLE OK: 2 fresh processes')
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('MIGRATION COMBAT ORACLE FAILED:', error, file=sys.stderr)
        return 1
    finally:
        if user_dir is not None and user_dir.name == token and user_dir.exists():
            shutil.rmtree(user_dir)
        print('Isolated oracle project retained:', task)


if __name__ == '__main__':
    raise SystemExit(main())
