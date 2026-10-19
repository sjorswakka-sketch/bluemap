using System;
using UnityEngine;

namespace BlueMapMigration.Phase6
{
    // The source renderer paints behind/body/front in that order. This component
    // exposes that same ordering without implementing appearance or gear rules.
    public sealed class Phase6CharacterLayers : MonoBehaviour
    {
        private SpriteRenderer behind, body, front;
        private Phase6Catalog catalog;
        private void EnsureLayers()
        {
            if (body != null) return;
            behind = Layer("Behind", -1); body = Layer("Body", 0); front = Layer("Front", 1);
        }
        private SpriteRenderer Layer(string label, int order)
        {
            var child = new GameObject(label); child.transform.SetParent(transform, false);
            var renderer = child.AddComponent<SpriteRenderer>(); renderer.sortingOrder = order; return renderer;
        }
        public void SetFrame(Sprite behindSprite, Sprite bodySprite, Sprite frontSprite, int baseOrder = 0)
        {
            if (bodySprite == null) throw new ArgumentException("Original body frame is required.");
            EnsureLayers();
            if (catalog == null) catalog = Phase6Catalog.LoadRequired();
            catalog.Apply(behind, behindSprite); catalog.Apply(body, bodySprite); catalog.Apply(front, frontSprite);
            behind.sortingOrder = baseOrder - 1; body.sortingOrder = baseOrder; front.sortingOrder = baseOrder + 1;
        }
        public void SetColors(Color behindColor, Color bodyColor, Color frontColor)
        { EnsureLayers(); behind.color = behindColor; body.color = bodyColor; front.color = frontColor; }
    }
}
