using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Persistence;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Probe;
using BlueMapMigration.Route;
using BlueMapMigration.Story;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace BlueMapMigration.Professions
{
    /// <summary>Native professions proof uses a fresh test profile and the real route controller.</summary>
    public static class ProfessionsProbeRunner
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

        /// <summary>Generator results chosen by the proof; ordinary play never uses this.</summary>
        sealed class Scripted : IFishingRandom
        {
            readonly Queue<double> values;
            public Scripted(params double[] draws) { values = new Queue<double>(draws); }
            public int Left => values.Count;
            double Next() => values.Count > 0 ? values.Dequeue() : 0.5;
            public double Randf() => Next();
            public double Range(double from, double to) => Next();
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
                    throw new InvalidOperationException("Duplicate professions proof " + name);
                checks.Add(new Phase2Probe.Check { name = name, passed = passed });
                Last.checks = checks.ToArray();
                if (!passed) Debug.Log("Professions native check failed: " + name);
            }

            var repository = FoundationWorldRepository.LoadRequired();
            ProfessionsModelChecks.Verify(repository, Check);
            string root = PersistencePaths.Checked(Path.Combine(output, "professions-profiles"));
            if (Directory.Exists(root)) throw new IOException("Fresh professions profile required");
            route.CloseModal();
            Fixture = new PersistenceCoordinator(repository, world.InputSource, root);
            if (!route.BeginNew(Fixture)) throw new IOException(Fixture.Status);
            route.CombatSimulationEnabled = false;
            route.ResidentsSimulationEnabled = false;
            Check("professions_native_shared_state_and_profile", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && ReferenceEquals(route.Professions.State, route.Gameplay.State)
                && ReferenceEquals(route.Professions.Inventory, route.Inventory)
                && ReferenceEquals(route.Professions.Progression, route.Progression));

            var live = RunLiveEpisodes(output, repository, world, route, Check);
            while (live.MoveNext()) yield return live.Current;

            Check("professions_no_personal_saves_used", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && PersistencePaths.Within(PersistencePaths.Checked(output), root)
                && !PersistencePaths.Within(PersistencePaths.UnityDefault, root)
                && !PersistencePaths.Within(PersistencePaths.LegacyDefault, root));
            route.CloseModal();
            route.FishingRandom = new UnityFishingRandom();
            route.Save();
            Last.success = checks.Count > 5 && checks.All(row => row.passed);
            Last.checks = checks.ToArray();
            File.WriteAllText(Path.Combine(output, "professions-result.json"), JsonUtility.ToJson(Last, true));
            Debug.Log("Professions native proof: " + checks.Count + " checks");
        }

        /// <summary>Positive numeric entries only: a reload may add zero defaults or reorder keys.</summary>
        static Dictionary<string, double> Counts(FoundationValue table) => table.Entries
            .Where(row => (row.Value.Kind == "int" || row.Value.Kind == "float") && row.Value.AsDouble() != 0)
            .ToDictionary(row => row.Key.AsString(), row => row.Value.AsDouble(), StringComparer.Ordinal);

        static IEnumerator Resolution(int width, int height)
        {
            Screen.SetResolution(width, height, FullScreenMode.Windowed);
            for (int frame = 0; frame < 30; frame++)
            { yield return null; if (Screen.width == width && Screen.height == height) yield break; }
            throw new InvalidOperationException("Professions viewport resize did not apply");
        }

        static IEnumerator RunLiveEpisodes(string output, FoundationWorldRepository repository,
            PlayerWorld world, RouteWorldController route, Action<string, bool> check)
        {
            var state = route.Gameplay.State;
            var model = route.Professions;
            string Json(FoundationValue value) => FoundationJson.StringifyPlain(value);
            void Travel(string map)
            {
                route.CloseModal();
                var source = repository.Read(map);
                string spawn = source.Arrivals.FirstOrDefault(row => row.Name == "start")?.Name ?? source.Arrivals[0].Name;
                if (!route.TryTravel(map, spawn)) throw new InvalidOperationException("Professions travel failed: " + map);
                state = route.Gameplay.State; model = route.Professions; route.Combat.ResetTransient();
            }
            void At(RouteTarget target, float distance = 30)
            {
                route.CloseModal();
                world.Teleport(target.Position + new Vector2(0, distance));
                world.Step(0, new MotionInput()); world.FocusCameraOnPlayer(); route.Tick(0);
            }
            RouteTarget Node(string kind, bool ready = true) => route.Targets.First(target => target.Kind == "resource_node" && target.Id == kind
                && (!ready || model.Remaining(target.UniqueKey) <= 0));
            bool Harvest(RouteTarget target)
            {
                At(target);
                if (!route.InteractTarget(target.Address)) return false;
                for (int guard = 0; route.Working && guard < 600; guard++) route.Tick(1.0 / 60);
                return !route.Working;
            }
            void Capture(string name)
            {
                string path = Path.Combine(output, "screenshot-professions-" + name + ".png");
                if (File.Exists(path)) throw new IOException("Fresh professions capture required");
                var image = ScreenCapture.CaptureScreenshotAsTexture();
                try
                {
                    if (image.width != 1152 || image.height != 648) throw new InvalidOperationException("Professions viewport differs");
                    File.WriteAllBytes(path, image.EncodeToPNG());
                }
                finally { UnityEngine.Object.Destroy(image); }
            }
            int captures = 0;

            // --- Timed harvest, cooldown and interruption in the village ---
            var twigs = Node("branches");
            long branchesBefore = state.Count("prof_branch"), woodBefore = model.Xp("woodcutting");
            At(twigs);
            bool started = route.InteractTarget(twigs.Address) && route.Working;
            route.Tick(.1); bool unpaidMidway = route.Working && state.Count("prof_branch") == branchesBefore;
            for (int guard = 0; route.Working && guard < 600; guard++) route.Tick(1.0 / 60);
            long gained = state.Count("prof_branch") - branchesBefore;
            bool rewarded = gained == model.GatherAmount("branches") && model.Xp("woodcutting") > woodBefore
                && model.Remaining(twigs.UniqueKey) > 0;
            bool refusedWhileRecovering = !route.InteractTarget(twigs.Address) && !route.Working
                && state.Count("prof_branch") == branchesBefore + gained;
            var secondTwigs = Node("branches");
            At(secondTwigs); long beforeInterrupt = state.Count("prof_branch");
            bool interrupted = route.InteractTarget(secondTwigs.Address) && route.Working;
            world.Teleport(secondTwigs.Position + new Vector2(0, 36)); world.Step(0, new MotionInput()); route.Tick(.05);
            interrupted &= !route.Working && state.Count("prof_branch") == beforeInterrupt && model.Remaining(secondTwigs.UniqueKey) <= 0;
            check("professions_native_timed_harvest_and_cooldown", started && unpaidMidway && rewarded && refusedWhileRecovering && interrupted);

            // --- Tools gate a stump; the first axe is made from loose twigs and flint ---
            Harvest(secondTwigs);
            foreach (var stone in route.Targets.Where(target => target.Kind == "resource_node" && target.Id == "stones").ToArray()) Harvest(stone);
            Travel("forest");
            var stump = Node("stump");
            At(stump); long birchBefore = state.Count(model.Resources.Require("stump").Require("item").AsString());
            bool gated = !route.InteractTarget(stump.Address) && !route.Working && model.GatherTool("stump") == "";
            bool enough = state.Count("prof_branch") >= 2 && state.Count("prof_stone") >= 2;
            bool axe = model.Craft("stone_axe") && state.Count("prof_axe") == 1 && model.GatherTool("stump") == "prof_axe";
            bool chopped = Harvest(stump) && state.Count(model.Resources.Require("stump").Require("item").AsString()) == birchBefore + model.GatherAmount("stump");
            check("professions_native_tool_gate_and_first_axe", gated && enough && axe && chopped);

            // --- The professions book: goal, recipe and food through the real panel ---
            state.Set("inventory", ProfessionsModelChecks.With(state.Get("inventory"), ("prof_branch", 6), ("prof_stone", 6), ("prof_berry", 4), ("prof_herb", 2)));
            route.OpenProfessions("stone_pickaxe");
            var panel = route.ProfessionsPanel;
            bool opened = route.Modal == "professions" && panel.IsOpen && panel.SelectedSkill == "mining" && panel.Current != null && panel.Current.Id == "stone_pickaxe";
            panel.MoveColumn(1); bool goalSet = panel.Column == 2 && panel.ToggleGoal() && model.Goal == "stone_pickaxe"; panel.MoveColumn(-1);
            yield return new WaitForEndOfFrame(); Capture("book"); captures++;
            bool crafted = panel.ActivateSelected() && state.Count("prof_pickaxe") == 1 && model.Goal == "" && model.Xp("mining") > 0;
            bool onceOnly = !panel.ActivateSelected() && state.Count("prof_pickaxe") == 1 && panel.LastSound == "error";
            panel.ToggleSupplies(); bool supplies = panel.Supplies && panel.Entries.All(entry => entry.Kind == "use");
            panel.ToggleSupplies(); bool back = !panel.Supplies && panel.SelectedSkill == "mining";
            route.CloseModal();
            check("professions_native_book_goal_and_recipe", opened && goalSet && crafted && onceOnly && supplies && back && !panel.IsOpen && route.Modal == "");

            var input = VerifyBookInput(output, world, route, check);
            while (input.MoveNext()) yield return input.Current;

            // --- Workplaces and work notes ---
            state.Set("inventory", ProfessionsModelChecks.With(state.Get("inventory"), ("prof_copper_ore", 4), ("prof_branch", 6)));
            string smelt = model.RecipeIds.First(id => model.Recipes.Require(id).TryGet("station", out var station) && station.AsString() == "smithy" && !model.Recipes.Require(id).TryGet("unlock", out _) && model.Recipes.Require(id).Require("level").AsInt64() == 1);
            string away = model.CraftReason(smelt);
            Travel("smithy");
            var notes = route.Targets.First(target => target.Kind == "craft_notes");
            string noteKind = WorldAccess.WorldAccessModel.Get(WorldAccess.WorldAccessModel.Get(notes.Fields, "obj", notes.Fields), "kind", FoundationValue.StringValue("")).AsString();
            string noteFlag = model.Notes.Require(noteKind).Require("flag").AsString();
            At(notes); bool unread = !state.Flag(noteFlag);
            bool read = route.InteractTarget(notes.Address) && route.Modal == "sign" && state.Flag(noteFlag) && route.Hud.SignLines.Length == model.NoteLines(noteKind).Count;
            string learnedMessage = route.Message; route.CloseModal(); route.ShowMessage("");
            bool again = route.InteractTarget(notes.Address) && route.Modal == "sign" && route.Message == "" && learnedMessage != "";
            route.CloseModal();
            bool station = away != "" && away == ProfessionsModel.Fill(model.Tr(model.Catalogs.Require("text").Require("station_required").AsString()), model.StationName("smithy"))
                && state.MapId == "smithy" && model.CraftReason(smelt) != away;
            check("professions_native_workplace_and_notes_once", unread && read && again && station);

            // --- Shop: rows, a purchase, a one-time item and an honest refusal ---
            state.Coins = 200;
            bool shopOpened = route.OpenShop("tobias") && route.Modal == "shop" && route.ShopPanel.IsOpen;
            var shop = route.ShopPanel;
            bool sameRows = shop.Rows.Select(row => row.Text).SequenceEqual(model.ShopRows("tobias").Select(row => row.Text)) && shop.Rows.Count > 3;
            yield return new WaitForEndOfFrame(); Capture("shop"); captures++;
            long potions = state.Count("potion");
            bool boughtPotion = shop.Selected == 0 && shop.ActivateSelected() && state.Count("potion") == potions + 1 && state.Coins == 200 - shop.Rows[0].Price;
            int boots = shop.Rows.ToList().FindIndex(row => row.Item == "boots");
            while (shop.Selected != boots) shop.MoveSelection(1);
            long coinsBeforeBoots = state.Coins;
            bool boughtOnce = shop.ActivateSelected() && state.Count("boots") == 1 && shop.Rows[boots].Owned && shop.Selected != boots
                && state.Coins == coinsBeforeBoots - shop.Rows[boots].Price;
            state.Coins = 1; shop.Refresh(); string beforePoor = Json(state.Snapshot());
            while (shop.Selected != 0) shop.MoveSelection(1);
            bool poor = !shop.ActivateSelected() && Json(state.Snapshot()) == beforePoor;
            while (shop.Selected != shop.CloseIndex) shop.MoveSelection(1);
            bool closed = shop.ActivateSelected() && route.Modal == "" && !shop.IsOpen;
            check("professions_native_shop_rows_and_purchase", shopOpened && sameRows && boughtPotion && boughtOnce && poor && closed);

            // --- Lake fishing: the rod gate, then one landed catch through the real session ---
            Travel("lake");
            var spot = route.Targets.First(target => target.Kind == "meer_visplek");
            At(spot); route.ShowMessage("");
            bool rodGate = state.Count("fishing_rod") == 0 && !route.InteractTarget(spot.Address) && route.Modal == "" && route.Message != "";
            route.ShowMessage(""); bool oneNotice = !route.InteractTarget(spot.Address) && route.Message == "";
            check("professions_native_fishing_rod_gate", rodGate && oneNotice);
            state.Set("inventory", ProfessionsModelChecks.With(state.Get("inventory"), ("fishing_rod", 1)));
            route.FishingRandom = new Scripted(1.25, 0.3, 0.3, 0.5, 0.9, 0.5, 0.9, 0.5, 0.9, 0.5, 0.9, 0.5, 0.9, 0.5, 0.9);
            long fishingBefore = model.Xp("fishing"), caughtBefore = state.Get("meer").TryGet("gevangen", out var landed) ? landed.AsInt64() : 0;
            bool cast = route.InteractTarget(spot.Address) && route.Modal == "fishing" && route.Fishing.Phase == "cast" && state.InputLocked;
            for (int guard = 0; route.Fishing != null && route.Fishing.Phase != "bite" && guard < 600; guard++) route.Tick(1.0 / 60);
            bool bite = route.Fishing.Phase == "bite"; string fish = route.Fishing.CatchId;
            bool hooked = route.Fishing.Press() && route.Fishing.Phase == "reel";
            bool pictured = false;
            for (int guard = 0; route.Fishing.Phase == "reel" && guard < 3600; guard++)
            {
                route.FishingView.Holding = route.Fishing.Reel.FishPos > route.Fishing.Reel.ZonePos; route.Tick(1.0 / 60);
                if (!pictured && guard == 120 && route.Fishing.Phase == "reel") { yield return new WaitForEndOfFrame(); Capture("fishing"); captures++; pictured = true; }
            }
            bool caught = route.Fishing.Phase == "result" && route.Fishing.Outcome == "gevangen" && state.Count(fish) == 1
                && model.Xp("fishing") > fishingBefore && state.Get("meer").Require("gevangen").AsInt64() == caughtBefore + 1;
            for (int guard = 0; !route.Fishing.CanCastAgain && guard < 120; guard++) route.Tick(1.0 / 60);
            bool again2 = route.Fishing.Press() && route.Fishing.Phase == "cast" && state.Count(fish) == 1;
            route.CloseModal();
            bool released = route.Modal == "" && !state.InputLocked && !route.Fishing.Active;
            check("professions_native_fishing_catch_once", cast && bite && hooked && pictured && caught && again2 && released);

            // --- A profile reload keeps skill, cooldowns and purchases without paying twice ---
            string inventoryBefore = state.Get("inventory").CanonicalJson, lakeBefore = state.Get("meer").CanonicalJson, goalBefore = model.Goal;
            var bagBefore = Counts(state.Get("inventory")); var lakeCounts = Counts(state.Get("meer"));
            var xpBefore = model.SkillIds.ToDictionary(skill => skill, skill => model.Xp(skill));
            var waitBefore = state.Get("professions").Require("cooldowns").Entries.ToDictionary(row => row.Key.AsString(), row => row.Value.AsDouble());
            double clockBefore = state.PlayTime; long coins = state.Coins;
            bool saved = route.Save() && route.Reload(false);
            state = route.Gameplay.State; model = route.Professions;
            bool sameSkills = model.SkillIds.All(skill => model.Xp(skill) == xpBefore[skill]) && model.Goal == goalBefore;
            var waitAfter = state.Get("professions").Require("cooldowns");
            bool sameWaits = waitBefore.Count > 0 && waitBefore.All(row => row.Value <= clockBefore || waitAfter.TryGet(row.Key, out var due) && due.AsDouble() == row.Value);
            bool sameBag = Counts(state.Get("inventory")).OrderBy(row => row.Key, StringComparer.Ordinal).SequenceEqual(bagBefore.OrderBy(row => row.Key, StringComparer.Ordinal));
            bool sameLake = Counts(state.Get("meer")).OrderBy(row => row.Key, StringComparer.Ordinal).SequenceEqual(lakeCounts.OrderBy(row => row.Key, StringComparer.Ordinal));
            if (!(saved && sameSkills && sameWaits && sameBag && sameLake && state.Coins == coins))
                Debug.Log("Professions reload detail: saved=" + saved + " skills=" + sameSkills + " waits=" + sameWaits + " bag=" + sameBag + " lake=" + sameLake + " coins=" + state.Coins + "/" + coins + " clock=" + clockBefore + "/" + state.PlayTime + " before=" + inventoryBefore + " after=" + state.Get("inventory").CanonicalJson + " lake=" + lakeBefore + " -> " + state.Get("meer").CanonicalJson);
            bool kept = saved && sameSkills && sameWaits && sameBag
                && sameLake && state.Coins == coins && model.Level("woodcutting") >= 1 && state.Count("boots") == 1;
            check("professions_native_reload_keeps_progress_without_duplicates", kept);
            check("professions_native_three_rendered_captures", captures == 3);
        }

        static IEnumerator VerifyBookInput(string output, PlayerWorld world, RouteWorldController route, Action<string, bool> check)
        {
            var previousMode = InputSystem.settings.updateMode;
            var devices = new List<InputDevice>(); PlayerInputSource input = null;
            var original = route.Persistence.Preferences;
            try
            {
                InputSystem.settings.updateMode = InputSettings.UpdateMode.ProcessEventsManually;
                var keyboard = InputSystem.AddDevice<Keyboard>("Professions book keyboard");
                var mouse = InputSystem.AddDevice<Mouse>("Professions book mouse");
                var pad = InputSystem.AddDevice<Gamepad>("Professions book controller");
                devices.AddRange(new InputDevice[] { keyboard, mouse, pad }); input = new PlayerInputSource(devices);
                Vector2 pointer = new Vector2(500, 140);
                InputFrame Sample(KeyboardState keys, GamepadState gamepad)
                {
                    InputSystem.QueueStateEvent(keyboard, keys); InputSystem.QueueStateEvent(mouse, new MouseState { position = pointer });
                    InputSystem.QueueStateEvent(pad, gamepad); InputSystem.Update(); input.SetContext(true, route.Gameplay.State.InputLocked);
                    var frame = input.Read(); route.Tick(0); route.HandleFrame(frame); return frame;
                }
                InputFrame Neutral() => Sample(new KeyboardState(), new GamepadState());
                InputFrame KeyPress(Key key) { Neutral(); var frame = Sample(new KeyboardState(key), new GamepadState()); Neutral(); return frame; }
                InputFrame PadPress(GamepadButton button) { Neutral(); var frame = Sample(new KeyboardState(), new GamepadState().WithButton(button)); Neutral(); return frame; }
                yield return new WaitForEndOfFrame();
                var open = KeyPress(Key.C);
                var panel = route.ProfessionsPanel;
                bool keyboardOpened = open.Pressed("crafting") && !open.ControllerActive && route.Modal == "professions" && panel.IsOpen;
                int first = panel.EntryIndex; KeyPress(Key.DownArrow); bool keyboardMoved = panel.Entries.Count < 2 || panel.EntryIndex == first + 1;
                KeyPress(Key.UpArrow); keyboardMoved &= panel.EntryIndex == first;
                var down = PadPress(GamepadButton.DpadDown);
                bool controllerMoved = down.ControllerActive && panel.ControllerActive && (panel.Entries.Count < 2 || panel.EntryIndex == first + 1);
                PadPress(GamepadButton.DpadLeft); bool controllerColumn = panel.Column == 0;
                int skillBefore = panel.SkillIndex, skillCount = route.Professions.SkillIds.Count;
                PadPress(GamepadButton.DpadDown); int skillAfter = (skillBefore + 1) % (skillCount + 1);
                bool controllerSkill = panel.SkillIndex == skillAfter && (skillAfter == skillCount ? panel.Supplies : panel.SelectedSkill == route.Professions.SkillIds[skillAfter]);
                PadPress(GamepadButton.DpadRight);
                if (!(keyboardOpened && keyboardMoved && controllerMoved && controllerColumn && controllerSkill))
                    Debug.Log("Professions book input detail: opened=" + keyboardOpened + " moved=" + keyboardMoved + " pad=" + controllerMoved + " column=" + controllerColumn + " skill=" + controllerSkill + " entries=" + panel.Entries.Count + " index=" + panel.EntryIndex + " modal=" + route.Modal);
                check("professions_native_book_keyboard_and_controller", keyboardOpened && keyboardMoved && controllerMoved && controllerColumn && controllerSkill);

                string privateRoot = Path.Combine(output, "private-professions-ui");
                if (Directory.Exists(privateRoot)) throw new IOException("Fresh private professions layout directory required");
                Directory.CreateDirectory(privateRoot); bool layouts = true; int layoutCaptures = 0;
                foreach (string language in new[] { "nl", "en" })
                foreach (int width in new[] { 1152, 960 })
                {
                    int height = width == 1152 ? 648 : 540;
                    yield return Resolution(width, height);
                    var old = route.Persistence.Preferences;
                    if (!route.Persistence.SetPreferences(new LegacyPreferences(language, old.Muted, old.MusicVolume, old.SfxVolume)))
                        throw new IOException("Synthetic professions locale could not be saved");
                    panel.Refresh(); route.Tick(0); yield return new WaitForEndOfFrame();
                    layouts &= panel.LayoutFits && panel.SelectionVisible && panel.RenderedSelectedBounds.width > 0
                        && StoryUi.Contains(ProfessionsPanel.PanelRect, panel.RenderedSelectedBounds)
                        && route.ShopPanel.LayoutFits && route.FishingView.LayoutFits;
                    var image = ScreenCapture.CaptureScreenshotAsTexture();
                    try
                    {
                        layouts &= image.width == width && image.height == height;
                        File.WriteAllBytes(Path.Combine(privateRoot, "book-" + language + "-" + width + ".png"), image.EncodeToPNG());
                        layoutCaptures++;
                    }
                    finally { UnityEngine.Object.Destroy(image); }
                }
                var close = KeyPress(Key.Escape);
                bool closed = route.Modal == "" && !panel.IsOpen && (close.Pressed("ui_cancel") || close.Pressed("pause"));
                check("professions_native_book_nl_en_responsive_layout", layouts && layoutCaptures == 4 && closed);
            }
            finally
            {
                route.Persistence.SetPreferences(original);
                input?.Dispose();
                foreach (var device in devices) InputSystem.RemoveDevice(device);
                InputSystem.settings.updateMode = previousMode;
            }
            yield return Resolution(1152, 648);
            route.CloseModal(); route.Tick(0);
        }
    }
}
