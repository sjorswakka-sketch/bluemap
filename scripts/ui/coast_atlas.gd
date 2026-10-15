extends CanvasLayer
## An honest regional overview: walking links plus the selected real ferry route.
const Region:=preload("res://scripts/core/coastal_region.gd")
const Maps:=preload("res://scripts/maps/registry.gd")
const Journey:=preload("res://scripts/core/journey.gd")
const Style:=preload("res://scripts/core/ui_style.gd")
const POINTS:=[Vector2(60,50),Vector2(230,20),Vector2(400,20),Vector2(575,20),Vector2(230,88),Vector2(400,88)]
const WALK:=[[0,1],[1,2],[2,3],[4,5]]
var world: Node2D
var source: WeakRef
var map_id:=""
var selected:=""
var active:=false
var opened_frame:=-1
var root: Control
var panel: PanelContainer
var title: Label
var legend: Label
var detail: Label
var preview: Control
var buttons: Array[Button]=[]
var back: Button
func _ready():
	layer=15;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("coast_atlas")
	root=Control.new();root.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(root)
	var dim:=ColorRect.new();dim.set_anchors_preset(Control.PRESET_FULL_RECT);dim.color=Color(0.02,0.06,0.11,0.94);root.add_child(dim)
	panel=PanelContainer.new();Style.style_panel(panel);root.add_child(panel)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",6);panel.add_child(box)
	title=Style.make_label("",24,Color("efd39a"));box.add_child(title)
	preview=Control.new();preview.custom_minimum_size=Vector2(640,110);preview.draw.connect(draw_region);box.add_child(preview)
	legend=Style.make_label("",15,Color("b7d7d7"));box.add_child(legend)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);box.add_child(grid)
	for id: String in Region.IDS:
		var button:=Button.new();Style.style_button(button,17);button.custom_minimum_size=Vector2(209,40);grid.add_child(button);button.pressed.connect(select.bind(id));buttons.append(button)
	detail=Style.make_label("",17,Color("dfebe0"));detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size=Vector2(640,100);box.add_child(detail)
	back=Button.new();Style.style_button(back,18);back.custom_minimum_size=Vector2(0,40);back.pressed.connect(close);box.add_child(back)
	var focus: Array[Control]=[]
	focus.append_array(buttons);focus.append(back);Style.link_vertical(focus)
	for i in 6:
		var row:=i/3;var col:=i%3
		buttons[i].focus_neighbor_left=buttons[i].get_path_to(buttons[row*3+posmod(col-1,3)])
		buttons[i].focus_neighbor_right=buttons[i].get_path_to(buttons[row*3+(col+1)%3])
		buttons[i].focus_neighbor_top=buttons[i].get_path_to(back if row==0 else buttons[i-3])
		buttons[i].focus_neighbor_bottom=buttons[i].get_path_to(back if row==1 else buttons[i+3])
	back.focus_neighbor_top=back.get_path_to(buttons[3]);back.focus_neighbor_bottom=back.get_path_to(buttons[0])
	Controls.device_changed.connect(device_changed);Lang.changed.connect(language_changed);root.hide();refresh()
func valid_source() -> bool:
	var node: Node2D=source.get_ref() if source!=null else null
	return is_instance_valid(node) and not node.is_queued_for_deletion() and node.world==world and GameState.map_id==map_id and not GameState.transitioning and not GameState.ended and world.player.position.distance_to(node.position)<=64
func open(node: Node2D):
	if active or GameState.input_locked():return
	source=weakref(node);map_id=GameState.map_id
	if not valid_source():return
	active=true;selected=map_id;opened_frame=Engine.get_process_frames();GameState.set_ui("rg_atlas",true);root.show();refresh();layout()
	buttons[Region.IDS.find(selected)].grab_focus();device_changed(Controls.controller_active)
func select(id: String):
	if id not in Region.IDS:return
	selected=id;refresh();layout()
func language_changed(_locale: String):refresh()
func refresh():
	title.text=tr("Kustregio · kaart en verbindingen")
	legend.text=tr("Goud: wandelpad · blauw: gekozen veerroute · witte ring: hier")
	back.text=tr("Sluiten")
	for i in Region.IDS.size():buttons[i].text="%d. %s" % [i+1,tr(Maps.MAPS[Region.IDS[i]].DATA.name)]
	if selected=="":return
	var here: String=tr(Maps.MAPS[map_id].DATA.name)
	var description:=Region.hint(selected)
	if selected==map_id:
		detail.text=tr("Je bent hier: %s.") % here+"\n"+description
	else:
		var route: Array[String]=Journey.path(map_id,selected)
		var names: Array[String]=[]
		for id: String in route:names.append(tr(Maps.MAPS[id].DATA.name))
		var walk:=Region.walk_path(map_id,selected)
		if walk.is_empty():description+="\n"+tr("Met de veer: %s") % " → ".join(names)
		else:
			names.clear()
			for id: String in walk:names.append(tr(Maps.MAPS[id].DATA.name))
			description+="\n"+tr("Te voet: %s") % " → ".join(names)
			if route!=walk:
				names.clear()
				for id: String in route:names.append(tr(Maps.MAPS[id].DATA.name))
				description+="\n"+tr("Korter met de veer: %s") % " → ".join(names)
		detail.text=description
	preview.queue_redraw()
func device_changed(_pad: bool):
	for button in buttons+[back]:button.mouse_filter=Control.MOUSE_FILTER_IGNORE if Controls.controller_active else Control.MOUSE_FILTER_STOP
func layout():
	var viewport:=get_viewport().get_visible_rect().size;var wanted:=panel.get_combined_minimum_size()
	var factor:=minf(1,minf((viewport.x-32)/wanted.x,(viewport.y-32)/wanted.y))
	panel.scale=Vector2.ONE*factor;panel.size=wanted;panel.position=(viewport-wanted*factor)*.5
func close():active=false;root.hide();GameState.set_ui("rg_atlas",false)
func _process(_delta: float):
	if not active:return
	if not valid_source():close();return
	layout()
func _unhandled_input(event: InputEvent):
	if not active or Engine.get_process_frames()<=opened_frame or not Controls.allows_event(event):return
	if event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
	elif Style.activate_focused(root,event):get_viewport().set_input_as_handled()
func _exit_tree():
	if active:GameState.set_ui("rg_atlas",false)
func draw_region():
	preview.draw_rect(Rect2(Vector2.ZERO,preview.size),Color("285566"))
	for edge: Array in WALK:preview.draw_line(POINTS[edge[0]],POINTS[edge[1]],Color("deca91"),3)
	if selected!="" and map_id!="":
		var route:=Journey.path(map_id,selected)
		for i in range(route.size()-1):
			var a: int=Region.IDS.find(route[i]);var b: int=Region.IDS.find(route[i+1])
			if a<0 or b<0 or [a,b] in WALK or [b,a] in WALK:continue
			for n in 14:
				preview.draw_line(POINTS[a].lerp(POINTS[b],n/14.0),POINTS[a].lerp(POINTS[b],(n+.5)/14.0),Color("91dbdd"),2)
	for i in Region.IDS.size():
		var at: Vector2=POINTS[i];preview.draw_circle(at,12,Color("869d78"))
		if Region.IDS[i]==map_id:preview.draw_arc(at,16,0,TAU,24,Color("ecf1df"),2)
		if Region.IDS[i]==selected:preview.draw_arc(at,20,0,TAU,24,Color("f0d196"),2)
		preview.draw_string(ThemeDB.fallback_font,at+Vector2(-4,5),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f7e9c4"))
