"""The foundation package must retain its frozen sources and reject unsafe edits.

Small private fixture repositories exercise failure cases without touching Godot,
Unity's live asset folder, or any player's saves.
"""
from __future__ import annotations

import gzip
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import build_migration_foundation as transfer


class FoundationPackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="BlueMap-Foundation-Tests-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.world = {"units": {"tilePixels": 32, "yAxis": "down"},
                      "baselineCommit": "fixture", "baselineTree": "fixture",
                      "shared": [], "snapshots": [], "scenarios": [{} for _ in range(59)]}
        self.portable = {"documents": []}
        for index in range(218):
            data = transfer.canonical({"sequence": index})
            if index < 163:
                relative = f"snapshots/{index}.json"
                full = "migration/world/" + relative
                rows = self.world["shared"] if index == 0 else self.world["snapshots"]
            else:
                relative = f"catalogs/{index}.json"
                full = "migration/portable/" + relative
                rows = self.portable["documents"]
            path = self.root / full
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            rows.append({"path": relative, "bytes": len(data), "sha256": transfer.sha(data)})
        self.oracle = b'{\r\n  "schema": "fixture", "unknown": {"future": [1, null, "\\u2603"]}\r\n}\r\n'
        oracle_path = self.root / "migration/phase-07/state-oracle.json"
        oracle_path.parent.mkdir(parents=True)
        oracle_path.write_bytes(self.oracle)
        identities = self.root / "migration/phase-05/runtime-identities.json"
        identities.parent.mkdir(parents=True)
        identities.write_bytes(b'{"future_identity": "retained"}\n')
        self.refresh_manifests()

    def refresh_manifests(self):
        for relative, value in (("migration/world/index.json", self.world),
                                ("migration/portable/manifest.json", self.portable)):
            (self.root / relative).write_bytes(transfer.canonical(value))
        self.anchors = {name: transfer.sha((self.root / name).read_bytes()) for name in transfer.ANCHORS}

    def build(self):
        with patch.dict(transfer.ANCHORS, self.anchors, clear=True):
            return transfer.build_documents(self.root)

    def test_every_compressed_document_roundtrips_and_hashes_bind_both_forms(self):
        docs, manifest = self.build()
        self.assertEqual(manifest["sourceFiles"], 221)
        self.assertEqual(len(manifest["documents"]), 221)
        for row in manifest["documents"]:
            target = transfer.RESOURCE + "/" + row["sourcePath"].removeprefix("migration/").removesuffix(".json") + ".bytes"
            packed = docs[target]
            unpacked = gzip.decompress(packed)
            self.assertEqual(unpacked, (self.root / row["sourcePath"]).read_bytes())
            self.assertEqual((len(unpacked), transfer.sha(unpacked)), (row["bytes"], row["sha256"]))
            self.assertEqual((len(packed), transfer.sha(packed)), (row["gzipBytes"], row["gzipSha256"]))
            self.assertEqual(packed[4:8], bytes(4))
            self.assertEqual(packed[9], 255)
        transfer.apply(self.root, docs, write=True)
        transfer.apply(self.root, docs)

    def test_original_oracle_bytes_and_unknown_future_fields_survive_without_reserialization(self):
        docs, manifest = self.build()
        self.assertEqual(docs[transfer.RESOURCE + "/state-oracle.json"], self.oracle)
        self.assertEqual(manifest["stateOracle"]["sha256"], transfer.sha(self.oracle))
        transfer.apply(self.root, docs, write=True)
        target = self.root / transfer.RESOURCE / "state-oracle.json"
        target.write_bytes(self.oracle.replace(b"\r\n", b"\n"))
        with self.assertRaisesRegex(transfer.FoundationError, "Stale/corrupt"):
            transfer.apply(self.root, docs)

    def test_changed_frozen_anchor_rejected(self):
        (self.root / "migration/world/index.json").write_bytes(b"{}\n")
        with self.assertRaisesRegex(transfer.FoundationError, "anchor changed"):
            self.build()

    def test_source_mutation_and_truncation_rejected(self):
        path = self.root / "migration/world/snapshots/0.json"
        original = path.read_bytes()
        for raw in (original[:-1], original.replace(b"0", b"9")):
            path.write_bytes(raw)
            with self.subTest(raw=raw), self.assertRaisesRegex(transfer.FoundationError, "Corrupt frozen"):
                self.build()

    def test_missing_source_rejected(self):
        (self.root / "migration/portable/catalogs/217.json").unlink()
        with self.assertRaisesRegex(transfer.FoundationError, "Missing/oversized"):
            self.build()

    def test_traversal_absolute_noncanonical_and_platform_paths_rejected(self):
        for name in ("../escape.json", "/escape.json", "C:/escape.json", "a\\b.json", "a/./b.json", "a//b.json"):
            with self.subTest(name=name), self.assertRaises(transfer.FoundationError):
                transfer.safe_name(name)

    def test_manifest_source_paths_cannot_escape_or_alias_another_file(self):
        for name in ("../../outside.json", "./snapshots/0.json"):
            self.world["shared"][0]["path"] = name
            self.refresh_manifests()
            with self.subTest(name=name), self.assertRaisesRegex(transfer.FoundationError, "Unsafe"):
                self.build()

    def test_duplicate_source_entry_rejected_instead_of_silently_overwritten(self):
        self.world["snapshots"][1] = dict(self.world["snapshots"][0])
        self.refresh_manifests()
        with self.assertRaisesRegex(transfer.FoundationError, "Duplicate foundation source"):
            self.build()

    def test_bad_descriptor_lengths_hashes_and_shapes_rejected(self):
        original = self.world["shared"][0]
        for row in ({"path": original["path"], "bytes": True, "sha256": original["sha256"]},
                    {"path": original["path"], "bytes": 10, "sha256": "not-a-sha256"},
                    {"bytes": 3}, "not a descriptor"):
            self.world["shared"][0] = row
            self.refresh_manifests()
            with self.subTest(row=row), self.assertRaises(transfer.FoundationError):
                self.build()

    def test_malformed_duplicate_or_nonfinite_json_is_rejected(self):
        for raw in (b'{"x":1,"x":2}', b'{"x": NaN}', b'{"x":Infinity}', b'{"x":', b'"\xff"'):
            with self.subTest(raw=raw), self.assertRaises(transfer.FoundationError):
                transfer.json_document(raw, "private fixture")
        oracle = self.root / "migration/phase-07/state-oracle.json"
        for raw in (b'[]', b'{"x":1,"x":2}'):
            oracle.write_bytes(raw)
            with self.subTest(oracle=raw), self.assertRaises(transfer.FoundationError):
                self.build()

    def test_meta_guid_is_stable_unique_and_check_detects_damage(self):
        docs, _ = self.build()
        metas = {name: data for name, data in docs.items() if name.endswith(".meta")}
        guids = [data.split(b"guid: ")[1].split(b"\n")[0] for data in metas.values()]
        self.assertEqual(len(guids), len(set(guids)))
        name = next(name for name in metas if name.endswith(".bytes.meta"))
        unity_path = name.removeprefix("unity/").removesuffix(".meta")
        self.assertEqual(transfer.guid(unity_path), hashlib.sha256(("bluemap-foundation:" + unity_path).encode()).hexdigest()[:32])
        transfer.apply(self.root, docs, write=True)
        (self.root / name).write_bytes(b"wrong importer\n")
        with self.assertRaisesRegex(transfer.FoundationError, "Stale/corrupt"):
            transfer.apply(self.root, docs)

    def test_unknown_extra_file_or_empty_directory_rejected_before_any_write(self):
        docs, _ = self.build()
        transfer.apply(self.root, docs, write=True)
        package = self.root / transfer.RESOURCE
        sentinel = package / "manifest.json"
        before = sentinel.read_bytes()
        extra = package / "unowned.json"
        extra.write_bytes(b"{}")
        with self.assertRaisesRegex(transfer.FoundationError, "Unexpected extra files"):
            transfer.apply(self.root, docs, write=True)
        self.assertEqual(sentinel.read_bytes(), before)
        extra.unlink()
        (package / "unknown-empty").mkdir()
        with self.assertRaisesRegex(transfer.FoundationError, "Unexpected extra directory"):
            transfer.apply(self.root, docs, write=True)

    def test_extra_oracle_adjacent_file_is_not_implicitly_allowed(self):
        docs, _ = self.build()
        transfer.apply(self.root, docs, write=True)
        (self.root / transfer.RESOURCE / "state-oracle-other.json").write_bytes(self.oracle)
        with self.assertRaisesRegex(transfer.FoundationError, "Unexpected extra files"):
            transfer.apply(self.root, docs)

    def test_missing_or_corrupt_output_is_detected_without_regeneration(self):
        docs, _ = self.build()
        transfer.apply(self.root, docs, write=True)
        target = self.root / next(name for name in docs if name.endswith(".bytes"))
        target.write_bytes(b"invalid gzip")
        with self.assertRaisesRegex(transfer.FoundationError, "Stale/corrupt"):
            transfer.apply(self.root, docs)
        target.unlink()
        with self.assertRaisesRegex(transfer.FoundationError, "Missing foundation output"):
            transfer.apply(self.root, docs)
        self.assertFalse(target.exists())

    def test_write_destinations_cannot_prefix_escape_or_traverse(self):
        for name in (transfer.RESOURCE + "-outside/data.bytes", transfer.RESOURCE + "/../escape.bytes"):
            with self.subTest(name=name), self.assertRaisesRegex(transfer.FoundationError, "Unexpected export target"):
                transfer.apply(self.root, {name: b"blocked"}, write=True)
        self.assertFalse((self.root / "unity").exists())

    def test_git_crlf_checkout_uses_frozen_lf_source_identity(self):
        path = self.root / "migration/world/snapshots/0.json"
        original = path.read_bytes()
        path.write_bytes(original.replace(b"\n", b"\r\n"))
        docs, _ = self.build()
        self.assertEqual(gzip.decompress(docs[transfer.RESOURCE + "/world/snapshots/0.bytes"]), original)


if __name__ == "__main__":
    unittest.main()
