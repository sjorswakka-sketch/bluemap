extends CanvasLayer
## De winkel. Kopen met Enter/E, sluiten met Esc.

const UiStyle := preload("res://scripts/core/ui_style.gd")
const Art := preload("res://scripts/core/art.gd")
const Items := preload("res://scripts/data/items.gd")
const Shops := preload("res://scripts/data/shops.gd")

var root: Control
var panel: PanelContainer
var title_label: Label
var coins_label: Label
var list: VBoxContainer
var desc_label: Label
var hint: Label
var close_button: Button
var scroll: ScrollContainer
var shop: Dictionary = {}
var active := false
var opened_frame := -1


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	root.visible = false
	GameState.shop_requested.connect(open)
	Lang.changed.connect(_refresh_language)
	GameState.items_changed.connect(func() -> void:
		if active:
			coins_label.text = tr("Munten: %d") % GameState.coins)


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	root.add_child(dim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.06, 0.1, 0.22, 0.97), Color(0.45, 0.75, 1.0), 3))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(560, 0)
	panel.add_child(box)
	title_label = UiStyle.make_label("", 30, Color(0.6, 0.88, 1.0))
	box.add_child(title_label)
	coins_label = UiStyle.make_label("", 24, Color(1, 0.9, 0.4))
	box.add_child(coins_label)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	scroll.add_child(list)
	desc_label = Label.new()
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(0, 54)
	box.add_child(desc_label)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	close_button = Button.new()
	UiStyle.style_button(close_button, 20)
	close_button.custom_minimum_size.y = 38
	close_button.text = tr("Sluiten")
	close_button.pressed.connect(close)
	box.add_child(close_button)


func open(shop_id: String) -> void:
	shop = Shops.info(shop_id)
	title_label.text = tr(shop["name"])
	coins_label.text = tr("Munten: %d") % GameState.coins
	_populate(0)
	active = true
	root.visible = true
	opened_frame = Engine.get_process_frames()
	GameState.set_ui("shop", true)


func close() -> void:
	active = false
	root.visible = false
	GameState.set_ui("shop", false)


func _populate(focus_index: int) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var controls: Array[Control] = []
	var first: Button = null
	var index := 0
	for entry: Dictionary in shop["items"]:
		if entry.has("if") and not GameState.check_all(entry["if"]):
			continue # nog niet te koop (bijvoorbeeld pijlen zonder boog)
		var info := Items.info(entry["item"])
		var owned: bool = entry.get("once", false) and GameState.count(entry["item"]) > 0
		var button := Button.new()
		var price: int = entry["price"]
		# Vertalers: achter iets in de winkel dat je maar één keer kunt kopen en al hebt; anders de prijs
		button.text = "%s   —   %s" % [_label(entry), tr("gekocht") if owned else tr_n("%d munt", "%d munten", price) % price]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiStyle.style_button(button, 22)
		button.disabled = owned
		button.icon = Items.icon_tex(entry["item"])
		button.pressed.connect(_buy.bind(entry, index))
		button.focus_entered.connect(func() -> void: desc_label.text = tr(info["desc"]))
		list.add_child(button)
		if not owned:
			controls.append(button)
		if first == null or index == focus_index:
			if not owned:
				first = button
		index += 1
	controls.append(close_button)
	UiStyle.link_vertical(controls)
	if first:
		UiStyle.focus_if_visible.call_deferred(first)
	else:
		desc_label.text = tr("Je hebt alles gekocht!")
		UiStyle.focus_if_visible.call_deferred(close_button)


## De naam van een winkelregel (vertaald): een eigen `label`, anders de naam van het voorwerp (met het aantal erbij).
func _label(entry: Dictionary) -> String:
	if entry.has("label"):
		return tr(entry["label"])
	var amount: int = entry.get("amount", 1)
	var item_name := tr(Items.info(entry["item"])["name"])
	return item_name if amount == 1 else "%s x%d" % [item_name, amount]


func _buy(entry: Dictionary, index: int) -> void:
	if not active:
		return
	var price: int = entry["price"]
	var amount: int = entry.get("amount", 1)
	if entry.get("once", false) and GameState.count(entry["item"]) > 0:
		return # eenmalige dingen koop je maar één keer
	if entry.has("if") and not GameState.check_all(entry["if"]):
		return # nog niet te koop
	if GameState.coins < price:
		Sound.play("error")
		GameState.toast.emit(tr("Je hebt niet genoeg munten."))
		return
	if GameState.room(entry["item"]) < amount:
		Sound.play("error")
		GameState.toast.emit(_no_room_text(entry["item"]))
		return
	GameState.add_coins(-price)
	GameState.give(entry["item"], amount, true)
	for extra: Array in entry.get("with", []):
		GameState.give(extra[0], int(extra[1]), true)
	Sound.play("buy")
	GameState.toast.emit(tr("Gekocht: %s") % _label(entry))
	_populate(index)


## Waarom iets niet meer past: helemaal vol, of bijna vol (dan met hoeveel je er hebt, bijvoorbeeld "38 van de 40").
func _no_room_text(item_id: String) -> String:
	var info := Items.info(item_id)
	if GameState.room(item_id) > 0 and info.has("almost_full_text"):
		# Vertalers: melding dat iets bijna vol is, met hoeveel je hebt en het maximum: "Je pijlenkoker zit bijna vol (38 van de 40)"
		return tr("%s (%d van de %d)") % [tr(info["almost_full_text"]), GameState.count(item_id), int(info["max"])]
	return GameState.full_text(item_id)


func _unhandled_input(event: InputEvent) -> void:
	if not Controls.allows_event(event):
		return
	if not active or Engine.get_process_frames() == opened_frame or event.is_echo():
		return
	if UiStyle.shortcut(event, "pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif UiStyle.activate_focused(root, event):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if active:
		panel.size = panel.get_combined_minimum_size()
		var factor := minf(1.0, minf((root.size.x - 24.0) / panel.size.x, (root.size.y - 24.0) / panel.size.y))
		panel.scale = Vector2.ONE * maxf(factor, 0.1)
		panel.position = (root.size - panel.size * panel.scale) * 0.5
		hint.text = tr("↑ ↓ kiezen  ·  %s kopen  ·  %s sluiten") % [Controls.action_label("ui_accept"), Controls.action_label("ui_cancel")]


func _exit_tree() -> void:
	if active:
		GameState.set_ui("shop", false)


func _refresh_language(_locale: String) -> void:
	close_button.text = tr("Sluiten")
	if active:
		var focused := get_viewport().gui_get_focus_owner()
		var index := focused.get_index() if focused != null and focused.get_parent() == list else 0
		title_label.text = tr(shop["name"])
		coins_label.text = tr("Munten: %d") % GameState.coins
		_populate(index)
