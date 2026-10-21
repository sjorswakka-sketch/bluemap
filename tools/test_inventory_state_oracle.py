"""Independent lossless-input and exact-number guards for the inventory source recorder."""
import copy
import json
from pathlib import Path
import struct
import unittest

from record_migration_inventory_state import (
    decode_ordered_input, normalize_exact_mirrors, validate_float64_bits,
    validate_ordered_inputs,
)


def exact(value):
    if type(value) is float:
        return {'$f64': struct.pack('<d', value).hex()}
    if type(value) is dict:
        return {key: exact(child) for key, child in value.items()}
    if type(value) is list:
        return [exact(child) for child in value]
    return value


def ordered(value):
    if type(value) is dict:
        return {'$dict': [[key, ordered(child)] for key, child in value.items()]}
    if type(value) is list:
        return [ordered(child) for child in value]
    return exact(value)


def fixture():
    row = {'id': 'synthetic_guard', 'initial': {'bag': {'z': 2, 'a': 1}, 'clock': 0.15},
           'operations': [['ids', {'z': 2, 'a': 1}]], 'results': [['z', 'a']],
           'expected': {'bag': {'z': 2, 'a': 1}, 'clock': 0.15}}
    for field in ('initial', 'operations', 'results', 'expected'):
        row[field + 'Exact'] = exact(row[field])
    for field in ('initial', 'operations'):
        row[field + 'Ordered'] = ordered(row[field])
    return {'orderedInputEncoding': 'dictionary-pairs-and-exact-f64-v1', 'cases': [row]}


class InventoryExactInputTests(unittest.TestCase):
    def test_canonical_json_does_not_erase_source_dictionary_order(self):
        data = json.loads(json.dumps(fixture(), sort_keys=True))
        self.assertTrue(validate_ordered_inputs(data))
        original = decode_ordered_input(data['cases'][0]['initialOrdered'])
        self.assertEqual(list(original['bag']), ['z', 'a'])
        self.assertEqual(list(data['cases'][0]['initial']['bag']), ['a', 'z'])

    def test_large_integer_remains_an_integer(self):
        value = {'bag': 9007199254740993}
        self.assertEqual(decode_ordered_input(ordered(value)), value)
        self.assertIs(type(decode_ordered_input(ordered(value))['bag']), int)

    def test_literal_reserved_keys_round_trip_as_data(self):
        value = {'$dict': [['$f64', 'mod-data']], 'kind': 'future_mod'}
        self.assertEqual(decode_ordered_input(ordered(value)), value)

    def test_negative_zero_retains_exact_bits(self):
        decoded = decode_ordered_input(exact(-0.0))
        self.assertEqual(struct.pack('<d', decoded), bytes.fromhex('0000000000000080'))

    def test_duplicate_ordered_key_is_rejected(self):
        with self.assertRaises(ValueError):
            decode_ordered_input({'$dict': [['a', 1], ['a', 2]]})

    def test_unwrapped_float_is_rejected(self):
        with self.assertRaises(ValueError):
            decode_ordered_input({'$dict': [['a', 0.15]]})

    def test_arbitrary_wrapper_is_rejected(self):
        for value in ({'$dict': [], 'extra': 1}, {'kind': 'dictionary'}, {'$dict': 'bad'}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                decode_ordered_input(value)

    def test_nonfinite_f64_is_rejected(self):
        with self.assertRaises(ValueError):
            decode_ordered_input({'$f64': struct.pack('<d', float('nan')).hex()})

    def test_boolean_does_not_alias_integer(self):
        data = fixture()
        data['cases'][0]['initialExact']['bag']['z'] = True
        with self.assertRaises(ValueError):
            normalize_exact_mirrors(data)

    def test_missing_ordered_input_is_rejected(self):
        data = fixture()
        del data['cases'][0]['operationsOrdered']
        with self.assertRaises(ValueError):
            normalize_exact_mirrors(data)

    def test_ordered_values_must_match_the_exact_source_mirror(self):
        data = fixture()
        data['cases'][0]['initialOrdered']['$dict'][0][1]['$dict'][0][1] = 99
        with self.assertRaises(ValueError):
            normalize_exact_mirrors(data)

    def test_wrong_decimal_mirror_is_rejected(self):
        data = fixture()
        data['cases'][0]['initial']['clock'] = 0.15000001
        with self.assertRaises(ValueError):
            normalize_exact_mirrors(data)

    def test_all_f64_witnesses_are_counted_and_validated(self):
        data = fixture()
        self.assertEqual(validate_float64_bits(data), 3)
        self.assertEqual(normalize_exact_mirrors(data)['cases'][0]['initial']['clock'], 0.15)


if __name__ == '__main__':
    unittest.main()
