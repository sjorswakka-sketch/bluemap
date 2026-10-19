#!/usr/bin/env python3
"""Data-only, lossless transport for phase-1 inventory-shaped Variant values.

This codec neither imports Godot nor constructs/loads engine resources. It retains
the inventory's available type information; StringName versus String and any
precision already lost before the inventory was written cannot be recovered.
Dictionary order is represented by entry arrays, never JSON object key order.

Transport node shapes (all fields are required and extra fields reject):
  {"kind":"nil"}
  {"kind":"bool","value":true|false}
  {"kind":"int","value":"canonical decimal integer"}
  {"kind":"float","value":"Python repr of finite IEEE-754 binary64"}
  {"kind":"string","value":"UTF-8 text"}
  {"kind":"array","values":[node,...]}
  {"kind":"dictionary","entries":[[key_node,value_node],...]}
  {"kind":"variant","tag":"known $type","fields":[[field_name,node],...]}
Dictionary key nodes are string or int. Variant fields include the original
$type field and retain its position; its string must equal the tag discriminator.
The inventory's tagged Dictionary uses a variant node with its original ordered
entries array, allowing Vector2i and other explicitly typed keys without casting.
No discriminator is inferred from an ordinary unknown field name.

Only reference-inventory order can be retained: phase 1 sorted ordinary object
keys before saving JSON, so original Godot dictionary iteration order is already
unavailable there. Declaration ids arrays still record their authored ordering.
JSON/int/float information is preserved as it exists in the reference; this is
not a claim to reconstruct type or precision information the exporter discarded.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import re


MAX_DEPTH = 64
MAX_NODES = 2_000_000
MAX_STRING = 1_000_000
MAX_INTEGER_DIGITS = 128
MAX_JSON_BYTES = 128 * 1024 * 1024
INT_TEXT = re.compile(r"(?:0|-[1-9][0-9]*|[1-9][0-9]*)\Z")
VECTOR_DIMENSIONS = {"Vector2": 2, "Vector2i": 2, "Vector3": 3, "Vector3i": 3,
                     "Vector4": 4, "Vector4i": 4}
PACKED_TYPES = {"PackedByteArray", "PackedInt32Array", "PackedInt64Array", "PackedFloat32Array",
                "PackedFloat64Array", "PackedStringArray", "PackedVector2Array", "PackedVector3Array",
                "PackedVector4Array", "PackedColorArray"}
RESOURCE_TYPES = {"Resource", "Script", "GDScript", "PackedScene", "Texture2D", "CompressedTexture2D",
                  "ImageTexture", "AudioStreamWAV", "AudioStreamOggVorbis", "AudioStreamMP3",
                  "FontFile", "FontVariation", "Shader"}
TAGS = set(VECTOR_DIMENSIONS) | PACKED_TYPES | RESOURCE_TYPES | {"Rect2", "Rect2i", "Color",
                                                              "Transform2D", "Dictionary"}


class CodecError(ValueError):
    """Invalid, unsupported or ambiguous inventory/transport data."""


def _require(condition, message):
    if not condition:
        raise CodecError(message)


def _string(value):
    _require(type(value) is str and len(value) <= MAX_STRING, "Expected a bounded string")
    try:
        value.encode("utf-8")
    except UnicodeError as error:
        raise CodecError("String contains an invalid Unicode surrogate") from error
    return value


def _number(value, integer=False, bits=None):
    _require(type(value) is int if integer else type(value) in (int, float), "Expected numeric component; bool is not a number")
    if type(value) is float:
        _require(math.isfinite(value), "Non-finite number")
    if bits is not None:
        _require(-(2 ** (bits - 1)) <= value < 2 ** (bits - 1), "Integer component outside its declared range")


def _shape(value, fields):
    _require(type(value) is dict and set(value) == set(fields), "Invalid object shape; required fields: " + ", ".join(fields))


def _key_identity(value):
    """Typed key identity, independent of object-field insertion order."""
    if value is None:
        return ["nil"]
    if type(value) is bool:
        return ["bool", value]
    if type(value) is int:
        return ["int", str(value)]
    if type(value) is float:
        return ["float", repr(0.0 if value == 0.0 else value)]
    if type(value) is str:
        return ["string", value]
    if type(value) is list:
        return ["array", [_key_identity(item) for item in value]]
    if type(value) is dict:
        entries = [[_key_identity(key), _key_identity(item)] for key, item in value.items()]
        entries.sort(key=lambda item: canonical_bytes(item[0]))
        return ["object", entries]
    raise CodecError("Unsupported dictionary key type")


def _unique_keys(entries):
    seen = set()
    for key, _ in entries:
        identity = canonical_bytes(_key_identity(key))
        _require(identity not in seen, "Duplicate typed dictionary key")
        seen.add(identity)


def _validate_tag(value):
    tag = value.get("$type")
    _require(type(tag) is str and tag in TAGS, f"Unsupported inventory $type: {tag!r}")
    if tag in VECTOR_DIMENSIONS:
        _shape(value, ("$type", "value"))
        components = value["value"]
        _require(type(components) is list and len(components) == VECTOR_DIMENSIONS[tag], "Wrong vector dimension")
        for item in components:
            _number(item, integer=tag.endswith("i"), bits=32 if tag.endswith("i") else None)
    elif tag in {"Rect2", "Rect2i"}:
        _shape(value, ("$type", "position", "size"))
        vector = "Vector2i" if tag.endswith("i") else "Vector2"
        for name in ("position", "size"):
            _require(type(value[name]) is dict and value[name].get("$type") == vector, "Rect components require the matching vector type")
    elif tag == "Color":
        _shape(value, ("$type", "rgba"))
        _require(type(value["rgba"]) is list and len(value["rgba"]) == 4, "Color needs four components")
        for item in value["rgba"]:
            _number(item)
    elif tag == "Transform2D":
        _shape(value, ("$type", "x", "y", "origin"))
        for name in ("x", "y", "origin"):
            _require(type(value[name]) is dict and value[name].get("$type") == "Vector2", "Transform2D requires Vector2 components")
    elif tag == "Dictionary":
        _shape(value, ("$type", "entries"))
        entries = value["entries"]
        _require(type(entries) is list and all(type(pair) is list and len(pair) == 2 for pair in entries),
                 "Dictionary entries must be ordered key/value pairs")
        _unique_keys(entries)
    elif tag in RESOURCE_TYPES:
        _shape(value, ("$type", "path"))
        path = _string(value["path"])
        _require(path == "" or path.startswith(("res://", "uid://")), "Resource reference needs res:// or uid://; it is never loaded")
    elif tag in PACKED_TYPES:
        _shape(value, ("$type", "values"))
        values = value["values"]
        _require(type(values) is list, "Packed array values must be an array")
        for item in values:
            if tag == "PackedByteArray":
                _number(item, integer=True)
                _require(0 <= item <= 255, "Packed byte outside 0..255")
            elif tag in {"PackedInt32Array", "PackedInt64Array"}:
                _number(item, integer=True, bits=32 if tag == "PackedInt32Array" else 64)
            elif tag in {"PackedFloat32Array", "PackedFloat64Array"}:
                _number(item)
            elif tag == "PackedStringArray":
                _string(item)
            else:
                expected = {"PackedVector2Array": "Vector2", "PackedVector3Array": "Vector3",
                            "PackedVector4Array": "Vector4", "PackedColorArray": "Color"}[tag]
                _require(type(item) is dict and item.get("$type") == expected, "Packed array element has wrong Variant type")


class _Budget:
    def __init__(self):
        self.nodes = 0
        self.active = set()

    def enter(self, value, depth):
        self.nodes += 1
        _require(depth <= MAX_DEPTH and self.nodes <= MAX_NODES, "Codec depth or node limit exceeded")
        if type(value) in (dict, list):
            identity = id(value)
            _require(identity not in self.active, "Cyclic data cannot be transported")
            self.active.add(identity)

    def leave(self, value):
        if type(value) in (dict, list):
            self.active.remove(id(value))


def encode(value):
    """Encode inventory-shaped JSON/Variant data into typed plain JSON nodes."""
    budget = _Budget()

    def visit(item, depth):
        budget.enter(item, depth)
        try:
            if item is None:
                return {"kind": "nil"}
            if type(item) is bool:
                return {"kind": "bool", "value": item}
            if type(item) is int:
                _require(item.bit_length() <= MAX_INTEGER_DIGITS * 4, "Integer digit limit exceeded")
                text = str(item)
                _require(len(text.lstrip("-")) <= MAX_INTEGER_DIGITS, "Integer digit limit exceeded")
                return {"kind": "int", "value": text}
            if type(item) is float:
                _number(item)
                return {"kind": "float", "value": repr(item)}
            if type(item) is str:
                return {"kind": "string", "value": _string(item)}
            if type(item) is list:
                return {"kind": "array", "values": [visit(child, depth + 1) for child in item]}
            if type(item) is dict:
                if "$type" in item:
                    tag = item["$type"]
                    _require(type(tag) is str and tag in TAGS, f"Unsupported inventory $type: {tag!r}")
                    fields = [[_string(key), visit(child, depth + 1)] for key, child in item.items()]
                    _validate_tag(item)
                    return {"kind": "variant", "tag": tag, "fields": fields}
                entries = []
                for key, child in item.items():
                    _require(type(key) in (str, int), "Plain dictionary keys must be string or integer; bool is not int")
                    entries.append([visit(key, depth + 1), visit(child, depth + 1)])
                return {"kind": "dictionary", "entries": entries}
            raise CodecError(f"Unsupported Python value type: {type(item).__name__}")
        finally:
            budget.leave(item)

    return visit(value, 0)


def decode(node):
    """Decode typed nodes to the exact inventory-shaped value, without execution."""
    budget = _Budget()

    def visit(item, depth):
        budget.enter(item, depth)
        try:
            _require(type(item) is dict and type(item.get("kind")) is str, "Typed node needs a kind discriminator")
            kind = item["kind"]
            if kind == "nil":
                _shape(item, ("kind",))
                return None
            if kind in {"bool", "int", "float", "string"}:
                _shape(item, ("kind", "value"))
                value = item["value"]
                if kind == "bool":
                    _require(type(value) is bool, "Boolean node needs true or false")
                elif kind == "int":
                    _require(type(value) is str and len(value.lstrip("-")) <= MAX_INTEGER_DIGITS
                             and INT_TEXT.fullmatch(value) is not None, "Integer node needs canonical decimal text")
                    value = int(value)
                elif kind == "float":
                    _require(type(value) is str and len(value) <= 64, "Float node needs bounded decimal text")
                    try:
                        number = float(value)
                    except ValueError as error:
                        raise CodecError("Invalid float text") from error
                    _require(math.isfinite(number) and repr(number) == value, "Float text must be finite and canonical")
                    value = number
                else:
                    _string(value)
                return value
            if kind == "array":
                _shape(item, ("kind", "values"))
                _require(type(item["values"]) is list, "Array node needs ordered values")
                return [visit(child, depth + 1) for child in item["values"]]
            if kind == "dictionary":
                _shape(item, ("kind", "entries"))
                entries = item["entries"]
                _require(type(entries) is list, "Dictionary node needs ordered entries")
                result = {}
                for pair in entries:
                    _require(type(pair) is list and len(pair) == 2, "Dictionary node entry must be a key/value pair")
                    key, value = visit(pair[0], depth + 1), visit(pair[1], depth + 1)
                    _require(type(key) in (str, int), "Plain dictionary keys must be string or integer; bool is not int")
                    _require(key not in result, "Duplicate typed dictionary key")
                    result[key] = value
                _require("$type" not in result, "Tagged inventory object requires a variant node")
                return result
            if kind == "variant":
                _shape(item, ("kind", "tag", "fields"))
                tag = item["tag"]
                _require(type(tag) is str and tag in TAGS, f"Unsupported inventory $type: {tag!r}")
                fields = item["fields"]
                _require(type(fields) is list, "Variant fields must be ordered pairs")
                result = {}
                for pair in fields:
                    _require(type(pair) is list and len(pair) == 2, "Variant field must be a name/value pair")
                    key = _string(pair[0])
                    _require(key not in result, "Duplicate Variant field")
                    result[key] = visit(pair[1], depth + 1)
                _require(result.get("$type") == tag, "Variant discriminator and $type differ")
                _validate_tag(result)
                return result
            raise CodecError(f"Unknown typed node kind: {kind!r}")
        finally:
            budget.leave(item)

    return visit(node, 0)


def canonical_bytes(value):
    """Deterministic UTF-8 plain JSON (sorted object keys, two spaces, newline)."""
    try:
        return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + "\n").encode("utf-8")
    except (TypeError, ValueError, UnicodeError, RecursionError) as error:
        raise CodecError("Value cannot be represented as finite canonical JSON") from error


def _json_pairs(pairs):
    value = {}
    for key, child in pairs:
        _require(key not in value, f"Duplicate JSON object key: {key!r}")
        value[key] = child
    return value


def _json_constant(value):
    raise CodecError(f"Non-finite JSON number: {value}")


def json_read(path):
    """Read strict JSON; no duplicate keys, non-finite numbers or resource loads."""
    path = Path(path)
    _require(path.stat().st_size <= MAX_JSON_BYTES, "JSON file size limit exceeded")
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=_json_pairs,
                           parse_constant=_json_constant)
    except (ValueError, UnicodeError, RecursionError) as error:
        if isinstance(error, CodecError):
            raise
        raise CodecError("Invalid JSON") from error
    # json.loads accepts an overflowing exponent as infinity; encode rejects it
    # as well as invalid Unicode, unsupported tags, depth and integer limits.
    encode(value)
    return value
