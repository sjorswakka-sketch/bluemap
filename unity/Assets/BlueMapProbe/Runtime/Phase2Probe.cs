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
            else if (phase != 3) error = "phase must be 3.";
            else if (previewVersion != "0.1.0-phase3") error = "previewVersion must be 0.1.0-phase3.";
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

    // Own, deliberately small test scene; it does not load any BlueMap game or save data.
    public sealed class Phase2Probe : MonoBehaviour
    {
        [Serializable] public sealed class Check { public string name; public bool passed; }
        [Serializable] public sealed class Result
        {
            public bool success;
            public string editorVersion;
            public string graphicsDeviceType;
            public int frames;
            public int width;
            public int height;
            public string companyName;
            public string productName;
            public BuildIdentity identity;
            public string captureMode = "Camera.Render to GPU RenderTexture; window overlay excluded";
            public bool gameSaveAccessed = false;
            public Check[] checks;
        }

        private readonly List<Check> checks = new List<Check>();
        private readonly List<UnityEngine.Object> ownedArt = new List<UnityEngine.Object>();
        private Transform actor;
        private Camera worldCamera;
        private BoxCollider2D obstacle;
        private Texture2D panel;
        private bool automated;
        private int frames;
        private float walk;
        private string output;
        private bool runtimeError;
        private BuildIdentity identity;
        private const int TilePixels = 32;
        private static readonly Color Sky = Hex(0x131e2d);

        private IEnumerator Start()
        {
            Application.targetFrameRate = 60;
            Application.runInBackground = true;
            Application.logMessageReceived += LogReceived;
            automated = Array.IndexOf(Environment.GetCommandLineArgs(), "--probe-automated") >= 0;
            output = Argument("--probe-output-directory");
            try
            {
                TextAsset embedded = Resources.Load<TextAsset>("BuildIdentity");
                if (embedded == null) throw new FormatException("Embedded BuildIdentity.json is missing.");
                identity = BuildIdentity.Parse(embedded.text);
            }
            catch (Exception exception)
            {
                Debug.LogError("Cannot identify this technical preview: " + exception.Message);
            }
            BuildView();
            Add("pinned_editor_version", Application.unityVersion == "6000.3.26f1");
            Add("separate_test_identity", Application.companyName == "BlueMapMigrationTests" && Application.productName == "BlueMapUnityProbe");
            Add("embedded_identity_consistent", identity != null && identity.editorVersion == Application.unityVersion && Application.platform == RuntimePlatform.WindowsPlayer);
            Add("preview_version", identity != null && Application.version == identity.previewVersion);
            Add("release_player", !Debug.isDebugBuild);
            Add("graphics_device_active", SystemInfo.graphicsDeviceType != GraphicsDeviceType.Null);
            Add("orthographic_camera", worldCamera.orthographic);
            Add("native_32px_tiles", Mathf.Abs((Screen.height / (2 * worldCamera.orthographicSize)) - TilePixels) < .01f);
            Physics2D.SyncTransforms();
            Add("physics2d_query", Physics2D.OverlapPoint(obstacle.transform.position) == obstacle);

            if (!automated) yield break;
            if (string.IsNullOrEmpty(output) || !Path.IsPathRooted(output))
            {
                Debug.LogError("The automated probe requires an absolute output directory.");
                Application.Quit(2);
                yield break;
            }
            Directory.CreateDirectory(output);
            // A hidden Windows window can have a black backbuffer. Explicitly render
            // the actual player camera on the GPU; never generate a substitute image.
            while (frames < 60 || !SplashScreen.isFinished || Time.realtimeSinceStartup < 2.5f) yield return null;
            yield return new WaitForEndOfFrame();
            Texture2D screenshot = CaptureCamera();
            Add("player_loop_60_frames", frames >= 60);
            Add("startup_splash_finished", SplashScreen.isFinished);
            Add("window_1152x648", Screen.width == 1152 && Screen.height == 648);
            Add("rendered_image_available", screenshot != null && screenshot.width == 1152 && screenshot.height == 648);
            if (screenshot != null)
            {
                Color32[] pixels = screenshot.GetPixels32();
                HashSet<int> colors = new HashSet<int>();
                int grassPixels = 0, waterPixels = 0, actorPixels = 0;
                for (int i = 0; i < pixels.Length; i++)
                {
                    Color32 c = pixels[i];
                    int rgb = (c.r << 16) | (c.g << 8) | c.b;
                    colors.Add(rgb);
                    if (rgb == 0x4d7858) grassPixels++;
                    if (rgb == 0x397d97) waterPixels++;
                    if (rgb == 0x538fce) actorPixels++;
                }
                Add("rendered_scene_palette", colors.Count >= 12);
                Add("rendered_grass_water_actor", grassPixels > 1000 && waterPixels > 1000 && actorPixels > 50);
                File.WriteAllBytes(Path.Combine(output, "screenshot.png"), screenshot.EncodeToPNG());
                Destroy(screenshot);
            }
            Add("no_runtime_exceptions", !runtimeError);
            bool passed = true;
            foreach (Check check in checks) passed &= check.passed;
            Result result = new Result
            {
                success = passed,
                editorVersion = Application.unityVersion,
                graphicsDeviceType = SystemInfo.graphicsDeviceType.ToString(),
                frames = frames,
                width = Screen.width,
                height = Screen.height,
                companyName = Application.companyName,
                productName = Application.productName,
                identity = identity,
                checks = checks.ToArray()
            };
            File.WriteAllText(Path.Combine(output, "result.json"), JsonUtility.ToJson(result, true));
            Debug.Log(passed ? "BLUEMAP_PHASE2_PLAYER_OK" : "BLUEMAP_PHASE2_PLAYER_FAILED");
            Application.Quit(passed ? 0 : 1);
        }

        private void Update()
        {
            frames++;
            if (actor == null) return;
            if (automated)
            {
                walk = Mathf.Sin(frames / 16f);
                actor.position = new Vector3(-6 + walk * .7f, -.25f, 0);
            }
            else
            {
                Vector2 movement = Vector2.zero;
                if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow)) movement.x--;
                if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow)) movement.x++;
                if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow)) movement.y++;
                if (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow)) movement.y--;
                Vector3 pos = actor.position + (Vector3)movement.normalized * (Time.deltaTime * 3);
                actor.position = new Vector3(Mathf.Clamp(pos.x, -13, 13), Mathf.Clamp(pos.y, -4.8f, 4.5f), 0);
                if (Input.GetKeyDown(KeyCode.Escape)) Application.Quit();
            }
        }

        private void BuildView()
        {
            worldCamera = new GameObject("Probe camera").AddComponent<Camera>();
            worldCamera.orthographic = true;
            worldCamera.orthographicSize = 10.125f;
            worldCamera.transform.position = new Vector3(0, 0, -10);
            worldCamera.backgroundColor = Sky;
            worldCamera.clearFlags = CameraClearFlags.SolidColor;
            worldCamera.allowHDR = false;
            worldCamera.allowMSAA = false;
            panel = Texture2D.whiteTexture;
            Sprite grass = Pattern(Hex(0x4d7858), Hex(0x639165), false);
            Sprite path = Pattern(Hex(0xbb9c6b), Hex(0xceb789), false);
            Sprite water = Pattern(Hex(0x397d97), Hex(0x68acbb), true);
            Sprite bridge = Pattern(Hex(0xa8794d), Hex(0xd0ab73), true);
            for (int y = -5; y <= 5; y++)
                for (int x = -14; x <= 14; x++)
                {
                    bool river = x >= 2 && x <= 4;
                    bool trail = y == 0 || y == -1;
                    Put("Probe tile", river ? (trail ? bridge : water) : (trail ? path : grass), x, y, 0);
                }
            Sprite stone = Pattern(Hex(0x78868d), Hex(0xaab7b7), false);
            var rock = Put("Physics test stone", stone, -10, 3, 2);
            obstacle = rock.AddComponent<BoxCollider2D>();
            obstacle.size = new Vector2(.8f, .7f);
            foreach (Vector2 pos in new[] { new Vector2(-12, 4), new Vector2(-5, 4), new Vector2(9, 4), new Vector2(12, -4) })
            {
                Put("Probe tree trunk", Solid(Hex(0x715542)), pos.x, pos.y - .2f, 1).transform.localScale = new Vector3(.35f, 1.2f, 1);
                Put("Probe tree crown", Pattern(Hex(0x2f604c), Hex(0x458064), false), pos.x, pos.y + .55f, 2).transform.localScale = new Vector3(1.5f, 1.4f, 1);
            }
            actor = Put("Technical test marker", Actor(), -6, -.25f, 5).transform;
        }

        private Texture2D CaptureCamera()
        {
            RenderTexture previousActive = RenderTexture.active;
            RenderTexture previousTarget = worldCamera.targetTexture;
            RenderTexture target = RenderTexture.GetTemporary(1152, 648, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            try
            {
                worldCamera.targetTexture = target;
                worldCamera.Render();
                RenderTexture.active = target;
                Texture2D image = new Texture2D(1152, 648, TextureFormat.RGBA32, false, true);
                image.ReadPixels(new Rect(0, 0, 1152, 648), 0, 0, false);
                image.Apply(false);
                return image;
            }
            finally
            {
                worldCamera.targetTexture = previousTarget;
                RenderTexture.active = previousActive;
                RenderTexture.ReleaseTemporary(target);
            }
        }

        private Sprite Pattern(Color ground, Color fleck, bool lines)
        {
            Texture2D image = new Texture2D(32, 32, TextureFormat.RGBA32, false);
            Color[] colors = new Color[32 * 32];
            for (int y = 0; y < 32; y++)
                for (int x = 0; x < 32; x++)
                    colors[y * 32 + x] = (lines ? y % 8 == 1 && (x + y) % 17 < 9 : (x * 17 + y * 7) % 43 < 3) ? fleck : ground;
            image.SetPixels(colors);
            return SpriteFor(image);
        }

        private Sprite Solid(Color color) => Pattern(color, color, false);

        private Sprite Actor()
        {
            Texture2D image = new Texture2D(32, 32, TextureFormat.RGBA32, false);
            Color[] pixels = new Color[1024];
            for (int y = 0; y < 32; y++)
                for (int x = 0; x < 32; x++)
                {
                    Color c = Color.clear;
                    if (x >= 9 && x <= 22 && y >= 4 && y <= 7) c = Hex(0x253546);
                    if (x >= 10 && x <= 21 && y >= 8 && y <= 19) c = Hex(0x538fce);
                    if (x >= 10 && x <= 21 && y >= 20 && y <= 28) c = Hex(0xe4b991);
                    if (x >= 9 && x <= 22 && y >= 26 && y <= 30) c = Hex(0x493a3a);
                    if ((x == 12 || x == 19) && y == 23) c = Hex(0x273347);
                    pixels[y * 32 + x] = c;
                }
            image.SetPixels(pixels);
            return SpriteFor(image);
        }

        private Sprite SpriteFor(Texture2D image)
        {
            image.filterMode = FilterMode.Point;
            image.wrapMode = TextureWrapMode.Clamp;
            image.Apply();
            Sprite sprite = Sprite.Create(image, new Rect(0, 0, 32, 32), Vector2.one * .5f, 32);
            ownedArt.Add(image);
            ownedArt.Add(sprite);
            return sprite;
        }

        private static GameObject Put(string name, Sprite sprite, float x, float y, int order)
        {
            var obj = new GameObject(name);
            obj.transform.position = new Vector3(x, y, 0);
            var renderer = obj.AddComponent<SpriteRenderer>();
            renderer.sprite = sprite;
            renderer.sortingOrder = order;
            return obj;
        }

        private void OnGUI()
        {
            if (panel == null) return;
            Matrix4x4 previous = GUI.matrix;
            GUI.matrix = Matrix4x4.Scale(new Vector3(Screen.width / 1152f, Screen.height / 648f, 1));
            GUI.color = Hex(0x1c2c40);
            GUI.DrawTexture(new Rect(48, 30, 1056, 102), panel);
            GUI.color = Color.white;
            var title = new GUIStyle(GUI.skin.label) { fontSize = 27, fontStyle = FontStyle.Bold };
            var copy = new GUIStyle(GUI.skin.label) { fontSize = 17 };
            var badge = new GUIStyle(copy) { alignment = TextAnchor.MiddleRight };
            GUI.Label(new Rect(72, 47, 720, 40), "BLUEMAP QUEST  /  UNITY-PROEF", title);
            GUI.Label(new Rect(74, 91, 850, 28), "Technische preview; de bestaande game blijft veilig in Godot.", copy);
            string buildBadge = identity == null ? "IDENTITEIT ONTBREEKT" : "FASE 3  ·  " + identity.sourceCommit.Substring(0, 8);
            GUI.Label(new Rect(854, 52, 220, 35), buildBadge, badge);
            GUI.color = Hex(0x1c2c40);
            GUI.DrawTexture(new Rect(48, 524, 1056, 94), panel);
            GUI.color = Hex(0xb7e2bf);
            GUI.Label(new Rect(73, 537, 900, 29), "Windows x64   ·   eigen proefbeeld   ·   32 pixels per tegel", copy);
            GUI.color = Color.white;
            GUI.Label(new Rect(73, 575, 1000, 27), automated ? "Automatische start- en beeldcontrole actief." : "WASD / pijlen: verplaats het proefpersonage     ·     Esc: sluiten", copy);
            GUI.matrix = previous;
        }

        private void Add(string name, bool passed) => checks.Add(new Check { name = name, passed = passed });

        private void LogReceived(string text, string stack, LogType type)
        {
            if (type == LogType.Error || type == LogType.Exception || type == LogType.Assert) runtimeError = true;
        }

        private void OnDestroy()
        {
            Application.logMessageReceived -= LogReceived;
            foreach (UnityEngine.Object item in ownedArt) if (item != null) Destroy(item);
        }

        private static string Argument(string key)
        {
            var args = Environment.GetCommandLineArgs();
            for (int i = 0; i + 1 < args.Length; i++) if (args[i] == key) return args[i + 1];
            return null;
        }

        private static Color Hex(int rgb) => new Color32((byte)(rgb >> 16), (byte)(rgb >> 8), (byte)rgb, 255);
    }
}
