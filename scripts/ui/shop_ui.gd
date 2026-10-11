extends CanvasLayer
## De winkel. Kopen met Enter/E, sluiten met Esc.

const UiStyle := preload("res://scripts/core/ui_style.gd")
const Art := preload("res://scripts/core/art.gd")
const Items := preload("res://scripts/data/items.gd")
const Shops := preload("res://scripts/data/shops.gd")

var root: Control
var title_label: Label
var coins_label: Label
var list: VBoxContainer
var desc_label: Label
var shop: Dictionary = {}
var active := false
var opened_frame := -1


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	root.visible = false
	GameState.shop_requested.connect(open)
	GameState.items_changed.connect(func() -> void:
		if active:
			coins_label.text = "Munten: %d" % GameState.coins)


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.06, 0.1, 0.22, 0.97), Color(0.45, 0.75, 1.0), 3))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(560, 0)
	panel.add_child(box)
	title_label = UiStyle.make_label("", 38, Color(0.6, 0.88, 1.0))
	box.add_child(title_label)
	coins_label = UiStyle.make_label("", 24, Color(1, 0.9, 0.4))
	box.add_child(coins_label)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	box.add_child(list)
	desc_label = Label.new()
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(0, 54)
	box.add_child(desc_label)
	var hint := Label.new()
	hint.text = "↑ ↓ kiezen  ·  E kopen  ·  Esc sluiten"
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func open(shop_id: String) -> void:
	shop = Shops.info(shop_id)
	title_label.text = shop["name"]
	coins_label.text = "Munten: %d" % GameState.coins
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
		child.queue_free()
	var first: Button = null
	var index := 0
	for entry: Dictionary in shop["items"]:
		if entry.has("if") and not GameState.check_all(entry["if"]):
			continue # nog niet te koop (bijvoorbeeld pijlen zonder boog)
		var info := Items.info(entry["item"])
		var owned: bool = entry.get("once", false) and GameState.count(entry["item"]) > 0
		var button := Button.new()
		button.text = "%s   —   %s" % [_label(entry), "gekocht" if owned else "%d munten" % entry["price"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiStyle.style_button(button, 22)
		button.disabled = owned
		button.icon = Items.icon_tex(entry["item"])
		button.pressed.connect(_buy.bind(entry, index))
		button.focus_entered.connect(func() -> void: desc_label.text = info["desc"])
		list.add_child(button)
		if first == null or index == focus_index:
			if not owned:
				first = button
		index += 1
	if first:
		first.grab_focus.call_deferred()
	else:
		desc_label.text = "Je hebt alles gekocht!"


## De naam van een winkelregel: een eigen `label`, anders de naam van het voorwerp (met het aantal erbij).
func _label(entry: Dictionary) -> String:
	if entry.has("label"):
		return entry["label"]
	var amount: int = entry.get("amount", 1)
	var item_name: String = Items.info(entry["item"])["name"]
	return item_name if amount == 1 else "%s x%d" % [item_name, amount]


func _buy(entry: Dictionary, index: int) -> void:
	var price: int = entry["price"]
	var amount: int = entry.get("amount", 1)
	if entry.get("once", false) and GameState.count(entry["item"]) > 0:
		return # eenmalige dingen koop je maar één keer
	if entry.has("if") and not GameState.check_all(entry["if"]):
		return # nog niet te koop
	if GameState.coins < price:
		Sound.play("error")
		GameState.toast.emit("Je hebt niet genoeg munten.")
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
	GameState.toast.emit("Gekocht: %s" % _label(entry))
	_populate(index)


## Waarom iets niet meer past: helemaal vol, of bijna vol (dan met hoeveel je er hebt, bijvoorbeeld "38 van de 40").
func _no_room_text(item_id: String) -> String:
	var info := Items.info(item_id)
	if GameState.room(item_id) > 0 and info.has("almost_full_text"):
		return "%s (%d van de %d)" % [info["almost_full_text"], GameState.count(item_id), int(info["max"])]
	return info.get("full_text", "Je tas is vol")


func _unhandled_input(event: InputEvent) -> void:
	if not active or Engine.get_process_frames() == opened_frame:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button:
			(focused as Button).pressed.emit()
