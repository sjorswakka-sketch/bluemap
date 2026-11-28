using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using BlueMapMigration.Foundation;

namespace BlueMapMigration.Persistence
{
    /// <summary>What a return to Godot contains, and what Godot does not know.</summary>
    public sealed class LegacySaveExport
    {
        public byte[] SaveJson { get; }
        public string Sha256 { get; }
        /// <summary>Fields the Godot game does not know. They are written too, so nothing is dropped silently, but Godot ignores them.</summary>
        public IReadOnlyList<string> UnknownToGodot { get; }
        public LegacySaveExport(byte[] json, IReadOnlyList<string> unknown)
        {
            SaveJson = json; UnknownToGodot = unknown;
            using (var hash = SHA256.Create()) Sha256 = BitConverter.ToString(hash.ComputeHash(json)).Replace("-", "").ToLowerInvariant();
        }
    }

    /// <summary>
    /// Writes Unity progress back in the form GameState.save_game writes: the same 34 fields in the same order.
    /// It only builds bytes in memory; it never looks for, opens or overwrites a Godot save itself.
    /// </summary>
    public static class LegacySaveExporter
    {
        public const string FileName = "savegame.json";
        // The order GameState.save_game writes; ng_plus is appended last there as well.
        public static readonly IReadOnlyList<string> SourceOrder = Array.AsReadOnly(new[] {
            "version", "map", "pos", "hp", "coins", "inventory", "flags", "quests", "weapon", "visited_maps",
            "play_time", "kills", "meer", "day_time", "day_count", "kills_by", "rolls", "potions_drunk", "deaths",
            "boss_deaths", "talked", "achievements", "arena_records", "homestead", "coastal_storage", "stockroom",
            "personal_home", "yard", "professions", "hero_xp", "equipment", "appearance", "clothing", "ng_plus"
        });

        public static LegacySaveExport Export(FoundationValue state)
        {
            if (state == null) throw new ArgumentNullException(nameof(state));
            if (state.Kind != "object" && state.Kind != "dictionary") throw new FormatException("Only a complete game state can return to Godot.");
            var pairs = new List<KeyValuePair<FoundationValue, FoundationValue>>();
            foreach (string key in SourceOrder)
            {
                if (!state.TryGet(key, out var value)) throw new FormatException("Game state misses a field Godot needs: " + key);
                if (key == "talked" || key == "achievements") value = Names(value);
                pairs.Add(new KeyValuePair<FoundationValue, FoundationValue>(FoundationValue.StringValue(key), Written(value, 0)));
            }
            var known = new HashSet<string>(SourceOrder, StringComparer.Ordinal); var unknown = new List<string>();
            foreach (var entry in state.Entries)
            {
                string key = entry.Key.AsString(); if (known.Contains(key)) continue;
                unknown.Add(key); pairs.Add(entry);
            }
            unknown.Sort(StringComparer.Ordinal);
            string json = FoundationJson.StringifyPlain(FoundationValue.Object(pairs));
            return new LegacySaveExport(new UTF8Encoding(false).GetBytes(json), unknown.AsReadOnly());
        }

        /// <summary>Godot's own JSON writer does not keep the sign of a zero; neither does the way back.</summary>
        static FoundationValue Written(FoundationValue value, int depth)
        {
            if (depth > 64) throw new FormatException("Game state is nested too deeply to return to Godot.");
            if (value.Kind == "float") return value.AsDouble() == 0 && value.DoubleBits != 0 ? FoundationValue.Number(0.0) : value;
            if (value.Kind == "array") return FoundationValue.Array(value.Items.Select(item => Written(item, depth + 1)));
            if (value.Kind == "object" || value.Kind == "dictionary")
                return FoundationValue.Object(value.Entries.Select(row => new KeyValuePair<FoundationValue, FoundationValue>(row.Key, Written(row.Value, depth + 1))));
            return value;
        }

        /// <summary>Godot stores who you spoke to and what you earned as a list of names.</summary>
        static FoundationValue Names(FoundationValue value)
        {
            if (value.Kind == "array") return value;
            if (value.Kind != "object" && value.Kind != "dictionary") return FoundationValue.Array(new FoundationValue[0]);
            return FoundationValue.Array(value.Entries.Where(row => row.Value.Kind != "bool" || row.Value.AsBool()).Select(row => FoundationValue.StringValue(row.Key.AsString())));
        }
    }
}
