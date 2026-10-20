using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;

namespace BlueMapMigration.Foundation
{
    // Namespace components and identity are separate; labels never become save IDs.
    public sealed class FoundationStableId
    {
        public IReadOnlyList<string> Namespace { get; }
        public string Id { get; }
        public FoundationStableId(IEnumerable<string> scope, string id)
        {
            Namespace = new ReadOnlyCollection<string>(new List<string>(scope)); Id = id ?? throw new ArgumentNullException(nameof(id));
        }
        public override string ToString() => FoundationValue.Object(new Dictionary<string, FoundationValue>
        { { "namespace", FoundationValue.Array(NamespaceValues()) }, { "id", FoundationValue.StringValue(Id) } }).CanonicalJson;
        private IEnumerable<FoundationValue> NamespaceValues() { foreach (string component in Namespace) yield return FoundationValue.StringValue(component); }
    }
    public sealed class FoundationObjectSlot
    {
        public int Index { get; }
        public string Type { get; }
        public bool Enabled { get; }
        public bool ConditionsPassed { get; }
        public string LegacySlotKey { get; }
        public int? RegistryIndex { get; }
        public int? AppendOrder { get; }
        public FoundationStableId StableId { get; }
        public FoundationValue Source { get; }
        internal FoundationObjectSlot(string mapId, FoundationValue source)
        {
            Source = source; Index = checked((int)source.Require("index").AsInt64()); Type = source.Require("type").AsString();
            Enabled = source.Require("enabled").AsBool(); ConditionsPassed = source.Require("conditionsPassed").AsBool();
            LegacySlotKey = source.Require("legacySlotKey").AsString();
            var registry = source.Require("registryIndex"); RegistryIndex = registry.Kind == "nil" ? (int?)null : checked((int)registry.AsInt64());
            var append = source.Require("appendOrder"); AppendOrder = append.Kind == "nil" ? (int?)null : checked((int)append.AsInt64());
            // The slot identity is structural. Actual custom resource/altar save IDs stay in Raw/runtime-identities.
            StableId = new FoundationStableId(new[] { "map_object_slot", mapId }, Index.ToString(System.Globalization.CultureInfo.InvariantCulture));
            if (LegacySlotKey != Type + ":" + mapId + ":" + Index.ToString(System.Globalization.CultureInfo.InvariantCulture)) throw new FormatException("World slot legacy key changed.");
        }
    }
    public sealed class FoundationTerrainCell
    {
        public int X { get; }
        public int Y { get; }
        public int SourceId { get; }
        public int AtlasX { get; }
        public int AtlasY { get; }
        public int Alternative { get; }
        internal FoundationTerrainCell(FoundationValue value)
        {
            if (value.Items.Count != 6) throw new FormatException("World terrain cell shape changed.");
            X = checked((int)value.Items[0].AsInt64()); Y = checked((int)value.Items[1].AsInt64()); SourceId = checked((int)value.Items[2].AsInt64());
            AtlasX = checked((int)value.Items[3].AsInt64()); AtlasY = checked((int)value.Items[4].AsInt64()); Alternative = checked((int)value.Items[5].AsInt64());
        }
    }
    public sealed class FoundationArrival
    {
        public string Name { get; }
        public Vector2 Nominal { get; }
        public Vector2 Resolved { get; }
        public bool Fits { get; }
        public FoundationValue Source { get; }
        internal FoundationArrival(FoundationValue source)
        {
            Source = source; Name = source.Require("name").AsString(); Nominal = FoundationCoordinates.Vector(source.Require("nominal"));
            Resolved = FoundationCoordinates.Vector(source.Require("resolved")); Fits = source.Require("fits").AsBool();
        }
    }
    public sealed class FoundationWorldSnapshot
    {
        public string MapId { get; }
        public string ScenarioId { get; }
        public FoundationValue Root { get; }
        public FoundationValue MapData => Root.Require("mapData");
        public FoundationValue StateAfter => Root.Require("stateAfter");
        public IReadOnlyList<FoundationObjectSlot> Slots { get; }
        public IReadOnlyList<FoundationTerrainCell> TerrainCells { get; }
        public IReadOnlyList<FoundationArrival> Arrivals { get; }
        public int Width => MapData.Require("rows").Items.Count == 0 ? 0 : MapData.Require("rows").Items[0].AsString().Length;
        public int Height => MapData.Require("rows").Items.Count;
        internal FoundationWorldSnapshot(FoundationValue source, string expectedMap, string expectedScenario)
        {
            Root = source; MapId = source.Require("mapId").AsString(); ScenarioId = source.Require("scenarioId").AsString();
            if (source.Require("schema").AsString() != "bluemap.migration.world-snapshot.v1" || MapId != expectedMap || ScenarioId != expectedScenario || source.Require("stage").AsString() != "loaded_projection") throw new FormatException("World snapshot identity/schema mismatch.");
            if (source.Require("units").Require("tilePixels").AsInt64() != 32 || source.Require("units").Require("yAxis").AsString() != "down") throw new FormatException("World snapshot coordinate contract changed.");
            var slots = new List<FoundationObjectSlot>(); var identities = new HashSet<string>(StringComparer.Ordinal);
            foreach (var slot in source.Require("slots").Items)
            {
                var result = new FoundationObjectSlot(MapId, slot);
                if (result.Index != slots.Count || !identities.Add(result.StableId.ToString())) throw new FormatException("World object slots were reordered or duplicated."); slots.Add(result);
            }
            Slots = new ReadOnlyCollection<FoundationObjectSlot>(slots);
            var cells = new List<FoundationTerrainCell>(); var coordinates = new HashSet<long>();
            foreach (var cell in source.Require("terrain").Require("cells").Items)
            {
                var result = new FoundationTerrainCell(cell);
                if (result.X < 0 || result.Y < 0 || result.X >= Width || result.Y >= Height || !coordinates.Add(((long)result.X << 32) | (uint)result.Y)) throw new FormatException("Invalid/duplicate terrain coordinates."); cells.Add(result);
            }
            if (cells.Count != Width * Height) throw new FormatException("World terrain does not cover its map.");
            TerrainCells = new ReadOnlyCollection<FoundationTerrainCell>(cells);
            var arrivals = new List<FoundationArrival>(); var names = new HashSet<string>(StringComparer.Ordinal);
            foreach (var arrival in source.Require("arrivals").Items)
            {
                var result = new FoundationArrival(arrival); if (!names.Add(result.Name)) throw new FormatException("Duplicate world arrival."); arrivals.Add(result);
            }
            Arrivals = new ReadOnlyCollection<FoundationArrival>(arrivals);
        }
    }

    public sealed class FoundationWorldRepository
    {
        public const string ManifestPath = "BlueMapFoundation/manifest";
        private readonly Dictionary<string, FoundationValue> documents = new Dictionary<string, FoundationValue>(StringComparer.Ordinal);
        private readonly Dictionary<string, string> snapshotPaths = new Dictionary<string, string>(StringComparer.Ordinal);
        private readonly Func<string, byte[]> loadBytes;
        private FoundationWorldSnapshot staged;
        public IReadOnlyList<string> MapIds { get; }
        public IReadOnlyList<string> ScenarioIds { get; }
        public IReadOnlyList<string> DocumentPaths { get; }
        public FoundationValue Index { get; }
        public FoundationWorldSnapshot Current { get; private set; }
        public static FoundationWorldRepository LoadRequired()
        {
            TextAsset manifest = Resources.Load<TextAsset>(ManifestPath);
            if (manifest == null) throw new InvalidOperationException("BlueMap foundation manifest is missing.");
            return new FoundationWorldRepository(manifest.text, path =>
            {
                TextAsset file = Resources.Load<TextAsset>(path);
                if (file == null) throw new FormatException("Missing foundation resource: " + path);
                byte[] bytes = file.bytes; Resources.UnloadAsset(file); return bytes;
            });
        }
        public FoundationWorldRepository(string manifestJson, Func<string, byte[]> byteProvider)
        {
            loadBytes = byteProvider ?? throw new ArgumentNullException(nameof(byteProvider));
            var manifest = FoundationJson.Parse(manifestJson);
            if (manifest.Require("schema").AsString() != "bluemap.foundation.package.v1" || manifest.Require("phase").AsInt64() != 7 || manifest.Require("tilePixels").AsInt64() != 32) throw new FormatException("Unknown foundation package schema.");
            foreach (var row in manifest.Require("documents").Items)
            {
                string path = row.Require("sourcePath").AsString();
                if (documents.ContainsKey(path) || !SafePath(path)) throw new FormatException("Invalid/duplicate foundation document.");
                string resource = row.Require("resourcePath").AsString();
                if (!SafePath(resource) || !resource.StartsWith("BlueMapFoundation/", StringComparison.Ordinal)) throw new FormatException("Unsafe foundation resource path.");
                documents.Add(path, row);
            }
            DocumentPaths = new ReadOnlyCollection<string>(new List<string>(documents.Keys));
            Index = ReadDocument("migration/world/index.json");
            if (Index.Require("schema").AsString() != "bluemap.migration.world-index.v1" || Index.Require("valueEncoding").AsString() != "bluemap.world.variant.v2") throw new FormatException("Unknown world index schema.");
            var maps = new SortedSet<string>(StringComparer.Ordinal); var scenarios = new List<string>();
            foreach (var row in Index.Require("scenarios").Items) scenarios.Add(row.Require("id").AsString());
            foreach (var row in Index.Require("snapshots").Items)
            {
                string map = row.Require("mapId").AsString(), scenario = row.Require("scenarioId").AsString();
                string key = Key(map, scenario);
                if (snapshotPaths.ContainsKey(key)) throw new FormatException("Duplicate world scenario/map pair.");
                snapshotPaths.Add(key, "migration/world/" + row.Require("path").AsString()); if (scenario == "fresh_baseline") maps.Add(map);
            }
            if (maps.Count != 37 || scenarios.Count != 59 || snapshotPaths.Count != 162) throw new FormatException("World coverage is incomplete.");
            MapIds = new ReadOnlyCollection<string>(new List<string>(maps)); ScenarioIds = new ReadOnlyCollection<string>(scenarios);
        }
        private static bool SafePath(string path)
        {
            if (string.IsNullOrEmpty(path) || path[0] == '/' || path.Contains("\\") || path.Contains(":")) return false;
            foreach (string part in path.Split('/')) if (part == "" || part == "." || part == "..") return false; return true;
        }
        private static string Key(string map, string scenario) => scenario + "\0" + map;
        public FoundationValue ReadDocument(string sourcePath)
        {
            if (!documents.TryGetValue(sourcePath, out var row)) throw new FormatException("Unknown foundation document: " + sourcePath);
            byte[] compressed = loadBytes(row.Require("resourcePath").AsString());
            if (compressed == null || compressed.LongLength != row.Require("gzipBytes").AsInt64() || Hash(compressed) != row.Require("gzipSha256").AsString()) throw new FormatException("Corrupt foundation compressed resource: " + sourcePath);
            int expected = checked((int)row.Require("bytes").AsInt64());
            if (expected <= 0 || expected > 128 * 1024 * 1024) throw new FormatException("Foundation document exceeds decompression bound.");
            byte[] data = Inflate(compressed, expected);
            if (Hash(data) != row.Require("sha256").AsString()) throw new FormatException("Foundation source SHA256 mismatch: " + sourcePath);
            return FoundationJson.Parse(new UTF8Encoding(false, true).GetString(data));
        }
        public static byte[] Inflate(byte[] compressed, int expectedBytes)
        {
            if (compressed == null || expectedBytes <= 0 || expectedBytes > 128 * 1024 * 1024) throw new FormatException("Invalid foundation decompression bound.");
            var result = new byte[expectedBytes];
            using (var memory = new MemoryStream(compressed, false)) using (var stream = new GZipStream(memory, CompressionMode.Decompress))
            {
                int offset = 0; while (offset < result.Length) { int count = stream.Read(result, offset, result.Length - offset); if (count == 0) throw new FormatException("Truncated foundation gzip."); offset += count; }
                if (stream.ReadByte() != -1) throw new FormatException("Foundation gzip expansion exceeded its exact byte count.");
            }
            return result;
        }
        public static string Hash(byte[] data)
        {
            using (var algorithm = SHA256.Create()) { byte[] hash = algorithm.ComputeHash(data); var text = new StringBuilder(64); foreach (byte value in hash) text.Append(value.ToString("x2")); return text.ToString(); }
        }
        // Read stages a fully validated immutable value. Failed lookup/parse cannot replace Current.
        public FoundationWorldSnapshot Read(string mapId, string scenarioId = "fresh_baseline")
        {
            if (mapId == null || scenarioId == null || !snapshotPaths.TryGetValue(Key(mapId, scenarioId), out var path)) throw new FormatException("Unknown world map/scenario: " + mapId + "/" + scenarioId);
            if (staged != null && staged.MapId == mapId && staged.ScenarioId == scenarioId) return staged;
            if (Current != null && Current.MapId == mapId && Current.ScenarioId == scenarioId) return Current;
            var prepared = new FoundationWorldSnapshot(ReadDocument(path), mapId, scenarioId);
            staged = prepared; return prepared;
        }
        public FoundationWorldSnapshot Load(string mapId, string scenarioId = "fresh_baseline") { var next = Read(mapId, scenarioId); Current = next; return next; }
        public bool TryLoad(string mapId, string scenarioId, out string diagnostic)
        {
            try { Load(mapId, scenarioId); diagnostic = ""; return true; }
            catch (Exception error) when (error is FormatException || error is IOException || error is OverflowException) { diagnostic = error.Message; return false; }
        }
    }
}
