"""Rule-contract tests use public source/JSON and synthetic data, never saves."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("rule_contracts", ROOT / "tools/migration_rule_contracts.py")
rules = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(rules)


class RuleContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.content = json.loads((ROOT / "migration/reference/content-inventory.json").read_text(encoding="utf-8"))
        cls.maps = json.loads((ROOT / "migration/reference/maps-inventory.json").read_text(encoding="utf-8"))
        cls.contract = rules.build_rule_contracts(ROOT, cls.content, cls.maps)

    def scan(self, value, field="if"):
        content = copy.deepcopy(self.content)
        content["catalogs"]["talks"]["entries"].append({"id": "synthetic_fixture", "value": {field: value}})
        report = rules.scan_rule_usages(content, self.maps)
        return [item for item in report["diagnostics"] if "synthetic_fixture" in item["location"]]

    def test_actual_registry_usage_and_all_handler_contracts_pass(self):
        rules.validate_rule_contracts(self.contract)
        self.assertEqual(self.contract["counts"]["conditions"], 33)
        self.assertEqual(self.contract["counts"]["actions"], 36)
        self.assertGreaterEqual(self.contract["counts"]["invocations"], 1000)
        self.assertEqual(self.contract["usage"]["diagnostics"], [])
        self.assertFalse(self.contract["implementation"]["runtimeEquivalenceProven"])

    def test_contract_output_is_deterministic_and_matches_stored_contract(self):
        stored = json.loads((ROOT / "migration/contracts/rules.json").read_text(encoding="utf-8"))
        self.assertEqual(self.contract, stored)
        self.assertEqual(self.contract, rules.build_rule_contracts(ROOT, self.content, self.maps))

    def test_nested_any_conditions_are_recursively_checked(self):
        self.assertEqual(self.scan([["any", ["flag", "one"], ["any", ["has", "potion"], ["hurt"]]]]), [])
        errors = self.scan([["any", ["flag", "one"], ["unknown_nested"]]])
        self.assertEqual(errors[0]["code"], "unknown_operation")
        self.assertTrue(errors[0]["location"].endswith("/0/2"))
        self.assertIn("return false", errors[0]["legacyBehavior"])

    def test_unknown_action_is_rejected_without_inventing_runtime_effect(self):
        errors = self.scan([["unknown_action"]], "do")
        self.assertEqual(errors[0]["code"], "unknown_operation")
        self.assertIn("perform no action", errors[0]["legacyBehavior"])

    def test_empty_condition_list_is_distinct_from_empty_condition(self):
        self.assertEqual(self.scan([]), [])
        self.assertEqual(self.scan([[]])[0]["code"], "malformed_invocation")
        self.assertIn("empty list returns true", self.contract["dispatch"]["conditions"])
        self.assertIn("gate blocked", self.contract["contexts"]["gate"])
        self.assertIn("explicitly excluded", self.contract["contexts"]["achievement"])

    def test_malformed_lists_and_invocation_ids_are_rejected(self):
        for value in (None, "flag", {"flag": "one"}):
            with self.subTest(value=value):
                self.assertEqual(self.scan(value)[0]["code"], "malformed_operation_list")
        for value in (["flag", "one"], [[42]], ["hurt"]):
            with self.subTest(value=value):
                self.assertEqual(self.scan(value)[0]["code"], "malformed_invocation")

    def test_missing_and_excess_arguments_are_rejected(self):
        self.assertEqual(self.scan([["has"]])[0]["code"], "incorrect_arity")
        errors = self.scan([["hurt", 1]])
        self.assertEqual(errors[0]["code"], "incorrect_arity")
        self.assertIn("ignore unused trailing", errors[0]["legacyBehavior"])
        self.assertEqual(self.scan([["quest_step", "main"]], "do")[0]["code"], "incorrect_arity")

    def test_argument_types_and_reference_namespaces_are_checked(self):
        for value in ([["coins", True]], [["has", "potion", "2"]], [["kinds_killed", "slime"]]):
            with self.subTest(value=value):
                self.assertEqual(self.scan(value)[0]["code"], "incorrect_type")
        for value in ([["map", "not_a_map"]], [["quest", "not_a_quest", "active"]], [["talked_to_all", ["not_an_npc"]]]):
            with self.subTest(value=value):
                self.assertEqual(self.scan(value)[0]["code"], "unknown_reference")
        self.assertEqual(self.scan([["sound", "not_a_sound"]], "do")[0]["code"], "unknown_reference")

    def test_dutch_phase_tokens_and_arena_rank_links_are_preserved(self):
        self.assertEqual(self.scan([["phase", "nacht"]]), [])
        self.assertEqual(self.scan([["phase", "night"]])[0]["code"], "unknown_argument_value")
        self.assertEqual(self.scan([["arena_enter", "bronze"]], "do"), [])
        self.assertEqual(self.scan([["arena_enter", "diamond"]], "do")[0]["code"], "unknown_reference")

    def test_optional_counts_and_variadic_zero_operand_legacy_behavior(self):
        self.assertEqual(self.scan([["has", "potion"], ["lacks", "potion", 2], ["any"], ["boog_missing"]]), [])
        self.assertEqual(self.scan([["give", "potion"], ["boog_progress"]], "do"), [])
        has = next(value for value in self.contract["conditions"] if value["id"] == "has")
        self.assertEqual(has["arguments"][1]["default"], 1)
        self.assertEqual(has["arity"], {"minimumArguments": 1, "maximumArguments": 2})
        any_rule = next(value for value in self.contract["conditions"] if value["id"] == "any")
        self.assertIsNone(any_rule["arity"]["maximumArguments"])

    def test_legacy_unhandled_world_action_is_explicit(self):
        self.assertEqual(self.contract["diagnostics"][0]["code"], "legacy_unhandled_world_action")
        self.assertEqual(self.contract["diagnostics"][0]["id"], "lock_arena")
        self.assertEqual(self.scan([["lock_arena"]], "do"), [])

    def test_validation_rejects_missing_contract_changed_defaults_and_false_port_claim(self):
        damaged = copy.deepcopy(self.contract)
        damaged["actions"].pop()
        with self.assertRaises(rules.RuleContractError):
            rules.validate_rule_contracts(damaged)
        damaged = copy.deepcopy(self.contract)
        has = next(value for value in damaged["conditions"] if value["id"] == "has")
        has["arguments"][1]["default"] = 2
        with self.assertRaisesRegex(rules.RuleContractError, "arguments/defaults"):
            rules.validate_rule_contracts(damaged)
        damaged = copy.deepcopy(self.contract)
        damaged["implementation"]["runtimeEquivalenceProven"] = True
        with self.assertRaisesRegex(rules.RuleContractError, "does not implement"):
            rules.validate_rule_contracts(damaged)

    def test_source_evidence_hashes_ignore_windows_line_endings(self):
        record = next(value for value in self.contract["conditions"] if value["id"] == "flag")
        with tempfile.TemporaryDirectory(prefix="bluemap-rule-source-fixture-") as temporary:
            root = Path(temporary)
            path = root / "scripts/core/game_state.gd"
            path.parent.mkdir(parents=True)
            original = (ROOT / "scripts/core/game_state.gd").read_text(encoding="utf-8-sig")
            path.write_bytes(original.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))
            self.assertEqual(record["handlers"][0], rules._source_anchor(root, "scripts/core/game_state.gd", "check"))


if __name__ == "__main__":
    unittest.main()
