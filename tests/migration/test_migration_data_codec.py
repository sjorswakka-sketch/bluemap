"""Codec invariants and all frozen inventory values; no actual game/save run."""
import importlib.util
import json
import math
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("migration_data_codec", ROOT / "tools/migration_data_codec.py")
codec = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(codec)


def exact(value):
    """Order and Python numeric type matter; Python's ordinary == hides both."""
    if type(value) is dict:
        return (dict, tuple((exact(key), exact(child)) for key, child in value.items()))
    if type(value) is list:
        return (list, tuple(exact(child) for child in value))
    if type(value) is float:
        return (float, value.hex())
    return (type(value), value)


class CodecRoundTripTests(unittest.TestCase):
    def roundtrip(self, value):
        encoded = codec.encode(value)
        transported = json.loads(codec.canonical_bytes(encoded))
        self.assertEqual(exact(codec.decode(transported)), exact(value))
        return encoded

    def test_scalar_types_large_integers_negative_zero_and_unicode(self):
        self.roundtrip([None, False, True, 0, 1, -7, 2 ** 63 - 1, 2 ** 80,
                        0.0, -0.0, 1.0, 1.2345678901234567, 1e-200, "héél 🍇"])

    def test_plain_dictionary_order_string_and_integer_keys_and_unknown_fields(self):
        self.roundtrip({"z": {"future_custom_rule": ["do not drop", 5]}, 7: "int key", "7": "string key", "a": []})

    def test_tag_fields_keep_original_order(self):
        self.roundtrip({"value": [2, 3], "$type": "Vector2i"})

    def test_integer_and_string_typed_dictionary_keys_remain_different(self):
        self.roundtrip({"$type": "Dictionary", "entries": [[7, "integer"], ["7", "string"],
                        [{"$type": "Vector2i", "value": [1, 2]}, "coordinate"]]})

    def test_vectors_rects_color_transform_and_resources_are_data(self):
        for tag, dimension in codec.VECTOR_DIMENSIONS.items():
            self.roundtrip({"$type": tag, "value": list(range(dimension))})
        for tag, vector in [("Rect2", "Vector2"), ("Rect2i", "Vector2i")]:
            self.roundtrip({"$type": tag, "position": {"$type": vector, "value": [0, 1]},
                            "size": {"$type": vector, "value": [2, 3]}})
        self.roundtrip({"$type": "Color", "rgba": [0.1, 1.0, 2.0, 0.5]})
        self.roundtrip({"$type": "Transform2D", **{key: {"$type": "Vector2", "value": [1.0, 0.0]}
                                                   for key in ("x", "y", "origin")}})
        for tag in codec.RESOURCE_TYPES:
            self.roundtrip({"$type": tag, "path": "res://never_loaded.tres"})

    def test_every_packed_array_kind(self):
        examples = {"PackedByteArray": [0, 255], "PackedInt32Array": [-2 ** 31, 2 ** 31 - 1],
                    "PackedInt64Array": [-2 ** 63, 2 ** 63 - 1], "PackedFloat32Array": [0.1, 2.0],
                    "PackedFloat64Array": [-0.0, 1e200], "PackedStringArray": ["zaad", "🌷"]}
        for dimension in (2, 3, 4):
            examples[f"PackedVector{dimension}Array"] = [{"$type": f"Vector{dimension}", "value": [1.0] * dimension}]
        examples["PackedColorArray"] = [{"$type": "Color", "rgba": [1.0, 0.0, 0.0, 1.0]}]
        self.assertEqual(set(examples), codec.PACKED_TYPES)
        for tag, values in examples.items():
            self.roundtrip({"$type": tag, "values": values})

    def test_all_frozen_content_and_map_inventory_values_roundtrip(self):
        for name in ("content-inventory.json", "maps-inventory.json"):
            with self.subTest(inventory=name):
                value = codec.json_read(ROOT / "migration/reference" / name)
                self.roundtrip(value)

    def test_canonical_bytes_are_utf8_and_repeatable(self):
        self.assertEqual(codec.canonical_bytes({"z": "é", "a": 1}), b'{\n  "a": 1,\n  "z": "\xc3\xa9"\n}\n')
        value = {"b": ["ordered", "array"], "a": 1}
        self.assertEqual(codec.canonical_bytes(codec.encode(value)), codec.canonical_bytes(codec.encode(value)))


class CodecRejectionTests(unittest.TestCase):
    def test_unknown_tag_and_unknown_node_kind_reject_visibly(self):
        with self.assertRaisesRegex(codec.CodecError, "Unsupported inventory"):
            codec.encode({"$type": "FutureScript", "path": "res://danger.gd"})
        with self.assertRaisesRegex(codec.CodecError, "Unknown typed node"):
            codec.decode({"kind": "execute", "value": "anything"})

    def test_bool_is_not_integer_or_numeric_vector_component(self):
        for value in [{True: "ambiguous"}, {"$type": "Vector2i", "value": [True, 2]},
                      {"$type": "Color", "rgba": [False, 0.0, 0.0, 1.0]}]:
            with self.subTest(value=value), self.assertRaises(codec.CodecError):
                codec.encode(value)

    def test_malformed_tag_shapes_do_not_silently_drop_fields(self):
        for value in [{"$type": "Vector2", "value": [1.0]},
                      {"$type": "Vector2i", "value": [1, 2], "extra": "unknown"},
                      {"$type": "Color", "rgba": [0, 0, 0]},
                      {"$type": "Rect2", "position": {"$type": "Vector2i", "value": [1, 2]},
                       "size": {"$type": "Vector2", "value": [1, 2]}}]:
            with self.subTest(value=value), self.assertRaises(codec.CodecError):
                codec.encode(value)

    def test_duplicate_typed_dictionary_keys_reject_even_if_field_order_differs(self):
        for entries in [[[1, "first"], [1, "duplicate"]],
                        [[{"$type": "Vector2i", "value": [1, 2]}, "first"],
                         [{"value": [1, 2], "$type": "Vector2i"}, "duplicate"]]]:
            with self.subTest(entries=entries), self.assertRaisesRegex(codec.CodecError, "Duplicate typed"):
                codec.encode({"$type": "Dictionary", "entries": entries})

    def test_decoded_dictionary_rejects_duplicate_keys(self):
        pair = [codec.encode("a"), codec.encode(1)]
        with self.assertRaisesRegex(codec.CodecError, "Duplicate typed"):
            codec.decode({"kind": "dictionary", "entries": [pair, pair]})

    def test_nonfinite_and_unsupported_python_objects_reject(self):
        for value in [math.nan, math.inf, -math.inf, {"bad": math.inf}, object(), (1, 2)]:
            with self.subTest(type=type(value)), self.assertRaises(codec.CodecError):
                codec.encode(value)

    def test_integer_and_float_text_are_strict_and_different(self):
        for value in [True, 7, "01", "+1", "-0", "1.0", "1e3", "9" * 129]:
            with self.subTest(value=value), self.assertRaises(codec.CodecError):
                codec.decode({"kind": "int", "value": value})
        for value in [True, 1.0, "1", "NaN", "Infinity", "1e309", " 1.0 "]:
            with self.subTest(value=value), self.assertRaises(codec.CodecError):
                codec.decode({"kind": "float", "value": value})

    def test_extra_node_fields_and_conflicting_variant_discriminator_reject(self):
        with self.assertRaises(codec.CodecError):
            codec.decode({"kind": "int", "value": "1", "ignored": True})
        value = codec.encode({"$type": "Vector2i", "value": [1, 2]})
        value["tag"] = "Vector2"
        with self.assertRaisesRegex(codec.CodecError, "differ"):
            codec.decode(value)

    def test_typed_object_cannot_bypass_variant_validation_as_plain_dictionary(self):
        with self.assertRaisesRegex(codec.CodecError, "requires a variant"):
            codec.decode({"kind": "dictionary", "entries": [[codec.encode("$type"), codec.encode("FutureType")]]})

    def test_invalid_packed_element_ranges_and_types_reject(self):
        for tag, values in [("PackedByteArray", [256]), ("PackedInt32Array", [2 ** 31]),
                            ("PackedInt64Array", [2 ** 63]), ("PackedStringArray", [1]),
                            ("PackedVector2Array", [{"$type": "Vector3", "value": [1, 2, 3]}])]:
            with self.subTest(tag=tag), self.assertRaises(codec.CodecError):
                codec.encode({"$type": tag, "values": values})

    def test_resource_reference_never_accepts_filesystem_or_http_loading(self):
        for path in ["C:/private/file", "../../private", "https://example.com/script"]:
            with self.subTest(path=path), self.assertRaises(codec.CodecError):
                codec.encode({"$type": "GDScript", "path": path})

    def test_cycles_and_excessive_depth_reject(self):
        cycle = []
        cycle.append(cycle)
        with self.assertRaisesRegex(codec.CodecError, "Cyclic"):
            codec.encode(cycle)
        node = []
        for _ in range(codec.MAX_DEPTH + 1):
            node = [node]
        with self.assertRaisesRegex(codec.CodecError, "limit"):
            codec.encode(node)
        cyclic_node = {"kind": "array", "values": []}
        cyclic_node["values"].append(cyclic_node)
        with self.assertRaisesRegex(codec.CodecError, "Cyclic"):
            codec.decode(cyclic_node)

    def test_strict_json_reader_rejects_duplicates_nonfinite_and_overflow(self):
        with tempfile.TemporaryDirectory(prefix="bluemap-codec-fixture-") as directory:
            path = Path(directory) / "fixture.json"
            for text in ['{"a":1,"a":2}', '[NaN]', '[Infinity]', '[1e309]', '{"a":{"z":0,"z":1}}']:
                with self.subTest(text=text), self.assertRaises(codec.CodecError):
                    path.write_text(text, encoding="utf-8")
                    codec.json_read(path)

    def test_invalid_unicode_surrogate_rejects(self):
        with self.assertRaises(codec.CodecError):
            codec.encode("\ud800")


if __name__ == "__main__":
    unittest.main()
