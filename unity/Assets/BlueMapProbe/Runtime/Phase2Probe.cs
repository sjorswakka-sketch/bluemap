using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
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
            else if (phase != 14) error = "phase must be 14.";
            else if (previewVersion != "0.10.0-phase14") error = "previewVersion must be 0.10.0-phase14.";
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

    // Original-art gallery and isolated foundation test. No personal save or settings access.
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
        private BlueMapMigration.Foundation.FoundationView foundationView;
        private BlueMapMigration.Player.PlayerWorld playerWorld;
        private BlueMapMigration.Persistence.PersistenceCoordinator persistence;
        private BlueMapMigration.Persistence.PersistencePanel persistencePanel;
        private BlueMapMigration.Route.RouteWorldController route;
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
            if (!automated)
            {
                EnsureFoundationView();
                gallery.gameObject.SetActive(false); foundationView.gameObject.SetActive(false);
                EnsurePlayerWorld();
                EnsurePersistence(false);ShowPersistence();
                yield break;
            }
            // Automated virtual devices are deliberately exercised without taking focus
            // from the user's app. Real adventures retain normal focus handling.
            UnityEngine.InputSystem.InputSystem.settings.backgroundBehavior=UnityEngine.InputSystem.InputSettings.BackgroundBehavior.IgnoreFocus;
            Add("automated_input_background_scope",automated&&UnityEngine.InputSystem.InputSystem.settings.backgroundBehavior==UnityEngine.InputSystem.InputSettings.BackgroundBehavior.IgnoreFocus);
            while (frames < 60 || !SplashScreen.isFinished || Time.realtimeSinceStartup < 2.5f) yield return null;
            gallery.CheckNativeAnimationBoundaries();
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
            // The source viewport PNG stores premultiplied RGB. Render every
            // partial-alpha pixel over opaque black: its exact output RGB must
            // equal the retained source RGB, without another texture-alpha step.
            Color previousBackground = worldCamera.backgroundColor;
            bool premultipliedCaptureSaved = false, tintChecked = false;
            worldCamera.backgroundColor = Color.black;
            try
            {
                foreach (var texture in gallery.Catalog.textures.Where(value => value.definition.alphaMode == "premultiplied").OrderBy(value => value.definition.id.StartsWith("generated:swords", StringComparison.Ordinal) ? 0 : 1).ThenBy(value => value.definition.id, StringComparer.Ordinal))
                {
                    Color32[] source = texture.texture.GetPixels32();
                    var textureProof = new BlueMapMigration.Phase6.PremultipliedTextureProof { id = texture.definition.id };
                    for (int top = 0; top < texture.texture.height; top += 648) for (int left = 0; left < texture.texture.width; left += 1152)
                    {
                        gallery.ShowPremultipliedTexture(texture, left, top);
                        yield return new WaitForEndOfFrame();
                        Texture2D image = CaptureCamera();
                        var chunk = gallery.ComparePremultipliedChunk(texture, left, top, source, image);
                        textureProof.comparedPixels += chunk.comparedPixels; textureProof.alphaOnePixels += chunk.alphaOnePixels; textureProof.mismatches += chunk.mismatches;
                        if (!premultipliedCaptureSaved && chunk.comparedPixels > 0)
                        {
                            File.WriteAllBytes(Path.Combine(output, "screenshot-premultiplied.png"), image.EncodeToPNG()); captures.Add("screenshot-premultiplied.png"); premultipliedCaptureSaved = true;
                        }
                        Destroy(image);
                        if (!tintChecked && gallery.HasExactTintSamples(texture, left, top, source))
                        {
                            gallery.ShowPremultipliedTexture(texture, left, top, true);
                            yield return new WaitForEndOfFrame();
                            Texture2D tinted = CaptureCamera();
                            var tint = gallery.ComparePremultipliedChunk(texture, left, top, source, tinted, true);
                            textureProof.tintComparedPixels += tint.tintComparedPixels; textureProof.tintMismatches += tint.tintMismatches;
                            Destroy(tinted); tintChecked = true;
                        }
                    }
                    gallery.RecordPremultipliedProof(textureProof);
                }
            }
            finally { worldCamera.backgroundColor = previousBackground; }
            gallery.Show("overview"); gallery.SampleAnimations(.125f);
            var presentation = gallery.Report(proofs, captures.ToArray());
            Add("native_source_pixels_exact", presentation.allNativeTexturesReadable);
            Add("native_animation_clips_available", presentation.allNativeAnimationsReferenced);
            Add("native_animation_boundaries_exact", presentation.nativeBoundaryFramesExact);
            Add("native_audio_available", presentation.audioCount == 138 && presentation.effectsPoolSize == 8);
            Add("original_localization_exact", presentation.localizationExact);
            Add("original_font_available", presentation.originalFontAvailable);
            Add("supplementary_source_glyphs_rendered", presentation.supplementaryGlyphsRendered);
            Add("ninety_original_hair_styles", presentation.hairStyles == 90);
            Add("twenty_four_original_clothing", presentation.clothingPieces == 24);
            Add("original_audio_playback_started", presentation.audioPlaybackStarted);
            Add("gpu_original_pixels_exact", presentation.nativeGpuMismatches == 0 && presentation.nativeGpuComparedPixels > 1000);
            Add("gpu_premultiplied_pixels_exact", presentation.premultipliedPixelsExact);
            File.WriteAllText(Path.Combine(output, "presentation-result.json"), JsonUtility.ToJson(presentation, true));
            var foundation = BlueMapMigration.Foundation.FoundationProbeRunner.Run(identity);
            Add("foundation_runtime_verified", foundation.success);
            File.WriteAllText(Path.Combine(output, "foundation-result.json"), JsonUtility.ToJson(foundation, true));
            EnsureFoundationView();
            gallery.gameObject.SetActive(false); foundationView.gameObject.SetActive(true);
            foundationView.Show("village");
            yield return new WaitForEndOfFrame();
            Texture2D foundationCapture = CaptureCamera();
            File.WriteAllBytes(Path.Combine(output, "screenshot-foundation.png"), foundationCapture.EncodeToPNG());
            Destroy(foundationCapture);
            foundationView.Show("cave");
            yield return new WaitForEndOfFrame();
            Texture2D caveCapture = CaptureCamera();
            File.WriteAllBytes(Path.Combine(output, "screenshot-foundation-cave.png"), caveCapture.EncodeToPNG());
            Destroy(caveCapture);
            foundationView.gameObject.SetActive(false);
            yield return null;
            EnsurePlayerWorld();
            var player = BlueMapMigration.Player.PlayerProbeRunner.Run(identity, playerWorld);
            yield return new WaitForEndOfFrame();
            Texture2D playerCapture = CaptureCamera();
            File.WriteAllBytes(Path.Combine(output, "screenshot-player.png"), playerCapture.EncodeToPNG());
            playerWorld.AvatarRenderer.enabled=false;
            Texture2D withoutAvatar=CaptureCamera();playerWorld.AvatarRenderer.enabled=true;
            Color32[] withPixels=playerCapture.GetPixels32(),withoutPixels=withoutAvatar.GetPixels32();
            int avatarPixels=0;for(int i=0;i<withPixels.Length;i++)if(!withPixels[i].Equals(withoutPixels[i]))avatarPixels++;
            bool avatarVisible=avatarPixels>100;
            player.checks=player.checks.Concat(new[]{new Check{name="player_world_avatar_rendered_on_gpu",passed=avatarVisible}}).ToArray();
            player.success &= avatarVisible;
            Add("player_runtime_verified",player.success);
            File.WriteAllText(Path.Combine(output,"player-result.json"),JsonUtility.ToJson(player,true));
            Destroy(playerCapture);Destroy(withoutAvatar);
            Texture2D playerUiCapture = ScreenCapture.CaptureScreenshotAsTexture();
            File.WriteAllBytes(Path.Combine(output,"screenshot-player-ui.png"),playerUiCapture.EncodeToPNG()); Destroy(playerUiCapture);
            playerWorld.ToggleControls();
            yield return new WaitForEndOfFrame();
            Texture2D controlsCapture = ScreenCapture.CaptureScreenshotAsTexture();
            File.WriteAllBytes(Path.Combine(output,"screenshot-player-controls.png"),controlsCapture.EncodeToPNG()); Destroy(controlsCapture);
            playerWorld.ToggleControls();
            playerWorld.Motor.RollCooldown = 0; playerWorld.Motor.TryRoll(Vector2.right); playerWorld.Motor.RollTimer = .21;
            playerWorld.UpdateAppearance();
            yield return new WaitForEndOfFrame();
            Texture2D rollCapture = CaptureCamera();
            File.WriteAllBytes(Path.Combine(output, "screenshot-player-roll.png"), rollCapture.EncodeToPNG()); Destroy(rollCapture);
            BlueMapMigration.Persistence.PersistenceProbeRunner.Result persistenceProof;
            try{persistenceProof=BlueMapMigration.Persistence.PersistenceProbeRunner.Run(identity,output,playerWorld.InputSource);}
            catch(Exception error){Debug.LogError("Native persistence proof failed: "+error);Add("persistence_runtime_verified",false);Finish();yield break;}
            Add("persistence_runtime_verified",persistenceProof.success);
            File.WriteAllText(Path.Combine(output,"persistence-result.json"),JsonUtility.ToJson(persistenceProof,true));
            EnsurePersistence(true);ShowPersistence();
            yield return new WaitForEndOfFrame();
            Texture2D persistenceCapture=ScreenCapture.CaptureScreenshotAsTexture();
            File.WriteAllBytes(Path.Combine(output,"screenshot-persistence.png"),persistenceCapture.EncodeToPNG());Destroy(persistenceCapture);
            persistencePanel.Visible=false;
            EnsurePlayerWorld();EnsureRoute();
            BlueMapMigration.Route.RouteProbeRunner.Result routeProof;
            try{routeProof=BlueMapMigration.Route.RouteProbeRunner.Run(identity,output,playerWorld,route);}
            catch(Exception error){Debug.LogError("Native route proof failed: "+error);Add("route_runtime_verified",false);Finish();yield break;}
            Add("route_runtime_verified",routeProof.success);
            File.WriteAllText(Path.Combine(output,"route-result.json"),JsonUtility.ToJson(routeProof,true));
            foreach(string map in new[]{"village","player_home","forest"})
            {
                route.CloseModal();
                string spawn=route.Session.Repository.Read(map).Arrivals.FirstOrDefault(v=>v.Name=="start")?.Name??route.Session.Repository.Read(map).Arrivals[0].Name;
                route.TryTravel(map,spawn);
                playerWorld.Present(route.Session.Current,map=="village"?new Vector2(770,624):map=="player_home"?new Vector2(208,240):new Vector2(350,976));
                yield return new WaitForEndOfFrame();
                Texture2D routeCapture=ScreenCapture.CaptureScreenshotAsTexture();
                File.WriteAllBytes(Path.Combine(output,"screenshot-route-"+(map=="player_home"?"home":map)+".png"),routeCapture.EncodeToPNG());Destroy(routeCapture);
            }
            route.CloseModal();route.TryTravel("village",route.Session.Repository.Read("village").Arrivals.First(v=>v.Name=="start").Name);
            playerWorld.Present(route.Session.Current,new Vector2(770,624));route.Tick(.02);
            yield return new WaitForEndOfFrame();SaveRouteCapture("ui");
            route.Gameplay.Talk("pim");
            yield return new WaitForEndOfFrame();SaveRouteCapture("dialogue");
            route.CloseModal();route.OpenInventory();
            yield return new WaitForEndOfFrame();SaveRouteCapture("inventory");
            route.CloseModal();
            var accessProof=BlueMapMigration.WorldAccess.WorldAccessProbeRunner.Run(identity,output,playerWorld,route,gallery.Catalog);
            bool accessFailed=false;
            while(true)
            {
                object current=null;bool more=false;
                try{more=accessProof.MoveNext();if(more)current=accessProof.Current;}
                catch(Exception error){Debug.LogError("Native world access proof failed: "+error);accessFailed=true;}
                if(accessFailed||!more)break;yield return current;
            }
            Add("world_access_runtime_verified",!accessFailed&&BlueMapMigration.WorldAccess.WorldAccessProbeRunner.Last.success);
            var capturePositions=new[]{new Vector2(880,304),new Vector2(784,288),new Vector2(688,496),new Vector2(1136,1168),new Vector2(1328,880),new Vector2(288,304),new Vector2(464,432),new Vector2(304,208)};int accessCaptureIndex=0;
            foreach(var captureArea in new[]{new[]{"lake","lake"},new[]{"kruipmoeras","swamp"},new[]{"prismamine","mountain"},new[]{"steampeak","steampeak"},new[]{"harbor","coast"},new[]{"library","library"},new[]{"reedvault","reedvault"},new[]{"inn","interior"}})
            {
                route.CloseModal();var area=route.Session.Repository.Read(captureArea[0]);route.TryTravel(captureArea[0],area.Arrivals.FirstOrDefault(a=>a.Name=="start")?.Name??area.Arrivals[0].Name);
                playerWorld.Present(route.Session.Current,route.Access.ResolveArrival(route.Session.Current,capturePositions[accessCaptureIndex++]));route.Tick(.02);
                yield return new WaitForEndOfFrame();Texture2D capture=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(output,"screenshot-access-"+captureArea[1]+".png"),capture.EncodeToPNG());Destroy(capture);
            }
            var inventoryProof=BlueMapMigration.Inventory.InventoryProbeRunner.Run(identity,output,playerWorld,route,gallery.Catalog);
            bool inventoryFailed=false;
            while(true)
            {
                object current=null;bool more=false;
                try{more=inventoryProof.MoveNext();if(more)current=inventoryProof.Current;}
                catch(Exception error){Debug.LogError("Native inventory proof failed: "+error);inventoryFailed=true;}
                if(inventoryFailed||!more)break;yield return current;
            }
            Add("inventory_runtime_verified",!inventoryFailed&&BlueMapMigration.Inventory.InventoryProbeRunner.Last.success);
            var progressionProof=BlueMapMigration.Progression.ProgressionProbeRunner.Run(identity,output,playerWorld,route,gallery.Catalog);
            bool progressionFailed=false;
            while(true)
            {
                object current=null;bool more=false;
                try{more=progressionProof.MoveNext();if(more)current=progressionProof.Current;}
                catch(Exception error){Debug.LogError("Native progression proof failed: "+error);progressionFailed=true;}
                if(progressionFailed||!more)break;yield return current;
            }
            Add("progression_runtime_verified",!progressionFailed&&BlueMapMigration.Progression.ProgressionProbeRunner.Last.success);
            var combatProof=BlueMapMigration.Combat.CombatProbeRunner.Run(identity,output,playerWorld,route,gallery.Catalog);
            bool combatFailed=false;
            while(true)
            {
                object current=null;bool more=false;
                try{more=combatProof.MoveNext();if(more)current=combatProof.Current;}
                catch(Exception error){Debug.LogError("Native combat proof failed: "+error);combatFailed=true;}
                if(combatFailed||!more)break;yield return current;
            }
            Add("combat_runtime_verified",!combatFailed&&BlueMapMigration.Combat.CombatProbeRunner.Last.success);
            Finish();
        }
        private void SaveRouteCapture(string name)
        {Texture2D capture=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(output,"screenshot-route-"+name+".png"),capture.EncodeToPNG());Destroy(capture);}
        private void EnsureRoute()
        {
            if(route!=null)return;
            route=new GameObject("BlueMap Quest first playable route").AddComponent<BlueMapMigration.Route.RouteWorldController>();
            route.Initialize(playerWorld,worldCamera,gallery.Catalog,automated);
            route.ProfilesRequested+=ShowPersistence;
        }
        private void StartAdventure(bool fresh)
        {
            EnsureRoute();bool started=fresh?route.BeginNew(persistence):route.BeginContinue(persistence);
            if(!started)return;
            persistencePanel.Visible=false;gallery.gameObject.SetActive(false);foundationView.gameObject.SetActive(false);playerWorld.gameObject.SetActive(true);
        }
        private void EnsurePersistence(bool fixture)
        {
            if(persistencePanel!=null)return;
            persistence=fixture?BlueMapMigration.Persistence.PersistenceProbeRunner.Fixture:new BlueMapMigration.Persistence.PersistenceCoordinator(BlueMapMigration.Foundation.FoundationWorldRepository.LoadRequired(),playerWorld.InputSource,BlueMapMigration.Persistence.PersistencePaths.UnityDefault);
            persistencePanel=new BlueMapMigration.Persistence.PersistencePanel();persistencePanel.Initialize(persistence,playerWorld.InputSource);
            persistencePanel.WalkRequested+=()=>{if(route!=null&&!route.PrepareMovementPreview())return;persistencePanel.Visible=false;EnsurePlayerWorld();};
            persistencePanel.ControlsRequested+=()=>{if(route!=null&&!route.PrepareMovementPreview())return;persistencePanel.Visible=false;EnsurePlayerWorld();if(!playerWorld.ControlsOpen)playerWorld.ToggleControls();};
            persistencePanel.NewAdventureRequested+=()=>StartAdventure(true);
            persistencePanel.ContinueAdventureRequested+=()=>StartAdventure(false);
            persistence.PreferencesChanged+=()=>{playerWorld.SetPersistencePreferences(persistence.Preferences,persistence.HasProfile);gallery.Audio.SetVolumes((float)persistence.Preferences.MusicVolume,(float)persistence.Preferences.SfxVolume,persistence.Preferences.Muted);};
            playerWorld.SetPersistencePreferences(persistence.Preferences,persistence.HasProfile);
        }
        private void ShowPersistence()
        {playerWorld.gameObject.SetActive(false);foundationView.gameObject.SetActive(false);gallery.gameObject.SetActive(false);RestoreGalleryCamera();persistencePanel.Visible=true;playerWorld.InputSource.SetContext(false,true);playerWorld.InputSource.SetFocused(Application.isFocused);}
        private void EnsurePlayerWorld()
        {
            if (playerWorld != null) { playerWorld.gameObject.SetActive(true); return; }
            playerWorld = new GameObject("Source player movement preview").AddComponent<BlueMapMigration.Player.PlayerWorld>();
            playerWorld.Initialize(gallery.Catalog, worldCamera, automated);
        }
        private void RestoreGalleryCamera()
        { worldCamera.orthographicSize = 10.125f; worldCamera.transform.position = new Vector3(0,0,-10); }
        private void EnsureFoundationView()
        {
            if (foundationView != null) return;
            foundationView = new GameObject("Isolated area foundation").AddComponent<BlueMapMigration.Foundation.FoundationView>();
            foundationView.Initialize(gallery.Catalog, automated);
        }
        private void Finish()
        {
            Add("no_runtime_exceptions", !runtimeError);
            bool passed = true; foreach (Check check in checks) passed &= check.passed;
            var result = new Result { success = passed, editorVersion = Application.unityVersion, graphicsDeviceType = SystemInfo.graphicsDeviceType.ToString(), frames = frames, width = Screen.width, height = Screen.height, companyName = Application.companyName, productName = Application.productName, identity = identity, checks = checks.ToArray() };
            File.WriteAllText(Path.Combine(output, "result.json"), JsonUtility.ToJson(result, true));
            Debug.Log(passed ? "BLUEMAP_PHASE2_PLAYER_OK" : "BLUEMAP_PHASE2_PLAYER_FAILED"); Application.Quit(passed ? 0 : 1);
        }
        private void Update()
        {
            frames++;
            if(route!=null&&route.Running)return;
            if (Input.GetKeyDown(KeyCode.Escape) && (playerWorld == null || !playerWorld.gameObject.activeSelf)) Application.Quit();
            if (automated || foundationView == null) return;
            if (playerWorld != null && playerWorld.gameObject.activeSelf && playerWorld.ControlsOpen) return;
            if(persistencePanel!=null&&persistencePanel.Visible&&persistencePanel.EditingSourceDirectory)return;
            if(Input.GetKeyDown(KeyCode.Alpha9)){EnsurePersistence(false);ShowPersistence();}
            if(persistencePanel!=null&&persistencePanel.Visible)
            {
                if(Input.GetKeyDown(KeyCode.Alpha8)){if(route!=null&&!route.PrepareMovementPreview())return;persistencePanel.Visible=false;EnsurePlayerWorld();}
                if(Input.GetKeyDown(KeyCode.F9)){if(route!=null&&!route.PrepareMovementPreview())return;persistencePanel.Visible=false;EnsurePlayerWorld();if(!playerWorld.ControlsOpen)playerWorld.ToggleControls();}
                return;
            }
            var pad=UnityEngine.InputSystem.Gamepad.current;
            if(playerWorld!=null&&playerWorld.gameObject.activeSelf&&playerWorld.InputSource.ControllerActive&&pad!=null&&pad.startButton.isPressed&&pad.selectButton.wasPressedThisFrame){EnsurePersistence(false);ShowPersistence();return;}
            if (Input.GetKeyDown(KeyCode.Alpha8)) { foundationView.gameObject.SetActive(false); gallery.gameObject.SetActive(false); EnsurePlayerWorld(); }
            if (Input.GetKeyDown(KeyCode.Alpha7)) { if(playerWorld!=null)playerWorld.gameObject.SetActive(false); RestoreGalleryCamera(); gallery.gameObject.SetActive(false); foundationView.gameObject.SetActive(true); }
            if(playerWorld!=null && playerWorld.gameObject.activeSelf)
            {
                if(Input.GetKeyDown(KeyCode.F1))playerWorld.Show("village");
                if(Input.GetKeyDown(KeyCode.F2))playerWorld.Show("forest");
                if(Input.GetKeyDown(KeyCode.F3))playerWorld.Show("cave");
            }
            for (int i = 0; i < 6; i++) if (Input.GetKeyDown(KeyCode.Alpha1 + i))
            { if(playerWorld!=null)playerWorld.gameObject.SetActive(false); RestoreGalleryCamera(); foundationView.gameObject.SetActive(false); gallery.gameObject.SetActive(true); gallery.Show(BlueMapMigration.Phase6.Phase6Gallery.Pages[i]); }
        }
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
        private void OnGUI()
        {
            if(persistencePanel==null||!persistencePanel.Visible)return;
            var old=GUI.matrix;var oldFont=GUI.skin.font;GUI.matrix=Matrix4x4.Scale(new Vector3(Screen.width/1152f,Screen.height/648f,1));GUI.skin.font=gallery.Catalog.originalFont;
            persistencePanel.Draw(new Rect(20,20,1112,608));GUI.skin.font=oldFont;GUI.matrix=old;
        }
        private void LogReceived(string text, string stack, LogType type) { if (type == LogType.Error || type == LogType.Exception || type == LogType.Assert) runtimeError = true; }
        private void OnApplicationFocus(bool focused){if(persistencePanel!=null&&persistencePanel.Visible)playerWorld.InputSource.SetFocused(focused);}
        private void OnDestroy() { persistence?.Dispose();Application.logMessageReceived -= LogReceived; }
        private static string Argument(string key) { string[] args = Environment.GetCommandLineArgs(); for (int i = 0; i + 1 < args.Length; i++) if (args[i] == key) return args[i + 1]; return null; }
    }
}
