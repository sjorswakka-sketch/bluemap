"""Portable data integrity, source anchoring and cross-reference regressions."""
from copy import deepcopy
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from build_migration_data import (DataError, build_documents, inputs, load_bundle,
                                 verify_bundle, write_bundle)
from migration_data_codec import canonical_bytes, json_read
from migration_references import ReferenceError, build_references


class PortableBundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.documents = build_documents(ROOT)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='bluemap-portable-test-')
        self.addCleanup(self.temp.cleanup)
        self.bundle = Path(self.temp.name) / 'bundle'
        for name, data in self.documents.items():
            path = self.bundle / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)

    def manifest(self, change):
        path = self.bundle / 'manifest.json'
        value = json_read(path)
        change(value)
        path.write_bytes(canonical_bytes(value))

    def test_full_source_anchored_roundtrip_and_repeatable_build(self):
        result = verify_bundle(ROOT, self.bundle)
        self.assertTrue(result['passed'])
        self.assertFalse(result['worldRuntimeExported'])
        self.assertFalse(result['playerSavesAccessed'])
        self.assertEqual(self.documents, build_documents(ROOT))
        self.assertEqual(result['counts']['registrySlots'], 905)

    def test_missing_extra_and_corrupt_documents_are_rejected(self):
        path = self.bundle / 'catalogs/items.json'
        original = path.read_bytes()
        path.unlink()
        with self.assertRaises(DataError):
            load_bundle(self.bundle)
        path.write_bytes(original + b' ')
        with self.assertRaises(DataError):
            load_bundle(self.bundle)
        path.write_bytes(original)
        (self.bundle / 'untracked.json').write_text('{}')
        with self.assertRaises(DataError):
            load_bundle(self.bundle)

    def test_path_traversal_and_duplicate_paths_rejected(self):
        self.manifest(lambda m: m['documents'][0].update(path='../outside.json'))
        with self.assertRaisesRegex(DataError, 'path'):
            load_bundle(self.bundle)
        (self.bundle / 'manifest.json').write_bytes(self.documents['manifest.json'])
        self.manifest(lambda m: m['documents'].append(deepcopy(m['documents'][0])))
        with self.assertRaisesRegex(DataError, 'Duplicate'):
            load_bundle(self.bundle)

    def test_forged_replacement_manifest_is_not_source_proof(self):
        self.manifest(lambda m: m['inputs'].update({'content-inventory': '0' * 64}))
        # Internal checksums alone cannot authenticate the manifest itself.
        load_bundle(self.bundle)
        with self.assertRaisesRegex(DataError, 'trusted source'):
            verify_bundle(ROOT, self.bundle)

    def test_wrong_schema_scope_and_encoding_rejected(self):
        for field, value in [('schema', 'bluemap.portable.bundle.v999'),
                             ('phase', True), ('notSaveConverter', False),
                             ('codec', 'execute-a-script')]:
            with self.subTest(field=field):
                (self.bundle / 'manifest.json').write_bytes(self.documents['manifest.json'])
                self.manifest(lambda m: m.update({field: value}))
                with self.assertRaises(DataError):
                    load_bundle(self.bundle)
        (self.bundle / 'manifest.json').write_bytes(self.documents['manifest.json'])
        self.manifest(lambda m: m['documents'][0].update(encoding='contract_json'))
        with self.assertRaisesRegex(DataError, 'encoding'):
            load_bundle(self.bundle)

    def test_windows_checkout_line_endings_preserve_wire_checksums(self):
        for name in self.documents:
            path = self.bundle / name
            path.write_bytes(path.read_bytes().replace(b'\n', b'\r\n'))
        loaded = load_bundle(self.bundle)
        self.assertEqual(loaded['content']['catalogs']['items']['count'], 226)

    def test_invalid_sizes_and_checksums_rejected(self):
        for field, value in [('bytes', True), ('bytes', 100_000_000), ('sha256', 'no')]:
            with self.subTest(field=field, value=value):
                (self.bundle / 'manifest.json').write_bytes(self.documents['manifest.json'])
                self.manifest(lambda m: m['documents'][0].update({field: value}))
                with self.assertRaises(DataError):
                    load_bundle(self.bundle)

    def test_reference_changes_cannot_be_trusted_by_repeating_metadata(self):
        root = Path(self.temp.name) / 'altered-source'
        destination = root / 'migration/reference'
        destination.mkdir(parents=True)
        for name in ('content-inventory', 'maps-inventory', 'save-contract', 'source-manifest'):
            shutil.copyfile(ROOT / f'migration/reference/{name}.json', destination / f'{name}.json')
        for name, mutate in [
            ('content-inventory', lambda v: v['catalogs']['items']['entries'][0]['value'].update(desc='changed')),
            ('maps-inventory', lambda v: v['maps'][0].update(name='changed')),
            ('save-contract', lambda v: v.update(status='changed'))]:
            path = destination / (name + '.json')
            original = path.read_bytes()
            value = json_read(path)
            mutate(value)
            path.write_bytes(canonical_bytes(value))
            with self.subTest(name=name), self.assertRaisesRegex(DataError, 'Frozen reference changed'):
                inputs(root)
            path.write_bytes(original)
        content = json_read(destination / 'content-inventory.json')
        first_handler = root / content['source_files'][0]['path'][6:]
        first_handler.parent.mkdir(parents=True, exist_ok=True)
        first_handler.write_text('# changed original handler, unchanged inventory metadata\n')
        with self.assertRaisesRegex(DataError, 'Frozen handler source changed'):
            inputs(root)

    def test_parent_symlink_rejected_before_any_output_is_written(self):
        output = Path(self.temp.name) / 'new-output'
        outside = Path(self.temp.name) / 'outside'
        output.mkdir()
        outside.mkdir()
        try:
            (output / 'catalogs').symlink_to(outside, target_is_directory=True)
        except OSError:
            self.skipTest('Host does not permit creating symlink fixtures; Linux CI covers this case')
        with self.assertRaisesRegex(DataError, 'symlink'):
            write_bundle(ROOT, output)
        self.assertEqual(list(outside.iterdir()), [])
        self.assertFalse((output / 'header.json').exists())


class ReferenceGraphTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.content, cls.maps, _ = inputs(ROOT)

    def test_all_explicit_references_resolve_and_currency_is_not_an_item(self):
        graph = build_references(self.content, self.maps)
        self.assertEqual(graph['count'], 2561)
        currency = [e for e in graph['edges'] if e['target']['namespace'] == ['currency_operation']]
        self.assertTrue(currency)
        self.assertEqual({e['target']['id'] for e in currency}, {'coins'})

    def test_every_link_source_resolves_to_its_target_with_explicit_key_semantics(self):
        catalogs = {name: {e['id']: e for e in data['entries']}
                    for name, data in self.content['catalogs'].items()}
        maps = {m['id']: m for m in self.maps['maps']}
        resources = {r['id']: r['value'] for m in self.maps['maps'] for r in m['post_registry_legacy_resources']}
        for edge in build_references(self.content, self.maps)['edges']:
            source = edge['source']
            namespace = source['namespace']
            if source['root'] in {'entry', 'entry_value'}:
                value = catalogs[namespace[1]][source['id']]
                if source['root'] == 'entry_value':
                    value = value['value']
            elif source['root'] == 'registry_object':
                value = maps[namespace[1]]['registry_snapshot']['objects'][int(source['id'])]
            else:
                value = resources[source['id']]
            parts = [p.replace('~1', '/').replace('~0', '~') for p in edge['path'].split('/')[1:]]
            for part in parts:
                value = value[int(part)] if isinstance(value, list) else value[part]
            selected = parts[-1] if edge['selection'] == 'dictionary_key' else value
            self.assertEqual(selected, edge['target']['id'], edge)

    def test_recipe_and_npc_references_reject_unknown_ids(self):
        for name, mutate in [('recipes', lambda v: v.update(output='missing_item')),
                             ('npcs', lambda v: v['rules'][0].update(talk='missing_talk'))]:
            content = deepcopy(self.content)
            mutate(content['catalogs'][name]['entries'][0]['value'])
            with self.assertRaises(ReferenceError):
                build_references(content, self.maps)

    def test_portals_require_destination_and_arrival_spawn(self):
        for field, value in [('to', 'missing_map'), ('spawn', 'missing_spawn')]:
            maps = deepcopy(self.maps)
            portal = next(o for m in maps['maps'] for o in m['registry_snapshot']['objects'] if o['type'] == 'portal')
            portal[field] = value
            with self.assertRaises(ReferenceError):
                build_references(self.content, maps)


if __name__ == '__main__':
    unittest.main()
