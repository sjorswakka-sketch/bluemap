#!/usr/bin/env python3
"""Record the original Godot world access methods twice in a verified isolated project."""
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


def decode_float64_witness(value):
    if (type(value) is not dict or set(value) != {'$f64'} or
            type(value['$f64']) is not str or
            not re.fullmatch(r'[0-9a-f]{16}', value['$f64'])):
        raise ValueError('Invalid exact Float64 witness')
    number = struct.unpack('<d', bytes.fromhex(value['$f64']))[0]
    if not math.isfinite(number):
        raise ValueError('Invalid exact Float64 witness')
    return number


def normalize_exact_mirrors(document):
    """Validate redundant Godot JSON decimals against their unchanged exact witnesses.

    Godot 4.4.1's platform CRTs choose different tie rounding for a 15-digit
    decimal. Only these explicitly paired fields may use either rendering.
    The exact IEEE bytes and every other field still participate in comparison.
    """
    def pair(plain, exact, path):
        if type(exact) is dict:
            if '$f64' in exact:
                number = decode_float64_witness(exact)
                if type(plain) is not float or not math.isfinite(plain):
                    raise ValueError('Invalid Float64 decimal mirror at ' + path)
                decimal = Decimal.from_float(number)
                quantum = Decimal(1).scaleb(decimal.adjusted() - 14)
                with localcontext() as context:
                    context.prec = 128
                    renderings = [float(decimal.quantize(quantum, rounding=mode))
                                  for mode in (ROUND_HALF_EVEN, ROUND_HALF_UP)]
                if not any(struct.pack('<d', plain) == struct.pack('<d', candidate)
                           for candidate in renderings):
                    raise ValueError('Invalid Godot 15-digit decimal mirror at ' + path)
                return number
            if type(plain) is not dict or plain.keys() != exact.keys():
                raise ValueError('Mismatched exact dictionary shape at ' + path)
            return {key: pair(plain[key], child, path + '/' + key)
                    for key, child in exact.items()}
        if type(exact) is list:
            if type(plain) is not list or len(plain) != len(exact):
                raise ValueError('Mismatched exact array shape at ' + path)
            return [pair(left, right, path + '/' + str(index))
                    for index, (left, right) in enumerate(zip(plain, exact))]
        if (type(exact) not in (str, int, bool, type(None)) or
                type(plain) is not type(exact) or plain != exact):
            raise ValueError('Mismatched exact non-float value at ' + path)
        return plain

    if type(document) is not dict:
        raise ValueError('World access oracle must be an object')
    result = copy.deepcopy(document)
    for collection, fields in (('snapshots', ('state',)),
                               ('cases', ('initial', 'operation', 'result', 'expected'))):
        if type(result.get(collection)) is not list:
            raise ValueError('Missing world access oracle collection ' + collection)
        for index, row in enumerate(result[collection]):
            if type(row) is not dict:
                raise ValueError('Invalid world access oracle row')
            for field in fields:
                if field not in row or field + 'Exact' not in row:
                    raise ValueError('Missing exact mirror pair ' + collection + '/' + field)
                row[field] = pair(row[field], row[field + 'Exact'],
                                  '$/' + collection + '/' + str(index) + '/' + field)
    return result


def validate_float64_bits(value):
    count = 0
    if isinstance(value, dict):
        if '$f64' in value:
            decode_float64_witness(value)
            return 1
        for child in value.values():
            count += validate_float64_bits(child)
    elif isinstance(value, list):
        for child in value:
            count += validate_float64_bits(child)
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('godot')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / 'migration/phase-11/world-access-oracle.json')
    parser.add_argument('--evidence-dir', required=True, type=Path)
    args = parser.parse_args()
    task = Path(tempfile.mkdtemp(prefix='bluemap-world-access-oracle-'))
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
            run('run-' + str(number), ['-s', 'res://tools/migration_world_access_export.gd', '--', '--output', str(path)], 'MIGRATION WORLD ACCESS EXPORT OK')
            outputs.append(canonical_bytes(json.loads(path.read_text(encoding='utf-8'))))
        if outputs[0] != outputs[1]:
            raise ValueError('Original engine oracle was not deterministic across two fresh processes')
        if fingerprint(ROOT) != before:
            raise ValueError('Original game source changed during recording')
        data = json.loads(outputs[0])
        if len(data['snapshots']) != 162 or len(data['cases']) != 15:
            raise ValueError('World access oracle coverage changed')
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
                print('WORLD ACCESS REFERENCE DIFFERENCES ' + json.dumps(difference, ensure_ascii=False), flush=True)
                raise ValueError('Fresh original methods disagree with checked-in state oracle')
        else:
            if args.output.exists():
                raise ValueError('Never overwrite an existing oracle; use --check or an explicit fresh --output')
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_bytes(outputs[0])
        (args.evidence_dir / 'world-access-oracle.json').write_bytes(outputs[0])
        receipt = {'schema': 1, 'success': True, 'engineVersion': ENGINE_VERSION, 'checkOnly': args.check,
                   'freshProcessRuns': 2, 'sourceUnchanged': True, 'personalSavesUsed': False,
                   'cases': len(data['cases']), 'snapshots': len(data['snapshots']),
                   'exactFloat64Values': float64_values,
                   'sha256': hashlib.sha256(outputs[0]).hexdigest(),
                   'comparisonPolicy': COMPARISON_POLICY,
                   'exactComparisonSha256': hashlib.sha256(comparison).hexdigest(),
                   'referenceSha256': hashlib.sha256(reference).hexdigest() if reference is not None else None,
                   'sourceHashes': {name: digest for name, digest in before.items() if name in ['scripts/core/game_state.gd', 'scripts/world.gd', 'scripts/entities/gate.gd', 'scripts/entities/portal.gd', 'scripts/entities/diepte_gate.gd', 'scripts/entities/diepte_seal.gd', 'scripts/core/access_points.gd', 'scripts/core/fast_travel.gd', 'scripts/core/tides.gd', 'scripts/entities/tide_cove.gd', 'scripts/entities/living_scenery.gd', 'scripts/entities/meer_kast.gd', 'scripts/ui/coast_voyage.gd', 'scripts/ui/coast_routes.gd', 'scripts/data/arena.gd', 'scripts/data/ext/boog.gd', 'scripts/data/ext/echo.gd', 'scripts/core/living_world.gd', 'scripts/core/regional_adventures.gd', 'scripts/core/first_route.gd', 'scripts/data/quests.gd', 'scripts/core/personal_home.gd', 'scripts/data/house_catalog.gd', 'scripts/entities/home_station.gd', 'scripts/entities/house_furniture.gd']}}
        (args.evidence_dir / 'receipt.json').write_bytes(canonical_bytes(receipt))
        print('MIGRATION WORLD ACCESS ORACLE OK: 162 loaded worlds; 2 fresh processes')
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('MIGRATION WORLD ACCESS ORACLE FAILED:', error, file=sys.stderr)
        return 1
    finally:
        if user_dir is not None and user_dir.name == token and user_dir.exists():
            shutil.rmtree(user_dir)
        print('Isolated oracle project retained:', task)


if __name__ == '__main__':
    raise SystemExit(main())
