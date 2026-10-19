"""Synthetic identity-corruption cases; no engine, original data edits or saves."""
from copy import deepcopy
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import migration_runtime_ids as runtime


def wire(value):
    if value is None:
        return {"kind": "nil"}
    if type(value) is bool:
        return {"kind": "bool", "value": value}
    if type(value) in (int, float):
        return {"kind": "int" if type(value) is int else "float", "value": str(value)}
    if type(value) is str:
        return {"kind": "string", "value": value}
    if type(value) is list:
        return {"kind": "array", "type": "Array", "values": [wire(v) for v in value]}
    return {"kind": "dictionary", "entries": [[wire(k), wire(v)] for k, v in value.items()]}


def vector(x, y):
    return {"kind": "vector", "type": "Vector2", "values": [wire(float(x)), wire(float(y))]}


def node(index, script, position, **fields):
    return {"address": ["entities", index], "script": "res://scripts/entities/" + script + ".gd",
            "globalTransform": {"kind": "transform2d", "x": vector(1, 0), "y": vector(0, 1),
                                "origin": vector(*position)}, "fields": wire(fields)}


def set_field(record, name, value):
    fields = record["fields"]["entries"]
    found = next((pair for pair in fields if pair[0]["value"] == name), None)
    if found is None:
        fields.append([wire(name), wire(value)])
    else:
        found[1] = wire(value)


def fixture():
    objects = [{"type": "chest", "pos": [1, 1]},
               {"type": "chest", "pos": [2, 1], "enabled": False},
               {"type": "profession_resource", "id": "ore", "kind": "iron", "pos": [3, 1]},
               {"type": "savepoint", "pos": [4, 1]},
               *[{"type": "route_object", "id": "rf_tracks", "pos": [x, 2]} for x in [1, 2, 3]]]
    appended = {"type": "profession_resource", "id": "apple", "kind": "apple", "pos": [5, 1]}
    maps = {"maps": [{"id": "a", "registry_snapshot": {"objects": objects},
                      "post_registry_legacy_resources": [{"id": "apple", "value": appended}]}]}
    phase4 = {"resourceInstances": [{"id": key, "mapId": "a"} for key in ["ore", "apple"]],
              "maps": [{"altars": [{"id": "altaar_a_4_1", "mapId": "a"}]}]}
    slots = [{key: value for key, value in row.items()
              if key in {"index", "registryIndex", "appendOrder", "type", "legacySlotKey", "enabled"}}
             for row in runtime.expected_slots(maps)["a"]]
    scene = [node(0, "chest", [48, 48], unique_key="chest:a:0"),
             node(2, "resource_node", [112, 48], resource_id="ore", kind="iron", key="profession_resource:a:2"),
             node(3, "savepoint", [144, 48]),
             *[node(index, "first_route_object", [x * 32 + 16, 80], id="rf_tracks", key=f"route_object:a:{index}")
               for index, x in zip(range(4, 7), [1, 2, 3])],
             node(7, "resource_node", [176, 48], resource_id="apple", kind="apple", key="profession_resource:a:7")]
    snapshot = {"scenarioId": "fresh_baseline", "mapId": "a", "slots": slots,
                "mapData": wire({"objects": objects + [appended]}), "scene": scene}
    return maps, phase4, snapshot


class RuntimeWorldIdentityTests(unittest.TestCase):
    def setUp(self):
        self.maps, self.phase4, self.snapshot = fixture()

    def collect(self, *snapshots, **kwargs):
        return runtime.collect_runtime_identities(snapshots or [self.snapshot], self.maps, self.phase4, **kwargs)

    def test_final_indices_keep_disabled_slots_and_exact_append_order(self):
        report = self.collect()
        slots = report["maps"][0]["slots"]
        self.assertEqual([row["index"] for row in slots], list(range(8)))
        self.assertFalse(slots[1]["enabled"])
        self.assertEqual((slots[7]["registryIndex"], slots[7]["appendOrder"], slots[7]["resourceId"]), (None, 0, "apple"))
        self.assertEqual(slots[7]["legacySlotKey"], "profession_resource:a:7")

    def test_three_duplicate_logical_route_ids_are_preserved(self):
        report = self.collect()
        track = next(r for r in report["identities"] if r["id"] == "rf_tracks")
        self.assertEqual(len(track["occurrences"]), 3)
        self.assertEqual([o["objectArrayIndex"] for o in track["occurrences"]], [4, 5, 6])

    def test_resource_repeated_in_another_profile_is_the_same_identity(self):
        other = deepcopy(self.snapshot)
        other["scenarioId"] = "full_progress"
        report = self.collect(self.snapshot, other)
        self.assertEqual(report["coverage"]["runtimeResourceIds"], 2)
        resource = next(r for r in report["identities"] if r["namespace"] == ["profession_cooldown"] and r["id"] == "ore")
        self.assertEqual(len(resource["occurrences"]), 2)

    def test_runtime_resources_and_fishing_have_no_invented_array_index(self):
        other = deepcopy(self.snapshot)
        other["scenarioId"] = "restored"
        other["scene"] += [node(17, "resource_node", [800, 900], resource_id="dynamic", kind="mint", key="dynamic"),
                           node(18, "meer_visplek", [900, 900], key="lw_marsh_fishing")]
        report = self.collect(self.snapshot, other, runtime_resources={"dynamic": ("a", [800.0, 900.0], "mint")})
        resource = next(r for r in report["identities"] if r["namespace"] == ["profession_cooldown"] and r["id"] == "dynamic")
        self.assertIsNone(resource["occurrences"][0]["objectArrayIndex"])
        self.assertEqual(resource["occurrences"][0]["origin"], "runtime_node_outside_object_array")
        self.assertEqual(report["coverage"]["additionalFishingKeys"], ["lw_marsh_fishing"])
        fishing = next(r for r in report["identities"] if r["id"] == "lw_marsh_fishing")
        self.assertEqual(fishing["role"], "handler_key_not_claimed_saved")

    def test_renamed_legacy_saved_key_is_rejected(self):
        set_field(self.snapshot["scene"][0], "unique_key", "chest:a:renamed")
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "Unknown or renamed"):
            self.collect()

    def test_saved_key_cannot_be_renamed_to_another_existing_chest(self):
        set_field(self.snapshot["scene"][0], "unique_key", "chest:a:1")
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "another physical slot"):
            self.collect()

    def test_filtered_reindexing_is_rejected_even_if_count_is_unchanged(self):
        self.snapshot["slots"][2]["index"] = 1
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "final object index"):
            self.collect()

    def test_bool_cannot_impersonate_integer_index(self):
        self.snapshot["slots"][1]["index"] = True
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "final object index"):
            self.collect()

    def test_reordered_explicit_resource_array_is_rejected(self):
        values = runtime.field_nodes(self.snapshot["mapData"])["objects"]["values"]
        values[2], values[7] = values[7], values[2]
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "Resource array was reordered"):
            self.collect()

    def test_duplicate_explicit_resource_id_in_one_profile_is_rejected(self):
        self.snapshot["scene"].append(node(99, "resource_node", [112, 48], resource_id="ore", kind="iron"))
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "Duplicate explicit resource"):
            self.collect()

    def test_explicit_resource_id_on_different_node_in_other_profile_is_rejected(self):
        other = deepcopy(self.snapshot)
        other["scenarioId"] = "full_progress"
        other["scene"][1]["globalTransform"]["origin"] = vector(700, 800)
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "distinct logical map nodes"):
            self.collect(self.snapshot, other)

    def test_unknown_runtime_only_resource_id_is_rejected(self):
        other = deepcopy(self.snapshot)
        other["scenarioId"] = "restored"
        other["scene"].append(node(99, "resource_node", [100, 200], resource_id="renamed_dynamic", kind="mint"))
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "Unknown or renamed runtime-only"):
            self.collect(self.snapshot, other)

    def test_resource_id_must_still_match_actual_slot_position(self):
        self.snapshot["scene"][1]["globalTransform"]["origin"] = vector(700, 800)
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "physical object-array slot"):
            self.collect()

    def test_missing_baseline_map_and_altar_are_rejected(self):
        self.snapshot["scenarioId"] = "full_progress"
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "every fresh baseline map"):
            self.collect()
        self.snapshot["scenarioId"] = "fresh_baseline"
        self.snapshot["scene"] = [n for n in self.snapshot["scene"] if not n["script"].endswith("/savepoint.gd")]
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "altar membership"):
            self.collect()

    def test_repeated_npc_ids_and_handler_keys_do_not_claim_global_uniqueness(self):
        self.snapshot["scene"] += [node(30, "npc", [100, 200], npc_id="joris"),
                                   node(31, "npc", [200, 200], npc_id="joris")]
        report = self.collect()
        npc = next(r for r in report["identities"] if r["id"] == "joris")
        self.assertEqual(len(npc["occurrences"]), 2)
        candidates = [r for r in report["identities"] if r["namespace"][0] == "handler_key_candidate"]
        self.assertTrue(candidates)
        self.assertEqual({r["role"] for r in candidates}, {"handler_dependent_not_universal_persistence"})

    def test_gate_derivation_is_conditioned_on_key_use(self):
        self.snapshot["scene"] += [node(30, "gate", [100, 200], gate_id="north", key_item="key"),
                                   node(31, "gate", [200, 200], gate_id="west", key_item="")]
        report = self.collect()
        gates = {r["id"]: r for r in report["identities"] if r["namespace"] == ["gate", "a"]}
        self.assertEqual(gates["north"]["derivedKeyUseFlag"]["id"], "gate_north")
        self.assertTrue(gates["north"]["derivedKeyUseFlag"]["usedWhenKeyItemNonempty"])
        self.assertFalse(gates["west"]["derivedKeyUseFlag"]["usedWhenKeyItemNonempty"])

    def test_saved_story_flags_keep_string_type(self):
        self.snapshot["scene"].append(node(30, "enemy", [100, 200], unique_flag=123))
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "story flag must remain a string"):
            self.collect()

    def test_saved_manure_key_is_tied_to_exact_drop_journal(self):
        self.snapshot["stateAfter"] = wire({"homestead": {"drops": {"animal:600": {"map": "a", "pos": [300, 400]}}}})
        self.snapshot["scene"].append(node(30, "pickup", [300, 400], unique_key="hs_drop:animal:600", item="hs_manure"))
        report = self.collect()
        drop = next(r for r in report["identities"] if r["id"] == "hs_drop:animal:600")
        self.assertIsNone(drop["occurrences"][0]["objectArrayIndex"])
        set_field(self.snapshot["scene"][-1], "unique_key", "hs_drop:renamed")
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "absent from the captured drop journal"):
            self.collect()

    def test_guardian_reward_has_fixed_key_and_source_chest_coordinate(self):
        objects = [{"type": "guardian", "pos": [3, 4], "chest": [5, 6]}]
        maps = {"maps": [{"id": "depths2", "registry_snapshot": {"objects": objects}, "post_registry_legacy_resources": []}]}
        fixed = runtime.expected_slots(maps)["depths2"][0]
        slots = [{key: fixed[key] for key in ("index", "registryIndex", "appendOrder", "type", "legacySlotKey", "enabled")}]
        snapshot = {"scenarioId": "fresh_baseline", "mapId": "depths2", "mapData": wire({"objects": objects}),
                    "slots": slots, "scene": [node(50, "chest", [176, 208], unique_key="chest:depths2:heart")]}
        phase4 = {"resourceInstances": [], "maps": [{"altars": []}]}
        report = runtime.collect_runtime_identities([snapshot], maps, phase4)
        self.assertEqual(report["identities"][0]["id"], "chest:depths2:heart")
        self.assertIsNone(report["identities"][0]["occurrences"][0]["objectArrayIndex"])
        snapshot["scene"][0]["globalTransform"]["origin"] = vector(200, 300)
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "authored chest tile"):
            runtime.collect_runtime_identities([snapshot], maps, phase4)

    def test_saved_chest_key_on_pickup_handler_is_rejected(self):
        self.snapshot["scene"][0]["script"] = "res://scripts/entities/pickup.gd"
        with self.assertRaisesRegex(runtime.RuntimeIdentityError, "different handler"):
            self.collect()

    def test_cli_runs_whole_validation_and_never_accepts_obsolete_source_bypass(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "report.json"
            with patch.object(sys, "argv", ["runtime_ids", "--directory", folder, "--output", str(output)]), \
                    patch.object(runtime, "validate_world_export", side_effect=ValueError("obsolete scenario source")) as whole, \
                    patch.object(runtime, "build_runtime_identities") as collector:
                self.assertEqual(runtime.main(), 1)
            whole.assert_called_once()
            collector.assert_not_called()
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
