using System;
using System.Linq;
using UnityEngine;

namespace BlueMapMigration.Player
{
    /// <summary>A small real binding preview. Complete settings/menu conversion remains phase 24.</summary>
    public sealed class PlayerControlsPanel
    {
        readonly PlayerInputSource input;
        readonly string[] actions;
        string category = "keyboard";
        int selected;
        Vector2 scroll;
        float nextNavigation;
        float viewportHeight = 210;
        bool captureGuard;
        public bool IsOpen { get; private set; }
        public PlayerControlsPanel(PlayerInputSource source)
        { input = source ?? throw new ArgumentNullException(nameof(source)); actions = input.RebindableActions.ToArray(); }

        public void Toggle()
        {
            IsOpen = !IsOpen; input.CancelCapture(); captureGuard = false;
            if (IsOpen) { category = input.ControllerActive ? "controller" : "keyboard"; nextNavigation = Time.unscaledTime + .2f; }
        }

        public void Handle(InputFrame frame)
        {
            if (!IsOpen) return;
            bool ignore = input.Capturing || captureGuard; captureGuard = input.Capturing;
            if (ignore) return;
            if (frame.Pressed("ui_cancel")) { Toggle(); return; }
            if (frame.Pressed("ui_prev_tab") || frame.Pressed("ui_next_tab")) category = category == "keyboard" ? "controller" : "keyboard";
            if (Time.unscaledTime >= nextNavigation)
            {
                int direction = frame.Held("ui_down") ? 1 : frame.Held("ui_up") ? -1 : 0;
                if (direction != 0)
                {
                    selected = Mathf.Clamp(selected + direction, 0, actions.Length - 1);
                    scroll.y = Mathf.Clamp(scroll.y, Mathf.Max(0, selected * 30 - viewportHeight + 30), selected * 30);
                    nextNavigation = Time.unscaledTime + .16f;
                }
            }
            if (frame.ControllerActive) scroll.y = Mathf.Clamp(scroll.y + frame.UiScroll.y * 340 * Time.unscaledDeltaTime, 0, Mathf.Max(0, actions.Length * 30 - viewportHeight));
            if (frame.Pressed("ui_accept")) Begin();
        }

        void Begin() { input.BeginRebindCapture(actions[selected], category); captureGuard = true; }

        static string Label(InputBindingSpec binding)
        {
            string path = binding.path.Replace("<Keyboard>/", "").Replace("<Mouse>/", "Muis ").Replace("<Gamepad>/", "");
            if (binding.kind == "axis" || path.EndsWith("/x", StringComparison.Ordinal) || path.EndsWith("/y", StringComparison.Ordinal))
                path += binding.direction < 0 ? " −" : " +";
            if (binding.shift) path = "Shift + " + path;
            return path;
        }

        public void Draw(Rect bounds)
        {
            if (!IsOpen) return;
            GUI.Box(bounds, ""); GUILayout.BeginArea(new Rect(bounds.x + 20, bounds.y + 12, bounds.width - 40, bounds.height - 24));
            var heading = new GUIStyle(GUI.skin.label) { fontSize = 20 };
            var label = new GUIStyle(GUI.skin.label) { fontSize = 14, clipping = TextClipping.Clip };
            GUILayout.Label("Bediening — alleen deze proefsessie", heading);
            GUILayout.Label("Wijzigingen worden nog niet opgeslagen. De oorspronkelijke bediening blijft behouden.", label);
            bool oldEnabled = GUI.enabled;
            // Pointer widgets follow the same one-device policy as gameplay.
            GUI.enabled = oldEnabled && !input.ControllerActive && !input.Capturing;
            GUILayout.BeginHorizontal();
            if (GUILayout.Toggle(category == "keyboard", "Toetsenbord / muis", GUI.skin.button, GUILayout.Height(30))) category = "keyboard";
            if (GUILayout.Toggle(category == "controller", "Controller", GUI.skin.button, GUILayout.Height(30))) category = "controller";
            GUILayout.EndHorizontal();
            viewportHeight = Mathf.Max(60, bounds.height - (input.Capturing ? 235 : 215));
            scroll = GUILayout.BeginScrollView(scroll, GUILayout.Height(viewportHeight));
            for (int index = 0; index < actions.Length; index++)
            {
                GUILayout.BeginHorizontal(GUILayout.Height(30));
                if (GUILayout.Toggle(selected == index, input.ActionLabel(actions[index]), GUI.skin.button, GUILayout.Width(320), GUILayout.Height(27))) selected = index;
                string bindings = string.Join(" / ", input.Bindings(actions[index]).Where(b => b.category == category).Select(Label));
                GUILayout.Label(bindings == "" ? "Niet ingesteld" : bindings, label, GUILayout.Height(27));
                GUILayout.EndHorizontal();
            }
            GUILayout.EndScrollView();
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("Geselecteerde actie wijzigen", GUILayout.Height(32))) Begin();
            if (GUILayout.Button("Herstel deze categorie", GUILayout.Height(32))) input.ResetBindings(category);
            if (GUILayout.Button("Sluiten", GUILayout.Height(32))) Toggle();
            GUILayout.EndHorizontal(); GUI.enabled = oldEnabled;
            if (input.Capturing)
            {
                GUILayout.Label("Druk nieuwe invoer voor: " + input.ActionLabel(actions[selected]), label);
                GUILayout.Label(input.CaptureMessage == "" ? "Kies " + (category == "controller" ? "een knop, stickrichting of trigger (rechterstick blijft richten)." : "een toets of muisknop; Esc annuleert.") : input.CaptureMessage, label);
            }
            else GUILayout.Label("D-pad / linkerstick: actie  ·  A / Enter: wijzigen  ·  B / Esc: sluiten  ·  LB / RB: apparaat", label);
            GUILayout.Label("Rechterstick: lijst schuiven. Conflicten wisselen koppelingen; Esc en richten blijven bereikbaar.", label);
            GUILayout.EndArea();
        }
    }
}
