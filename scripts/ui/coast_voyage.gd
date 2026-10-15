extends CanvasLayer
## A free, cancellable presentation before handing off to the existing map travel.
const Style:=preload("res://scripts/core/ui_style.gd")
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var source: WeakRef
var from_map:=""
var target:=""
var spawn:=""
var active:=false
var committing:=false
var elapsed:=0.0
var opened_frame:=-1
var root: Control
var panel: PanelContainer
var title: Label
var detail: Label
var preview: Control
var arrive: Button
var back: Button
const DURATION:=2.2
func _ready():
	layer=14;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("coast_voyage")
	root=Control.new();root.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(root)
	var dim:=ColorRect.new();dim.set_anchors_preset(Control.PRESET_FULL_RECT);dim.color=Color(0.02,0.06,0.11,0.90);root.add_child(dim)
	panel=PanelContainer.new();Style.style_panel(panel);root.add_child(panel)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",12);panel.add_child(box)
	title=Style.make_label("",28,Color("f1d295"));box.add_child(title)
	preview=Control.new();preview.custom_minimum_size=Vector2(600,130);preview.draw.connect(draw_trip);box.add_child(preview)
	detail=Style.make_label("",19,Color("d2e6e5"));detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size=Vector2(600,50);box.add_child(detail)
	arrive=Button.new();Style.style_button(arrive,20);arrive.custom_minimum_size=Vector2(0,44);box.add_child(arrive);arrive.pressed.connect(depart)
	back=Button.new();Style.style_button(back,20);back.custom_minimum_size=Vector2(0,44);box.add_child(back);back.pressed.connect(close)
	Style.link_vertical([arrive,back])
	Controls.device_changed.connect(device_changed);Lang.changed.connect(language_changed)
	root.hide();refresh()
func valid_source() -> bool:
	if source==null:return false
	var dock: Node2D=source.get_ref()
	if not is_instance_valid(dock) or dock.is_queued_for_deletion() or dock.world!=world or GameState.map_id!=from_map or GameState.transitioning or GameState.ended or world.player.position.distance_to(dock.position)>64:return false
	if dock.obj.has("routes"):return {"to":target,"spawn":spawn} in dock.obj.routes
	return dock.obj.to==target and dock.obj.spawn==spawn
func offer(dock: Node2D):
	source=weakref(dock);from_map=GameState.map_id;target=dock.obj.to;spawn=dock.obj.spawn
	if valid_source():GameState.start_dialogue(dock.obj.talk)
func choose_route(station: Node2D,route: Dictionary):
	if active or committing or GameState.input_locked() or route not in station.obj.get("routes",[]):return
	source=weakref(station);from_map=GameState.map_id;target=route.to;spawn=route.spawn
	begin()
func begin():
	if active or committing or GameState.input_locked() or not valid_source():return
	active=true;elapsed=0;opened_frame=Engine.get_process_frames()
	GameState.set_ui("ce_voyage",true);root.show();refresh();layout()
	arrive.grab_focus();Sound.play("ce_rope",-14.0)
func language_changed(_language: String):refresh()
func refresh():
	title.text=tr("Overtocht naar %s") % tr(load("res://scripts/maps/registry.gd").MAPS[target].DATA.name) if target!="" else tr("Veerboot")
	detail.text=tr("Een korte, gratis overtocht. Je spullen en gezondheid veranderen niet.")
	arrive.text=tr("Meteen aankomen");back.text=tr("Terug naar de steiger")
func layout():
	var viewport:=get_viewport().get_visible_rect().size
	var wanted:=panel.get_combined_minimum_size()
	var scale:=minf(1.0,minf((viewport.x-32)/wanted.x,(viewport.y-32)/wanted.y))
	panel.scale=Vector2.ONE*scale;panel.size=wanted;panel.position=(viewport-wanted*scale)*0.5
func device_changed(_pad: bool):
	for button in [arrive,back]:button.mouse_filter=Control.MOUSE_FILTER_IGNORE if Controls.controller_active else Control.MOUSE_FILTER_STOP
func close():
	if committing:return
	active=false;root.hide();GameState.set_ui("ce_voyage",false)
func depart():
	if committing or not active:return
	if not valid_source():close();return
	var maps: Script=load("res://scripts/maps/registry.gd")
	if not maps.MAPS.has(target) or not maps.get_map(target).spawns.has(spawn):close();return
	committing=true;active=false;root.hide();GameState.set_ui("ce_voyage",false)
	Sound.play("ce_water",-15.0)
	world.travel(target,spawn,"")
func _process(delta: float):
	if not active:return
	if not valid_source():close();return
	elapsed+=delta;layout();device_changed(Controls.controller_active);preview.queue_redraw()
	if elapsed>=DURATION:depart()
func _unhandled_input(event: InputEvent):
	if not active or Engine.get_process_frames()<=opened_frame or not Controls.allows_event(event):return
	if event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
	elif Style.activate_focused(root,event):get_viewport().set_input_as_handled()
func _exit_tree():
	if active:GameState.set_ui("ce_voyage",false)
func draw_trip():
	var size:=preview.size
	var start:=Vector2(55,size.y*0.65);var end:=Vector2(size.x-55,size.y*0.65)
	var progress:=clampf(elapsed/DURATION,0,1)
	preview.draw_line(start,end,Color("48767b"),2)
	for i in 9:
		var at:=start.lerp(end,i/8.0)
		preview.draw_circle(at,2,Color("9fc9c6"))
	var boat:=start.lerp(end,progress)+Vector2(0,-10+sin(elapsed*4)*2)
	DrawUtil.sprite(preview,Art.tex("ce_boat"),int(elapsed*3)%2,0,boat,Vector2i(48,32),1.8)
	preview.draw_arc(start,16,0,TAU,24,Color("c4b582"),2)
	preview.draw_arc(end,16,0,TAU,24,Color("9bc3a8"),2)
