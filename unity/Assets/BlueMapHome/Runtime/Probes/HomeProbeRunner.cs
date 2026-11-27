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

namespace BlueMapMigration.Home
{
    /// <summary>Native home and yard proof uses a fresh test profile and the real route controller.</summary>
    public static class HomeProbeRunner
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
                    throw new InvalidOperationException("Duplicate home proof " + name);
                checks.Add(new Phase2Probe.Check { name = name, passed = passed });
                Last.checks = checks.ToArray();
                if (!passed) Debug.Log("Home native check failed: " + name);
            }

            var repository = FoundationWorldRepository.LoadRequired();
            HomeModelChecks.Verify(repository, Check);
            string root = PersistencePaths.Checked(Path.Combine(output, "home-profiles"));
            if (Directory.Exists(root)) throw new IOException("Fresh home profile required");
            route.CloseModal();
            Fixture = new PersistenceCoordinator(repository, world.InputSource, root);
            if (!route.BeginNew(Fixture)) throw new IOException(Fixture.Status);
            route.CombatSimulationEnabled = false;
            route.ResidentsSimulationEnabled = false;
            Check("home_native_shared_state_and_profile", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && ReferenceEquals(route.Home.State, route.Gameplay.State)
                && ReferenceEquals(route.Home.Inventory, route.Inventory));

            var live = RunLiveEpisodes(output, repository, world, route, Check);
            while (live.MoveNext()) yield return live.Current;

            Check("home_no_personal_saves_used", Fixture.Current.Snapshot.CopyOriginals().Count == 0
                && PersistencePaths.Within(PersistencePaths.Checked(output), root)
                && !PersistencePaths.Within(PersistencePaths.UnityDefault, root)
                && !PersistencePaths.Within(PersistencePaths.LegacyDefault, root));
            route.CloseModal();
            route.Save();
            Last.success = checks.Count > 5 && checks.All(row => row.passed);
            Last.checks = checks.ToArray();
            File.WriteAllText(Path.Combine(output, "home-result.json"), JsonUtility.ToJson(Last, true));
            Debug.Log("Home native proof: " + checks.Count + " checks");
        }

        static IEnumerator Resolution(int width, int height)
        {
            Screen.SetResolution(width, height, FullScreenMode.Windowed);
            for (int frame = 0; frame < 30; frame++)
            { yield return null; if (Screen.width == width && Screen.height == height) yield break; }
            throw new InvalidOperationException("Home viewport resize did not apply");
        }

        static IEnumerator RunLiveEpisodes(string output, FoundationWorldRepository repository,
            PlayerWorld world, RouteWorldController route, Action<string, bool> check)
        {
            var state = route.Gameplay.State;
            HomeModel Model() => route.Home;
            string Json(FoundationValue value) => value.CanonicalJson;
            void Travel(string map)
            {
                route.CloseModal();
                var source = repository.Read(map);
                string spawn = source.Arrivals.FirstOrDefault(row => row.Name == "start")?.Name ?? source.Arrivals[0].Name;
                if (!route.TryTravel(map, spawn)) throw new InvalidOperationException("Home travel failed: " + map);
                state = route.Gameplay.State; route.Combat.ResetTransient(); route.Tick(0);
            }
            void Stand(Vector2 position)
            { world.Teleport(position); world.Step(0, new MotionInput()); world.FocusCameraOnPlayer(); route.Tick(0); }
            RouteTarget Station(string role) => route.Targets.First(target => target.Kind == "home_station" && target.Id == role);
            bool Reach(RouteTarget target)
            { route.CloseModal(); Stand(target.Position + new Vector2(0, 34)); return route.InteractTarget(target.Address); }
            void Detail(string name, params (string key, object value)[] parts)
                => Debug.Log("Home detail " + name + ": " + String.Join(" ", parts.Select(part => part.key + "=" + part.value)));
            void Capture(string name)
            {
                string path = Path.Combine(output, "screenshot-home-" + name + ".png");
                if (File.Exists(path)) throw new IOException("Fresh home capture required");
                var image = ScreenCapture.CaptureScreenshotAsTexture();
                try
                {
                    if (image.width != 1152 || image.height != 648) throw new InvalidOperationException("Home viewport differs");
                    File.WriteAllBytes(path, image.EncodeToPNG());
                }
                finally { UnityEngine.Object.Destroy(image); }
            }
            int captures = 0;
            var free = new Vector2(208, 336);

            // --- The bed: rest, or open the designer from the same menu ---
            Travel("player_home");
            var bed = Station("bed");
            bool menu = Reach(bed) && route.Modal == "home_menu" && route.HomeMenu.IsOpen
                && route.HomeMenu.OptionIds.SequenceEqual(new[] { "rest", "decorate", "close" }) && route.HomeMenu.LayoutFits;
            state.Hp = 1;
            bool rested = route.HomeMenu.ActivateSelected() && route.Modal == "" && state.Hp == state.MaxHp;
            bool again = Reach(bed) && route.Modal == "home_menu";
            route.HomeMenu.MoveSelection(1);
            bool designer = route.HomeMenu.ActivateSelected() && route.Modal == "house_editor" && route.HouseEditor.IsOpen;
            if (!(menu && rested && again && designer)) Detail("bed", ("menu", menu), ("rested", rested), ("again", again), ("designer", designer), ("modal", route.Modal));
            check("home_native_bed_menu_rest_and_design", menu && rested && again && designer);

            // --- A blocked walking route is refused; cancelling discards the draft ---
            var editor = route.HouseEditor;
            Stand(free); route.OpenHouseEditor(); editor = route.HouseEditor;
            string before = Json(state.Get("personal_home"));
            int chair = Model().PieceIds.ToList().IndexOf("chair");
            editor.SelectKind(chair);
            while (editor.Cursor.X < 6) editor.MoveCursor(1, 0);
            while (editor.Cursor.Y > 8) editor.MoveCursor(0, -1);
            bool refused = editor.Cursor.Equals(new HomeCell(6, 8)) && !editor.Place()
                && editor.PlacementReason() == route.Translate("Houd de deur en de gemarkeerde looproute vrij.");
            while (editor.Cursor.X > 4) editor.MoveCursor(-1, 0);
            while (editor.Cursor.Y < 9) editor.MoveCursor(0, 1);
            bool drafted = editor.Place() && editor.Draft.Require("layout").TryGet("chair:1", out _);
            route.CloseModal();
            bool discarded = route.Modal == "" && !editor.IsOpen && Json(state.Get("personal_home")) == before;
            check("home_native_house_blocked_route_refused", refused);
            check("home_native_house_cancel_discards", drafted && discarded);

            // --- Make a second chair, place both, choose a floor and apply: the room is rebuilt from the save ---
            state.Set("inventory", With(state.Get("inventory"), ("prof_log", 2), ("prof_branch", 2)));
            Stand(free); route.OpenHouseEditor(); editor = route.HouseEditor;
            editor.SelectKind(chair);
            bool made = editor.Activate("make") && Model().HouseView.Require("owned").Require("chair").AsInt64() == 2
                && state.Count("prof_log") == 0 && !editor.Activate("make");
            editor.SelectKind(chair);
            while (editor.Cursor.X > 4) editor.MoveCursor(-1, 0); while (editor.Cursor.X < 4) editor.MoveCursor(1, 0);
            while (editor.Cursor.Y < 9) editor.MoveCursor(0, 1); while (editor.Cursor.Y > 9) editor.MoveCursor(0, -1);
            bool first = editor.Place();
            editor.SelectKind(chair);
            while (editor.Cursor.X < 9) editor.MoveCursor(1, 0);
            while (editor.Cursor.Y < 10) editor.MoveCursor(0, 1);
            editor.CycleTint();
            bool second = editor.EditingId == "chair:2" && editor.Place();
            editor.Activate("floor"); editor.Activate("light");
            yield return new WaitForEndOfFrame(); Capture("house"); captures++;
            bool applied = editor.Activate("apply") && route.Modal == "" && !editor.IsOpen;
            route.Tick(0); state = route.Gameplay.State;
            var layout = Model().HouseView.Require("layout");
            bool saved = layout.TryGet("chair:1", out var one) && layout.TryGet("chair:2", out var two)
                && two.Require("cell").Items[0].AsInt64() == 9 && two.Require("tint").AsInt64() == 1
                && Model().HouseView.Require("floor").AsInt64() == 1 && Model().HouseView.Require("light").AsInt64() == 1;
            bool rebuilt = world.RoutePresentation.Objects.ContainsKey("home-furniture/chair:1")
                && world.RoutePresentation.Objects.ContainsKey("home-furniture/chair:2")
                && Vector2.Distance(world.Position, free) < 28 && state.MapId == "player_home";
            if (!(made && first && second && applied && saved && rebuilt))
                Detail("house", ("made", made), ("first", first), ("second", second), ("applied", applied), ("saved", saved), ("rebuilt", rebuilt), ("status", editor.LastStatus), ("position", world.Position), ("layout", Json(layout)));
            check("home_native_house_design_apply_rebuilds_room", made && first && second && applied && saved && rebuilt);

            var input = VerifyEditorInput(output, world, route, check);
            while (input.MoveNext()) yield return input.Current;

            // --- The yard: paths, a fence and a self-opening gate ---
            Travel("village");
            var guide = Station("guide");
            bool yardMenu = Reach(guide) && route.Modal == "garden_menu" && route.GardenMenu.OptionIds.Contains("yard") && route.GardenMenu.LayoutFits;
            bool yardOpened = route.GardenMenu.Choose("yard") && route.Modal == "yard_editor" && route.YardEditor.IsOpen;
            var yard = route.YardEditor;
            var outside = new Vector2(240, 720);
            world.Teleport(outside); world.Step(0, new MotionInput());
            var ids = Model().UnitIds.Concat(Model().YardPieceIds).ToList();
            void Aim(int x, int y)
            {
                for (int guard = 0; guard < 80 && yard.Cursor.X != x; guard++) yard.MoveCursor(Math.Sign(x - yard.Cursor.X), 0);
                for (int guard = 0; guard < 80 && yard.Cursor.Y != y; guard++) yard.MoveCursor(0, Math.Sign(y - yard.Cursor.Y));
            }
            yard.Choose(ids.IndexOf("gravel")); yard.Activate("row"); Aim(5, 27);
            bool path = yard.RowMode && yard.Place(); Aim(6, 27); path &= yard.StrokeCells().Count == 2 && yard.Place(); yard.Activate("row"); path &= !yard.RowMode;
            yard.Choose(ids.IndexOf("fence_h")); Aim(12, 27); bool fence = yard.Place();
            yard.Choose(ids.IndexOf("gate_h")); Aim(13, 27); bool gate = yard.Place();
            yard.Choose(ids.IndexOf("fence_h")); Aim(20, 31); bool water = !yard.Place() && yard.Reason != "";
            Aim(12, 27);
            yield return new WaitForEndOfFrame(); Capture("yard-design"); captures++;
            bool yardApplied = yard.Activate("apply") && route.Modal == "" && !yard.IsOpen;
            route.Tick(0);
            bool drawn = route.YardPathNodes == 2 && route.YardFenceNodes == 2 && route.YardGateNodes == 1
                && world.SurfaceAt(new Vector2(5 * 32 + 16, 27 * 32 + 8)) == "path" && world.SurfaceAt(new Vector2(4 * 32 + 16, 27 * 32 + 8)) != "path"
                && Model().YardView.Require("paths").Entries.Count == 2 && Model().YardView.Require("fences").Entries.Count == 2;
            if (!(yardMenu && yardOpened && path && fence && gate && water && yardApplied && drawn))
                Detail("yard", ("menu", yardMenu), ("opened", yardOpened), ("path", path), ("fence", fence), ("gate", gate), ("water", water), ("applied", yardApplied), ("drawn", drawn), ("reason", yard.Reason), ("nodes", route.YardPathNodes + "/" + route.YardFenceNodes + "/" + route.YardGateNodes));
            check("home_native_yard_paths_fence_and_gate", yardMenu && yardOpened && path && fence && gate && water && yardApplied && drawn);

            var gateCenter = new Vector2(13 * 32 + 16, 27 * 32 + 16);
            Stand(gateCenter + new Vector2(0, 150)); bool closedFar = route.YardOpenGates == 0;
            Stand(gateCenter + new Vector2(0, 40)); bool opensNear = route.YardOpenGates == 1;
            Stand(gateCenter + new Vector2(0, 70)); bool staysOpen = route.YardOpenGates == 1;
            yield return new WaitForEndOfFrame(); Capture("yard"); captures++;
            Stand(gateCenter + new Vector2(0, 150)); bool closesBehind = route.YardOpenGates == 0;
            check("home_native_yard_gate_opens_and_closes", closedFar && opensNear && staysOpen && closesBehind);

            // --- Move the hive, store a wine barrel and unlock building room ---
            Stand(outside); state.Set("inventory", With(state.Get("inventory"), ("prof_log", 6), ("prof_stone", 6)));
            bool reopened = route.OpenYardEditor(); yard = route.YardEditor;
            var hive = Station("hive"); var barrel = route.Targets.First(target => target.Kind == "home_station" && target.Id == "wine");
            yard.Choose(ids.IndexOf("hive")); Aim(14, 34); bool movedHive = yard.Place();
            yard.Choose(ids.IndexOf("wine_a")); bool stored = yard.Activate("pack");
            bool expanded = yard.Activate("expand") && !yard.Activate("expand")
                && Model().YardView.Require("extensions").Items.Any(v => v.AsString() == "west") && state.Count("prof_log") == 0;
            bool stationsApplied = yard.Activate("apply"); route.Tick(0);
            hive = Station("hive");
            bool placed = Vector2.Distance(hive.Position, new Vector2(14 * 32 + 16, 34 * 32 + 16)) < .5f
                && route.Targets.Count(target => target.Kind == "home_station" && target.Id == "wine" && target.Position.x < -1000) == 1
                && Model().YardView.Require("stations").Require("wine_a").Items.Count == 0;
            if (!(reopened && movedHive && stored && expanded && stationsApplied && placed))
                Detail("stations", ("reopened", reopened), ("hive", movedHive), ("stored", stored), ("expanded", expanded), ("applied", stationsApplied), ("placed", placed), ("reason", yard.Reason), ("hiveAt", hive.Position));
            check("home_native_yard_station_move_store_and_expand", reopened && movedHive && stored && expanded && stationsApplied && placed);

            // --- A profile reload keeps the whole design ---
            FoundationValue houseBefore = Model().HouseView, yardBefore = Model().YardView; string house = Json(houseBefore), yardSaved = Json(yardBefore);
            bool reloaded = route.Save() && route.Reload(false); route.Tick(0); state = route.Gameplay.State;
            bool kept = reloaded && Same(Model().HouseView, houseBefore) && Same(Model().YardView, yardBefore);
            if (state.MapId != "village") Travel("village");
            route.Tick(0);
            bool redrawn = route.YardPathNodes == 2 && route.YardFenceNodes == 2 && route.YardGateNodes == 1
                && Vector2.Distance(Station("hive").Position, new Vector2(14 * 32 + 16, 34 * 32 + 16)) < .5f;
            if (!(kept && redrawn)) Detail("reload", ("reloaded", reloaded), ("kept", kept), ("redrawn", redrawn), ("map", state.MapId), ("house", Json(Model().HouseView)), ("was", house), ("yard", Json(Model().YardView)), ("wasYard", yardSaved));
            check("home_native_reload_keeps_house_and_yard", kept && redrawn);
            check("home_native_three_rendered_captures", captures == 3);
        }

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

        /// <summary>A bag with the given counts set; used to prepare synthetic test profiles only.</summary>
        static FoundationValue With(FoundationValue inventory, params (string item, long count)[] items)
        { foreach (var row in items) inventory = InventoryModel.Replace(inventory, row.item, FoundationValue.Integer(row.count), row.count <= 0); return inventory; }

        static IEnumerator VerifyEditorInput(string output, PlayerWorld world, RouteWorldController route, Action<string, bool> check)
        {
            var previousMode = InputSystem.settings.updateMode;
            var devices = new List<InputDevice>(); PlayerInputSource input = null;
            var original = route.Persistence.Preferences;
            try
            {
                InputSystem.settings.updateMode = InputSettings.UpdateMode.ProcessEventsManually;
                var keyboard = InputSystem.AddDevice<Keyboard>("Home designer keyboard");
                var mouse = InputSystem.AddDevice<Mouse>("Home designer mouse");
                var pad = InputSystem.AddDevice<Gamepad>("Home designer controller");
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
                world.Teleport(new Vector2(208, 336)); world.Step(0, new MotionInput()); route.Tick(0);
                bool opened = route.OpenHouseEditor(); var editor = route.HouseEditor; Neutral();
                int kind = Array.IndexOf(route.Home.PieceIds.ToArray(), editor.Kind);
                var down = KeyPress(Key.DownArrow);
                bool listMoved = !down.ControllerActive && editor.Zone == 0 && Array.IndexOf(route.Home.PieceIds.ToArray(), editor.Kind) == (kind + 1) % route.Home.PieceIds.Count;
                var next = KeyPress(Key.PageDown);
                bool toPlan = next.Pressed("ui_next_tab") && editor.Zone == 1;
                while (editor.Cursor.X > 5) editor.MoveCursor(-1, 0); while (editor.Cursor.X < 5) editor.MoveCursor(1, 0);
                while (editor.Cursor.Y > 5) editor.MoveCursor(0, -1); while (editor.Cursor.Y < 5) editor.MoveCursor(0, 1);
                var at = editor.Cursor; KeyPress(Key.RightArrow);
                bool cursorKey = editor.Cursor.X == Math.Min(11, at.X + 1) && editor.Cursor.Y == at.Y;
                at = editor.Cursor; var padDown = PadPress(GamepadButton.DpadDown);
                bool cursorPad = padDown.ControllerActive && editor.ControllerActive && editor.Cursor.Y == Math.Min(11, at.Y + 1);
                PadPress(GamepadButton.DpadUp); PadPress(GamepadButton.DpadLeft);
                bool restored = editor.Cursor.Equals(new HomeCell(at.X - 1, at.Y));
                if (!(opened && listMoved && toPlan && cursorKey && cursorPad && restored))
                    Debug.Log("Home detail input: opened=" + opened + " list=" + listMoved + " plan=" + toPlan + " key=" + cursorKey + " pad=" + cursorPad + " restored=" + restored + " zone=" + editor.Zone + " cursor=" + editor.Cursor.Key);
                check("home_native_designer_keyboard_and_controller", opened && listMoved && toPlan && cursorKey && cursorPad && restored);

                string privateRoot = Path.Combine(output, "private-home-ui");
                if (Directory.Exists(privateRoot)) throw new IOException("Fresh private home layout directory required");
                Directory.CreateDirectory(privateRoot); bool layouts = true; int layoutCaptures = 0;
                foreach (string language in new[] { "nl", "en" })
                foreach (int width in new[] { 1152, 960 })
                {
                    int height = width == 1152 ? 648 : 540;
                    yield return Resolution(width, height);
                    var old = route.Persistence.Preferences;
                    if (!route.Persistence.SetPreferences(new LegacyPreferences(language, old.Muted, old.MusicVolume, old.SfxVolume)))
                        throw new IOException("Synthetic home locale could not be saved");
                    route.Tick(0); yield return new WaitForEndOfFrame();
                    layouts &= editor.LayoutFits && editor.RenderedSelectedBounds.width > 0
                        && StoryUi.Contains(HouseEditorPanel.PanelRect, editor.RenderedSelectedBounds)
                        && route.YardEditor.LayoutFits && route.HomeMenu.LayoutFits;
                    var image = ScreenCapture.CaptureScreenshotAsTexture();
                    try
                    {
                        layouts &= image.width == width && image.height == height;
                        File.WriteAllBytes(Path.Combine(privateRoot, "house-" + language + "-" + width + ".png"), image.EncodeToPNG());
                        layoutCaptures++;
                    }
                    finally { UnityEngine.Object.Destroy(image); }
                }
                string unchanged = route.Gameplay.State.Get("personal_home").CanonicalJson;
                var close = KeyPress(Key.Escape);
                bool closed = route.Modal == "" && !editor.IsOpen && (close.Pressed("ui_cancel") || close.Pressed("pause"))
                    && route.Gameplay.State.Get("personal_home").CanonicalJson == unchanged;
                check("home_native_designer_nl_en_responsive_layout", layouts && layoutCaptures == 4 && closed);
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
