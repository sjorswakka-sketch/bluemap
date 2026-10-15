extends Control
## Non-blocking side feed. Existing GameState.toast listeners keep their public signal.
const Style:=preload("res://scripts/core/ui_style.gd")
const LIFE:=4.5
const MAX_ROWS:=4
var entries: Array[Dictionary]=[]
var stack: VBoxContainer
var tracker: Control
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	stack=VBoxContainer.new();stack.add_theme_constant_override("separation",6);stack.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(stack)
func accepts(message: String) -> bool:
	# Match the actual localized item template, rather than hard-coding Dutch or English.
	var prefix:=tr("Gekregen: %s").get_slice("%s",0)
	return prefix!="" and message.begins_with(prefix)
func push(message: String):
	entries.append({"text":message,"left":LIFE})
	while entries.size()>MAX_ROWS:entries.pop_front()
	rebuild()
func rebuild():
	for child in stack.get_children():stack.remove_child(child);child.queue_free()
	for entry in entries:
		var panel:=PanelContainer.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel",Style.flat(Color(.06,.13,.17,.93),Color("799b8d"),1));stack.add_child(panel)
		var label:=Label.new();label.text=entry.text;label.add_theme_font_size_override("font_size",16);label.add_theme_color_override("font_color",Color("e7e2bf"));label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.max_lines_visible=3;label.custom_minimum_size.x=280;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(label)
		entry["panel"]=panel
func _process(delta: float):
	visible=not GameState.input_locked() and not GameState.dialogue_open and not GameState.ended
	if not visible:return # menus cannot silently consume unread item receipts
	var removed:=false
	for entry in entries:entry.left-=delta
	while not entries.is_empty() and entries[0].left<=0:entries.pop_front();removed=true
	if removed:rebuild()
	var view:=get_viewport_rect().size
	var width:=minf(320,view.x*.34)
	var top:=maxf(100,tracker.get_global_rect().end.y+12) if is_instance_valid(tracker) and tracker.visible else 100.0
	stack.size.x=width
	var used:=0.0
	var budget:=maxf(90,view.y-210-top)
	for i in range(entries.size()-1,-1,-1):
		var entry: Dictionary=entries[i]
		var panel: PanelContainer=entry.panel
		var label: Label=panel.get_child(0);label.custom_minimum_size.x=maxf(160,width-22)
		var height:=maxf(42,panel.get_combined_minimum_size().y)+6
		panel.visible=used+height<=budget
		if panel.visible:used+=height
		panel.modulate.a=clampf(entry.left*2,0,1)
	stack.position=Vector2(view.x-width-16,top)
