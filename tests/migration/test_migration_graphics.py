"""Pixel identity, source-proven layout cells and generated-art boundaries."""
from __future__ import annotations

import copy
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import build_migration_graphics as graphics
from build_migration_audio_text import PresentationError, sha


def image_bytes(mode="RGBA"):
    image = Image.new(mode, (2, 2))
    image.putdata([(255, 0, 0, 255), (0, 255, 0, 128), (0, 0, 255, 0), (22, 33, 44, 255)]
                  if mode == "RGBA" else [(255, 0, 0), (0, 255, 0), (0, 0, 255), (22, 33, 44)])
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def small_catalog():
    texture = {"id": "png:test", "resourcePath": "BlueMapAssets/Graphics/Original/test",
               "sourcePath": "test.png", "alphaMode": "straight", **graphics.png_metadata(image_bytes())}
    return {"schemaVersion": 1, "tilePixels": 32, "textures": [texture], "sprites": [
        {"id": "frame", "textureId": "png:test", "category": "test", "x": 0, "y": 0,
         "width": 1, "height": 2, "pivotX": .5, "pivotY": .5, "pixelsPerUnit": 32}],
        "animations": [{"id": "animation", "frames": ["frame"], "fps": 5, "loop": True}]}


class PNGTests(unittest.TestCase):
    def test_rgba_digest_retains_top_down_rows_and_transparent_rgb(self):
        raw = image_bytes()
        metadata = graphics.png_metadata(raw)
        expected = bytes((255, 0, 0, 255, 0, 255, 0, 128, 0, 0, 255, 0, 22, 33, 44, 255))
        self.assertEqual(metadata["rgbaSha256"], sha(expected))
        self.assertEqual(metadata["sha256"], sha(raw))
        self.assertEqual((metadata["width"], metadata["height"]), (2, 2))

    def test_rgb_png_is_converted_to_rgba_without_changing_the_source(self):
        raw = image_bytes("RGB")
        expected = bytes((255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 22, 33, 44, 255))
        self.assertEqual(graphics.png_metadata(raw)["rgbaSha256"], sha(expected))
        self.assertEqual(graphics.png_metadata(raw)["sha256"], sha(raw))

    def test_bad_crc_or_truncated_png_is_rejected(self):
        original = image_bytes()
        for raw in (b"bad", original[:-8], original[:38] + bytes([original[38] ^ 1]) + original[39:]):
            with self.subTest(size=len(raw)), self.assertRaises(PresentationError):
                graphics.png_metadata(raw)

    def test_pixel_import_policy_preserves_nearest_alpha_and_native_size(self):
        meta = graphics.texture_meta("Assets/BlueMapContent/test.png").decode()
        for setting in ("enableMipMap: 0", "filterMode: 0", "nPOTScale: 0", "alphaIsTransparency: 0",
                        "textureCompression: 0", "isReadable: 1"):
            self.assertIn(setting, meta)


class GraphicsContractTests(unittest.TestCase):
    def test_all_sprite_bounds_and_animation_references_validate(self):
        graphics.validate_catalog(small_catalog())

    def test_missing_or_duplicate_texture_and_sprite_ids_reject(self):
        for mutate in (lambda c: c["textures"].append(copy.deepcopy(c["textures"][0])),
                       lambda c: c["sprites"].append(copy.deepcopy(c["sprites"][0])),
                       lambda c: c["sprites"][0].update(textureId="missing")):
            catalog = small_catalog()
            mutate(catalog)
            with self.assertRaises(PresentationError):
                graphics.validate_catalog(catalog)

    def test_every_texture_needs_explicit_alpha_semantics_and_originals_stay_straight(self):
        for alpha in (None, "opaque", "Premultiplied", "premultiplied", [], 1):
            catalog = small_catalog()
            if alpha is None:
                del catalog["textures"][0]["alphaMode"]
            else:
                catalog["textures"][0]["alphaMode"] = alpha
            with self.subTest(alpha=alpha), self.assertRaises(PresentationError):
                graphics.validate_catalog(catalog)

    def test_gpu_atlas_alpha_is_premultiplied_and_direct_images_are_straight(self):
        for identifier in ("generated:appearances-0", "generated:eyes-0", "generated:swords-1",
                           "generated:tools-0", "generated:water-0", "generated:crops-0"):
            graphics.validate_generated_alpha({"id": identifier, "alphaMode": "premultiplied"})
            for wrong in ({"id": identifier}, {"id": identifier, "alphaMode": "straight"}):
                with self.subTest(wrong=wrong), self.assertRaises(PresentationError):
                    graphics.validate_generated_alpha(wrong)
        for identifier in graphics.STRAIGHT_GENERATED:
            graphics.validate_generated_alpha({"id": identifier, "alphaMode": "straight"})
            with self.assertRaises(PresentationError):
                graphics.validate_generated_alpha({"id": identifier, "alphaMode": "premultiplied"})

    def test_outside_rectangle_negative_size_and_boolean_coordinates_reject(self):
        for field, value in (("x", 2), ("y", -1), ("height", 3), ("width", 0), ("x", True)):
            catalog = small_catalog()
            catalog["sprites"][0][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(PresentationError):
                graphics.validate_catalog(catalog)

    def test_invalid_pivot_scale_and_animation_timing_reject(self):
        for field, value in (("pivotX", float("nan")), ("pivotY", 2), ("pixelsPerUnit", 16)):
            catalog = small_catalog()
            catalog["sprites"][0][field] = value
            with self.subTest(field=field), self.assertRaises(PresentationError):
                graphics.validate_catalog(catalog)
        for mutate in (lambda c: c["animations"][0].update(frames=["missing"]),
                       lambda c: c["animations"][0].update(fps=0),
                       lambda c: c["animations"][0].update(loop=1)):
            catalog = small_catalog()
            mutate(catalog)
            with self.assertRaises(PresentationError):
                graphics.validate_catalog(catalog)

    def test_layout_literal_is_data_only_and_retains_authored_order(self):
        source = 'const HAIR := {"second":2,"first":1}\n'
        self.assertEqual(list(graphics.literal_constant(source, "HAIR")), ["second", "first"])
        array = 'const NAMES: Array[String] = ["a", # note\n "b", ]\n'
        self.assertEqual(graphics.literal_constant(array, "NAMES"), ["a", "b"])
        for source in ('const HAIR := load("res://run.gd")', 'const HAIR := [run()]', 'const HAIR := ["unclosed"'):
            with self.subTest(source=source), self.assertRaises(PresentationError):
                graphics.literal_constant(source, "HAIR")

    def test_procedural_contract_retains_whole_source_and_nested_function_spans(self):
        source = ('extends RefCounted\n# dependencies also stay here\nclass Inner:\n'
                  '\tfunc draw():\n\t\treturn "pixels"\n\n'
                  'static func helper():\n\treturn 2\n')
        contract = graphics.procedural_contract("scripts/fixture.gd", source)
        self.assertEqual(contract["source"], source)
        self.assertEqual(contract["sha256"], sha(source.encode()))
        self.assertEqual([item["name"] for item in contract["functions"]], ["draw", "helper"])
        for item in contract["functions"]:
            expected = "".join(source.splitlines(keepends=True)[item["line"] - 1:item["endLine"]])
            self.assertEqual(item["source"], expected)
            self.assertEqual(item["sha256"], sha(expected.encode()))
        self.assertEqual(contract["execution"], "not_executed_source_only")

    def test_generated_engine_and_exporter_hashes_reject_stale_or_wrong_sources(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-Graphics-Tests-") as temporary:
            root = Path(temporary)
            handlers = {}
            for source in graphics.EXPORTERS:
                path = root / source[len("res://"):]
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"extends SceneTree\r\n")
                handlers[source] = sha(b"extends SceneTree\n")
            index = {"engineVersion": graphics.ENGINE_VERSION, "exporterSources": handlers}
            graphics.validate_generated_provenance(index, root)
            for change in ({"engineVersion": "4.4.2.stable"}, {"exporterSources": {}},
                           {"exporterSources": {key: "0" * 64 for key in handlers}}):
                with self.subTest(change=change), self.assertRaises(PresentationError):
                    graphics.validate_generated_provenance({**index, **change}, root)
            (root / graphics.EXPORTERS[0][len("res://"):]).write_text("changed source", encoding="utf-8")
            with self.assertRaisesRegex(PresentationError, "Stale generated"):
                graphics.validate_generated_provenance(index, root)


class FrozenGraphicsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.documents = graphics.build_documents(ROOT, require_generated=False)
        cls.catalog = json.loads(cls.documents["migration/presentation/graphics.json"])
        cls.sprites = {entry["id"]: entry for entry in cls.catalog["sprites"]}

    def test_all_244_original_png_bytes_and_rgba_are_preserved(self):
        textures = [entry for entry in self.catalog["textures"] if entry["id"].startswith("png:")]
        self.assertEqual(len(textures), 244)
        for entry in textures:
            raw = (ROOT / entry["sourcePath"]).read_bytes()
            self.assertEqual(raw, self.documents[graphics.GRAPHICS_ROOT + "/Original/" + entry["sourcePath"]])
            self.assertEqual(graphics.png_metadata(raw)["rgbaSha256"], entry["rgbaSha256"])
            self.assertIn("image:" + entry["sourcePath"], self.sprites)
            self.assertEqual(entry["alphaMode"], "straight")

    def test_generated_alpha_tag_changes_no_png_or_rgba_bytes(self):
        generated = [entry for entry in self.catalog["textures"] if entry["id"].startswith("generated:")]
        for entry in generated:
            graphics.validate_generated_alpha(entry)
            raw = self.documents[graphics.GRAPHICS_ROOT + "/Generated/" + entry["file"]]
            self.assertEqual(raw, (ROOT / graphics.GENERATED_ROOT / entry["file"]).read_bytes())
            self.assertEqual(graphics.png_metadata(raw)["rgbaSha256"], entry["rgbaSha256"])

    def test_native_player_and_npc_cells_and_walk_timing(self):
        self.assertEqual([self.sprites["player:down:" + pose]["x"] for pose in graphics.POSES], [0, 32, 64])
        self.assertEqual(self.sprites["npc_bram:left:step2"]["y"], 96)
        animations = {entry["id"]: entry for entry in self.catalog["animations"]}
        self.assertEqual(animations["actor:player:down"]["fps"], 9)
        self.assertEqual(animations["actor:npc_bram:down"]["fps"], 5)
        self.assertEqual(animations["actor:player:down"]["frames"], ["player:down:step1", "player:down:step2"])

    def test_hair_clothing_and_terrain_indices_are_not_renumbered(self):
        self.assertEqual(self.sprites["hair:m_kort:down"]["x"], 2 * 32)
        self.assertEqual(self.sprites["hair:v_kort_golvend:left"]["x"], 89 * 32)
        self.assertEqual(self.sprites["clothes:cloth_cape:right:step2"]["x"], (3 * 3 + 2) * 32)
        self.assertEqual(self.sprites["clothes:gear_gloves:up:idle"]["x"], 27 * 3 * 32)
        self.assertEqual((self.sprites["tile:grass:0"]["x"], self.sprites["tile:grass:0"]["y"]), (0, 0))
        self.assertEqual(self.sprites["tile:ad_seawall:7"]["x"], 79 * 32)
        self.assertEqual(sum(entry["category"] == "terrain" for entry in self.catalog["sprites"]), 640)

    def test_canopy_and_orchard_pivots_keep_source_draw_anchors(self):
        self.assertEqual(self.sprites["canopy:tree:0"]["pivotY"], 6 / 64)
        self.assertEqual(self.sprites["orchard:canopies:4"]["pivotY"], .25)
        self.assertNotIn("orchard:trunks:4", self.sprites)
        self.assertIn("orchard:trunks:3", self.sprites)
        for identifier in ("furniture:lamp:2", "yard:fence:3"):
            self.assertEqual((self.sprites[identifier]["pivotX"], self.sprites[identifier]["pivotY"]), (.5, .25))

    def test_house_yard_and_crop_regions_match_authored_frames(self):
        self.assertEqual(self.sprites["furniture:lamp:2"]["x"], 6 * 64)
        self.assertEqual(self.sprites["rug:2"]["width"], 128)
        self.assertEqual(self.sprites["yard:path:boards:15"]["y"], 2 * 32)
        self.assertEqual(self.sprites["crop:rosemary:3"]["y"], 3 * 32)
        self.assertNotIn("crop:grape:0", self.sprites)  # Its runtime art is exported separately.

    def test_native_aliases_choose_existing_detailed_texture(self):
        aliases = {entry["name"]: entry for entry in self.catalog["aliases"]}
        self.assertEqual(aliases["player"]["detailedTextureId"], "png:assets/pixel_player.png")
        self.assertEqual(aliases["player"]["density"], 2)

    def test_all_original_scripts_retain_raw_source_and_function_hashes(self):
        contracts = self.catalog["proceduralSources"]
        expected = {entry["path"] for entry in json.loads((ROOT / "migration/reference/source-manifest.json").read_text())["files"]
                    if entry["path"].startswith("scripts/") and entry["path"].endswith(".gd")}
        self.assertEqual({entry["path"] for entry in contracts}, expected)
        for entry in contracts:
            self.assertEqual(entry["source"], (ROOT / entry["path"]).read_text(encoding="utf-8"))
            self.assertEqual(entry["sha256"], sha(entry["source"].encode()))
        functions = {entry["path"]: {function["name"] for function in entry["functions"]} for entry in contracts}
        self.assertIn("_draw", functions["scripts/entities/player.gd"])
        self.assertIn("front", functions["scripts/core/character_layers.gd"])

    def test_svg_source_and_dual_catalog_are_exact(self):
        self.assertEqual(self.documents[graphics.GRAPHICS_ROOT + "/Original/icon.svg.txt"],
                         (ROOT / "icon.svg").read_bytes().replace(b"\r\n", b"\n"))
        self.assertEqual(self.documents["migration/presentation/graphics.json"],
                         self.documents[graphics.RESOURCE_ROOT + "/Data/graphics.json"])

    def test_generated_index_required_for_complete_publication(self):
        if (ROOT / graphics.GENERATED_ROOT / "index.json").is_file():
            self.assertTrue(graphics.build_documents(ROOT))
        else:
            with self.assertRaisesRegex(PresentationError, "has not been supplied"):
                graphics.build_documents(ROOT)

    def test_optional_complete_generated_outputs(self):
        if not (ROOT / "migration/presentation/graphics.json").is_file():
            self.skipTest("Complete generated graphics output not supplied yet")
        self.assertTrue(graphics.write_or_check(ROOT, self.documents, check=True)["success"])


if __name__ == "__main__":
    unittest.main()
