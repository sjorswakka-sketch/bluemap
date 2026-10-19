using System;
using System.IO;
using BlueMapMigration.Probe;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace BlueMapMigration.Editor
{
    // Phase 2 proves the build route only. No Godot content or saves are imported.
    public static class Phase2Build
    {
        public const string EditorVersion = "6000.3.26f1";
        public const string EditorRevision = "de8167e7440c";
        private const string ScenePath = "Assets/BlueMapProbe/Scenes/Phase2Probe.unity";

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
            public string scope = "Isolated technical probe, not the ported game";
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
                PlayerSettings.bundleVersion = "0.1.0-phase2";
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

                // Keep committed scene IDs stable across repeated builds.
                if (AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath) == null)
                {
                    var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                    new GameObject("Phase 2 — technical build probe").AddComponent<Phase2Probe>();
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

        private static string Argument(string key)
        {
            var args = Environment.GetCommandLineArgs();
            for (int i = 0; i + 1 < args.Length; i++)
                if (args[i] == key) return args[i + 1];
            return null;
        }
    }
}
