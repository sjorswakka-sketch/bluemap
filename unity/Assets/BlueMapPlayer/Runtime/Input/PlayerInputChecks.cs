using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Controls;
using UnityEngine.InputSystem.LowLevel;

namespace BlueMapMigration.Player
{
    /// <summary>Exercise the real package event queue; no fabricated InputFrame is accepted as input proof.</summary>
    public static class PlayerInputChecks
    {
        public static int BindingCases { get; private set; }
        public static int VectorCases { get; private set; }
        public static string[] HardwareInventory { get; private set; } = Array.Empty<string>();

        public static void Verify(Action<string, bool> check)
        {
            HardwareInventory = PlayerInputSource.ConnectedDeviceInventory();
            BindingCases = 0; VectorCases = 0;
            bool oldCursor = Cursor.visible;
            bool callbackErrors = false;
            Application.LogCallback observe = (message, stack, type) =>
            { if (type == LogType.Exception || type == LogType.Error || type == LogType.Assert) callbackErrors = true; };
            Application.logMessageReceived += observe;
            var oldMode = InputSystem.settings.updateMode;
            var owned = new List<InputDevice>();
            PlayerInputSource source = null;
            try
            {
                InputSystem.settings.updateMode = InputSettings.UpdateMode.ProcessEventsManually;
                var keyboard = InputSystem.AddDevice<Keyboard>("Phase8VerificationKeyboard"); owned.Add(keyboard);
                var mouse = InputSystem.AddDevice<Mouse>("Phase8VerificationMouse"); owned.Add(mouse);
                var pad = InputSystem.AddDevice<Gamepad>("Phase8VerificationGamepad"); owned.Add(pad);
                var pad2 = InputSystem.AddDevice<Gamepad>("Phase8VerificationGamepad2"); owned.Add(pad2);
                source = new PlayerInputSource(owned);
                check("player_input_real_package_virtual_devices", typeof(InputSystem).Assembly.GetName().Name == "Unity.InputSystem" && owned.All(d => d.added && !d.native));

                InputFrame Neutral()
                {
                    InputSystem.QueueStateEvent(keyboard, new KeyboardState());
                    InputSystem.QueueStateEvent(mouse, new MouseState());
                    InputSystem.QueueStateEvent(pad, new GamepadState());
                    InputSystem.QueueStateEvent(pad2, new GamepadState());
                    InputSystem.Update(); return source.Read();
                }
                InputFrame Keys(params Key[] keys)
                {
                    InputSystem.QueueStateEvent(keyboard, new KeyboardState(keys)); InputSystem.Update(); return source.Read();
                }
                InputFrame Pad(GamepadState state)
                {
                    InputSystem.QueueStateEvent(pad, state); InputSystem.Update(); return source.Read();
                }
                InputFrame Mouse(MouseState state)
                {
                    InputSystem.QueueStateEvent(mouse, state); InputSystem.Update(); return source.Read();
                }

                bool bindingsExact = true, releasesExact = true;
                foreach (var action in source.Oracle.defaults)
                    foreach (var binding in source.Bindings(action.id))
                    {
                        Neutral();
                        InputFrame result;
                        if (binding.kind == "key")
                        {
                            var control = InputControlPath.TryFindControl(keyboard, binding.path) as KeyControl;
                            if (binding.keyName == "Ctrl") control = keyboard.leftCtrlKey;
                            if (binding.keyName == "Shift") control = keyboard.leftShiftKey;
                            if (binding.keyName == "Alt") control = keyboard.leftAltKey;
                            if (control == null) { bindingsExact = false; continue; }
                            var keys = new List<Key> { control.keyCode };
                            if (binding.shift) keys.Add(Key.LeftShift);
                            if (binding.ctrl) keys.Add(Key.LeftCtrl);
                            if (binding.alt) keys.Add(Key.LeftAlt);
                            if (binding.meta) keys.Add(Key.LeftMeta);
                            result = Keys(keys.ToArray());
                        }
                        else if (binding.kind == "mouse")
                        {
                            var state = new MouseState { position = new Vector2(150, 200) };
                            state = state.WithButton(binding.code == 1 ? MouseButton.Left : binding.code == 2 ? MouseButton.Right : MouseButton.Middle);
                            result = Mouse(state);
                        }
                        else if (binding.kind == "button")
                        {
                            var buttons = new[] { GamepadButton.South, GamepadButton.East, GamepadButton.West, GamepadButton.North,
                                GamepadButton.Select, GamepadButton.Select, GamepadButton.Start, GamepadButton.LeftStick,
                                GamepadButton.RightStick, GamepadButton.LeftShoulder, GamepadButton.RightShoulder,
                                GamepadButton.DpadUp, GamepadButton.DpadDown, GamepadButton.DpadLeft, GamepadButton.DpadRight };
                            result = Pad(new GamepadState().WithButton(buttons[binding.code]));
                        }
                        else
                        {
                            var state = new GamepadState();
                            switch (binding.code)
                            {
                                case 0: state.leftStick = new Vector2(binding.direction, 0); break;
                                case 1: state.leftStick = new Vector2(0, binding.direction); break;
                                case 2: state.rightStick = new Vector2(binding.direction, 0); break;
                                case 3: state.rightStick = new Vector2(0, binding.direction); break;
                                case 4: state.leftTrigger = 1; break;
                                case 5: state.rightTrigger = 1; break;
                            }
                            result = Pad(state);
                        }
                        bindingsExact &= result.Held(action.id) && result.Pressed(action.id) && result.ControllerActive == (binding.category == "controller");
                        BindingCases++;
                        var released = Neutral();
                        releasesExact &= released.Released(action.id) && !released.Held(action.id);
                    }
                check("player_input_all_36_source_actions_native_bindings", bindingsExact && source.ActionCount == 36 && BindingCases == 86);
                check("player_input_all_binding_releases_no_latched_action", releasesExact);

                Neutral(); var northEast = Keys(Key.W, Key.D);
                check("player_input_keyboard_diagonal_normalized", Near(northEast.Move, new Vector2(0.70710677f, -0.70710677f)));
                var opposite = Keys(Key.W, Key.A, Key.S, Key.D);
                check("player_input_opposite_directions_cancel", opposite.Move == Vector2.zero);
                Neutral();
                var sprint = Keys(Key.LeftCtrl); var roll = Keys(Key.LeftShift);
                check("player_input_original_ctrl_sprint_shift_roll", sprint.SprintHeld && !sprint.RollPressed && roll.RollPressed && !roll.SprintHeld);
                Neutral(); var rightSprint = Keys(Key.RightCtrl); var rightRoll = Keys(Key.RightShift);
                check("player_input_both_modifier_sides_preserved", rightSprint.SprintHeld && rightRoll.RollPressed);
                bool vectors = true;
                foreach (var row in source.Oracle.vectors)
                {
                    var actual = PlayerInputSource.CircularDeadzone(new Vector2(row.raw[0], row.raw[1]), row.deadzone);
                    vectors &= Near(actual, new Vector2(row.expected[0], row.expected[1])); VectorCases++;
                }
                check("player_input_16_original_circular_deadzone_vectors", vectors && VectorCases == 16);

                Neutral(); var keyboardMove = Keys(Key.D);
                var drift = Pad(new GamepadState { leftStick = new Vector2(0.3f, 0) });
                var switched = Pad(new GamepadState { leftStick = new Vector2(0.7f, 0) });
                var quietMouse = Mouse(new MouseState { delta = Vector2.one });
                check("player_input_switch_threshold_and_mouse_drift", !keyboardMove.ControllerActive && !drift.ControllerActive && switched.ControllerActive && quietMouse.ControllerActive && quietMouse.Move.x > 0);
                var mouseMove = Mouse(new MouseState { delta = new Vector2(3, 0), position = new Vector2(500, 320) });
                var heldPad = Pad(new GamepadState { leftStick = new Vector2(0.7f, 0) });
                check("player_input_held_controller_does_not_steal_mouse", !mouseMove.ControllerActive && mouseMove.MouseAimActive && mouseMove.Move == Vector2.zero && !heldPad.ControllerActive && heldPad.Move == Vector2.zero);
                var heldKey = Keys(Key.D); // D was physically held before the category switch.
                bool noGhost = heldKey.Move == Vector2.zero;
                Keys(); var freshKey = Keys(Key.D);
                check("player_input_old_held_keyboard_requires_fresh_press", noGhost && freshKey.Move.x == 1);

                Neutral(); Pad(new GamepadState().WithButton(GamepadButton.South));
                var mouseAttack = Mouse(new MouseState().WithButton(MouseButton.Left));
                var afterPress = source.Read();
                var mouseRelease = Mouse(new MouseState());
                check("player_input_switching_press_works_once_and_releases", mouseAttack.Pressed("attack") && mouseAttack.Held("attack") && !afterPress.Pressed("attack") && mouseRelease.Released("attack") && !mouseRelease.Held("attack"));
                Neutral(); var wheel = Mouse(new MouseState { scroll = new Vector2(0, -120) });
                check("player_input_wheel_activates_mouse_and_scrolls", !wheel.ControllerActive && wheel.MouseAimActive && wheel.UiScroll.y == -120);
                Neutral(); var aim = Pad(new GamepadState { rightStick = new Vector2(-0.8f, 0.6f) });
                check("player_input_right_stick_aim_and_ui_scroll", aim.ControllerActive && Near(aim.Aim, new Vector2(-0.8f, -0.6f)) && aim.UiScroll == aim.Aim);

                source.SetContext(true, false); bool playHidden = !source.CursorVisible;
                source.SetContext(true, true); bool controllerHidden = !source.CursorVisible;
                Keys(Key.F12); bool menuVisible = source.CursorVisible;
                source.SetContext(false, false); bool titleVisible = source.CursorVisible;
                check("player_input_original_cursor_context_policy", playHidden && controllerHidden && menuVisible && titleVisible);

                Neutral(); Pad(new GamepadState().WithButton(GamepadButton.West));
                InputSystem.RemoveDevice(pad); InputSystem.Update(); var removed = source.Read();
                bool disconnect = !removed.ControllerActive && !removed.Held("attack");
                InputSystem.AddDevice(pad); Neutral();
                var reconnect = Pad(new GamepadState().WithButton(GamepadButton.West));
                check("player_input_controller_disconnect_reconnect", disconnect && reconnect.ControllerActive && reconnect.Pressed("attack"));
                InputSystem.QueueStateEvent(pad2, new GamepadState().WithButton(GamepadButton.North)); InputSystem.Update();
                var secondPad = source.Read();
                check("player_input_one_selected_gamepad", secondPad.ControllerDeviceId == pad2.deviceId && secondPad.Pressed("potion") && !secondPad.Held("attack"));

                Neutral(); Keys(Key.D); source.SetFocused(false); var lostFocus = source.Read();
                source.SetFocused(true); InputSystem.Update(); var resumed = source.Read();
                Keys(); var newFocusPress = Keys(Key.D);
                check("player_input_focus_loss_releases_without_ghost_resume", lostFocus.Move == Vector2.zero && resumed.Move == Vector2.zero && newFocusPress.Move.x == 1);

                Neutral(); string swap = source.Rebind("attack", "keyboard", "<Keyboard>/f");
                var swapAttack = Keys(Key.F); Keys(); var swapBow = Keys(Key.J);
                bool swapWorks = swap == "" && swapAttack.Pressed("attack") && !swapAttack.Held("bow") && swapBow.Pressed("bow") && !swapBow.Held("attack");
                bool reserves = source.Rebind("attack", "keyboard", "<Keyboard>/escape") != ""
                    && source.Rebind("attack", "controller", "<Gamepad>/rightStick/x") != ""
                    && source.Rebind("attack", "keyboard", "<Keyboard>/notARealKey") != ""
                    && source.Rebind("homestead", "controller", "<Gamepad>/buttonWest") != "";
                source.ResetBindings("keyboard"); Keys(); var restored = Keys(Key.J);
                check("player_input_rebind_swap_reservations_and_reset", swapWorks && reserves && restored.Pressed("attack") && !restored.Held("bow"));
                Neutral(); source.BeginRebindCapture("homestead", "keyboard"); Keys(Key.O);
                bool captured = !source.Capturing && source.CaptureMessage == "" && source.Bindings("homestead").Any(b => b.path == "<Keyboard>/o");
                source.BeginRebindCapture("homestead", "keyboard"); Keys(Key.Escape);
                bool cancelled = !source.Capturing; source.ResetBindings("keyboard");
                check("player_input_real_event_rebind_capture_and_cancel", captured && cancelled && source.Bindings("homestead").Any(b => b.path == "<Keyboard>/u"));
                check("player_input_no_real_hardware_or_save_claim", owned.All(d => !d.native) && HardwareInventory != null);
            }
            finally
            {
                source?.Dispose();
                foreach (var device in owned) if (device.added) InputSystem.RemoveDevice(device);
                InputSystem.settings.updateMode = oldMode;
                Cursor.visible = oldCursor;
                Application.logMessageReceived -= observe;
                check("player_input_device_lifecycle_no_callback_errors", !callbackErrors);
            }
        }
        static bool Near(Vector2 a, Vector2 b) => (a - b).sqrMagnitude < 0.0000000001f;
    }
}

