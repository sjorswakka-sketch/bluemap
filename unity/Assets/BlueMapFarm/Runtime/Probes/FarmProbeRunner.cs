using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Home;
using BlueMapMigration.Inventory;
using BlueMapMigration.Persistence;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Probe;
using BlueMapMigration.Route;
using BlueMapMigration.Story;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace BlueMapMigration.Farm
{
    /// <summary>Native garden, production and water proof uses a fresh test profile and the real route controller.</summary>
    public static class FarmProbeRunner
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
                    throw new InvalidOperationException("Duplicate farm proof " + name);
                checks.Add(new Phase2Probe.Check { name = name, passed = passed });
                Last.checks = checks.ToArray();
                if (!passed) Debug.Log("Farm native check failed: " + name);
            }

            var repository = FoundationWorldRepository.LoadRequired();
            FarmModelChecks.Verify(repository, Check);
            string root = PersistencePaths.Checked(Path.Combine(output, "farm-profiles"));
            if (Directory.Exists(root)) throw new IOException("Fresh farm profile required");
            route.CloseModal();
            Fixture = new PersistenceCoordinator(repository, world.InputSource, root);
            if (!route.BeginNew(Fixture)) throw new IOException(Fixture.Status);
            route.CombatSimulationEnabled = false;
            route.ResidentsSimulationEnabled = false;
            Check("farm_native_shared_state_and_profile", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && ReferenceEquals(route.Farm.State, route.Gameplay.State)
                && ReferenceEquals(route.Farm.Inventory, route.Inventory)
                && ReferenceEquals(route.Farm.Home, route.Home)
                && ReferenceEquals(route.Farm.Professions, route.Professions));

            var live = RunLiveEpisodes(output, repository, world, route, Check);
            while (live.MoveNext()) yield return live.Current;

            Check("farm_no_personal_saves_used", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && PersistencePaths.Within(PersistencePaths.Checked(output), root)
                && !PersistencePaths.Within(PersistencePaths.UnityDefault, root)
                && !PersistencePaths.Within(PersistencePaths.LegacyDefault, root));
            route.CloseModal();
            route.Save();
            Last.success = checks.Count > 5 && checks.All(row => row.passed);
            Last.checks = checks.ToArray();
            File.WriteAllText(Path.Combine(output, "farm-result.json"), JsonUtility.ToJson(Last, true));
            Debug.Log("Farm native proof: " + checks.Count + " checks");
        }

        static IEnumerator Resolution(int width, int height)
        {
            Screen.SetResolution(width, height, FullScreenMode.Windowed);
            for (int frame = 0; frame < 30; frame++)
            { yield return null; if (Screen.width == width && Screen.height == height) yield break; }
            throw new InvalidOperationException("Farm viewport resize did not apply");
        }

        /// <summary>A bag with the given counts set; used to prepare synthetic test profiles only.</summary>
        static FoundationValue With(FoundationValue inventory, params (string item, long count)[] items)
        { foreach (var row in items) inventory = InventoryModel.Replace(inventory, row.item, FoundationValue.Integer(row.count), row.count <= 0); return inventory; }

        /// <summary>The same saved content, regardless of key order or of whole numbers stored as int or float.</summary>
        static bool Same(FoundationValue a, FoundationValue b)
        {
            bool Table(FoundationValue v) => v.Kind == "object" || v.Kind == "dictionary";
            bool Numeric(FoundationValue v) => v.Kind == "int" || v.Kind == "float";
            if (Table(a) || Table(b))
                return Table(a) && Table(b) && a.Entries.Count == b.Entries.Count
                    && a.Entries.All(row => b.TryGet(row.Key.AsString(), out var other) && Same(row.Value, other));
            if (a.Kind == "array" || b.Kind == "array")
                return a.Kind == b.Kind && a.Items.Count == b.Items.Count && a.Items.Zip(b.Items, Same).All(same => same);
            if (Numeric(a) || Numeric(b)) return Numeric(a) && Numeric(b) && a.AsDouble() == b.AsDouble();
            return a.Kind == b.Kind && a.CanonicalJson == b.CanonicalJson;
        }

        static IEnumerator RunLiveEpisodes(string output, FoundationWorldRepository repository,
            PlayerWorld world, RouteWorldController route, Action<string, bool> check)
        {
            var state = route.Gameplay.State;
            FarmModel Model() => route.Farm;
            void Travel(string map)
            {
                route.CloseModal();
                var source = repository.Read(map);
                string spawn = source.Arrivals.FirstOrDefault(row => row.Name == "start")?.Name ?? source.Arrivals[0].Name;
                if (!route.TryTravel(map, spawn)) throw new InvalidOperationException("Farm travel failed: " + map);
                state = route.Gameplay.State; route.Combat.ResetTransient(); route.Tick(0);
            }
            void Stand(Vector2 position)
            { world.Teleport(position); world.Step(0, new MotionInput()); world.FocusCameraOnPlayer(); route.Tick(0); }
            RouteTarget Station(string role, string unit = "")
                => route.Targets.First(target => target.Kind == "home_station" && target.Id == role
                    && (unit == "" || (target.Fields.Require("obj").TryGet("unit", out var value) && value.AsString() == unit)));
            bool Reach(RouteTarget target)
            { route.CloseModal(); Stand(target.Position + new Vector2(0, 34)); return route.InteractTarget(target.Address); }
            void Detail(string name, params (string key, object value)[] parts)
                => Debug.Log("Farm detail " + name + ": " + String.Join(" ", parts.Select(part => part.key + "=" + part.value)));
            int captures = 0;
            void Capture(string name)
            {
                string path = Path.Combine(output, "screenshot-farm-" + name + ".png");
                if (File.Exists(path)) throw new IOException("Fresh farm capture required");
                var image = ScreenCapture.CaptureScreenshotAsTexture();
                try
                {
                    if (image.width != 1152 || image.height != 648) throw new InvalidOperationException("Farm viewport differs");
                    File.WriteAllBytes(path, image.EncodeToPNG()); captures++;
                }
                finally { UnityEngine.Object.Destroy(image); }
            }
            Vector2 Center(HomeCell cell) => new Vector2(cell.X * 32 + 16, cell.Y * 32 + 16);
            // Stand on the tile above the target and face it, exactly as a player would.
            int Work(HomeCell cell, string mode)
            {
                if (Model().Mode != mode) route.ChooseGardenMode(mode);
                Stand(Center(cell.Offset(0, -1))); world.Motor.Facing = new Vector2(0, 1); route.Tick(.35);
                return route.GardenAimCell().Equals(cell) ? route.WorkGarden() : -1;
            }
            void Pass(double seconds)
            { state.Events.Publish(new FoundationActiveTimeAdvanced(seconds)); route.Tick(0); }
            string Crop(HomeCell cell) => Model().EntryAt(cell).TryGet("crop", out var crop) ? crop.AsString() : "";
            double Growth(HomeCell cell) => Model().EntryAt(cell).TryGet("growth", out var growth) ? growth.AsDouble() : -1;

            // --- The garden guide: free supplies and the seed book ---
            Travel("village");
            var guide = Station("guide");
            bool guideMenu = Reach(guide) && route.Modal == "garden_menu" && route.GardenMenu.IsOpen && route.GardenMenu.Role == "guide"
                && route.GardenMenu.OptionIds.SequenceEqual(new[] { "supply", "tools", "harvest", "help", "seeds", "yard", "close" })
                && route.GardenMenu.LayoutFits && route.GardenMenu.Enabled("supply");
            bool supplied = route.GardenMenu.Choose("supply") && state.Count("hs_hoe") == 1 && state.Count("hs_seed") == 8
                && state.Count("hs_flower_seed") == 4 && state.Flag("hs_supplies") && !route.GardenMenu.Enabled("supply");
            bool book = route.GardenMenu.Choose("seeds") && route.Modal == "seed_book" && route.SeedBook.IsOpen && route.SeedBook.LayoutFits;
            yield return new WaitForEndOfFrame();
            bool stages = route.SeedBook.StagesDrawn == 4 && route.SeedBook.DescriptionFits;
            route.SeedBook.SelectCrop(SeedBookPanel.StarterIndex);
            bool starter = route.SeedBook.Activate() && state.Flag("or_starter") && state.Count("or_apple_seed") == 1 && state.Count("or_carrot_seed") == 2;
            state.Set("coins", FoundationValue.Integer(60));
            route.SeedBook.SelectCrop(route.SeedBook.CropIds.ToList().IndexOf("apple"));
            yield return new WaitForEndOfFrame();
            bool appleStages = route.SeedBook.StagesDrawn == 4;
            bool bought = route.SeedBook.SelectAction("buy1") && route.SeedBook.Activate() && state.Count("or_apple_seed") == 2 && state.Coins == 44
                && !route.SeedBook.SelectAction("buy5");
            route.SeedBook.SelectCrop(route.SeedBook.CropIds.ToList().IndexOf("grape"));
            yield return new WaitForEndOfFrame(); Capture("seed-book");
            bool plantMode = route.SeedBook.SelectAction("plant") && route.SeedBook.Activate() && route.Modal == "" && Model().Mode == "grape";
            if (!(guideMenu && supplied && book && stages && starter && appleStages && bought && plantMode))
                Detail("guide", ("menu", guideMenu), ("supplied", supplied), ("book", book), ("stages", stages), ("starter", starter), ("apple", appleStages), ("bought", bought), ("plant", plantMode), ("options", String.Join(",", route.GardenMenu.OptionIds)), ("coins", state.Coins), ("drawn", route.SeedBook.StagesDrawn));
            check("farm_native_guide_supplies_and_seed_book", guideMenu && supplied && book && stages && starter && appleStages && bought && plantMode);

            // --- Dig a channel from the brook, till, plant and read the field text ---
            HomeCell ditchA = new HomeCell(22, 34), ditchB = new HomeCell(23, 34), bed = new HomeCell(24, 34);
            bool dug = Work(ditchA, "channel") == 1 && Work(ditchB, "channel") == 1 && Model().IsWet(ditchA) && Model().IsWet(ditchB);
            bool tilled = Work(bed, "soil") == 1 && Model().Watered(bed);
            bool sown = Work(bed, "grape") == 1 && Crop(bed) == "grape" && state.Count("hs_seed") == 7 && Work(bed, "grape") == 0;
            route.Tick(0);
            bool drawn = route.GardenChannelNodes == 2 && route.GardenWetChannels == 2 && route.GardenSoilNodes == 1 && route.GardenCropNodes == 1;
            bool hint = route.GardenHint.Contains(Model().ModeName("grape")) && route.GardenHint.Contains(Model().CellText(bed).Split('\n')[0]) && route.GardenPreviewVisible;
            yield return new WaitForEndOfFrame();
            bool hintDrawn = route.Hud.LastGardenHintBounds.width > 0 && route.Hud.GardenHintFits && StoryUi.Contains(new Rect(0, 0, 1152, 648), route.Hud.LastGardenHintBounds);
            if (!(dug && tilled && sown && drawn && hint && hintDrawn))
                Detail("work", ("dug", dug), ("tilled", tilled), ("sown", sown), ("drawn", drawn), ("hint", hint), ("hintDrawn", hintDrawn), ("channels", route.GardenChannelNodes), ("wet", route.GardenWetChannels), ("soil", route.GardenSoilNodes), ("crops", route.GardenCropNodes), ("text", route.GardenHint.Replace("\n", " | ")), ("aim", route.GardenAimCell().Key), ("reason", Model().WorkReason(bed, "soil")));
            check("farm_native_channel_soil_and_planting", dug && tilled && sown && drawn && hint && hintDrawn);

            // --- Growth follows active play time and nothing else ---
            long version = route.GardenWorldVersion;
            state.PlayTime += 5000; route.Tick(0); route.Tick(5);
            bool waited = Growth(bed) == 0;
            Pass(45); bool half = Growth(bed) == 45 && Work(bed, "harvest") == 0;
            Pass(45); bool ripe = Growth(bed) == 90 && route.GardenWorldVersion > version;
            long foraging = route.Professions.Xp("foraging");
            bool harvested = Work(bed, "harvest") == 1 && state.Count("hs_grape") == 3 && Growth(bed) == 0 && Crop(bed) == "grape"
                && state.Flag("hs_intro_harvest") && route.Professions.Xp("foraging") == foraging + 4;
            if (!(waited && half && ripe && harvested))
                Detail("growth", ("waited", waited), ("half", half), ("ripe", ripe), ("harvested", harvested), ("growth", Growth(bed)), ("grapes", state.Count("hs_grape")), ("pending", route.PendingFarmTime));
            check("farm_native_growth_on_active_time_and_harvest", waited && half && ripe && harvested);

            // --- An apple tree keeps its crown free and stands in the way ---
            HomeCell trunk = new HomeCell(29, 34);
            bool treeSoil = Work(trunk, "soil") == 1;
            bool planted = Work(trunk, "apple") == 1 && Model().AppleTrees().Count == 1;
            route.Tick(0);
            bool tree = route.GardenTreeNodes == 1 && !world.CombatBodyFits(Center(trunk) + new Vector2(0, 9), 3)
                && Model().WorkReason(trunk.Offset(1, 0), "soil").Length > 0 && Work(trunk.Offset(0, 1), "soil") == 0;
            if (!(treeSoil && planted && tree))
                Detail("tree", ("soil", treeSoil), ("planted", planted), ("tree", tree), ("nodes", route.GardenTreeNodes), ("reason", Model().WorkReason(trunk, "apple")), ("seeds", state.Count("or_apple_seed")));
            check("farm_native_apple_tree_crown_and_trunk", treeSoil && planted && tree);
            Stand(Center(new HomeCell(25, 36))); world.Motor.Facing = new Vector2(0, -1); route.Tick(0);
            yield return new WaitForEndOfFrame(); Capture("garden");

            var input = VerifyInput(output, world, route, check);
            while (input.MoveNext()) yield return input.Current;

            // --- Compost, wine and honey run on the same active time ---
            state.Set("inventory", With(state.Get("inventory"), ("hs_manure", 4), ("hs_grape", 6)));
            var heap = Station("compost"); var barrel = Station("wine", "wine_a"); var hive = Station("hive");
            bool heapMenu = Reach(heap) && route.Modal == "garden_menu" && route.GardenMenu.Role == "compost"
                && route.GardenMenu.OptionIds.SequenceEqual(new[] { "start:1", "start:2", "close" }) && route.GardenMenu.LayoutFits;
            yield return new WaitForEndOfFrame(); Capture("station");
            bool mixing = route.GardenMenu.Choose("start:2") && state.Count("hs_manure") == 0 && Model().Job("compost") != null
                && route.GardenMenu.OptionIds.SequenceEqual(new[] { "collect", "close" }) && !route.GardenMenu.Enabled("collect");
            route.CloseModal(); Pass(29.5);
            bool early = Reach(heap) && !route.GardenMenu.Enabled("collect");
            route.CloseModal(); Pass(.5);
            long cooking = route.Professions.Xp("cooking");
            bool compost = Reach(heap) && route.GardenMenu.Choose("collect") && state.Count("hs_fertilizer") == 6 && Model().Job("compost") == null
                && route.Professions.Xp("cooking") == cooking + 6;
            bool wineStart = Reach(barrel) && route.GardenMenu.Role == "wine" && route.GardenMenu.Choose("start:1") && state.Count("hs_grape") == 3 && Model().Job("wine_a") != null;
            route.CloseModal(); Pass(90);
            bool wine = Reach(barrel) && route.GardenMenu.Choose("collect") && state.Count("hs_wine") == 1 && Model().Job("wine_a") == null;
            route.CloseModal(); Pass(240);
            long honey = Model().Honey;
            bool hiveMenu = Reach(hive) && route.GardenMenu.Role == "hive" && Model().Flowers() >= 3 && honey >= 2;
            bool honeyOut = route.GardenMenu.Choose("collect") && state.Count("hs_honey") == honey && Model().Honey == 0;
            if (!(heapMenu && mixing && early && compost && wineStart && wine && hiveMenu && honeyOut))
                Detail("production", ("heap", heapMenu), ("mixing", mixing), ("early", early), ("compost", compost), ("wineStart", wineStart), ("wine", wine), ("hive", hiveMenu), ("honey", honeyOut), ("options", String.Join(",", route.GardenMenu.OptionIds)), ("flowers", Model().Flowers()), ("stock", honey), ("modal", route.Modal));
            check("farm_native_compost_wine_and_honey", heapMenu && mixing && early && compost && wineStart && wine && hiveMenu && honeyOut);

            // --- Fertilize, harvest everything at the guide and switch the garden help ---
            bool fed = Work(bed, "fertilize") == 1 && state.Count("hs_fertilizer") == 5 && Work(bed, "fertilize") == 0;
            route.ChooseGardenMode(""); route.Tick(0);
            bool stowed = Model().Mode == "" && route.GardenHint == "";
            Pass(400);
            long grapesBefore = state.Count("hs_grape");
            bool all = Reach(guide) && route.GardenMenu.Choose("harvest") && state.Count("hs_grape") == grapesBefore + 5 && Growth(bed) == 0;
            bool help = route.GardenMenu.Choose("help") && state.Flag("hs_garden_help");
            route.CloseModal(); Stand(Center(bed.Offset(0, -1))); route.Tick(0);
            bool helpShown = route.GardenHint.Contains(Model().GuideText());
            bool helpOff = Reach(guide) && route.GardenMenu.Choose("help") && !state.Flag("hs_garden_help");
            if (!(fed && stowed && all && help && helpShown && helpOff))
                Detail("guide-harvest", ("fed", fed), ("stowed", stowed), ("all", all), ("help", help), ("shown", helpShown), ("off", helpOff), ("grapes", state.Count("hs_grape")), ("before", grapesBefore), ("hint", route.GardenHint.Replace("\n", " | ")));
            check("farm_native_fertilize_harvest_all_and_help", fed && stowed && all && help && helpShown && helpOff);

            // --- A profile reload keeps the whole garden ---
            FoundationValue before = Model().FarmView;
            bool reloaded = route.Save() && route.Reload(false); route.Tick(0); state = route.Gameplay.State;
            if (state.MapId != "village") Travel("village");
            route.Tick(0);
            bool kept = reloaded && Same(Model().FarmView, before);
            bool redrawn = route.GardenChannelNodes == 2 && route.GardenWetChannels == 2 && route.GardenTreeNodes == 1 && route.GardenSoilNodes >= 2;
            if (!(kept && redrawn)) Detail("reload", ("reloaded", reloaded), ("kept", kept), ("redrawn", redrawn), ("map", state.MapId), ("channels", route.GardenChannelNodes), ("trees", route.GardenTreeNodes), ("soil", route.GardenSoilNodes));
            check("farm_native_reload_keeps_garden", kept && redrawn);

            // --- Water is named where you stand beside it ---
            route.CloseModal(); Stand(Center(new HomeCell(22, 33))); route.Tick(0);
            string canal = route.Translate(WaterModel.Types.Require("canal").Require("name").AsString());
            bool brook = route.WaterInfo.StartsWith(canal + " · ", StringComparison.Ordinal) && WaterModel.Irrigates("canal");
            yield return new WaitForEndOfFrame();
            bool waterDrawn = route.Hud.LastWaterInfoBounds.width > 0 && route.Hud.WaterInfoFits;
            Stand(Center(new HomeCell(10, 20))); route.Tick(0);
            bool dryLand = route.WaterInfo == "";
            int described = WaterModel.MapIds.Sum(map => WaterModel.Describe(map).Count);
            bool kinds = WaterModel.Describe("ijsdal").Any(feature => feature.Kind == "hot_spring") && WaterModel.Describe("sunwell").Any(feature => feature.Kind == "geyser")
                && WaterModel.Describe("coast").All(feature => feature.Kind == "sea") && !WaterModel.Irrigates("sea") && !WaterModel.Irrigates("marsh");
            if (!(brook && waterDrawn && dryLand && kinds && described > 20))
                Detail("water", ("brook", brook), ("drawn", waterDrawn), ("dry", dryLand), ("kinds", kinds), ("described", described), ("info", route.WaterInfo));
            check("farm_native_water_types_named", brook && waterDrawn && dryLand && kinds && described > 20);

            // --- Wild grapes in the forest ---
            Travel("forest");
            var vine = Station("wild_grape");
            long grapes = state.Count("hs_grape");
            bool vineMenu = Reach(vine) && route.GardenMenu.Role == "wild_grape" && route.GardenMenu.Enabled("grapes");
            bool picked = route.GardenMenu.Choose("grapes") && state.Count("hs_grape") == grapes + 3 && !route.GardenMenu.Enabled("grapes") && !Model().WildGrapesReady;
            route.CloseModal(); state.PlayTime += 120; route.Tick(0);
            bool regrown = Model().WildGrapesReady;
            if (!(vineMenu && picked && regrown)) Detail("vine", ("menu", vineMenu), ("picked", picked), ("regrown", regrown), ("grapes", state.Count("hs_grape")), ("modal", route.Modal));
            check("farm_native_wild_grapes", vineMenu && picked && regrown);
            Travel("village");
            check("farm_native_three_rendered_captures", captures == 3);
        }

        static IEnumerator VerifyInput(string output, PlayerWorld world, RouteWorldController route, Action<string, bool> check)
        {
            var previousMode = InputSystem.settings.updateMode;
            var devices = new List<InputDevice>(); PlayerInputSource input = null;
            var original = route.Persistence.Preferences;
            try
            {
                InputSystem.settings.updateMode = InputSettings.UpdateMode.ProcessEventsManually;
                var keyboard = InputSystem.AddDevice<Keyboard>("Garden keyboard");
                var mouse = InputSystem.AddDevice<Mouse>("Garden mouse");
                var pad = InputSystem.AddDevice<Gamepad>("Garden controller");
                devices.AddRange(new InputDevice[] { keyboard, mouse, pad }); input = new PlayerInputSource(devices);
                InputFrame Sample(KeyboardState keys, GamepadState gamepad, double seconds = 0)
                {
                    InputSystem.QueueStateEvent(keyboard, keys); InputSystem.QueueStateEvent(mouse, new MouseState { position = new Vector2(40, 40) });
                    InputSystem.QueueStateEvent(pad, gamepad); InputSystem.Update(); input.SetContext(true, route.Gameplay.State.InputLocked);
                    var frame = input.Read(); route.Tick(seconds); route.HandleFrame(frame); return frame;
                }
                InputFrame Neutral() => Sample(new KeyboardState(), new GamepadState());
                InputFrame KeyPress(Key key) { Neutral(); var frame = Sample(new KeyboardState(key), new GamepadState()); Neutral(); return frame; }
                InputFrame PadPress(GamepadButton button) { Neutral(); var frame = Sample(new KeyboardState(), new GamepadState().WithButton(button)); Neutral(); return frame; }
                yield return new WaitForEndOfFrame();
                var farm = route.Farm; var state = route.Gameplay.State;
                route.CloseModal(); farm.Mode = "";
                // The hoe key opens the tool choices; arrows and Enter pick a tool.
                world.Teleport(new Vector2(26 * 32 + 16, 36 * 32 + 16)); world.Step(0, new MotionInput()); world.Motor.Facing = new Vector2(0, 1); route.Tick(0);
                var open = KeyPress(Key.U);
                bool opened = open.Pressed("homestead") && route.Modal == "garden_menu" && route.GardenMenu.Role == "tools" && route.GardenMenu.SelectedId == "mode:soil"
                    && route.GardenMenu.OptionIds.Take(8).SequenceEqual(FarmModel.ToolModes.Select(mode => "mode:" + mode));
                KeyPress(Key.RightArrow); bool right = route.GardenMenu.SelectedId == "mode:channel";
                KeyPress(Key.LeftArrow); KeyPress(Key.DownArrow); bool down = route.GardenMenu.SelectedId == "mode:grape";
                KeyPress(Key.UpArrow); bool up = route.GardenMenu.SelectedId == "mode:soil";
                KeyPress(Key.Enter);
                bool chosen = route.Modal == "" && farm.Mode == "soil";
                // Holding the use key works the tile ahead; walking on continues the row.
                var first = new HomeCell(26, 37);
                Neutral(); Sample(new KeyboardState(), new GamepadState(), .35);
                Sample(new KeyboardState(Key.E), new GamepadState(), .02);
                bool worked = farm.EntryAt(first).Entries.Count == 1;
                world.Teleport(new Vector2(28 * 32 + 16, 36 * 32 + 16)); world.Step(0, new MotionInput()); world.Motor.Facing = new Vector2(0, 1);
                Sample(new KeyboardState(Key.E), new GamepadState(), .12);
                bool row = farm.EntryAt(new HomeCell(27, 37)).Entries.Count == 1 && farm.EntryAt(new HomeCell(28, 37)).Entries.Count == 1;
                Neutral();
                // Restoring soil takes one press per tile, and a controller reaches the same menu.
                KeyPress(Key.U); bool reopened = route.Modal == "garden_menu" && route.GardenMenu.SelectedId == "mode:soil";
                bool fillPicked = route.GardenMenu.Choose("mode:fill") && farm.Mode == "fill";
                Neutral(); Sample(new KeyboardState(), new GamepadState(), .35);
                Sample(new KeyboardState(Key.E), new GamepadState(), .02);
                bool restored = farm.EntryAt(new HomeCell(28, 37)).Entries.Count == 0;
                world.Teleport(new Vector2(27 * 32 + 16, 36 * 32 + 16)); world.Step(0, new MotionInput()); world.Motor.Facing = new Vector2(0, 1);
                Sample(new KeyboardState(Key.E), new GamepadState(), .12);
                bool held = farm.EntryAt(new HomeCell(27, 37)).Entries.Count == 1;
                Neutral(); Sample(new KeyboardState(Key.E), new GamepadState(), .12);
                bool pressedAgain = farm.EntryAt(new HomeCell(27, 37)).Entries.Count == 0;
                Neutral();
                route.OpenGardenMenu("tools", null); Neutral();
                var padDown = PadPress(GamepadButton.DpadDown);
                bool padMoved = padDown.ControllerActive && route.GardenMenu.SelectedId != "mode:fill";
                PadPress(GamepadButton.East);
                bool padClosed = route.Modal == "";
                if (!(opened && right && down && up && chosen && worked && row && reopened && fillPicked && restored && held && pressedAgain && padMoved && padClosed))
                    Debug.Log("Farm detail input: opened=" + opened + " right=" + right + " down=" + down + " up=" + up + " chosen=" + chosen + " worked=" + worked + " row=" + row + " reopened=" + reopened + " fill=" + fillPicked + " restored=" + restored + " held=" + held + " again=" + pressedAgain + " pad=" + padMoved + " closed=" + padClosed + " selected=" + route.GardenMenu.SelectedId + " mode=" + farm.Mode + " modal=" + route.Modal + " aim=" + route.GardenAimCell().Key);
                check("farm_native_keyboard_and_controller_work", opened && right && down && up && chosen && worked && row && reopened && fillPicked && restored && held && pressedAgain && padMoved && padClosed);
                farm.EntryAt(first); route.ChooseGardenMode("fill");
                world.Teleport(new Vector2(26 * 32 + 16, 36 * 32 + 16)); world.Step(0, new MotionInput()); world.Motor.Facing = new Vector2(0, 1); route.Tick(.35); route.WorkGarden();
                route.ChooseGardenMode("");

                string privateRoot = Path.Combine(output, "private-farm-ui");
                if (Directory.Exists(privateRoot)) throw new IOException("Fresh private farm layout directory required");
                Directory.CreateDirectory(privateRoot); bool layouts = true; int layoutCaptures = 0;
                foreach (string language in new[] { "nl", "en" })
                foreach (int width in new[] { 1152, 960 })
                {
                    int height = width == 1152 ? 648 : 540;
                    yield return Resolution(width, height);
                    var old = route.Persistence.Preferences;
                    if (!route.Persistence.SetPreferences(new LegacyPreferences(language, old.Muted, old.MusicVolume, old.SfxVolume)))
                        throw new IOException("Synthetic farm locale could not be saved");
                    foreach (string view in new[] { "tools", "guide", "book" })
                    {
                        route.CloseModal();
                        if (view == "book") route.OpenSeedBook();
                        else route.OpenGardenMenu(view, null);
                        route.Tick(0); yield return new WaitForEndOfFrame();
                        if (view == "book")
                            layouts &= route.SeedBook.LayoutFits && route.SeedBook.DescriptionFits && route.SeedBook.StagesDrawn == 4
                                && route.SeedBook.RenderedSelectedBounds.width > 0 && StoryUi.Contains(SeedBookPanel.PanelRect, route.SeedBook.RenderedSelectedBounds);
                        else
                            layouts &= route.GardenMenu.LayoutFits && route.GardenMenu.BodyFits && route.GardenMenu.RenderedSelectedBounds.width > 0
                                && StoryUi.Contains(GardenMenu.PanelRect, route.GardenMenu.RenderedSelectedBounds);
                        var image = ScreenCapture.CaptureScreenshotAsTexture();
                        try
                        {
                            layouts &= image.width == width && image.height == height;
                            File.WriteAllBytes(Path.Combine(privateRoot, view + "-" + language + "-" + width + ".png"), image.EncodeToPNG());
                            layoutCaptures++;
                        }
                        finally { UnityEngine.Object.Destroy(image); }
                    }
                }
                string unchanged = route.Gameplay.State.Get("homestead").CanonicalJson;
                var close = KeyPress(Key.Escape);
                bool closed = route.Modal == "" && !route.SeedBook.IsOpen && (close.Pressed("ui_cancel") || close.Pressed("pause"))
                    && route.Gameplay.State.Get("homestead").CanonicalJson == unchanged;
                if (!(layouts && layoutCaptures == 12 && closed)) Debug.Log("Farm detail layout: layouts=" + layouts + " captures=" + layoutCaptures + " closed=" + closed);
                check("farm_native_menus_nl_en_responsive_layout", layouts && layoutCaptures == 12 && closed);
            }
            finally
            {
                route.Persistence.SetPreferences(original);
                input?.Dispose();
                foreach (var device in devices) if (device.added) InputSystem.RemoveDevice(device);
                InputSystem.settings.updateMode = previousMode;
            }
            yield return Resolution(1152, 648);
            route.CloseModal(); route.Tick(0);
        }
    }
}
