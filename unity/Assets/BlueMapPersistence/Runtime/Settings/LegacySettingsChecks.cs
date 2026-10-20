using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace BlueMapMigration.Persistence
{
    /// <summary>Native comparison against two fresh original-engine runs; every input file is a synthetic in-memory fixture.</summary>
    public static class LegacySettingsChecks
    {
        public const string OracleResource = "BlueMapPersistenceSettingsOracle";
        public static int Cases { get; private set; }
        public static void Verify(Action<string, bool> check, FoundationWorldRepository repository = null)
        {
            var asset = Resources.Load<TextAsset>(OracleResource);
            if (!asset) throw new InvalidOperationException("Missing original settings oracle.");
            var oracle = FoundationJson.ParsePlain(asset.text);
            if (oracle.Require("schema").AsString() != "bluemap.settings-import.v1" || oracle.Require("engineVersion").AsString() != "4.4.1-stable (official)" || oracle.Require("personalSavesUsed").AsBool())
                throw new FormatException("Invalid original settings oracle.");
            var importer = new LegacySaveImporter(repository ?? FoundationWorldRepository.LoadRequired());
            Cases = 0; check("persistence_settings_checks_ran", true);
            bool originalsExact = true, preferencesRoundTrip = true, unknownRetained = false, invalidSafe = false, oldShortcuts = false, modifiers = false, deliberateEmpty = false, duplicates = false, achievementsPresence = false;
            foreach (var test in oracle.Require("cases").Items)
            {
                string id = test.Require("id").AsString(); var documents = test.Require("documents");
                byte[] Bytes(string name) { var item = documents.Require(name); return item.Kind == "nil" ? null : Convert.FromBase64String(item.AsString()); }
                using (var input = new PlayerInputSource())
                {
                    var bundle = LegacySettingsBundle.Decode(Bytes("settings"), Bytes("controls"), Bytes("meta"), Bytes("ng"), input, importer, "nl", "en");
                    bool good = true; var differences = new List<string>();
                    void Difference(string field, object expected, object actual)
                    { good = false; if (differences.Count < 32) differences.Add(field + " expected=" + expected + " actual=" + actual); }
                    void Scalar(string field, object expected, object actual)
                    { if (!object.Equals(expected, actual)) Difference(field, expected, actual); }
                    Scalar("locale", test.Require("locale").AsString(), bundle.Preferences.Locale);
                    Scalar("muted", test.Require("muted").AsBool(), bundle.Preferences.Muted);
                    Scalar("music", test.Require("music").AsDouble(), bundle.Preferences.MusicVolume);
                    Scalar("sfx", test.Require("sfx").AsDouble(), bundle.Preferences.SfxVolume);
                    bundle.ApplyBindings(input);
                    foreach (var action in test.Require("bindings").Items)
                    {
                        string actionId = action.Require("id").AsString(); var actual = input.Bindings(actionId); var expected = action.Require("bindings").Items;
                        if (actual.Count != expected.Count) { Difference("bindings." + actionId + ".count", expected.Count, actual.Count); continue; }
                        for (int index = 0; index < actual.Count; index++)
                        {
                            var row = expected[index];
                            var expectedBinding = new InputBindingSpec { category=row.Require("category").AsString(),kind=row.Require("kind").AsString(),code=(int)row.Require("code").AsInt64(),keyName=row.Require("keyName").AsString(),direction=(float)row.Require("direction").AsDouble(),shift=row.Require("shift").AsBool(),ctrl=row.Require("ctrl").AsBool(),alt=row.Require("alt").AsBool(),meta=row.Require("meta").AsBool() };
                            expectedBinding.path = PlayerInputSource.SourcePath(expectedBinding);
                            var got = actual[index];
                            bool same = got.category == expectedBinding.category && got.kind == expectedBinding.kind && got.code == expectedBinding.code && got.keyName == expectedBinding.keyName && got.direction == expectedBinding.direction && got.path == expectedBinding.path
                                && got.shift == expectedBinding.shift && got.ctrl == expectedBinding.ctrl && got.alt == expectedBinding.alt && got.meta == expectedBinding.meta;
                            if (!same) Difference("bindings." + actionId + "[" + index + "]", JsonUtility.ToJson(expectedBinding), JsonUtility.ToJson(got));
                        }
                    }
                    var expectedAchievements = test.Require("achievements").Items.Select(v => v.AsString()).OrderBy(v => v, StringComparer.Ordinal);
                    string[] gotAchievements = bundle.Achievements.Entries.Select(p => p.Key.AsString()).OrderBy(v => v, StringComparer.Ordinal).ToArray();
                    if (!gotAchievements.SequenceEqual(expectedAchievements)) Difference("achievements", string.Join(",", expectedAchievements), string.Join(",", gotAchievements));
                    if (!Equal(bundle.NgMeta, test.Require("ng"))) Difference("ng", FoundationJson.StringifyPlain(test.Require("ng")), FoundationJson.StringifyPlain(bundle.NgMeta));
                    foreach (var part in new[] { "settings", "controls", "meta", "ng" })
                    {
                        byte[] bytes = Bytes(part); string filename = part == "ng" ? "ng_plus.cfg" : part + ".cfg";
                        bool expectedValid = bytes != null && test.Require("parseOk").Require(part).AsBool();
                        bool gotValid = bundle.Documents.ContainsKey(filename);
                        Scalar("documents." + part + ".valid", expectedValid, gotValid);
                        if (expectedValid && gotValid && !bundle.Documents[filename].SourceBytes.SequenceEqual(bytes)) Difference("documents." + part + ".bytes", "original exact bytes", "different source bytes");
                    }
                    if (!good) Debug.Log("Settings source oracle difference " + id + ":\n" + string.Join("\n", differences));
                    check("persistence_settings_source_" + id, good); originalsExact &= good; Cases++;
                    if (id == "unknown_multiline") unknownRetained = bundle.Documents["settings.cfg"].Root.Require("future").Require("values").Require("kind").AsString() == "literal" && bundle.Diagnostics.Count == 0;
                    if (id == "malformed") invalidSafe = bundle.Diagnostics.Count == 4 && bundle.Documents.Count == 0 && input.Bindings("attack").Count > 0;
                    if (id == "legacy_conflicts") oldShortcuts = input.Bindings("technique").Single(b => b.category == "keyboard").code == 71 && input.Bindings("homestead").Single(b => b.category == "keyboard").code == 79;
                    if (id == "physical_and_modifiers") modifiers = input.Bindings("attack").Single(b => b.category == "keyboard").ctrl && input.Bindings("bow").Single(b => b.category == "keyboard").meta;
                    if (id == "explicit_empty") deliberateEmpty = !input.Bindings("attack").Any(b => b.category == "keyboard") && !input.Bindings("sprint").Any(b => b.category == "controller");
                    if (id == "oversized_and_duplicate") duplicates = input.Bindings("bow").Count(b => b.category == "keyboard") == 2;
                    if (id == "full_defaults") achievementsPresence = bundle.Achievements.Require("explorer").AsBool();
                    var roundTrip = LegacyPreferences.FromValue(FoundationJson.Parse(bundle.Preferences.ToValue().CanonicalJson));
                    preferencesRoundTrip &= roundTrip.Locale == bundle.Preferences.Locale && roundTrip.MusicVolume == bundle.Preferences.MusicVolume && roundTrip.Muted == bundle.Preferences.Muted && roundTrip.SfxVolume == bundle.Preferences.SfxVolume;
                }
            }
            check("persistence_settings_source_oracle_complete", originalsExact && Cases == 10);
            check("persistence_settings_preferences_roundtrip", preferencesRoundTrip);
            check("persistence_settings_unknown_sections_bytes_retained", unknownRetained);
            check("persistence_settings_malformed_files_safe_defaults", invalidSafe);
            check("persistence_settings_legacy_shortcuts_avoid_existing_bindings", oldShortcuts);
            check("persistence_settings_physical_keys_modifiers_retained", modifiers);
            check("persistence_settings_empty_bindings_retained", deliberateEmpty);
            check("persistence_settings_legacy_duplicate_bindings_retained", duplicates);
            check("persistence_settings_achievement_presence_semantics", achievementsPresence);
            var source = Encoding.UTF8.GetBytes("[future]\nscript=Object(Script,\"source_code\":\"must never execute\")\n");
            var inert = SafeConfigDocument.Parse(source); source[0] = 0;
            var returned = inert.SourceBytes; returned[0] = 0;
            check("persistence_settings_no_object_instantiation", inert.Root.Require("future").Require("script").Require("$fields").Require("$class").AsString() == "Script");
            check("persistence_settings_original_bytes_immutable", inert.SourceBytes[0] == '[');
            bool deepRejected = false, utfRejected = false;
            try { SafeConfigDocument.Parse(Encoding.UTF8.GetBytes("[s]\na=" + new string('[', 66) + "0" + new string(']', 66))); } catch (FormatException) { deepRejected = true; }
            try { SafeConfigDocument.Parse(new byte[] { 0xff, 0xfe, 0xff }); } catch (FormatException) { utfRejected = true; }
            check("persistence_settings_bounded_untrusted_config", deepRejected && utfRejected);
            VerifyEvents(check, importer);
        }
        static bool Equal(FoundationValue actual, FoundationValue expected)
        {
            if ((actual.Kind == "dictionary" || actual.Kind == "object") && (expected.Kind == "dictionary" || expected.Kind == "object"))
                return actual.Entries.Count == expected.Entries.Count && actual.Entries.All(p => expected.TryGet(p.Key.AsString(), out var item) && Equal(p.Value, item));
            if (actual.Kind == "array" && expected.Kind == "array") return actual.Items.Count == expected.Items.Count && actual.Items.Where((v, i) => !Equal(v, expected.Items[i])).Count() == 0;
            if ((actual.Kind == "int" || actual.Kind == "float") && (expected.Kind == "int" || expected.Kind == "float")) return actual.AsDouble() == expected.AsDouble();
            return actual.Kind == expected.Kind && (actual.Kind == "string" ? actual.AsString() == expected.AsString() : actual.Kind == "bool" ? actual.AsBool() == expected.AsBool() : actual.Kind == "nil");
        }
        static void VerifyEvents(Action<string, bool> check, LegacySaveImporter importer)
        {
            var oldMode = InputSystem.settings.updateMode; bool oldCursor = Cursor.visible; var owned = new List<InputDevice>();
            try
            {
                InputSystem.settings.updateMode = InputSettings.UpdateMode.ProcessEventsManually;
                var keyboard = InputSystem.AddDevice<Keyboard>("Phase9ImportedKeyboard"); owned.Add(keyboard);
                using (var input = new PlayerInputSource(owned))
                {
                    var controlBytes = Encoding.UTF8.GetBytes("[keyboard]\nattack=[Object(InputEventKey,\"physical_keycode\":81,\"shift_pressed\":true,\"ctrl_pressed\":true)]\n");
                    var bundle = LegacySettingsBundle.Decode(null, controlBytes, null, null, input, importer, "nl", "en");
                    bundle.ApplyBindings(input); int notifications = 0; input.BindingsChanged += () => notifications++;
                    InputFrame Keys(params Key[] keys) { InputSystem.QueueStateEvent(keyboard, new KeyboardState(keys)); InputSystem.Update(); return input.Read(); }
                    Keys(); bool plain = !Keys(Key.Q).Held("attack"); Keys(); bool controlOnly = !Keys(Key.Q, Key.LeftCtrl).Held("attack"); Keys();
                    bool modified = Keys(Key.Q, Key.LeftCtrl, Key.LeftShift).Pressed("attack"); Keys();
                    check("persistence_settings_imported_real_keyboard_modifiers", plain && controlOnly && modified);
                    var encoded = LegacySettingsBundle.BindingValue(input); string result = input.Rebind("attack", "keyboard", "<Keyboard>/f9");
                    LegacySettingsBundle.ApplyBindingValue(input, FoundationJson.Parse(encoded.CanonicalJson));
                    bool restored = input.Bindings("attack").Any(b => b.category == "keyboard" && b.path == "<Keyboard>/q" && b.shift && b.ctrl);
                    input.ResetBindings("keyboard");
                    check("persistence_settings_rebind_restore_notifications", result == "" && restored && notifications == 3);
                    bool rejected = false; var invalid = input.Oracle.defaults.ToDictionary(a => a.id, a => input.Bindings(a.id).Select(b => b.Copy()).ToArray());
                    invalid["ui_cancel"] = Array.Empty<InputBindingSpec>();
                    try { input.ApplyImportedBindings(invalid); } catch (FormatException) { rejected = true; }
                    check("persistence_settings_import_cannot_remove_fixed_menu_controls", rejected && input.Bindings("ui_cancel").Count > 0);
                }
            }
            finally { foreach (var device in owned) if (device.added) InputSystem.RemoveDevice(device); InputSystem.settings.updateMode = oldMode; Cursor.visible = oldCursor; }
        }
    }
}
