using System;
using System.Linq;
using BlueMapMigration.Player;
using UnityEngine;
using UnityEngine.InputSystem;

namespace BlueMapMigration.Persistence
{
    /// <summary>Explicit import and isolated profile controls. Drawing never discovers or opens legacy player files.</summary>
    public sealed class PersistencePanel
    {
        PersistenceCoordinator coordinator;
        PlayerInputSource input;
        string sourceDirectory = "";
        int selectedProfile, focus, lastFrame = -1;
        float nextNavigation, nextActivation;
        bool visible, wasAccept;
        bool editingSourceDirectory;
        Vector2 profileScroll;
        public event Action WalkRequested;
        public event Action ControlsRequested;
        public bool EditingSourceDirectory => visible && editingSourceDirectory;
        public bool Visible
        {
            get => visible;
            set { if (visible == value) return; visible = value; editingSourceDirectory = false; nextActivation = Time.unscaledTime + .25f; nextNavigation = nextActivation; wasAccept = true; }
        }
        public void Initialize(PersistenceCoordinator owner, PlayerInputSource source)
        {
            coordinator = owner ?? throw new ArgumentNullException(nameof(owner));
            input = source ?? throw new ArgumentNullException(nameof(source));
            sourceDirectory = owner.SourceDirectory ?? "";
        }
        public void SetSourceDirectory(string path) { sourceDirectory = path ?? ""; }

        void Navigate()
        {
            if (lastFrame == Time.frameCount) return; lastFrame = Time.frameCount;
            bool controller = input.ControllerActive; var pad = controller ? InputSystem.GetDeviceById(input.ControllerDeviceId) as Gamepad : null;
            var keyboard = controller ? null : Keyboard.current;
            bool accept = pad != null ? pad.buttonSouth.isPressed : keyboard != null && keyboard.enterKey.isPressed;
            int vertical = pad != null ? (pad.dpad.down.isPressed || pad.leftStick.y.ReadValue() < -.5f ? 1 : pad.dpad.up.isPressed || pad.leftStick.y.ReadValue() > .5f ? -1 : 0)
                : keyboard != null && GUI.GetNameOfFocusedControl() != "Phase9ImportDirectory" ? (keyboard.downArrowKey.isPressed ? 1 : keyboard.upArrowKey.isPressed ? -1 : 0) : 0;
            if (keyboard != null && keyboard.tabKey.wasPressedThisFrame) vertical = keyboard.shiftKey.isPressed ? -1 : 1;
            if (vertical != 0 && Time.unscaledTime >= nextNavigation)
            {
                focus = Mathf.Clamp(focus + vertical, 0, 13); GUI.FocusControl(""); nextNavigation = Time.unscaledTime + .18f;
            }
            if (pad != null && focus == 3 && coordinator.Profiles.Count > 0)
            {
                int horizontal = pad.dpad.right.isPressed || pad.leftStick.x.ReadValue() > .5f ? 1 : pad.dpad.left.isPressed || pad.leftStick.x.ReadValue() < -.5f ? -1 : 0;
                if (horizontal != 0 && Time.unscaledTime >= nextNavigation)
                { selectedProfile = Mathf.Clamp(selectedProfile + horizontal, 0, coordinator.Profiles.Count - 1); profileScroll.y = Mathf.Max(0, selectedProfile * 28 - 100); nextNavigation = Time.unscaledTime + .18f; }
                float scroll = PlayerInputSource.CircularDeadzone(pad.rightStick.ReadUnprocessedValue(), input.Oracle.aimDeadzone).y;
                profileScroll.y = Mathf.Clamp(profileScroll.y - scroll * 260 * Time.unscaledDeltaTime, 0, Mathf.Max(0, coordinator.Profiles.Count * 28 - 112));
            }
            if (accept && !wasAccept && Time.unscaledTime >= nextActivation) { Activate(focus); nextActivation = Time.unscaledTime + .2f; }
            wasAccept = accept;
        }
        void Activate(int id)
        {
            var preferences = coordinator.Preferences;
            switch (id)
            {
                case 0: if (!input.ControllerActive) GUI.FocusControl("Phase9ImportDirectory"); break;
                case 1: coordinator.ImportSource(sourceDirectory); break;
                case 2: coordinator.RefreshProfiles(); selectedProfile = Mathf.Clamp(selectedProfile, 0, Mathf.Max(0, coordinator.Profiles.Count - 1)); break;
                case 3: if (coordinator.Profiles.Count > 0) selectedProfile = (selectedProfile + 1) % coordinator.Profiles.Count; break;
                case 4: if (coordinator.Profiles.Count > 0) coordinator.OpenProfile(coordinator.Profiles[Mathf.Clamp(selectedProfile, 0, coordinator.Profiles.Count - 1)]); break;
                case 5:
                    if (coordinator.HasProfile) coordinator.RecoverPrevious();
                    else if (coordinator.Profiles.Count > 0) coordinator.RecoverProfile(coordinator.Profiles[Mathf.Clamp(selectedProfile, 0, coordinator.Profiles.Count - 1)]);
                    break;
                case 6: coordinator.SetPreferences(new LegacyPreferences(preferences.Locale == "nl" ? "en" : "nl", preferences.Muted, preferences.MusicVolume, preferences.SfxVolume)); break;
                case 7: coordinator.SetPreferences(new LegacyPreferences(preferences.Locale, !preferences.Muted, preferences.MusicVolume, preferences.SfxVolume)); break;
                case 8: ChangeVolume(true, -.1); break; case 9: ChangeVolume(true, .1); break;
                case 10: ChangeVolume(false, -.1); break; case 11: ChangeVolume(false, .1); break;
                case 12: WalkRequested?.Invoke(); break;
                case 13: ControlsRequested?.Invoke(); break;
            }
        }
        void ChangeVolume(bool music, double delta)
        {
            var p = coordinator.Preferences;
            coordinator.SetPreferences(new LegacyPreferences(p.Locale, p.Muted, p.MusicVolume + (music ? delta : 0), p.SfxVolume + (music ? 0 : delta)));
        }
        void Button(int id, Rect rect, string text, bool enabled = true)
        {
            var previousColor = GUI.backgroundColor; if (focus == id) GUI.backgroundColor = new Color(.38f, .72f, .88f);
            bool previous = GUI.enabled; GUI.enabled = previous && enabled && !input.ControllerActive;
            if (GUI.Button(rect, (focus == id ? "› " : "") + text)) { focus = id; Activate(id); }
            GUI.enabled = previous; GUI.backgroundColor = previousColor;
            if (input.ControllerActive && focus == id)
            {
                var tint = GUI.color; GUI.color = new Color(.5f, .85f, 1);
                GUI.DrawTexture(new Rect(rect.x - 2, rect.y - 2, rect.width + 4, 2), Texture2D.whiteTexture);
                GUI.DrawTexture(new Rect(rect.x - 2, rect.yMax, rect.width + 4, 2), Texture2D.whiteTexture);
                GUI.DrawTexture(new Rect(rect.x - 2, rect.y, 2, rect.height), Texture2D.whiteTexture);
                GUI.DrawTexture(new Rect(rect.xMax, rect.y, 2, rect.height), Texture2D.whiteTexture); GUI.color = tint;
            }
        }
        public void Draw(Rect bounds)
        {
            if (!Visible || coordinator == null) return;
            Navigate(); GUI.Box(bounds, "");
            var title = new GUIStyle(GUI.skin.label) { fontSize = 22, fontStyle = FontStyle.Bold };
            var label = new GUIStyle(GUI.skin.label) { fontSize = 14, wordWrap = true };
            var small = new GUIStyle(label) { fontSize = 12 };
            float x = bounds.x + 22, y = bounds.y + 16, width = bounds.width - 44;
            GUI.Label(new Rect(x, y, width, 30), "Je avontuur veilig meenemen", title);
            GUI.Label(new Rect(x, y + 35, width, 40), "Importeer een kopie van je Godot-opslag naar een apart Unity-profiel. Je oorspronkelijke spelbestanden blijven behouden.", label);
            float leftWidth = Mathf.Floor(width * .55f), gap = 26, rightX = x + leftWidth + gap, rightWidth = width - leftWidth - gap;
            float top = y + 86;
            GUI.Label(new Rect(x, top, leftWidth, 25), "1. Kies de map met je oorspronkelijke opslag", label);
            bool oldEnabled = GUI.enabled; GUI.enabled = oldEnabled && !input.ControllerActive;
            GUI.SetNextControlName("Phase9ImportDirectory"); sourceDirectory = GUI.TextField(new Rect(x, top + 28, leftWidth, 31), sourceDirectory, 1024);
            editingSourceDirectory = GUI.GetNameOfFocusedControl() == "Phase9ImportDirectory";
            GUI.enabled = oldEnabled;
            Button(1, new Rect(x, top + 68, leftWidth * .62f - 5, 34), "Kopie importeren");
            Button(2, new Rect(x + leftWidth * .62f + 5, top + 68, leftWidth * .38f - 5, 34), "Profielen verversen");
            GUI.Label(new Rect(x, top + 112, leftWidth, 40), "Import start alleen na jouw keuze. Ontbrekende of beschadigde onderdelen worden zichtbaar gemeld.", small);
            GUI.Label(new Rect(x, top + 159, leftWidth, 25), "2. Bestaande Unity-profielen", label);
            var profiles = coordinator.Profiles; selectedProfile = Mathf.Clamp(selectedProfile, 0, Mathf.Max(0, profiles.Count - 1));
            var list = new Rect(x, top + 189, leftWidth, 114); GUI.Box(list, "");
            if (profiles.Count == 0) GUI.Label(new Rect(list.x + 10, list.y + 10, list.width - 20, 40), "Nog geen profiel. Importeer eerst een kopie.", small);
            else
            {
                profileScroll = GUI.BeginScrollView(list, profileScroll, new Rect(0, 0, list.width - 24, profiles.Count * 28));
                for (int index = 0; index < profiles.Count; index++)
                {
                    bool enabled = GUI.enabled; GUI.enabled = enabled && !input.ControllerActive;
                    bool clicked = GUI.Toggle(new Rect(5, index * 28, list.width - 34, 26), selectedProfile == index, profiles[index], GUI.skin.button);
                    if (clicked && !input.ControllerActive) { selectedProfile = index; focus = 3; }
                    GUI.enabled = enabled;
                }
                GUI.EndScrollView();
            }
            Button(4, new Rect(x, top + 313, leftWidth * .53f - 5, 34), "Gekozen profiel openen", profiles.Count > 0);
            Button(5, new Rect(x + leftWidth * .53f + 5, top + 313, leftWidth * .47f - 5, 34), coordinator.HasProfile ? "Vorige versie herstellen" : "Profiel herstellen", coordinator.HasProfile || profiles.Count > 0);
            var preferences = coordinator.Preferences;
            GUI.Label(new Rect(rightX, top, rightWidth, 25), "Taal en geluid", title);
            Button(6, new Rect(rightX, top + 38, rightWidth, 34), preferences.Locale == "nl" ? "Taal: Nederlands" : "Language: English");
            Button(7, new Rect(rightX, top + 82, rightWidth, 34), preferences.Muted ? "Geluid: uit" : "Geluid: aan");
            GUI.Label(new Rect(rightX, top + 130, rightWidth, 26), "Muziek: " + Mathf.RoundToInt((float)preferences.MusicVolume * 100) + "%", label);
            Button(8, new Rect(rightX, top + 160, rightWidth * .5f - 5, 32), "− zachter"); Button(9, new Rect(rightX + rightWidth * .5f + 5, top + 160, rightWidth * .5f - 5, 32), "+ harder");
            GUI.Label(new Rect(rightX, top + 207, rightWidth, 26), "Effecten: " + Mathf.RoundToInt((float)preferences.SfxVolume * 100) + "%", label);
            Button(10, new Rect(rightX, top + 237, rightWidth * .5f - 5, 32), "− zachter"); Button(11, new Rect(rightX + rightWidth * .5f + 5, top + 237, rightWidth * .5f - 5, 32), "+ harder");
            GUI.Label(new Rect(rightX, top + 280, rightWidth, 38), "Voortgang, uiterlijk en bezittingen blijven bewaard. De loopproef verandert je oorspronkelijke avontuur niet.", small);
            Button(12, new Rect(rightX, top + 321, rightWidth * .5f - 5, 34), "Loopproef");
            Button(13, new Rect(rightX + rightWidth * .5f + 5, top + 321, rightWidth * .5f - 5, 34), "Bediening aanpassen");
            float statusY = top + 367;
            GUI.Box(new Rect(x, statusY, width, 63), "");
            GUI.Label(new Rect(x + 10, statusY + 8, width - 20, 49), coordinator.Status ?? "Kies een opslagmap of een bestaand profiel.", small);
            GUI.Label(new Rect(x, bounds.yMax - 39, width, 27), input.ControllerActive ? "D-pad / linkerstick: kiezen  ·  A: gebruiken  ·  links/rechts bij profielen: profiel kiezen  ·  rechterstick: lijst schuiven" : "Muis: kiezen  ·  Tab / pijlen: navigeren  ·  Enter: gebruiken  ·  F9: opgeslagen bediening", small);
        }
    }
}
