using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Linq;
using BlueMapMigration.Probe;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace BlueMapMigration.Editor
{
    // Original presentation assets only; never load gameplay or personal saves.
    public static class Phase2Build
    {
        public const string EditorVersion = "6000.3.26f1";
        public const string EditorRevision = "de8167e7440c";
        private const string ScenePath = "Assets/BlueMapProbe/Scenes/Phase2Probe.unity";
        private const string IdentityAssetPath = "Assets/BlueMapProbe/Resources/BuildIdentity.json";

        [Serializable]
        private sealed class PackageInput { public string name, version, source; }
        [Serializable]
        private sealed class DllInput { public string name, sha256; public long bytes; }
        [Serializable]
        private sealed class Report
        {
            public string target = "StandaloneWindows64";
            public string editorVersion = Application.unityVersion;
            public string editorRevision = EditorRevision;
            public string buildResult;
            public int totalErrors;
            public int totalWarnings;
            public long totalBytes;
            public double durationSeconds;
            public string scriptingBackend = "Mono";
            public string renderPipeline = "Built-in";
            public string scope = "Original world, player, safe profiles, equipment, combat, conversations and quests with bounded resident roaming, work and rest routines, remembered encounters and evening guests. Remaining profession, home, farming, water, production and regional systems follow their migration phases";
            public PackageInput[] unityPackages;
            public DllInput[] runtimeDllInputs;
            public BuildIdentity identity;
        }

        public static void BuildWindows()
        {
            string output = Argument("--probe-build-output");
            if (string.IsNullOrWhiteSpace(output) || !Path.IsPathRooted(output))
                throw new BuildFailedException("An absolute --probe-build-output directory is required.");
            output = Path.GetFullPath(output);
            string reportPath = Path.Combine(Directory.GetParent(output).FullName, "build-report.json");
            Report report = new Report { buildResult = "Failed", totalErrors = 1 };
            try
            {
                if (Application.unityVersion != EditorVersion)
                    throw new BuildFailedException("Use pinned Unity " + EditorVersion + ".");
                string identityPath = Argument("--probe-build-identity");
                if (string.IsNullOrWhiteSpace(identityPath) || !Path.IsPathFullyQualified(identityPath))
                    throw new BuildFailedException("An absolute --probe-build-identity JSON path is required.");
                if (!File.Exists(identityPath))
                    throw new BuildFailedException("The --probe-build-identity JSON file does not exist.");
                report.identity = BuildIdentity.Parse(File.ReadAllText(identityPath));
                if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.StandaloneWindows64)
                    throw new BuildFailedException("Start Editor with -buildTarget StandaloneWindows64.");
                if (!BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Standalone, BuildTarget.StandaloneWindows64))
                    throw new BuildFailedException("Windows x64 playback module is missing.");
                if (Directory.Exists(output) && Directory.GetFileSystemEntries(output).Length != 0)
                    throw new BuildFailedException("Build output must be new or empty; existing files are never removed.");
                Directory.CreateDirectory(output);
                Directory.CreateDirectory(Path.GetDirectoryName(reportPath));

                EditorSettings.serializationMode = SerializationMode.ForceText;
                EditorSettings.defaultBehaviorMode = EditorBehaviorMode.Mode2D;
                PlayerSettings.companyName = "BlueMapMigrationTests";
                PlayerSettings.productName = "BlueMapUnityProbe";
                PlayerSettings.bundleVersion = report.identity.previewVersion;
                PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Standalone, "nl.bluemap.migration.probe");
                PlayerSettings.SetScriptingBackend(NamedBuildTarget.Standalone, ScriptingImplementation.Mono2x);
                PlayerSettings.SetApiCompatibilityLevel(NamedBuildTarget.Standalone, ApiCompatibilityLevel.NET_Standard);
                PlayerSettings.colorSpace = ColorSpace.Gamma;
                PlayerSettings.runInBackground = true;
                PlayerSettings.resizableWindow = false;
                PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
                PlayerSettings.defaultScreenWidth = 1152;
                PlayerSettings.defaultScreenHeight = 648;
                PlayerSettings.usePlayerLog = true;
                PlayerSettings.allowFullscreenSwitch = false;
                PlayerSettings.SplashScreen.show = false;
                // The retained art gallery uses legacy input; the walking preview uses
                // the pinned native Input System. Both are intentional in this phase.
                var settings = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/ProjectSettings.asset")[0]);
                settings.FindProperty("activeInputHandler").intValue = 2;
                settings.ApplyModifiedPropertiesWithoutUndo();
                var packageLock = BlueMapMigration.Foundation.FoundationJson.Parse(File.ReadAllText("Packages/packages-lock.json")).Require("dependencies");
                var lockedNames = packageLock.Entries.Select(pair => pair.Key.AsString()).ToArray();
                report.unityPackages = UnityEditor.PackageManager.PackageInfo.GetAllRegisteredPackages()
                    .Select(package => new PackageInput { name = package.name, version = package.version,
                        source = package.source == UnityEditor.PackageManager.PackageSource.BuiltIn ? "builtin" : "registry" })
                    .Where(package => lockedNames.Contains(package.name))
                    .OrderBy(package => package.name, StringComparer.Ordinal).ToArray();
                PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64, false);
                PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneWindows64, new[] { GraphicsDeviceType.Direct3D11 });
                GraphicsSettings.defaultRenderPipeline = null;
                for (int i = 0; i < QualitySettings.names.Length; i++)
                {
                    QualitySettings.SetQualityLevel(i, false);
                    QualitySettings.renderPipeline = null;
                }
                QualitySettings.antiAliasing = 0;
                QualitySettings.vSyncCount = 0;
                QualitySettings.shadows = ShadowQuality.Disable;

                EmbedIdentity(report.identity);
                Phase6Importer.ImportAll(Path.Combine(Directory.GetParent(output).FullName, "import-report.json"));

                // Keep committed scene IDs stable across repeated builds.
                if (AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath) == null)
                {
                    var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                    new GameObject("Technical build preview").AddComponent<Phase2Probe>();
                    Directory.CreateDirectory(Path.GetDirectoryName(ScenePath));
                    if (!EditorSceneManager.SaveScene(scene, ScenePath))
                        throw new BuildFailedException("Could not save probe scene.");
                }
                EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
                AssetDatabase.SaveAssets();
                var build = BuildPipeline.BuildPlayer(new BuildPlayerOptions
                {
                    scenes = new[] { ScenePath },
                    locationPathName = Path.Combine(output, "BlueMapUnityProbe.exe"),
                    target = BuildTarget.StandaloneWindows64,
                    options = BuildOptions.None
                });
                var summary = build.summary;
                report.buildResult = summary.result.ToString();
                report.totalErrors = (int)summary.totalErrors;
                report.totalWarnings = (int)summary.totalWarnings;
                report.totalBytes = (long)summary.totalSize;
                report.durationSeconds = summary.totalTime.TotalSeconds;
                string inputDll = Path.Combine(output, "BlueMapUnityProbe_Data", "Managed", "Unity.InputSystem.dll");
                if (summary.result == BuildResult.Succeeded)
                {
                    byte[] bytes = File.ReadAllBytes(inputDll);
                    using (SHA256 hash = SHA256.Create())
                        report.runtimeDllInputs = new[] { new DllInput { name = "Unity.InputSystem.dll", bytes = bytes.LongLength,
                            sha256 = BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant() } };
                }
                File.WriteAllText(reportPath, JsonUtility.ToJson(report, true));
                if (summary.result != BuildResult.Succeeded || summary.totalErrors != 0)
                    throw new BuildFailedException("Windows probe failed. See the private build log.");
                Debug.Log("BLUEMAP_PHASE2_BUILD_OK");
            }
            catch
            {
                Directory.CreateDirectory(Path.GetDirectoryName(reportPath));
                File.WriteAllText(reportPath, JsonUtility.ToJson(report, true));
                throw;
            }
        }

        private static void EmbedIdentity(BuildIdentity identity)
        {
            // The wrapper calls this only inside a disposable copy of the project.
            // Stable metadata avoids introducing random asset GUIDs into each build.
            string resourcesPath = Path.Combine(Application.dataPath, "BlueMapProbe", "Resources");
            Directory.CreateDirectory(resourcesPath);
            WriteMeta(resourcesPath + ".meta", "Assets/BlueMapProbe/Resources", true);
            string assetPath = Path.Combine(resourcesPath, "BuildIdentity.json");
            File.WriteAllText(assetPath, JsonUtility.ToJson(identity, true), new UTF8Encoding(false));
            WriteMeta(assetPath + ".meta", IdentityAssetPath, false);
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            AssetDatabase.ImportAsset(IdentityAssetPath, ImportAssetOptions.ForceSynchronousImport | ImportAssetOptions.ForceUpdate);
            TextAsset imported = AssetDatabase.LoadAssetAtPath<TextAsset>(IdentityAssetPath);
            if (imported == null || JsonUtility.ToJson(BuildIdentity.Parse(imported.text)) != JsonUtility.ToJson(identity))
                throw new BuildFailedException("The embedded build identity could not be verified after import.");
        }

        private static void WriteMeta(string destination, string assetPath, bool folder)
        {
            string guid;
            using (SHA256 hash = SHA256.Create())
                guid = BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes("BlueMapMigration/" + assetPath)))
                    .Replace("-", "").ToLowerInvariant().Substring(0, 32);
            string importer = folder ? "DefaultImporter" : "TextScriptImporter";
            string metadata = "fileFormatVersion: 2\nguid: " + guid + "\n" + (folder ? "folderAsset: yes\n" : "")
                + importer + ":\n  externalObjects: {}\n  userData: \n  assetBundleName: \n  assetBundleVariant: \n";
            File.WriteAllText(destination, metadata, new UTF8Encoding(false));
        }

        private static string Argument(string key)
        {
            var args = Environment.GetCommandLineArgs();
            for (int i = 0; i + 1 < args.Length; i++)
                if (args[i] == key) return args[i + 1];
            return null;
        }
    }
}
