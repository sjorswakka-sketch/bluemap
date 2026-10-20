#!/usr/bin/env python3
"""Record original Godot movement and stamina methods twice in a verified isolated project."""
from __future__ import annotations

import argparse
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
from record_migration_world import ENGINE_VERSION, ERROR, fingerprint, no_symlink

ROOT = Path(__file__).resolve().parents[1]


def validate_float64_bits(data):
    """All numeric oracle values use exact original bytes; JSON decimal text is never an expectation."""
    if data.get('float64Encoding') != 'ieee754-binary64-little-endian-hex' or data.get('vectorEncoding') != 'ieee754-binary32-xy-little-endian-hex':
        raise ValueError('Missing exact source numeric encodings')
    count = 0
    doubles = {'stamina','delay','capacity','regenRate','threshold','delta','amount','factor','multiplier','speedMultiplier','distance','rollTimer','rollCooldown','walkTime','stepDistance','maxBonus','regenBonus','moveBonus'}
    vectors = {'facing','aim','rollDirection','knockback','velocity','direction'}
    def walk(value):
        nonlocal count
        if isinstance(value, dict):
            for key, item in value.items():
                if key in doubles or key in vectors:
                    if not isinstance(item, str) or re.fullmatch(r'[0-9a-f]{16}', item) is None:
                        raise ValueError('Malformed original numeric bytes: '+key)
                    numbers = struct.unpack('<d' if key in doubles else '<ff', bytes.fromhex(item))
                    if not all(math.isfinite(number) for number in numbers): raise ValueError('Nonfinite original bytes: '+key)
                    count += len(numbers)
                elif isinstance(item,(dict,list)): walk(item)
        elif isinstance(value,list):
            for item in value: walk(item)
    # The top-level stamina key names a case list, not a scalar.
    for key in ('stamina','surfaces','equipment','motions','rolls','transition'): walk(data[key])
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('godot')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / 'migration/phase-08/motion-oracle.json')
    parser.add_argument('--evidence-dir', required=True, type=Path)
    args = parser.parse_args()
    task = Path(tempfile.mkdtemp(prefix='bluemap-motion-oracle-'))
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
        (project / 'motion_isolation_probe.gd').write_text(probe, encoding='utf-8')

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
        log = run('isolation', ['-s', 'res://motion_isolation_probe.gd'])
        match = re.search(r'^ISOLATED_USER_DIR=(.+)$', log, re.M)
        if not match or Path(match[1].strip()).name != token:
            raise ValueError('Exact UUID isolation could not be verified')
        user_dir = Path(match[1].strip())
        outputs = []
        for number in (1, 2):
            path = args.evidence_dir / ('run-' + str(number) + '.json')
            run('run-' + str(number), ['--fixed-fps', '60', '--quit-after', '120', '-s', 'res://tools/migration_player_motion_export.gd', '--', '--output', str(path)], 'MIGRATION PLAYER MOTION EXPORT OK')
            outputs.append(canonical_bytes(json.loads(path.read_text(encoding='utf-8'))))
        if outputs[0] != outputs[1]:
            raise ValueError('Original engine oracle was not deterministic across two fresh processes')
        if fingerprint(ROOT) != before:
            raise ValueError('Original game source changed during recording')
        data = json.loads(outputs[0])
        if len(data['stamina']) != 26 or len(data['surfaces']) != 83 or len(data['equipment']) != 8 or len(data['motions']) != 15 or len(data['rolls']) != 4:
            raise ValueError('Oracle coverage changed')
        if data.get('sourceHashes') != {name: hashlib.sha256((ROOT / name).read_bytes().replace(b'\r\n', b'\n')).hexdigest() for name in data.get('sourceHashes', {})} or len(data.get('sourceHashes', {})) != 5:
            raise ValueError('Original movement source hashes differ')
        float64_values = validate_float64_bits(data)
        if args.check:
            if args.output.read_bytes().replace(b'\r\n', b'\n') != outputs[0]:
                raise ValueError('Fresh original methods disagree with checked-in state oracle')
        else:
            if args.output.exists():
                raise ValueError('Never overwrite an existing oracle; use --check or an explicit fresh --output')
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_bytes(outputs[0])
        (args.evidence_dir / 'motion-oracle.json').write_bytes(outputs[0])
        receipt = {'schema': 1, 'success': True, 'engineVersion': ENGINE_VERSION, 'checkOnly': args.check,
                   'freshProcessRuns': 2, 'sourceUnchanged': True, 'personalSavesUsed': False,
                   'stamina': len(data['stamina']), 'surfaces': len(data['surfaces']), 'equipment': len(data['equipment']), 'motions': len(data['motions']), 'rolls': len(data['rolls']),
                   'exactNumericValues': float64_values,
                   'sha256': hashlib.sha256(outputs[0]).hexdigest(),
                   'sourceHashes': {name: digest for name, digest in before.items() if name in ['scripts/core/movement.gd', 'scripts/core/game_state.gd', 'scripts/core/equipment.gd', 'scripts/data/tiles.gd', 'scripts/entities/player.gd']}}
        (args.evidence_dir / 'receipt.json').write_bytes(canonical_bytes(receipt))
        print('MIGRATION PLAYER MOTION ORACLE OK: 26 stamina, 83 surfaces, 8 equipment, 15 motion, 4 roll, 1 transition cases; 2 fresh processes')
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('MIGRATION PLAYER MOTION ORACLE FAILED:', error, file=sys.stderr)
        return 1
    finally:
        if user_dir is not None and user_dir.name == token and user_dir.exists():
            shutil.rmtree(user_dir)
        print('Isolated oracle project retained:', task)


if __name__ == '__main__':
    raise SystemExit(main())
