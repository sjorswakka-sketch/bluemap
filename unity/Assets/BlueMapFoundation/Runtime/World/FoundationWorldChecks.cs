using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using UnityEngine;

namespace BlueMapMigration.Foundation
{
    public static class FoundationWorldChecks
    {
        public static void Verify(Action<string, bool> check)
        {
            var repository = FoundationWorldRepository.LoadRequired(); var tiles = new FoundationTileSet(repository);
            int cells = 0, slots = 0, registry = 0, appended = 0, disabled = 0, arrivals = 0;
            bool idsExact = true, roundtrip = true, terrainDefinitions = true, arrivalScale = true;
            var ids = new HashSet<string>(StringComparer.Ordinal);
            foreach (string map in repository.MapIds)
            {
                var snapshot = repository.Read(map);
                cells += snapshot.TerrainCells.Count; slots += snapshot.Slots.Count; arrivals += snapshot.Arrivals.Count;
                foreach (var slot in snapshot.Slots)
                {
                    if (slot.RegistryIndex.HasValue) registry++; else appended++;
                    if (!slot.Enabled) disabled++;
                    idsExact &= ids.Add(slot.StableId.ToString()) && slot.LegacySlotKey == slot.Type + ":" + map + ":" + slot.Index;
                    string original = slot.Source.CanonicalJson;
                    roundtrip &= FoundationJson.Parse(original).CanonicalJson == original;
                }
                foreach (var cell in snapshot.TerrainCells) terrainDefinitions &= tiles.Definition(cell) != null;
                foreach (var arrival in snapshot.Arrivals) arrivalScale &= FoundationCoordinates.ToGodot(FoundationCoordinates.ToUnity(arrival.Resolved)) == arrival.Resolved;
            }
            check("foundation_world_37_maps_49758_tiles", repository.MapIds.Count == 37 && cells == 49758 && tiles.Count == 640 && terrainDefinitions);
            check("foundation_world_980_stable_slots", slots == 980 && registry == 905 && appended == 75 && disabled == 10 && idsExact && roundtrip);
            check("foundation_world_arrival_coordinate_roundtrip", arrivals > 0 && arrivalScale);
            var before = repository.Load("village");
            bool staged = repository.Read("forest").MapId == "forest" && ReferenceEquals(before, repository.Current);
            bool failed = !repository.TryLoad("unknown_map", "fresh_baseline", out string diagnostic) && !string.IsNullOrEmpty(diagnostic) && ReferenceEquals(before, repository.Current);
            check("foundation_world_atomic_failed_and_staged_load", staged && failed);
            bool scenarios = repository.ScenarioIds.Count == 59; int snapshotsDecoded = repository.MapIds.Count;
            foreach (var row in repository.Index.Require("snapshots").Items)
            {
                string scenario = row.Require("scenarioId").AsString();
                if (scenario == "fresh_baseline") continue;
                string mapId = row.Require("mapId").AsString();
                var loaded = repository.Read(mapId, scenario);
                scenarios &= loaded.MapId == mapId && loaded.ScenarioId == scenario;
                snapshotsDecoded++;
            }
            var progressed = repository.Read("village", "full_progress");
            check("foundation_world_162_scenarios_addressable", scenarios && snapshotsDecoded == 162 && progressed.ScenarioId == "full_progress" && progressed.MapId == before.MapId && !ReferenceEquals(before, progressed));
            int sourceDocuments = 0;
            foreach (string sourcePath in repository.DocumentPaths)
                if (!sourcePath.StartsWith("migration/world/snapshots/", StringComparison.Ordinal) && sourcePath != "migration/world/index.json" && sourcePath != "migration/world/tile-set.json")
                { repository.ReadDocument(sourcePath); sourceDocuments++; }
            check("foundation_all_221_source_documents_native_decoded", sourceDocuments + snapshotsDecoded + 2 == 221);
            var identityMetadata = repository.ReadDocument("migration/portable/identity.json");
            var declaration = identityMetadata.Require("declarations").Items[0];
            var ruleMetadata = repository.ReadDocument("migration/portable/rules.json");
            var invocation = ruleMetadata.Require("usage").Require("invocations").Items[0];
            bool metadataContext = identityMetadata.Require("declarations").Items.Count == 377
                && declaration.Kind == "object" && declaration.Entries.Count == 5
                && declaration.Require("kind").String == "dictionary"
                && declaration.Require("namespace").Items[1].String == "res://scripts/core/appearance.gd"
                && declaration.Require("source").Require("constant").String == "DEFAULT"
                && declaration.Require("entries").Items[0].Require("id").String == "gender"
                && declaration.Require("declarationFingerprint").String == "db35d2f9ff65b7936c96003069ff4ee337afb954491cb3a8ea8b83475a37921a"
                && invocation.Kind == "object" && invocation.Require("kind").String == "conditions"
                && invocation.Require("invocation").Items[0].String == "kinds_killed"
                && FoundationJson.ParseDocument(identityMetadata.CanonicalJson, "migration/portable/identity.json").CanonicalJson == identityMetadata.CanonicalJson
                && FoundationJson.ParseDocument(ruleMetadata.CanonicalJson, "migration/portable/rules.json").CanonicalJson == ruleMetadata.CanonicalJson;
            check("foundation_metadata_kind_document_context_lossless", metadataContext);
            var numbers = FoundationJson.Parse("{\"kind\":\"array\",\"values\":[{\"kind\":\"int\",\"value\":\"9223372036854775807\"},{\"kind\":\"int\",\"value\":\"9007199254740993\"},{\"kind\":\"float\",\"value\":\"-0.0\"},{\"kind\":\"float\",\"value\":\"0.10000000000000002\"}]}");
            check("foundation_variant_int64_and_double_bits", numbers.Items[0].Int64 == long.MaxValue && numbers.Items[1].Int64 == 9007199254740993L && numbers.Items[2].DoubleBits == 0x8000000000000000UL && numbers.Items[3].DoubleBits == unchecked((ulong)BitConverter.DoubleToInt64Bits(0.10000000000000002)) && FoundationJson.Parse(numbers.CanonicalJson).CanonicalJson == numbers.CanonicalJson);
            bool rejects = Rejects(() => FoundationJson.Parse("{\"kind\":\"future_engine_object\"}"))
                && Rejects(() => FoundationJson.Parse("{\"a\":1,\"a\":2}"))
                && Rejects(() => FoundationJson.Parse("{\"kind\":\"int\",\"value\":\"9223372036854775808\"}"))
                && Rejects(() => FoundationJson.Parse("{\"kind\":\"int\",\"value\":\"3\",\"future\":4}"))
                && Rejects(() => FoundationJson.Parse("{\"kind\":\"array\",\"values\":[{\"kind\":\"future_engine_object\"}]}"))
                && Rejects(() => FoundationJson.ParseDocument(identityMetadata.CanonicalJson, "migration/portable/catalogs/identity.json"))
                && Rejects(() => FoundationJson.ParseDocument("{\"schema\":\"bluemap.migration.identity.v2\",\"schemaVersion\":1,\"phase\":4}", "migration/portable/identity.json"))
                && Rejects(() => FoundationJson.Parse("{\"kind\":\"vector\",\"type\":\"Vector2i\",\"values\":[{\"kind\":\"float\",\"value\":\"1.0\"},{\"kind\":\"int\",\"value\":\"2\"}]}"))
                && Rejects(() => FoundationJson.Parse("\"\\ud800\""));
            check("foundation_variant_unknown_and_malformed_fail_closed", rejects);
            byte[] small;
            using (var stream = new MemoryStream()) { using (var gzip = new GZipStream(stream, System.IO.Compression.CompressionLevel.Optimal, true)) gzip.Write(new byte[] { 1, 2, 3 }, 0, 3); small = stream.ToArray(); }
            check("foundation_gzip_exact_decompression_bound", FoundationWorldRepository.Inflate(small, 3).Length == 3 && Rejects(() => FoundationWorldRepository.Inflate(small, 2)) && Rejects(() => FoundationWorldRepository.Inflate(small, 4)));
            Rect converted = FoundationCoordinates.RectToUnity(new Rect(32, 64, 64, 96));
            Rect atlas = FoundationCoordinates.AtlasRect(new Rect(32, 64, 64, 96), 256);
            check("foundation_32px_rect_pivot_and_axis_adapter", converted == new Rect(1, -5, 2, 3) && atlas == new Rect(32, 96, 64, 96) && FoundationCoordinates.Pivot(new Vector2(16, 8), 32, 32) == new Vector2(.5f, .75f) && FoundationCoordinates.TileCenter(2, 3) == new Vector2(2.5f, -3.5f));
            var solid = new GameObject("Foundation native solid collision proof");
            var player = new GameObject("Foundation native player collision proof");
            var decoration = new GameObject("Foundation native zero-membership proof");
            var enemy = new GameObject("Foundation native enemy mask proof");
            SimulationMode2D originalMode = Physics2D.simulationMode;
            try
            {
                solid.transform.position = new Vector3(-300, -300, 0); player.transform.position = new Vector3(-302, -300, 0); decoration.transform.position = new Vector3(-304, -300, 0);
                var wall = FoundationCollision.Box(solid, new Rect(-16, -16, 32, 32), 1, 1);
                var foot = FoundationCollision.Circle(player, new Vector2(0, 8), 7, 2, 1);
                var zero = FoundationCollision.Box(decoration, new Rect(-16, -16, 32, 32), 0, 0);
                Physics2D.SyncTransforms();
                bool native = Physics2D.OverlapPoint(solid.transform.position, FoundationCollision.Mask(1)) == wall
                    && Physics2D.OverlapPoint(player.transform.position + new Vector3(0, -.25f), FoundationCollision.Mask(2)) == foot
                    && Physics2D.OverlapPoint(decoration.transform.position, FoundationCollision.Mask(1 | 2 | 4)) != zero;
                native &= foot.radius == 7f / 32f && foot.offset == new Vector2(0, -.25f) && wall.size == Vector2.one;
                native &= FoundationCollision.GodotCanPair(2, 1, 1, 0) && !FoundationCollision.GodotCanPair(2, 0, 1, 0);
                native &= solid.GetComponent<FoundationCollisionBits>().sourceLayer == 1 && player.GetComponent<FoundationCollisionBits>().sourceMask == 1;
                check("foundation_native_physics_layers_and_player_foot", native);
                player.transform.position = solid.transform.position + new Vector3(.55f, .25f, 0);
                enemy.transform.position = solid.transform.position + new Vector3(-.55f, .25f, 0);
                var enemyFoot = FoundationCollision.Circle(enemy, new Vector2(0, 8), 7, 4, 1);
                var playerBody = player.AddComponent<Rigidbody2D>(); playerBody.gravityScale = 0; playerBody.constraints = RigidbodyConstraints2D.FreezeRotation;
                var enemyBody = enemy.AddComponent<Rigidbody2D>(); enemyBody.gravityScale = 0; enemyBody.constraints = RigidbodyConstraints2D.FreezeRotation;
                Physics2D.SyncTransforms(); Physics2D.simulationMode = SimulationMode2D.Script; Physics2D.Simulate(1f / 60f);
                bool contact = foot.IsTouching(wall) && enemyFoot.IsTouching(wall) && !foot.IsTouching(enemyFoot)
                    && Physics2D.GetIgnoreCollision(foot, enemyFoot) && !Physics2D.GetIgnoreCollision(foot, wall)
                    && Physics2D.GetIgnoreCollision(zero, foot) && Physics2D.GetIgnoreCollision(zero, wall);
                check("foundation_native_godot_or_masks_real_contacts", contact);
                bool invalid = Rejects(() => FoundationCollision.Box(decoration, new Rect(0, 0, 0, 32), 1, 1))
                    && Rejects(() => FoundationCollision.Circle(decoration, Vector2.zero, float.NaN, 1, 1))
                    && Rejects(() => FoundationCollision.Box(decoration, new Rect(0, 0, 32, 32), 3, 1));
                check("foundation_invalid_collider_has_no_partial_mutation", invalid && decoration.GetComponents<Collider2D>().Length == 1);
            }
            finally { Physics2D.simulationMode = originalMode; solid.SetActive(false); player.SetActive(false); decoration.SetActive(false); enemy.SetActive(false); UnityEngine.Object.Destroy(solid); UnityEngine.Object.Destroy(player); UnityEngine.Object.Destroy(decoration); UnityEngine.Object.Destroy(enemy); }
        }
        private static bool Rejects(Action action)
        {
            try { action(); return false; } catch (Exception error) when (error is FormatException || error is IOException || error is OverflowException) { return true; }
        }
    }
}
