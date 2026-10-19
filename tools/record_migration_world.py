#!/usr/bin/env python3
"""Export actual Godot-loaded world data twice, in a verified disposable project.

Game and player-save sources stay untouched. The checked-in export can be
verified offline with migration_world_data.py; --check also replays the real
engine pipeline and verifies both fresh process runs against the same reference.
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

from migration_data_codec import canonical_bytes, json_read

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r'SCRIPT ERROR|Parse Error|\bFAIL |^ERROR: (?!\d+ resources still in use at exit \(run with --verbose for details\)\.)', re.MULTILINE)
ENGINE_VERSION = '4.4.1.stable.official.49a5bc7b6'


def no_symlink(path):
    if any(p.is_symlink() for p in [path, *path.parents]):
        raise ValueError('World export paths may not follow symlinks')


def fingerprint(root):
    paths = [root / 'project.godot', *root.glob('scripts/**/*.gd'), *root.glob('scenes/**/*.tscn')]
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}


def normalize_export(directory):
    """Canonical JSON bytes, retaining typed entry arrays and source order."""
    index = json_read(directory / 'index.json')
    for row in [*index['shared'], *index['snapshots']]:
        name = row['path']
        if not re.fullmatch(r'tile-set\.json|snapshots/[a-z0-9_]+/[a-z0-9_]+\.json', name):
            raise ValueError('Unsafe engine output document path')
        path = directory / name
        data = canonical_bytes(json_read(path))
        path.write_bytes(data)
        row.update(sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))
    (directory / 'index.json').write_bytes(canonical_bytes(index))
    return {p.relative_to(directory).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(directory.rglob('*.json'))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('godot')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'migration/world')
    parser.add_argument('--evidence-dir', type=Path)
    parser.add_argument('--scenario', help='Private diagnostic subset; cannot write/check the complete reference')
    parser.add_argument('--keep', action='store_true')
    args = parser.parse_args()
    engine = shutil.which(args.godot)
    if not engine:
        parser.error('Godot executable not found')
    if args.scenario and (args.check or args.output_dir == ROOT / 'migration/world'):
        parser.error('A diagnostic subset requires its own explicit output directory and cannot be checked as complete')
    task = Path(tempfile.mkdtemp(prefix='bluemap-runtime-world-'))
    project = task / 'project'
    evidence = args.evidence_dir or task / 'evidence'
    no_symlink(evidence)
    no_symlink(args.output_dir)
    if evidence.resolve().is_relative_to(ROOT.resolve()):
        parser.error('Evidence must be outside the source project')
    if evidence.exists() and any(evidence.iterdir()):
        parser.error('Evidence directory must be new or empty')
    evidence.mkdir(parents=True, exist_ok=True)
    token = 'Bluemap-Codex-Tests-' + uuid.uuid4().hex
    user_dir = None
    before = fingerprint(ROOT)
    receipt = {'schema': 1, 'kind': 'phase5_actual_loaded_world', 'checkOnly': args.check,
               'scenarioSubset': args.scenario, 'project': str(project), 'token': token,
               'realPlayerSavesAccessed': False, 'offlineGrowthAdded': False}
    succeeded = False
    print('Runtime world evidence:', evidence, flush=True)
    try:
        version = subprocess.run([engine, '--version'], cwd=task, capture_output=True,
                                 text=True, encoding='utf8', errors='replace', timeout=30)
        if version.returncode or version.stdout.strip() != ENGINE_VERSION:
            raise ValueError('World reference export requires exact Godot ' + ENGINE_VERSION)
        receipt['engineVersion'] = version.stdout.strip()
        shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(
            '.git', '.godot', '.testdata', 'build', 'dist', '__pycache__'))
        settings = project / 'project.godot'
        text = settings.read_text(encoding='utf8')
        text = re.sub(r'^config/name=.*$', 'config/name=' + json.dumps(token), text, flags=re.MULTILINE)
        text = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n?', '', text, flags=re.MULTILINE)
        text = text.replace('[application]', '[application]\nconfig/use_custom_user_dir=false', 1)
        settings.write_text(text, encoding='utf8')
        probe = ('extends SceneTree\nfunc _initialize():\n'
                 '\tvar path:=OS.get_user_data_dir()\n\tprint("ISOLATED_USER_DIR="+path)\n'
                 '\tquit(0 if path.replace(char(92),"/").get_file() == ' + json.dumps(token) + ' else 1)\n')
        (project / 'world_isolation_probe.gd').write_text(probe, encoding='utf8')
        env = dict(os.environ, BLUEMAP_LANG='nl')

        def run(label, arguments, marker=None, timeout=1200):
            result = subprocess.run([str(Path(engine).resolve()), '--headless', '--path', str(project), *arguments],
                                    cwd=project, capture_output=True, text=True, encoding='utf8', errors='replace',
                                    timeout=timeout, env=env)
            log = result.stdout + result.stderr
            (evidence / (label + '.log')).write_text(log, encoding='utf8')
            if result.returncode or ERROR.search(log) or (marker and marker not in log):
                raise RuntimeError(label + ' failed:\n' + log[-12000:])
            return log

        run('import', ['--editor', '--import'])
        log = run('isolation', ['-s', 'res://world_isolation_probe.gd'])
        match = re.search(r'^ISOLATED_USER_DIR=(.+)$', log, re.MULTILINE)
        if not match or Path(match[1].strip()).name != token:
            raise RuntimeError('Exact UUID save directory could not be verified')
        user_dir = Path(match[1].strip())
        receipt['verifiedUserDirectory'] = str(user_dir)
        print('Verified separate save directory:', user_dir, flush=True)
        run('scenario-fixtures', ['-s', 'res://tests/migration_world_scenarios_test.gd'], 'MIGRATION WORLD SCENARIOS OK')
        runs = []
        for number in (1, 2):
            directory = evidence / ('export-' + str(number))
            if directory.exists():
                raise RuntimeError('Never overwrite a prior engine run')
            arguments = ['-s', 'res://tools/migration_world_export.gd', '--', '--output-dir', str(directory)]
            if args.scenario:
                arguments += ['--scenario', args.scenario]
            run('export-' + str(number), arguments, 'MIGRATION WORLD EXPORT OK')
            hashes = normalize_export(directory)
            runs.append(hashes)
            print(f'World export {number}: {len(hashes)} documents', flush=True)
        if runs[0] != runs[1]:
            changed = [name for name in sorted(set(runs[0]) | set(runs[1])) if runs[0].get(name) != runs[1].get(name)]
            receipt['nondeterministicDocuments'] = changed
            raise RuntimeError('Repeated real engine exports differ: ' + ', '.join(changed[:12]))
        if fingerprint(ROOT) != before:
            raise RuntimeError('Original game source changed during world export')
        if not args.scenario:
            from migration_world_data import validate_world_export
            from check_world_witnesses import check_world_witnesses
            from migration_runtime_ids import build_runtime_identities
            summary = validate_world_export(evidence / 'export-1', ROOT)
            witnesses = check_world_witnesses(evidence / 'export-1')
            identities = build_runtime_identities(evidence / 'export-1', ROOT)
            (evidence / 'world-witnesses.json').write_bytes(canonical_bytes(witnesses))
            (evidence / 'world-identities.json').write_bytes(canonical_bytes(identities))
            receipt.update(semanticWitnesses=witnesses['checkCount'],
                           runtimeIdentities=identities['coverage'])
        else:
            summary = {'diagnosticSubsetOnly': True, 'scenario': args.scenario}
        if args.check:
            existing = {}
            for path in sorted(args.output_dir.rglob('*')):
                no_symlink(path)
                if path.is_file():
                    existing[path.relative_to(args.output_dir).as_posix()] = hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
            if existing != runs[0]:
                changed = [name for name in sorted(set(existing) | set(runs[0]))
                           if existing.get(name) != runs[0].get(name)]
                receipt['referenceDifferences'] = changed
                raise RuntimeError('Actual loaded-world export differs from the committed reference: '
                                   + ', '.join(changed[:12]))
        else:
            if args.output_dir.exists():
                raise RuntimeError('Output already exists; use --check or a new directory')
            shutil.copytree(evidence / 'export-1', args.output_dir)
        receipt.update(success=True, sourceUnchanged=True, isolatedUserDirectoryVerified=True,
                       repeatableEngineRuns=2, documents=runs[0], summary=summary)
        succeeded = True
        print('MIGRATION WORLD CHECK OK' if args.check else 'MIGRATION WORLD RECORDED OK', flush=True)
        return 0
    except (ValueError, OSError, subprocess.SubprocessError, RuntimeError) as error:
        receipt.update(success=False, error=str(error))
        print(str(error), file=sys.stderr, flush=True)
        return 1
    finally:
        receipt['sourceUnchanged'] = fingerprint(ROOT) == before
        (evidence / 'receipt.json').write_bytes(canonical_bytes(receipt))
        # This exact new UUID directory is the only save directory eligible for
        # cleanup. Keep project/logs on failure; never enumerate production saves.
        if user_dir is not None and user_dir.name == token and user_dir.exists():
            shutil.rmtree(user_dir)
        if succeeded and not args.keep and not project.is_symlink() and project.parent == task:
            shutil.rmtree(project)
        print('Complete world evidence retained:', evidence, flush=True)


if __name__ == '__main__':
    sys.exit(main())
