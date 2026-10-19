#!/usr/bin/env python3
"""Build/check phase-4 portable reference data; no engine, saves or code execution.

The exported catalogs/tables are data. GDScript paths and rule handlers are
provenance, never executable instructions. Loaded world states follow in phase 5.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import re
import sys

from migration_data_codec import CodecError, canonical_bytes, decode, encode, json_read
from migration_identity import build_identity_registry, validate_identity_registry
from migration_references import build_references
from migration_rule_contracts import build_rule_contracts, validate_rule_contracts

ROOT = Path(__file__).resolve().parent.parent
BASELINE = 'a8a988be27835dec979d2523a3a85a34385eac54'
TREE = '73ba02ea4db0a1c920360b6570f5209ccb970143'
SCHEMA = 'bluemap.portable.bundle.v1'
DOC_PATH = re.compile(r'(header|save-contract|identity|rules|references)\.json|catalogs/[a-z0-9_]+\.json|declarations/[0-9]{3}\.json')
TOOLS = ('build_migration_data.py', 'migration_data_codec.py', 'migration_identity.py',
         'migration_references.py', 'migration_rule_contracts.py')
# Canonical phase-1 documents, independently checked against two real Godot
# exports. A repeated metadata fingerprint is not sufficient proof of content.
REFERENCE_SHA256 = {
    'content-inventory.json': '23318c3696211a67d96436c20914c69dfb93a16004422b6cf6da9e68b91a2cf2',
    'maps-inventory.json': '3b6e3818d720f501dbcce09252919f7c76f2814a651a5fba796a322767cfb207',
    'save-contract.json': '96a2862d2dbcf168d76bb38674f2d7899b030eb385573d4c7d0d589f8f01423e',
    'source-manifest.json': 'd2abc50852378cac1b69948ab16ca1451f7577f7e991041967220d436e365c30',
}


class DataError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise DataError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def no_symlink(path):
    require(not any(p.is_symlink() for p in [path, *path.parents]), 'Refuse symlinked output or input path')


def inputs(root):
    reference = root / 'migration/reference'
    content = json_read(reference / 'content-inventory.json')
    maps = json_read(reference / 'maps-inventory.json')
    save = json_read(reference / 'save-contract.json')
    source = json_read(reference / 'source-manifest.json')
    for name, value in [('content-inventory.json', content), ('maps-inventory.json', maps),
                        ('save-contract.json', save), ('source-manifest.json', source)]:
        require(sha(canonical_bytes(value)) == REFERENCE_SHA256[name], 'Frozen reference changed: ' + name)
    require(source['commit'] == BASELINE and source['tree'] == TREE, 'Unexpected reference baseline')
    require(content['schema'] == 'bluemap.migration.content-inventory.v1' and not content['failures'],
            'Incomplete content reference')
    require(maps['not_phase5_runtime_export'] is True, 'Wrong world-export scope')
    require(content['source_fingerprint'] == maps['source_fingerprint'], 'Reference provenance mismatch')
    for entry in content['source_files']:
        name = entry['path']
        require(name.startswith('res://scripts/') and '..' not in name and '\\' not in name,
                'Unsafe reference source path')
        path = root / name[6:]
        require(path.is_file() and sha(path.read_bytes().replace(b'\r\n', b'\n')) == entry['sha256'],
                'Frozen handler source changed: ' + name)
    return content, maps, save


def build_documents(root):
    """Return the complete deterministic file set, including its manifest."""
    root = Path(root)
    content, maps, save = inputs(root)
    identity = build_identity_registry(content, maps, save)
    validate_identity_registry(identity, content, maps, save)
    validate_identity_registry(json_read(root / 'migration/contracts/identity.json'), content, maps, save)
    rules = build_rule_contracts(root, content, maps)
    validate_rule_contracts(rules)
    require(rules == json_read(root / 'migration/contracts/rules.json'),
            'Rule contract differs from the current frozen handler sources')
    references = build_references(content, maps)
    docs = {}

    def typed(path, value):
        node = encode(value)
        require(encode(decode(node)) == node, 'Lossy round trip: ' + path)
        docs[path] = canonical_bytes(node)

    typed('header.json', {k: v for k, v in content.items() if k not in {'catalogs', 'declarations'}})
    for name, value in sorted(content['catalogs'].items()):
        typed('catalogs/' + name + '.json', value)
    for n in range(0, len(content['declarations']), 25):
        typed(f'declarations/{n // 25:03}.json', content['declarations'][n:n + 25])
    typed('save-contract.json', save)
    for name, value in [('identity', identity), ('rules', rules), ('references', references)]:
        docs[name + '.json'] = canonical_bytes(value)
    manifest = {
        'schema': SCHEMA, 'phase': 4, 'baselineCommit': BASELINE, 'baselineTree': TREE,
        'scope': 'effective_catalogs_declared_tables_and_identity_contracts',
        'notRuntimeWorldExport': True, 'notSaveConverter': True,
        'codec': 'bluemap.portable.variant.v1',
        'contentRootOrder': list(content),
        'dictionaryOrder': 'order_present_in_reference_inventory_not_recovered_Godot_insertion_order',
        'originalTypeLimits': ['Godot StringName and String were merged by the phase-1 inventory',
                              'plain JSON dictionary keys were sorted in the phase-1 inventory',
                              'phase-1 numbers retain JSON number type, not omitted GDScript static annotations'],
        'inputs': {name: sha(canonical_bytes(value)) for name, value in
                   [('content-inventory', content), ('maps-inventory', maps), ('save-contract', save)]},
        'toolSources': {name: sha((root / 'tools' / name).read_bytes().replace(b'\r\n', b'\n'))
                        for name in TOOLS},
        'counts': {'catalogs': len(content['catalogs']),
                   'catalogEntries': sum(v['count'] for v in content['catalogs'].values()),
                   'declaredTables': len(content['declarations']),
                   'maps': maps['map_count'], 'registrySlots': maps['registry_object_slots'],
                   'postRegistryResources': maps['legacy_resource_count'],
                   'saveFields': save['savegame']['field_count'], 'referenceLinks': references['count']},
        'documents': [{'path': name, 'bytes': len(data), 'sha256': sha(data),
                       'encoding': 'typed_variant' if name not in {'identity.json', 'rules.json', 'references.json'} else 'contract_json'}
                      for name, data in sorted(docs.items())],
    }
    docs['manifest.json'] = canonical_bytes(manifest)
    return docs


def load_bundle(directory):
    """Verify file integrity then reconstruct the complete phase-1 content input.

    Integrity is relative to manifest.json. verify_bundle additionally anchors it
    to the trusted repository inputs, generator and frozen source handlers.
    """
    directory = Path(directory)
    require(directory.is_dir() and not directory.is_symlink(), 'Bundle must be a real directory')
    manifest = json_read(directory / 'manifest.json')
    require(manifest.get('schema') == SCHEMA and type(manifest.get('phase')) is int
            and manifest['phase'] == 4, 'Unsupported bundle schema/phase')
    require(manifest.get('codec') == 'bluemap.portable.variant.v1', 'Unsupported Variant codec')
    require(manifest.get('baselineCommit') == BASELINE and manifest.get('baselineTree') == TREE,
            'Unexpected baseline identity')
    require(manifest.get('notRuntimeWorldExport') is True and manifest.get('notSaveConverter') is True,
            'Missing export scope guard')
    rows = manifest.get('documents')
    require(isinstance(rows, list) and 5 <= len(rows) <= 1000, 'Invalid document list')
    seen, decoded, total = set(), {}, 0
    for row in rows:
        require(isinstance(row, dict) and set(row) == {'path', 'bytes', 'sha256', 'encoding'},
                'Invalid document descriptor')
        name = row['path']
        require(isinstance(name, str) and DOC_PATH.fullmatch(name), 'Unsafe or unsupported document path')
        require(name.casefold() not in seen, 'Duplicate document path')
        seen.add(name.casefold())
        require(type(row['bytes']) is int and 0 < row['bytes'] <= 16 * 1024 * 1024,
                'Invalid document byte count')
        require(isinstance(row['sha256'], str) and re.fullmatch('[0-9a-f]{64}', row['sha256']),
                'Invalid document checksum')
        total += row['bytes']
        require(total <= 80 * 1024 * 1024, 'Bundle too large')
        path = directory / name
        no_symlink(path)
        require(path.is_file(), 'Missing bundle document')
        # Git can check out JSON as CRLF on Windows. The wire representation is LF.
        require(path.stat().st_size <= row['bytes'] * 2, 'Oversized document')
        data = path.read_bytes().replace(b'\r\n', b'\n')
        require(len(data) == row['bytes'] and sha(data) == row['sha256'], 'Corrupt document: ' + name)
        value = json_read(path)
        require(canonical_bytes(value) == data, 'Noncanonical document: ' + name)
        contract = name in {'identity.json', 'rules.json', 'references.json'}
        require(row['encoding'] == ('contract_json' if contract else 'typed_variant'),
                'Wrong document encoding')
        decoded[name] = value if contract else decode(value)
    actual = set()
    for path in directory.rglob('*'):
        require(not path.is_symlink(), 'Symlink inside bundle')
        if path.is_file():
            actual.add(path.relative_to(directory).as_posix())
    require(actual == seen | {'manifest.json'}, 'Missing or extra bundle files')
    needed = {'header.json', 'save-contract.json', 'identity.json', 'rules.json', 'references.json'}
    require(needed <= decoded.keys(), 'Missing required document')
    content = decoded['header.json']
    require(isinstance(content, dict) and not {'catalogs', 'declarations'} & content.keys(), 'Invalid content header')
    content['catalogs'] = {name[9:-5]: value for name, value in sorted(decoded.items()) if name.startswith('catalogs/')}
    batches = sorted(name for name in decoded if name.startswith('declarations/'))
    require(batches == [f'declarations/{n:03}.json' for n in range(len(batches))], 'Missing declaration batch')
    content['declarations'] = []
    for name in batches:
        require(isinstance(decoded[name], list), 'Invalid declaration batch')
        content['declarations'].extend(decoded[name])
    order = manifest.get('contentRootOrder')
    require(isinstance(order, list) and all(isinstance(k, str) for k in order)
            and len(order) == len(set(order)) and set(order) == set(content), 'Invalid content root order')
    content = {key: content[key] for key in order}
    return {'manifest': manifest, 'content': content, 'saveContract': decoded['save-contract.json'],
            'identity': decoded['identity.json'], 'rules': decoded['rules.json'], 'references': decoded['references.json']}


def verify_bundle(root, directory):
    expected = build_documents(Path(root))
    loaded = load_bundle(directory)
    for name, data in expected.items():
        path = Path(directory) / name
        require(path.is_file() and path.read_bytes().replace(b'\r\n', b'\n') == data,
                'Bundle differs from trusted source: ' + name)
    require({p.relative_to(directory).as_posix() for p in Path(directory).rglob('*') if p.is_file()}
            == set(expected), 'Bundle document set differs from trusted source')
    content, maps, save = inputs(Path(root))
    require(encode(loaded['content']) == encode(content), 'Content round trip changed values or order')
    require(encode(loaded['saveContract']) == encode(save), 'Save contract round trip changed values or order')
    validate_identity_registry(loaded['identity'], content, maps, save)
    validate_rule_contracts(loaded['rules'])
    return {'schema': 'bluemap.portable.verification.v1', 'passed': True,
            'scope': loaded['manifest']['scope'], 'baselineCommit': BASELINE,
            'manifestSha256': sha(expected['manifest.json']), 'files': len(expected),
            'bytes': sum(map(len, expected.values())), 'counts': loaded['manifest']['counts'],
            'checks': ['deterministic_source_rebuild', 'complete_typed_content_roundtrip',
                       'complete_save_contract_roundtrip', 'all_document_checksums',
                       'stable_id_registry', 'rule_handler_source_contracts', 'explicit_reference_links'],
            'worldRuntimeExported': False, 'gameRulesExecuted': False, 'playerSavesAccessed': False}


def write_bundle(root, directory):
    docs = build_documents(Path(root))
    directory = Path(directory)
    # Validate every output first: a parent link must never redirect even one
    # catalog write before the later read-side verifier can report the problem.
    for name in docs:
        no_symlink(directory / name)
    for name, data in docs.items():
        path = directory / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--write', action='store_true')
    mode.add_argument('--check', action='store_true')
    parser.add_argument('--directory', type=Path, default=ROOT / 'migration/portable')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    try:
        if args.write:
            write_bundle(ROOT, args.directory)
        report = verify_bundle(ROOT, args.directory)
        if args.report:
            no_symlink(args.report)
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_bytes(canonical_bytes(report))
        print(f'Portable data OK: {report["files"]} files, {report["counts"]}')
        return 0
    except (ValueError, OSError, KeyError, TypeError) as error:
        print('Portable data FAILED: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
