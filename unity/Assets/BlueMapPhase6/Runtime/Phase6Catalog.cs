using System;
using System.Collections.Generic;
using UnityEngine;

namespace BlueMapMigration.Phase6
{
    [Serializable] public sealed class GraphicsTextureDefinition
    {
        public string id, resourcePath, sourcePath, sha256, rgbaSha256;
        public int width, height;
    }
    [Serializable] public sealed class GraphicsSpriteDefinition
    {
        public string id, textureId, category;
        public int x, y, width, height;
        public float pivotX, pivotY, pixelsPerUnit;
    }
    [Serializable] public sealed class GraphicsAnimationDefinition
    {
        public string id;
        public string[] frames;
        public float fps;
        public bool loop;
    }
    [Serializable] public sealed class GraphicsManifest
    {
        public int schemaVersion, version, tilePixels;
        public string schema;
        public GraphicsTextureDefinition[] textures;
        public GraphicsSpriteDefinition[] sprites;
        public GraphicsAnimationDefinition[] animations;
    }
    [Serializable] public sealed class AudioDefinition
    {
        public string id, role, resourcePath, sourcePath, sha256;
        public int sourceIndex, bytes, channels, sampleRate, sampleFrames, sampleWidth;
        public bool loop;
        public int loopBeginFrame, loopEndFrame;
    }
    [Serializable] public sealed class AmbienceDefinition
    {
        public string cue, resourcePath, bus;
        public int loopBeginFrame, loopEndFrame;
        public float baseDb;
    }
    [Serializable] public sealed class AudioPolicies
    {
        public int effectPoolSize, busyPoolStealIndex;
        public float defaultEffectDb, defaultPitch, musicDb, musicFadeStartDb, musicFadeSeconds;
        public string musicFallbackTrack, musicBus, sfxBus, muteBus;
        public bool sameMusicDoesNotRestart, processingWhilePaused, defaultMuted;
        public float volumeMinimumLinear, defaultMusicVolume, defaultSfxVolume;
    }
    [Serializable] public sealed class AudioManifest
    {
        public string schema;
        public int version, schemaVersion;
        public AudioDefinition[] clips;
        public AmbienceDefinition[] ambience;
        public AudioPolicies policies;
    }
    [Serializable] public sealed class LocalizationDefinition
    {
        public string context, source, plural;
        public string[] nl, en, refs, printf, tokens;
        public bool fuzzy, translated;
        public int escapedPercentCount;
    }
    [Serializable] public sealed class LocalizationManifest
    {
        public string schema, sourceLocale, pluralRule, fallback;
        public int version, schemaVersion;
        public string[] locales;
        public LocalizationDefinition[] entries;
    }
    [Serializable] public sealed class CatalogTexture
    {
        public GraphicsTextureDefinition definition;
        public Texture2D texture;
        public string sourceRgbaSha256, importedRgbaSha256;
    }
    [Serializable] public sealed class CatalogSprite
    {
        public GraphicsSpriteDefinition definition;
        public Sprite sprite;
    }
    [Serializable] public sealed class CatalogAnimation
    {
        public GraphicsAnimationDefinition definition;
        public Sprite[] frames;
        public AnimationClip nativeClip;
    }
    [Serializable] public sealed class CatalogAudio
    {
        public AudioDefinition definition;
        public AudioClip clip;
    }

    // Data and native Unity assets only. Gameplay state and real saves are absent.
    public sealed class Phase6Catalog : ScriptableObject
    {
        public const string ResourcePath = "BlueMapAssets/Catalog";
        public const string GraphicsPath = "BlueMapAssets/Data/graphics";
        public const string AudioPath = "BlueMapAssets/Data/audio";
        public const string LocalizationPath = "BlueMapAssets/Data/localization";
        public const string FontPath = "BlueMapAssets/Fonts/DefaultFont";
        public const string FallbackFontPath = "BlueMapAssets/Fonts/FallbackFont";
        public int schemaVersion = 1;
        public TextAsset graphicsSource, audioSource, localizationSource;
        public string graphicsSha256, audioSha256, localizationSha256;
        public CatalogTexture[] textures;
        public CatalogSprite[] sprites;
        public CatalogAnimation[] animations;
        public CatalogAudio[] audio;
        public AudioPolicies audioPolicies;
        public AmbienceDefinition[] ambience;
        public LocalizationDefinition[] localization;
        public Font originalFont;
        public Font fallbackFont;

        private Dictionary<string, CatalogSprite> spriteLookup;
        private Dictionary<string, CatalogAnimation> animationLookup;
        private Dictionary<string, CatalogAudio> audioLookup;

        public static Phase6Catalog LoadRequired()
        {
            Phase6Catalog catalog = Resources.Load<Phase6Catalog>(ResourcePath);
            if (catalog == null) throw new InvalidOperationException("Original BlueMap presentation catalog is missing; import the presentation assets before building.");
            catalog.Initialize();
            return catalog;
        }

        private void Initialize()
        {
            if (spriteLookup != null) return;
            if (schemaVersion != 1 || sprites == null || textures == null || animations == null || audio == null || localization == null || originalFont == null || fallbackFont == null)
                throw new InvalidOperationException("Original presentation catalog is incomplete.");
            spriteLookup = new Dictionary<string, CatalogSprite>(StringComparer.Ordinal);
            animationLookup = new Dictionary<string, CatalogAnimation>(StringComparer.Ordinal);
            audioLookup = new Dictionary<string, CatalogAudio>(StringComparer.Ordinal);
            foreach (CatalogSprite item in sprites)
            {
                if (item == null || item.definition == null || item.sprite == null || string.IsNullOrEmpty(item.definition.id) || spriteLookup.ContainsKey(item.definition.id))
                    throw new InvalidOperationException("Catalog has an invalid or duplicate original sprite.");
                spriteLookup.Add(item.definition.id, item);
            }
            foreach (CatalogAnimation item in animations)
            {
                if (item == null || item.definition == null || item.frames == null || item.frames.Length == 0 || item.nativeClip == null || animationLookup.ContainsKey(item.definition.id))
                    throw new InvalidOperationException("Catalog has an invalid or duplicate original animation.");
                animationLookup.Add(item.definition.id, item);
            }
            foreach (CatalogAudio item in audio)
            {
                string key = item.definition.role + ":" + item.definition.id;
                if (item.clip == null || audioLookup.ContainsKey(key)) throw new InvalidOperationException("Catalog has an invalid or duplicate original audio clip.");
                audioLookup.Add(key, item);
            }
        }

        public Sprite GetSprite(string id)
        {
            Initialize();
            return id != null && spriteLookup.TryGetValue(id, out CatalogSprite value) ? value.sprite : null;
        }
        public CatalogAnimation GetAnimation(string id)
        {
            Initialize();
            return id != null && animationLookup.TryGetValue(id, out CatalogAnimation value) ? value : null;
        }
        public AudioClip GetClip(string role, string id)
        {
            Initialize();
            return audioLookup.TryGetValue(role + ":" + id, out CatalogAudio value) ? value.clip : null;
        }
        public CatalogSprite SpriteRecord(string id)
        {
            Initialize();
            return id != null && spriteLookup.TryGetValue(id, out CatalogSprite value) ? value : null;
        }
    }
}
