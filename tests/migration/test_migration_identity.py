"""Stable IDs, disabled slots and every legacy key family survive data contracts."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import migration_identity as identity


class MigrationIdentityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        base = ROOT / "migration/reference"
        cls.content = json.loads((base / "content-inventory.json").read_text(encoding="utf-8"))
        cls.maps = json.loads((base / "maps-inventory.json").read_text(encoding="utf-8"))
        cls.save = json.loads((base / "save-contract.json").read_text(encoding="utf-8"))
        cls.registry = identity.build_identity_registry(cls.content, cls.maps, cls.save)

    def rejected_registry(self, registry: dict) -> None:
        with self.assertRaises(identity.IdentityError):
            identity.validate_identity_registry(registry, self.content, self.maps, self.save)

    def test_complete_frozen_inputs_and_written_contract(self) -> None:
        report = identity.validate_identity_registry(self.registry, self.content, self.maps, self.save)
        self.assertTrue(report["success"])
        self.assertFalse(report["engineExecuted"])
        self.assertFalse(report["playerSavesUsed"])
        self.assertEqual(report["coverage"]["maps"], 37)
        self.assertEqual(report["coverage"]["catalogEntries"], 1501)
        self.assertEqual(report["coverage"]["registrySlots"], 905)
        self.assertEqual(report["coverage"]["disabledSlots"], 10)
        written = json.loads((ROOT / "migration/contracts/identity.json").read_text(encoding="utf-8"))
        self.assertEqual(written, self.registry)

    def test_builder_is_deterministic_and_does_not_mutate_inputs(self) -> None:
        before = [identity._digest(value) for value in (self.content, self.maps, self.save)]
        rebuilt = identity.build_identity_registry(self.content, self.maps, self.save)
        self.assertEqual(rebuilt, self.registry)
        self.assertEqual(before, [identity._digest(value) for value in (self.content, self.maps, self.save)])

    def test_all_existing_ids_remain_exact_strings_in_their_catalog(self) -> None:
        for name, catalog in self.content["catalogs"].items():
            self.assertEqual([row["id"] for row in catalog["entries"]],
                             [row["id"] for row in self.registry["catalogs"][name]])

    def test_same_id_in_different_catalogs_does_not_collide(self) -> None:
        item = next(row for row in self.registry["catalogs"]["items"] if row["id"] == "boots")
        achievement = next(row for row in self.registry["catalogs"]["achievements"] if row["id"] == "boots")
        self.assertEqual(item["id"], achievement["id"])
        self.assertNotEqual(item["namespace"], achievement["namespace"])

    def test_namespace_and_id_are_never_ambiguously_delimiter_joined(self) -> None:
        content = copy.deepcopy(self.content)
        sample = copy.deepcopy(content["catalogs"]["items"]["entries"][0])
        first, second = {**sample, "id": "c"}, {**sample, "id": "b:c"}
        content["catalogs"]["a:b"] = {"count": 1, "entries": [first]}
        content["catalogs"]["a"] = {"count": 1, "entries": [second]}
        built = identity.build_identity_registry(content, self.maps, self.save)
        one = built["catalogs"]["a:b"][0]
        two = built["catalogs"]["a"][0]
        self.assertEqual(one["namespace"], ["catalog", "a:b"])
        self.assertEqual(two["namespace"], ["catalog", "a"])
        self.assertNotEqual((one["namespace"], one["id"]), (two["namespace"], two["id"]))

    def test_duplicate_catalog_id_is_rejected(self) -> None:
        content = copy.deepcopy(self.content)
        catalog = content["catalogs"]["items"]
        catalog["entries"].append(copy.deepcopy(catalog["entries"][0]))
        catalog["count"] += 1
        with self.assertRaises(identity.IdentityError):
            identity.build_identity_registry(content, self.maps, self.save)

    def test_palette_indices_keep_the_same_saved_color(self) -> None:
        palettes = [row for row in self.registry["orderedCatalogs"]
                    if row["namespace"][-1] in {"hair_colors", "eye_colors", "dye_colors"}]
        self.assertEqual(len(palettes), 3)
        for palette in palettes:
            for index, entry in enumerate(palette["entries"]):
                self.assertEqual((entry["index"], entry["id"]), (index, str(index)))

    def test_changed_palette_index_is_rejected(self) -> None:
        content = copy.deepcopy(self.content)
        content["catalogs"]["hair_colors"]["entries"][1]["source_index"] = 0
        with self.assertRaises(identity.IdentityError):
            identity.build_identity_registry(content, self.maps, self.save)

    def test_tile_indices_preserve_original_art_order(self) -> None:
        tiles = next(row for row in self.registry["orderedCatalogs"] if row["namespace"][-1] == "tile_types")
        self.assertEqual(tiles["entries"][0]["id"], "grass")
        self.assertEqual(len(tiles["entries"]), 80)
        self.assertEqual([item["index"] for item in tiles["entries"]], list(range(80)))

    def test_changed_registry_tile_order_is_rejected(self) -> None:
        registry = copy.deepcopy(self.registry)
        tiles = next(row for row in registry["orderedCatalogs"] if row["namespace"][-1] == "tile_types")
        tiles["entries"][0], tiles["entries"][1] = tiles["entries"][1], tiles["entries"][0]
        self.rejected_registry(registry)

    def test_dictionary_order_is_preserved_for_appearance_fallbacks(self) -> None:
        source = next(row for row in self.content["declarations"]
                      if row["source"]["constant"] == "HAIR_M")
        result = next(row for row in self.registry["declarations"]
                      if row["namespace"] == ["declaration", source["source"]["path"], "HAIR_M"])
        self.assertEqual([entry["id"] for entry in result["entries"]], source["ids"])
        self.assertEqual([entry["sourceOrder"] for entry in result["entries"]],
                         list(range(len(source["ids"]))))

    def test_ordered_declaration_index_cannot_be_renumbered(self) -> None:
        content = copy.deepcopy(self.content)
        declaration = next(row for row in content["declarations"] if row["kind"] == "ordered_array")
        declaration["ids"][0]["index"] = 1
        with self.assertRaises(identity.IdentityError):
            identity.build_identity_registry(content, self.maps, self.save)

    def test_disabled_slots_are_not_filtered_or_reindexed(self) -> None:
        forest = next(row for row in self.registry["maps"] if row["id"] == "forest")
        disabled = [slot for slot in forest["slots"] if not slot["enabled"]]
        self.assertTrue(disabled)
        self.assertIn(14, [slot["index"] for slot in disabled])
        for index, slot in enumerate(forest["slots"]):
            self.assertEqual(slot["index"], index)
            self.assertEqual(slot["legacySlotKey"], f"{slot['type']}:forest:{index}")

    def test_deleted_slot_is_rejected(self) -> None:
        registry = copy.deepcopy(self.registry)
        next(row for row in registry["maps"] if row["id"] == "forest")["slots"].pop(14)
        self.rejected_registry(registry)

    def test_reordered_slot_is_rejected(self) -> None:
        maps = copy.deepcopy(self.maps)
        slots = maps["maps"][0]["object_slots"]
        slots[0], slots[1] = slots[1], slots[0]
        with self.assertRaises(identity.IdentityError):
            identity.build_identity_registry(self.content, maps, self.save)

    def test_changed_disabled_slot_state_is_rejected(self) -> None:
        maps = copy.deepcopy(self.maps)
        disabled = next(slot for row in maps["maps"] for slot in row["object_slots"] if not slot["enabled"])
        disabled["enabled"] = True
        with self.assertRaises(identity.IdentityError):
            identity.build_identity_registry(self.content, maps, self.save)

    def test_changed_generic_legacy_key_is_rejected(self) -> None:
        maps = copy.deepcopy(self.maps)
        maps["maps"][0]["object_slots"][0]["legacy_slot_key"] = "arena_crowd:arena:1"
        with self.assertRaises(identity.IdentityError):
            identity.build_identity_registry(self.content, maps, self.save)

    def test_duplicate_explicit_resource_ids_are_rejected_across_maps(self) -> None:
        maps = copy.deepcopy(self.maps)
        rows = [row for row in maps["maps"] if row["post_registry_legacy_resources"]]
        first = rows[0]["post_registry_legacy_resources"][0]
        second = rows[1]["post_registry_legacy_resources"][0]
        second["id"] = first["id"]
        second["value"]["id"] = first["id"]
        with self.assertRaises(identity.IdentityError):
            identity.build_identity_registry(self.content, maps, self.save)

    def test_registry_and_appended_resource_id_collision_is_rejected(self) -> None:
        maps = copy.deepcopy(self.maps)
        explicit = next(obj["id"] for row in maps["maps"]
                        for obj in row["registry_snapshot"]["objects"] if obj["type"] == "profession_resource")
        appended = next(row["post_registry_legacy_resources"][0]
                        for row in maps["maps"] if row["post_registry_legacy_resources"])
        appended["id"] = appended["value"]["id"] = explicit
        with self.assertRaises(identity.IdentityError):
            identity.build_identity_registry(self.content, maps, self.save)

    def test_post_registry_append_order_keeps_no_invented_runtime_index(self) -> None:
        for source, output in zip(self.maps["maps"], self.registry["maps"]):
            self.assertEqual([row["id"] for row in source["post_registry_legacy_resources"]],
                             [row["id"] for row in output["postRegistryResources"]])
            for index, resource in enumerate(output["postRegistryResources"]):
                self.assertEqual(resource["appendOrder"], index)
                self.assertIsNone(resource["registryIndex"])
                self.assertIsNone(resource["finalRuntimeIndex"])

    def test_runtime_index_must_remain_unclaimed(self) -> None:
        registry = copy.deepcopy(self.registry)
        registry["maps"][0]["slots"][0]["finalRuntimeIndex"] = 0
        self.rejected_registry(registry)

    def test_altars_use_coordinates_not_generic_slot_keys(self) -> None:
        village = next(row for row in self.registry["maps"] if row["id"] == "village")
        home = next(row for row in village["altars"] if row["tile"] == [9, 23])
        self.assertEqual(home["legacyDiscoveryKey"], "altaar_village_9_23")
        self.assertEqual(home["requestedSpawn"], "home_altar")
        self.assertNotEqual(home["id"], "savepoint:village:49")

    def test_changed_altar_key_is_rejected(self) -> None:
        registry = copy.deepcopy(self.registry)
        altar = next(altar for row in registry["maps"] for altar in row["altars"])
        altar["legacyDiscoveryKey"] = "altaar_relocated_without_alias"
        self.rejected_registry(registry)

    def test_map_display_names_and_spawn_scopes_are_preserved(self) -> None:
        for source, output in zip(self.maps["maps"], self.registry["maps"]):
            self.assertEqual(source["name"], output["name"])
            self.assertEqual(source["registry_snapshot"]["spawns"],
                             {spawn["id"]: spawn["tile"] for spawn in output["spawns"]})
            self.assertTrue(all(spawn["namespace"] == ["map_spawn", source["id"]]
                                for spawn in output["spawns"]))

    def test_all_saved_fields_and_sidecar_files_are_preserved(self) -> None:
        files = [row["id"] for row in self.registry["saveScopes"] if row["namespace"] == ["save_file"]]
        self.assertEqual(files, self.save["storage"]["files"])
        root_fields = next(row for row in self.registry["saveScopes"]
                           if row["namespace"] == ["save_fields", "savegame.json"])
        self.assertEqual([row["id"] for row in root_fields["entries"]], list(self.save["savegame"]["fields"]))
        controls = [row for row in self.registry["saveScopes"] if row["namespace"][:2] ==
                    ["config_section", "controls.cfg"]]
        self.assertEqual(len(controls), 2)
        self.assertTrue(all(row["engineCodesRequireTranslation"] for row in controls))

    def test_deleted_save_field_or_config_file_is_rejected(self) -> None:
        registry = copy.deepcopy(self.registry)
        root_fields = next(row for row in registry["saveScopes"]
                           if row["namespace"] == ["save_fields", "savegame.json"])
        root_fields["entries"].pop()
        self.rejected_registry(registry)
        registry = copy.deepcopy(self.registry)
        registry["saveScopes"].pop(0)
        self.rejected_registry(registry)

    def test_runtime_only_resource_gap_and_key_family_caveats_are_explicit(self) -> None:
        rules = {rule["kind"]: rule for rule in self.registry["legacyKeyRules"]}
        self.assertEqual(set(rules), {rule["kind"] for rule in self.save["identity_rules"]})
        self.assertIn("lw_mine_iron", rules["runtime_living_resource"]["format"])
        self.assertFalse(self.registry["coverage"]["runtimeOnlyResourceMembershipComplete"])
        self.assertEqual(self.registry["coverage"]["finalRuntimeIndicesAssigned"], 0)

    def test_boolean_cannot_replace_a_preserved_integer_index(self) -> None:
        registry = copy.deepcopy(self.registry)
        registry["maps"][0]["slots"][0]["index"] = False
        self.rejected_registry(registry)

    def test_changed_source_inventory_invalidates_old_registry(self) -> None:
        content = copy.deepcopy(self.content)
        content["catalogs"]["items"]["entries"][0]["id"] += "_changed"
        with self.assertRaises(identity.IdentityError):
            identity.validate_identity_registry(self.registry, content, self.maps, self.save)


if __name__ == "__main__":
    unittest.main()
