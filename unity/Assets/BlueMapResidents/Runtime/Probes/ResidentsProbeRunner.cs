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
using BlueMapMigration.Story;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace BlueMapMigration.Residents
{
    /// <summary>Native resident proof uses a fresh test profile and the real route controller.</summary>
    public static class ResidentsProbeRunner
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
                    throw new InvalidOperationException("Duplicate resident proof " + name);
                checks.Add(new Phase2Probe.Check { name = name, passed = passed });
                Last.checks = checks.ToArray();
                if (!passed) Debug.Log("Resident native check failed: " + name);
            }

            var repository = FoundationWorldRepository.LoadRequired();
            ResidentMotionChecks.Verify(Check);
            ResidentSocialChecks.Verify(repository, Check);
            string root = PersistencePaths.Checked(Path.Combine(output, "residents-profiles"));
            if (Directory.Exists(root)) throw new IOException("Fresh resident profile required");
            route.CloseModal();
            Fixture = new PersistenceCoordinator(repository, world.InputSource, root);
            if (!route.BeginNew(Fixture)) throw new IOException(Fixture.Status);
            route.CombatSimulationEnabled = false;
            route.ResidentsSimulationEnabled = true;
            Check("residents_native_shared_state_and_profile", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && ReferenceEquals(route.Residents.State, route.Gameplay.State)
                && ReferenceEquals(route.Residents.Story, route.Story)
                && ReferenceEquals(route.Residents.Story.Inventory, route.Inventory));

            var live = RunLiveEpisodes(output, repository, world, route, catalog, Check);
            while (live.MoveNext()) yield return live.Current;

            Check("residents_no_personal_saves_used", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && PersistencePaths.Within(PersistencePaths.Checked(output), root)
                && !PersistencePaths.Within(PersistencePaths.UnityDefault, root)
                && !PersistencePaths.Within(PersistencePaths.LegacyDefault, root));
            route.CloseModal();
            route.Residents.CloseKitchen();
            route.ResidentsSimulationEnabled = false;
            route.Save();
            Last.success = checks.Count > 4 && checks.All(row => row.passed);
            Last.checks = checks.ToArray();
            File.WriteAllText(Path.Combine(output, "residents-result.json"), JsonUtility.ToJson(Last, true));
            Debug.Log("Resident native proof: " + checks.Count + " checks");
        }

        static IEnumerator RunLiveEpisodes(string output, FoundationWorldRepository repository,
            PlayerWorld world, RouteWorldController route, Phase6Catalog catalog, Action<string, bool> check)
        {
            var state = route.Gameplay.State;
            string Json(FoundationValue value) => FoundationJson.StringifyPlain(value);
            string Snapshot(ResidentLiveActor actor) => Json(ResidentMotionChecks.Snapshot(actor.Motion));
            void Travel(string map)
            {
                route.CloseModal(); route.Residents.CloseKitchen();
                var source = repository.Read(map);
                string spawn = source.Arrivals.FirstOrDefault(row => row.Name == "start")?.Name ?? source.Arrivals[0].Name;
                if (!route.TryTravel(map, spawn)) throw new InvalidOperationException("Resident travel failed: " + map);
                state = route.Gameplay.State; route.Combat.ResetTransient();
            }
            void At(RouteTarget target, float distance = 30)
            {
                route.CloseModal(); route.Residents.CloseKitchen();
                world.Teleport(target.Position + new Vector2(0, distance));
                world.Step(0, new MotionInput()); world.FocusCameraOnPlayer(); route.Tick(0);
            }
            RouteTarget Object(string kind) => route.Targets.First(target => target.Kind == "supper_object" && target.Id == kind);
            void ToChoices()
            {
                for (int guard = 0; route.Gameplay.DialogueOpen && !route.Gameplay.Dialogue.ChoicesReady && guard < 80; guard++)
                { route.DialoguePanel.Reveal(); route.AdvanceDialogue(); }
                if (!route.Gameplay.DialogueOpen || !route.Gameplay.Dialogue.ChoicesReady)
                    throw new InvalidOperationException("Original resident choices did not open");
            }
            void Choose(string operation, string argument)
            {
                ToChoices();
                int selected = route.Gameplay.Dialogue.Choices.ToList().FindIndex(choice =>
                    choice.Source.TryGet("do", out var actions) && actions.Items.Any(action =>
                        action.Items.Count > 1 && action.Items[0].AsString() == operation && action.Items[1].AsString() == argument));
                if (selected < 0) throw new InvalidOperationException("Original resident choice missing: " + operation + "/" + argument);
                route.ChooseDialogue(selected);
            }
            void Capture(string name)
            {
                string path = Path.Combine(output, "screenshot-residents-" + name + ".png");
                if (File.Exists(path)) throw new IOException("Fresh resident capture required");
                var image = ScreenCapture.CaptureScreenshotAsTexture();
                try
                {
                    if (image.width != 1152 || image.height != 648) throw new InvalidOperationException("Resident viewport differs");
                    File.WriteAllBytes(path, image.EncodeToPNG());
                }
                finally { UnityEngine.Object.Destroy(image); }
            }

            // Existing opening progress is a legitimate saved context for testing the resident route.
            // The prior story proof separately earns this flag through the original grate and wheel.
            state.SetFlag("op_water", true); state.DayTime = .3; route.Tick(0);
            var gardener = route.ResidentActors.First(actor => actor.Motion.Kind == "village" && actor.Motion.Role == "gardener");
            Vector2 origin = gardener.Motion.Position;
            var originalFoot = world.ResidentFoot(gardener.Target.Address);
            world.Teleport(origin + new Vector2(0, 112)); world.Step(0, new MotionInput()); world.FocusCameraOnPlayer();
            bool moved = false, targetsFollow = true, movingFrame = false;
            for (int step = 0; step < 200; step++)
            {
                route.Tick(.05);
                moved |= Vector2.Distance(origin, gardener.Motion.Position) > 8;
                targetsFollow &= gardener.Target.Position == gardener.Motion.Position
                    && Vector2.Distance(world.ResidentVisualPosition(gardener.Target.Address), gardener.Motion.Position) < .01f;
                movingFrame |= gardener.Motion.Velocity.sqrMagnitude > 1 && world.ResidentVisualFrame(gardener.Target.Address) > 0;
            }
            check("residents_native_village_motion_targets", moved && targetsFollow && movingFrame);
            var foot = world.ResidentFoot(gardener.Target.Address);
            check("residents_native_moving_feet_no_old_anchor", originalFoot != null && ReferenceEquals(originalFoot, foot)
                && Vector2.Distance(foot.bounds.center, FoundationCoordinates.ToUnity(gardener.Motion.Position + new Vector2(0, 8))) < .001f
                && Vector2.Distance(foot.bounds.center, FoundationCoordinates.ToUnity(origin + new Vector2(0, 8))) > .1f);
            yield return new WaitForEndOfFrame(); Capture("roaming");

            string motion = Snapshot(gardener); route.OpenPause(); route.Tick(.7);
            bool menuPaused = Snapshot(gardener) == motion; route.CloseModal();
            At(gardener.Target); bool talked = route.InteractTarget(gardener.Target.Address) && route.Gameplay.DialogueOpen;
            motion = Snapshot(gardener); route.Tick(.7); bool dialoguePaused = Snapshot(gardener) == motion;
            route.CloseModal();
            check("residents_native_pause_and_dialogue_freeze", menuPaused && talked && dialoguePaused);
            var originalMotion = gardener.Motion; var originalCombat = route.Combat; var originalEncounter = route.Encounter;
            var oldPositions = route.Encounter.Actors.ToDictionary(actor => actor, actor => actor.Position);
            string currentSpawn = state.SpawnName;
            bool refreshed = route.TryTravel("village", currentSpawn, true);
            gardener = route.ResidentActors.First(actor => actor.Target.Address == gardener.Target.Address);
            check("residents_native_same_map_refresh_retains_actors", refreshed && ReferenceEquals(originalMotion, gardener.Motion)
                && ReferenceEquals(originalCombat, route.Combat) && ReferenceEquals(originalEncounter, route.Encounter)
                && oldPositions.All(row => route.Encounter.Actors.Contains(row.Key) && row.Key.Position == row.Value));
            string dayRoute = gardener.Motion.RouteKey; state.DayTime = .9; route.Tick(0);
            check("residents_native_daytime_route_change", ReferenceEquals(originalMotion, gardener.Motion)
                && dayRoute != gardener.Motion.RouteKey && gardener.Motion.RouteKey == "[true, true]");
            world.Teleport(new Vector2(640, 520)); world.Step(0, new MotionInput()); world.FocusCameraOnPlayer();
            for (int step = 0; step < 120; step++) route.Tick(.05);
            route.ShowMessage(""); route.ItemNotices.Clear();
            yield return new WaitForEndOfFrame(); Capture("routines");

            state.DayTime = .1; // Original day-zero morning slot is clear, so the working-route occupancy test cannot select a resting route.
            Travel("mistgarden"); bool absent = !route.ResidentActors.Any(actor => actor.Motion.Kind == "memory" && actor.Motion.Role == "gardener");
            state.SetFlag("lw_forest", true); route.RefreshResidentActors();
            var memory = route.ResidentActors.FirstOrDefault(actor => actor.Motion.Kind == "memory" && actor.Motion.Role == "gardener");
            var spawnedMotion = memory?.Motion; route.Tick(0);
            memory = route.ResidentActors.FirstOrDefault(actor => actor.Motion.Kind == "memory" && actor.Motion.Role == "gardener");
            check("residents_native_dynamic_memory_spawn", absent && memory != null && ReferenceEquals(spawnedMotion, memory.Motion)
                && world.ResidentFoot(memory.Target.Address) != null);
            if (memory == null) throw new InvalidOperationException("Original restored-garden resident missing");
            Vector2 memoryOrigin = memory.Motion.Position;
            var workPoints = route.Residents.Place("gardener").Require("work").Items;
            var occupiedPoint = workPoints[workPoints.Count - 1];
            world.Teleport(ResidentFootGrid.Center(new Vector2Int((int)occupiedPoint.Items[0].AsInt64(), (int)occupiedPoint.Items[1].AsInt64())));
            world.Step(0, new MotionInput());
            bool noOverlap = true, waited = false;
            for (int step = 0; step < 260; step++)
            {
                route.Tick(.05); noOverlap &= Vector2.Distance(memory.Motion.Position, world.Position) >= 26;
                waited |= memory.Motion.RouteIndex >= 2 && memory.Motion.Path.Count == 0 && memory.Motion.Wait > 0;
            }
            world.Teleport(memoryOrigin + new Vector2(112, 112)); world.Step(0, new MotionInput());
            bool memoryMoved = false;
            for (int step = 0; step < 300; step++)
            { route.Tick(.05); memoryMoved |= Vector2.Distance(memoryOrigin, memory.Motion.Position) > 4; }
            check("residents_native_memory_motion_and_player_occupancy", noOverlap && waited && memoryMoved
                && memory.Target.Position == memory.Motion.Position
                && Vector2.Distance(world.ResidentVisualPosition(memory.Target.Address), memory.Motion.Position) < .01f);
            At(memory.Target); long beforeCoins = state.Coins, beforeHeroXp = state.Get("hero_xp").AsInt64();
            string beforeBag = Json(state.Get("inventory"));
            bool greeted = route.InteractTarget(memory.Target.Address) && route.Gameplay.DialogueOpen && state.Flag("wm_met_gardener");
            route.CloseModal();
            Travel("inn"); var book = route.Targets.First(target => target.Kind == "memory_book"); At(book);
            bool readBook = route.InteractTarget(book.Address) && route.Gameplay.DialogueOpen
                && route.Gameplay.Dialogue.Lines.Any(line => line.Contains(route.Residents.Name("gardener")));
            check("residents_native_memory_interaction_and_book", greeted && readBook && state.Coins == beforeCoins
                && state.Get("hero_xp").AsInt64() == beforeHeroXp && Json(state.Get("inventory")) == beforeBag);
            route.DialoguePanel.Reveal();
            if (route.Gameplay.Dialogue.Lines.Count > 1) { route.AdvanceDialogue(); route.DialoguePanel.Reveal(); }
            yield return new WaitForEndOfFrame(); Capture("memory"); route.CloseModal();

            Travel("lake"); var basket = Object("basket"); At(basket, 38);
            bool toolMessage = route.InteractTarget(basket.Address) && route.Gameplay.DialogueOpen && !state.Flag("ls_basket");
            route.CloseModal(); state.Set("inventory", InventoryModel.Replace(state.Get("inventory"), "fishing_rod", FoundationValue.Integer(1)));
            At(basket, 38); route.InteractTarget(basket.Address); route.Tick(.9);
            world.Teleport(world.Position + new Vector2(9, 0)); route.Tick(.9);
            bool interrupted = route.Residents.Object != null && !route.Residents.Object.Pulling && !state.Flag("ls_basket");
            check("residents_native_basket_tools_and_interruption", toolMessage && interrupted);
            At(basket, 38); bool pulling = route.InteractTarget(basket.Address); route.Tick(1.79);
            bool pending = !state.Flag("ls_basket"); route.Tick(.02); long crates = state.Count("ls_crate");
            route.InteractTarget(basket.Address); route.Tick(2);
            check("residents_native_basket_reward_once", pulling && pending && state.Flag("ls_basket")
                && crates == 1 && state.Count("ls_crate") == crates && basket.Consumed);

            var net = Object("net"); At(net); route.InteractTarget(net.Address); Choose("ls_weave", "under");
            bool wrongReset = !state.Flag("ls_net") && route.Story.PendingSupperStitch == 0;
            foreach (string side in new[] { "over", "under", "over" }) Choose("ls_weave", side);
            long fish = state.Count("meer_baars"), herbs = state.Count("prof_herb");
            route.CloseModal(); At(net); route.InteractTarget(net.Address); route.CloseModal();
            route.Tick(0);
            check("residents_native_net_ordered_actions_once", wrongReset && state.Flag("ls_net")
                && fish == 2 && herbs == 1 && state.Count("meer_baars") == fish && state.Count("prof_herb") == herbs
                && world.ResidentObjectFrame(net.Address) == 1);

            Travel("inn"); var stove = Object("stove"); At(stove); bool kitchenOpened = route.InteractTarget(stove.Address)
                && route.Residents.Kitchen != null && route.Residents.Kitchen.Active && state.Paused;
            var kitchenInput = VerifyKitchenInput(output, world, route, check);
            while (kitchenInput.MoveNext()) yield return kitchenInput.Current;
            check("residents_native_kitchen_shared_state", kitchenOpened && state.Flag("ls_cooked")
                && state.Count("ls_crate") == 0 && state.Count("ls_chowder") == 2);
            route.Residents.CloseKitchen(); route.CloseModal();
            var table = Object("table"); At(table); route.InteractTarget(table.Address); Choose("ls_share", "ls_chowder");
            route.CloseModal(); route.RefreshResidentActors(); world.Teleport(new Vector2(592, 272));
            world.Step(0, new MotionInput()); world.FocusCameraOnPlayer();
            for (int step = 0; step < 160; step++) route.Tick(.05);
            var guests = route.ResidentActors.Where(actor => actor.Motion.Kind == "supper").ToArray();
            bool dishArtwork = world.ResidentObjectFrame(table.Address) == 1;
            // This artwork-only fixture exercises the other original favorite without granting another meal or reward.
            state.SetFlag("ls_favorite_broth", true); route.Tick(0);
            dishArtwork &= world.ResidentObjectFrame(table.Address) == 2;
            state.SetFlag("ls_favorite_broth", false); route.Tick(0);
            dishArtwork &= world.ResidentObjectFrame(table.Address) == 1;
            check("residents_native_supper_guests_and_share", state.Flag("ls_served") && state.QuestState("ls_supper") == "done"
                && state.Count("ls_chowder") == 1 && dishArtwork && guests.Length == 3 && guests.Select(actor => actor.Motion.Role).Distinct().Count() == 3
                && guests.All(actor => world.ResidentFoot(actor.Target.Address) != null
                    && Vector2.Distance(world.ResidentVisualPosition(actor.Target.Address), actor.Motion.Position) < .01f));
            route.ShowMessage(""); route.ItemNotices.Clear();
            yield return new WaitForEndOfFrame(); Capture("supper");

            state.Set("future_residents", FoundationJson.ParsePlain("{\"exact\":9007199254740993,\"unknown\":[null,true,\"🌿\"]}"));
            string savedBag = Json(state.Get("inventory")); long savedCoins = state.Coins, savedXp = state.Get("hero_xp").AsInt64();
            bool saved = route.Save(), reloaded = route.Reload(false); state = route.Gameplay.State;
            At(Object("table")); route.InteractTarget(Object("table").Address); route.CloseModal();
            check("residents_native_reload_no_duplicate_rewards", saved && reloaded && state.Flag("ls_served")
                && state.Flag("ls_basket") && state.Flag("ls_net") && state.Flag("wm_met_gardener")
                && state.Count("ls_chowder") == 1 && state.Coins == savedCoins && state.Get("hero_xp").AsInt64() == savedXp
                && Json(state.Get("inventory")) == savedBag && state.Get("future_residents").Require("exact").AsInt64() == 9007199254740993L);
            check("residents_native_four_rendered_captures", new[] { "roaming", "routines", "memory", "supper" }
                .All(name => File.Exists(Path.Combine(output, "screenshot-residents-" + name + ".png"))));
        }

        static IEnumerator Resolution(int width, int height)
        {
            if (Screen.width == width && Screen.height == height) yield break;
            Screen.SetResolution(width, height, FullScreenMode.Windowed);
            for (int frame = 0; frame < 30; frame++)
            { yield return null; if (Screen.width == width && Screen.height == height) yield break; }
            throw new InvalidOperationException("Resident viewport resize did not apply");
        }

        static IEnumerator VerifyKitchenInput(string output, PlayerWorld world, RouteWorldController route, Action<string, bool> check)
        {
            var previousMode = InputSystem.settings.updateMode;
            var preferences = route.Persistence.Preferences;
            var devices = new List<InputDevice>(); PlayerInputSource input = null; GameObject hostObject = null;
            try
            {
                InputSystem.settings.updateMode = InputSettings.UpdateMode.ProcessEventsManually;
                var keyboard = InputSystem.AddDevice<Keyboard>("Resident kitchen keyboard");
                var mouse = InputSystem.AddDevice<Mouse>("Resident kitchen mouse");
                var pad = InputSystem.AddDevice<Gamepad>("Resident kitchen controller");
                devices.AddRange(new InputDevice[] { keyboard, mouse, pad }); input = new PlayerInputSource(devices);
                Vector2 pointer = new Vector2(500, 140); int samples = 0;
                InputFrame Sample(KeyboardState keys, GamepadState gamepad, MouseState mouseState)
                {
                    InputSystem.QueueStateEvent(keyboard, keys); InputSystem.QueueStateEvent(mouse, mouseState);
                    InputSystem.QueueStateEvent(pad, gamepad); InputSystem.Update(); input.SetContext(true, route.Gameplay.State.InputLocked);
                    var frame = input.Read(); samples++; route.Tick(0); route.HandleFrame(frame); return frame;
                }
                InputFrame Neutral() => Sample(new KeyboardState(), new GamepadState(), new MouseState { position = pointer });
                InputFrame KeyPress(Key key)
                { Neutral(); var frame = Sample(new KeyboardState(key), new GamepadState(), new MouseState { position = pointer }); Neutral(); return frame; }
                InputFrame PadPress(GamepadButton button)
                { Neutral(); var frame = Sample(new KeyboardState(), new GamepadState().WithButton(button), new MouseState { position = pointer }); Neutral(); return frame; }
                yield return new WaitForEndOfFrame();
                var key = KeyPress(Key.Enter);
                bool keyboardSelected = !key.ControllerActive && key.Pressed("ui_accept")
                    && route.Residents.Kitchen.Dish == "ls_chowder" && route.ResidentsKitchen.SelectedControl == 2;

                string privateRoot = Path.Combine(output, "private-residents-ui");
                if (Directory.Exists(privateRoot)) throw new IOException("Fresh private kitchen layout directory required");
                Directory.CreateDirectory(privateRoot); bool layouts = true; int layoutCaptures = 0;
                foreach (string language in new[] { "nl", "en" })
                foreach (int width in new[] { 1152, 960 })
                {
                    int height = width == 1152 ? 648 : 540;
                    yield return Resolution(width, height);
                    var old = route.Persistence.Preferences;
                    if (!route.Persistence.SetPreferences(new LegacyPreferences(language, old.Muted, old.MusicVolume, old.SfxVolume)))
                        throw new IOException("Synthetic resident locale could not be saved");
                    route.Tick(0); yield return new WaitForEndOfFrame();
                    layouts &= route.ResidentsKitchen.LayoutFits && route.ResidentsKitchen.SelectionVisible
                        && route.ResidentsKitchen.RenderedSelectedBounds.width > 0
                        && StoryUi.Contains(ResidentsKitchenView.PanelRect, route.ResidentsKitchen.RenderedSelectedBounds);
                    var image = ScreenCapture.CaptureScreenshotAsTexture();
                    try
                    {
                        layouts &= image.width == width && image.height == height;
                        File.WriteAllBytes(Path.Combine(privateRoot, "kitchen-" + language + "-" + width + ".png"), image.EncodeToPNG());
                        layoutCaptures++;
                    }
                    finally { UnityEngine.Object.Destroy(image); }
                }
                var controller = PadPress(GamepadButton.South);
                bool first = controller.ControllerActive && !controller.CursorVisible && route.Residents.Kitchen.Working;
                route.Tick(0, .91); bool stageOne = route.Residents.Kitchen.Stage == 1 && !route.Residents.Kitchen.Working;
                PadPress(GamepadButton.DpadDown); bool navigation = route.ResidentsKitchen.SelectedControl == 3;
                PadPress(GamepadButton.DpadUp); navigation &= route.ResidentsKitchen.SelectedControl == 2;
                var secondKey = KeyPress(Key.Enter);
                bool second = !secondKey.ControllerActive && secondKey.CursorVisible && route.Residents.Kitchen.Working;
                route.Tick(0, .91); bool stageTwo = route.Residents.Kitchen.Stage == 2 && !route.Residents.Kitchen.Working;

                // Real virtual mouse packets and the corresponding normal IMGUI Down/Up events occur on separate repaint frames.
                hostObject = new GameObject("Resident kitchen native pointer proof"); var host = hostObject.AddComponent<StoryLayoutProbeHost>();
                Vector2 click = ResidentsKitchenView.ControlRects[2].center;
                pointer = new Vector2(click.x * Screen.width / 1152f, (648 - click.y) * Screen.height / 648f);
                Neutral(); bool down = false, up = false, pressed = false, released = false, mouseOwner = false;
                int downFrame = -1, upFrame = -1;
                void GuiPointer(EventType type)
                {
                    var original = Event.current;
                    try { Event.current = new Event { type = type, button = 0, mousePosition = click }; route.ResidentsKitchen.Draw(); }
                    finally { Event.current = original; }
                }
                host.Render = () =>
                {
                    if (Event.current.type != EventType.Repaint) return;
                    var frame = Sample(new KeyboardState(), new GamepadState(), new MouseState { position = pointer, buttons = 1 });
                    pressed = frame.Pressed("attack"); mouseOwner = !frame.ControllerActive && frame.CursorVisible;
                    GuiPointer(EventType.MouseDown); downFrame = Time.frameCount; down = true; host.Render = null;
                };
                for (int frame = 0; frame < 8 && !down; frame++) yield return new WaitForEndOfFrame();
                if (host.Error != null) throw host.Error;
                host.Render = () =>
                {
                    if (Event.current.type != EventType.Repaint) return;
                    var frame = Sample(new KeyboardState(), new GamepadState(), new MouseState { position = pointer });
                    released = frame.Released("attack"); GuiPointer(EventType.MouseUp);
                    upFrame = Time.frameCount; up = true; host.Render = null;
                };
                for (int frame = 0; frame < 8 && !up; frame++) yield return new WaitForEndOfFrame();
                if (host.Error != null) throw host.Error;
                bool third = route.Residents.Kitchen.Working; route.Tick(0, .91);
                check("residents_native_kitchen_keyboard_controller_mouse", samples >= 15 && keyboardSelected && first && stageOne
                    && navigation && second && stageTwo && third && down && up && pressed && released && mouseOwner && upFrame > downFrame
                    && route.Residents.Kitchen.Result != "" && !route.Residents.Kitchen.Working
                    && devices.All(device => device.added && !device.native));
                check("residents_native_kitchen_nl_en_responsive_layout", layouts && layoutCaptures == 4);
            }
            finally
            {
                if (hostObject != null) UnityEngine.Object.Destroy(hostObject);
                input?.Dispose(); foreach (var device in devices) if (device.added) InputSystem.RemoveDevice(device);
                InputSystem.settings.updateMode = previousMode;
                if (route.Persistence != null) route.Persistence.SetPreferences(preferences);
            }
            yield return Resolution(1152, 648); route.Tick(0);
        }
    }
}
