"""Font fidelity and corrupt-table tests; no font dependency install or engine."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from record_migration_font import SOURCE_SHA256, FALLBACK_SHA256, FALLBACK_CODEPOINTS, sfnt_tables, table_hashes


def fixture():
    rows = [(b"head", bytes(range(24))), (b"glyf", b"original-outline")]
    directory = bytearray(b"\x00\x01\x00\x00" + struct.pack(">HHHH", len(rows), 0, 0, 0))
    offset = 12 + 16 * len(rows)
    payload = bytearray()
    for tag, data in rows:
        directory.extend(struct.pack(">4sIII", tag, 0, offset, len(data)))
        payload.extend(data)
        offset += len(data)
    return bytes(directory + payload)


class FontContainerTests(unittest.TestCase):
    def test_only_head_container_checksum_adjustment_is_ignored(self):
        first = fixture()
        second = bytearray(first)
        second[44 + 8:44 + 12] = b"abcd"
        self.assertEqual(sfnt_tables(first), sfnt_tables(bytes(second)))
        second[44 + 12] ^= 1
        self.assertNotEqual(sfnt_tables(first), sfnt_tables(bytes(second)))

    def test_changed_outline_is_not_treated_as_equivalent(self):
        original = fixture()
        changed = bytearray(original)
        changed[-1] ^= 1
        self.assertNotEqual(table_hashes(sfnt_tables(original)), table_hashes(sfnt_tables(bytes(changed))))

    def test_wrong_font_flavor_and_truncated_table_directory_are_rejected(self):
        for value in [b"OTTO" + fixture()[4:], fixture()[:20], b""]:
            with self.subTest(size=len(value)), self.assertRaises(ValueError):
                sfnt_tables(value)

    def test_duplicate_tags_out_of_bounds_and_overlap_are_rejected(self):
        for offset, value in [(28, b"head"), (36, struct.pack(">I", 10**6)), (36, struct.pack(">I", 44))]:
            changed = bytearray(fixture())
            changed[offset:offset + 4] = value
            with self.subTest(offset=offset, value=value), self.assertRaises(ValueError):
                sfnt_tables(bytes(changed))


class ImportedFontTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = ROOT / "unity/Assets/BlueMapContent/Resources/BlueMapAssets/Fonts"
        cls.manifest = json.loads((cls.path / "font-manifest.json").read_text(encoding="utf-8"))

    def test_exact_godot_embedded_source_bytes_are_preserved(self):
        source = (self.path / "DefaultFont.woff2.bytes").read_bytes()
        self.assertEqual(len(source), 46392)
        self.assertEqual(source[:4], b"wOF2")
        self.assertEqual(hashlib.sha256(source).hexdigest(), SOURCE_SHA256)
        self.assertEqual(self.manifest["metrics"]["sha256"], SOURCE_SHA256)
        self.assertFalse(self.manifest["fontSubstituted"])
        self.assertFalse(self.manifest["personalSavesUsed"])

    def test_imported_ttf_matches_every_uncompressed_original_table(self):
        raw = (self.path / "DefaultFont.ttf").read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), self.manifest["conversion"]["ttfSha256"])
        tables = sfnt_tables(raw)
        self.assertEqual(table_hashes(tables), self.manifest["conversion"]["tableHashes"])
        self.assertEqual(len(tables), self.manifest["conversion"]["tableCount"])
        self.assertFalse(self.manifest["conversion"]["timestampRecalculated"])

    def test_font_covers_all_existing_source_and_translation_glyphs(self):
        import i18n
        po = i18n.read_po(str(ROOT / "translations/en.po"))
        expected = {ord(c) for e in po.entries for c in e.msgid + e.plural + e.msgstr + "".join(e.msgstr_plural)}
        self.assertLessEqual(expected, set(self.manifest["codepoints"]))
        self.assertEqual(self.manifest["conversion"]["missingPrimaryCodepoints"], FALLBACK_CODEPOINTS)
        self.assertEqual(self.manifest["metrics"]["missingPrimaryGlyphs"], FALLBACK_CODEPOINTS)
        self.assertEqual(self.manifest["metrics"]["family"], "Open Sans SemiBold")
        self.assertIn("SemiBold", self.manifest["metrics"]["style"])

    def test_six_original_os_fallback_symbols_have_explicit_bundled_coverage(self):
        fallback = self.manifest["fallback"]
        self.assertEqual(fallback["codepoints"], FALLBACK_CODEPOINTS)
        source = (self.path / "FallbackFont.woff2.bytes").read_bytes()
        self.assertEqual(hashlib.sha256(source).hexdigest(), FALLBACK_SHA256)
        raw = (self.path / "FallbackFont.ttf").read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), fallback["conversion"]["ttfSha256"])
        self.assertEqual(table_hashes(sfnt_tables(raw)), fallback["conversion"]["tableHashes"])
        self.assertFalse(fallback["conversion"]["missingPrimaryCodepoints"])
        self.assertTrue(fallback["platformIndependent"])
        self.assertFalse(fallback["claimedSameAsOriginalOsFace"])
        self.assertEqual(fallback["resourceKey"], "BlueMapAssets/Fonts/FallbackFont")

    def test_original_license_and_modification_notice_are_bundled(self):
        license_text = (self.path / "Apache-2.0.txt").read_text(encoding="utf-8")
        self.assertIn("Apache License", license_text)
        self.assertIn("Version 2.0", license_text)
        notice = (self.path / "NOTICE.txt").read_text(encoding="utf-8")
        self.assertIn("Copyright", notice)
        self.assertIn("Container conversion only", notice)
        self.assertEqual(self.manifest["license"], "Apache-2.0")


if __name__ == "__main__":
    unittest.main()
