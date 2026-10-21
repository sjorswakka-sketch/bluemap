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
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace BlueMapMigration.Inventory
{
    /// <summary>Actual player UI and native Input System events; only the caller's synthetic profile is used.</summary>
    public static class InventoryUiProbeRunner
    {
        public static int NativeSamples { get; private set; }
        public static int Captures { get; private set; }
        public static int PrivateLayoutCaptures { get; private set; }
        public static readonly string[] CaptureFiles = { "screenshot-inventory-bag.png", "screenshot-inventory-home.png", "screenshot-inventory-coast.png", "screenshot-inventory-controller.png" };
        static FoundationValue S(string text) => FoundationValue.StringValue(text);
        static FoundationValue I(long number) => FoundationValue.Integer(number);
        static string Spawn(FoundationWorldSnapshot map) => map.Arrivals.FirstOrDefault(v => v.Name == "start")?.Name ?? map.Arrivals[0].Name;
        static bool Contains(Rect outer, Rect inner) => inner.width > 0 && inner.height > 0 && inner.xMin >= outer.xMin - .5f && inner.yMin >= outer.yMin - .5f && inner.xMax <= outer.xMax + .5f && inner.yMax <= outer.yMax + .5f;
        static bool CoastStorage(RouteTarget target) => target.Kind == "coastal_workstation" && InventoryModel.Get(InventoryModel.Get(target.Fields, "obj", target.Fields), "role", S("")).AsString() == "storage";
        static void StandAt(PlayerWorld world, RouteWorldController route, RouteTarget target)
        {
            var candidates = new[] { new Vector2(0, 28), new Vector2(0, 40), new Vector2(32, 0), new Vector2(-32, 0), new Vector2(0, -32) };
            Vector2 point = candidates.Select(offset => target.Position + offset).FirstOrDefault(p => route.Access.SpawnFits(route.Session.Current, p));
            if (point == Vector2.zero) point = route.Access.ResolveArrival(route.Session.Current, target.Position + new Vector2(0, 32));
            world.Teleport(point); world.Step(0, new MotionInput { Direction = Vector2.zero }); route.Tick(.02);
        }
        static void Capture(string path, int width, int height)
        {
            if (File.Exists(path)) throw new IOException("A fresh native UI screenshot is required: " + Path.GetFileName(path));
            Texture2D picture = ScreenCapture.CaptureScreenshotAsTexture();
            try
            {
                if (picture == null || picture.width != width || picture.height != height) throw new InvalidOperationException("The native UI screenshot does not match the requested viewport.");
                File.WriteAllBytes(path, picture.EncodeToPNG());
            }
            finally { if (picture != null) UnityEngine.Object.Destroy(picture); }
        }
        static IEnumerator Resolution(int width, int height)
        {
            if (Screen.width == width && Screen.height == height) yield break;
            Screen.SetResolution(width, height, FullScreenMode.Windowed);
            for (int frame = 0; frame < 30; frame++)
            { yield return null; if (Screen.width == width && Screen.height == height) yield break; }
            throw new InvalidOperationException("Native UI viewport resize was not applied.");
        }

        public static IEnumerator Run(BuildIdentity identity, string output, PlayerWorld world, RouteWorldController route, Phase6Catalog catalog, Action<string, bool> check)
        {
            if (identity == null || world == null || route == null || catalog == null || check == null) throw new ArgumentNullException("Native inventory UI proof arguments are required.");
            if (!route.Running || route.Persistence == null) throw new InvalidOperationException("The caller must supply an isolated synthetic adventure.");
            NativeSamples = Captures = PrivateLayoutCaptures = 0;
            var originalMode = InputSystem.settings.updateMode; bool originalCursor = Cursor.visible;
            LegacyPreferences originalPreferences = route.Persistence.Preferences;
            var devices = new List<InputDevice>(); PlayerInputSource input = null;
            try
            {
                InputSystem.settings.updateMode = InputSettings.UpdateMode.ProcessEventsManually;
                var keyboard = InputSystem.AddDevice<Keyboard>("Phase12InventoryKeyboard"); devices.Add(keyboard);
                var mouse = InputSystem.AddDevice<Mouse>("Phase12InventoryMouse"); devices.Add(mouse);
                var gamepad = InputSystem.AddDevice<Gamepad>("Phase12InventoryGamepad"); devices.Add(gamepad);
                input = new PlayerInputSource(devices); input.SetContext(true, true);
                Vector2 pointer = new Vector2(300 * Screen.width / 1152f, (648 - 310) * Screen.height / 648f);
                InputFrame Sample(GamepadState pad, KeyboardState keys, MouseState mouseState, double delta = 1.0 / 60)
                {
                    InputSystem.QueueStateEvent(keyboard, keys); InputSystem.QueueStateEvent(mouse, mouseState); InputSystem.QueueStateEvent(gamepad, pad); InputSystem.Update();
                    input.SetContext(true, true); var frame = input.Read(); NativeSamples++; route.Tick(delta); route.HandleFrame(frame); return frame;
                }
                InputFrame Neutral(double delta = 1.0 / 60) => Sample(new GamepadState(), new KeyboardState(), new MouseState { position = pointer }, delta);
                InputFrame Pad(GamepadState value, double delta = 1.0 / 60) => Sample(value, new KeyboardState(), new MouseState { position = pointer }, delta);
                InputFrame KeySample(Key key) => Sample(new GamepadState(), new KeyboardState(key), new MouseState { position = pointer });
                void Press(GamepadButton button) { Neutral(); Pad(new GamepadState().WithButton(button)); Neutral(); }
                void KeyPress(Key key) { Neutral(); KeySample(key); Neutral(); }
                bool Travel(string map)
                { route.CloseModal(); var source = route.Session.Repository.Read(map); return route.TryTravel(map, Spawn(source)); }
                void Preferences(string locale)
                { var old = route.Persistence.Preferences; if (!route.Persistence.SetPreferences(new LegacyPreferences(locale, old.Muted, old.MusicVolume, old.SfxVolume))) throw new IOException("Cannot store synthetic UI language preference."); route.UpdateInventoryContext(); }

                yield return Resolution(1152, 648); Preferences("nl");
                if (!Travel("player_home")) throw new InvalidOperationException("The synthetic home UI could not be reached.");
                var model = route.Inventory; var state = model.State;
                var bag = state.Get("inventory").Entries.ToDictionary(row => row.Key.AsString(), row => row.Value, StringComparer.Ordinal);
                foreach (var item in model.Items.Entries)
                {
                    string id = item.Key.AsString(); long cap = InventoryModel.Get(item.Value, "max", I(0)).AsInt64();
                    bag[id] = I(cap > 0 ? Math.Min(24, cap) : 24);
                }
                state.Set("inventory", FoundationValue.Object(bag));
                var materials = model.Items.Entries.Select(row => row.Key.AsString()).Where(id => model.ItemType(id) == "material").ToArray();
                string chosen = materials.First(id => model.Category(id) == 1);
                var home = materials.Take(30).Select((id, index) => new KeyValuePair<string, FoundationValue>(id, I(48 + index * 3))).ToDictionary(row => row.Key, row => row.Value, StringComparer.Ordinal);
                home[chosen] = I(73);
                var coast = materials.Take(12).Select((id, index) => new KeyValuePair<string, FoundationValue>(id, I(87 + index))).ToDictionary(row => row.Key, row => row.Value, StringComparer.Ordinal);
                var stockroom = InventoryModel.Replace(state.Get("stockroom"), "home", FoundationValue.Object(home));
                stockroom = InventoryModel.Replace(stockroom, "favorites", FoundationValue.Object(new Dictionary<string, FoundationValue> { { chosen, FoundationValue.Boolean(true) } }));
                state.Set("stockroom", stockroom); state.Set("coastal_storage", FoundationValue.Object(coast));
                model.SetSort(0); state.Hp = Math.Max(1, state.MaxHp - 2); state.Coins = 137;
                var stockTarget = route.Targets.First(target => target.Kind == "stock_chest"); StandAt(world, route, stockTarget);
                route.InventoryPanel.Refresh();
                bool allIcons = model.Items.Entries.All(row => route.InventoryPanel.HasSourceIcon(row.Key.AsString()));
                check("inventory_ui_original_item_icons", allIcons && model.Items.Entries.Count == 226);

                // The retained H/Y shortcut uses the same transaction as the bag action and never wastes a potion.
                long quickCount = state.Count("potion"), quickDrunk = state.Get("potions_drunk").AsInt64(), quickHp = state.Hp;
                KeyPress(Key.H);
                bool keyboardPotion = state.Count("potion") == quickCount - 1 && state.Hp == Math.Min(state.MaxHp, quickHp + 3) && state.Get("potions_drunk").AsInt64() == quickDrunk + 1;
                state.Hp = state.MaxHp - 1; Press(GamepadButton.North);
                bool controllerPotion = state.Count("potion") == quickCount - 2 && state.Hp == state.MaxHp && state.Get("potions_drunk").AsInt64() == quickDrunk + 2;
                KeyPress(Key.H); Press(GamepadButton.North);
                bool noWaste = state.Hp == state.MaxHp && state.Count("potion") == quickCount - 2 && state.Get("potions_drunk").AsInt64() == quickDrunk + 2;
                state.Hp = Math.Max(1, state.MaxHp - 2);

                // Keyboard and mouse enter through the real event manager, then the same live UI handler as a player.
                KeyPress(Key.I); var panel = route.InventoryPanel; int beforeKeyboard = panel.SelectedIndex;
                KeyPress(Key.DownArrow); int afterKeyboard = panel.SelectedIndex;
                var wheel = Sample(new GamepadState(), new KeyboardState(), new MouseState { position = pointer, scroll = new Vector2(0, -120) }); Neutral();
                bool keyboardMouse = route.Modal == "inventory" && panel.Kind == "bag" && afterKeyboard == beforeKeyboard + InventoryPanel.Columns && panel.SelectedIndex == afterKeyboard + InventoryPanel.Columns && !wheel.ControllerActive && wheel.CursorVisible;
                yield return new WaitForEndOfFrame();
                check("inventory_native_keyboard_mouse_navigation", keyboardMouse && panel.SelectionVisible && Contains(panel.ViewportRect, panel.RenderedSelectedBounds));

                // Actual IMGUI search focus must protect ordinary P/I letters from pause/inventory shortcuts.
                panel.FocusSearch(); yield return new WaitForEndOfFrame(); yield return new WaitForEndOfFrame();
                bool searchFocused = panel.SearchEditing;
                string beforeSearch = FoundationJson.StringifyPlain(state.Get("inventory"));
                long menuPotions = state.Count("potion"), menuHp = state.Hp;
                KeyPress(Key.P); KeyPress(Key.I); KeyPress(Key.H); panel.SetQuery("potion");
                bool typedSearch = searchFocused && route.Modal == "inventory" && panel.SearchEditing && panel.Query == "potion" && beforeSearch == FoundationJson.StringifyPlain(state.Get("inventory"));
                bool searchPotionIgnored = state.Count("potion") == menuPotions && state.Hp == menuHp;
                KeyPress(Key.Escape);
                check("inventory_ui_search_shortcut_isolation", typedSearch && route.Modal == "");
                check("inventory_native_potion_hotkeys", keyboardPotion && controllerPotion && noWaste && searchPotionIgnored);

                // Shared filters are operated with actual shoulder, D-pad and face-button events.
                route.OpenStorage("home"); panel = route.InventoryPanel;
                Press(GamepadButton.RightShoulder); Press(GamepadButton.RightShoulder); Press(GamepadButton.DpadRight);
                bool categoryChanged = panel.FocusZone == 2 && panel.Category == 1 && panel.BagIds.Count > 0 && panel.BagIds.All(id => model.Category(id) == 1);
                Press(GamepadButton.RightShoulder); Press(GamepadButton.DpadRight);
                bool sortChanged = panel.FocusZone == 3 && model.Sort == 1;
                Press(GamepadButton.RightShoulder); Press(GamepadButton.South);
                bool favoriteChanged = panel.FocusZone == 4 && panel.FavoritesOnly && panel.BagIds.SequenceEqual(new[] { chosen }) && panel.StockIds.SequenceEqual(new[] { chosen });
                panel.SetQuery(chosen); bool sharedQuery = panel.BagIds.SequenceEqual(new[] { chosen }) && panel.StockIds.SequenceEqual(new[] { chosen });
                panel.SetQuery("__absent_inventory_ui_fixture__"); sharedQuery &= panel.BagIds.Count == 0 && panel.StockIds.Count == 0;
                check("inventory_ui_search_shared", sharedQuery);
                check("inventory_ui_category_sort_favorites", categoryChanged && sortChanged && favoriteChanged);

                // A held right stick is sampled across rendered frames; the viewport follows its selected row.
                route.OpenStorage("home"); panel = route.InventoryPanel; int start = panel.SelectedIndex, previous = start; bool visible = true, monotonic = true;
                for (int frame = 0; frame < 90; frame++)
                {
                    Pad(new GamepadState { rightStick = new Vector2(0, -.9f) });
                    yield return new WaitForEndOfFrame();
                    visible &= panel.SelectionVisible && Contains(panel.ViewportRect, panel.RenderedSelectedBounds);
                    monotonic &= panel.SelectedIndex >= previous && panel.FocusZone == 0; previous = panel.SelectedIndex;
                }
                Neutral(); bool scrolled = panel.SelectedIndex > start + 7 && panel.Scroll > 0 && panel.ActivePane == 0 && visible && monotonic;
                Pad(new GamepadState { rightStick = new Vector2(.9f, 0) }, .14); Neutral();
                bool switchedPane = panel.ActivePane == 1 && panel.SelectedIndex == 0 && panel.SelectionVisible;
                Press(GamepadButton.DpadDown); int chestIndex = panel.SelectedIndex; Press(GamepadButton.DpadLeft);
                bool retainedPane = panel.ActivePane == 0 && panel.SelectedIndex == previous;
                Press(GamepadButton.DpadRight); retainedPane &= panel.ActivePane == 1 && panel.SelectedIndex == chestIndex;
                yield return new WaitForEndOfFrame();
                check("inventory_native_sustained_right_stick_keeps_focus", scrolled);
                check("inventory_ui_right_stick_scroll", scrolled && switchedPane);
                check("inventory_ui_controller_selection_visible", visible && retainedPane && panel.SelectionVisible && Contains(panel.ViewportRect, panel.RenderedSelectedBounds));
                check("inventory_native_controller_navigation", switchedPane && retainedPane && panel.ControllerActive && route.Modal == "inventory");

                // Full-stack confirmation is reached by controller focus navigation; B only dismisses the overlay.
                route.OpenStorage("home"); panel = route.InventoryPanel; panel.SetQuery(chosen); panel.SwitchPane(0);
                for (int step = 0; step < 5; step++) Press(GamepadButton.RightShoulder);
                Press(GamepadButton.DpadRight); Press(GamepadButton.DpadRight);
                long bagBefore = state.Count(chosen), stockBefore = model.StockCount(chosen, "home");
                string beforeConfirmation = FoundationJson.StringifyPlain(state.Snapshot());
                Press(GamepadButton.South); bool requested = panel.ConfirmationVisible && panel.PendingAction == "stack" && panel.PendingQuantity == bagBefore;
                Press(GamepadButton.East); bool cancelled = !panel.ConfirmationVisible && route.Modal == "inventory" && beforeConfirmation == FoundationJson.StringifyPlain(state.Snapshot());
                Press(GamepadButton.South); Press(GamepadButton.South);
                bool confirmed = !panel.ConfirmationVisible && state.Count(chosen) == 0 && model.StockCount(chosen, "home") == stockBefore + bagBefore;
                check("inventory_ui_confirmation_cancel_atomic", requested && cancelled);
                check("inventory_ui_focus_actions", requested && confirmed && panel.FocusZone == 5);

                // The controller search alphabet is a real nested UI, without a mouse or a physical keyboard.
                route.OpenStorage("home"); panel = route.InventoryPanel;
                Press(GamepadButton.RightShoulder); Press(GamepadButton.South); bool lettersOpened = panel.LettersVisible;
                Press(GamepadButton.South); Press(GamepadButton.DpadRight); Press(GamepadButton.South);
                bool lettersTyped = panel.Query == "AB"; Press(GamepadButton.East);
                bool nestedKeyboard = lettersOpened && lettersTyped && !panel.LettersVisible && route.Modal == "inventory";

                // A moving mouse changes device ownership; a still-held stick must not regain it.
                panel.SetQuery(""); panel.SetFocus(0); panel.SwitchPane(0);
                var held = new GamepadState { rightStick = new Vector2(0, -.8f) };
                var ownedPad = Pad(held, .14);
                var ownedMouse = Sample(held, new KeyboardState(), new MouseState { position = pointer + new Vector2(8, 0), delta = new Vector2(8, 0) });
                int afterMouseSwitch = panel.SelectedIndex;
                var drift = Sample(held, new KeyboardState(), new MouseState { position = pointer + new Vector2(8, 0) }, .3);
                bool mouseStable = panel.SelectedIndex == afterMouseSwitch;
                Neutral(); var returnedPad = Pad(new GamepadState().WithButton(GamepadButton.DpadDown)); Neutral();
                bool ownerSwitch = ownedPad.ControllerActive && !ownedPad.CursorVisible && !ownedMouse.ControllerActive && ownedMouse.CursorVisible && !drift.ControllerActive && mouseStable && returnedPad.ControllerActive && !returnedPad.CursorVisible;
                check("inventory_native_input_owner_switch", ownerSwitch);
                check("inventory_ui_input_device_exclusivity", ownerSwitch && nestedKeyboard && panel.ControllerActive && devices.All(device => device.added && !device.native));

                // Four public native screenshots are always the normal 1152 by 648 player canvas.
                KeyPress(Key.DownArrow); route.CloseModal(); route.OpenInventory(); panel = route.InventoryPanel;
                int grape = panel.Ids.ToList().IndexOf("hs_grape"); if (grape >= 0) panel.SelectedIndex = grape;
                yield return new WaitForEndOfFrame(); Capture(Path.Combine(output, CaptureFiles[0]), 1152, 648); Captures++;
                route.CloseModal(); StandAt(world, route, stockTarget); route.OpenStorage("home"); panel = route.InventoryPanel; panel.SwitchPane(1);
                yield return new WaitForEndOfFrame(); Capture(Path.Combine(output, CaptureFiles[1]), 1152, 648); Captures++;
                bool homeCapacity = !panel.IsReadOnly && model.Stock("home").Entries.Count == 30 && InventoryModel.HomeSlots == 144 && InventoryModel.HomeCap == 999 && world.RoutePresentation.HomeStorageVisualOpen;
                route.CloseModal(); if (!Travel("coast_workshop")) throw new InvalidOperationException("The coastal storage UI could not be reached.");
                var coastal = route.Targets.First(CoastStorage); StandAt(world, route, coastal); route.OpenStorage("coast"); panel = route.InventoryPanel;
                yield return new WaitForEndOfFrame(); Capture(Path.Combine(output, CaptureFiles[2]), 1152, 648); Captures++;
                bool coastCapacity = !panel.IsReadOnly && model.Stock("coast").Entries.Count == 12 && InventoryModel.CoastSlots == 12 && InventoryModel.CoastCap == 99;
                check("inventory_ui_home_coast_capacities", homeCapacity && coastCapacity);
                route.CloseModal(); Travel("player_home"); stockTarget = route.Targets.First(target => target.Kind == "stock_chest"); StandAt(world, route, stockTarget); route.OpenStorage("home"); panel = route.InventoryPanel;
                Pad(new GamepadState { rightStick = new Vector2(0, -.9f) }); panel.SelectedIndex = Math.Min(19, panel.Ids.Count - 1);
                yield return new WaitForEndOfFrame(); Capture(Path.Combine(output, CaptureFiles[3]), 1152, 648); Captures++;

                // Private layout evidence exercises both languages at both actual window sizes.
                string layoutFolder = Path.Combine(output, "private-ui-layout"); Directory.CreateDirectory(layoutFolder);
                bool layouts = true;
                foreach (string locale in new[] { "nl", "en" }) foreach (int width in new[] { 1152, 960 })
                {
                    int height = width == 1152 ? 648 : 540; yield return Resolution(width, height); Preferences(locale);
                    KeyPress(Key.DownArrow); route.CloseModal(); route.OpenInventory(); panel = route.InventoryPanel;
                    int detail = panel.Ids.ToList().IndexOf("gear_pg_focus_plus"); if (detail >= 0) panel.SelectedIndex = detail;
                    yield return new WaitForEndOfFrame();
                    layouts &= panel.LayoutFits && panel.SelectionVisible && Contains(panel.ViewportRect, panel.RenderedSelectedBounds) && Screen.width == width && Screen.height == height;
                    Capture(Path.Combine(layoutFolder, "bag-" + locale + "-" + width + ".png"), width, height); PrivateLayoutCaptures++;
                    route.CloseModal(); route.OpenStorage("home"); panel = route.InventoryPanel; panel.SwitchPane(1); panel.SelectedIndex = Math.Min(15, panel.Ids.Count - 1);
                    yield return new WaitForEndOfFrame(); layouts &= panel.LayoutFits && panel.SelectionVisible && Contains(panel.ViewportRect, panel.RenderedSelectedBounds);
                    Capture(Path.Combine(layoutFolder, "home-" + locale + "-" + width + ".png"), width, height); PrivateLayoutCaptures++;
                }
                check("inventory_ui_responsive_layout", layouts && PrivateLayoutCaptures == 8);
                check("inventory_ui_four_native_captures", Captures == 4 && CaptureFiles.All(name => File.Exists(Path.Combine(output, name)) && new FileInfo(Path.Combine(output, name)).Length > 1000));
                route.CloseModal(); Preferences(originalPreferences.Locale); route.Save();
                yield return Resolution(1152, 648);
            }
            finally
            {
                route.CloseModal(); input?.Dispose(); foreach (var device in devices) if (device.added) InputSystem.RemoveDevice(device);
                InputSystem.settings.updateMode = originalMode; Cursor.visible = originalCursor;
                if (route.Persistence != null && route.Persistence.Preferences.Locale != originalPreferences.Locale) route.Persistence.SetPreferences(originalPreferences);
                if (Screen.width != 1152 || Screen.height != 648) Screen.SetResolution(1152, 648, FullScreenMode.Windowed);
            }
        }
    }
}
