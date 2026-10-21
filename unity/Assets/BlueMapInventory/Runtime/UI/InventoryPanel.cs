using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using UnityEngine;

namespace BlueMapMigration.Inventory
{
    /// <summary>
    /// The original six-column backpack and two-column stock ledger share one selected item contract.
    /// The route owns the input source, world lock and physical-store context. This view never opens a
    /// save, changes a world object, polls a second device, or supplies materials from a remote store.
    /// Coordinates use the route HUD's 1152 by 648 logical canvas; every interactive area is clipped.
    /// </summary>
    public sealed class InventoryPanel
    {
        public const int Columns = 6, PageSize = 24;
        public const float RowHeight = 34f, LedgerHeight = 210f, StickRepeatSeconds = .13f;
        public static readonly Rect PanelRect = new Rect(76, 68, 1000, 556);
        public static readonly Rect BagGridRect = new Rect(98, 208, 496, 328);
        public static readonly Rect BagListRect = new Rect(98, 208, 468, LedgerHeight);
        public static readonly Rect StockListRect = new Rect(586, 208, 468, LedgerHeight);
        readonly InventoryModel model;
        readonly Phase6Catalog catalog;
        readonly Func<string, string> translate;
        readonly Func<string, string, string> bilingual;
        readonly HashSet<string> consumables;
        readonly Dictionary<string, Texture2D> sheets = new Dictionary<string, Texture2D>(StringComparer.Ordinal);
        readonly Dictionary<string, string> aliases = new Dictionary<string, string>(StringComparer.Ordinal);
        readonly Dictionary<string, int> densities = new Dictionary<string, int>(StringComparer.Ordinal);
        readonly List<string>[] rows = { new List<string>(), new List<string>() };
        readonly int[] indices = { 0, 0 };
        readonly float[] scroll = { 0, 0 };
        readonly string[] selected = { "", "" };
        readonly string[] categoriesNl = { "Alles", "Grondstoffen", "Landbouw", "Eten & drinken", "Gereedschap & uitrusting", "Verhaal & sleutels" };
        readonly string[] categoriesEn = { "Everything", "Materials", "Farming", "Food & drink", "Tools & equipment", "Story & keys" };
        readonly string[] sortsNl = { "Gevonden", "Categorie", "Naam", "Aantal" };
        readonly string[] sortsEn = { "Found", "Category", "Name", "Quantity" };
        GUIStyle text, title, small, wrap, button, entry, number;
        string query = "", message = "", pending = "", pendingItem = "";
        long pendingAmount;
        bool pendingDeposit, pendingConfirm = true, controller, letters, clearSearchFocus, searchHasFocus, requestSearchFocus;
        int category, focus, actionIndex, letterIndex;
        InputFrame lastHandledFrame;
        float stickWait, repeatWait, detailScroll;
        bool onlyFavorites;
        public bool IsOpen { get; private set; }
        public string Kind { get; private set; } = "bag";
        public bool IsStorage => Kind != "bag";
        public bool IsReadOnly => IsStorage && model.NearbyKind != Kind;
        public bool ControllerActive => controller;
        public bool LettersVisible => letters;
        public bool SearchEditing => !controller && searchHasFocus && !letters && pending == "";
        public bool ConfirmationVisible => pending != "";
        public string PendingAction => pending;
        public long PendingQuantity => pendingAmount;
        public int ActivePane { get; private set; }
        public int FocusZone => focus;
        public string FocusName => letters ? "letters" : pending != "" ? "confirmation" : new[] { "items", "search", "category", "sort", "favorites", "actions", "bulk", "details", "destination", "close" }[focus];
        public string Query => query;
        public int Category => category;
        public bool FavoritesOnly => onlyFavorites;
        public int Page => IsStorage ? 0 : SelectedIndex / PageSize;
        public int LastRowsDrawn { get; private set; }
        public int VisibleRows => IsStorage ? (int)(LedgerHeight / RowHeight) : PageSize;
        public IReadOnlyList<string> Ids => rows[ActivePane];
        public IReadOnlyList<string> BagIds => rows[0];
        public IReadOnlyList<string> StockIds => rows[1];
        public string SelectedId => rows[ActivePane].Count == 0 ? "" : rows[ActivePane][Mathf.Clamp(indices[ActivePane], 0, rows[ActivePane].Count - 1)];
        public int SelectedIndex
        {
            get => indices[ActivePane];
            set { indices[ActivePane] = Mathf.Clamp(value, 0, Math.Max(0, rows[ActivePane].Count - 1)); RememberSelection(); EnsureVisible(); }
        }
        public float Scroll
        {
            get => scroll[ActivePane];
            set { scroll[ActivePane] = Mathf.Clamp(value, 0, MaximumScroll(ActivePane)); }
        }
        public Rect ViewportRect => IsStorage ? (ActivePane == 0 ? BagListRect : StockListRect) : BagGridRect;
        public Rect SelectedScreenRect
        {
            get
            {
                if (SelectedId == "") return Rect.zero;
                if (IsStorage) { Rect view = ViewportRect; return new Rect(view.x, view.y + SelectedIndex * RowHeight - Scroll, view.width - 16, RowHeight); }
                int local = SelectedIndex % PageSize; return new Rect(BagGridRect.x + local % Columns * 84, BagGridRect.y + local / Columns * 84, 76, 76);
            }
        }
        public Rect RenderedSelectedBounds { get; private set; }
        public bool SelectionVisible => SelectedId == "" || Contains(ViewportRect, SelectedScreenRect);
        public bool LayoutFits => LayoutRects().All(r => Contains(new Rect(0, 0, 1152, 648), r));
        public string SummaryText { get; set; } = "";
        public Func<string, bool> CanUse { get; set; }
        public Func<string, string> ItemUses { get; set; }
        public event Action<string> UseRequested;
        public event Action Closed;
        public event Action<string> ContextRequested;

        [Serializable] sealed class AliasManifest { public AliasEntry[] aliases = Array.Empty<AliasEntry>(); }
        [Serializable] sealed class AliasEntry { public string name = "", originalTextureId = "", detailedTextureId = ""; public int density = 1; }

        public InventoryPanel(InventoryModel inventory, Phase6Catalog sourceCatalog, Func<string, string> translateSource, Func<string, string, string> text)
        {
            model = inventory ?? throw new ArgumentNullException(nameof(inventory));
            catalog = sourceCatalog;
            translate = translateSource ?? (s => s);
            bilingual = text ?? ((nl, en) => nl);
            consumables = new HashSet<string>(model.Oracle.Require("catalogs").Require("consumables").Items.Select(value => value.AsString()), StringComparer.Ordinal);
            if (catalog != null && catalog.graphicsSource != null)
            {
                var manifest = JsonUtility.FromJson<AliasManifest>(catalog.graphicsSource.text);
                foreach (var alias in manifest?.aliases ?? Array.Empty<AliasEntry>())
                    if (!string.IsNullOrEmpty(alias.name) && !string.IsNullOrEmpty(alias.detailedTextureId))
                    { aliases[alias.name] = alias.detailedTextureId; densities[alias.name] = Math.Max(1, alias.density); }
            }
        }
        string T(string nl, string en) => bilingual(nl, en);
        string Tr(string value) => translate(value ?? "");
        Color Accent => Kind == "home" ? new Color(.70f, .83f, .57f) : Kind == "coast" ? new Color(.45f, .78f, .85f) : new Color(.57f, .77f, .92f);
        Color Gold => new Color(.92f, .82f, .57f);
        Color Ink => new Color(.91f, .94f, .88f);
        static bool Contains(Rect outer, Rect inner) => inner.xMin >= outer.xMin - .5f && inner.yMin >= outer.yMin - .5f && inner.xMax <= outer.xMax + .5f && inner.yMax <= outer.yMax + .5f;
        public IReadOnlyList<Rect> LayoutRects() => new[] { PanelRect, new Rect(98, 82, 488, 36), new Rect(98, 150, 244, 30), new Rect(350, 150, 66, 30), new Rect(424, 150, 190, 30), new Rect(622, 150, 235, 30), new Rect(865, 150, 187, 30), BagGridRect, BagListRect, StockListRect, new Rect(624, 208, 430, 328), new Rect(98, 516, 956, 34), new Rect(98, 558, 956, 34), new Rect(98, 598, 956, 18) };

        public void Open(string kind = "bag")
        {
            if (kind != "bag" && kind != "home" && kind != "coast") throw new ArgumentOutOfRangeException(nameof(kind));
            ContextRequested?.Invoke(kind);
            Kind = kind; IsOpen = true; ActivePane = 0; focus = 0; letters = false; pending = ""; message = ""; clearSearchFocus = true;
            query = ""; category = 0; onlyFavorites = false; detailScroll = 0; searchHasFocus = false;
            for (int pane = 0; pane < 2; pane++) { indices[pane] = 0; scroll[pane] = 0; selected[pane] = ""; }
            stickWait = repeatWait = 0; lastHandledFrame = null; Refresh(); EnsureVisible();
        }
        public void Close()
        {
            if (!IsOpen) return;
            IsOpen = false; letters = false; pending = ""; Closed?.Invoke();
        }
        public void SetControllerActive(bool active)
        {
            if (active && !controller) { EnsureVisible(); clearSearchFocus = true; searchHasFocus = false; }
            controller = active;
        }
        public void ChangeKind(string kind)
        {
            if (kind != "bag" && kind != "home" && kind != "coast") throw new ArgumentOutOfRangeException(nameof(kind));
            if (kind == Kind) return;
            ContextRequested?.Invoke(kind); Kind = kind; ActivePane = 0; focus = 0; letters = false; pending = ""; message = ""; clearSearchFocus = true; Refresh(); EnsureVisible();
        }
        public void SetQuery(string value) { query = value ?? ""; Refresh(); }
        public void FocusSearch() { focus = 1; requestSearchFocus = true; clearSearchFocus = false; }
        public void SetCategory(int value) { category = Mathf.Clamp(value, 0, 5); Refresh(); }
        public void SetFavoritesOnly(bool value) { onlyFavorites = value; Refresh(); }
        public void SetSort(int value) { model.SetSort(Mathf.Clamp(value, 0, 3)); Refresh(); }
        public void SetFocus(int value) { focus = Mathf.Clamp(value, 0, 9); if (!IsStorage && focus == 6) focus = 7; if (focus != 1) clearSearchFocus = true; }
        public void SwitchPane(int pane) { ActivePane = IsStorage ? Mathf.Clamp(pane, 0, 1) : 0; focus = 0; clearSearchFocus = true; RememberSelection(); EnsureVisible(); }
        public void MoveSelection(int delta)
        {
            if (rows[ActivePane].Count == 0) return;
            SelectedIndex = Mathf.Clamp(SelectedIndex + delta, 0, rows[ActivePane].Count - 1); focus = 0;
        }
        public void Refresh()
        {
            for (int pane = 0; pane < 2; pane++)
            {
                string old = selected[pane]; int oldIndex = indices[pane];
                rows[pane].Clear();
                if (pane == 0) rows[pane].AddRange(model.Ids(model.State.Get("inventory"), query, category, onlyFavorites));
                else if (IsStorage) rows[pane].AddRange(model.Ids(model.Stock(Kind), query, category, onlyFavorites));
                int existing = old == "" ? -1 : rows[pane].IndexOf(old);
                indices[pane] = existing >= 0 ? existing : Mathf.Clamp(oldIndex, 0, Math.Max(0, rows[pane].Count - 1));
                selected[pane] = rows[pane].Count == 0 ? "" : rows[pane][indices[pane]];
                scroll[pane] = Mathf.Clamp(scroll[pane], 0, MaximumScroll(pane));
            }
            EnsureVisible();
        }
        void RememberSelection() { selected[ActivePane] = SelectedId; detailScroll = 0; }
        float MaximumScroll(int pane) => Math.Max(0, rows[pane].Count * RowHeight - LedgerHeight);
        void EnsureVisible()
        {
            if (!IsStorage) return;
            float top = indices[ActivePane] * RowHeight;
            if (top < scroll[ActivePane]) scroll[ActivePane] = top;
            else if (top + RowHeight > scroll[ActivePane] + LedgerHeight) scroll[ActivePane] = top + RowHeight - LedgerHeight;
            scroll[ActivePane] = Mathf.Clamp(scroll[ActivePane], 0, MaximumScroll(ActivePane));
        }

        /// <summary>Consumes the route's already-arbitrated snapshot, including real right-stick events.</summary>
        public void HandleInput(InputFrame frame, double delta)
        {
            if (!IsOpen || frame == null) return;
            // A sample is consumed once. Synchronous native probes can legitimately deliver several
            // distinct Input System samples before the next rendered frame.
            if (ReferenceEquals(lastHandledFrame, frame)) return;
            lastHandledFrame = frame; SetControllerActive(frame.ControllerActive);
            stickWait = Math.Max(0, stickWait - (float)delta); repeatWait = Math.Max(0, repeatWait - (float)delta);
            if (frame.Pressed("ui_cancel") || frame.Pressed("pause") && !SearchEditing)
            {
                if (pending != "") { pending = ""; return; }
                if (letters) { letters = false; focus = 1; return; }
                Close(); return;
            }
            bool accept = frame.Pressed("ui_accept") || frame.Pressed("interact");
            int horizontal = frame.Pressed("ui_right") ? 1 : frame.Pressed("ui_left") ? -1 : 0;
            int vertical = frame.Pressed("ui_down") ? 1 : frame.Pressed("ui_up") ? -1 : 0;
            if (pending != "")
            {
                if (horizontal != 0 || vertical != 0) pendingConfirm = !pendingConfirm;
                if (accept) { if (pendingConfirm) ConfirmPending(); else pending = ""; }
                return;
            }
            if (letters)
            {
                if (horizontal != 0) letterIndex = Mathf.Clamp(letterIndex + horizontal, 0, 29);
                if (vertical > 0) letterIndex = letterIndex < 13 ? letterIndex + 13 : letterIndex < 26 ? 26 + Math.Min(3, (letterIndex - 13) / 4) : letterIndex;
                if (vertical < 0) letterIndex = letterIndex >= 26 ? Math.Min(25, 13 + (letterIndex - 26) * 4) : Math.Max(0, letterIndex - 13);
                if (accept) ActivateLetter(letterIndex);
                return;
            }
            if (frame.Pressed("ui_next_tab")) CycleFocus(1);
            if (frame.Pressed("ui_prev_tab")) CycleFocus(-1);
            if (!controller && !IsStorage && !SearchEditing && frame.UiScroll.y != 0)
            {
                Vector2 point = new Vector2(frame.MousePosition.x * 1152f / Math.Max(1, Screen.width), (Screen.height - frame.MousePosition.y) * 648f / Math.Max(1, Screen.height));
                if (BagGridRect.Contains(point)) MoveSelection((frame.UiScroll.y < 0 ? 1 : -1) * Columns);
            }
            if (controller && frame.UiScroll.magnitude > .45f && stickWait <= 0)
            {
                if (focus == 7) detailScroll = Math.Max(0, detailScroll + Math.Sign(frame.UiScroll.y) * 28);
                else if (IsStorage && Math.Abs(frame.UiScroll.x) > Math.Abs(frame.UiScroll.y)) SwitchPane(frame.UiScroll.x < 0 ? 0 : 1);
                else if (Math.Abs(frame.UiScroll.y) > .3f) MoveSelection((frame.UiScroll.y > 0 ? 1 : -1) * (IsStorage ? 1 : Columns));
                stickWait = StickRepeatSeconds;
            }
            if (SearchEditing) return; // Typed A/W/S/D/P/I belongs to the search field.
            if (vertical == 0 && horizontal == 0 && repeatWait <= 0 && (controller || focus == 0))
            {
                if (frame.Held("ui_down")) vertical = 1; else if (frame.Held("ui_up")) vertical = -1;
                if (frame.Held("ui_right")) horizontal = 1; else if (frame.Held("ui_left")) horizontal = -1;
            }
            if (vertical != 0 || horizontal != 0) { Navigate(horizontal, vertical); repeatWait = .16f; }
            if (accept) ActivateFocused();
        }
        void CycleFocus(int direction)
        {
            focus = (focus + direction + 10) % 10;
            if (!IsStorage && focus == 6) focus = (focus + direction + 10) % 10;
            actionIndex = 0; if (focus != 1) clearSearchFocus = true;
        }
        void Navigate(int horizontal, int vertical)
        {
            switch (focus)
            {
                case 0:
                    if (IsStorage) { if (horizontal != 0) SwitchPane(horizontal < 0 ? 0 : 1); if (vertical != 0) MoveSelection(vertical); }
                    else MoveSelection(horizontal + vertical * Columns);
                    break;
                case 1: if (vertical != 0) CycleFocus(vertical); break;
                case 2: SetCategory((category + (horizontal != 0 ? horizontal : vertical) + 6) % 6); break;
                case 3: SetSort((model.Sort + (horizontal != 0 ? horizontal : vertical) + 4) % 4); break;
                case 4: if (horizontal != 0 || vertical != 0) SetFavoritesOnly(!onlyFavorites); break;
                case 5: actionIndex = Mathf.Clamp(actionIndex + (horizontal != 0 ? horizontal : vertical), 0, IsStorage ? 3 : 1); break;
                case 6: actionIndex = Mathf.Clamp(actionIndex + (horizontal != 0 ? horizontal : vertical), 0, 1); break;
                case 7: detailScroll = Math.Max(0, detailScroll + (vertical != 0 ? vertical : horizontal) * 24); break;
                case 8: ChangeKind((horizontal != 0 ? horizontal : vertical) > 0 ? Kind == "bag" ? "home" : Kind == "home" ? "coast" : "bag" : Kind == "bag" ? "coast" : Kind == "coast" ? "home" : "bag"); focus = 8; break;
                case 9: break;
            }
        }
        void ActivateFocused()
        {
            switch (focus)
            {
                case 0: if (IsStorage) ActivateTransfer(1); else UseSelected(); break;
                case 1: letters = true; letterIndex = 0; break;
                case 2: SetCategory((category + 1) % 6); break;
                case 3: SetSort((model.Sort + 1) % 4); break;
                case 4: SetFavoritesOnly(!onlyFavorites); break;
                case 5:
                    if (IsStorage) { if (actionIndex == 3) ToggleFavorite(); else ActivateTransfer(actionIndex == 0 ? 1 : actionIndex == 1 ? 10 : 0); }
                    else if (actionIndex == 0) UseSelected(); else ToggleFavorite();
                    break;
                case 6: RequestBulk(actionIndex == 0); break;
                case 7: focus = 0; break;
                case 8: ChangeKind(Kind == "bag" ? "home" : Kind == "home" ? "coast" : "bag"); focus = 8; break;
                case 9: Close(); break;
            }
        }
        void UseSelected()
        {
            string id = SelectedId;
            if (id == "" || CanUse == null || !CanUse(id)) return;
            UseRequested?.Invoke(id); Refresh();
        }
        public void ToggleFavorite()
        {
            if (SelectedId == "") return;
            model.ToggleFavorite(SelectedId); Refresh();
        }
        public void ActivateTransfer(long amount)
        {
            if (!IsStorage || SelectedId == "" || IsReadOnly) return;
            bool deposit = ActivePane == 0; long movable = model.Movable(SelectedId, deposit, Kind);
            if (amount == 0)
            {
                if (movable == 0) return;
                pending = "stack"; pendingItem = SelectedId; pendingAmount = movable; pendingDeposit = deposit; pendingConfirm = true;
            }
            else if (amount > 0 && amount <= movable)
            { if (model.Transfer(SelectedId, amount, deposit, Kind)) message = amount + T(" verplaatst.", " moved."); Refresh(); }
        }
        public void RequestBulk(bool existingOnly)
        {
            if (!IsStorage || IsReadOnly) return;
            pendingAmount = 0;
            foreach (string id in model.Ids(model.State.Get("inventory")))
            {
                if (model.Favorite(id) || (existingOnly ? model.StockCount(id, Kind) == 0 : model.ItemType(id) != "material")) continue;
                pendingAmount += model.Movable(id, true, Kind);
            }
            if (pendingAmount == 0) { message = T("Niets te verplaatsen. Favorieten blijven bij je.", "Nothing to move. Favorites stay with you."); return; }
            pending = existingOnly ? "existing" : "materials"; pendingItem = ""; pendingConfirm = true;
        }
        public void ConfirmPending()
        {
            if (pending == "") return;
            string action = pending; pending = "";
            // Revalidate at the moment of commit: opening a confirmation does not reserve storage room.
            if (IsReadOnly) { message = T("Loop naar de kist om te verplaatsen.", "Walk to the chest to move items."); return; }
            if (action == "stack")
            {
                if (pendingAmount > 0 && pendingAmount <= model.Movable(pendingItem, pendingDeposit, Kind) && model.Transfer(pendingItem, pendingAmount, pendingDeposit, Kind))
                    message = pendingAmount + T(" verplaatst.", " moved.");
                else message = T("De voorraad is veranderd. Kies de stapel opnieuw.", "The stock changed. Select the stack again.");
            }
            else { long moved = model.Bulk(action == "existing", Kind); message = moved + T(" verplaatst. Favorieten zijn overgeslagen.", " moved. Favorites were skipped."); }
            Refresh();
        }
        void ActivateLetter(int index)
        {
            if (index < 26) SetQuery(query + (char)('A' + index));
            else if (index == 26) SetQuery(query + " ");
            else if (index == 27) SetQuery(query.Length == 0 ? "" : query.Substring(0, query.Length - 1));
            else if (index == 28) SetQuery("");
            else { letters = false; focus = 0; }
        }

        void Styles()
        {
            text = new GUIStyle(GUI.skin.label) { font = catalog != null ? catalog.originalFont : GUI.skin.font, fontSize = 16, padding = new RectOffset(0, 0, 0, 0), normal = { textColor = Ink } };
            title = new GUIStyle(text) { fontSize = 23, fontStyle = FontStyle.Bold };
            small = new GUIStyle(text) { fontSize = 13, normal = { textColor = new Color(.70f, .79f, .76f) } };
            wrap = new GUIStyle(text) { wordWrap = true };
            number = new GUIStyle(small) { alignment = TextAnchor.MiddleRight, fontStyle = FontStyle.Bold, normal = { textColor = Ink } };
            button = new GUIStyle(text) { alignment = TextAnchor.MiddleCenter, padding = new RectOffset(6, 6, 3, 3) };
            entry = new GUIStyle(GUI.skin.textField) { font = text.font, fontSize = 15, padding = new RectOffset(10, 10, 5, 4), normal = { textColor = Ink }, focused = { textColor = Ink } };
        }
        static void Fill(Rect rect, Color color)
        { Color previous = GUI.color; GUI.color = color; GUI.DrawTexture(rect, Texture2D.whiteTexture); GUI.color = previous; }
        static void Border(Rect rect, Color color, float thickness = 1)
        {
            Fill(new Rect(rect.x, rect.y, rect.width, thickness), color); Fill(new Rect(rect.x, rect.yMax - thickness, rect.width, thickness), color);
            Fill(new Rect(rect.x, rect.y, thickness, rect.height), color); Fill(new Rect(rect.xMax - thickness, rect.y, thickness, rect.height), color);
        }
        void Card(Rect rect, bool strong = false)
        { Fill(rect, new Color(.035f, .071f, .080f, .98f)); Border(rect, strong ? Accent : new Color(.21f, .34f, .34f), strong ? 2 : 1); }
        void Label(Rect rect, string value, GUIStyle style = null, bool fit = false)
        {
            GUIStyle used = new GUIStyle(style ?? text);
            if (fit) while (used.fontSize > 11 && used.CalcSize(new GUIContent(value)).x > rect.width) used.fontSize--;
            GUI.BeginGroup(rect); GUI.Label(new Rect(0, 0, rect.width, rect.height), value, used); GUI.EndGroup();
        }
        bool Button(Rect rect, string label, bool focused = false, bool enabled = true)
        {
            Fill(rect, enabled ? (focused ? new Color(.18f, .36f, .33f) : new Color(.08f, .16f, .18f)) : new Color(.055f, .09f, .10f));
            Border(rect, focused ? Gold : enabled ? new Color(.25f, .39f, .39f) : new Color(.13f, .20f, .20f), focused ? 2 : 1);
            var style = new GUIStyle(button); style.normal.textColor = enabled ? Ink : new Color(.40f, .48f, .46f);
            while (style.fontSize > 11 && style.CalcSize(new GUIContent(label)).x > rect.width - 12) style.fontSize--;
            Label(rect, label, style);
            bool previous = GUI.enabled; GUI.enabled = previous && enabled && !controller;
            bool clicked = GUI.Button(rect, GUIContent.none, GUIStyle.none); GUI.enabled = previous; if (clicked) GUI.FocusControl(""); return clicked;
        }
        public void Draw()
        {
            if (!IsOpen) return;
            if (clearSearchFocus) { GUI.FocusControl(""); clearSearchFocus = false; searchHasFocus = false; }
            // The input source decides device ownership before OnGUI. Residual pointer events cannot
            // operate a scrollbar or focused text field while the controller still owns the menu.
            if (controller && (Event.current.isMouse || Event.current.type == EventType.ScrollWheel)) Event.current.Use();
            if (!controller && Event.current.type == EventType.MouseDown && Event.current.button == 1)
            {
                if (pending != "") pending = "";
                else if (letters) letters = false;
                else Close();
                Event.current.Use(); if (!IsOpen) return;
            }
            if (!controller && !IsStorage && !letters && pending == "" && Event.current.type == EventType.ScrollWheel && Event.current.delta.y != 0 && BagGridRect.Contains(Event.current.mousePosition))
            { if (lastHandledFrame == null || lastHandledFrame.UiScroll.y == 0) MoveSelection((Event.current.delta.y > 0 ? 1 : -1) * Columns); Event.current.Use(); }
            Styles(); LastRowsDrawn = 0; RenderedSelectedBounds = Rect.zero;
            bool underlyingEnabled = GUI.enabled; GUI.enabled = underlyingEnabled && !letters && pending == "";
            Fill(new Rect(0, 0, 1152, 648), new Color(.01f, .025f, .035f, .78f));
            Fill(new Rect(PanelRect.x + 6, PanelRect.y + 6, PanelRect.width, PanelRect.height), new Color(0, 0, 0, .3f));
            Card(PanelRect, true); Fill(new Rect(PanelRect.x + 2, PanelRect.y + 2, PanelRect.width - 4, 4), Accent);
            Label(new Rect(98, 82, 488, 34), Kind == "home" ? T("Huisvoorraad", "Home stock") : Kind == "coast" ? T("Havenkist", "Harbor chest") : T("Je spullen", "Your belongings"), title);
            string[] destinations = { "bag", "home", "coast" };
            string[] destinationNames = { T("Tas", "Backpack"), T("Huis", "Home"), T("Haven", "Harbor") };
            for (int i = 0; i < 3; i++) if (Button(new Rect(628 + i * 132, 84, 122, 30), destinationNames[i], Kind == destinations[i])) ChangeKind(destinations[i]);
            if (Button(new Rect(1034, 84, 20, 30), "×", focus == 9 && controller)) Close();
            string subtitle = !IsStorage ? T("Alles wat je bij je draagt; geen limiet op het aantal soorten.", "Everything you carry; no limit on the number of item kinds.")
                : IsReadOnly ? T("Voorraad op afstand · loop naar de kist om voorwerpen te verplaatsen.", "Viewing stock remotely · walk to the chest to move items.")
                : T("Binnen bereik · recepten gebruiken eerst je tas, daarna deze kist.", "Within reach · recipes use your backpack first, then this chest.");
            Label(new Rect(98, 119, 956, 22), subtitle, small, true);
            DrawFilters();
            if (IsStorage) DrawLedger(); else DrawBag();
            Label(new Rect(98, 598, 956, 18), message != "" ? message : controller
                ? T("Rechterstick: bladeren · schouderknoppen: bediening kiezen · A: bevestigen · B: terug", "Right stick: browse · shoulder buttons: select a control · A: confirm · B: back")
                : T("Pijlen: kiezen · E / Enter: gebruiken · PageUp / PageDown: bediening kiezen · Esc: terug", "Arrows: select · E / Enter: use · PageUp / PageDown: select a control · Esc: back"), small, true);
            GUI.enabled = underlyingEnabled;
            if (letters) DrawLetters();
            if (pending != "") DrawConfirmation();
            if (controller && GUI.GetNameOfFocusedControl() == "BlueMapInventorySearch") GUI.FocusControl("");
        }
        void DrawFilters()
        {
            Rect searchRect = new Rect(98, 150, 244, 30); Fill(searchRect, new Color(.04f, .09f, .10f)); Border(searchRect, focus == 1 && controller ? Gold : new Color(.25f, .39f, .39f), focus == 1 && controller ? 2 : 1);
            bool previous = GUI.enabled; GUI.enabled = previous && !controller;
            GUI.SetNextControlName("BlueMapInventorySearch"); string next = GUI.TextField(searchRect, query, entry);
            GUI.enabled = previous;
            if (requestSearchFocus && !controller && GUI.enabled) { GUI.FocusControl("BlueMapInventorySearch"); requestSearchFocus = false; }
            if (next != query) SetQuery(next);
            bool wasSearchFocused = searchHasFocus;
            searchHasFocus = !controller && GUI.GetNameOfFocusedControl() == "BlueMapInventorySearch";
            if (searchHasFocus) focus = 1;
            else if (focus == 1 && wasSearchFocused) focus = 0;
            if (query == "" && GUI.GetNameOfFocusedControl() != "BlueMapInventorySearch") Label(new Rect(109, 155, 221, 22), T("Zoek een voorwerp…", "Search for an item…"), small);
            if (Button(new Rect(350, 150, 66, 30), T("Letters", "Letters"), focus == 1 && controller)) { letters = true; letterIndex = 0; }
            string categoryLabel = T(categoriesNl[category], categoriesEn[category]);
            if (Button(new Rect(424, 150, 190, 30), categoryLabel + "  ›", focus == 2 && controller)) { SetCategory((category + 1) % 6); focus = 2; }
            if (Button(new Rect(622, 150, 235, 30), T("Volgorde: ", "Order: ") + T(sortsNl[model.Sort], sortsEn[model.Sort]) + "  ›", focus == 3 && controller)) { SetSort((model.Sort + 1) % 4); focus = 3; }
            if (Button(new Rect(865, 150, 187, 30), (onlyFavorites ? "★ " : "☆ ") + T("Favorieten", "Favorites"), focus == 4 && controller)) { SetFavoritesOnly(!onlyFavorites); focus = 4; }
        }
        void DrawBag()
        {
            Label(new Rect(98, 184, 496, 20), T("Bij je", "Carried") + " · " + rows[0].Count + T(" soorten", " kinds"), small);
            Label(new Rect(624, 184, 430, 20), T("Geselecteerd voorwerp", "Selected item"), small);
            int first = Page * PageSize, last = Math.Min(first + PageSize, rows[0].Count);
            for (int i = first; i < first + PageSize; i++)
            {
                int local = i - first; Rect rect = new Rect(98 + local % Columns * 84, 208 + local / Columns * 84, 76, 76);
                bool occupied = i < last, chosen = occupied && i == SelectedIndex;
                Fill(rect, chosen ? new Color(.13f, .26f, .31f) : new Color(.035f, .085f, .11f)); Border(rect, chosen ? Gold : new Color(.20f, .32f, .38f), chosen ? 2 : 1);
                if (!occupied) { Fill(new Rect(rect.x + 34, rect.y + 35, 8, 2), new Color(.12f, .22f, .26f)); continue; }
                string id = rows[0][i]; DrawIcon(id, new Rect(rect.x + 14, rect.y + 10, 48, 48));
                if (model.Favorite(id)) Label(new Rect(rect.x + 4, rect.y + 2, 18, 20), "★", new GUIStyle(small) { normal = { textColor = Gold } });
                Label(new Rect(rect.x + 3, rect.y + 55, 67, 18), "×" + model.State.Count(id), number, true);
                bool previous = GUI.enabled; GUI.enabled = previous && !controller;
                if (GUI.Button(rect, GUIContent.none, GUIStyle.none)) { SwitchPane(0); SelectedIndex = i; if (Event.current.clickCount > 1) UseSelected(); GUI.FocusControl(""); }
                GUI.enabled = previous; LastRowsDrawn++; if (chosen) RenderedSelectedBounds = rect;
            }
            if (rows[0].Count == 0) { Card(new Rect(119, 334, 454, 54)); Label(new Rect(133, 345, 426, 34), EmptyText(), new GUIStyle(wrap) { alignment = TextAnchor.MiddleCenter }); }
            DrawBagDetail();
            if (Button(new Rect(98, 548, 74, 34), "‹", false, Page > 0)) SelectedIndex = Math.Max(0, first - PageSize);
            Label(new Rect(184, 555, 322, 22), rows[0].Count == 0 ? T("Geen voorwerpen", "No items") : (first + 1) + "–" + last + " / " + rows[0].Count, new GUIStyle(small) { alignment = TextAnchor.MiddleCenter });
            if (Button(new Rect(520, 548, 74, 34), "›", false, last < rows[0].Count)) SelectedIndex = Math.Min(rows[0].Count - 1, first + PageSize);
            Label(new Rect(624, 547, 430, 37), SummaryText, new GUIStyle(small) { wordWrap = true });
        }
        void DrawBagDetail()
        {
            Rect card = new Rect(624, 208, 430, 328); Card(card, focus == 7 && controller);
            string id = SelectedId;
            if (id == "") { Label(new Rect(646, 230, 386, 80), T("Kies een voorwerp om de beschrijving te lezen.", "Select an item to read its description."), wrap); return; }
            DrawIcon(id, new Rect(644, 226, 48, 48)); Label(new Rect(707, 225, 325, 54), Tr(model.ItemName(id)), new GUIStyle(title) { fontSize = 20, wordWrap = true });
            string body = Tr(model.ItemDescription(id)); string uses = ItemUses?.Invoke(id) ?? "";
            if (uses != "") body += "\n\n" + Tr(uses);
            DrawDescription(new Rect(646, 290, 386, 142), body);
            bool usable = CanUse != null && CanUse(id);
            if (Button(new Rect(646, 448, 386, 34), consumables.Contains(id) ? T("Gebruiken", "Use") : T("Bij je · ", "Carried · ") + model.State.Count(id), focus == 5 && actionIndex == 0 && controller, usable)) UseSelected();
            if (Button(new Rect(646, 490, 386, 30), model.Favorite(id) ? T("★ Favoriet verwijderen", "★ Remove favorite") : T("☆ Favoriet bewaren", "☆ Keep as favorite"), focus == 5 && actionIndex == 1 && controller)) ToggleFavorite();
        }
        void DrawLedger()
        {
            Label(new Rect(98, 184, 468, 20), T("Bij je", "Carried") + " · " + rows[0].Count + T(" soorten", " kinds"), small);
            int count = model.Stock(Kind).Entries.Count();
            Label(new Rect(586, 184, 468, 20), (Kind == "home" ? T("Huis", "Home") : T("Haven", "Harbor")) + " · " + count + (Kind == "home" ? "/144" : "/12") + T(" soorten · ", " kinds · ") + (Kind == "home" ? "999" : "99") + T(" per stapel", " per stack"), small, true);
            DrawList(0, BagListRect); DrawList(1, StockListRect);
            Rect detail = new Rect(98, 430, 956, 76); Card(detail, focus == 7 && controller);
            string id = SelectedId;
            if (id == "") Label(new Rect(112, 445, 927, 46), T("Kies links wat je wilt opbergen, of rechts wat je wilt meenemen.", "Choose items to store on the left, or items to take on the right."), wrap);
            else
            {
                DrawIcon(id, new Rect(112, 448, 32, 32)); Label(new Rect(156, 438, 880, 24), Tr(model.ItemName(id)), new GUIStyle(text) { fontStyle = FontStyle.Bold }, true);
                string body = Tr(model.ItemDescription(id)); string uses = ItemUses?.Invoke(id) ?? ""; if (uses != "") body += "\n" + Tr(uses);
                DrawDescription(new Rect(156, 464, 880, 33), body);
            }
            long movable = id == "" ? 0 : model.Movable(id, ActivePane == 0, Kind);
            string arrow = ActivePane == 0 ? " →" : " ←";
            if (Button(new Rect(98, 516, 130, 34), "1" + arrow, focus == 5 && actionIndex == 0 && controller, movable >= 1)) ActivateTransfer(1);
            if (Button(new Rect(236, 516, 142, 34), "10" + arrow, focus == 5 && actionIndex == 1 && controller, movable >= 10)) ActivateTransfer(10);
            if (Button(new Rect(386, 516, 218, 34), T("Hele stapel", "Whole stack") + arrow, focus == 5 && actionIndex == 2 && controller, movable >= 1)) ActivateTransfer(0);
            if (Button(new Rect(612, 516, 218, 34), id != "" && model.Favorite(id) ? T("★ Favoriet", "★ Favorite") : T("☆ Favoriet", "☆ Favorite"), focus == 5 && actionIndex == 3 && controller, id != "")) ToggleFavorite();
            Label(new Rect(842, 523, 212, 22), movable + T(" verplaatsbaar", " movable"), small, true);
            if (Button(new Rect(98, 558, 468, 34), T("Bestaande stapels aanvullen", "Top up existing stacks"), focus == 6 && actionIndex == 0 && controller, !IsReadOnly)) RequestBulk(true);
            if (Button(new Rect(586, 558, 468, 34), T("Grondstoffen opbergen", "Store materials"), focus == 6 && actionIndex == 1 && controller, !IsReadOnly)) RequestBulk(false);
        }
        void DrawList(int pane, Rect view)
        {
            Card(view, focus == 0 && ActivePane == pane);
            bool previous = GUI.enabled; GUI.enabled = previous && !controller;
            Vector2 next = GUI.BeginScrollView(view, new Vector2(0, scroll[pane]), new Rect(0, 0, view.width - 17, Math.Max(view.height, rows[pane].Count * RowHeight)), false, true);
            GUI.enabled = previous;
            scroll[pane] = Mathf.Clamp(next.y, 0, MaximumScroll(pane));
            int first = Math.Max(0, (int)(scroll[pane] / RowHeight)), last = Math.Min(rows[pane].Count, (int)Math.Ceiling((scroll[pane] + view.height) / RowHeight));
            for (int i = first; i < last; i++)
            {
                Rect row = new Rect(2, i * RowHeight + 1, view.width - 21, RowHeight - 2); string id = rows[pane][i]; bool chosen = ActivePane == pane && i == indices[pane];
                Fill(row, chosen ? new Color(.16f, .30f, .29f) : i % 2 == 0 ? new Color(.045f, .10f, .11f) : new Color(.035f, .08f, .09f));
                if (chosen) { Border(row, Gold); RenderedSelectedBounds = new Rect(view.x + row.x, view.y + row.y - scroll[pane], row.width, row.height); }
                DrawIcon(id, new Rect(10, row.y + 4, 24, 24));
                Label(new Rect(43, row.y + 6, 314, 22), (model.Favorite(id) ? "★ " : "") + Tr(model.ItemName(id)), new GUIStyle(text) { fontSize = 15 }, true);
                long amount = pane == 0 ? model.State.Count(id) : model.StockCount(id, Kind); Label(new Rect(360, row.y + 6, 73, 22), "×" + amount, number, true);
                previous = GUI.enabled; GUI.enabled = previous && !controller;
                if (GUI.Button(row, GUIContent.none, GUIStyle.none)) { SwitchPane(pane); SelectedIndex = i; if (Event.current.clickCount > 1) ActivateTransfer(1); GUI.FocusControl(""); }
                GUI.enabled = previous; LastRowsDrawn++;
            }
            GUI.EndScrollView();
            if (rows[pane].Count == 0) Label(new Rect(view.x + 16, view.y + 70, view.width - 32, 62), EmptyText(), new GUIStyle(wrap) { alignment = TextAnchor.MiddleCenter, fontSize = 15 });
        }
        string EmptyText() => query != "" || category != 0 || onlyFavorites ? T("Geen voorwerpen met deze filters.", "No items match these filters.") : T("Hier is het nog leeg.", "There is nothing here yet.");
        void DrawDescription(Rect rect, string body)
        {
            var style = new GUIStyle(wrap) { fontSize = 15 }; float contentHeight = Math.Max(rect.height, style.CalcHeight(new GUIContent(body), rect.width - 18));
            detailScroll = Mathf.Clamp(detailScroll, 0, contentHeight - rect.height);
            bool previous = GUI.enabled; GUI.enabled = previous && !controller;
            Vector2 position = GUI.BeginScrollView(rect, new Vector2(0, detailScroll), new Rect(0, 0, rect.width - 18, contentHeight), false, contentHeight > rect.height);
            GUI.enabled = previous; detailScroll = position.y; Label(new Rect(0, 0, rect.width - 18, contentHeight), body, style); GUI.EndScrollView();
        }
        void DrawIcon(string id, Rect rect)
        {
            if (TryIcon(id, out Texture2D texture, out Rect atlasRect)) GUI.DrawTextureWithTexCoords(rect, texture, atlasRect);
        }
        public bool HasSourceIcon(string id) => TryIcon(id, out _, out _);
        bool TryIcon(string id, out Texture2D texture, out Rect atlasRect)
        {
            texture = null; atlasRect = Rect.zero;
            if (catalog == null || id == "") return false;
            string sheet = model.ItemSheet(id); string textureId = sheet == "items_equipment" ? "generated:equipment-icons" : aliases.TryGetValue(sheet, out string alias) ? alias : "png:assets/" + sheet + ".png";
            int density = densities.TryGetValue(sheet, out int value) ? value : 1;
            if (!sheets.TryGetValue(textureId, out texture))
            {
                texture = catalog.textures.FirstOrDefault(t => t.definition.id == textureId)?.texture;
                sheets[textureId] = texture;
            }
            if (texture == null) return false;
            float tile = 16 * density, left = model.ItemIcon(id) * tile;
            if (left < 0 || left + tile > texture.width || tile > texture.height) return false;
            atlasRect = new Rect(left / texture.width, (texture.height - tile) / texture.height, tile / texture.width, tile / texture.height); return true;
        }
        void DrawLetters()
        {
            Fill(new Rect(0, 0, 1152, 648), new Color(0, 0, 0, .65f)); Rect box = new Rect(142, 212, 868, 244); Card(box, true);
            Label(new Rect(164, 227, 824, 28), T("Zoekletters", "Search letters") + " · " + query, new GUIStyle(title) { fontSize = 19 }, true);
            for (int i = 0; i < 26; i++) if (Button(new Rect(164 + i % 13 * 64, 271 + i / 13 * 46, 56, 38), ((char)('A' + i)).ToString(), controller && letterIndex == i)) ActivateLetter(i);
            string[] edits = { T("Spatie", "Space"), T("Wis letter", "Delete letter"), T("Wis zoekveld", "Clear search"), T("Klaar", "Done") };
            for (int i = 0; i < 4; i++) if (Button(new Rect(164 + i * 208, 370, 200, 38), edits[i], controller && letterIndex == i + 26)) ActivateLetter(i + 26);
            Label(new Rect(164, 424, 824, 19), T("Pijlen: kiezen · A: letter · B: terug", "Directions: select · A: letter · B: back"), small);
        }
        void DrawConfirmation()
        {
            Fill(new Rect(0, 0, 1152, 648), new Color(0, 0, 0, .72f)); Rect box = new Rect(304, 218, 544, 220); Card(box, true);
            Label(new Rect(328, 237, 496, 30), T("Voorwerpen verplaatsen?", "Move these items?"), new GUIStyle(title) { fontSize = 21 });
            string body = pending == "stack" ? pendingAmount + " × " + Tr(model.ItemName(pendingItem)) + (pendingDeposit ? T(" naar de kist.", " to the chest.") : T(" naar je tas.", " to your backpack."))
                : pendingAmount + T(" voorwerpen naar de kist. Favorieten blijven bij je.", " items to the chest. Favorites stay with you.");
            Label(new Rect(328, 282, 496, 74), body, wrap);
            if (Button(new Rect(328, 375, 238, 38), T("Verplaatsen", "Move"), controller && pendingConfirm)) ConfirmPending();
            if (Button(new Rect(586, 375, 238, 38), T("Annuleren", "Cancel"), controller && !pendingConfirm)) pending = "";
        }
    }
}
