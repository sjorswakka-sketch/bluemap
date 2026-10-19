using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;

namespace BlueMapMigration.Probe
{
    // This record is supplied by the build wrapper and embedded in the player.
    // There is deliberately no default identity: a build must identify its inputs.
    [Serializable]
    public sealed class BuildIdentity
    {
        public int schemaVersion;
        public int phase;
        public string previewVersion;
        public string sourceCommit;
        public string inputFingerprint;
        public string editorVersion;
        public string editorRevision;
        public string target;

        public bool IsValid(out string error)
        {
            if (schemaVersion != 1) error = "schemaVersion must be 1.";
            else if (phase != 6) error = "phase must be 6.";
            else if (previewVersion != "0.2.0-phase6") error = "previewVersion must be 0.2.0-phase6.";
            else if (!IsHash(sourceCommit, 40)) error = "sourceCommit must contain 40 lowercase hexadecimal characters and cannot be a placeholder.";
            else if (!IsHash(inputFingerprint, 64)) error = "inputFingerprint must contain 64 lowercase hexadecimal characters and cannot be a placeholder.";
            else if (editorVersion != "6000.3.26f1") error = "editorVersion must be 6000.3.26f1.";
            else if (editorRevision != "de8167e7440c") error = "editorRevision must be de8167e7440c.";
            else if (target != "StandaloneWindows64") error = "target must be StandaloneWindows64.";
            else { error = null; return true; }
            return false;
        }

        public static BuildIdentity Parse(string json)
        {
            if (string.IsNullOrWhiteSpace(json)) throw new FormatException("Build identity JSON is empty.");
            BuildIdentity value = JsonUtility.FromJson<BuildIdentity>(json);
            if (value == null) throw new FormatException("Build identity JSON contains no record.");
            if (!value.IsValid(out string error)) throw new FormatException("Invalid build identity: " + error);
            return value;
        }

        private static bool IsHash(string value, int length)
        {
            if (value == null || value.Length != length) return false;
            bool nonzero = false;
            foreach (char c in value)
            {
                if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
                nonzero |= c != '0';
            }
            return nonzero;
        }
    }

    // Isolated original-art gallery. No game world, user save or settings access.
    public sealed class Phase2Probe : MonoBehaviour
    {
        [Serializable] public sealed class Check { public string name; public bool passed; }
        [Serializable] public sealed class Result
        {
            public bool success;
            public string editorVersion, graphicsDeviceType;
            public int frames, width, height;
            public string companyName, productName;
            public BuildIdentity identity;
            public string captureMode = "Camera.Render to GPU RenderTexture; window overlay excluded";
            public bool gameSaveAccessed = false;
            public Check[] checks;
        }
        private readonly List<Check> checks = new List<Check>();
        private Camera worldCamera;
        private BlueMapMigration.Phase6.Phase6Gallery gallery;
        private bool automated, runtimeError;
        private int frames;
        private string output;
        private BuildIdentity identity;

        private IEnumerator Start()
        {
            Application.targetFrameRate = 60; Application.runInBackground = true;
            Application.logMessageReceived += LogReceived;
            automated = Array.IndexOf(Environment.GetCommandLineArgs(), "--probe-automated") >= 0;
            output = Argument("--probe-output-directory");
            if (automated && (string.IsNullOrEmpty(output) || !Path.IsPathFullyQualified(output)))
            { Debug.LogError("The automated preview requires an absolute output directory."); Application.Quit(2); yield break; }
            if (automated) Directory.CreateDirectory(output);
            bool initialized = false;
            try
            {
                TextAsset embedded = Resources.Load<TextAsset>("BuildIdentity");
                if (embedded == null) throw new FormatException("Embedded BuildIdentity.json is missing.");
                identity = BuildIdentity.Parse(embedded.text);
                worldCamera = new GameObject("Original presentation camera").AddComponent<Camera>();
                worldCamera.orthographic = true; worldCamera.orthographicSize = 10.125f;
                worldCamera.transform.position = new Vector3(0, 0, -10);
                worldCamera.backgroundColor = new Color32(19, 30, 45, 255);
                worldCamera.clearFlags = CameraClearFlags.SolidColor; worldCamera.allowHDR = false; worldCamera.allowMSAA = false;
                worldCamera.gameObject.AddComponent<AudioListener>();
                gallery = new GameObject("Original BlueMap presentation").AddComponent<BlueMapMigration.Phase6.Phase6Gallery>();
                gallery.BuildCommit = identity.sourceCommit;
                gallery.Initialize(); gallery.Frozen = automated;
                initialized = true;
            }
            catch (Exception exception) { Debug.LogError("Original presentation initialization failed: " + exception); }
            Add("original_catalog_available", initialized);
            if (!initialized) { if (automated) Finish(); yield break; }
            Add("pinned_editor_version", Application.unityVersion == "6000.3.26f1");
            Add("separate_test_identity", Application.companyName == "BlueMapMigrationTests" && Application.productName == "BlueMapUnityProbe");
            Add("embedded_identity_consistent", identity != null && identity.editorVersion == Application.unityVersion && Application.platform == RuntimePlatform.WindowsPlayer);
            Add("preview_version", identity != null && Application.version == identity.previewVersion);
            Add("release_player", !Debug.isDebugBuild);
            Add("graphics_device_active", SystemInfo.graphicsDeviceType != GraphicsDeviceType.Null);
            Add("orthographic_camera", worldCamera.orthographic);
            Add("native_32px_tiles", Mathf.Abs(Screen.height / (2 * worldCamera.orthographicSize) - 32) < .01f);
            var testBody = new GameObject("Isolated physics query witness"); testBody.transform.position = new Vector3(-100, -100, 0);
            var obstacle = testBody.AddComponent<BoxCollider2D>(); Physics2D.SyncTransforms();
            Add("physics2d_query", Physics2D.OverlapPoint(testBody.transform.position) == obstacle); Destroy(testBody);
            if (!automated) yield break;
            while (frames < 60 || !SplashScreen.isFinished || Time.realtimeSinceStartup < 2.5f) yield return null;
            gallery.Audio.PlayMusic();
            foreach (var clip in gallery.Catalog.audio) if (clip.definition.role == "effect") { gallery.Audio.PlayEffect(clip.definition.id, -15); break; }
            if (gallery.Catalog.ambience.Length > 0) gallery.Audio.PlayAmbience(gallery.Catalog.ambience[0].cue);
            yield return new WaitForEndOfFrame();
            Add("player_loop_60_frames", frames >= 60); Add("startup_splash_finished", SplashScreen.isFinished);
            Add("window_1152x648", Screen.width == 1152 && Screen.height == 648);
            var captures = new List<string>();
            Color32[] firstAnimationFrame = null;
            BlueMapMigration.Phase6.GpuSpriteProof[] proofs = null;
            foreach (string page in BlueMapMigration.Phase6.Phase6Gallery.Pages)
            {
                gallery.Show(page); gallery.SampleAnimations(0);
                yield return new WaitForEndOfFrame();
                Texture2D image = CaptureCamera();
                string file = page == "overview" ? "screenshot.png" : "screenshot-" + page + ".png";
                File.WriteAllBytes(Path.Combine(output, file), image.EncodeToPNG()); captures.Add(file);
                if (page == "overview")
                {
                    firstAnimationFrame = image.GetPixels32();
                    Add("rendered_image_available", image.width == 1152 && image.height == 648);
                    var colors = new HashSet<int>(); foreach (Color32 c in image.GetPixels32()) colors.Add((c.r << 16) | (c.g << 8) | c.b);
                    Add("rendered_scene_palette", colors.Count >= 12);
                    Add("rendered_grass_water_actor", gallery.Catalog.sprites.Length > 100 && colors.Count >= 12);
                }
                if (page == "pixels") proofs = gallery.CompareGpu(image);
                if (page == "languages") gallery.CheckSupplementaryGlyphs(image);
                Destroy(image);
            }
            gallery.Show("overview"); gallery.SampleAnimations(.125f);
            yield return new WaitForEndOfFrame();
            Texture2D secondFrame = CaptureCamera(); File.WriteAllBytes(Path.Combine(output, "screenshot-animation.png"), secondFrame.EncodeToPNG()); captures.Add("screenshot-animation.png");
            Color32[] secondAnimationFrame = secondFrame.GetPixels32(); Destroy(secondFrame); int changedPixels = 0;
            // First actor card is the actual player. Restrict proof to its art,
            // excluding text and dynamic font-atlas repacking on other pages.
            for (int y = 648 - 270; y < 648 - 206; y++) for (int x = 56; x < 120; x++)
                if (!firstAnimationFrame[y * 1152 + x].Equals(secondAnimationFrame[y * 1152 + x])) changedPixels++;
            Add("animated_source_frames_change", changedPixels > 5);
            var presentation = gallery.Report(proofs, captures.ToArray());
            Add("native_source_pixels_exact", presentation.allNativeTexturesReadable);
            Add("native_animation_clips_available", presentation.allNativeAnimationsReferenced);
            Add("native_audio_available", presentation.audioCount == 138 && presentation.effectsPoolSize == 8);
            Add("original_localization_exact", presentation.localizationExact);
            Add("original_font_available", presentation.originalFontAvailable);
            Add("supplementary_source_glyphs_rendered", presentation.supplementaryGlyphsRendered);
            Add("ninety_original_hair_styles", presentation.hairStyles == 90);
            Add("twenty_four_original_clothing", presentation.clothingPieces == 24);
            Add("original_audio_playback_started", presentation.audioPlaybackStarted);
            Add("gpu_original_pixels_exact", presentation.nativeGpuMismatches == 0 && presentation.nativeGpuComparedPixels > 1000);
            File.WriteAllText(Path.Combine(output, "presentation-result.json"), JsonUtility.ToJson(presentation, true));
            Finish();
        }
        private void Finish()
        {
            Add("no_runtime_exceptions", !runtimeError);
            bool passed = true; foreach (Check check in checks) passed &= check.passed;
            var result = new Result { success = passed, editorVersion = Application.unityVersion, graphicsDeviceType = SystemInfo.graphicsDeviceType.ToString(), frames = frames, width = Screen.width, height = Screen.height, companyName = Application.companyName, productName = Application.productName, identity = identity, checks = checks.ToArray() };
            File.WriteAllText(Path.Combine(output, "result.json"), JsonUtility.ToJson(result, true));
            Debug.Log(passed ? "BLUEMAP_PHASE2_PLAYER_OK" : "BLUEMAP_PHASE2_PLAYER_FAILED"); Application.Quit(passed ? 0 : 1);
        }
        private void Update() { frames++; if (Input.GetKeyDown(KeyCode.Escape)) Application.Quit(); }
        private Texture2D CaptureCamera()
        {
            RenderTexture previousActive = RenderTexture.active, previousTarget = worldCamera.targetTexture;
            RenderTexture target = RenderTexture.GetTemporary(1152, 648, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            try
            {
                worldCamera.targetTexture = target; worldCamera.Render(); RenderTexture.active = target;
                var image = new Texture2D(1152, 648, TextureFormat.RGBA32, false, true);
                image.ReadPixels(new Rect(0, 0, 1152, 648), 0, 0, false); image.Apply(false); return image;
            }
            finally { worldCamera.targetTexture = previousTarget; RenderTexture.active = previousActive; RenderTexture.ReleaseTemporary(target); }
        }
        private void Add(string name, bool passed) => checks.Add(new Check { name = name, passed = passed });
        private void LogReceived(string text, string stack, LogType type) { if (type == LogType.Error || type == LogType.Exception || type == LogType.Assert) runtimeError = true; }
        private void OnDestroy() { Application.logMessageReceived -= LogReceived; }
        private static string Argument(string key) { string[] args = Environment.GetCommandLineArgs(); for (int i = 0; i + 1 < args.Length; i++) if (args[i] == key) return args[i + 1]; return null; }
    }
}
