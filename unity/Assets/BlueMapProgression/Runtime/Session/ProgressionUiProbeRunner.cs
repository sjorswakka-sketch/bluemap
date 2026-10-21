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
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace BlueMapMigration.Progression
{
    /// <summary>Genuine native device events and rendered character UI; uses only the caller's isolated synthetic adventure.</summary>
    public static class ProgressionUiProbeRunner
    {
        public static int NativeSamples { get; private set; }
        public static int Captures { get; private set; }
        public static int PrivateLayoutCaptures { get; private set; }
        public static readonly string[] CaptureFiles = { "screenshot-progression-overview.png", "screenshot-progression-equipment.png", "screenshot-progression-appearance.png", "screenshot-progression-upgrade.png" };
        static FoundationValue I(long value) => FoundationValue.Integer(value);
        static FoundationValue S(string value) => FoundationValue.StringValue(value);
        static FoundationValue Empty() => FoundationValue.Object(new Dictionary<string, FoundationValue>());
        static string Json(FoundationValue value) => FoundationJson.StringifyPlain(value);
        static string Spawn(FoundationWorldSnapshot map) => map.Arrivals.FirstOrDefault(a => a.Name == "start")?.Name ?? map.Arrivals[0].Name;
        static bool Contains(Rect outer, Rect inner) => inner.width > 0 && inner.height > 0 && inner.xMin >= outer.xMin - .5f && inner.yMin >= outer.yMin - .5f && inner.xMax <= outer.xMax + .5f && inner.yMax <= outer.yMax + .5f;
        static IEnumerator Resolution(int width, int height)
        {
            if (Screen.width == width && Screen.height == height) yield break;
            Screen.SetResolution(width, height, FullScreenMode.Windowed);
            for (int frame = 0; frame < 30; frame++) { yield return null; if (Screen.width == width && Screen.height == height) yield break; }
            throw new InvalidOperationException("The native character UI viewport resize was not applied.");
        }
        static void Capture(string path, int width, int height)
        {
            if (File.Exists(path)) throw new IOException("Fresh native character UI evidence is required: " + Path.GetFileName(path));
            Texture2D image = ScreenCapture.CaptureScreenshotAsTexture();
            try
            {
                if (image == null || image.width != width || image.height != height) throw new InvalidOperationException("Native character UI capture dimensions differ.");
                File.WriteAllBytes(path, image.EncodeToPNG());
            }
            finally { if (image != null) UnityEngine.Object.Destroy(image); }
        }
        public static IEnumerator Run(BuildIdentity identity, string output, PlayerWorld world, RouteWorldController route, Phase6Catalog catalog, Action<string, bool> check)
        {
            if (identity == null || world == null || route == null || catalog == null || check == null) throw new ArgumentNullException("Native character UI arguments are required.");
            if (!route.Running || route.Persistence == null) throw new InvalidOperationException("An isolated synthetic adventure is required.");
            NativeSamples = Captures = PrivateLayoutCaptures = 0;
            var originalMode = InputSystem.settings.updateMode; bool originalCursor = Cursor.visible;
            LegacyPreferences originalPreferences = route.Persistence.Preferences;
            var devices = new List<InputDevice>(); PlayerInputSource input = null;
            try
            {
                InputSystem.settings.updateMode = InputSettings.UpdateMode.ProcessEventsManually;
                var keyboard = InputSystem.AddDevice<Keyboard>("Phase13CharacterKeyboard"); devices.Add(keyboard);
                var mouse = InputSystem.AddDevice<Mouse>("Phase13CharacterMouse"); devices.Add(mouse);
                var gamepad = InputSystem.AddDevice<Gamepad>("Phase13CharacterGamepad"); devices.Add(gamepad);
                input = new PlayerInputSource(devices); input.SetContext(true, true);
                Vector2 pointer = new Vector2(400, 330);
                InputFrame Sample(GamepadState pad, KeyboardState keys, MouseState mouseState, double delta = 1.0 / 60)
                {
                    InputSystem.QueueStateEvent(keyboard, keys); InputSystem.QueueStateEvent(mouse, mouseState); InputSystem.QueueStateEvent(gamepad, pad); InputSystem.Update();
                    input.SetContext(true, true); var frame = input.Read(); NativeSamples++; route.Tick(delta); route.HandleFrame(frame); return frame;
                }
                InputFrame Neutral(double delta = 1.0 / 60) => Sample(new GamepadState(), new KeyboardState(), new MouseState { position = pointer }, delta);
                InputFrame Pad(GamepadState value, double delta = 1.0 / 60) => Sample(value, new KeyboardState(), new MouseState { position = pointer }, delta);
                void Press(GamepadButton button) { Neutral(); Pad(new GamepadState().WithButton(button)); Neutral(); }
                void KeyPress(Key key) { Neutral(); Sample(new GamepadState(), new KeyboardState(key), new MouseState { position = pointer }); Neutral(); }
                void Travel(string map)
                { route.CloseModal(); if (!route.TryTravel(map, Spawn(route.Session.Repository.Read(map)))) throw new InvalidOperationException("Synthetic character UI travel failed: " + map); }
                void Preferences(string locale)
                {
                    var old = route.Persistence.Preferences;
                    if (!route.Persistence.SetPreferences(new LegacyPreferences(locale, old.Muted, old.MusicVolume, old.SfxVolume))) throw new IOException("Synthetic character UI language failed.");
                    route.UpdateProgressionContext();
                }
                void AtGreta()
                {
                    Travel("smithy"); var greta = route.Targets.First(t => t.Kind == "npc" && t.Id == "greta");
                    Vector2 point = greta.Position + new Vector2(0, 28);
                    if (!route.Access.SpawnFits(route.Session.Current, point)) throw new InvalidOperationException("The actual Greta standing position is blocked.");
                    world.Teleport(point); world.Step(0, new MotionInput { Direction = Vector2.zero }); route.Tick(0); route.UpdateProgressionContext();
                }

                yield return Resolution(1152, 648); Preferences("nl"); Travel("player_home");
                var model = route.Progression; var state = model.State;
                var bag = state.Get("inventory").Entries.ToDictionary(row => row.Key.AsString(), row => row.Value, StringComparer.Ordinal);
                foreach (var row in model.Catalogs.Require("gear").Entries.Concat(model.Catalogs.Require("clothing").Entries)) bag[row.Key.AsString()] = I(1);
                bag.Remove("gear_bronze_helm"); bag["gel"] = I(25); bag["shard"] = I(5); bag["boots"] = I(1);
                state.Set("inventory", FoundationValue.Object(bag)); state.Set("equipment", Empty()); state.Set("clothing", Empty());
                state.Set("hero_xp", I(137)); state.Set("weapon", S("wood")); state.Coins = 500; model.Equip("gear_cloth_hood");
                model.SetGender("m"); model.SetHair(model.HairIds("m")[2]); model.SetHairColor(4); model.SetEyes(model.EyeIds[2]); model.SetEyeColor(4);
                world.RefreshRouteState(); route.UpdateProgressionContext();

                // The real inventory focus route is how a controller player discovers the character ledger.
                route.OpenInventory(); route.InventoryPanel.SetFocus(10); Press(GamepadButton.South);
                var panel = route.ProgressionPanel;
                yield return new WaitForEndOfFrame();
                bool entered = route.Modal == "progression" && panel.Tab == "overview" && panel.IsOpen && state.Paused;
                KeyPress(Key.I); bool backpack = route.Modal == "inventory"; route.InventoryPanel.SetFocus(10); Press(GamepadButton.South);
                check("progression_ui_character_entry", entered && backpack && route.Modal == "progression");
                yield return new WaitForEndOfFrame();
                var progress = model.Progress;
                check("progression_ui_stats_readable", progress.Level == 2 && progress.Current == 87 && progress.Needed == 100 && progress.NextReward == 15 && panel.SkillIds.Count == model.Catalogs.Require("skills").Entries.Count && panel.LayoutFits && Contains(panel.ViewportRect, panel.RenderedSelectedBounds) && panel.PreviewDraws == 1);

                // Every selectable source alternative is read without creating ownership or altering the worn set.
                panel.ChangeTab("equipment"); string beforeBrowse = Json(state.Snapshot()); bool slots = panel.GearSlots.SequenceEqual(model.EquipmentSlotIds.Concat(new[] { "weapon", "boots" })); int alternatives = 0;
                for (int slot = 0; slot < panel.GearSlots.Count; slot++)
                {
                    panel.SelectSlot(slot); alternatives += panel.Alternatives.Count;
                    for (int candidate = 0; candidate < panel.Alternatives.Count; candidate++) { panel.SelectCandidate(candidate); model.ComparisonText(panel.Candidate); }
                }
                bool browsePure = beforeBrowse == Json(state.Snapshot());
                panel.SelectSlot(panel.GearSlots.ToList().IndexOf("head")); panel.SelectCandidate(panel.Alternatives.ToList().IndexOf("gear_bronze_helm"));
                Press(GamepadButton.South); Press(GamepadButton.South);
                bool noUnowned = !panel.CanEquip && model.Equipped("head") == "gear_cloth_hood" && state.Count("gear_bronze_helm") == 0 && beforeBrowse == Json(state.Snapshot());
                yield return new WaitForEndOfFrame();
                check("progression_ui_all_slots", slots && panel.GearSlots.Count == 7 && alternatives == model.Catalogs.Require("gear").Entries.Count && panel.PreviewDraws == 3);
                check("progression_ui_browsing_is_readonly", browsePure && noUnowned);

                // Two-stage A selection makes equipment changes explicit; B returns to slots before it closes.
                panel.SelectSlot(panel.GearSlots.ToList().IndexOf("chest")); panel.SelectCandidate(panel.Alternatives.ToList().IndexOf("gear_iron_armor"));
                world.Motor.Stamina.Stamina = 7; string beforeEquip = model.Equipped("chest"), comparison = model.ComparisonText(panel.Candidate);
                Press(GamepadButton.South); bool explicitAction = beforeEquip == model.Equipped("chest") && panel.Zone == 2;
                Press(GamepadButton.South); bool equipped = model.Equipped("chest") == "gear_iron_armor" && world.Motor.Stamina.Stamina == 7 && comparison != "";
                Press(GamepadButton.East); bool nestedBack = panel.Zone == 0 && route.Modal == "progression";
                check("progression_ui_compare_and_confirm", explicitAction && equipped && nestedBack && world.Motor.Stamina.Capacity == 100 + model.Bonus("stamina_max"));

                // Held right-stick input runs across real rendered frames and keeps source selection in the viewport.
                panel.ChangeTab("overview"); panel.SelectOverview(0); int previous = 0; bool visible = true, monotonic = true;
                for (int frame = 0; frame < 90; frame++)
                {
                    Pad(new GamepadState { rightStick = new Vector2(0, -.9f) }); yield return new WaitForEndOfFrame();
                    visible &= panel.SelectionVisible && Contains(panel.ViewportRect, panel.RenderedSelectedBounds); monotonic &= panel.SelectedOverview >= previous; previous = panel.SelectedOverview;
                }
                Neutral(); bool browsed = panel.SelectedOverview == 3 + panel.SkillIds.Count && monotonic;
                panel.SelectOverview(3); Press(GamepadButton.South); yield return new WaitForEndOfFrame();
                float beforeScroll = panel.DetailsScroll;
                for (int frame = 0; frame < 90; frame++)
                {
                    Pad(new GamepadState { rightStick = new Vector2(0, -.9f) }); yield return new WaitForEndOfFrame();
                    visible &= panel.SelectionVisible && Contains(panel.ViewportRect, panel.RenderedSelectedBounds) && panel.Zone == 3;
                }
                Neutral(); bool scrolled = panel.MaxDetailsScroll > 0 && panel.DetailsScroll > beforeScroll && panel.DetailsScroll <= panel.MaxDetailsScroll + .5f;
                check("progression_ui_controller_selection_visible", visible && browsed && panel.ControllerActive);
                check("progression_ui_sustained_right_stick", browsed && scrolled && visible && NativeSamples >= 180);

                // A moving mouse takes ownership once; an already-held stick never immediately steals it back.
                panel.ChangeTab("appearance"); panel.SelectAppearanceRow(0);
                var held = new GamepadState { rightStick = new Vector2(0, -.8f) };
                var padOwned = Pad(held, .14);
                var mouseOwned = Sample(held, new KeyboardState(), new MouseState { position = pointer + new Vector2(8, 0), delta = new Vector2(8, 0) });
                int afterMouse = panel.SelectedAppearanceRow;
                var drift = Sample(held, new KeyboardState(), new MouseState { position = pointer + new Vector2(8, 0) }, .3);
                bool noSteal = panel.SelectedAppearanceRow == afterMouse;
                Neutral(); var returnedPad = Pad(new GamepadState().WithButton(GamepadButton.DpadDown)); Neutral();
                check("progression_ui_input_owner_switch", padOwned.ControllerActive && !padOwned.CursorVisible && !mouseOwned.ControllerActive && mouseOwned.CursorVisible && !drift.ControllerActive && noSteal && returnedPad.ControllerActive && !returnedPad.CursorVisible && devices.All(d => d.added && !d.native));

                // Appearance follows source semantics: row navigation is pure, arrows apply, and dyes are nested.
                string cosmeticBag = Json(state.Get("inventory")), cosmeticGear = Json(state.Get("equipment")); double cosmeticArmor = model.Bonus("armor");
                panel.SelectAppearanceRow(0); string oldGender = state.Get("appearance").Require("gender").AsString(); Press(GamepadButton.DpadRight);
                bool appearance = oldGender != state.Get("appearance").Require("gender").AsString();
                panel.SelectAppearanceRow(1); string oldHair = state.Get("appearance").Require("hair").AsString(); Press(GamepadButton.DpadRight); appearance &= oldHair != state.Get("appearance").Require("hair").AsString();
                panel.SelectAppearanceRow(2); long oldColor = state.Get("appearance").Require("hair_color").AsInt64(); Press(GamepadButton.DpadRight); appearance &= oldColor != state.Get("appearance").Require("hair_color").AsInt64();
                panel.SelectAppearanceRow(3); string oldEyes = state.Get("appearance").Require("eyes").AsString(); Press(GamepadButton.DpadRight); appearance &= oldEyes != state.Get("appearance").Require("eyes").AsString();
                panel.SelectAppearanceRow(4); long oldEyeColor = state.Get("appearance").Require("eye_color").AsInt64(); Press(GamepadButton.DpadRight); appearance &= oldEyeColor != state.Get("appearance").Require("eye_color").AsInt64();
                bool allClothing = true;
                for (int slot = 0; slot < model.ClothingSlotIds.Count; slot++)
                {
                    panel.SelectAppearanceRow(5 + slot); string beforeRow = Json(state.Get("clothing")); yield return new WaitForEndOfFrame();
                    allClothing &= beforeRow == Json(state.Get("clothing")); Press(GamepadButton.DpadRight);
                    allClothing &= model.Worn(model.ClothingSlotIds[slot]).Entries.Count > 0;
                }
                string dyeSlot = model.ClothingSlotIds.Last(); Press(GamepadButton.South); bool dyeOpened = panel.DyeMode;
                long dyeBefore = model.Worn(dyeSlot).Require("dye").AsInt64(); Press(GamepadButton.DpadRight); bool dyed = model.Worn(dyeSlot).Require("dye").AsInt64() != dyeBefore;
                Press(GamepadButton.East); bool dyeClosed = !panel.DyeMode && route.Modal == "progression";
                yield return new WaitForEndOfFrame();
                check("progression_ui_hair_clothing_layers", appearance && allClothing && dyeOpened && dyed && dyeClosed && panel.PreviewDraws == 3 && model.GenderIds.Sum(g => model.HairIds(g).Count) == 90 && model.Catalogs.Require("clothing").Entries.Count == 24 && cosmeticBag == Json(state.Get("inventory")) && cosmeticGear == Json(state.Get("equipment")) && cosmeticArmor == model.Bonus("armor") && world.AvatarLayers("down").All(layer => catalog.GetSprite(layer.Id) != null));

                // Remote screens remain guides; actual forging rechecks the exact physical context and costs.
                route.OpenProgression("upgrade"); panel = route.ProgressionPanel; panel.SelectUpgrade(0); string remote = Json(state.Snapshot());
                Press(GamepadButton.South); Press(GamepadButton.South); bool remoteDenied = !panel.ConfirmationVisible && panel.UpgradeReason != "" && remote == Json(state.Snapshot());
                AtGreta(); route.OpenProgression("upgrade"); panel = route.ProgressionPanel; panel.SelectUpgrade(0);
                long coins = state.Coins, gel = state.Count("gel"); string beforeConfirmation = Json(state.Snapshot());
                Press(GamepadButton.South); Press(GamepadButton.South); bool pending = panel.ConfirmationVisible && beforeConfirmation == Json(state.Snapshot());
                Press(GamepadButton.East); bool cancelled = !panel.ConfirmationVisible && route.Modal == "progression" && beforeConfirmation == Json(state.Snapshot());
                Press(GamepadButton.South); Press(GamepadButton.South); bool upgraded = !panel.ConfirmationVisible && state.Weapon == "iron" && state.Coins == coins - 40 && state.Count("gel") == gel - 5;
                check("progression_ui_upgrade_confirmation", remoteDenied && pending && cancelled && upgraded && panel.UpgradeIds.Count == 3);

                // The four public pictures are the actual player UI at the main window size.
                KeyPress(Key.DownArrow); route.OpenProgression("overview"); panel = route.ProgressionPanel; panel.SelectOverview(0);
                yield return new WaitForEndOfFrame(); Capture(Path.Combine(output, CaptureFiles[0]), 1152, 648); Captures++;
                KeyPress(Key.PageDown); panel.SelectSlot(panel.GearSlots.ToList().IndexOf("head")); panel.SelectCandidate(panel.Alternatives.ToList().IndexOf("gear_bronze_helm"));
                yield return new WaitForEndOfFrame(); Capture(Path.Combine(output, CaptureFiles[1]), 1152, 648); Captures++;
                KeyPress(Key.PageDown); model.Unwear("hat"); model.Wear("cloth_cape"); model.Wear("cloth_tunic"); model.Dye("top", 8); panel.SelectAppearanceRow(1);
                yield return new WaitForEndOfFrame(); Capture(Path.Combine(output, CaptureFiles[2]), 1152, 648); Captures++;
                KeyPress(Key.PageDown); panel.SelectUpgrade(0);
                yield return new WaitForEndOfFrame(); Capture(Path.Combine(output, CaptureFiles[3]), 1152, 648); Captures++;

                // Private visual evidence covers source-heavy pages in both languages and real window sizes.
                string layoutFolder = Path.Combine(output, "private-progression-layout"); Directory.CreateDirectory(layoutFolder); bool layouts = true;
                foreach (string locale in new[] { "nl", "en" }) foreach (int width in new[] { 1152, 960 })
                {
                    int height = width == 1152 ? 648 : 540; yield return Resolution(width, height); Preferences(locale);
                    route.OpenProgression("equipment"); panel = route.ProgressionPanel; panel.SelectSlot(panel.GearSlots.ToList().IndexOf("neck")); panel.SelectCandidate(panel.Alternatives.Count - 1);
                    yield return new WaitForEndOfFrame(); layouts &= panel.LayoutFits && panel.SelectionVisible && Contains(panel.ViewportRect, panel.RenderedSelectedBounds) && panel.PreviewDraws == 3 && Screen.width == width && Screen.height == height;
                    Capture(Path.Combine(layoutFolder, "equipment-" + locale + "-" + width + ".png"), width, height); PrivateLayoutCaptures++;
                    route.OpenProgression("appearance"); panel = route.ProgressionPanel; panel.SelectAppearanceRow(9);
                    yield return new WaitForEndOfFrame(); layouts &= panel.LayoutFits && panel.SelectionVisible && Contains(panel.ViewportRect, panel.RenderedSelectedBounds) && panel.PreviewDraws == 3;
                    Capture(Path.Combine(layoutFolder, "appearance-" + locale + "-" + width + ".png"), width, height); PrivateLayoutCaptures++;
                }
                check("progression_ui_responsive_layout", layouts && PrivateLayoutCaptures == 8);
                check("progression_ui_four_native_captures", Captures == 4 && CaptureFiles.All(name => File.Exists(Path.Combine(output, name)) && new FileInfo(Path.Combine(output, name)).Length > 1000));
                route.CloseModal(); Preferences(originalPreferences.Locale); route.Save(); yield return Resolution(1152, 648);
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
