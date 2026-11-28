#!/usr/bin/env python3
"""Let the original Godot game load the saves Unity writes back, twice, in a verified isolated project.

Input is the set of saves the Unity exporter wrote for the 24 recorded original saves of phase 9. For every case the
real game first loads the old save and saves it again in its own way, then loads Unity's bytes; both must give the
same state. Nothing personal is read: the project copy has its own UUID user directory.
"""
from __future__ import annotations

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

from migration_data_codec import canonical_bytes
from record_migration_world import ENGINE_VERSION, ERROR, fingerprint, no_symlink

ROOT = Path(__file__).resolve().parents[1]
SAVE_ORACLE = ROOT / 'migration/phase-09/save-oracle.json'
OUTPUT = ROOT / 'migration/phase-22/export-oracle.json'


def reduce(data: dict) -> dict:
    """Keep what the proof needs: the bytes Unity wrote, that Godot took them, and the state it reached."""
    rows = []
    for row in data['cases']:
        equal = canonical_bytes(row['afterOwnSave']) == canonical_bytes(row['expected'])
        rows.append({'id': row['id'], 'sha256': row['sha256'], 'godotAccepted': row['godotAccepted'],
                     'godotStateEqualsOriginal': equal, 'expected': row['expected'], 'useLoadPosition': row['useLoadPosition']})
    return {**{key: value for key, value in data.items() if key != 'cases'}, 'cases': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('godot')
    parser.add_argument('--exports', required=True, type=Path, help='JSON object: case id -> save text written by Unity')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--evidence-dir', required=True, type=Path)
    args = parser.parse_args()
    task = Path(tempfile.mkdtemp(prefix='bluemap-return-oracle-'))
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
        exports = json.loads(args.exports.read_text(encoding='utf-8'))
        source = json.loads(SAVE_ORACLE.read_text(encoding='utf-8'))
        if not isinstance(exports, dict) or set(exports) != {case['id'] for case in source['cases']} or len(exports) != 24:
            raise ValueError('Unity must have written a save for exactly the 24 recorded cases')
        cases = [{'id': case['id'], 'inputJson': case['inputJson'], 'exportJson': exports[case['id']]} for case in source['cases']]
        case_file = task / 'return-cases.json'
        case_file.write_text(json.dumps(cases, ensure_ascii=False), encoding='utf-8')
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
            run('run-' + str(number), ['--fixed-fps', '60', '--quit-after', '240', '-s', 'res://tools/migration_return_export.gd',
                                       '--', '--cases', str(case_file), '--output', str(path)], 'MIGRATION RETURN EXPORT OK')
            outputs.append(canonical_bytes(reduce(json.loads(path.read_text(encoding='utf-8')))))
        if outputs[0] != outputs[1]:
            raise ValueError('Original engine was not deterministic across two fresh processes')
        if fingerprint(ROOT) != before:
            raise ValueError('Original game source changed during recording')
        data = json.loads(outputs[0])
        refused = [row['id'] for row in data['cases'] if not (row['godotAccepted'] and row['godotStateEqualsOriginal'])]
        if len(data['cases']) != 24 or refused:
            raise ValueError('Godot does not reach the same progress from Unity\'s save: ' + ', '.join(refused))
        for row in data['cases']:
            if row['sha256'] != hashlib.sha256(exports[row['id']].encode('utf-8')).hexdigest():
                raise ValueError('Godot read other bytes than Unity wrote: ' + row['id'])
        if args.check:
            if args.output.read_bytes().replace(b'\r\n', b'\n') != outputs[0]:
                raise ValueError('Fresh original methods disagree with the checked-in return oracle')
        else:
            if args.output.exists():
                raise ValueError('Never overwrite an existing oracle; use --check or an explicit fresh --output')
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_bytes(outputs[0])
        receipt = {'schema': 1, 'success': True, 'engineVersion': ENGINE_VERSION, 'checkOnly': args.check,
                   'freshProcessRuns': 2, 'sourceUnchanged': True, 'personalSavesUsed': False,
                   'cases': len(data['cases']), 'sha256': hashlib.sha256(outputs[0]).hexdigest()}
        (args.evidence_dir / 'receipt.json').write_bytes(canonical_bytes(receipt))
        print('MIGRATION RETURN ORACLE OK: 24 saves written by Unity loaded by Godot; 2 fresh processes')
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('MIGRATION RETURN ORACLE FAILED:', error, file=sys.stderr)
        return 1
    finally:
        if user_dir is not None and user_dir.name == token and user_dir.exists():
            shutil.rmtree(user_dir)
        print('Isolated oracle project retained:', task)


if __name__ == '__main__':
    raise SystemExit(main())
