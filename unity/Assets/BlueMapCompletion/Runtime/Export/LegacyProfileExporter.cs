using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlueMapMigration.Foundation;

namespace BlueMapMigration.Persistence
{
    /// <summary>
    /// Builds the files a return to the Godot game needs, in a new folder of its own. It never writes into a Godot
    /// save folder: copying the files there stays a deliberate step of the player, after making a backup.
    /// </summary>
    public static class LegacyProfileExporter
    {
        public const string ReadMe = "LEESMIJ.txt";
        static readonly UTF8Encoding Utf8 = new UTF8Encoding(false);

        public static string Quote(string text) => "\"" + text.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
        static bool Simple(string id) => id.Length > 0 && id.All(c => c < 128 && (char.IsLetterOrDigit(c) || c == '_'));
        static string Key(string id) => Simple(id) ? id : Quote(id);
        static string Variant(FoundationValue value)
        {
            switch (value.Kind)
            {
                case "bool": return value.AsBool() ? "true" : "false";
                case "int": return value.AsInt64().ToString(System.Globalization.CultureInfo.InvariantCulture);
                case "float": return value.AsDouble().ToString("R", System.Globalization.CultureInfo.InvariantCulture);
                case "string": return Quote(value.AsString());
                case "object": case "dictionary":
                    return value.Entries.Count == 0 ? "{}" : "{\n" + String.Join(",\n", value.Entries.Select(row => Quote(row.Key.AsString()) + ": " + Variant(row.Value))) + "\n}";
                case "array": return "[" + String.Join(", ", value.Items.Select(Variant)) + "]";
                default: throw new FormatException("Value cannot be written for Godot: " + value.Kind);
            }
        }

        /// <summary>Every achievement ever earned, across all adventures, as meta.cfg keeps them.</summary>
        public static byte[] MetaConfig(FoundationValue state, FoundationValue preferences)
        {
            var ids = new List<string>(); var seen = new HashSet<string>(StringComparer.Ordinal);
            if (preferences != null && preferences.TryGet("achievements", out var global) && (global.Kind == "object" || global.Kind == "dictionary"))
                foreach (var row in global.Entries) if ((row.Value.Kind != "bool" || row.Value.AsBool()) && seen.Add(row.Key.AsString())) ids.Add(row.Key.AsString());
            var own = state.Require("achievements");
            foreach (string id in own.Kind == "array" ? own.Items.Where(v => v.Kind == "string").Select(v => v.AsString()) : own.Entries.Select(row => row.Key.AsString())) if (seen.Add(id)) ids.Add(id);
            var text = new StringBuilder("[achievements]\n\n"); foreach (string id in ids) text.Append(Key(id)).Append("=true\n");
            return Utf8.GetBytes(text.ToString());
        }

        /// <summary>What the game remembers of finished rounds, as ng_plus.cfg keeps it; null when nothing was finished.</summary>
        public static byte[] NgConfig(FoundationValue meta)
        {
            if (meta == null || !meta.TryGet("completed", out var completed) || completed.Kind != "bool" || !completed.AsBool()) return null;
            var text = new StringBuilder("[ng]\n\n");
            foreach (string key in new[] { "completed", "rounds", "weapon", "hearts", "boots", "hero_xp", "gear_items", "equipment" })
                if (meta.TryGet(key, out var value)) text.Append(key).Append('=').Append(Variant(value)).Append('\n');
            return Utf8.GetBytes(text.ToString());
        }

        public static Dictionary<string, byte[]> Files(PersistenceSnapshot snapshot, out LegacySaveExport save)
        {
            if (snapshot == null) throw new ArgumentNullException(nameof(snapshot));
            save = LegacySaveExporter.Export(snapshot.State);
            var files = new Dictionary<string, byte[]>(StringComparer.Ordinal) { { LegacySaveExporter.FileName, save.SaveJson }, { "meta.cfg", MetaConfig(snapshot.State, snapshot.Preferences) } };
            var ng = NgConfig(snapshot.Preferences.TryGet("ngMeta", out var meta) ? meta : null); if (ng != null) files["ng_plus.cfg"] = ng;
            // Settings and controls return exactly as they came, when this profile was once imported from Godot.
            var originals = snapshot.CopyOriginals();
            foreach (string name in new[] { "settings.cfg", "controls.cfg" }) if (originals.TryGetValue(name, out var bytes)) files[name] = bytes;
            var note = new StringBuilder();
            note.Append("BlueMap Quest - terug naar de Godot-game\n\n");
            note.Append("Deze map bevat je Unity-voortgang in de vorm die de Godot-game 0.34 leest.\n");
            note.Append("1. Sluit de Godot-game.\n2. Maak eerst een kopie van je bestaande Godot-opslagmap.\n3. Kopieer daarna de bestanden uit deze map naar die opslagmap.\n\n");
            note.Append("Bestanden: " + String.Join(", ", files.Keys.OrderBy(k => k, StringComparer.Ordinal)) + "\n");
            note.Append(save.UnknownToGodot.Count == 0 ? "Alles in deze voortgang is bekend bij de Godot-game.\n"
                : "Let op: de Godot-game kent deze onderdelen niet en slaat ze over: " + String.Join(", ", save.UnknownToGodot) + "\n");
            note.Append("\nThis folder holds your Unity progress in the form the Godot game 0.34 reads. Close the Godot game, back up your existing Godot save folder first, then copy these files into it.\n");
            files[ReadMe] = Utf8.GetBytes(note.ToString());
            return files;
        }

        /// <summary>Writes the files into a folder that does not exist yet (or is empty) and is not a Godot save folder.</summary>
        public static LegacySaveExport Write(PersistenceSnapshot snapshot, string directory)
        {
            string target = PersistencePaths.Checked(directory);
            PersistencePaths.Disjoint(PersistencePaths.LegacyDefault, target);
            if (Directory.Exists(target) && Directory.EnumerateFileSystemEntries(target).Any()) throw new IOException("De exportmap moet nieuw of leeg zijn; bestaande bestanden worden nooit overschreven.");
            var files = Files(snapshot, out var save);
            Directory.CreateDirectory(target);
            foreach (var file in files)
                using (var stream = new FileStream(Path.Combine(target, file.Key), FileMode.CreateNew, FileAccess.Write, FileShare.None)) stream.Write(file.Value, 0, file.Value.Length);
            return save;
        }
    }
}
