using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Phase6;
using UnityEngine;

namespace BlueMapMigration.Foundation
{
    // A terrain inspection window, not replacement scenery or a playable world.
    // Every cell is the original atlas frame at the original 32px scale.
    public sealed class FoundationView : MonoBehaviour
    {
        public FoundationSession Session { get; private set; }
        public FoundationWorldRepository Repository { get; private set; }
        private Phase6Catalog catalog;
        private GameObject content;
        private TextMesh status;
        private readonly Dictionary<string, CatalogSprite> terrain = new Dictionary<string, CatalogSprite>();
        private int selected;
        private bool frozen;
        private string[] maps;
        public void Initialize(Phase6Catalog original, bool automated)
        {
            catalog = original; frozen = automated;
            Repository = FoundationWorldRepository.LoadRequired();
            Session = new FoundationSession(Repository, new FoundationGameState());
            maps = new[] { "village", "forest", "cave" }.Concat(Repository.MapIds.Where(value => value != "village" && value != "forest" && value != "cave")).ToArray();
            foreach (var sprite in catalog.sprites.Where(value => value.definition.id.StartsWith("tile:", StringComparison.Ordinal)))
                terrain.Add((sprite.definition.x / 32) + ":" + (sprite.definition.y / 32), sprite);
            Show("village");
        }
        public void Show(string mapId)
        {
            var snapshot = Repository.Read(mapId);
            string spawn = snapshot.Arrivals.FirstOrDefault(value => value.Name == "start")?.Name ?? snapshot.Arrivals[0].Name;
            if (!Session.TryEnter(mapId, spawn)) throw new InvalidOperationException(Session.LastDiagnostic);
            selected = Array.IndexOf(maps, mapId);
            if (content != null) { content.SetActive(false); Destroy(content); }
            content = new GameObject("Original area inspection"); content.transform.SetParent(transform, false);
            Label("BLUEMAP QUEST", 48, 30, 25, new Color32(232,237,223,255));
            Label("Fase 7  /  de spelbasis", 49, 68, 15, new Color32(160,181,177,255));
            Label("Het oorspronkelijke terrein", 49, 116, 21, new Color32(232,237,223,255));
            Label("Gebied: " + mapId + "   /   aankomst: " + spawn, 49, 150, 14, new Color32(160,181,177,255));
            var cells = snapshot.TerrainCells;
            int width = cells.Max(value => value.X) + 1, height = cells.Max(value => value.Y) + 1;
            Vector2 at = snapshot.Arrivals.First(value => value.Name == spawn).Resolved;
            int left = Math.Max(0, Math.Min(width - 17, (int)(at.x / 32) - 8));
            int top = Math.Max(0, Math.Min(height - 12, (int)(at.y / 32) - 6));
            foreach (var cell in cells)
            {
                if (cell.X < left || cell.X >= left + 17 || cell.Y < top || cell.Y >= top + 12) continue;
                if (!terrain.TryGetValue(cell.AtlasX + ":" + cell.AtlasY, out var sprite))
                    throw new FormatException("Retained terrain sprite missing for " + cell.AtlasX + ":" + cell.AtlasY);
                var obj = new GameObject("Source tile " + cell.X + "," + cell.Y); obj.transform.SetParent(content.transform, false);
                // The same adapter used by gameplay/physics: convert one original tile centre.
                Vector2 sourceCentre = new Vector2((cell.X - left) * 32 + 16, (cell.Y - top) * 32 + 16);
                Vector2 mapped = FoundationCoordinates.ToUnity(sourceCentre) + new Vector2((48-576)/32f, (324-188)/32f);
                obj.transform.position = new Vector3(mapped.x, mapped.y, 0);
                var renderer = obj.AddComponent<SpriteRenderer>(); catalog.Apply(renderer, sprite); renderer.sortingOrder = 1;
            }
            Label("37 gebieden behouden", 640, 202, 21, new Color32(232,237,223,255));
            Label("49.758 tegels, dezelfde ruimte", 640, 239, 15, new Color32(160,181,177,255));
            Label("Voortgang blijft bij gebiedswissels.", 640, 283, 15, new Color32(232,237,223,255));
            Label("Pauze stopt de actieve speeltijd.", 640, 315, 15, new Color32(232,237,223,255));
            status = Label("", 640, 366, 17, new Color32(225,199,139,255));
            Label("Terreinweergave als controle.", 640, 466, 14, new Color32(160,181,177,255));
            Label("Objecten, speler en gameplay volgen", 640, 493, 14, new Color32(160,181,177,255));
            Label("in de volgende migratiefases.", 640, 518, 14, new Color32(160,181,177,255));
            Label("1-6 Beelden en geluid    7 Spelbasis    Links/Rechts Gebied    P Pauze", 49, 602, 14, new Color32(160,181,177,255));
            Label("Deze afzonderlijke proef gebruikt geen persoonlijke opslag.   Esc Sluiten", 49, 625, 12, new Color32(160,181,177,255));
            RefreshStatus();
        }
        private void Update()
        {
            if (!frozen)
            {
                Session.Clock.Tick(Time.unscaledDeltaTime);
                if (Input.GetKeyDown(KeyCode.P)) Session.State.SetUi("foundation-preview", !Session.State.Paused);
                if (!Session.State.InputLocked && Input.GetKeyDown(KeyCode.RightArrow)) Show(maps[(selected + 1) % maps.Length]);
                if (!Session.State.InputLocked && Input.GetKeyDown(KeyCode.LeftArrow)) Show(maps[(selected + maps.Length - 1) % maps.Length]);
            }
            RefreshStatus();
        }
        private void RefreshStatus()
        {
            if (status != null) status.text = "Speeltijd: " + Session.State.PlayTime.ToString("F1", System.Globalization.CultureInfo.InvariantCulture) + " s\n\n"
                + (Session.State.Paused ? "Gepauzeerd" : "Actief") + "\n\nGebied " + (selected + 1) + " / " + maps.Length;
        }
        private TextMesh Label(string value, int x, int y, int size, Color color)
        {
            var obj = new GameObject("Foundation label"); obj.transform.SetParent(content.transform, false);
            obj.transform.position = new Vector3((x-576)/32f, (324-y)/32f, 0);
            var mesh = obj.AddComponent<TextMesh>(); mesh.font = catalog.originalFont; mesh.fontSize = size;
            mesh.characterSize = 10f/32f; mesh.anchor = TextAnchor.UpperLeft; mesh.richText = false; mesh.text = value; mesh.color = color;
            obj.GetComponent<MeshRenderer>().sharedMaterial = catalog.originalFont.material;
            obj.GetComponent<MeshRenderer>().sortingOrder = 10; return mesh;
        }
        private void OnDisable() { if (Session != null) Session.State.SetUi("preview-hidden", true); }
        private void OnEnable() { if (Session != null) Session.State.SetUi("preview-hidden", false); }
        private void OnDestroy() { Session?.Dispose(); }
    }
}
