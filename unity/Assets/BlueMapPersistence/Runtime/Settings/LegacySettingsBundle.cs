using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;

namespace BlueMapMigration.Persistence
{
    public sealed class LegacyPreferences
    {
        public string Locale { get; }
        public bool Muted { get; }
        public double MusicVolume { get; }
        public double SfxVolume { get; }
        public LegacyPreferences(string locale = "nl", bool muted = false, double music = 1, double sfx = 1)
        {
            Locale = Supported(locale); if (Locale == "") throw new FormatException("Unsupported preference language.");
            if (double.IsNaN(music) || double.IsInfinity(music) || double.IsNaN(sfx) || double.IsInfinity(sfx)) throw new FormatException("Nonfinite volume.");
            Muted = muted; MusicVolume = Math.Max(0, Math.Min(1, music)); SfxVolume = Math.Max(0, Math.Min(1, sfx));
        }
        public static string Supported(string code)
        {
            string value = (code ?? "").Trim().ToLowerInvariant().Replace('-', '_').Split('_')[0];
            return value == "nl" || value == "en" ? value : "";
        }
        public FoundationValue ToValue() => FoundationValue.Object(new Dictionary<string, FoundationValue> {
            { "locale", FoundationValue.StringValue(Locale) }, { "muted", FoundationValue.Boolean(Muted) },
            { "music", FoundationValue.Number(MusicVolume) }, { "sfx", FoundationValue.Number(SfxVolume) } });
        public static LegacyPreferences FromValue(FoundationValue value) => new LegacyPreferences(value.Require("locale").AsString(), value.Require("muted").AsBool(), value.Require("music").AsDouble(), value.Require("sfx").AsDouble());
    }

    /// <summary>Read-only legacy settings projection. Original bytes, including unknown fields and malformed files, belong to the caller's isolated archive.</summary>
    public sealed class LegacySettingsBundle
    {
        public LegacyPreferences Preferences { get; private set; }
        public FoundationValue Bindings { get; private set; }
        public FoundationValue Achievements { get; private set; }
        public FoundationValue NgMeta { get; private set; }
        public IReadOnlyList<string> Diagnostics { get; private set; }
        public IReadOnlyDictionary<string, SafeConfigDocument> Documents { get; private set; }
        static FoundationValue Dict(Dictionary<string, FoundationValue> value) => FoundationValue.Object(value);
        static FoundationValue Empty() => Dict(new Dictionary<string, FoundationValue>());

        public static LegacySettingsBundle Decode(byte[] settings, byte[] controls, byte[] meta, byte[] ng,
            PlayerInputSource inputDefaults, LegacySaveImporter saveImporter, string environmentLocale = "", string systemLocale = "en")
        {
            if (inputDefaults == null || saveImporter == null) throw new ArgumentNullException("Settings require verified original defaults and save normalizers.");
            var warnings = new List<string>(); var docs = new Dictionary<string, SafeConfigDocument>(StringComparer.Ordinal);
            SafeConfigDocument Read(string name, byte[] bytes)
            {
                if (bytes == null) return null;
                try { var document = SafeConfigDocument.Parse(bytes); docs.Add(name, document); return document; }
                catch (FormatException error) { warnings.Add(name + ": " + error.Message + " Source bytes retained; safe defaults used."); return null; }
            }
            var cfg = Read("settings.cfg", settings); var bindingsCfg = Read("controls.cfg", controls);
            var achievementsCfg = Read("meta.cfg", meta); var ngCfg = Read("ng_plus.cfg", ng);
            string locale = LegacyPreferences.Supported(Text(cfg?.Get("taal", "locale")));
            if (locale == "") locale = LegacyPreferences.Supported(environmentLocale);
            if (locale == "") locale = systemLocale == "nl" ? "nl" : "en";
            double Volume(string key)
            {
                var value = cfg?.Get("audio", key);
                if (value == null) return 1;
                if (value.Kind == "int" || value.Kind == "float") return value.AsDouble();
                warnings.Add("settings.cfg/audio/" + key + ": invalid numeric volume; source retained."); return 1;
            }
            var preferences = new LegacyPreferences(locale, Truth(cfg?.Get("audio", "muted")), Volume("music"), Volume("sfx"));
            var bindingMap = new Dictionary<string, InputBindingSpec[]>(StringComparer.Ordinal);
            foreach (var action in inputDefaults.Oracle.defaults)
                bindingMap.Add(action.id, inputDefaults.DefaultBindings(action.id).Select(b => b.Copy()).ToArray());
            if (bindingsCfg != null)
            {
                foreach (var action in inputDefaults.Oracle.defaults.Where(a => a.rebindable))
                    foreach (string category in new[] { "keyboard", "controller" })
                    {
                        var stored = bindingsCfg.Get(category, action.id);
                        if (stored == null) continue;
                        var values = new List<InputBindingSpec>(); bool valid = stored.Kind == "array" && stored.Items.Count <= 8;
                        if (valid) foreach (var item in stored.Items)
                        {
                            try { var value = DecodeBinding(item, category); if (value == null) { valid = false; break; } values.Add(value); }
                            catch (Exception error) when (error is FormatException || error is OverflowException) { valid = false; break; }
                        }
                        if (valid) bindingMap[action.id] = bindingMap[action.id].Where(b => b.category != category).Concat(values).ToArray();
                        else warnings.Add("controls.cfg/" + category + "/" + action.id + ": original defaults retained for invalid binding array.");
                    }
                foreach (string category in new[] { "keyboard", "controller" })
                    MigrateMissing("technique", category, category == "keyboard" ? new[] { Key(86), Key(71), Key(90) } : new[] { Axis(4, 1), Axis(5, 1), Button(8) }, bindingsCfg, bindingMap, inputDefaults);
                foreach (string category in new[] { "keyboard", "controller" })
                    MigrateMissing("homestead", category, category == "keyboard" ? new[] { Key(85), Key(79), Key(90) } : Array.Empty<InputBindingSpec>(), bindingsCfg, bindingMap, inputDefaults);
            }
            var achievementValues = new Dictionary<string, FoundationValue>(StringComparer.Ordinal);
            if (achievementsCfg != null && achievementsCfg.Root.TryGet("achievements", out var achievementSection))
                foreach (var entry in achievementSection.Entries) achievementValues[entry.Key.AsString()] = FoundationValue.Boolean(true); // Source marks presence, regardless of value.
            FoundationValue Ng(string key, FoundationValue fallback) => ngCfg?.Get("ng", key) ?? fallback;
            var owned = saveImporter.NormalizeOwned(Ng("gear_items", Empty()));
            string weapon = Text(Ng("weapon", FoundationValue.StringValue("wood")));
            // The authoritative original weapon registry is frozen in the verified save oracle.
            if (!saveImporter.IsKnownWeapon(weapon)) weapon = "wood";
            var ngValues = new Dictionary<string, FoundationValue> {
                { "completed", FoundationValue.Boolean(Truth(Ng("completed", FoundationValue.Boolean(false)))) },
                { "rounds", FoundationValue.Integer(Int(Ng("rounds", FoundationValue.Integer(0)))) },
                { "weapon", FoundationValue.StringValue(weapon) }, { "hearts", FoundationValue.Integer(Int(Ng("hearts", FoundationValue.Integer(0)))) },
                { "boots", FoundationValue.Boolean(Truth(Ng("boots", FoundationValue.Boolean(false)))) },
                { "hero_xp", FoundationValue.Integer(LegacySaveImporter.NormalizeHeroXp(Ng("hero_xp", FoundationValue.Integer(0)))) },
                { "gear_items", owned }, { "equipment", saveImporter.NormalizeEquipment(Ng("equipment", Empty()), owned) } };
            return new LegacySettingsBundle { Preferences = preferences, Bindings = EncodeBindings(bindingMap), Achievements = Dict(achievementValues), NgMeta = Dict(ngValues), Diagnostics = new ReadOnlyCollection<string>(warnings), Documents = new ReadOnlyDictionary<string, SafeConfigDocument>(docs) };
        }
        static void MigrateMissing(string id, string category, InputBindingSpec[] choices, SafeConfigDocument cfg,
            Dictionary<string, InputBindingSpec[]> map, PlayerInputSource defaults)
        {
            if (cfg.Has(category, id)) return;
            map[id] = map[id].Where(b => b.category != category).ToArray();
            foreach (var candidate in choices)
            {
                candidate.category = category;
                bool used = defaults.Oracle.defaults.Where(a => a.rebindable && a.id != id).Any(a => map[a.id].Any(b => b.category == category && Same(b, candidate)));
                if (!used) { map[id] = map[id].Concat(new[] { candidate }).ToArray(); break; }
            }
        }
        static bool Same(InputBindingSpec a, InputBindingSpec b) => a.kind == b.kind && a.code == b.code && (a.kind != "axis" || a.direction == b.direction);
        static InputBindingSpec Key(int code) { var value = new InputBindingSpec { kind = "key", code = code, keyName = KeyName(code), direction = 1 }; value.path = PlayerInputSource.SourcePath(value); return value; }
        static InputBindingSpec Axis(int code, float direction) { var value = new InputBindingSpec { kind = "axis", code = code, direction = direction }; value.path = PlayerInputSource.SourcePath(value); return value; }
        static InputBindingSpec Button(int code) { var value = new InputBindingSpec { kind = "button", code = code, direction = 1 }; value.path = PlayerInputSource.SourcePath(value); return value; }
        static InputBindingSpec DecodeBinding(FoundationValue value, string category)
        {
            if (!value.TryGet("$constructor", out var constructor) || constructor.AsString() != "Object") return null;
            var fields = value.Require("$fields"); string type = fields.Require("$class").AsString();
            FoundationValue Field(string key) => fields.TryGet(key, out var item) ? item : null;
            var result = new InputBindingSpec { category = category, direction = 1, keyName = "" };
            switch (type)
            {
                case "InputEventKey":
                    if (category != "keyboard") return null;
                    result.kind = "key"; long physical = Int(Field("physical_keycode")); result.code = checked((int)(physical != 0 ? physical : Int(Field("keycode")))); result.keyName = KeyName(result.code);
                    result.shift = Truth(Field("shift_pressed")); result.ctrl = Truth(Field("ctrl_pressed")); result.alt = Truth(Field("alt_pressed")); result.meta = Truth(Field("meta_pressed")); break;
                case "InputEventMouseButton":
                    if (category != "keyboard") return null; result.kind = "mouse"; result.code = checked((int)Int(Field("button_index"))); break;
                case "InputEventJoypadButton":
                    if (category != "controller") return null; result.kind = "button"; result.code = checked((int)Int(Field("button_index"))); break;
                case "InputEventJoypadMotion":
                    if (category != "controller") return null; result.kind = "axis"; result.code = checked((int)Int(Field("axis"))); result.direction = Math.Sign(Field("axis_value")?.AsDouble() ?? 0); break;
                default: return null;
            }
            try { result.path = PlayerInputSource.SourcePath(result); }
            catch (InvalidOperationException) { result.path = "<GodotUnmapped>/" + result.kind + result.code; }
            return result;
        }
        public static string KeyName(int code)
        {
            if (code >= 65 && code <= 90 || code >= 48 && code <= 57) return ((char)code).ToString();
            if (code >= 4194332 && code <= 4194366) return "F" + (code - 4194331).ToString(CultureInfo.InvariantCulture);
            if (code >= 4194438 && code <= 4194447) return "Kp " + (code - 4194438).ToString(CultureInfo.InvariantCulture);
            var names = new Dictionary<int, string> { { 32,"Space" },{4194305,"Escape"},{4194306,"Tab"},{4194307,"Backtab"},{4194308,"Backspace"},{4194309,"Enter"},{4194310,"Kp Enter"},{4194311,"Insert"},{4194312,"Delete"},{4194313,"Pause"},{4194314,"Print"},{4194315,"SysReq"},{4194316,"Clear"},{4194317,"Home"},{4194318,"End"},{4194319,"Left"},{4194320,"Up"},{4194321,"Right"},{4194322,"Down"},{4194323,"PageUp"},{4194324,"PageDown"},{4194325,"Shift"},{4194326,"Ctrl"},{4194327,"Meta"},{4194328,"Alt"},{4194329,"CapsLock"},{4194330,"NumLock"},{4194331,"ScrollLock"},
                {39,"Apostrophe"},{44,"Comma"},{45,"Minus"},{46,"Period"},{47,"Slash"},{59,"Semicolon"},{61,"Equal"},{91,"BracketLeft"},{92,"Backslash"},{93,"BracketRight"},{96,"QuoteLeft"},
                {4194433,"Kp Multiply"},{4194434,"Kp Divide"},{4194435,"Kp Subtract"},{4194436,"Kp Period"},{4194437,"Kp Add"},{4194370,"Menu"} };
            return names.TryGetValue(code, out var name) ? name : "GodotKey" + code.ToString(CultureInfo.InvariantCulture);
        }
        static string Text(FoundationValue value) => value == null || value.Kind == "nil" ? "" : value.Kind == "string" ? value.AsString() : value.Kind == "int" ? value.AsInt64().ToString(CultureInfo.InvariantCulture) : value.Kind == "bool" ? (value.AsBool() ? "true" : "false") : value.CanonicalJson;
        static long Int(FoundationValue value)
        {
            if (value == null || value.Kind == "nil") return 0;
            if (value.Kind == "int") return value.AsInt64();
            if (value.Kind == "float") return checked((long)value.AsDouble());
            if (value.Kind == "bool") return value.AsBool() ? 1 : 0;
            return long.TryParse(Text(value), NumberStyles.Integer, CultureInfo.InvariantCulture, out var number) ? number : 0;
        }
        static bool Truth(FoundationValue value) => value != null && value.Kind != "nil" && (value.Kind == "bool" ? value.AsBool() : value.Kind == "int" || value.Kind == "float" ? value.AsDouble() != 0 : value.Kind == "string" ? value.AsString().Length != 0 : value.Kind == "array" ? value.Items.Count != 0 : value.Entries.Count != 0);
        public void ApplyBindings(PlayerInputSource input) => ApplyBindingValue(input, Bindings);
        public static FoundationValue BindingValue(PlayerInputSource input) => EncodeBindings(input.Oracle.defaults.ToDictionary(a => a.id, a => input.Bindings(a.id).Select(b => b.Copy()).ToArray(), StringComparer.Ordinal));
        static FoundationValue EncodeBindings(Dictionary<string, InputBindingSpec[]> map)
        {
            var result = new Dictionary<string, FoundationValue>(StringComparer.Ordinal);
            foreach (var action in map) result.Add(action.Key, FoundationValue.Array(action.Value.Select(b => Dict(new Dictionary<string, FoundationValue> {
                {"category",FoundationValue.StringValue(b.category)},{"kind",FoundationValue.StringValue(b.kind)},{"path",FoundationValue.StringValue(b.path)},{"code",FoundationValue.Integer(b.code)},{"keyName",FoundationValue.StringValue(b.keyName ?? "")},{"direction",FoundationValue.Number(b.direction)},
                {"shift",FoundationValue.Boolean(b.shift)},{"ctrl",FoundationValue.Boolean(b.ctrl)},{"alt",FoundationValue.Boolean(b.alt)},{"meta",FoundationValue.Boolean(b.meta)} }))));
            return Dict(result);
        }
        public static void ApplyBindingValue(PlayerInputSource input, FoundationValue value)
        {
            var map = new Dictionary<string, InputBindingSpec[]>(StringComparer.Ordinal);
            foreach (var action in value.Entries)
                map.Add(action.Key.AsString(), action.Value.Items.Select(v => new InputBindingSpec { category=v.Require("category").AsString(),kind=v.Require("kind").AsString(),path=v.Require("path").AsString(),code=checked((int)v.Require("code").AsInt64()),keyName=v.Require("keyName").AsString(),direction=(float)v.Require("direction").AsDouble(),shift=v.Require("shift").AsBool(),ctrl=v.Require("ctrl").AsBool(),alt=v.Require("alt").AsBool(),meta=v.Require("meta").AsBool() }).ToArray());
            input.ApplyImportedBindings(map);
        }
    }
}
