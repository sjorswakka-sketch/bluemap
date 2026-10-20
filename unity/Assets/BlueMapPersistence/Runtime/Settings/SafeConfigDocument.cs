using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using BlueMapMigration.Foundation;

namespace BlueMapMigration.Persistence
{
    /// <summary>Godot ConfigFile text decoded as inert data. Object/constructor syntax never creates a CLR or engine object.</summary>
    public sealed class SafeConfigDocument
    {
        readonly byte[] original;
        public byte[] SourceBytes => (byte[])original.Clone();
        public FoundationValue Root { get; }
        SafeConfigDocument(byte[] source, FoundationValue root) { original = (byte[])source.Clone(); Root = root; }
        public FoundationValue Get(string section, string key, FoundationValue fallback = null)
            => Root.TryGet(section, out var part) && part.TryGet(key, out var value) ? value : fallback;
        public bool Has(string section, string key) => Root.TryGet(section, out var part) && part.TryGet(key, out _);
        public static SafeConfigDocument Parse(byte[] bytes)
        {
            if (bytes == null || bytes.Length > 4 * 1024 * 1024) throw new FormatException("ConfigFile size exceeded.");
            string text;
            try { text = new UTF8Encoding(false, true).GetString(bytes); }
            catch (DecoderFallbackException error) { throw new FormatException("ConfigFile is not UTF-8.", error); }
            return new SafeConfigDocument(bytes, new Reader(text).Document());
        }
        sealed class Reader
        {
            readonly string source; int position, nodes;
            public Reader(string text) { source = text; if (source.Length > 0 && source[0] == '\ufeff') position++; }
            char Current => position < source.Length ? source[position] : '\0';
            FormatException Error(string message) => new FormatException(message + " at ConfigFile offset " + position + ".");
            void Skip()
            {
                while (position < source.Length)
                {
                    if (char.IsWhiteSpace(Current)) { position++; continue; }
                    if (Current == ';' || Current == '#') { while (position < source.Length && Current != '\n') position++; continue; }
                    break;
                }
            }
            void Expect(char value) { Skip(); if (Current != value) throw Error("Expected " + value); position++; }
            public FoundationValue Document()
            {
                var sections = new Dictionary<string, Dictionary<string, FoundationValue>>(StringComparer.Ordinal);
                string section = ""; Skip();
                while (position < source.Length)
                {
                    if (Current == '[')
                    {
                        position++; int start = position;
                        while (position < source.Length && Current != ']' && Current != '\n') position++;
                        if (Current != ']') throw Error("Unterminated section");
                        section = source.Substring(start, position - start).Trim(); position++;
                        if (section.Length == 0) throw Error("Empty section");
                        if (!sections.ContainsKey(section)) sections.Add(section, new Dictionary<string, FoundationValue>(StringComparer.Ordinal));
                    }
                    else
                    {
                        string key;
                        if (Current == '"') key = String();
                        else { int start = position; while (position < source.Length && Current != '=' && Current != '\n') position++; key = source.Substring(start, position - start).Trim(); }
                        if (key.Length == 0) throw Error("Empty key");
                        Expect('='); var value = Value(0);
                        if (!sections.ContainsKey(section)) sections.Add(section, new Dictionary<string, FoundationValue>(StringComparer.Ordinal));
                        sections[section][key] = value;
                    }
                    // ConfigFile permits whitespace and comments after each value; another token is parsed as a key.
                    Skip();
                }
                var result = new Dictionary<string, FoundationValue>(StringComparer.Ordinal);
                foreach (var pair in sections) result.Add(pair.Key, FoundationValue.Object(pair.Value));
                return FoundationValue.Object(result);
            }
            FoundationValue Value(int depth)
            {
                if (++nodes > 100000 || depth > 64) throw Error("ConfigFile nesting or item limit exceeded");
                Skip();
                if (Current == '"') return FoundationValue.StringValue(String());
                if (Current == '&' || Current == '^') { position++; if (Current != '"') throw Error("Invalid string prefix"); return FoundationValue.StringValue(String()); }
                if (Current == '[')
                {
                    position++; var values = new List<FoundationValue>(); Skip();
                    if (Current != ']') while (true) { values.Add(Value(depth + 1)); Skip(); if (Current != ',') break; position++; Skip(); if (Current == ']') break; }
                    Expect(']'); return FoundationValue.Array(values);
                }
                if (Current == '{')
                {
                    position++; var values = new List<KeyValuePair<FoundationValue, FoundationValue>>(); Skip();
                    if (Current != '}') while (true)
                    {
                        var key = Value(depth + 1); Expect(':'); var value = Value(depth + 1);
                        int old = values.FindIndex(p => p.Key.CanonicalJson == key.CanonicalJson);
                        if (old >= 0) values[old] = new KeyValuePair<FoundationValue, FoundationValue>(key, value);
                        else values.Add(new KeyValuePair<FoundationValue, FoundationValue>(key, value));
                        Skip(); if (Current != ',') break; position++; Skip(); if (Current == '}') break;
                    }
                    Expect('}'); return FoundationValue.Dictionary(values);
                }
                if (Current == '-' || Current == '+' || char.IsDigit(Current))
                {
                    int start = position; while (position < source.Length && (char.IsLetterOrDigit(Current) || Current == '.' || Current == '+' || Current == '-')) position++;
                    string token = source.Substring(start, position - start);
                    if (long.TryParse(token, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long integer)) return FoundationValue.Integer(integer);
                    if (!double.TryParse(token, NumberStyles.Float, CultureInfo.InvariantCulture, out double number) || double.IsNaN(number) || double.IsInfinity(number)) throw Error("Invalid finite number");
                    return FoundationValue.Number(number);
                }
                if (char.IsLetter(Current) || Current == '_')
                {
                    string name = Identifier(); Skip();
                    if (name == "true") return FoundationValue.Boolean(true);
                    if (name == "false") return FoundationValue.Boolean(false);
                    if (name == "null" || name == "nil") return FoundationValue.Nil();
                    Expect('(');
                    var args = new List<FoundationValue>(); var fields = new Dictionary<string, FoundationValue>(StringComparer.Ordinal);
                    // Object(ClassName, "property": value, ...) is a data record only.
                    if (name == "Object") { Skip(); fields.Add("$class", FoundationValue.StringValue(Identifier())); Skip(); if (Current == ',') position++; }
                    Skip();
                    if (Current != ')') while (true)
                    {
                        var first = Value(depth + 1); Skip();
                        if (Current == ':') { position++; fields[first.AsString()] = Value(depth + 1); }
                        else args.Add(first);
                        Skip(); if (Current != ',') break; position++; Skip(); if (Current == ')') break;
                    }
                    Expect(')');
                    return FoundationValue.Object(new Dictionary<string, FoundationValue> { { "$constructor", FoundationValue.StringValue(name) }, { "$fields", FoundationValue.Object(fields) }, { "$args", FoundationValue.Array(args) } });
                }
                throw Error("Expected inert ConfigFile value");
            }
            string Identifier()
            {
                int start = position; while (position < source.Length && (char.IsLetterOrDigit(Current) || Current == '_')) position++;
                if (position == start) throw Error("Expected identifier"); return source.Substring(start, position - start);
            }
            string String()
            {
                if (Current != '"') throw Error("Expected string"); position++; var result = new StringBuilder();
                while (position < source.Length)
                {
                    char item = source[position++]; if (item == '"') return result.ToString();
                    if (item == '\\')
                    {
                        if (position >= source.Length) throw Error("Unterminated string escape"); item = source[position++];
                        switch (item)
                        {
                            case 'n': item = '\n'; break; case 'r': item = '\r'; break; case 't': item = '\t'; break;
                            case 'b': item = '\b'; break; case 'f': item = '\f'; break; case 'v': item = '\v'; break; case 'a': item = '\a'; break;
                            case 'u':
                                if (position + 4 > source.Length || !ushort.TryParse(source.Substring(position, 4), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out ushort code)) throw Error("Invalid Unicode escape");
                                position += 4; item = (char)code; break;
                            case '"': case '\\': case '/': break;
                            default: throw Error("Unsupported string escape");
                        }
                    }
                    result.Append(item); if (result.Length > 1000000) throw Error("ConfigFile string limit exceeded");
                }
                throw Error("Unterminated string");
            }
        }
    }
}
