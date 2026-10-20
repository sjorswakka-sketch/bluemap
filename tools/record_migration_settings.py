#!/usr/bin/env python3
"""Record the original Godot ConfigFile settings and saved bindings twice in a verified isolated project."""
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('godot')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / 'migration/phase-09/settings-oracle.json')
    parser.add_argument('--evidence-dir', required=True, type=Path)
    args = parser.parse_args()
    task = Path(tempfile.mkdtemp(prefix='bluemap-settings-'))
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
        (project / 'settings_isolation_probe.gd').write_text(probe, encoding='utf-8')

        def run(label, arguments, marker=None):
            process = subprocess.run([engine, '--headless', '--path', str(project), *arguments], cwd=project,
                                     capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=600,
                                     env=dict(os.environ, BLUEMAP_LANG='nl'))
            log = process.stdout + process.stderr
            (args.evidence_dir / (label + '.log')).write_text(log, encoding='utf-8')
            checked_log = re.sub(r'ERROR: ConfigFile parse error at [^\n]*\n(?:\s+at: [^\n]*\n)?', '', log)
            if process.returncode or ERROR.search(checked_log) or (marker and marker not in log):
                raise ValueError(label + ' failed: ' + log[-10000:])
            return log

        run('import', ['--editor', '--import'])
        log = run('isolation', ['-s', 'res://settings_isolation_probe.gd'])
        match = re.search(r'^ISOLATED_USER_DIR=(.+)$', log, re.M)
        if not match or Path(match[1].strip()).name != token:
            raise ValueError('Exact UUID isolation could not be verified')
        user_dir = Path(match[1].strip())
        outputs = []
        for number in (1, 2):
            path = args.evidence_dir / ('run-' + str(number) + '.json')
            run('run-' + str(number), ['-s', 'res://tools/migration_settings_export.gd', '--', '--output', str(path)], 'MIGRATION SETTINGS EXPORT OK')
            outputs.append(canonical_bytes(json.loads(path.read_text(encoding='utf-8'))))
        if outputs[0] != outputs[1]:
            raise ValueError('Original engine oracle was not deterministic across two fresh processes')
        if fingerprint(ROOT) != before:
            raise ValueError('Original game source changed during recording')
        data = json.loads(outputs[0])
        if len(data['cases']) != 10:
            raise ValueError('Settings oracle coverage changed')
        if args.check:
            if args.output.read_bytes().replace(b'\r\n', b'\n') != outputs[0]:
                raise ValueError('Fresh original methods disagree with checked-in input oracle')
        else:
            if args.output.exists():
                raise ValueError('Never overwrite an existing oracle; use --check or an explicit fresh --output')
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_bytes(outputs[0])
        (args.evidence_dir / 'settings-oracle.json').write_bytes(outputs[0])
        receipt = {'schema': 1, 'success': True, 'engineVersion': ENGINE_VERSION, 'checkOnly': args.check,
                   'freshProcessRuns': 2, 'sourceUnchanged': True, 'personalSavesUsed': False,
                   'cases': len(data['cases']),
                   'sha256': hashlib.sha256(outputs[0]).hexdigest(),
                   'sourceHashes': {name: digest for name, digest in before.items() if name in ['project.godot', 'scripts/core/input_manager.gd', 'scripts/core/lang.gd', 'scripts/core/sound.gd', 'scripts/core/game_state.gd']}}
        (args.evidence_dir / 'receipt.json').write_bytes(canonical_bytes(receipt))
        print('MIGRATION SETTINGS ORACLE OK: 10 exact ConfigFile cases; 2 fresh processes')
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('MIGRATION SETTINGS ORACLE FAILED:', error, file=sys.stderr)
        return 1
    finally:
        if user_dir is not None and user_dir.name == token and user_dir.exists():
            shutil.rmtree(user_dir)
        print('Isolated oracle project retained:', task)


if __name__ == '__main__':
    raise SystemExit(main())

