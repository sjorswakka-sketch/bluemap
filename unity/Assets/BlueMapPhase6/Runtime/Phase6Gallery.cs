using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UnityEngine;
using UnityEngine.Animations;
using UnityEngine.Playables;

namespace BlueMapMigration.Phase6
{
    [Serializable] public sealed class GpuSpriteProof
    {
        public string id;
        public int opaquePixels, mismatches;
    }
    [Serializable] public sealed class PresentationResult
    {
        public int schemaVersion = 1;
        public string scope = "Original presentation assets in Unity; gameplay, world execution and saves are not ported";
        public int textureCount, spriteCount, animationCount, audioCount, localizationCount, hairStyles, clothingPieces;
        public bool success, allNativeTexturesReadable, allNativeAnimationsReferenced, localizationExact, originalFontAvailable, supplementaryGlyphsRendered, audioPlaybackStarted;
        public bool nativeBoundaryFramesExact;
        public int nativeBoundarySamples, nativeBoundaryFailures;
        public int[] supplementaryGlyphPixels;
        public int effectsPoolSize, effectsStarted, nativeGpuComparedPixels, nativeGpuMismatches;
        public string fontName, graphicsSha256, audioSha256, localizationSha256;
        public string[] captures;
        public GpuSpriteProof[] gpuSprites;
    }

    // A presentation gallery, not a second game implementation. Every displayed
    // sprite is a retained native asset cut from the original source pixels.
    public sealed class Phase6Gallery : MonoBehaviour
    {
        public Phase6Catalog Catalog { get; private set; }
        public Phase6Audio Audio { get; private set; }
        public Phase6Localization Localization { get; private set; }
        public string Page { get; private set; }
        public string BuildCommit { get; set; }
        public bool LocalizationExact { get; private set; }
        public bool FontAvailable { get; private set; }
        private GameObject content;
        private sealed class NativePlayback
        {
            public SpriteRenderer renderer;
            public CatalogAnimation animation;
            public PlayableGraph graph;
            public AnimationClipPlayable playable;
        }
        private readonly List<NativePlayback> animated = new List<NativePlayback>();
        private readonly List<Tuple<CatalogSprite, int, int>> witnesses = new List<Tuple<CatalogSprite, int, int>>();
        private readonly List<UnityEngine.Object> owned = new List<UnityEngine.Object>();
        private static readonly Color32 Ink = new Color32(232, 237, 223, 255);
        private static readonly Color32 Muted = new Color32(160, 181, 177, 255);
        private float animationTime;
        private int[] glyphPixels;
        private bool nativeAnimationSamplingExact = true;
        private int nativeBoundarySamples, nativeBoundaryFailures;
        public bool Frozen { get; set; }
        public static readonly string[] Pages = { "overview", "hair", "clothing", "equipment", "languages", "pixels" };

        public void Initialize()
        {
            Catalog = Phase6Catalog.LoadRequired();
            if (Composites("hair").Length != 90 || Composites("clothes").Length != 24 || Composites("gear").Length != 24)
                throw new InvalidOperationException("Original source-drawn hair/clothing/gear reference compositions are incomplete.");
            Localization = new Phase6Localization(Catalog);
            Audio = gameObject.AddComponent<Phase6Audio>(); Audio.Initialize(Catalog);
            FontAvailable = Catalog.originalFont != null && Catalog.fallbackFont != null;
            foreach (char symbol in "←↑→↓■●") FontAvailable &= Catalog.fallbackFont.HasCharacter(symbol);
            // Check exact lookup values directly against every retained PO entry,
            // including context, source/plural separation and untouched tokens.
            LocalizationExact = true;
            foreach (LocalizationDefinition entry in Catalog.localization)
            {
                foreach (string value in new[] { entry.source, entry.plural }.Concat(entry.en ?? Array.Empty<string>()))
                    foreach (char character in value ?? "")
                        if (!char.IsControl(character)) FontAvailable &= Catalog.originalFont.HasCharacter(character) || Catalog.fallbackFont.HasCharacter(character);
                for (int i = 0; i < (string.IsNullOrEmpty(entry.plural) ? 1 : 2); i++)
                {
                    long count = i == 0 ? 1 : 2;
                    string source = i == 0 ? entry.source : entry.plural;
                    LocalizationExact &= Localization.Translate(entry.source, entry.context, entry.plural, count, "nl") == source;
                    string english = !entry.fuzzy && entry.translated && entry.en != null && i < entry.en.Length && !string.IsNullOrEmpty(entry.en[i]) ? entry.en[i] : source;
                    LocalizationExact &= Localization.Translate(entry.source, entry.context, entry.plural, count, "en") == english;
                }
            }
            LocalizationExact &= Localization.Translate("__unknown__", "", "__unknown_plural__", 2, "en") == "__unknown_plural__";
            Show("overview");
        }

        public void Show(string page)
        {
            if (Array.IndexOf(Pages, page) < 0) throw new ArgumentException("Unknown presentation page.");
            ReleaseNativePlayers();
            if (content != null) { content.SetActive(false); Destroy(content); }
            content = new GameObject("Original assets " + page); content.transform.SetParent(transform, false);
            animated.Clear(); witnesses.Clear(); Page = page; animationTime = 0;
            Label("BLUEMAP QUEST", 48, 30, 25, Ink);
            if (!string.IsNullOrEmpty(BuildCommit) && BuildCommit.Length >= 8) Label("PREVIEW  " + BuildCommit.Substring(0, 8), 940, 39, 12, Muted);
            Label("Fase 6  /  oorspronkelijke pixelkunst, geluid en talen", 49, 68, 15, Muted);
            Label("1 Overzicht   2 Kapsels   3 Kleding   4 Uitrusting   5 Talen   6 Pixelcontrole", 49, 602, 14, Muted);
            Label("M Muziek starten   N Muziek stoppen   Spatie Geluid   Esc Sluiten", 49, 625, 12, Muted);
            switch (page)
            {
                case "overview": Overview(); break;
                case "hair": Grid(Composites("hair"), "90 kapsels op het oorspronkelijke personage", 15, 68, 64, 1); break;
                case "clothing": Clothing(); break;
                case "equipment": Equipment(); break;
                case "languages": Languages(); break;
                case "pixels": Pixels(); break;
            }
        }

        private CatalogSprite[] SelectSprites(Func<CatalogSprite, bool> filter) => Catalog.sprites.Where(filter).OrderBy(value => value.definition.id, StringComparer.Ordinal).ToArray();
        public CatalogSprite[] UniqueHair() => SelectSprites(value => value.definition.id.StartsWith("hair:", StringComparison.Ordinal)).GroupBy(value => value.definition.id.Split(':')[1]).Select(group => group.FirstOrDefault(value => value.definition.id.EndsWith(":down", StringComparison.Ordinal)) ?? group.First()).ToArray();
        public CatalogSprite[] UniqueClothing() => SelectSprites(value => value.definition.id.StartsWith("clothes:cloth_", StringComparison.Ordinal)).GroupBy(value => value.definition.id.Split(':')[1]).Select(group => group.FirstOrDefault(value => value.definition.id.EndsWith(":down:idle", StringComparison.Ordinal)) ?? group.First()).ToArray();
        private CatalogSprite[] Composites(string kind) => SelectSprites(value => value.definition.id.StartsWith("generated:" + kind + ":", StringComparison.Ordinal) && value.definition.id.EndsWith(":down:idle", StringComparison.Ordinal));

        private void Clothing()
        {
            Grid(Composites("clothes"), "Kleding op het oorspronkelijke personage", 12, 84, 100, 2);
            Label("Losse oorspronkelijke kledinglagen", 56, 438, 15, Muted);
            CatalogSprite[] layers = UniqueClothing();
            for (int i = 0; i < layers.Length; i++) Put(layers[i].sprite, 56 + i * 42, 474, 1);
        }
        private void Equipment()
        {
            Grid(Composites("gear"), "Uitrusting op het oorspronkelijke personage", 12, 84, 100, 2);
            Label("Oorspronkelijke uitrustingsiconen", 56, 438, 15, Muted);
            CatalogSprite[] icons = SelectSprites(value => (value.definition.id.StartsWith("generated:equipment:", StringComparison.Ordinal) || value.definition.id.StartsWith("equipment:", StringComparison.Ordinal)) && value.definition.width <= 32 && value.definition.height <= 32).Take(24).ToArray();
            for (int i = 0; i < icons.Length; i++) Put(icons[i].sprite, 56 + i * 42, 474, 2);
        }

        private void Overview()
        {
            Label("Dezelfde kunst. Nu ook als echte Unity-assets.", 49, 114, 21, Ink);
            Label("Personages & beweging", 49, 170, 17, Muted);
            var actors = Catalog.animations.Where(value => value.definition.id.StartsWith("actor:", StringComparison.Ordinal)).OrderBy(value => value.definition.id, StringComparer.Ordinal).GroupBy(value => value.definition.id.Split(':')[1]).Select(group => group.FirstOrDefault(value => value.definition.id.EndsWith(":down", StringComparison.Ordinal)) ?? group.First()).OrderBy(value => value.definition.id.StartsWith("actor:player:", StringComparison.Ordinal) ? 0 : 1).Take(14).ToArray();
            for (int i = 0; i < actors.Length; i++)
            {
                int x = 56 + i % 7 * 145, y = 206 + i / 7 * 124;
                SpriteRenderer renderer = Put(actors[i].frames[0], x, y, 2);
                animated.Add(CreateNativePlayer(renderer, actors[i]));
                Label(actors[i].definition.id.Split(':')[1], x, y + 68, 11, Muted);
            }
            Label("Wereld & voorwerpen", 49, 476, 17, Muted);
            var tiles = SelectSprites(value => value.definition.id.StartsWith("tile:", StringComparison.Ordinal)).GroupBy(value => value.definition.id.Split(':')[1]).Select(group => group.First()).Take(28).ToArray();
            for (int i = 0; i < tiles.Length; i++) Put(tiles[i].sprite, 56 + i * 37, 514, 1);
        }
        private void Grid(CatalogSprite[] sprites, string title, int columns, int dx, int dy, int scale)
        {
            Label(title, 49, 114, 21, Ink);
            Label("Originele frames, scherpe pixels en behouden kleuren", 49, 146, 14, Muted);
            for (int i = 0; i < sprites.Length; i++)
            {
                int x = 56 + i % columns * dx, y = 184 + i / columns * dy;
                if (y + sprites[i].definition.height * scale > 588) break;
                Put(sprites[i].sprite, x, y, scale);
            }
        }
        private void Languages()
        {
            Label("Nederlands / English", 49, 114, 21, Ink);
            Label("Het oorspronkelijke lettertype, context en meervoud blijven behouden.", 49, 149, 15, Muted);
            LocalizationDefinition[] examples = Catalog.localization.Where(value => !string.IsNullOrEmpty(value.plural)).Take(4).ToArray();
            int y = 204;
            foreach (LocalizationDefinition example in examples)
            {
                string nl = Localization.Translate(example.source, example.context, example.plural, 2, "nl");
                string en = Localization.Translate(example.source, example.context, example.plural, 2, "en");
                Label(Trim(nl, 76), 56, y, 17, Ink); Label(Trim(en, 76), 56, y + 29, 16, Muted); y += 85;
            }
            for (int i = 0; i < 6; i++) Label("←↑→↓■●"[i].ToString(), 56 + i * 52, 520, 26, Ink);
            Label("é ë ï ö ü á à è ê ó ô ú É – …   /   " + Localization.Count + " teksten", 56, 563, 15, Ink);
        }
        public void CheckSupplementaryGlyphs(Texture2D capture)
        {
            if (Page != "languages") throw new InvalidOperationException("Glyph GPU proof requires the language page.");
            Color32[] pixels = capture.GetPixels32(); glyphPixels = new int[6];
            for (int i = 0; i < 6; i++)
                for (int y = 648 - 553; y < 648 - 520; y++) for (int x = 56 + i * 52; x < 56 + i * 52 + 40; x++)
                {
                    Color32 c = pixels[y * 1152 + x];
                    if (c.r > 100 && c.g > 100 && c.b > 100) glyphPixels[i]++;
                }
        }
        private void Pixels()
        {
            Label("Exacte bronpixels op de GPU", 49, 114, 21, Ink);
            var selected = UniqueHair().Concat(UniqueClothing()).Concat(SelectSprites(value => value.definition.id.StartsWith("player:", StringComparison.Ordinal)).Take(12)).Concat(SelectSprites(value => value.definition.id.StartsWith("tile:", StringComparison.Ordinal)).Take(12)).Where(value => value.definition.width <= 32 && value.definition.height <= 32).Take(192).ToArray();
            for (int i = 0; i < selected.Length; i++)
            {
                int x = 56 + i % 24 * 43, y = 174 + i / 24 * 49;
                Put(selected[i].sprite, x, y, 1); witnesses.Add(Tuple.Create(selected[i], x, y));
            }
        }
        public GpuSpriteProof[] CompareGpu(Texture2D capture)
        {
            if (Page != "pixels") throw new InvalidOperationException("GPU source comparison requires the original pixel page.");
            var proofs = new List<GpuSpriteProof>();
            Color32[] output = capture.GetPixels32();
            foreach (var witness in witnesses)
            {
                CatalogSprite item = witness.Item1; Rect rect = item.sprite.rect;
                Color32[] source = item.sprite.texture.GetPixels32(); int sourceWidth = item.sprite.texture.width;
                var proof = new GpuSpriteProof { id = item.definition.id };
                for (int y = 0; y < item.definition.height; y++) for (int x = 0; x < item.definition.width; x++)
                {
                    Color32 expected = source[((int)rect.y + y) * sourceWidth + (int)rect.x + x];
                    if (expected.a != 255) continue;
                    Color32 actual = output[(648 - witness.Item3 - item.definition.height + y) * 1152 + witness.Item2 + x];
                    proof.opaquePixels++;
                    if (actual.r != expected.r || actual.g != expected.g || actual.b != expected.b) proof.mismatches++;
                }
                proofs.Add(proof);
            }
            return proofs.ToArray();
        }

        public void SampleAnimations(float seconds)
        {
            if (seconds < 0 || float.IsNaN(seconds) || float.IsInfinity(seconds)) throw new ArgumentOutOfRangeException(nameof(seconds));
            foreach (var pair in animated)
            {
                int frame = SourceFrame(pair.animation, seconds);
                SampleNativeFrame(pair, frame);
                nativeAnimationSamplingExact &= pair.renderer.sprite == pair.animation.frames[frame];
            }
        }
        private static int SourceFrame(CatalogAnimation animation, float seconds)
        {
            int frame = Mathf.FloorToInt(seconds * animation.definition.fps);
            return animation.definition.loop ? frame % animation.frames.Length : Mathf.Min(frame, animation.frames.Length - 1);
        }
        private static NativePlayback CreateNativePlayer(SpriteRenderer renderer, CatalogAnimation animation)
        {
            Animator animator = renderer.gameObject.AddComponent<Animator>(); animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
            PlayableGraph graph = PlayableGraph.Create(animation.definition.id); graph.SetTimeUpdateMode(DirectorUpdateMode.Manual);
            AnimationClipPlayable playable = AnimationClipPlayable.Create(graph, animation.nativeClip);
            AnimationPlayableOutput output = AnimationPlayableOutput.Create(graph, "Original sprite frames", animator); output.SetSourcePlayable(playable); graph.Play();
            return new NativePlayback { renderer = renderer, animation = animation, graph = graph, playable = playable };
        }
        private static void SampleNativeFrame(NativePlayback player, int sourceFrame)
        {
            // Source clock chooses the discrete sprite. Sample the native curve
            // inside that exact interval; modulo of rounded clip durations can
            // otherwise land just before a boundary (e.g. 1s at 5fps, 2 frames).
            float nativeTime = (sourceFrame + .5f) / player.animation.definition.fps;
            player.playable.SetTime(nativeTime); player.graph.Evaluate(0);
        }
        public void CheckNativeAnimationBoundaries()
        {
            nativeBoundarySamples = nativeBoundaryFailures = 0;
            foreach (CatalogAnimation animation in Catalog.animations)
            {
                var obj = new GameObject("Isolated native curve boundary witness"); obj.transform.position = new Vector3(-200, -200, 0);
                NativePlayback player = CreateNativePlayer(obj.AddComponent<SpriteRenderer>(), animation);
                try
                {
                    // Eight source cycles, on each boundary and its immediately
                    // preceding/following representable float32 clock. This is
                    // exact Sprite-reference validation, with no tolerance.
                    var clocks = new List<float> { 1f, BitConverter.Int32BitsToSingle(BitConverter.SingleToInt32Bits(1f) - 1), BitConverter.Int32BitsToSingle(BitConverter.SingleToInt32Bits(1f) + 1) };
                    for (int boundary = 0; boundary <= animation.frames.Length * 8; boundary++)
                    {
                        int bits = BitConverter.SingleToInt32Bits(boundary / animation.definition.fps);
                        if (boundary > 0) clocks.Add(BitConverter.Int32BitsToSingle(bits - 1));
                        clocks.Add(BitConverter.Int32BitsToSingle(bits)); clocks.Add(BitConverter.Int32BitsToSingle(bits + 1));
                    }
                    foreach (float clock in clocks)
                    {
                        int expected = SourceFrame(animation, clock);
                        SampleNativeFrame(player, expected); nativeBoundarySamples++;
                        if (player.renderer.sprite != animation.frames[expected])
                        {
                            nativeBoundaryFailures++;
                            if (nativeBoundaryFailures <= 5) Debug.LogError("Native source-frame boundary mismatch: " + animation.definition.id + " clock bits 0x" + BitConverter.SingleToInt32Bits(clock).ToString("x8") + " expected source frame " + expected);
                        }
                    }
                }
                finally { if (player.graph.IsValid()) player.graph.Destroy(); Destroy(obj); }
            }
        }
        private void Update()
        {
            if (!Frozen) { animationTime += Time.unscaledDeltaTime; SampleAnimations(animationTime); }
            for (int i = 0; i < Pages.Length; i++) if (Input.GetKeyDown(KeyCode.Alpha1 + i)) Show(Pages[i]);
            if (Input.GetKeyDown(KeyCode.M)) Audio.PlayMusic();
            if (Input.GetKeyDown(KeyCode.N)) Audio.StopMusic();
            if (Input.GetKeyDown(KeyCode.Space)) { CatalogAudio effect = Catalog.audio.FirstOrDefault(value => value.definition.role == "effect"); if (effect != null) Audio.PlayEffect(effect.definition.id); }
        }
        public PresentationResult Report(GpuSpriteProof[] proofs, string[] captures)
        {
            int mismatches = proofs.Sum(value => value.mismatches), pixels = proofs.Sum(value => value.opaquePixels);
            return new PresentationResult {
                success = mismatches == 0 && pixels > 1000 && nativeBoundarySamples > 0 && nativeBoundaryFailures == 0 && LocalizationExact && FontAvailable && glyphPixels != null && glyphPixels.All(value => value > 5) && Audio.EffectsStarted > 0 && Audio.MusicIsPlaying,
                textureCount = Catalog.textures.Length, spriteCount = Catalog.sprites.Length, animationCount = Catalog.animations.Length, audioCount = Catalog.audio.Length, localizationCount = Catalog.localization.Length,
                hairStyles = UniqueHair().Length, clothingPieces = UniqueClothing().Length,
                allNativeTexturesReadable = Catalog.textures.All(value => value.texture.isReadable && value.texture.filterMode == FilterMode.Point && value.texture.mipmapCount == 1 && value.sourceRgbaSha256 == value.importedRgbaSha256),
                allNativeAnimationsReferenced = nativeAnimationSamplingExact && Catalog.animations.All(value => value.nativeClip != null && value.frames.Length > 0), localizationExact = LocalizationExact, originalFontAvailable = FontAvailable,
                supplementaryGlyphsRendered = glyphPixels != null && glyphPixels.All(value => value > 5), supplementaryGlyphPixels = glyphPixels,
                nativeBoundarySamples = nativeBoundarySamples, nativeBoundaryFailures = nativeBoundaryFailures, nativeBoundaryFramesExact = nativeBoundarySamples > 0 && nativeBoundaryFailures == 0,
                fontName = Catalog.originalFont.name, audioPlaybackStarted = Audio.EffectsStarted > 0 && Audio.MusicWasStarted && Audio.MusicIsPlaying, effectsPoolSize = Audio.PoolSize, effectsStarted = Audio.EffectsStarted,
                nativeGpuComparedPixels = pixels, nativeGpuMismatches = mismatches, gpuSprites = proofs, captures = captures,
                graphicsSha256 = Catalog.graphicsSha256, audioSha256 = Catalog.audioSha256, localizationSha256 = Catalog.localizationSha256
            };
        }
        private SpriteRenderer Put(Sprite sprite, int left, int top, int scale)
        {
            var obj = new GameObject(sprite.name); obj.transform.SetParent(content.transform, false);
            obj.transform.position = Position(left + sprite.pivot.x * scale, top + (sprite.rect.height - sprite.pivot.y) * scale);
            obj.transform.localScale = Vector3.one * (sprite.pixelsPerUnit / 32f * scale);
            SpriteRenderer renderer = obj.AddComponent<SpriteRenderer>(); renderer.sprite = sprite; renderer.sortingOrder = 2; return renderer;
        }
        private void Label(string text, int x, int y, int size, Color color)
        {
            // Godot's original primary face lacks six UI symbols. Use the
            // explicitly retained engine fallback, never an OS-selected font.
            var run = new StringBuilder(); Font current = null; float offset = 0;
            foreach (char character in text)
            {
                Font selected = "←↑→↓■●".IndexOf(character) >= 0 ? Catalog.fallbackFont : Catalog.originalFont;
                if (current != null && current != selected)
                {
                    string value = run.ToString(); LabelRun(value, x + offset, y, size, color, current);
                    current.RequestCharactersInTexture(value, size, FontStyle.Normal);
                    foreach (char c in value) if (current.GetCharacterInfo(c, out CharacterInfo info, size, FontStyle.Normal)) offset += info.advance;
                    run.Clear();
                }
                current = selected; run.Append(character);
            }
            if (run.Length > 0) LabelRun(run.ToString(), x + offset, y, size, color, current);
        }
        private void LabelRun(string text, float x, int y, int size, Color color, Font font)
        {
            var obj = new GameObject("Original font label"); obj.transform.SetParent(content.transform, false); obj.transform.position = Position(x, y);
            var mesh = obj.AddComponent<TextMesh>(); mesh.font = font; mesh.fontSize = size; mesh.characterSize = 10f / 32f; mesh.anchor = TextAnchor.UpperLeft; mesh.richText = false; mesh.text = text; mesh.color = color;
            obj.GetComponent<MeshRenderer>().sharedMaterial = font.material;
            obj.GetComponent<MeshRenderer>().sortingOrder = 10;
        }
        private static Vector3 Position(float x, float y) => new Vector3((x - 576) / 32f, (324 - y) / 32f, 0);
        private static string Trim(string value, int length) { value = value.Replace("\n", " / "); return value.Length <= length ? value : value.Substring(0, length - 1) + "…"; }
        private void ReleaseNativePlayers() { foreach (NativePlayback item in animated) if (item.graph.IsValid()) item.graph.Destroy(); animated.Clear(); }
        private void OnDestroy() { ReleaseNativePlayers(); }
    }
}
