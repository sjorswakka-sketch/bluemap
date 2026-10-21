"""Independent adversarial guards for the original progression recorder and lossless catalogs."""
import copy
import json
from pathlib import Path
import struct
import sys
import unittest
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from record_migration_progression import (normalize_exact_mirrors, decode_ordered_input,
    decode_float64_witness, validate_float64_bits, validate_ordered_inputs)

def exact(value):
    if type(value) is float:return {"$f64":struct.pack("<d",value).hex()}
    if type(value) is dict:return {k:exact(v) for k,v in value.items()}
    if type(value) is list:return [exact(v) for v in value]
    return value

def ordered(value):
    if type(value) is dict:return {"$dict":[[k,ordered(v)] for k,v in value.items()]}
    if type(value) is list:return [ordered(v) for v in value]
    return exact(value)

def fixture():
    row={"id":"guard","initial":{"gear":{"z":1,"a":2},"clock":0.15,"future":9007199254740993},"operations":[["bonus","move_speed"]],"results":[0.12],"expected":{"gear":{"z":1,"a":2},"clock":0.15,"future":9007199254740993}}
    for key in ["initial","operations","results","expected"]:row[key+"Exact"]=exact(row[key])
    for key in ["initial","operations"]:row[key+"Ordered"]=ordered(row[key])
    catalogs={"hairColors":[{"name":"test","color":[0.15,0.25,0.75,1.0]}],"gear":{"z":{},"a":{}}}
    return {"float64Encoding":"ieee754-binary64-little-endian-hex","orderedInputEncoding":"dictionary-pairs-and-exact-f64-v1","catalogs":catalogs,"catalogsExact":exact(catalogs),"catalogsOrdered":ordered(catalogs),"cases":[row]}

class ProgressionOracleGuards(unittest.TestCase):
    def test_valid_lossless_reference(self):self.assertTrue(validate_ordered_inputs(fixture()))
    def test_catalog_original_order_survives_sorted_json(self):
        data=json.loads(json.dumps(fixture(),sort_keys=True));validate_ordered_inputs(data)
        self.assertEqual(list(decode_ordered_input(data["catalogsOrdered"])["gear"]),["z","a"])
    def test_case_input_original_order_survives_sorted_json(self):
        data=json.loads(json.dumps(fixture(),sort_keys=True));validate_ordered_inputs(data)
        self.assertEqual(list(decode_ordered_input(data["cases"][0]["initialOrdered"])["gear"]),["z","a"])
    def test_large_integer_never_rounds_to_double(self):
        result=normalize_exact_mirrors(fixture())["cases"][0]["initial"]["future"]
        self.assertEqual(result,9007199254740993);self.assertIs(type(result),int)
    def test_missing_float_encoding_rejected(self):
        data=fixture();del data["float64Encoding"]
        with self.assertRaises(ValueError):normalize_exact_mirrors(data)
    def test_catalog_decimal_tamper_rejected(self):
        data=fixture();data["catalogs"]["hairColors"][0]["color"][0]=0.16
        with self.assertRaises(ValueError):normalize_exact_mirrors(data)
    def test_catalog_binary_tamper_rejected(self):
        data=fixture();data["catalogsExact"]["hairColors"][0]["color"][0]=exact(0.16)
        with self.assertRaises(ValueError):normalize_exact_mirrors(data)
    def test_catalog_ordered_value_tamper_rejected(self):
        data=fixture();data["catalogsOrdered"]["$dict"][1][1]["$dict"][0][0]="changed"
        with self.assertRaises(ValueError):normalize_exact_mirrors(data)
    def test_catalog_duplicate_key_rejected(self):
        data=fixture();data["catalogsOrdered"]["$dict"].append(data["catalogsOrdered"]["$dict"][0])
        with self.assertRaises(ValueError):normalize_exact_mirrors(data)
    def test_case_decimal_tamper_rejected(self):
        data=fixture();data["cases"][0]["results"][0]=0.13
        with self.assertRaises(ValueError):normalize_exact_mirrors(data)
    def test_case_boolean_integer_confusion_rejected(self):
        data=fixture();data["cases"][0]["initial"]["gear"]["z"]=True
        with self.assertRaises(ValueError):normalize_exact_mirrors(data)
    def test_unknown_case_field_cannot_disappear(self):
        data=fixture();del data["cases"][0]["expected"]["future"]
        with self.assertRaises(ValueError):normalize_exact_mirrors(data)
    def test_lossy_ordered_float_is_rejected(self):
        data=fixture();data["cases"][0]["initialOrdered"]["$dict"][1][1]=0.15
        with self.assertRaises(ValueError):normalize_exact_mirrors(data)
    def test_missing_ordered_input_rejected(self):
        data=fixture();del data["cases"][0]["operationsOrdered"]
        with self.assertRaises(ValueError):normalize_exact_mirrors(data)
    def test_nonfinite_binary_witness_rejected(self):
        with self.assertRaises(ValueError):decode_float64_witness({"$f64":struct.pack("<d",float("nan")).hex()})
    def test_malformed_binary_witness_rejected(self):
        with self.assertRaises(ValueError):validate_float64_bits({"$f64":"00"})
    def test_unknown_binary_tag_cannot_hide_fields(self):
        with self.assertRaises(ValueError):decode_ordered_input({"$f64":"0000000000000000","future":1})
    def test_catalog_input_numbers_match_exact_bytes(self):
        data=fixture();result=normalize_exact_mirrors(data)
        self.assertEqual(struct.pack("<d",result["catalogs"]["hairColors"][0]["color"][0]),bytes.fromhex(data["catalogsExact"]["hairColors"][0]["color"][0]["$f64"]))

if __name__=="__main__":unittest.main()
