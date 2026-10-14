extends CanvasLayer
const Journal := preload("res://scripts/core/craft_journal.gd")
const Data := preload("res://scripts/data/ext/beroepen.gd")
const Professions := preload("res://scripts/core/professions.gd")
const UiStyle := preload("res://scripts/core/ui_style.gd")
var world: Node
var panel: PanelContainer
var label: Label
func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",UiStyle.flat(Color(0.05,0.13,0.14,0.88),Color(0.55,0.8,0.65),1))
	add_child(panel)
	label = UiStyle.make_label("",15,Color(0.88,0.96,0.86))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(350,0)
	panel.add_child(label)
func _process(_delta: float) -> void:
	var goal := Journal.goal()
	panel.visible = goal != "" and not GameState.input_locked() and GameState.in_game
	if not panel.visible or not is_instance_valid(world): return
	var reason := Professions.craft_reason(goal)
	label.text = tr("Materiaaldoel: %s") % Journal.name_of(Data.RECIPES[goal].output) + "\n" + Journal.ingredient_status(goal) + "\n" + (tr("Alles bij je: maak via %s.") % Controls.action_label("crafting") if reason == "" else reason)
	panel.position = Vector2(world.hud.tracker_panel.position.x,world.hud.tracker_panel.position.y+world.hud.tracker_panel.size.y+8)
	panel.size = Vector2(world.hud.tracker_panel.size.x,0)
