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
using BlueMapMigration.Residents;
using BlueMapMigration.Route;
using BlueMapMigration.Story;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace BlueMapMigration.Atmosphere
{
    /// <summary>Native proof of the hour, weather, lamps, atlas, travel, achievements and settings on a fresh test profile.</summary>
    public static class AtmosphereProbeRunner
    {
        [Serializable]
        public sealed class Result
        {
            public int schemaVersion = 1;
            public BuildIdentity identity;
            public bool success;
            public bool gameSaveAccessed = false;
            public Phase2Probe.Check[] checks = Array.Empty<Phase2Probe.Check>();
        }

        public static Result Last { get; private set; }
        public static PersistenceCoordinator Fixture { get; private set; }

        public static IEnumerator Run(BuildIdentity identity, string output, PlayerWorld world,
            RouteWorldController route, Phase6Catalog catalog)
        {
            Last = new Result { identity = identity };
            var checks = new List<Phase2Probe.Check>();
            void Check(string name, bool passed)
            {
                if (checks.Any(row => row.name == name))
                    throw new InvalidOperationException("Duplicate atmosphere proof " + name);
                checks.Add(new Phase2Probe.Check { name = name, passed = passed });
                Last.checks = checks.ToArray();
                if (!passed) Debug.Log("Atmosphere native check failed: " + name);
            }

            var repository = FoundationWorldRepository.LoadRequired();
            string root = PersistencePaths.Checked(Path.Combine(output, "atmosphere-profiles"));
            if (Directory.Exists(root)) throw new IOException("Fresh atmosphere profile required");
            route.CloseModal();
            Fixture = new PersistenceCoordinator(repository, world.InputSource, root);
            if (!route.BeginNew(Fixture)) throw new IOException(Fixture.Status);
            route.CombatSimulationEnabled = false;
            route.ResidentsSimulationEnabled = false;
            bool plainBefore = !route.AtmosphereEnabled;
            route.AtmosphereEnabled = true;
            Check("atmosphere_native_shared_state_and_profile", Fixture.Current.Snapshot.CopyOriginals().Count == 0 && plainBefore
                && route.WorldMap != null && route.Records != null);

            var live = RunLiveEpisodes(output, repository, world, route, Check);
            while (live.MoveNext()) yield return live.Current;

            Check("atmosphere_no_personal_saves_used", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && PersistencePaths.Within(PersistencePaths.Checked(output), root)
                && !PersistencePaths.Within(PersistencePaths.UnityDefault, root)
                && !PersistencePaths.Within(PersistencePaths.LegacyDefault, root));
            route.CloseModal();
            route.AtmosphereEnabled = false;
            route.Save();
            Last.success = checks.Count > 5 && checks.All(row => row.passed);
            Last.checks = checks.ToArray();
            File.WriteAllText(Path.Combine(output, "atmosphere-result.json"), JsonUtility.ToJson(Last, true));
            Debug.Log("Atmosphere native proof: " + checks.Count + " checks");
        }

        static bool Near(Color a, Color b) => Mathf.Abs(a.r - b.r) < .01f && Mathf.Abs(a.g - b.g) < .01f && Mathf.Abs(a.b - b.b) < .01f;

        static IEnumerator RunLiveEpisodes(string output, FoundationWorldRepository repository,
            PlayerWorld world, RouteWorldController route, Action<string, bool> check)
        {
            var state = route.Gameplay.State;
            bool Travel(string map)
            {
                route.CloseModal();
                var source = repository.Read(map);
                string spawn = source.Arrivals.FirstOrDefault(row => row.Name == "start")?.Name ?? source.Arrivals[0].Name;
                if (!route.TryTravel(map, spawn)) { Debug.Log("Atmosphere detail travel failed: " + map); return false; }
                state = route.Gameplay.State; route.Combat.ResetTransient(); route.Tick(0); return true;
            }
            void Stand(Vector2 position)
            { world.Teleport(position); world.Step(0, new MotionInput()); world.FocusCameraOnPlayer(); route.Tick(0); }
            void Detail(string name, params (string key, object value)[] parts)
                => Debug.Log("Atmosphere detail " + name + ": " + String.Join(" ", parts.Select(part => part.key + "=" + part.value)));
            int captures = 0;
            void Capture(string name)
            {
                string path = Path.Combine(output, "screenshot-atmosphere-" + name + ".png");
                if (File.Exists(path)) throw new IOException("Fresh atmosphere capture required");
                var image = ScreenCapture.CaptureScreenshotAsTexture();
                try
                {
                    if (image.width != 1152 || image.height != 648) throw new InvalidOperationException("Atmosphere viewport differs");
                    File.WriteAllBytes(path, image.EncodeToPNG()); captures++;
                }
                finally { UnityEngine.Object.Destroy(image); }
            }
            // Mean brightness of a block of the rendered picture, away from the HUD panels.
            float Brightness(int x0, int y0, int w, int h)
            {
                var image = ScreenCapture.CaptureScreenshotAsTexture();
                try { var pixels = image.GetPixels(x0, y0, w, h); return pixels.Average(p => (p.r + p.g + p.b) / 3f); }
                finally { UnityEngine.Object.Destroy(image); }
            }
            void Hour(double time) { state.DayTime = time; route.Tick(0); }

            // --- The colour of the hour follows the source table ---
            Travel("village"); Hour(.3);
            bool ready = route.AtmosphereReady && route.GlowCount >= 1;
            bool noon = Near(route.SkyTint, Color.white) && route.LightNeed == 0 && route.ClockText == route.Translate("Dag");
            Hour(.8); bool night = Near(route.SkyTint, new Color(.30f, .36f, .66f)) && route.LightNeed == 1 && route.ClockText == route.Translate("Nacht");
            Hour(0); bool dawn = Near(route.SkyTint, new Color(1f, .82f, .72f)) && Math.Abs(route.LightNeed - .35) < 1e-9 && route.ClockText == route.Translate("Ochtend");
            Hour(.64); bool dusk = route.LightNeed > .15 && route.LightNeed < .6 && route.ClockText == route.Translate("Avond") && route.SkyTint.r < 1;
            bool table = Near(RouteWorldController.TintAt(.17), Color.white) && RouteWorldController.NightAt(.76) == 1 && RouteWorldController.NightAt(.3) == 0
                && RouteWorldController.AmbienceFor("snow", .8) == "amb_sneeuw_nacht" && RouteWorldController.AmbienceFor("", .3) == "amb_bos_dag";
            if (!(ready && noon && night && dawn && dusk && table)) Detail("hour", ("ready", ready), ("noon", noon), ("night", night), ("dawn", dawn), ("dusk", dusk), ("table", table), ("tint", route.SkyTint), ("need", route.LightNeed), ("clock", route.ClockText));
            check("atmosphere_native_hour_colours_follow_source", ready && noon && night && dawn && dusk && table);

            // --- Night is really darker on screen, and a lamp really adds light ---
            Stand(new Vector2(10.5f, 30.5f) * 32); Hour(.3); yield return new WaitForEndOfFrame(); yield return new WaitForEndOfFrame();
            float day = Brightness(380, 200, 360, 240);
            Hour(.8); yield return new WaitForEndOfFrame(); yield return new WaitForEndOfFrame();
            float dark = Brightness(380, 200, 360, 240), far = Brightness(40, 180, 120, 120), own = Brightness(516, 264, 120, 120);
            Capture("night");
            bool darker = dark < day * .8f && dark > day * .15f, lamp = own > far * 1.02f;
            if (!(darker && lamp)) Detail("screen", ("day", day), ("night", dark), ("far", far), ("own", own));
            check("atmosphere_native_night_is_darker_and_lamps_glow", darker && lamp);

            // --- Caves are dark whatever the hour; shops are plain ---
            bool cave = Travel("cave") && Near(route.SkyTint, Color.Lerp(Color.white, new Color(.1f, .12f, .24f), .78f)) && route.LightNeed == 1 && route.ClockText == "" && route.AmbienceKey == "";
            bool shop = Travel("shop") && Near(route.SkyTint, Color.white) && route.LightNeed == 0 && route.AmbienceKey == "";
            if (!(cave && shop)) Detail("indoors", ("cave", cave), ("shop", shop), ("tint", route.SkyTint), ("amb", route.AmbienceKey));
            check("atmosphere_native_caves_dark_and_interiors_plain", cave && shop);

            // --- Weather belongs to the map: snow, drifting sand and passing rain ---
            Hour(.3);
            bool snow = Travel("ijsdal") && route.SnowLevel == 1 && route.RainLevel == 0; route.Tick(.1); snow &= route.WeatherMotes == 70 && route.AmbienceKey == "amb_sneeuw_dag";
            bool sand = Travel("dorstvallei") && route.DustLevel == 1; route.Tick(.1); sand &= route.WeatherMotes == 45 && route.AmbienceKey == "amb_dorst_dag";
            Travel("village"); long wet = -1;
            for (long dayCount = 1; dayCount < 40 && wet < 0; dayCount++) if (ResidentSocialModel.Raining("random", dayCount, .3)) wet = dayCount;
            state.DayCount = 0; Hour(.05); route.Tick(5); bool dryStart = route.RainLevel == 0;
            state.DayCount = Math.Max(1, wet); Hour(.3); route.Tick(2); bool rising = route.RainLevel > .4 && route.RainLevel < .6; route.Tick(3);
            bool rain = wet > 0 && dryStart && rising && route.RainLevel == 1 && route.WeatherMotes == 90 && route.SkyTint.r < .81f;
            if (!(snow && sand && rain)) Detail("weather", ("snow", snow), ("sand", sand), ("rain", rain), ("wetDay", wet), ("level", route.RainLevel), ("motes", route.WeatherMotes), ("amb", route.AmbienceKey));
            check("atmosphere_native_weather_follows_map_and_clock", snow && sand && rain);
            state.DayCount = 0;

            // --- The background sound follows climate and hour ---
            Hour(.3); bool amDay = route.AmbienceKey == "amb_bos_dag"; Hour(.8); bool amNight = route.AmbienceKey == "amb_bos_nacht";
            Hour(.6); bool amEve = route.AmbienceKey == "amb_bos_avond"; Hour(.1); bool amMorning = route.AmbienceKey == "amb_bos_ochtend";
            check("atmosphere_native_ambience_follows_climate_and_hour", amDay && amNight && amEve && amMorning);
            Hour(.3);

            // --- The atlas: nineteen regions, only visited names, the next passage ---
            bool opened = route.OpenWorldMap() && route.Modal == "world_map" && route.WorldMap.LayoutFits && route.WorldMap.RegionId == "village";
            var map = route.WorldMap;
            bool here = map.RegionState("village") == 2 && map.RegionTitle("village") == route.Translate(repository.Read("village").MapData.Require("name").AsString());
            bool hidden = map.RegionState("steampeak") == 0 && map.RegionTitle("steampeak") == route.Translate("Onbekend gebied") && !map.InfoText.Contains("steampeak");
            bool visited = map.RegionState("ijsdal") == 1 && map.RegionState("dorstvallei") == 1 && map.RegionState("forest") == 1 && map.PlaceTitle("cave") != route.Translate("Onbekende plek") && map.VisitedCount >= 5;
            map.MoveRegion(Vector2.right); bool stepped = map.RegionId == "forest_edge"; map.MoveRegion(Vector2.left); stepped &= map.RegionId == "village";
            map.MoveRegion(Vector2.right); map.MoveRegion(Vector2.right);
            yield return new WaitForEndOfFrame(); bool drawn = map.Draws > 0 && map.InfoFits && WorldMapPanel.Regions.Length == 19; Capture("atlas");
            if (!(opened && here && hidden && visited && stepped && drawn)) Detail("atlas", ("opened", opened), ("here", here), ("hidden", hidden), ("visited", visited), ("stepped", stepped), ("drawn", drawn), ("region", map.RegionId), ("count", map.VisitedCount));
            check("atmosphere_native_atlas_regions_names_and_steps", opened && here && hidden && visited && stepped && drawn);
            route.CloseModal();

            // --- Travel between discovered altars ---
            foreach (var row in state.Get("flags").Entries.ToArray()) if (row.Key.AsString().StartsWith("altaar_", StringComparison.Ordinal)) state.SetFlag(row.Key.AsString(), false);
            route.Tick(0);
            bool none = route.DiscoveredAltars().Count == 0 && route.TravelBlockedReason() != "";
            Travel("forest"); var altar = route.Targets.FirstOrDefault(t => t.Kind == "savepoint");
            string forestKey = altar == null ? "" : "altaar_forest_" + (int)(altar.Position.x / 32) + "_" + (int)(altar.Position.y / 32);
            bool found = altar != null; if (found) { Stand(altar.Position + new Vector2(0, 30)); found = route.InteractTarget(altar.Address) && state.Flag(forestKey); }
            route.CloseModal(); Travel("village"); var homeAltar = route.Targets.FirstOrDefault(t => t.Kind == "savepoint");
            if (homeAltar != null) { Stand(homeAltar.Position + new Vector2(0, 30)); route.InteractTarget(homeAltar.Address); route.CloseModal(); }
            var points = route.DiscoveredAltars(); var target = points.FirstOrDefault(p => p.Key == forestKey);
            bool listed = points.Count == 2 && target != null && route.TravelBlockedReason() == "";
            bool tabs = route.OpenWorldMap("travel") && route.WorldMap.Tab == "travel";
            route.WorldMap.MoveTravel(points.ToList().IndexOf(target));
            bool travelled = route.WorldMap.ActivateTravel() && state.MapId == "forest" && route.Modal == "" && state.Flag("wereld_snel_gereisd") && altar != null && Vector2.Distance(world.Position, altar.Position) < 96;
            bool unknown = !route.TravelToAltar(new TravelPoint { Map = "ijsdal", Key = "altaar_ijsdal_1_1", Name = "x", Spawn = "", Tile = new Vector2(1, 1) }) && state.MapId == "forest";
            if (!(none && found && listed && tabs && travelled && unknown)) Detail("travel", ("none", none), ("found", found), ("listed", listed), ("count", points.Count), ("tabs", tabs), ("travelled", travelled), ("unknown", unknown), ("map", state.MapId), ("key", forestKey));
            check("atmosphere_native_fast_travel_between_altars", none && found && listed && tabs && travelled && unknown);

            // --- Achievements unlock from their original conditions and are announced once ---
            route.CloseModal(); state.Set("achievements", FoundationValue.Array(new FoundationValue[0])); state.Set("kills", FoundationValue.Integer(0)); route.Tick(0);
            int before = route.AchievementsOwned; int idle = route.CheckAchievements();
            state.Set("kills", FoundationValue.Integer(1));
            bool unlocked = route.CheckAchievements() >= 1 && route.AchievementOwned("first_blood") && route.CheckAchievements() == 0 && route.AchievementsOwned > before;
            route.Tick(.1); bool announced = route.AchievementBanner != "" && route.AchievementBannerTime > 0;
            yield return new WaitForEndOfFrame(); bool bannerDrawn = route.Hud.LastAchievementBounds.width > 0;
            var rows = route.Records.Achievements();
            bool listedAll = RouteWorldController.AchievementCatalog.Items.Count == 40 && rows.Count == 40 && rows.Any(r => r.Id == "first_blood" && r.Known && r.Mark != "")
                && RouteWorldController.AchievementCatalog.Items.Where(r => r.Require("secret").AsBool() && !route.AchievementOwned(r.Require("id").AsString())).All(r => rows.First(x => x.Id == r.Require("id").AsString()).Title == "???");
            route.Tick(5); bool faded = route.AchievementBanner == "" || route.AchievementBannerTime > 0;
            if (!(unlocked && announced && bannerDrawn && listedAll && faded)) Detail("achievements", ("idle", idle), ("unlocked", unlocked), ("announced", announced), ("drawn", bannerDrawn), ("listed", listedAll), ("owned", route.AchievementsOwned));
            check("atmosphere_native_achievements_unlock_and_announce", unlocked && announced && bannerDrawn && listedAll && faded);

            // --- The bestiary shows what you have defeated and hides the rest ---
            state.Set("kills_by", InventoryModel.Replace(InventoryModel.Empty(), "slime", FoundationValue.Integer(3)));
            bool book = route.OpenRecords("bestiary") && route.Modal == "records" && route.Records.Tab == "bestiary" && route.Records.LayoutFits;
            var beasts = route.Records.Beasts();
            bool known = beasts.Count == route.Encounter.EnemyKinds.Count && beasts.Count > 20 && beasts.Count(r => r.Known) == 1 && beasts.First(r => r.Id == "slime").Mark == "x3" && beasts.Where(r => !r.Known).All(r => r.Title == "???");
            for (int i = 0; i < 14; i++) route.Records.Move(1);
            yield return new WaitForEndOfFrame(); bool scrolled = route.Records.Selected == 14 && route.Records.SelectionVisible && route.Records.DetailFits && route.Records.Draws > 0; Capture("bestiary");
            route.Records.SetTab("achievements"); bool switched = route.Records.Rows.Count == 40;
            if (!(book && known && scrolled && switched)) Detail("bestiary", ("book", book), ("known", known), ("count", beasts.Count), ("scrolled", scrolled), ("switched", switched));
            check("atmosphere_native_bestiary_known_and_hidden", book && known && scrolled && switched);
            route.CloseModal();

            // --- Language, volume and mute can be changed while playing ---
            var original = route.Persistence.Preferences; string dutch = route.Translate("Wereldkaart");
            if (original.Locale != "nl") route.ToggleLanguage();
            bool english = route.ToggleLanguage() && route.Locale == "en" && route.Translate("Wereldkaart") != dutch && route.SettingsLine(0).Contains("English");
            bool back = route.ToggleLanguage() && route.Locale == "nl" && route.Translate("Wereldkaart") == dutch;
            double music = route.Persistence.Preferences.MusicVolume; bool stepped2 = route.StepVolume(true) && Math.Abs(route.Persistence.Preferences.MusicVolume - (music >= 1 ? 0 : music + .1)) < 1e-9;
            bool muted = route.ToggleMute() && route.Persistence.Preferences.Muted != original.Muted && route.ToggleMute() && route.Persistence.Preferences.Muted == original.Muted;
            route.OpenPause(); route.ActivatePause(5); bool viaPause = route.Locale == "en"; route.ActivatePause(5); viaPause &= route.Locale == "nl"; route.CloseModal();
            route.Persistence.SetPreferences(original); world.SetPersistencePreferences(route.Persistence.Preferences, true);
            if (!(english && back && stepped2 && muted && viaPause)) Detail("settings", ("english", english), ("back", back), ("volume", stepped2), ("muted", muted), ("pause", viaPause));
            check("atmosphere_native_language_volume_and_mute", english && back && stepped2 && muted && viaPause);

            var input = VerifyKeys(route, check);
            while (input.MoveNext()) yield return input.Current;

            // --- A reload keeps achievements and discoveries ---
            bool reloaded = route.Save() && route.Reload(false); route.Tick(0); state = route.Gameplay.State;
            bool kept = reloaded && state.Get("achievements").Kind == "array" && route.AchievementOwned("first_blood") && state.Flag(forestKey) && state.Flag("wereld_snel_gereisd") && route.DiscoveredAltars().Count == 2;
            check("atmosphere_native_reload_keeps_records", kept);
            check("atmosphere_native_three_rendered_captures", captures == 3);
        }

        static IEnumerator VerifyKeys(RouteWorldController route, Action<string, bool> check)
        {
            var previousMode = InputSystem.settings.updateMode;
            var devices = new List<InputDevice>(); PlayerInputSource input = null;
            try
            {
                InputSystem.settings.updateMode = InputSettings.UpdateMode.ProcessEventsManually;
                var keyboard = InputSystem.AddDevice<Keyboard>("Atlas keyboard");
                var mouse = InputSystem.AddDevice<Mouse>("Atlas mouse");
                var pad = InputSystem.AddDevice<Gamepad>("Atlas controller");
                devices.AddRange(new InputDevice[] { keyboard, mouse, pad }); input = new PlayerInputSource(devices);
                InputFrame Sample(KeyboardState keys)
                {
                    InputSystem.QueueStateEvent(keyboard, keys); InputSystem.QueueStateEvent(mouse, new MouseState { position = new Vector2(40, 40) });
                    InputSystem.QueueStateEvent(pad, new GamepadState()); InputSystem.Update(); input.SetContext(true, route.Gameplay.State.InputLocked);
                    var frame = input.Read(); route.Tick(0); route.HandleFrame(frame); return frame;
                }
                InputFrame KeyPress(Key key) { Sample(new KeyboardState()); var frame = Sample(new KeyboardState(key)); Sample(new KeyboardState()); return frame; }
                yield return new WaitForEndOfFrame();
                route.CloseModal();
                bool map = KeyPress(Key.N).Pressed("map") && route.Modal == "world_map" && route.WorldMap.Tab == "map";
                string from = route.WorldMap.RegionId; KeyPress(Key.RightArrow); bool moved = route.WorldMap.RegionId != from;
                KeyPress(Key.PageDown); bool tab = route.WorldMap.Tab == "travel"; KeyPress(Key.Escape); bool closed = route.Modal == "";
                bool trophies = KeyPress(Key.T).Pressed("wereld_prestaties") && route.Modal == "records" && route.Records.Tab == "achievements";
                KeyPress(Key.DownArrow); bool down = route.Records.Selected == 1; KeyPress(Key.PageDown); bool beasts = route.Records.Tab == "bestiary"; KeyPress(Key.Escape);
                bool book = KeyPress(Key.B).Pressed("wereld_beestenboek") && route.Modal == "records" && route.Records.Tab == "bestiary"; KeyPress(Key.Escape);
                bool muteBefore = route.Persistence.Preferences.Muted; KeyPress(Key.M); bool muteKey = route.Persistence.Preferences.Muted != muteBefore; KeyPress(Key.M);
                bool all = map && moved && tab && closed && trophies && down && beasts && book && muteKey && route.Modal == "";
                if (!all) Debug.Log("Atmosphere detail keys: map=" + map + " moved=" + moved + " tab=" + tab + " closed=" + closed + " trophies=" + trophies + " down=" + down + " beasts=" + beasts + " book=" + book + " mute=" + muteKey + " modal=" + route.Modal);
                check("atmosphere_native_keys_open_map_and_books", all);
            }
            finally
            {
                input?.Dispose();
                foreach (var device in devices) if (device.added) InputSystem.RemoveDevice(device);
                InputSystem.settings.updateMode = previousMode;
            }
            route.CloseModal(); route.Tick(0);
        }
    }
}
