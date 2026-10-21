"""Focused guard for encounter source witnesses, including Godot's signed-zero JSON mirror."""
import copy
import importlib.util
import json
from pathlib import Path
import struct
import sys
import unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from record_migration_encounter import normalize_exact_mirrors
from migration_data_codec import canonical_bytes
class EncounterMirrorTests(unittest.TestCase):
 def fixture(self):
  case={'id':'zero','initial':{'value':0.0},'initialExact':{'value':{'$f64':'0000000000000080'}},'initialOrdered':{'$dict':[['value',{'$f64':'0000000000000080'}]]},'operations':[],'operationsExact':[],'operationsOrdered':[],'results':[],'resultsExact':[],'expected':{},'expectedExact':{},'fixture':{},'fixtureExact':{},'fixtureOrdered':{'$dict':[]}}
  return {'float64Encoding':'ieee754-binary64-little-endian-hex','orderedInputEncoding':'dictionary-pairs-and-exact-f64-v1','catalogs':{},'catalogsExact':{},'catalogsOrdered':{'$dict':[]},'cases':[case]}
 def test_godot_zero_rendering_keeps_negative_witness(self):
  d=normalize_exact_mirrors(self.fixture());self.assertEqual(struct.pack('<d',d['cases'][0]['initial']['value']).hex(),'0000000000000080')
 def test_changed_zero_witness_changes_exact_comparison(self):
  a=self.fixture();b=copy.deepcopy(a);b['cases'][0]['initialExact']['value']['$f64']='0000000000000000';b['cases'][0]['initialOrdered']['$dict'][0][1]['$f64']='0000000000000000'
  self.assertNotEqual(canonical_bytes(normalize_exact_mirrors(a)),canonical_bytes(normalize_exact_mirrors(b)))
 def test_nonzero_plain_is_never_repaired(self):
  d=self.fixture();d['cases'][0]['initial']['value']=0.001
  with self.assertRaises(ValueError):normalize_exact_mirrors(d)
 def test_subnormal_witness_is_never_zero_repaired(self):
  d=self.fixture();d['cases'][0]['initialExact']['value']['$f64']='0100000000000000'
  with self.assertRaises(ValueError):normalize_exact_mirrors(d)
 def test_invalid_witness_wrapper_rejected(self):
  d=self.fixture();d['cases'][0]['initialExact']['value']['extra']=True
  with self.assertRaises(ValueError):normalize_exact_mirrors(d)
 def test_fixture_witness_is_validated(self):
  d=self.fixture();d['cases'][0]['fixture']={'x':1.0};d['cases'][0]['fixtureExact']={'x':{'$f64':'0000000000000040'}}
  with self.assertRaises(ValueError):normalize_exact_mirrors(d)
if __name__=='__main__':unittest.main()
