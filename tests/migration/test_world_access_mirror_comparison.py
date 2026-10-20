"""Keep exact world-state witnesses strict across Godot's OS decimal tie rounding."""
from __future__ import annotations

import copy
import json
import math
from pathlib import Path
import struct
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from migration_data_codec import canonical_bytes
from record_migration_world_access import (
    decode_float64_witness,
    normalize_exact_mirrors,
    validate_float64_bits,
)


BINARY_VALUE = 1424.010009765625
WINDOWS_DECIMAL = 1424.01000976563
LINUX_DECIMAL = 1424.01000976562


def witness(number):
    return {"$f64": struct.pack("<d", number).hex()}


def fixture(decimal=WINDOWS_DECIMAL):
    state = {"pos": [decimal, 16.0], "coins": 3, "ready": True,
             "notes": ["boat", None, False]}
    exact = {"pos": [witness(BINARY_VALUE), witness(16.0)], "coins": 3,
             "ready": True, "notes": ["boat", None, False]}
    return {
        "schema": "bluemap.world-access.source-oracle.v1",
        "unpaired": {"decimal": WINDOWS_DECIMAL},
        "sourceMethods": ["spawn_fits", "valid_source"],
        "snapshots": [{"map": "coast", "state": state, "stateExact": exact,
                       "arrivals": [{"resolved": [WINDOWS_DECIMAL, 16.0]}]}],
        "cases": [{"id": "boat_distance_6401", "initial": copy.deepcopy(state),
                   "initialExact": copy.deepcopy(exact),
                   "operation": {"position": [decimal], "kind": "boat"},
                   "operationExact": {"position": [witness(BINARY_VALUE)], "kind": "boat"},
                   "result": [False, decimal],
                   "resultExact": [False, witness(BINARY_VALUE)],
                   "expected": copy.deepcopy(state), "expectedExact": copy.deepcopy(exact)}],
    }


def comparison(document):
    return canonical_bytes(normalize_exact_mirrors(document))


def number_document(plain, exact):
    return {"snapshots": [{"state": {"number": plain},
                            "stateExact": {"number": exact}}], "cases": []}


class WorldAccessMirrorComparisonTests(unittest.TestCase):
    def test_both_os_halfway_spellings_compare_with_all_exact_bytes_preserved(self):
        windows, linux = fixture(), fixture(LINUX_DECIMAL)
        self.assertNotEqual(canonical_bytes(windows), canonical_bytes(linux))
        self.assertEqual(comparison(windows), comparison(linux))
        normalized = normalize_exact_mirrors(linux)
        self.assertEqual(normalized["snapshots"][0]["state"]["pos"][0], BINARY_VALUE)
        self.assertEqual(normalized["snapshots"][0]["stateExact"], windows["snapshots"][0]["stateExact"])
        for key in ("initial", "operation", "result", "expected"):
            self.assertEqual(normalized["cases"][0][key + "Exact"], windows["cases"][0][key + "Exact"])

    def test_real_frozen_oracle_and_exact_linux_regression_keep_reference_bytes(self):
        path = ROOT / "migration/phase-11/world-access-oracle.json"
        before = path.read_bytes()
        frozen = json.loads(before)
        linux = copy.deepcopy(frozen)
        case = next(row for row in linux["cases"] if row["id"] == "boat_distance_6401")
        for field in ("initial", "expected"):
            self.assertEqual(case[field]["pos"][0], WINDOWS_DECIMAL)
            case[field]["pos"][0] = LINUX_DECIMAL
        self.assertEqual(case["operation"]["playerPosition"][0], WINDOWS_DECIMAL)
        case["operation"]["playerPosition"][0] = LINUX_DECIMAL
        self.assertNotEqual(canonical_bytes(frozen), canonical_bytes(linux))
        self.assertEqual(comparison(frozen), comparison(linux))
        self.assertEqual(validate_float64_bits(frozen), 1584)
        self.assertEqual(path.read_bytes(), before)

    def test_normalization_is_a_deep_copy_including_witnesses_and_unpaired_values(self):
        original = fixture()
        before = canonical_bytes(original)
        result = normalize_exact_mirrors(original)
        self.assertNotEqual(canonical_bytes(result), before)
        result["snapshots"][0]["stateExact"]["pos"][0]["$f64"] = "changed"
        result["cases"][0]["initial"]["notes"].append("changed")
        result["unpaired"]["decimal"] = 0.0
        self.assertEqual(canonical_bytes(original), before)

    def test_single_bit_witness_change_remains_a_mismatch_with_same_legal_display(self):
        original = fixture()
        changed = copy.deepcopy(original)
        encoded = changed["snapshots"][0]["stateExact"]["pos"][0]
        bits = struct.unpack("<Q", bytes.fromhex(encoded["$f64"]))[0] ^ 1
        encoded["$f64"] = struct.pack("<Q", bits).hex()
        self.assertNotEqual(decode_float64_witness(encoded), BINARY_VALUE)
        # Both binary values legally print the same Windows decimal; the exact
        # witness, rather than a broad tolerance, must keep them different.
        normalized = normalize_exact_mirrors(changed)
        self.assertEqual(normalized["snapshots"][0]["stateExact"]["pos"][0], encoded)
        self.assertNotEqual(comparison(original), comparison(changed))

    def test_even_nearby_non_rendered_decimal_corruption_is_rejected(self):
        for decimal in (math.nextafter(WINDOWS_DECIMAL, math.inf),
                        math.nextafter(LINUX_DECIMAL, -math.inf),
                        BINARY_VALUE, 1424.01000976564, 1424.0):
            with self.subTest(decimal=decimal), self.assertRaises(ValueError):
                normalize_exact_mirrors(number_document(decimal, witness(BINARY_VALUE)))

    def test_non_halfway_value_cannot_choose_a_neighboring_display(self):
        self.assertEqual(comparison(number_document(0.1, witness(0.1))),
                         canonical_bytes(number_document(0.1, witness(0.1))))
        for decimal in (math.nextafter(0.1, math.inf), math.nextafter(0.1, -math.inf)):
            with self.subTest(decimal=decimal), self.assertRaises(ValueError):
                normalize_exact_mirrors(number_document(decimal, witness(0.1)))

    def test_negative_halfway_values_support_both_legal_os_renderings(self):
        left = number_document(-WINDOWS_DECIMAL, witness(-BINARY_VALUE))
        right = number_document(-LINUX_DECIMAL, witness(-BINARY_VALUE))
        self.assertEqual(comparison(left), comparison(right))
        self.assertEqual(normalize_exact_mirrors(left)["snapshots"][0]["state"]["number"], -BINARY_VALUE)

    def test_signed_zero_witnesses_are_not_erased(self):
        positive = number_document(0.0, witness(0.0))
        negative = number_document(-0.0, witness(-0.0))
        self.assertNotEqual(comparison(positive), comparison(negative))
        self.assertEqual(struct.pack("<d", decode_float64_witness(witness(-0.0))), b"\0" * 7 + b"\x80")

    def test_bool_integer_string_null_container_and_nonfinite_mirrors_rejected(self):
        for plain in (True, False, 1, "1.0", None, {}, [], math.nan, math.inf, -math.inf):
            with self.subTest(plain=plain), self.assertRaises(ValueError):
                normalize_exact_mirrors(number_document(plain, witness(1.0)))

    def test_witness_decoder_requires_exact_lowercase_hex_shape_and_finite_value(self):
        valid = witness(BINARY_VALUE)
        malformed = [None, [], valid["$f64"], {}, {"$f64": None}, {"$f64": 0},
                     {"$f64": True}, {"$f64": []}, {"$f64": ""},
                     {"$f64": valid["$f64"][:-1]}, {"$f64": valid["$f64"] + "00"},
                     {"$f64": "x" * 16}, {"$f64": valid["$f64"].upper()},
                     {"$f64": " " + valid["$f64"]}, {"$f64": valid["$f64"], "extra": 1},
                     witness(math.nan), witness(math.inf), witness(-math.inf)]
        for exact in malformed:
            with self.subTest(exact=exact), self.assertRaises(ValueError):
                decode_float64_witness(exact)
        self.assertEqual(decode_float64_witness(valid), BINARY_VALUE)

    def test_invalid_witnesses_rejected_inside_pairs_and_full_validation(self):
        for exact in ({"$f64": "0"}, {"$f64": "z" * 16}, witness(math.nan),
                      witness(math.inf), {**witness(1.0), "other": False}):
            with self.subTest(exact=exact), self.assertRaises(ValueError):
                normalize_exact_mirrors(number_document(1.0, exact))
            with self.subTest(exact=exact), self.assertRaises(ValueError):
                validate_float64_bits({"nested": [exact]})

    def test_bare_float_cannot_replace_exact_witness(self):
        with self.assertRaises(ValueError):
            normalize_exact_mirrors(number_document(1.0, 1.0))

    def test_paired_dictionary_and_array_shape_changes_rejected(self):
        variants = []
        value = fixture(); value["snapshots"][0]["state"].pop("coins"); variants.append(value)
        value = fixture(); value["snapshots"][0]["state"]["extra"] = 0; variants.append(value)
        value = fixture(); value["snapshots"][0]["stateExact"].pop("coins"); variants.append(value)
        value = fixture(); value["snapshots"][0]["stateExact"]["extra"] = 0; variants.append(value)
        value = fixture(); value["snapshots"][0]["state"]["pos"].pop(); variants.append(value)
        value = fixture(); value["snapshots"][0]["state"]["pos"].append(1.0); variants.append(value)
        value = fixture(); value["snapshots"][0]["state"]["pos"] = {}; variants.append(value)
        value = fixture(); value["cases"][0]["result"] = {"0": False, "1": WINDOWS_DECIMAL}; variants.append(value)
        for index, value in enumerate(variants):
            with self.subTest(index=index), self.assertRaises(ValueError):
                normalize_exact_mirrors(value)

    def test_non_float_pair_values_and_types_are_strict(self):
        for plain, exact in ((False, 0), (0, False), (True, 1), (1, True),
                             ("3", 3), (3, "3"), (None, ""), ("", None),
                             (3.0, 3), ("other", "boat")):
            value = fixture()
            value["snapshots"][0]["state"]["notes"][0] = plain
            value["snapshots"][0]["stateExact"]["notes"][0] = exact
            with self.subTest(plain=plain, exact=exact), self.assertRaises(ValueError):
                normalize_exact_mirrors(value)
        original, changed = fixture(), fixture()
        changed["snapshots"][0]["state"]["coins"] = 4
        changed["snapshots"][0]["stateExact"]["coins"] = 4
        self.assertNotEqual(comparison(original), comparison(changed))

    def test_every_required_pair_rejects_missing_plain_or_exact_half(self):
        for collection, fields in (("snapshots", ("state",)),
                                   ("cases", ("initial", "operation", "result", "expected"))):
            for field in fields:
                for missing in (field, field + "Exact"):
                    value = fixture()
                    value[collection][0].pop(missing)
                    with self.subTest(collection=collection, missing=missing), self.assertRaises(ValueError):
                        normalize_exact_mirrors(value)

    def test_collections_rows_and_top_level_structure_are_required(self):
        for value in (None, [], "oracle", 1, True):
            with self.subTest(value=value), self.assertRaises(ValueError):
                normalize_exact_mirrors(value)
        for collection in ("snapshots", "cases"):
            for invalid in (None, {}, "rows", 1, True):
                value = fixture(); value[collection] = invalid
                with self.subTest(collection=collection, invalid=invalid), self.assertRaises(ValueError):
                    normalize_exact_mirrors(value)
            value = fixture(); value.pop(collection)
            with self.subTest(collection=collection, missing=True), self.assertRaises(ValueError):
                normalize_exact_mirrors(value)
            for invalid in (None, [], "row", 1, True):
                value = fixture(); value[collection] = [invalid]
                with self.subTest(collection=collection, row=invalid), self.assertRaises(ValueError):
                    normalize_exact_mirrors(value)

    def test_unpaired_decimals_and_unknown_exact_suffixes_remain_strict(self):
        original = fixture()
        variants = []
        value = fixture(); value["unpaired"]["decimal"] = LINUX_DECIMAL; variants.append(value)
        value = fixture(); value["snapshots"][0]["arrivals"][0]["resolved"][0] = LINUX_DECIMAL; variants.append(value)
        value = fixture(); value["cases"][0]["unrelated"] = LINUX_DECIMAL; variants.append(value)
        for index, changed in enumerate(variants):
            with self.subTest(index=index):
                self.assertNotEqual(comparison(original), comparison(changed))
        for container in ("root", "snapshot", "case"):
            left, right = fixture(), fixture()
            for document, decimal in ((left, WINDOWS_DECIMAL), (right, LINUX_DECIMAL)):
                row = document if container == "root" else document["snapshots" if container == "snapshot" else "cases"][0]
                row["other"] = decimal
                row["otherExact"] = witness(BINARY_VALUE)
            with self.subTest(container=container):
                self.assertNotEqual(comparison(left), comparison(right))

    def test_unpaired_array_order_extra_fields_and_area_names_still_mismatch(self):
        original = fixture()
        variants = []
        value = fixture(); value["sourceMethods"].reverse(); variants.append(value)
        value = fixture(); value["newField"] = True; variants.append(value)
        value = fixture(); value["snapshots"][0]["map"] = "temple"; variants.append(value)
        for index, changed in enumerate(variants):
            with self.subTest(index=index):
                self.assertNotEqual(comparison(original), comparison(changed))


if __name__ == "__main__":
    unittest.main()