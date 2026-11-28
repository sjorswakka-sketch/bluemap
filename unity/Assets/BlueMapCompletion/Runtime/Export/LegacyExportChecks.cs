using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UnityEngine;
using BlueMapMigration.Foundation;

namespace BlueMapMigration.Persistence
{
    /// <summary>
    /// Proof of the way back: every recorded original save is imported, written back in Godot's form and read again.
    /// The bytes written here are the bytes the real Godot 4.4.1 loaded when the return oracle was recorded.
    /// </summary>
    public static class LegacyExportChecks
    {
        public static int Cases { get; private set; }
        /// <summary>The written saves by case id, for the recorder that lets the real Godot game load them.</summary>
        public static IReadOnlyDictionary<string, string> Written => written;
        static readonly Dictionary<string, string> written = new Dictionary<string, string>(StringComparer.Ordinal);

        public static void Verify(FoundationWorldRepository repository, Action<string, bool> check, bool requireRecorded = true)
        {
            var importer = new LegacySaveImporter(repository);
            var oracle = FoundationJson.ParsePlain(Resources.Load<TextAsset>("BlueMapSaveOracle").text);
            var recorded = new Dictionary<string, FoundationValue>(StringComparer.Ordinal);
            var asset = Resources.Load<TextAsset>("BlueMapExportOracle");
            if (asset != null)
            {
                var document = FoundationJson.ParsePlain(asset.text);
                if (document.Require("schema").AsString() != "bluemap.persistence.export.source-oracle.v1") throw new FormatException("Unknown return oracle.");
                foreach (var row in document.Require("cases").Items)
                {
                    if (!row.Require("godotAccepted").AsBool() || !row.Require("godotStateEqualsOriginal").AsBool()) throw new FormatException("Return oracle holds a refused case.");
                    recorded.Add(row.Require("id").AsString(), row);
                }
            }
            else if (requireRecorded) throw new FormatException("Missing recorded return oracle.");
            Cases = 0; written.Clear();
            foreach (var sourceCase in oracle.Require("cases").Items)
            {
                string id = sourceCase.Require("id").AsString();
                var first = importer.Import(Encoding.UTF8.GetBytes(sourceCase.Require("inputJson").AsString()));
                var export = LegacySaveExporter.Export(first.State.Snapshot());
                written[id] = Encoding.UTF8.GetString(export.SaveJson);
                // Godot fills in what an old save left out the first time it saves; after that nothing moves any more.
                var again = importer.Import(export.SaveJson);
                var second = LegacySaveExporter.Export(again.State.Snapshot());
                var third = importer.Import(second.SaveJson);
                string difference = Difference(again.State.Snapshot(), third.State.Snapshot(), id);
                if (difference != null) throw new InvalidOperationException("Return to Godot keeps changing progress: " + difference);
                check("completion_export_roundtrip_" + id, export.UnknownToGodot.Count == 0 && again.State.Fields.Count == 34);
                if (requireRecorded || recorded.Count > 0)
                {
                    // The real Godot loaded exactly these bytes and reached the same state as after its own save.
                    bool same = recorded.TryGetValue(id, out var row) && row.Require("sha256").AsString() == export.Sha256;
                    string differs = same ? LegacySaveChecks.Difference(again.State.Snapshot(), row.Require("expected"), id) : "bytes differ from the recorded return";
                    if (differs != null) throw new InvalidOperationException("Return differs from the recorded Godot load: " + differs);
                    check("completion_export_godot_loaded_" + id, true);
                }
                Cases++;
            }
            check("completion_export_all_original_cases", Cases == 24 && (!requireRecorded || recorded.Count == Cases));
            // A field Godot does not know is written and reported, never dropped in silence.
            var extended = importer.Import(Encoding.UTF8.GetBytes("{\"coins\":7}")).State.Snapshot();
            var pairs = extended.Entries.ToList(); pairs.Add(new KeyValuePair<FoundationValue, FoundationValue>(FoundationValue.StringValue("unity_only"), FoundationValue.Integer(3)));
            var extra = LegacySaveExporter.Export(FoundationValue.Object(pairs));
            var parsed = FoundationJson.ParsePlain(Encoding.UTF8.GetString(extra.SaveJson));
            check("completion_export_reports_unknown_fields", extra.UnknownToGodot.Count == 1 && extra.UnknownToGodot[0] == "unity_only"
                && parsed.Require("unity_only").AsInt64() == 3 && parsed.Entries.Count == 35 && parsed.Entries[0].Key.AsString() == "version" && parsed.Entries[33].Key.AsString() == "ng_plus");
            // Earned achievements kept as a dictionary by an older Unity profile return as Godot's list.
            var legacyPairs = extended.Entries.Select(row => row.Key.AsString() == "achievements"
                ? new KeyValuePair<FoundationValue, FoundationValue>(row.Key, FoundationValue.Object(new Dictionary<string, FoundationValue> { { "first_blood", FoundationValue.Boolean(true) }, { "nooit", FoundationValue.Boolean(false) } }))
                : row).ToList();
            var listed = FoundationJson.ParsePlain(Encoding.UTF8.GetString(LegacySaveExporter.Export(FoundationValue.Object(legacyPairs)).SaveJson)).Require("achievements");
            check("completion_export_lists_achievements", listed.Kind == "array" && listed.Items.Count == 1 && listed.Items[0].AsString() == "first_blood");
            bool refused = false; try { LegacySaveExporter.Export(FoundationValue.Object(new Dictionary<string, FoundationValue> { { "coins", FoundationValue.Integer(1) } })); } catch (FormatException) { refused = true; }
            check("completion_export_refuses_incomplete_state", refused);
        }

        /// <summary>Compares content; the order of names inside a dictionary carries no meaning in a save.</summary>
        static string Difference(FoundationValue a, FoundationValue b, string path)
        {
            bool da = a.Kind == "object" || a.Kind == "dictionary", db = b.Kind == "object" || b.Kind == "dictionary";
            if (da || db)
            {
                if (!da || !db || a.Entries.Count != b.Entries.Count) return path + ": " + FoundationJson.StringifyPlain(a) + " -> " + FoundationJson.StringifyPlain(b);
                foreach (var entry in a.Entries)
                {
                    string key = entry.Key.AsString(); if (!b.TryGet(key, out var other)) return path + "." + key + " is missing";
                    string inner = Difference(entry.Value, other, path + "." + key); if (inner != null) return inner;
                }
                return null;
            }
            if (a.Kind != b.Kind) return path + ": " + a.Kind + " -> " + b.Kind;
            if (a.Kind == "array")
            {
                if (a.Items.Count != b.Items.Count) return path + ": length " + a.Items.Count + " -> " + b.Items.Count;
                for (int i = 0; i < a.Items.Count; i++) { string inner = Difference(a.Items[i], b.Items[i], path + "[" + i + "]"); if (inner != null) return inner; }
                return null;
            }
            string left = FoundationJson.StringifyPlain(a), right = FoundationJson.StringifyPlain(b);
            return left == right ? null : path + ": " + left + " -> " + right;
        }
    }
}
