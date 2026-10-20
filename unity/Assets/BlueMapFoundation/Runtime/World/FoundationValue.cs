using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace BlueMapMigration.Foundation
{
    // Immutable values retain ordered, typed dictionary keys. Engine references remain data.
    public sealed class FoundationValue
    {
        private readonly string text;
        private readonly bool boolean;
        private readonly IReadOnlyList<FoundationValue> items;
        private readonly IReadOnlyList<KeyValuePair<FoundationValue, FoundationValue>> entries;
        internal readonly FoundationValue Raw;
        public string Kind { get; }
        public string Tag { get; }
        public string String => AsString();
        public long Int64 => AsInt64();
        public double Double => AsDouble();
        public ulong DoubleBits => unchecked((ulong)BitConverter.DoubleToInt64Bits(AsDouble()));
        public bool Bool => AsBool();
        public IReadOnlyList<FoundationValue> Items => items;
        public IReadOnlyList<KeyValuePair<FoundationValue, FoundationValue>> Entries => entries;
        public string CanonicalJson => FoundationJson.Serialize(Raw ?? this);
        internal string Scalar => text;
        internal bool BooleanScalar => boolean;
        internal FoundationValue(string kind, string scalar = null, bool flag = false,
            IList<FoundationValue> list = null, IList<KeyValuePair<FoundationValue, FoundationValue>> pairs = null,
            string tag = null, FoundationValue raw = null)
        {
            Kind = kind; text = scalar; boolean = flag; Tag = tag ?? ""; Raw = raw;
            items = new ReadOnlyCollection<FoundationValue>(list == null ? new List<FoundationValue>() : new List<FoundationValue>(list));
            entries = new ReadOnlyCollection<KeyValuePair<FoundationValue, FoundationValue>>(pairs == null ? new List<KeyValuePair<FoundationValue, FoundationValue>>() : new List<KeyValuePair<FoundationValue, FoundationValue>>(pairs));
        }
        public static FoundationValue Nil() => new FoundationValue("nil");
        public static FoundationValue StringValue(string value) => new FoundationValue("string", value ?? throw new ArgumentNullException(nameof(value)));
        public static FoundationValue Integer(long value) => new FoundationValue("int", value.ToString(CultureInfo.InvariantCulture));
        public static FoundationValue Number(double value)
        {
            if (double.IsNaN(value) || double.IsInfinity(value)) throw new FormatException("Nonfinite foundation number.");
            string valueText = value == 0 && BitConverter.DoubleToInt64Bits(value) < 0 ? "-0.0" : value.ToString("R", CultureInfo.InvariantCulture);
            return new FoundationValue("float", valueText);
        }
        public static FoundationValue Boolean(bool value) => new FoundationValue("bool", flag: value);
        public static FoundationValue Array(IEnumerable<FoundationValue> values) => new FoundationValue("array", list: new List<FoundationValue>(values));
        public static FoundationValue Object(IEnumerable<KeyValuePair<FoundationValue, FoundationValue>> values) => new FoundationValue("dictionary", pairs: new List<KeyValuePair<FoundationValue, FoundationValue>>(values));
        public static FoundationValue Dictionary(IEnumerable<KeyValuePair<FoundationValue, FoundationValue>> values) => Object(values);
        public static FoundationValue Object(IDictionary<string, FoundationValue> values)
        {
            var result = new List<KeyValuePair<FoundationValue, FoundationValue>>();
            foreach (var pair in values) result.Add(new KeyValuePair<FoundationValue, FoundationValue>(StringValue(pair.Key), pair.Value));
            return Object(result);
        }
        public bool TryGet(string key, out FoundationValue value)
        {
            foreach (var pair in entries)
                if ((pair.Key.Kind == "string" || pair.Key.Kind == "string_name") && pair.Key.text == key) { value = pair.Value; return true; }
            value = null; return false;
        }
        public FoundationValue Require(string key)
        {
            if (!TryGet(key, out var value)) throw new FormatException("Missing foundation field: " + key);
            return value;
        }
        public string AsString()
        {
            if (Kind != "string" && Kind != "string_name" && Kind != "node_path") throw new FormatException("Expected foundation string, got " + Kind);
            return text;
        }
        public long AsInt64()
        {
            if (Kind != "int" || !long.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var value))
                throw new FormatException("Expected signed64 foundation integer, got " + Kind);
            return value;
        }
        public double AsDouble()
        {
            if ((Kind != "float" && Kind != "int") || !double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out var value) || double.IsInfinity(value) || double.IsNaN(value))
                throw new FormatException("Expected finite foundation number, got " + Kind);
            if (value == 0 && text.StartsWith("-", StringComparison.Ordinal)) return BitConverter.Int64BitsToDouble(long.MinValue);
            return value;
        }
        public bool AsBool()
        {
            if (Kind != "bool") throw new FormatException("Expected foundation boolean, got " + Kind);
            return boolean;
        }
    }

    // No JsonUtility, eval, reflection, scripts, packages or remote dependencies.
    public static class FoundationJson
    {
        private const int MaxDepth = 128, MaxNodes = 2000000, MaxString = 1000000;
        public static FoundationValue Parse(string json)
        {
            return Decode(ParseRaw(json), 0);
        }
        // These two frozen phase-4 documents are ordinary metadata JSON. Their
        // authored "kind" fields describe declarations, resources and rule use;
        // they are not the typed transport discriminator. Select by document
        // identity, never by a failed Variant decode or a guessed object shape.
        public static FoundationValue ParseDocument(string json, string sourcePath)
        {
            if (sourcePath != "migration/portable/identity.json" && sourcePath != "migration/portable/rules.json") return Parse(json);
            var raw = ParseRaw(json);
            if (raw.Kind != "object" || raw.Require("phase").AsInt64() != 4 || raw.Require("schemaVersion").AsInt64() != 1)
                throw new FormatException("Unknown phase-4 metadata document schema.");
            if (sourcePath == "migration/portable/identity.json" && raw.Require("schema").AsString() != "bluemap.migration.identity.v1")
                throw new FormatException("Unknown phase-4 identity document schema.");
            if (sourcePath == "migration/portable/rules.json"
                && (raw.Require("actions").Kind != "array" || raw.Require("conditions").Kind != "array" || raw.Require("usage").Kind != "object"))
                throw new FormatException("Invalid phase-4 rule metadata document.");
            return raw;
        }
        private static FoundationValue ParseRaw(string json)
        {
            if (json == null || json.Length > 128 * 1024 * 1024) throw new FormatException("Foundation JSON size exceeded.");
            var parser = new Parser(json); var raw = parser.Read(0); parser.End();
            return raw;
        }
        private static readonly HashSet<string> Types = new HashSet<string>(StringComparer.Ordinal)
        {
            "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i", "Rect2", "Rect2i", "Color", "Transform2D", "Dictionary",
            "Array", "PackedByteArray", "PackedInt32Array", "PackedInt64Array", "PackedFloat32Array", "PackedFloat64Array", "PackedStringArray", "PackedVector2Array", "PackedVector3Array", "PackedVector4Array", "PackedColorArray",
            "Resource", "Script", "GDScript", "PackedScene", "Texture2D", "CompressedTexture2D", "ImageTexture", "AudioStreamWAV", "AudioStreamOggVorbis", "AudioStreamMP3", "FontFile", "FontVariation", "Shader"
        };
        private static List<FoundationValue> Children(FoundationValue value, int depth)
        {
            if (value.Kind != "array") throw new FormatException("Foundation values require an array.");
            var result = new List<FoundationValue>(); foreach (var child in value.Items) result.Add(Decode(child, depth + 1)); return result;
        }
        private static FoundationValue Decode(FoundationValue raw, int depth)
        {
            if (depth > MaxDepth) throw new FormatException("Foundation Variant depth exceeded.");
            if (raw.Kind == "array") return new FoundationValue("array", list: Children(raw, depth), raw: raw);
            if (raw.Kind != "object") return raw;
            if (!raw.TryGet("kind", out var discriminator))
            {
                var pairs = new List<KeyValuePair<FoundationValue, FoundationValue>>();
                foreach (var pair in raw.Entries) pairs.Add(new KeyValuePair<FoundationValue, FoundationValue>(pair.Key, Decode(pair.Value, depth + 1)));
                return new FoundationValue("object", pairs: pairs, raw: raw);
            }
            string kind = discriminator.AsString();
            FoundationValue value; string tag = "";
            switch (kind)
            {
                case "nil": Shape(raw, "kind"); return new FoundationValue("nil", raw: raw);
                case "bool": Shape(raw, "kind", "value"); return new FoundationValue(kind, flag: raw.Require("value").AsBool(), raw: raw);
                case "int":
                    Shape(raw, "kind", "value"); string integer = raw.Require("value").AsString();
                    if (!CanonicalInteger(integer) || !long.TryParse(integer, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out _)) throw new FormatException("Foundation integer is not canonical signed64.");
                    return new FoundationValue(kind, integer, raw: raw);
                case "float":
                    Shape(raw, "kind", "value"); string number = raw.Require("value").AsString();
                    if (!Regex.IsMatch(number, @"\A-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?\z")) throw new FormatException("Foundation float text is not a JSON decimal.");
                    value = new FoundationValue(kind, number, raw: raw); double f = value.AsDouble();
                    if (f == 0 && HasNonzeroMantissa(number)) throw new FormatException("Foundation float underflow."); return value;
                case "string": case "string_name": case "node_path":
                    Shape(raw, "kind", "value"); return new FoundationValue(kind, raw.Require("value").AsString(), raw: raw);
                case "dictionary":
                    Shape(raw, "kind", "entries"); var pairs = new List<KeyValuePair<FoundationValue, FoundationValue>>(); var seen = new HashSet<string>(StringComparer.Ordinal);
                    if (raw.Require("entries").Kind != "array") throw new FormatException("Typed dictionary entries must be an array.");
                    foreach (var pair in raw.Require("entries").Items)
                    {
                        if (pair.Kind != "array" || pair.Items.Count != 2) throw new FormatException("Invalid typed dictionary pair.");
                        var key = Decode(pair.Items[0], depth + 1); var item = Decode(pair.Items[1], depth + 1);
                        if (!seen.Add(KeyIdentity(key))) throw new FormatException("Duplicate typed foundation dictionary key.");
                        pairs.Add(new KeyValuePair<FoundationValue, FoundationValue>(key, item));
                    }
                    return new FoundationValue(kind, pairs: pairs, raw: raw);
                case "array":
                    if (raw.TryGet("type", out value)) { Shape(raw, "kind", "type", "values"); tag = value.AsString(); if (!Types.Contains(tag) || (tag != "Array" && !tag.StartsWith("Packed", StringComparison.Ordinal))) throw new FormatException("Unknown foundation array type: " + tag); }
                    else Shape(raw, "kind", "values");
                    value = new FoundationValue(kind, list: Children(raw.Require("values"), depth), tag: tag, raw: raw); ValidatePacked(value); return value;
                case "vector":
                    Shape(raw, "kind", "type", "values"); tag = raw.Require("type").AsString();
                    if (!Types.Contains(tag) || !tag.StartsWith("Vector", StringComparison.Ordinal)) throw new FormatException("Unknown foundation vector type: " + tag);
                    value = new FoundationValue(kind, list: Children(raw.Require("values"), depth), tag: tag, raw: raw);
                    if (value.Items.Count != tag[6] - '0') throw new FormatException("Foundation vector dimensions changed.");
                    foreach (var part in value.Items)
                    {
                        if (part.Kind != (tag.EndsWith("i", StringComparison.Ordinal) ? "int" : "float")) throw new FormatException("Foundation vector component kind changed.");
                        if (part.Kind == "int" && (part.AsInt64() < int.MinValue || part.AsInt64() > int.MaxValue)) throw new FormatException("Foundation vector integer out of bounds.");
                    }
                    return value;
                case "rect": Shape(raw, "kind", "type", "position", "size"); tag = raw.Require("type").AsString(); if (tag != "Rect2" && tag != "Rect2i") throw new FormatException("Unknown foundation rect type."); break;
                case "color": Shape(raw, "kind", "rgba"); break;
                case "transform2d": Shape(raw, "kind", "x", "y", "origin"); break;
                case "resource_ref": Shape(raw, "kind", "class", "path"); string path = raw.Require("path").AsString(); if (path != "" && !path.StartsWith("res://", StringComparison.Ordinal) && !path.StartsWith("uid://", StringComparison.Ordinal)) throw new FormatException("Unsafe resource reference."); break;
                case "node_ref": Shape(raw, "kind", "address"); break;
                case "runtime_handle": Shape(raw, "kind", "type", "reason"); tag = raw.Require("type").AsString(); break;
                case "variant":
                    Shape(raw, "kind", "tag", "fields"); tag = raw.Require("tag").AsString(); if (!Types.Contains(tag)) throw new FormatException("Unknown portable Variant tag: " + tag);
                    var fields = new List<KeyValuePair<FoundationValue, FoundationValue>>(); var fieldNames = new HashSet<string>(StringComparer.Ordinal);
                    foreach (var field in raw.Require("fields").Items)
                    {
                        if (field.Items.Count != 2 || !fieldNames.Add(field.Items[0].AsString())) throw new FormatException("Invalid portable Variant fields.");
                        fields.Add(new KeyValuePair<FoundationValue, FoundationValue>(field.Items[0], Decode(field.Items[1], depth + 1)));
                    }
                    value = new FoundationValue(kind, pairs: fields, tag: tag, raw: raw);
                    if (value.Require("$type").AsString() != tag) throw new FormatException("Portable Variant tag disagrees."); return value;
                default: throw new FormatException("Unknown foundation Variant kind: " + kind);
            }
            var result = new List<KeyValuePair<FoundationValue, FoundationValue>>();
            foreach (var pair in raw.Entries) if (pair.Key.AsString() != "kind" && pair.Key.AsString() != "type") result.Add(new KeyValuePair<FoundationValue, FoundationValue>(pair.Key, Decode(pair.Value, depth + 1)));
            value = new FoundationValue(kind, pairs: result, tag: tag, raw: raw);
            if (kind == "rect")
                foreach (string field in new[] { "position", "size" })
                    if (value.Require(field).Kind != "vector" || value.Require(field).Tag != (tag == "Rect2i" ? "Vector2i" : "Vector2")) throw new FormatException("Rect lost its vector type.");
            if (kind == "transform2d")
                foreach (string field in new[] { "x", "y", "origin" })
                    if (value.Require(field).Kind != "vector" || value.Require(field).Tag != "Vector2") throw new FormatException("Transform basis lost its vector type.");
            if (kind == "color")
            {
                var channels = value.Require("rgba"); if (channels.Kind != "array" || channels.Items.Count != 4) throw new FormatException("Color requires four channels.");
                foreach (var channel in channels.Items) if (channel.Kind != "float") throw new FormatException("Color channel type changed.");
            }
            if (kind == "runtime_handle" && tag != "AStarGrid2D" && tag != "Callable" && tag != "RandomNumberGenerator" && tag != "RefCounted" && tag != "WeakRef") throw new FormatException("Unknown data-only runtime handle type: " + tag);
            return value;
        }
        private static void ValidatePacked(FoundationValue value)
        {
            foreach (var part in value.Items)
            {
                string tag = value.Tag;
                if (tag == "PackedByteArray" && (part.Kind != "int" || part.AsInt64() < 0 || part.AsInt64() > 255)) throw new FormatException("Invalid packed byte.");
                if ((tag == "PackedInt32Array" || tag == "PackedInt64Array") && part.Kind != "int") throw new FormatException("Invalid packed integer.");
                if (tag == "PackedInt32Array" && (part.AsInt64() < int.MinValue || part.AsInt64() > int.MaxValue)) throw new FormatException("PackedInt32 overflow.");
                if ((tag == "PackedFloat32Array" || tag == "PackedFloat64Array") && part.Kind != "float") throw new FormatException("Invalid packed float.");
                if (tag == "PackedFloat32Array" && Math.Abs(part.AsDouble()) > float.MaxValue) throw new FormatException("PackedFloat32 overflow.");
                if (tag == "PackedStringArray" && part.Kind != "string") throw new FormatException("Invalid packed string.");
                if (tag.StartsWith("PackedVector", StringComparison.Ordinal) && (part.Kind != "vector" || part.Tag != tag.Substring(6, tag.Length - 11))) throw new FormatException("Invalid packed vector.");
                if (tag == "PackedColorArray" && part.Kind != "color") throw new FormatException("Invalid packed color.");
            }
        }
        private static string KeyIdentity(FoundationValue value)
        {
            if (value.Kind == "float") return "float:" + (value.Double == 0 ? 0UL : value.DoubleBits).ToString("x16");
            return value.Kind + ":" + value.CanonicalJson;
        }
        private static bool HasNonzeroMantissa(string text)
        {
            foreach (char c in text) { if (c == 'e' || c == 'E') break; if (c >= '1' && c <= '9') return true; } return false;
        }
        private static bool CanonicalInteger(string text)
        {
            if (string.IsNullOrEmpty(text)) return false; int start = text[0] == '-' ? 1 : 0;
            if (start == text.Length || (text[start] == '0' && (text.Length - start != 1 || start == 1))) return false;
            for (int i = start; i < text.Length; i++) if (text[i] < '0' || text[i] > '9') return false; return true;
        }
        private static void Shape(FoundationValue raw, params string[] names)
        {
            if (raw.Entries.Count != names.Length) throw new FormatException("Invalid foundation Variant fields."); foreach (string name in names) raw.Require(name);
        }
        internal static string Serialize(FoundationValue value)
        {
            var text = new StringBuilder(); Write(value, text, 0); return text.ToString();
        }
        private static void Quote(string value, StringBuilder text)
        {
            text.Append('"'); foreach (char c in value)
            {
                switch (c) { case '"': text.Append("\\\""); break; case '\\': text.Append("\\\\"); break; case '\b': text.Append("\\b"); break; case '\f': text.Append("\\f"); break; case '\n': text.Append("\\n"); break; case '\r': text.Append("\\r"); break; case '\t': text.Append("\\t"); break; default: if (c < 32) text.Append("\\u" + ((int)c).ToString("x4")); else text.Append(c); break; }
            } text.Append('"');
        }
        private static void Write(FoundationValue value, StringBuilder text, int depth)
        {
            if (depth > MaxDepth) throw new FormatException("Foundation serialization depth exceeded.");
            if (value.Raw != null) { Write(value.Raw, text, depth); return; }
            // Raw JSON nodes use json_* scalar kinds, ordinary objects and arrays.
            if (value.Kind == "json_null") { text.Append("null"); return; }
            if (value.Kind == "json_bool") { text.Append(value.BooleanScalar ? "true" : "false"); return; }
            if (value.Kind == "json_number") { text.Append(value.Scalar); return; }
            if (value.Kind == "string") { Quote(value.Scalar, text); return; }
            if (value.Kind == "object")
            {
                text.Append('{'); for (int i = 0; i < value.Entries.Count; i++) { if (i > 0) text.Append(','); Quote(value.Entries[i].Key.AsString(), text); text.Append(':'); Write(value.Entries[i].Value, text, depth + 1); } text.Append('}'); return;
            }
            if (value.Kind == "array" && value.Tag == "raw")
            {
                text.Append('['); for (int i = 0; i < value.Items.Count; i++) { if (i > 0) text.Append(','); Write(value.Items[i], text, depth + 1); } text.Append(']'); return;
            }
            text.Append("{\"kind\":"); Quote(value.Kind, text);
            if (value.Kind == "bool") text.Append(value.Bool ? ",\"value\":true" : ",\"value\":false");
            else if (value.Kind == "int" || value.Kind == "float") { text.Append(",\"value\":"); Quote(value.Scalar, text); }
            else if (value.Kind == "array") { text.Append(",\"values\":["); for (int i = 0; i < value.Items.Count; i++) { if (i > 0) text.Append(','); WriteTyped(value.Items[i], text, depth + 1); } text.Append(']'); }
            else if (value.Kind == "dictionary") { text.Append(",\"entries\":["); for (int i = 0; i < value.Entries.Count; i++) { if (i > 0) text.Append(','); text.Append('['); WriteTyped(value.Entries[i].Key, text, depth + 1); text.Append(','); WriteTyped(value.Entries[i].Value, text, depth + 1); text.Append(']'); } text.Append(']'); }
            else if (value.Kind != "nil") throw new FormatException("Cannot construct unsupported foundation kind: " + value.Kind);
            text.Append('}');
        }
        private static void WriteTyped(FoundationValue value, StringBuilder text, int depth)
        {
            if (value.Raw == null && value.Kind == "string") { text.Append("{\"kind\":\"string\",\"value\":"); Quote(value.String, text); text.Append('}'); }
            else Write(value, text, depth);
        }
        private sealed class Parser
        {
            private readonly string source; private int position, nodes;
            internal Parser(string text) { source = text; }
            private void Space() { while (position < source.Length && (source[position] == ' ' || source[position] == '\r' || source[position] == '\n' || source[position] == '\t')) position++; }
            internal void End() { Space(); if (position != source.Length) throw Error("Trailing JSON content"); }
            private FormatException Error(string message) => new FormatException(message + " at character " + position.ToString(CultureInfo.InvariantCulture));
            internal FoundationValue Read(int depth)
            {
                if (++nodes > MaxNodes || depth > MaxDepth) throw Error("Foundation JSON budget exceeded"); Space(); if (position >= source.Length) throw Error("Unexpected end of JSON"); char c = source[position];
                if (c == '"') return FoundationValue.StringValue(Text());
                if (c == '{')
                {
                    position++; Space(); var pairs = new List<KeyValuePair<FoundationValue, FoundationValue>>(); var seen = new HashSet<string>(StringComparer.Ordinal);
                    if (Take('}')) return new FoundationValue("object", pairs: pairs);
                    do { Space(); if (position >= source.Length || source[position] != '"') throw Error("JSON object key expected"); string key = Text(); if (!seen.Add(key)) throw Error("Duplicate JSON key"); Space(); if (!Take(':')) throw Error("JSON colon expected"); pairs.Add(new KeyValuePair<FoundationValue, FoundationValue>(FoundationValue.StringValue(key), Read(depth + 1))); Space(); if (Take('}')) return new FoundationValue("object", pairs: pairs); } while (Take(',')); throw Error("JSON object separator expected");
                }
                if (c == '[')
                {
                    position++; Space(); var list = new List<FoundationValue>(); if (Take(']')) return new FoundationValue("array", list: list, tag: "raw");
                    do { list.Add(Read(depth + 1)); Space(); if (Take(']')) return new FoundationValue("array", list: list, tag: "raw"); } while (Take(',')); throw Error("JSON array separator expected");
                }
                if (Literal("true")) return new FoundationValue("bool", flag: true, raw: new FoundationValue("json_bool", flag: true));
                if (Literal("false")) return new FoundationValue("bool", flag: false, raw: new FoundationValue("json_bool", flag: false));
                if (Literal("null")) return new FoundationValue("nil", raw: new FoundationValue("json_null"));
                int start = position; if (Take('-') && position >= source.Length) throw Error("JSON number expected");
                if (Take('0')) { if (position < source.Length && char.IsDigit(source[position])) throw Error("JSON leading zero"); }
                else { if (position >= source.Length || source[position] < '1' || source[position] > '9') throw Error("JSON number expected"); while (position < source.Length && source[position] >= '0' && source[position] <= '9') position++; }
                bool real = false;
                if (Take('.')) { real = true; Digits(); }
                if (Take('e') || Take('E')) { real = true; if (!Take('+')) Take('-'); Digits(); }
                string number = source.Substring(start, position - start); string kind = real ? "float" : "int";
                var result = new FoundationValue(kind, number, raw: new FoundationValue("json_number", number));
                if (real) { double value = result.AsDouble(); if (value == 0 && HasNonzeroMantissa(number)) throw Error("JSON float underflow"); } else result.AsInt64();
                return result;
            }
            private void Digits() { int start = position; while (position < source.Length && source[position] >= '0' && source[position] <= '9') position++; if (position == start) throw Error("JSON fraction/exponent digit expected"); }
            private bool Take(char c) { if (position < source.Length && source[position] == c) { position++; return true; } return false; }
            private bool Literal(string value) { if (source.Length - position < value.Length || string.CompareOrdinal(source, position, value, 0, value.Length) != 0) return false; position += value.Length; return true; }
            private string Text()
            {
                position++; var text = new StringBuilder();
                while (position < source.Length)
                {
                    char c = source[position++]; if (c == '"') { if (text.Length > MaxString) throw Error("Foundation string budget exceeded"); string value = text.ToString(); for (int i = 0; i < value.Length; i++) if (char.IsSurrogate(value[i])) { if (!char.IsHighSurrogate(value[i]) || i + 1 >= value.Length || !char.IsLowSurrogate(value[++i])) throw Error("Invalid Unicode surrogate"); } return value; }
                    if (c < 32) throw Error("JSON control character"); if (c != '\\') { text.Append(c); continue; }
                    if (position >= source.Length) throw Error("Truncated JSON escape"); c = source[position++];
                    switch (c) { case '"': case '\\': case '/': text.Append(c); break; case 'b': text.Append('\b'); break; case 'f': text.Append('\f'); break; case 'n': text.Append('\n'); break; case 'r': text.Append('\r'); break; case 't': text.Append('\t'); break; case 'u': if (source.Length - position < 4 || !ushort.TryParse(source.Substring(position, 4), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out ushort code)) throw Error("Invalid Unicode escape"); text.Append((char)code); position += 4; break; default: throw Error("Invalid JSON escape"); }
                    if (text.Length > MaxString) throw Error("Foundation string budget exceeded");
                }
                throw Error("Unterminated JSON string");
            }
        }
    }
}
