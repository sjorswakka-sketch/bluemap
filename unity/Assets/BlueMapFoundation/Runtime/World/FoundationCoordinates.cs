using System;
using System.Collections.Generic;
using UnityEngine;

namespace BlueMapMigration.Foundation
{
    public static class FoundationCoordinates
    {
        public const int TilePixels = 32;
        public static Vector2 Vector(FoundationValue value)
        {
            if (value.Kind != "vector" || (value.Tag != "Vector2" && value.Tag != "Vector2i") || value.Items.Count != 2) throw new FormatException("Expected a source Vector2/Vector2i.");
            return new Vector2(Finite(value.Items[0].AsDouble()), Finite(value.Items[1].AsDouble()));
        }
        private static float Finite(double value)
        {
            if (double.IsNaN(value) || double.IsInfinity(value) || Math.Abs(value) > float.MaxValue) throw new FormatException("Source coordinate cannot be represented by Unity float.");
            return (float)value;
        }
        public static Vector2 ToUnity(Vector2 godotPixels) => new Vector2(godotPixels.x / TilePixels, -godotPixels.y / TilePixels);
        public static Vector2 ToGodot(Vector2 unityUnits) => new Vector2(unityUnits.x * TilePixels, -unityUnits.y * TilePixels);
        public static Vector2 TileCenter(int x, int y) => new Vector2(x + .5f, -y - .5f);
        public static Rect RectToUnity(Rect topLeftPixels) => new Rect(topLeftPixels.x / TilePixels, -(topLeftPixels.y + topLeftPixels.height) / TilePixels, topLeftPixels.width / TilePixels, topLeftPixels.height / TilePixels);
        public static Rect AtlasRect(Rect topLeftPixels, float textureHeight) => new Rect(topLeftPixels.x, textureHeight - topLeftPixels.y - topLeftPixels.height, topLeftPixels.width, topLeftPixels.height);
        public static Vector2 Pivot(Vector2 topLeftPivotPixels, float width, float height)
        {
            if (width <= 0 || height <= 0) throw new ArgumentOutOfRangeException(nameof(width));
            return new Vector2(topLeftPivotPixels.x / width, 1f - topLeftPivotPixels.y / height);
        }
        // Conjugation by Y reflection: translation is scaled, basis vectors are not.
        public static Matrix4x4 Transform(FoundationValue source)
        {
            if (source.Kind != "transform2d") throw new FormatException("Expected source Transform2D.");
            Vector2 x = Vector(source.Require("x")), y = Vector(source.Require("y")), origin = ToUnity(Vector(source.Require("origin")));
            Matrix4x4 result = Matrix4x4.identity;
            result.m00 = x.x; result.m10 = -x.y; result.m01 = -y.x; result.m11 = y.y;
            result.m03 = origin.x; result.m13 = origin.y; return result;
        }
    }

    public sealed class FoundationCollisionBits : MonoBehaviour
    {
        public uint sourceLayer, sourceMask;
        internal bool configured;
        private void OnEnable() { if (configured) FoundationCollision.RefreshCollisionPairs(); }
    }

    public static class FoundationCollision
    {
        private static readonly List<Collider2D> ownedColliders = new List<Collider2D>();
        // Explicit namespace for the source's observed solid/player/enemy bits.
        // Source masks themselves remain uint32 data; unimplemented bits reject instead of collapsing.
        public const int FirstUnityLayer = 8, ZeroLayer = 31;
        public static int Layer(uint sourceLayer)
        {
            if (sourceLayer == 0) return ZeroLayer;
            if ((sourceLayer & (sourceLayer - 1)) != 0) throw new FormatException("Multiple source membership bits require separate Unity proxies.");
            for (int bit = 0; bit < 23; bit++) if (sourceLayer == (1u << bit)) return FirstUnityLayer + bit;
            throw new FormatException("Source collision layer has no explicitly assigned Unity layer.");
        }
        public static int Mask(uint sourceMask)
        {
            if ((sourceMask & 0xff800000u) != 0) throw new FormatException("Source collision mask uses unassigned bits.");
            return unchecked((int)(sourceMask << FirstUnityLayer));
        }
        public static bool GodotCanPair(uint layerA, uint maskA, uint layerB, uint maskB) => (layerA & maskB) != 0 || (layerB & maskA) != 0;
        public static void RefreshCollisionPairs()
        {
            ownedColliders.RemoveAll(collider => collider == null);
            for (int first = 0; first < ownedColliders.Count; first++)
                for (int second = first + 1; second < ownedColliders.Count; second++)
                {
                    var a = ownedColliders[first]; var b = ownedColliders[second];
                    if (!a.gameObject.activeInHierarchy || !b.gameObject.activeInHierarchy) continue;
                    var sourceA = a.GetComponent<FoundationCollisionBits>(); var sourceB = b.GetComponent<FoundationCollisionBits>();
                    Physics2D.IgnoreCollision(a, b, !GodotCanPair(sourceA.sourceLayer, sourceA.sourceMask, sourceB.sourceLayer, sourceB.sourceMask));
                }
        }
        private static void ValidateBits(uint layer, uint mask)
        {
            int mapped = Layer(layer); Mask(mask);
            foreach (var other in ownedColliders)
                if (other != null && Physics2D.GetIgnoreLayerCollision(mapped, other.gameObject.layer)) throw new FormatException("Foundation layers require an enabled native collision matrix; no project settings are changed.");
        }
        private static void ValidatePoint(Vector2 point)
        {
            if (float.IsNaN(point.x) || float.IsInfinity(point.x) || float.IsNaN(point.y) || float.IsInfinity(point.y)) throw new FormatException("Source collider coordinate must be finite.");
        }
        private static T Configure<T>(GameObject owner, T collider, uint layer, uint mask, bool trigger) where T : Collider2D
        {
            int nativeLayer = Layer(layer);
            owner.layer = nativeLayer;
            var bits = owner.GetComponent<FoundationCollisionBits>(); if (bits == null) bits = owner.AddComponent<FoundationCollisionBits>(); bits.sourceLayer = layer; bits.sourceMask = mask; bits.configured = true;
            collider.isTrigger = trigger;
            // Godot's either-body mask rule cannot be expressed by two equal-priority Unity
            // include/exclude masks. Keep Unity filters neutral and apply the exact OR per pair.
            // Mapped layers must retain their default enabled matrix (validated below).
            collider.includeLayers = 0; collider.excludeLayers = 0; collider.layerOverridePriority = 0;
            ownedColliders.RemoveAll(other => other == null);
            if (owner.activeInHierarchy)
                foreach (var other in ownedColliders)
                    if (other.gameObject.activeInHierarchy)
                    {
                        var source = other.GetComponent<FoundationCollisionBits>();
                        Physics2D.IgnoreCollision(collider, other, !GodotCanPair(layer, mask, source.sourceLayer, source.sourceMask));
                    }
            ownedColliders.Add(collider);
            return collider;
        }
        public static BoxCollider2D Box(GameObject owner, Rect godotRect, uint layer = 1, uint mask = 1, bool trigger = false)
        {
            ValidateBits(layer, mask); ValidatePoint(godotRect.position); ValidatePoint(godotRect.size);
            if (godotRect.width <= 0 || godotRect.height <= 0) throw new FormatException("Source box dimensions must be positive.");
            var collider = owner.AddComponent<BoxCollider2D>(); Rect rect = FoundationCoordinates.RectToUnity(godotRect); collider.size = rect.size; collider.offset = rect.center;
            return Configure(owner, collider, layer, mask, trigger);
        }
        public static CircleCollider2D Circle(GameObject owner, Vector2 godotCenter, float godotRadius, uint layer = 2, uint mask = 1, bool trigger = false)
        {
            ValidateBits(layer, mask); ValidatePoint(godotCenter);
            if (godotRadius <= 0 || float.IsNaN(godotRadius) || float.IsInfinity(godotRadius)) throw new FormatException("Source circle radius is invalid.");
            var collider = owner.AddComponent<CircleCollider2D>(); collider.radius = godotRadius / FoundationCoordinates.TilePixels; collider.offset = FoundationCoordinates.ToUnity(godotCenter);
            return Configure(owner, collider, layer, mask, trigger);
        }
        public static PolygonCollider2D Polygon(GameObject owner, IReadOnlyList<Vector2> godotPoints, uint layer = 1, uint mask = 1, bool trigger = false)
        {
            ValidateBits(layer, mask);
            if (godotPoints == null || godotPoints.Count < 3) throw new FormatException("Source polygon needs at least three points.");
            foreach (var point in godotPoints) ValidatePoint(point);
            var collider = owner.AddComponent<PolygonCollider2D>(); var points = new Vector2[godotPoints.Count];
            for (int index = 0; index < points.Length; index++) points[index] = FoundationCoordinates.ToUnity(godotPoints[index]);
            collider.SetPath(0, points); return Configure(owner, collider, layer, mask, trigger);
        }
    }

    public sealed class FoundationTileSet
    {
        private readonly Dictionary<string, FoundationValue> tiles = new Dictionary<string, FoundationValue>(StringComparer.Ordinal);
        public FoundationValue Root { get; }
        public int Count => tiles.Count;
        public FoundationTileSet(FoundationWorldRepository repository)
        {
            Root = repository.ReadDocument("migration/world/tile-set.json");
            foreach (var source in Root.Require("sources").Items)
            {
                int id = checked((int)source.Require("id").AsInt64());
                foreach (var tile in source.Require("tiles").Items)
                {
                    Vector2 atlas = FoundationCoordinates.Vector(tile.Require("atlas")); int alternative = checked((int)tile.Require("alternative").AsInt64());
                    string key = Key(id, (int)atlas.x, (int)atlas.y, alternative);
                    if (tiles.ContainsKey(key)) throw new FormatException("Duplicate native tile definition."); tiles.Add(key, tile);
                }
            }
            if (tiles.Count != 640) throw new FormatException("Native tile set coverage changed.");
        }
        private static string Key(int source, int x, int y, int alternative) => source + ":" + x + ":" + y + ":" + alternative;
        public FoundationValue Definition(FoundationTerrainCell cell)
        {
            if (!tiles.TryGetValue(Key(cell.SourceId, cell.AtlasX, cell.AtlasY, cell.Alternative), out var tile)) throw new FormatException("Terrain references an unknown native tile."); return tile;
        }
        public bool IsSolid(FoundationTerrainCell cell)
        {
            foreach (var layer in Definition(cell).Require("layers").Items) if (layer.Require("polygons").Items.Count != 0 && layer.Require("collision_layer").AsInt64() != 0) return true; return false;
        }
        public int AddColliders(GameObject root, FoundationTerrainCell cell)
        {
            int count = 0;
            foreach (var layer in Definition(cell).Require("layers").Items)
                foreach (var polygon in layer.Require("polygons").Items)
                {
                    if (polygon.Require("one_way").AsBool()) throw new FormatException("One-way tile requires an explicit gameplay effector adapter.");
                    var owner = new GameObject("tile " + cell.X + "," + cell.Y); owner.transform.SetParent(root.transform, false); owner.transform.localPosition = FoundationCoordinates.TileCenter(cell.X, cell.Y);
                    var points = new List<Vector2>(); foreach (var point in polygon.Require("points").Items) points.Add(FoundationCoordinates.Vector(point));
                    FoundationCollision.Polygon(owner, points, checked((uint)layer.Require("collision_layer").AsInt64()), checked((uint)layer.Require("collision_mask").AsInt64())); count++;
                }
            return count;
        }
    }
}
