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
        public event Action NewAdventureRequested;
        public event Action ContinueAdventureRequested;
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
        string T(string dutch, string english) => coordinator.Preferences.Locale == "en" ? english : dutch;

        void Navigate()
        {
            if (lastFrame == Time.frameCount) return; lastFrame = Time.frameCount;
            if (!Application.isFocused) { wasAccept = true; nextActivation = Time.unscaledTime + .2f; nextNavigation = nextActivation; return; }
            bool controller = input.ControllerActive; var pad = controller ? InputSystem.GetDeviceById(input.ControllerDeviceId) as Gamepad : null;
            var keyboard = controller ? null : Keyboard.current;
            bool accept = pad != null ? pad.buttonSouth.isPressed : keyboard != null && keyboard.enterKey.isPressed;
            int vertical = pad != null ? (pad.dpad.down.isPressed || pad.leftStick.y.ReadValue() < -.5f ? 1 : pad.dpad.up.isPressed || pad.leftStick.y.ReadValue() > .5f ? -1 : 0)
                : keyboard != null && GUI.GetNameOfFocusedControl() != "Phase9ImportDirectory" ? (keyboard.downArrowKey.isPressed ? 1 : keyboard.upArrowKey.isPressed ? -1 : 0) : 0;
            if (keyboard != null && keyboard.tabKey.wasPressedThisFrame) vertical = keyboard.shiftKey.isPressed ? -1 : 1;
            if (vertical != 0 && Time.unscaledTime >= nextNavigation)
            {
                focus = Mathf.Clamp(focus + vertical, 0, 15); GUI.FocusControl(""); nextNavigation = Time.unscaledTime + .18f;
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
                case 14: NewAdventureRequested?.Invoke();break;
                case 15: if(coordinator.HasProfile)ContinueAdventureRequested?.Invoke();break;
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
            GUI.Label(new Rect(x, y, width, 30), T("Je avontuur veilig meenemen", "Bring your adventure safely"), title);
            GUI.Label(new Rect(x, y + 35, width, 40), T("Importeer een kopie van je Godot-opslag naar een apart Unity-profiel. Je kunt ook direct een nieuw avontuur starten. Je oorspronkelijke spelbestanden blijven behouden.", "Import a copy of your Godot save into a separate Unity profile. You can also start a new adventure directly. Your original game files remain preserved."), label);
            float leftWidth = Mathf.Floor(width * .55f), gap = 26, rightX = x + leftWidth + gap, rightWidth = width - leftWidth - gap;
            float top = y + 86;
            GUI.Label(new Rect(x, top, leftWidth, 25), T("1. Kies de map met je oorspronkelijke opslag", "1. Choose the folder containing your original save"), label);
            bool oldEnabled = GUI.enabled; GUI.enabled = oldEnabled && !input.ControllerActive;
            GUI.SetNextControlName("Phase9ImportDirectory"); sourceDirectory = GUI.TextField(new Rect(x, top + 28, leftWidth, 31), sourceDirectory, 1024);
            editingSourceDirectory = GUI.GetNameOfFocusedControl() == "Phase9ImportDirectory";
            GUI.enabled = oldEnabled;
            Button(1, new Rect(x, top + 68, leftWidth * .62f - 5, 34), T("Kopie importeren", "Import a copy"));
            Button(2, new Rect(x + leftWidth * .62f + 5, top + 68, leftWidth * .38f - 5, 34), T("Profielen verversen", "Refresh profiles"));
            GUI.Label(new Rect(x, top + 112, leftWidth, 40), T("Import start alleen na jouw keuze. Ontbrekende of beschadigde onderdelen worden zichtbaar gemeld.", "Import only starts when you choose it. Missing or damaged parts are reported visibly."), small);
            GUI.Label(new Rect(x, top + 159, leftWidth, 25), T("2. Bestaande Unity-profielen", "2. Existing Unity profiles"), label);
            var profiles = coordinator.Profiles; selectedProfile = Mathf.Clamp(selectedProfile, 0, Mathf.Max(0, profiles.Count - 1));
            var list = new Rect(x, top + 189, leftWidth, 114); GUI.Box(list, "");
            if (profiles.Count == 0) GUI.Label(new Rect(list.x + 10, list.y + 10, list.width - 20, 40), T("Nog geen profiel. Start hieronder een nieuw avontuur, of importeer een kopie.", "No profile yet. Start a new adventure below, or import a copy."), small);
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
            Button(4, new Rect(x, top + 313, leftWidth * .53f - 5, 34), T("Gekozen profiel openen", "Open selected profile"), profiles.Count > 0);
            Button(5, new Rect(x + leftWidth * .53f + 5, top + 313, leftWidth * .47f - 5, 34), coordinator.HasProfile ? T("Vorige versie herstellen", "Restore previous version") : T("Profiel herstellen", "Recover profile"), coordinator.HasProfile || profiles.Count > 0);
            var preferences = coordinator.Preferences;
            GUI.Label(new Rect(rightX, top, rightWidth, 34), T("Taal en geluid", "Language and audio"), title);
            Button(6, new Rect(rightX, top + 38, rightWidth, 34), preferences.Locale == "nl" ? "Taal: Nederlands" : "Language: English");
            Button(7, new Rect(rightX, top + 82, rightWidth, 34), preferences.Muted ? T("Geluid: uit", "Sound: off") : T("Geluid: aan", "Sound: on"));
            GUI.Label(new Rect(rightX, top + 130, rightWidth, 26), T("Muziek: ", "Music: ") + Mathf.RoundToInt((float)preferences.MusicVolume * 100) + "%", label);
            Button(8, new Rect(rightX, top + 160, rightWidth * .5f - 5, 32), T("− zachter", "− quieter")); Button(9, new Rect(rightX + rightWidth * .5f + 5, top + 160, rightWidth * .5f - 5, 32), T("+ harder", "+ louder"));
            GUI.Label(new Rect(rightX, top + 207, rightWidth, 26), T("Effecten: ", "Effects: ") + Mathf.RoundToInt((float)preferences.SfxVolume * 100) + "%", label);
            Button(10, new Rect(rightX, top + 237, rightWidth * .5f - 5, 32), T("− zachter", "− quieter")); Button(11, new Rect(rightX + rightWidth * .5f + 5, top + 237, rightWidth * .5f - 5, 32), T("+ harder", "+ louder"));
            GUI.Label(new Rect(rightX, top + 280, rightWidth, 38), T("Voortgang, uiterlijk en bezittingen blijven bewaard. De loopproef verandert je oorspronkelijke avontuur niet.", "Progress, appearance and items stay preserved. The movement preview does not change your original adventure."), small);
            Button(12, new Rect(rightX, top + 321, rightWidth * .5f - 5, 34), T("Loopproef", "Movement preview"));
            Button(13, new Rect(rightX + rightWidth * .5f + 5, top + 321, rightWidth * .5f - 5, 34), T("Bediening aanpassen", "Edit controls"));
            float statusY = top + 367;
            GUI.Box(new Rect(x, statusY, width, 63), "");
            GUI.Label(new Rect(x + 10, statusY + 8, width - 20, 49), coordinator.Status ?? T("Kies een opslagmap of een bestaand profiel.", "Choose a save folder or an existing profile."), small);
            Button(14,new Rect(x,statusY+71,width*.5f-6,28),T("Nieuw avontuur","New adventure"));
            Button(15,new Rect(x+width*.5f+6,statusY+71,width*.5f-6,28),coordinator.IsRouteProfile?T("Verder spelen","Continue adventure"):T("Speel een veilige kopie","Play a safe copy"),coordinator.HasProfile);
            GUI.Label(new Rect(x, bounds.yMax - 39, width, 27), input.ControllerActive ? T("D-pad / linkerstick: kiezen  ·  A: gebruiken  ·  links/rechts bij profielen: profiel kiezen  ·  rechterstick: lijst schuiven", "D-pad / left stick: select  ·  A: use  ·  left/right in profiles: choose profile  ·  right stick: scroll list") : T("Muis: kiezen  ·  Tab / pijlen: navigeren  ·  Enter: gebruiken  ·  F9: opgeslagen bediening", "Mouse: select  ·  Tab / arrows: navigate  ·  Enter: use  ·  F9: saved controls"), small);
        }
    }
}
