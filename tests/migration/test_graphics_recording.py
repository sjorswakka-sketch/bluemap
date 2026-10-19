"""Recording corruption/preflight fixtures; never start a GPU or touch saves."""
import base64
from contextlib import redirect_stderr
from copy import deepcopy
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import record_migration_graphics as recording

PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==")


def fixture(path):
    (path / "sample.png").write_bytes(PNG)
    index = {"schemaVersion": 1, "tilePixels": 32, "textures": [
        {"id": "generated:sample", "file": "sample.png", "width": 1, "height": 1}],
        "sprites": [{"id": "sample:frame", "textureId": "generated:sample", "x": 0, "y": 0, "width": 1, "height": 1}],
        "animations": [{"id": "sample:animation", "frames": ["sample:frame"], "fps": 1.0}]}
    (path / "index.json").write_text(json.dumps(index), encoding="utf-8")
    return index


class GraphicsRecordingTests(unittest.TestCase):
    def test_exact_png_bytes_and_exporter_provenance_are_retained(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            fixture(path)
            exporters = {"res://tools/migration_graphics_export.gd": "a" * 64,
                         "res://tools/migration_presentation_canvas.gd": "b" * 64}
            hashes = recording.normalize_graphics(path, exporters)
            index = json.loads((path / "index.json").read_text())
            self.assertEqual(index["engineVersion"], recording.ENGINE_VERSION)
            self.assertEqual(index["exporterSources"], exporters)
            self.assertEqual(index["textures"][0]["sha256"], hashlib.sha256(PNG).hexdigest())
            self.assertEqual(index["textures"][0]["bytes"], len(PNG))
            self.assertEqual(hashes["sample.png"], hashlib.sha256(PNG).hexdigest())
            self.assertEqual((path / "sample.png").read_bytes(), PNG)
            self.assertEqual(recording.normalize_graphics(path, exporters), hashes)

    def test_changed_declared_dimensions_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            index = fixture(path)
            index["textures"][0]["width"] = 2
            (path / "index.json").write_text(json.dumps(index))
            with self.assertRaisesRegex(ValueError, "dimensions differ"):
                recording.normalize_graphics(path)

    def test_duplicate_or_escaping_texture_paths_are_rejected(self):
        for name in ["duplicate", "../outside.png"]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as folder:
                path = Path(folder)
                index = fixture(path)
                if name == "duplicate":
                    index["textures"].append(deepcopy(index["textures"][0]))
                else:
                    index["textures"][0]["file"] = name
                (path / "index.json").write_text(json.dumps(index))
                with self.assertRaisesRegex(ValueError, "Unsafe or duplicate"):
                    recording.normalize_graphics(path)

    def test_unindexed_extra_document_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            fixture(path)
            (path / "extra.png").write_bytes(PNG)
            with self.assertRaisesRegex(ValueError, "Unexpected or missing"):
                recording.normalize_graphics(path)

    def test_non_png_texture_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            fixture(path)
            (path / "sample.png").write_bytes(b"invalid texture")
            with self.assertRaisesRegex(ValueError, "not a PNG"):
                recording.normalize_graphics(path)

    def test_missing_declared_png_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            fixture(path)
            (path / "sample.png").unlink()
            with self.assertRaises(OSError):
                recording.normalize_graphics(path)

    def test_stale_declared_digest_is_not_silently_replaced(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            index = fixture(path)
            index["textures"][0]["sha256"] = "0" * 64
            (path / "index.json").write_text(json.dumps(index))
            with self.assertRaisesRegex(ValueError, "digest/byte count is stale"):
                recording.normalize_graphics(path)

    def test_empty_renderer_export_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            (path / "index.json").write_text(json.dumps({"schemaVersion": 1, "tilePixels": 32,
                                                        "textures": [], "sprites": [], "animations": []}))
            with self.assertRaisesRegex(ValueError, "Empty renderer export"):
                recording.normalize_graphics(path)

    def test_duplicate_sprite_and_animation_ids_are_rejected(self):
        for key, message in [("sprites", "Duplicate sprite"), ("animations", "Duplicate animation")]:
            with self.subTest(key=key), tempfile.TemporaryDirectory() as folder:
                path = Path(folder)
                index = fixture(path)
                index[key].append(deepcopy(index[key][0]))
                (path / "index.json").write_text(json.dumps(index))
                with self.assertRaisesRegex(ValueError, message):
                    recording.normalize_graphics(path)

    def test_stale_engine_and_exporter_identities_are_rejected(self):
        for key, value in [("engineVersion", "different-engine"), ("exporterSources", {"wrong-script": "0" * 64})]:
            with self.subTest(key=key), tempfile.TemporaryDirectory() as folder:
                path = Path(folder)
                index = fixture(path)
                index[key] = value
                (path / "index.json").write_text(json.dumps(index))
                with self.assertRaisesRegex(ValueError, "stale"):
                    recording.normalize_graphics(path, {"current-script": "a" * 64})

    def test_existing_evidence_is_never_overwritten_even_on_preflight_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            evidence = path / "evidence"
            evidence.mkdir()
            sentinel = evidence / "verification.json"
            sentinel.write_bytes(b"existing proof")
            arguments = ["graphics", "unused-engine", "--evidence-dir", str(evidence), "--output-dir", str(path / "output")]
            with patch.object(sys, "argv", arguments), patch.object(recording, "source_fingerprint", return_value={}), \
                    redirect_stderr(io.StringIO()):
                self.assertEqual(recording.main(), 1)
            self.assertEqual(sentinel.read_bytes(), b"existing proof")
            self.assertFalse((path / "output").exists())


if __name__ == "__main__":
    unittest.main()
