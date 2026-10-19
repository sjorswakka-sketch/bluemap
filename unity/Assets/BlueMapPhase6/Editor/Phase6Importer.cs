using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using BlueMapMigration.Phase6;
using UnityEditor;
using UnityEditor.Build;
using UnityEngine;

namespace BlueMapMigration.Editor
{
    // Runs in the wrapper's disposable project. Original payloads are never rewritten.
    public static class Phase6Importer
    {
        private const string CatalogPath = "Assets/BlueMapContent/Resources/BlueMapAssets/Catalog.asset";
        [Serializable] public sealed class TextureProof
        {
            public string id, sourceSha256, sourceRgbaSha256, importedRgbaSha256;
            public int width, height, comparedPixels;
            public bool exactPixels, point, uncompressed, noMipmaps;
        }
        [Serializable] public sealed class ImportReport
        {
            public int schemaVersion = 1, textureCount, spriteCount, animationCount, audioCount, localizationCount;
            public bool success, allNativePixelsExact, allNativeAudioExact, allNativeAnimationCurvesExact, fontAvailable;
            public long comparedAudioFrames, comparedAudioSamples;
            public string graphicsSha256, audioSha256, localizationSha256;
            public string scope = "Original presentation assets; gameplay and save execution are not ported";
            public TextureProof[] textures;
            public AudioProof[] audio;
        }
        [Serializable] public sealed class AudioProof
        {
            public string id, role, sourceSha256;
            public int channels, sampleRate, comparedFrames, comparedSamples;
            public bool exactPcmSamples;
        }

        [MenuItem("BlueMap/Migration/Import original presentation")]
        public static void ImportFromMenu() { ImportAll(null); }

        public static ImportReport ImportAll(string reportPath)
        {
            TextAsset graphicsText = Required<TextAsset>(Phase6Catalog.GraphicsPath);
            TextAsset audioText = Required<TextAsset>(Phase6Catalog.AudioPath);
            TextAsset localizationText = Required<TextAsset>(Phase6Catalog.LocalizationPath);
            GraphicsManifest graphics = JsonUtility.FromJson<GraphicsManifest>(graphicsText.text);
            AudioManifest audio = JsonUtility.FromJson<AudioManifest>(audioText.text);
            LocalizationManifest localization = JsonUtility.FromJson<LocalizationManifest>(localizationText.text);
            Require(graphics != null && graphics.textures != null && graphics.sprites != null && graphics.animations != null, "Graphics manifest is incomplete.");
            Require(audio != null && audio.schema == "bluemap.presentation.audio.v1" && audio.version == 1 && audio.clips != null && audio.policies != null && audio.ambience != null, "Audio manifest is invalid.");
            Require(localization != null && localization.schema == "bluemap.presentation.localization.v1" && localization.version == 1 && localization.entries != null && localization.pluralRule == "n != 1", "Localization manifest is invalid.");
            Require(graphics.tilePixels == 32, "Original world cell size must remain 32 pixels.");
            Require(!File.Exists(AssetFile(CatalogPath)), "Catalog already exists. Generate in a new disposable build project.");
            var catalog = ScriptableObject.CreateInstance<Phase6Catalog>();
            catalog.graphicsSource = graphicsText; catalog.audioSource = audioText; catalog.localizationSource = localizationText;
            catalog.graphicsSha256 = AssetHash(graphicsText); catalog.audioSha256 = AssetHash(audioText); catalog.localizationSha256 = AssetHash(localizationText);
            catalog.originalFont = Required<Font>(Phase6Catalog.FontPath);
            catalog.fallbackFont = Required<Font>(Phase6Catalog.FallbackFontPath);
            foreach (char symbol in "←↑→↓■●") Require(catalog.originalFont.HasCharacter(symbol) || catalog.fallbackFont.HasCharacter(symbol), "Original font fallback cannot render source symbol: " + symbol);
            catalog.audioPolicies = audio.policies; catalog.ambience = audio.ambience; catalog.localization = localization.entries;
            var textureLookup = new Dictionary<string, CatalogTexture>(StringComparer.Ordinal);
            var proofs = new List<TextureProof>();
            foreach (GraphicsTextureDefinition definition in graphics.textures.OrderBy(value => value.id, StringComparer.Ordinal))
            {
                Require(!string.IsNullOrEmpty(definition.id) && !textureLookup.ContainsKey(definition.id), "Duplicate texture identity.");
                Texture2D original = Required<Texture2D>(definition.resourcePath);
                string path = AssetDatabase.GetAssetPath(original);
                byte[] sourceBytes = File.ReadAllBytes(AssetFile(path));
                Require(Hash(sourceBytes) == definition.sha256, "Texture bytes changed: " + definition.id);
                TextureImporter importer = AssetImporter.GetAtPath(path) as TextureImporter;
                Require(importer != null, "Texture importer is missing: " + definition.id);
                importer.textureType = TextureImporterType.Default;
                importer.filterMode = FilterMode.Point; importer.wrapMode = TextureWrapMode.Clamp; importer.anisoLevel = 0;
                importer.mipmapEnabled = false; importer.npotScale = TextureImporterNPOTScale.None;
                importer.maxTextureSize = 16384; importer.isReadable = true; importer.alphaIsTransparency = false;
                importer.alphaSource = TextureImporterAlphaSource.FromInput; importer.sRGBTexture = true;
                importer.textureCompression = TextureImporterCompression.Uncompressed; importer.crunchedCompression = false;
                importer.SetPlatformTextureSettings(new TextureImporterPlatformSettings {
                    name = "Standalone", overridden = true, maxTextureSize = 16384,
                    format = TextureImporterFormat.RGBA32, textureCompression = TextureImporterCompression.Uncompressed
                });
                importer.SaveAndReimport();
                Texture2D imported = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
                var decoded = new Texture2D(2, 2, TextureFormat.RGBA32, false);
                Require(ImageConversion.LoadImage(decoded, sourceBytes, false), "PNG decoder failed: " + definition.id);
                Require(decoded.width == definition.width && decoded.height == definition.height && imported.width == definition.width && imported.height == definition.height, "Texture dimensions changed: " + definition.id);
                Color32[] expected = decoded.GetPixels32(), actual = imported.GetPixels32();
                bool exact = expected.Length == actual.Length;
                for (int i = 0; exact && i < actual.Length; i++) exact = expected[i].Equals(actual[i]);
                string expectedHash = RgbaHash(expected, imported.width, imported.height), actualHash = RgbaHash(actual, imported.width, imported.height);
                Require(exact && expectedHash == definition.rgbaSha256, "Native texture pixel mismatch: " + definition.id);
                UnityEngine.Object.DestroyImmediate(decoded);
                textureLookup.Add(definition.id, new CatalogTexture { definition = definition, texture = imported, sourceRgbaSha256 = expectedHash, importedRgbaSha256 = actualHash });
                proofs.Add(new TextureProof { id = definition.id, sourceSha256 = definition.sha256, sourceRgbaSha256 = expectedHash, importedRgbaSha256 = actualHash, width = imported.width, height = imported.height, comparedPixels = actual.Length, exactPixels = exact, point = imported.filterMode == FilterMode.Point, uncompressed = imported.format == TextureFormat.RGBA32, noMipmaps = imported.mipmapCount == 1 });
            }
            catalog.textures = textureLookup.Values.OrderBy(value => value.definition.id, StringComparer.Ordinal).ToArray();
            AssetDatabase.CreateAsset(catalog, CatalogPath);
            var spriteLookup = new Dictionary<string, CatalogSprite>(StringComparer.Ordinal);
            foreach (GraphicsSpriteDefinition definition in graphics.sprites.OrderBy(value => value.id, StringComparer.Ordinal))
            {
                Require(!string.IsNullOrEmpty(definition.id) && !spriteLookup.ContainsKey(definition.id), "Duplicate sprite identity.");
                Require(textureLookup.TryGetValue(definition.textureId, out CatalogTexture texture), "Unknown sprite texture: " + definition.id);
                Require(definition.width > 0 && definition.height > 0 && definition.x >= 0 && definition.y >= 0 && definition.x + definition.width <= texture.texture.width && definition.y + definition.height <= texture.texture.height, "Sprite rectangle is outside source texture: " + definition.id);
                Require(Finite(definition.pixelsPerUnit) && definition.pixelsPerUnit > 0 && Finite(definition.pivotX) && Finite(definition.pivotY) && definition.pivotX >= 0 && definition.pivotX <= 1 && definition.pivotY >= 0 && definition.pivotY <= 1, "Invalid source scale/pivot: " + definition.id);
                Rect rect = new Rect(definition.x, texture.texture.height - definition.y - definition.height, definition.width, definition.height);
                Sprite sprite = Sprite.Create(texture.texture, rect, new Vector2(definition.pivotX, definition.pivotY), definition.pixelsPerUnit, 0, SpriteMeshType.FullRect);
                sprite.name = definition.id;
                AssetDatabase.AddObjectToAsset(sprite, catalog);
                spriteLookup.Add(definition.id, new CatalogSprite { definition = definition, sprite = sprite });
            }
            catalog.sprites = spriteLookup.Values.OrderBy(value => value.definition.id, StringComparer.Ordinal).ToArray();
            var animations = new List<CatalogAnimation>();
            var animationIds = new HashSet<string>(StringComparer.Ordinal);
            foreach (GraphicsAnimationDefinition definition in graphics.animations.OrderBy(value => value.id, StringComparer.Ordinal))
            {
                Require(animationIds.Add(definition.id) && Finite(definition.fps) && definition.fps > 0 && definition.frames != null && definition.frames.Length > 0, "Invalid original animation.");
                Sprite[] frames = definition.frames.Select(id => { Require(spriteLookup.ContainsKey(id), "Animation references unknown sprite: " + id); return spriteLookup[id].sprite; }).ToArray();
                var clip = new AnimationClip { name = definition.id, frameRate = definition.fps };
                var keys = new ObjectReferenceKeyframe[frames.Length + 1];
                for (int i = 0; i < frames.Length; i++) keys[i] = new ObjectReferenceKeyframe { time = i / definition.fps, value = frames[i] };
                keys[frames.Length] = new ObjectReferenceKeyframe { time = frames.Length / definition.fps, value = definition.loop ? frames[0] : frames[frames.Length - 1] };
                AnimationUtility.SetObjectReferenceCurve(clip, EditorCurveBinding.PPtrCurve("", typeof(SpriteRenderer), "m_Sprite"), keys);
                var settings = AnimationUtility.GetAnimationClipSettings(clip); settings.loopTime = definition.loop; AnimationUtility.SetAnimationClipSettings(clip, settings);
                AssetDatabase.AddObjectToAsset(clip, catalog);
                animations.Add(new CatalogAnimation { definition = definition, frames = frames, nativeClip = clip });
            }
            catalog.animations = animations.ToArray();
            var clips = new List<CatalogAudio>(); var clipIds = new HashSet<string>(StringComparer.Ordinal); var audioProofs = new List<AudioProof>();
            foreach (AudioDefinition definition in audio.clips.OrderBy(value => value.role + ":" + value.id, StringComparer.Ordinal))
            {
                Require(clipIds.Add(definition.role + ":" + definition.id), "Duplicate audio identity.");
                AudioClip clip = Required<AudioClip>(definition.resourcePath); string path = AssetDatabase.GetAssetPath(clip);
                Require(new FileInfo(AssetFile(path)).Length == definition.bytes && Hash(File.ReadAllBytes(AssetFile(path))) == definition.sha256, "Original WAV changed: " + definition.id);
                AudioImporter importer = AssetImporter.GetAtPath(path) as AudioImporter; Require(importer != null, "Audio importer is missing.");
                importer.forceToMono = false; importer.loadInBackground = false;
                AudioImporterSampleSettings settings = importer.defaultSampleSettings;
                settings.loadType = AudioClipLoadType.DecompressOnLoad; settings.compressionFormat = AudioCompressionFormat.PCM;
                settings.sampleRateSetting = AudioSampleRateSetting.PreserveSampleRate; importer.defaultSampleSettings = settings; importer.SaveAndReimport();
                clip = AssetDatabase.LoadAssetAtPath<AudioClip>(path);
                Require(clip.channels == definition.channels && clip.frequency == definition.sampleRate && clip.samples == definition.sampleFrames, "Native audio shape changed: " + definition.id);
                audioProofs.Add(ComparePcm(definition, clip, File.ReadAllBytes(AssetFile(path))));
                clips.Add(new CatalogAudio { definition = definition, clip = clip });
            }
            catalog.audio = clips.ToArray();
            foreach (AmbienceDefinition cue in catalog.ambience)
            {
                AudioClip clip = Required<AudioClip>(cue.resourcePath);
                Require(cue.loopBeginFrame == 0 && cue.loopEndFrame == clip.samples && cue.bus == "SFX", "Unsupported original ambience loop/bus.");
            }
            _ = new Phase6Localization(catalog);
            EditorUtility.SetDirty(catalog); AssetDatabase.SaveAssets();
            AssetDatabase.ImportAsset(CatalogPath, ImportAssetOptions.ForceSynchronousImport | ImportAssetOptions.ForceUpdate);
            catalog = AssetDatabase.LoadAssetAtPath<Phase6Catalog>(CatalogPath);
            foreach (CatalogAnimation animation in catalog.animations)
            {
                ObjectReferenceKeyframe[] keys = AnimationUtility.GetObjectReferenceCurve(animation.nativeClip, EditorCurveBinding.PPtrCurve("", typeof(SpriteRenderer), "m_Sprite"));
                Require(keys != null && keys.Length == animation.frames.Length + 1 && animation.nativeClip.frameRate == animation.definition.fps, "Native animation curve shape changed: " + animation.definition.id);
                for (int i = 0; i < animation.frames.Length; i++)
                {
                    if (keys[i].value != animation.frames[i]) throw new BuildFailedException("Native animation sprite reference changed: " + animation.definition.id + " key " + i + "; expected " + ReferenceId(animation.frames[i]) + "; actual " + ReferenceId(keys[i].value));
                    VerifyKeyTime(keys[i].time, i, animation.definition.fps, animation.definition.id);
                }
                int end = animation.frames.Length;
                VerifyKeyTime(keys[end].time, end, animation.definition.fps, animation.definition.id);
                Require(keys[end].value == (animation.definition.loop ? animation.frames[0] : animation.frames[end - 1]) && AnimationUtility.GetAnimationClipSettings(animation.nativeClip).loopTime == animation.definition.loop, "Native animation loop changed: " + animation.definition.id);
            }
            var report = new ImportReport { success = true, allNativePixelsExact = true, allNativeAudioExact = true, allNativeAnimationCurvesExact = true, comparedAudioFrames = audioProofs.Sum(value => (long)value.comparedFrames), comparedAudioSamples = audioProofs.Sum(value => (long)value.comparedSamples), fontAvailable = catalog.originalFont != null, textureCount = catalog.textures.Length, spriteCount = catalog.sprites.Length, animationCount = catalog.animations.Length, audioCount = catalog.audio.Length, localizationCount = catalog.localization.Length, graphicsSha256 = catalog.graphicsSha256, audioSha256 = catalog.audioSha256, localizationSha256 = catalog.localizationSha256, textures = proofs.ToArray(), audio = audioProofs.ToArray() };
            if (!string.IsNullOrEmpty(reportPath)) File.WriteAllText(reportPath, JsonUtility.ToJson(report, true), new UTF8Encoding(false));
            Debug.Log("BLUEMAP_PHASE6_IMPORT_OK");
            return report;
        }

        private static T Required<T>(string path) where T : UnityEngine.Object
        {
            Require(!string.IsNullOrEmpty(path) && path.StartsWith("BlueMapAssets/", StringComparison.Ordinal), "Asset resource path is outside original presentation root.");
            T value = Resources.Load<T>(path); Require(value != null, "Missing native " + typeof(T).Name + " resource: " + path); return value;
        }
        private static void Require(bool condition, string message) { if (!condition) throw new BuildFailedException(message); }
        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
        private static void VerifyKeyTime(float actual, int frame, float fps, string id)
        {
            // Mono may keep the inline division in extra intermediate precision.
            // Compare exactly the float32 value written to ObjectReferenceKeyframe,
            // including its bits; do not introduce a timing tolerance.
            int expectedBits = BitConverter.SingleToInt32Bits(frame / fps);
            int actualBits = BitConverter.SingleToInt32Bits(actual);
            if (actualBits != expectedBits) throw new BuildFailedException("Native animation key time changed: " + id + " key " + frame + "; expected float32 0x" + expectedBits.ToString("x8") + "; actual 0x" + actualBits.ToString("x8"));
        }
        private static string ReferenceId(UnityEngine.Object value)
        {
            if (value == null) return "null";
            AssetDatabase.TryGetGUIDAndLocalFileIdentifier(value, out string guid, out long localId);
            return value.name + " [" + guid + ":" + localId + "]";
        }
        private static string AssetHash(UnityEngine.Object asset) => Hash(File.ReadAllBytes(AssetFile(AssetDatabase.GetAssetPath(asset))));
        private static string AssetFile(string path)
        {
            Require(path != null && path.StartsWith("Assets/BlueMapContent/", StringComparison.Ordinal) && !path.Contains(".."), "Presentation asset path is outside the imported content root.");
            return Path.GetFullPath(Path.Combine(Application.dataPath, "..", path));
        }
        private static string Hash(byte[] value) { using (var hash = SHA256.Create()) return BitConverter.ToString(hash.ComputeHash(value)).Replace("-", "").ToLowerInvariant(); }
        private static string RgbaHash(Color32[] values, int width, int height)
        {
            byte[] rgba = new byte[values.Length * 4]; int index = 0;
            // Manifest hashes use source PNG's top-to-bottom pixel order.
            for (int y = height - 1; y >= 0; y--) for (int x = 0; x < width; x++)
            { Color32 c = values[y * width + x]; rgba[index++] = c.r; rgba[index++] = c.g; rgba[index++] = c.b; rgba[index++] = c.a; }
            return Hash(rgba);
        }
        private static AudioProof ComparePcm(AudioDefinition definition, AudioClip clip, byte[] bytes)
        {
            Require(definition.sampleWidth == 2 && bytes.Length >= 44, "Only verified original PCM16 WAV is supported: " + definition.id);
            int format = -1, channels = 0, rate = 0, bits = 0, dataStart = -1, dataLength = 0;
            using (var reader = new BinaryReader(new MemoryStream(bytes), Encoding.ASCII))
            {
                Require(new string(reader.ReadChars(4)) == "RIFF", "Original WAV is not RIFF."); reader.ReadUInt32();
                Require(new string(reader.ReadChars(4)) == "WAVE", "Original audio is not WAV.");
                while (reader.BaseStream.Position + 8 <= bytes.Length)
                {
                    string tag = new string(reader.ReadChars(4)); uint length = reader.ReadUInt32(); long start = reader.BaseStream.Position;
                    Require(start + length <= bytes.Length, "Original WAV has a truncated chunk.");
                    if (tag == "fmt ")
                    {
                        Require(length >= 16, "Original WAV format chunk is truncated.");
                        format = reader.ReadUInt16(); channels = reader.ReadUInt16(); rate = reader.ReadInt32(); reader.ReadUInt32(); reader.ReadUInt16(); bits = reader.ReadUInt16();
                    }
                    if (tag == "data") { Require(dataStart < 0, "Original WAV has multiple data chunks."); dataStart = (int)start; dataLength = (int)length; }
                    reader.BaseStream.Position = start + length + (length & 1);
                }
            }
            Require(format == 1 && bits == 16 && channels == definition.channels && rate == definition.sampleRate && dataStart >= 0 && dataLength == definition.sampleFrames * channels * 2, "Original WAV PCM shape differs from manifest: " + definition.id);
            var native = new float[definition.sampleFrames * channels];
            Require(clip.LoadAudioData() && clip.GetData(native, 0), "Cannot read imported PCM samples: " + definition.id);
            for (int i = 0; i < native.Length; i++)
            {
                int index = dataStart + i * 2; short sample = unchecked((short)(bytes[index] | bytes[index + 1] << 8));
                if (native[i] != sample / 32768f) throw new BuildFailedException("Native PCM sample changed: " + definition.id + " at sample " + i);
            }
            return new AudioProof { id = definition.id, role = definition.role, sourceSha256 = definition.sha256, channels = channels, sampleRate = rate, comparedFrames = definition.sampleFrames, comparedSamples = native.Length, exactPcmSamples = true };
        }
    }
}
