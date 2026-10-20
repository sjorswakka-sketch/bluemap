using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Controls;
using UnityEngine.InputSystem.LowLevel;

namespace BlueMapMigration.Player
{
    /// <summary>One consumed input snapshot. Move and Aim use original Godot coordinates (+Y south).</summary>
    public sealed class InputFrame
    {
        public Vector2 Move { get; internal set; }
        public Vector2 Aim { get; internal set; }
        public Vector2 MousePosition { get; internal set; }
        public Vector2 UiScroll { get; internal set; }
        public bool MouseAimActive { get; internal set; }
        public bool ControllerActive { get; internal set; }
        public int ControllerDeviceId { get; internal set; }
        public bool CursorVisible { get; internal set; }
        internal readonly HashSet<string> down = new HashSet<string>(StringComparer.Ordinal);
        internal readonly HashSet<string> pressed = new HashSet<string>(StringComparer.Ordinal);
        internal readonly HashSet<string> released = new HashSet<string>(StringComparer.Ordinal);
        public bool Held(string id) => down.Contains(id);
        public bool Pressed(string id) => pressed.Contains(id);
        public bool Released(string id) => released.Contains(id);
        public bool SprintHeld => Held("sprint");
        public bool RollPressed => Pressed("dodge");
    }

    [Serializable] public sealed class InputOracle
    {
        public string schema, engineVersion;
        public float switchDeadzone, aimDeadzone, mouseSwitchPixels;
        public InputActionSpec[] defaults;
        public InputVectorCase[] vectors;
    }
    [Serializable] public sealed class InputVectorCase { public float[] raw, expected; public float deadzone; }
    [Serializable] public sealed class InputActionSpec
    {
        public string id, label; public bool rebindable; public float deadzone; public InputBindingSpec[] bindings;
    }
    [Serializable] public sealed class InputBindingSpec
    {
        public string category, kind, keyName, path; public int code; public float direction;
        public bool shift, ctrl, alt, meta;
        public InputBindingSpec Copy() => (InputBindingSpec)MemberwiseClone();
    }

    /// <summary>
    /// Real Unity Input System devices/events, with the original game's category arbitration.
    /// Sources are read unprocessed: Godot circular deadzones are applied once, not twice.
    /// Rebindings are memory-only until phase 9's explicitly isolated save adapter exists.
    /// </summary>
    public sealed class PlayerInputSource : IDisposable
    {
        public const string OracleResource = "BlueMapPlayerInputOracle";
        public readonly InputOracle Oracle;
        readonly Dictionary<string, InputActionSpec> actions;
        readonly Dictionary<string, InputBindingSpec[]> original = new Dictionary<string, InputBindingSpec[]>(StringComparer.Ordinal);
        readonly HashSet<string> down = new HashSet<string>(StringComparer.Ordinal);
        readonly HashSet<string> pressed = new HashSet<string>(StringComparer.Ordinal);
        readonly HashSet<string> released = new HashSet<string>(StringComparer.Ordinal);
        readonly HashSet<InputControl> blocked = new HashSet<InputControl>();
        readonly HashSet<int> allowedDevices;
        readonly List<InputDevice> devices = new List<InputDevice>();
        Gamepad controller;
        Mouse lastMouse;
        bool disposed, focused = true, inGame = true, inputLocked;
        string captureAction, captureCategory;
        public bool ControllerActive => controller != null && controller.added && controller.enabled;
        public int ControllerDeviceId => ControllerActive ? controller.deviceId : -1;
        public bool MouseAimActive { get; private set; }
        public bool CursorVisible => !ControllerActive && (!inGame || inputLocked);
        public int ActionCount => actions.Count;
        public bool Capturing => captureAction != null;
        public string CaptureMessage { get; private set; } = "";
        public IEnumerable<string> RebindableActions => actions.Values.Where(a => a.rebindable).Select(a => a.id);
        public string ActionLabel(string id) => actions[id].label;

        public PlayerInputSource(IEnumerable<InputDevice> onlyDevices = null)
        {
            var asset = Resources.Load<TextAsset>(OracleResource);
            if (!asset) throw new InvalidOperationException("Missing original Godot input oracle");
            Oracle = JsonUtility.FromJson<InputOracle>(asset.text);
            if (Oracle == null || Oracle.schema != "bluemap.player-input.v1" || Oracle.defaults == null || Oracle.defaults.Length != 36)
                throw new InvalidOperationException("Invalid input contract");
            if (onlyDevices != null) allowedDevices = new HashSet<int>(onlyDevices.Select(d => d.deviceId));
            actions = new Dictionary<string, InputActionSpec>(StringComparer.Ordinal);
            foreach (var action in Oracle.defaults)
            {
                if (actions.ContainsKey(action.id)) throw new InvalidOperationException("Duplicate action " + action.id);
                foreach (var binding in action.bindings) binding.path = SourcePath(binding);
                original.Add(action.id, action.bindings.Select(b => b.Copy()).ToArray()); actions.Add(action.id, action);
            }
            RefreshDevices();
            InputSystem.onEvent += OnEvent;
            InputSystem.onAfterUpdate += AfterUpdate;
            InputSystem.onDeviceChange += OnDeviceChange;
        }

        public void SetContext(bool gameActive, bool locked)
        {
            inGame = gameActive; inputLocked = locked;
            Cursor.visible = CursorVisible;
        }

        public void SetFocused(bool value)
        {
            if (focused == value) return;
            focused = value; ForceRelease();
        }

        public void ForceRelease()
        {
            foreach (var id in down) released.Add(id);
            down.Clear(); pressed.Clear();
            BlockHeldControls();
        }

        void RefreshDevices()
        {
            devices.Clear();
            foreach (var device in InputSystem.devices)
                if (Allowed(device) && (device is Keyboard || device is Mouse || device is Gamepad)) devices.Add(device);
        }
        bool Allowed(InputDevice device) => allowedDevices == null || allowedDevices.Contains(device.deviceId);

        void OnDeviceChange(InputDevice device, InputDeviceChange change)
        {
            if (!Allowed(device)) return;
            if (device == controller && (change == InputDeviceChange.Removed || change == InputDeviceChange.Disconnected || change == InputDeviceChange.Disabled))
                SelectDevice(null);
            RefreshDevices();
        }

        void OnEvent(InputEventPtr data, InputDevice device)
        {
            if (!focused || !Allowed(device) || (!data.IsA<StateEvent>() && !data.IsA<DeltaStateEvent>())) return;
            if (Capturing) { CaptureEvent(data, device); return; }
            if (device is Gamepad pad)
            {
                foreach (var control in pad.allControls)
                {
                    if (!(control is AxisControl axis) || !axis.ReadValueFromEvent(data, out float value)) continue;
                    float before = axis.ReadUnprocessedValue();
                    bool button = axis is ButtonControl && axis != pad.leftTrigger && axis != pad.rightTrigger;
                    if ((button && value >= 0.5f && before < 0.5f) || (!button && Mathf.Abs(value) >= Oracle.switchDeadzone && Mathf.Abs(before) < Oracle.switchDeadzone))
                    { SelectDevice(pad, axis); break; }
                }
            }
            else if (device is Keyboard keyboard)
            {
                foreach (var key in keyboard.allKeys)
                    if (key.ReadValueFromEvent(data, out float value) && value >= 0.5f && key.ReadUnprocessedValue() < 0.5f)
                    { SelectDevice(null, key); break; }
            }
            else if (device is Mouse mouse)
            {
                lastMouse = mouse;
                bool activity = mouse.delta.ReadValueFromEvent(data, out Vector2 delta) && delta.magnitude >= Oracle.mouseSwitchPixels;
                activity |= mouse.scroll.ReadValueFromEvent(data, out Vector2 wheel) && wheel != Vector2.zero;
                foreach (var button in new[] { mouse.leftButton, mouse.rightButton, mouse.middleButton, mouse.forwardButton, mouse.backButton })
                    activity |= button.ReadValueFromEvent(data, out float value) && value >= 0.5f && button.ReadUnprocessedValue() < 0.5f;
                if (activity) { SelectDevice(null); MouseAimActive = true; }
            }
        }

        void SelectDevice(Gamepad pad, InputControl switchingControl = null)
        {
            if (controller == pad) return;
            foreach (var id in down) released.Add(id);
            down.Clear(); pressed.Clear(); controller = pad;
            if (pad != null) MouseAimActive = false;
            BlockHeldControls();
            // A fresh threshold-crossing axis can have a nonzero pre-event drift value.
            // Restore that very switching input, as the Godot manager does for its event.
            if (switchingControl != null) blocked.Remove(switchingControl);
            if (switchingControl is KeyControl key && key.device is Keyboard keyboard)
            {
                if (key.keyCode == Key.LeftCtrl || key.keyCode == Key.RightCtrl) blocked.Remove(keyboard.ctrlKey);
                if (key.keyCode == Key.LeftShift || key.keyCode == Key.RightShift) blocked.Remove(keyboard.shiftKey);
                if (key.keyCode == Key.LeftAlt || key.keyCode == Key.RightAlt) blocked.Remove(keyboard.altKey);
            }
            Cursor.visible = CursorVisible;
        }

        void BlockHeldControls()
        {
            // A held input from the previous category cannot spring back to life on a mouse move.
            blocked.Clear();
            foreach (var device in devices)
                foreach (var control in device.allControls)
                    if (control is AxisControl axis && !(control is DeltaControl) && Mathf.Abs(axis.ReadUnprocessedValue()) > 0.01f)
                        blocked.Add(control);
        }

        void AfterUpdate()
        {
            if (disposed || !focused) return;
            blocked.RemoveWhere(c => c.device == null || !c.device.added || !(c is AxisControl a) || Mathf.Abs(a.ReadUnprocessedValue()) < 0.01f);
            foreach (var pair in actions)
            {
                bool held = Strength(pair.Value) > pair.Value.deadzone;
                if (held && down.Add(pair.Key)) pressed.Add(pair.Key);
                else if (!held && down.Remove(pair.Key)) released.Add(pair.Key);
            }
        }

        float Strength(InputActionSpec action)
        {
            if (!focused) return 0;
            float value = 0; string category = ControllerActive ? "controller" : "keyboard";
            foreach (var binding in action.bindings)
            {
                if (binding.category != category) continue;
                foreach (var device in devices)
                {
                    if (!device.added || !device.enabled || (ControllerActive ? device != controller : !(device is Keyboard || device is Mouse))) continue;
                    var control = InputControlPath.TryFindControl(device, binding.path) as AxisControl;
                    if (control == null || blocked.Contains(control) || !Modifiers(device, binding)) continue;
                    value = Mathf.Max(value, Mathf.Clamp01(control.ReadUnprocessedValue() * binding.direction));
                }
            }
            return value;
        }

        static bool Modifiers(InputDevice device, InputBindingSpec binding)
        {
            var keyboard = device as Keyboard;
            if (keyboard == null) return true;
            return (!binding.shift || keyboard.shiftKey.isPressed) && (!binding.ctrl || keyboard.ctrlKey.isPressed)
                && (!binding.alt || keyboard.altKey.isPressed) && (!binding.meta || keyboard.leftMetaKey.isPressed || keyboard.rightMetaKey.isPressed);
        }

        Vector2 Vector(string left, string right, string up, string bottom, float deadzone)
            => CircularDeadzone(new Vector2(Strength(actions[right]) - Strength(actions[left]), Strength(actions[bottom]) - Strength(actions[up])), deadzone);

        public static Vector2 CircularDeadzone(Vector2 raw, float deadzone)
        {
            float length = raw.magnitude;
            if (length <= deadzone || length == 0) return Vector2.zero;
            if (length > 1) return raw / length;
            return raw / length * ((length - deadzone) / (1 - deadzone));
        }

        public InputFrame Read()
        {
            if (disposed) throw new ObjectDisposedException(nameof(PlayerInputSource));
            var result = new InputFrame { ControllerActive = ControllerActive, ControllerDeviceId = ControllerDeviceId,
                MouseAimActive = MouseAimActive, CursorVisible = CursorVisible };
            if (focused)
            {
                float moveDeadzone = (actions["move_left"].deadzone + actions["move_right"].deadzone + actions["move_up"].deadzone + actions["move_down"].deadzone) / 4;
                result.Move = Vector("move_left", "move_right", "move_up", "move_down", moveDeadzone);
                result.Aim = ControllerActive ? Vector("aim_left", "aim_right", "aim_up", "aim_down", Oracle.aimDeadzone) : Vector2.zero;
                if (lastMouse == null || !lastMouse.added) lastMouse = devices.OfType<Mouse>().FirstOrDefault();
                result.MousePosition = lastMouse != null ? lastMouse.position.ReadValue() : Vector2.zero;
                result.UiScroll = ControllerActive ? result.Aim : (lastMouse != null ? lastMouse.scroll.ReadValue() : Vector2.zero);
                result.down.UnionWith(down); result.pressed.UnionWith(pressed);
            }
            result.released.UnionWith(released); pressed.Clear(); released.Clear();
            return result;
        }

        public IReadOnlyList<InputBindingSpec> Bindings(string id) => actions[id].bindings.Select(b => b.Copy()).ToArray();

        public void BeginRebindCapture(string id, string category)
        {
            if (!actions.TryGetValue(id, out var action) || !action.rebindable || (category != "keyboard" && category != "controller"))
                throw new ArgumentException("Invalid capture action/category");
            captureAction = id; captureCategory = category; CaptureMessage = ""; ForceRelease();
        }
        public void CancelCapture() { captureAction = null; captureCategory = null; CaptureMessage = ""; ForceRelease(); }

        void CaptureEvent(InputEventPtr data, InputDevice device)
        {
            if (device is Keyboard keyboard)
            {
                foreach (var key in keyboard.allKeys)
                {
                    if (!key.ReadValueFromEvent(data, out float value) || value < 0.5f || key.ReadUnprocessedValue() >= 0.5f) continue;
                    if (key.keyCode == Key.Escape && captureAction != "pause") { CancelCapture(); return; }
                    if (captureCategory != "keyboard") return;
                    string name = key.name;
                    if (key.keyCode == Key.LeftCtrl || key.keyCode == Key.RightCtrl) name = "ctrl";
                    if (key.keyCode == Key.LeftShift || key.keyCode == Key.RightShift) name = "shift";
                    if (key.keyCode == Key.LeftAlt || key.keyCode == Key.RightAlt) name = "alt";
                    FinishCapture("<Keyboard>/" + name, 1); return;
                }
            }
            else if (device is Mouse mouse && captureCategory == "keyboard")
            {
                foreach (var button in new[] { mouse.leftButton, mouse.rightButton, mouse.middleButton, mouse.forwardButton, mouse.backButton })
                    if (button.ReadValueFromEvent(data, out float value) && value >= 0.5f && button.ReadUnprocessedValue() < 0.5f)
                    { FinishCapture("<Mouse>/" + button.name, 1); return; }
                if (mouse.scroll.ReadValueFromEvent(data, out Vector2 wheel) && wheel != Vector2.zero)
                    FinishCapture("<Mouse>/scroll/" + (Mathf.Abs(wheel.y) >= Mathf.Abs(wheel.x) ? "y" : "x"), Mathf.Sign(Mathf.Abs(wheel.y) >= Mathf.Abs(wheel.x) ? wheel.y : wheel.x));
            }
            else if (device is Gamepad pad && captureCategory == "controller")
            {
                foreach (var control in pad.allControls)
                {
                    if (!(control is AxisControl axis) || !axis.ReadValueFromEvent(data, out float value) || Mathf.Abs(value) < 0.6f || Mathf.Abs(axis.ReadUnprocessedValue()) >= 0.6f) continue;
                    string relative = axis.path.Substring(pad.path.Length + 1);
                    FinishCapture("<Gamepad>/" + relative, Mathf.Sign(value)); return;
                }
            }
        }
        void FinishCapture(string path, float direction)
        {
            string error = Rebind(captureAction, captureCategory, path, direction);
            CaptureMessage = error;
            if (error == "") { captureAction = null; captureCategory = null; }
        }

        public string Rebind(string id, string category, string path, float direction = 1)
        {
            if (!actions.TryGetValue(id, out var action) || !action.rebindable || (category != "keyboard" && category != "controller")
                || string.IsNullOrEmpty(path) || (direction != 1 && direction != -1)) return "Kies een geldige toets of controllerknop.";
            bool controllerPath = path.StartsWith("<Gamepad>/", StringComparison.Ordinal);
            bool keyboardPath = path.StartsWith("<Keyboard>/", StringComparison.Ordinal) || path.StartsWith("<Mouse>/", StringComparison.Ordinal);
            if ((category == "controller" && !controllerPath) || (category == "keyboard" && !keyboardPath)) return "Kies het juiste apparaat.";
            if (controllerPath && path.StartsWith("<Gamepad>/rightStick", StringComparison.Ordinal)) return "De rechterstick blijft beschikbaar om te richten.";
            if (path == "<Keyboard>/escape" && id != "pause") return "Esc blijft beschikbaar om menu's te sluiten.";
            // Validate the actual control layout even when no physical device is connected.
            if (!ValidPath(path)) return "Kies een toets, muisknop, stickrichting of trigger.";
            var conflicts = actions.Values.Where(a => a.rebindable && a.id != id && a.bindings.Any(b => b.category == category && b.path == path && b.direction == direction)).ToArray();
            if (conflicts.Length > 1) return "Deze invoer hoort bij meerdere acties; kies een andere.";
            var old = action.bindings.Where(b => b.category == category).Select(b => b.Copy()).ToArray();
            if (conflicts.Length == 1)
            {
                if (old.Length == 0) return "Die invoer is al gekoppeld; kies een vrije knop.";
                var other = conflicts[0]; other.bindings = other.bindings.Where(b => b.category != category).Concat(old).ToArray();
            }
            action.bindings = action.bindings.Where(b => b.category != category).Concat(new[] { new InputBindingSpec { category = category, path = path, direction = direction, kind = "unity" } }).ToArray();
            ForceRelease(); return "";
        }

        static bool ValidPath(string path)
        {
            // InputControlPath parses the layout without creating or touching real devices.
            string layout = InputControlPath.TryGetDeviceLayout(path);
            string control = InputControlPath.TryGetControlLayout(path);
            return !string.IsNullOrEmpty(layout) && !string.IsNullOrEmpty(control) && (control == "Button" || control == "Key" || control == "Axis" || control == "DiscreteButton");
        }

        public void ResetBindings(string category)
        {
            if (category != "keyboard" && category != "controller") return;
            foreach (var action in actions.Values.Where(a => a.rebindable))
                action.bindings = action.bindings.Where(b => b.category != category).Concat(original[action.id].Where(b => b.category == category).Select(b => b.Copy())).ToArray();
            ForceRelease();
        }

        public static string SourcePath(InputBindingSpec b)
        {
            if (b.kind == "key")
            {
                var names = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) { { "Space", "space" }, { "Enter", "enter" }, { "Tab", "tab" }, { "Escape", "escape" }, { "Shift", "shift" }, { "Ctrl", "ctrl" }, { "Alt", "alt" }, { "Meta", "meta" }, { "Left", "leftArrow" }, { "Right", "rightArrow" }, { "Up", "upArrow" }, { "Down", "downArrow" }, { "PageUp", "pageUp" }, { "PageDown", "pageDown" } };
                return "<Keyboard>/" + (names.TryGetValue(b.keyName, out string name) ? name : b.keyName.ToLowerInvariant());
            }
            if (b.kind == "mouse")
            {
                string[] names = { "", "leftButton", "rightButton", "middleButton", "scroll/y", "scroll/y", "scroll/x", "scroll/x", "backButton", "forwardButton" };
                if (b.code < 1 || b.code >= names.Length) throw new InvalidOperationException("Unknown source mouse button");
                if (b.code == 5 || b.code == 6) b.direction = -1;
                return "<Mouse>/" + names[b.code];
            }
            if (b.kind == "button")
            {
                string[] names = { "buttonSouth", "buttonEast", "buttonWest", "buttonNorth", "select", "systemButton", "start", "leftStickPress", "rightStickPress", "leftShoulder", "rightShoulder", "dpad/up", "dpad/down", "dpad/left", "dpad/right" };
                if (b.code < 0 || b.code >= names.Length) throw new InvalidOperationException("Unknown source gamepad button");
                return "<Gamepad>/" + names[b.code];
            }
            if (b.kind == "axis")
            {
                string[] names = { "leftStick/x", "leftStick/y", "rightStick/x", "rightStick/y", "leftTrigger", "rightTrigger" };
                if (b.code < 0 || b.code >= names.Length) throw new InvalidOperationException("Unknown source gamepad axis");
                if (b.code == 1 || b.code == 3) b.direction *= -1; // Unity Y is north; original Godot Y is south.
                return "<Gamepad>/" + names[b.code];
            }
            throw new InvalidOperationException("Unmapped original input event " + b.kind);
        }

        public static string[] ConnectedDeviceInventory() => InputSystem.devices.Select(d => d.layout + ":" + d.deviceId + ":" + (d.native ? "native" : "virtual") + ":" + (d.enabled ? "enabled" : "disabled")).ToArray();

        public void Dispose()
        {
            if (disposed) return; disposed = true;
            InputSystem.onEvent -= OnEvent; InputSystem.onAfterUpdate -= AfterUpdate; InputSystem.onDeviceChange -= OnDeviceChange;
            down.Clear(); pressed.Clear(); released.Clear(); blocked.Clear();
        }
    }
}
