using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Persistence;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Probe;
using BlueMapMigration.Route;
using UnityEngine;

namespace BlueMapMigration.Completion
{
    /// <summary>Native proof of the ending, New Game+, the way back to Godot, frame times and a long session through every map.</summary>
    public static class CompletionProbeRunner
    {
        [Serializable]
        public sealed class Result
        {
            public int schemaVersion = 1;
            public BuildIdentity identity;
            public bool success;
            public bool gameSaveAccessed = false;
            public Phase2Probe.Check[] checks = Array.Empty<Phase2Probe.Check>();
            public string[] frameMaps = Array.Empty<string>();
            public float[] frameAverageMs = Array.Empty<float>();
            public float[] frameSlowestMs = Array.Empty<float>();
            public int sessionMaps;
            public float sessionSimulatedMinutes;
            public int sessionErrors;
            public float sessionMemoryGrowthMb;
        }

        public static Result Last { get; private set; }
        public static PersistenceCoordinator Fixture { get; private set; }
        public const float FrameBudgetMs = 33.4f; // never below thirty pictures a second, also at low process priority

        public static IEnumerator Run(BuildIdentity identity, string output, PlayerWorld world,
            RouteWorldController route, Phase6Catalog catalog)
        {
            Last = new Result { identity = identity };
            var checks = new List<Phase2Probe.Check>();
            void Check(string name, bool passed)
            {
                if (checks.Any(row => row.name == name))
                    throw new InvalidOperationException("Duplicate completion proof " + name);
                checks.Add(new Phase2Probe.Check { name = name, passed = passed });
                Last.checks = checks.ToArray();
                if (!passed) Debug.Log("Completion native check failed: " + name);
            }

            var repository = FoundationWorldRepository.LoadRequired();
            // The way back: every recorded original save, written by this player, equals what the real Godot loaded.
            LegacyExportChecks.Verify(repository, Check);

            string root = PersistencePaths.Checked(Path.Combine(output, "completion-profiles"));
            if (Directory.Exists(root)) throw new IOException("Fresh completion profile required");
            route.CloseModal();
            Fixture = new PersistenceCoordinator(repository, world.InputSource, root);
            if (!route.BeginNew(Fixture)) throw new IOException(Fixture.Status);
            route.CombatSimulationEnabled = false;
            route.ResidentsSimulationEnabled = false;
            Check("completion_native_shared_state_and_profile", Fixture.Current.Snapshot.CopyOriginals().Count == 0 && route.Ending != null
                && !RouteWorldController.NgPlusAvailable(Fixture));

            var live = RunLiveEpisodes(output, repository, world, route, Check);
            while (live.MoveNext()) yield return live.Current;

            Check("completion_no_personal_saves_used", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && PersistencePaths.Within(PersistencePaths.Checked(output), root)
                && !PersistencePaths.Within(PersistencePaths.UnityDefault, root)
                && !PersistencePaths.Within(PersistencePaths.LegacyDefault, root));
            route.CloseModal();
            route.AtmosphereEnabled = false;
            route.Save();
            Last.success = checks.Count > 5 && checks.All(row => row.passed);
            Last.checks = checks.ToArray();
            File.WriteAllText(Path.Combine(output, "completion-result.json"), JsonUtility.ToJson(Last, true));
            Debug.Log("Completion native proof: " + checks.Count + " checks");
        }

        static IEnumerator RunLiveEpisodes(string output, FoundationWorldRepository repository,
            PlayerWorld world, RouteWorldController route, Action<string, bool> check)
        {
            var state = route.Gameplay.State;
            bool Travel(string map)
            {
                route.CloseModal();
                var source = repository.Read(map);
                string spawn = source.Arrivals.FirstOrDefault(row => row.Name == "start")?.Name ?? source.Arrivals[0].Name;
                if (!route.TryTravel(map, spawn)) { Debug.Log("Completion detail travel failed: " + map + " " + route.Message); return false; }
                state = route.Gameplay.State; route.Combat.ResetTransient(); route.Tick(0); return true;
            }
            void Detail(string name, params (string key, object value)[] parts)
                => Debug.Log("Completion detail " + name + ": " + String.Join(" ", parts.Select(part => part.key + "=" + part.value)));
            int captures = 0;
            void Capture(string name)
            {
                string path = Path.Combine(output, "screenshot-completion-" + name + ".png");
                if (File.Exists(path)) throw new IOException("Fresh completion capture required");
                var image = ScreenCapture.CaptureScreenshotAsTexture();
                try
                {
                    if (image.width != 1152 || image.height != 648) throw new InvalidOperationException("Completion viewport differs");
                    File.WriteAllBytes(path, image.EncodeToPNG()); captures++;
                }
                finally { UnityEngine.Object.Destroy(image); }
            }
            var importer = new LegacySaveImporter(repository);
            string gear = importer.Rules.Require("gear").Entries[0].Key.AsString();

            // --- Frame times on the busiest maps, with day, weather and lamps drawn ---
            int oldVsync = QualitySettings.vSyncCount, oldTarget = Application.targetFrameRate;
            QualitySettings.vSyncCount = 0; Application.targetFrameRate = -1;
            route.AtmosphereEnabled = true; route.ResidentsSimulationEnabled = true;
            var frameMaps = new[] { "village", "forest", "ijsdal", "dorstvallei", "lake" };
            var averages = new List<float>(); var slowest = new List<float>(); bool measured = true;
            foreach (string map in frameMaps)
            {
                if (!Travel(map)) { measured = false; break; }
                state.DayTime = map == "forest" ? .8 : .3; route.Tick(0);
                for (int i = 0; i < 20; i++) { route.Tick(Time.unscaledDeltaTime); yield return null; }
                var samples = new List<float>();
                for (int i = 0; i < 150; i++) { route.Tick(Math.Min(.05, Time.unscaledDeltaTime)); yield return null; samples.Add(Time.unscaledDeltaTime * 1000f); }
                samples.Sort(); averages.Add(samples.Average()); slowest.Add(samples[(int)(samples.Count * .95f)]);
            }
            QualitySettings.vSyncCount = oldVsync; Application.targetFrameRate = oldTarget;
            route.ResidentsSimulationEnabled = false;
            Last.frameMaps = frameMaps; Last.frameAverageMs = averages.ToArray(); Last.frameSlowestMs = slowest.ToArray();
            Detail("frames", ("maps", String.Join(",", frameMaps)), ("averageMs", String.Join(",", averages.Select(v => v.ToString("0.00")))), ("slowestMs", String.Join(",", slowest.Select(v => v.ToString("0.00")))));
            check("completion_native_frame_time_within_budget", measured && averages.Count == frameMaps.Length && averages.All(v => v > 0 && v <= FrameBudgetMs));

            // --- A long session: every map, residents alive, days passing, saving and reloading on the way ---
            int errors = 0; void Logged(string message, string trace, LogType type) { if (type == LogType.Error || type == LogType.Exception || type == LogType.Assert) errors++; }
            Application.logMessageReceived += Logged;
            long memoryBefore = GC.GetTotalMemory(true); int visitedMaps = 0; double simulated = 0; bool sessionOk = true; long daysBefore = state.DayCount;
            route.ResidentsSimulationEnabled = true;
            try
            {
                foreach (string map in repository.MapIds)
                {
                    if (!Travel(map)) { sessionOk = false; Detail("session", ("refused", map)); continue; }
                    visitedMaps++; state.Hp = route.Gameplay.MaxHp;
                    for (int i = 0; i < 600; i++) { route.Tick(1.0 / 30); simulated += 1.0 / 30; if (i % 150 == 149) yield return null; }
                    if (state.Ended || !route.Running) { sessionOk = false; Detail("session", ("stopped", map)); break; }
                    if (visitedMaps % 9 == 0) { sessionOk &= route.Save() && route.Reload(false); route.Tick(0); state = route.Gameplay.State; route.ResidentsSimulationEnabled = true; }
                }
            }
            finally { Application.logMessageReceived -= Logged; }
            route.ResidentsSimulationEnabled = false;
            float growth = (GC.GetTotalMemory(true) - memoryBefore) / 1048576f;
            Last.sessionMaps = visitedMaps; Last.sessionSimulatedMinutes = (float)(simulated / 60); Last.sessionErrors = errors; Last.sessionMemoryGrowthMb = growth;
            bool session = sessionOk && visitedMaps == repository.MapIds.Count && visitedMaps == 37 && errors == 0 && growth < 200 && simulated >= 700 && state.DayCount >= daysBefore;
            Detail("session", ("maps", visitedMaps), ("minutes", (simulated / 60).ToString("0.0")), ("errors", errors), ("growthMb", growth.ToString("0.0")), ("days", state.DayCount));
            check("completion_native_long_session_through_all_maps", session);
            route.AtmosphereEnabled = false;

            // --- The ending: epilogue, your numbers, credits and a thank you ---
            Travel("temple");
            state.Set("inventory", InventoryModel.Replace(InventoryModel.Replace(InventoryModel.Replace(state.Get("inventory"), "heart_container", FoundationValue.Integer(2)), "boots", FoundationValue.Integer(1)), gear, FoundationValue.Integer(1)));
            route.Progression.SetWeapon("iron"); state.Set("kills", FoundationValue.Integer(42)); state.Coins = 77; route.Tick(0);
            bool lockedBefore = !RouteWorldController.NgPlusAvailable(Fixture) && !route.BeginNewGamePlus(Fixture) && route.Running;
            route.RequestEnding(); route.Tick(0);
            var ending = route.Ending;
            bool opened = route.Modal == "victory" && ending.IsOpen && ending.Pages.Count == 10 && state.Flag("game_completed") && state.MapId == "village"
                && Fixture.Current.Snapshot.State.Require("map").AsString() == "village";
            var stats = ending.Stats;
            bool numbers = stats.Count == 6 && stats[1].value == "42" && stats[2].value == "77" && stats[4].value == "7" && stats[3].value != "" && stats[0].value.Split(':').Length == 3;
            bool typing = !ending.LineComplete; route.Tick(.2); typing &= !ending.LineComplete; ending.Advance(); typing &= ending.LineComplete && ending.PageIndex == 0;
            yield return new WaitForEndOfFrame(); bool fits = ending.LayoutFits && ending.Draws > 0; Capture("epilogue");
            ending.Advance(); ending.Advance(); bool lines = ending.PageIndex == 0; ending.Advance(); ending.Advance(); ending.Advance(); lines &= ending.PageIndex == 1;
            int guard = 0; while (ending.IsOpen && ending.Current.Type == "text" && guard++ < 40) { ending.Advance(); yield return new WaitForEndOfFrame(); fits &= ending.LayoutFits; }
            bool onStats = ending.IsOpen && ending.Current.Type == "stats"; yield return new WaitForEndOfFrame(); fits &= ending.LayoutFits; Capture("stats");
            ending.Advance(); bool credits = ending.Current.Type == "credits" && EndingPanel.Credits.Length == 30; route.Tick(2); yield return new WaitForEndOfFrame();
            for (int i = 0; i < 80 && ending.IsOpen && ending.Current.Type == "credits"; i++) route.Tick(1);
            bool rolled = ending.IsOpen && ending.Current.Type == "end"; yield return new WaitForEndOfFrame(); fits &= ending.LayoutFits;
            ending.Advance(); bool closed = !ending.IsOpen && route.Modal == "" && route.Message != "";
            if (!(opened && numbers && typing && lines && onStats && credits && rolled && closed && fits)) Detail("ending", ("opened", opened), ("numbers", numbers), ("typing", typing), ("lines", lines), ("stats", onStats), ("credits", credits), ("rolled", rolled), ("closed", closed), ("fits", fits), ("page", ending.PageIndex), ("modal", route.Modal), ("values", String.Join("|", stats.Select(s => s.value))));
            check("completion_native_ending_epilogue_numbers_and_credits", lockedBefore && opened && numbers && typing && lines && onStats && credits && rolled && closed && fits);

            // --- What a finished round remembers ---
            var meta = Fixture.NgMeta; string revision = Fixture.Current.RevisionId;
            bool remembered = RouteWorldController.NgPlusAvailable(Fixture) && meta.Require("rounds").AsInt64() == 1 && meta.Require("weapon").AsString() == "iron"
                && meta.Require("hearts").AsInt64() == 2 && meta.Require("boots").AsBool() && meta.Require("gear_items").TryGet(gear, out _);
            bool quiet = route.RecordCompletion() && Fixture.Current.RevisionId == revision;
            route.Progression.SetWeapon("wood"); bool keepsBest = route.Save() && Fixture.NgMeta.Require("weapon").AsString() == "iron" && Fixture.NgMeta.Require("rounds").AsInt64() == 1;
            if (!(remembered && quiet && keepsBest)) Detail("memory", ("remembered", remembered), ("quiet", quiet), ("best", keepsBest), ("meta", FoundationJson.StringifyPlain(Fixture.NgMeta)));
            check("completion_native_finished_round_remembers_best_gear", remembered && quiet && keepsBest);

            // --- The way back to Godot: a folder of its own, never an existing one ---
            string folder = Path.Combine(output, "completion-godot-export");
            bool exported = Fixture.ExportForGodot(folder) && Fixture.LastExport.UnknownToGodot.Count == 0;
            string[] expected = { "LEESMIJ.txt", "meta.cfg", "ng_plus.cfg", "savegame.json" };
            bool files = exported && Directory.GetFiles(folder).Select(Path.GetFileName).OrderBy(n => n, StringComparer.Ordinal).SequenceEqual(expected);
            bool again = !Fixture.ExportForGodot(folder) && !Fixture.ExportForGodot(Path.Combine(PersistencePaths.LegacyDefault, "bluemap-probe-never-created"));
            bool reread = false, sameMeta = false, sameAchievements = false;
            if (files)
            {
                var source = LegacySourceSet.Read(folder); var converted = Fixture.Convert(source);
                var direct = importer.Import(LegacySaveExporter.Export(Fixture.Current.Snapshot.State).SaveJson).State.Snapshot();
                reread = FoundationJson.StringifyPlain(converted.State) == FoundationJson.StringifyPlain(direct) && converted.State.Require("map").AsString() == "village"
                    && converted.State.Require("coins").AsInt64() == 77 && converted.State.Require("flags").TryGet("game_completed", out _);
                var back = converted.Preferences.Require("ngMeta"); var mine = Fixture.NgMeta;
                sameMeta = back.Require("completed").AsBool() && back.Require("rounds").AsInt64() == 1 && back.Require("weapon").AsString() == "iron" && back.Require("hearts").AsInt64() == 2
                    && back.Require("boots").AsBool() && back.Require("gear_items").TryGet(gear, out _) && back.Require("hero_xp").AsInt64() == mine.Require("hero_xp").AsInt64();
                sameAchievements = state.Get("achievements").Items.All(id => converted.State.Require("achievements").Items.Any(v => v.AsString() == id.AsString()));
            }
            if (!(exported && files && again && reread && sameMeta && sameAchievements)) Detail("export", ("exported", exported), ("files", files), ("again", again), ("reread", reread), ("meta", sameMeta), ("achievements", sameAchievements), ("status", Fixture.Status));
            check("completion_native_export_folder_for_godot", exported && files && again && reread && sameMeta && sameAchievements);

            // --- New Game+: your best gear against stronger enemies ---
            bool reloaded = route.Reload(false); route.Tick(0); state = route.Gameplay.State;
            bool kept = reloaded && state.Flag("game_completed") && RouteWorldController.NgPlusAvailable(Fixture);
            check("completion_native_reload_keeps_completion", kept);
            string oldProfile = Fixture.Current.ProfileId;
            bool started = route.BeginNewGamePlus(Fixture); route.Tick(0); state = route.Gameplay.State; route.CombatSimulationEnabled = false; route.ResidentsSimulationEnabled = false;
            bool fresh = started && Fixture.Current.ProfileId != oldProfile && state.MapId == "village" && !state.Flag("game_completed") && !state.Get("flags").TryGet("op_new_adventure", out _);
            bool carried = state.Get("ng_plus").AsInt64() == 1 && state.Coins == 100 && state.Get("weapon").AsString() == "iron" && state.Count("heart_container") == 2 && state.Count("boots") == 1
                && state.Count(gear) == 1 && state.Hp == 7 && route.Gameplay.MaxHp == 7;
            bool stronger = route.Combat.NgHp(4) == 6 && route.Combat.NgHp(3) == 5 && route.Combat.NgCoins(2) == 3;
            bool stillOpen = RouteWorldController.NgPlusAvailable(Fixture) && Fixture.NgMeta.Require("rounds").AsInt64() == 1;
            yield return new WaitForEndOfFrame(); yield return new WaitForEndOfFrame(); Capture("new-game-plus");
            // Finishing this round counts it: the next one is round two.
            route.RequestEnding(); route.Tick(0); route.CloseModal(); bool second = Fixture.NgMeta.Require("rounds").AsInt64() == 2;
            if (!(fresh && carried && stronger && stillOpen && second)) Detail("ngplus", ("started", started), ("fresh", fresh), ("carried", carried), ("stronger", stronger), ("open", stillOpen), ("second", second), ("hp", state.Hp), ("coins", state.Coins), ("weapon", state.Get("weapon").AsString()), ("ng", state.Get("ng_plus").AsInt64()));
            check("completion_native_new_game_plus_best_gear_stronger_enemies", fresh && carried && stronger && stillOpen && second);
            check("completion_native_three_rendered_captures", captures == 3);
        }
    }
}
