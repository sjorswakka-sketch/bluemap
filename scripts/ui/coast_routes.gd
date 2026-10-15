extends CanvasLayer
## Route planning, reusable shore tool and an isolated, consequence-free steering prototype.
const Style:=preload("res://scripts/core/ui_style.gd")
const Tide:=preload("res://scripts/core/tides.gd")
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var source: WeakRef
var map_id:=""
var active:=false
var crossing:=false
var sailing:=false
var elapsed:=0.0
var start:=Vector2.ZERO
var landing:=Vector2.ZERO
var boat:=Vector2(85,110)
var boat_velocity:=Vector2.ZERO
var boat_angle:=0.0
var buoys: Array[Vector2]=[Vector2(170,80),Vector2(330,110),Vector2(530,65)]
var visited: Array[bool]=[false,false,false]
var opened_frame:=-1
var root: Control
var panel: PanelContainer
var box: VBoxContainer
var title: Label
var detail: Label
var preview: Control
var options: VBoxContainer
var buttons: Array[Button]=[]
var back: Button
var float_visual: Node2D
func _ready():
	layer=15;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("coast_routes")
	root=Control.new();root.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(root)
	var dim:=ColorRect.new();dim.set_anchors_preset(Control.PRESET_FULL_RECT);dim.color=Color(0.02,0.06,0.11,0.94);root.add_child(dim)
	panel=PanelContainer.new();Style.style_panel(panel);root.add_child(panel)
	box=VBoxContainer.new();box.add_theme_constant_override("separation",9);panel.add_child(box)
	title=Style.make_label("",26,Color("f1d295"));box.add_child(title)
	preview=Control.new();preview.custom_minimum_size=Vector2(600,150);preview.draw.connect(draw_preview);box.add_child(preview)
	detail=Style.make_label("",18,Color("d2e6e5"));detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size=Vector2(600,75);box.add_child(detail)
	options=VBoxContainer.new();options.add_theme_constant_override("separation",6);box.add_child(options)
	Controls.device_changed.connect(device_changed);Controls.bindings_changed.connect(refresh_steering);Lang.changed.connect(language_changed);root.hide()
func valid_source(distance:=true) -> bool:
	var station: Node2D=source.get_ref() if source!=null else null
	return is_instance_valid(station) and not station.is_queued_for_deletion() and station.world==world and GameState.map_id==map_id and not GameState.transitioning and not GameState.ended and (not distance or world.player.position.distance_to(station.position)<=64)
func open(station: Node2D):
	if active or GameState.input_locked():return
	source=weakref(station);map_id=GameState.map_id
	if not valid_source():return
	active=true;opened_frame=Engine.get_process_frames();GameState.set_ui("td_routes",true);root.show();rebuild()
func add_option(text: String,action: Callable,disabled:=false):
	var button:=Button.new();Style.style_button(button,18);button.text=text;button.custom_minimum_size=Vector2(600,42);button.disabled=disabled;options.add_child(button);button.pressed.connect(action);buttons.append(button)
func rebuild():
	for child in options.get_children():options.remove_child(child);child.queue_free()
	buttons.clear();preview.custom_minimum_size.y=150 if sailing else 100
	var station: Node2D=source.get_ref() if source!=null else null
	if station==null:return
	if sailing:
		title.text=tr("Proefhaven · vrij varen")
		refresh_steering()
	elif station.obj.role=="routes":
		title.text=tr("Bestemmingen en reisroutes")
		detail.text=tr("Alle veren zijn gratis en varen bij ieder getij. Meeuweneiland heeft een loopbrug naar de Getijdenbaai. De hoge route in de baai blijft open.")
		var maps: Script=load("res://scripts/maps/registry.gd")
		for route: Dictionary in station.obj.routes:
			add_option(tr("Veer naar %s · gratis") % tr(maps.MAPS[route.to].DATA.name),choose_route.bind(route))
		add_option(tr("Bekijk de kustregio"),open_atlas)
	elif station.obj.role=="kit":
		title.text=tr("Leenkist aan de baai")
		detail.text=tr("Leen een landingslijn voor beide lijnpalen. Zo steek je de baai over zonder de noordelijke omweg. Gratis, herbruikbaar en zonder verbruik. Je kunt ook gewoon over het hoge pad lopen.")
		add_option(tr("Landingslijn is al in je tas") if GameState.count("td_line")>0 else tr("Leen de landingslijn · gratis"),borrow,GameState.count("td_line")>0)
		add_option(tr("Probeer vrij varen in de proefhaven"),start_sailing)
	elif station.obj.role=="line":
		title.text=tr("Lijnpaal · korte oversteek")
		detail.text=tr("Nodig: landingslijn uit de gratis leenkist bij de westelijke steiger. De lijn blijft in je tas. Zonder lijn: volg het hoge pad naar het noorden.")
		add_option(tr("Steek over met je landingslijn") if GameState.count("td_line")>0 else tr("Ontbreekt: landingslijn · leen bij de steiger"),start_crossing,GameState.count("td_line")==0)
	else:
		title.text=tr("Getijdenbaai · drie routes")
		detail.text=Tide.label(GameState.day_time)+"\n"+tr("Zandbank: kort bij laagwater. Noordelijke loopbrug: altijd open. Lijnpalen: kort met een geleende landingslijn. De boot en westelijke loopbrug brengen je altijd terug.")
	add_option(tr("Terug naar de steiger") if sailing else tr("Sluiten"),close);back=buttons.back()
	var focusable: Array[Control]=[]
	for button in buttons:
		if not button.disabled:focusable.append(button)
	Style.link_vertical(focusable);device_changed(Controls.controller_active);layout();focusable[0].grab_focus();preview.queue_redraw()
func language_changed(_locale: String):
	if active and not crossing:rebuild()
func refresh_steering():
	if sailing:detail.text=tr("Stuur met %s / %s / %s / %s. Laat los om af te remmen. Vaar door de drie boeien; er is geen timer, schade of beloning. De gewone veer blijft je reisroute.") % [Controls.action_label("move_up"),Controls.action_label("move_left"),Controls.action_label("move_down"),Controls.action_label("move_right")]
func device_changed(_pad: bool):
	refresh_steering()
	for button in buttons:button.mouse_filter=Control.MOUSE_FILTER_IGNORE if Controls.controller_active else Control.MOUSE_FILTER_STOP
func layout():
	var viewport:=get_viewport().get_visible_rect().size
	var wanted:=panel.get_combined_minimum_size()
	var factor:=minf(1,minf((viewport.x-32)/wanted.x,(viewport.y-32)/wanted.y))
	panel.scale=Vector2.ONE*factor;panel.size=wanted;panel.position=(viewport-wanted*factor)*0.5
func borrow():
	if not active or not valid_source() or source.get_ref().obj.role!="kit" or GameState.count("td_line")>0:return
	GameState.give("td_line",1,true);GameState.save_requested.emit();Sound.play("ce_rope",-14);rebuild.call_deferred()
func choose_route(route: Dictionary):
	if not active or not valid_source():return
	var station: Node2D=source.get_ref()
	if route not in station.obj.get("routes",[]):return
	close()
	for voyage in get_tree().get_nodes_in_group("coast_voyage"):
		if not voyage.is_queued_for_deletion() and voyage.world==world: voyage.choose_route(station,route);return
func open_atlas():
	if not active or not valid_source():return
	var node: Node2D=source.get_ref();close()
	for ui in get_tree().get_nodes_in_group("coast_atlas"):
		if not ui.is_queued_for_deletion() and ui.world==world:ui.open(node);return
func start_sailing():
	if not active or not valid_source() or source.get_ref().obj.role!="kit":return
	sailing=true;visited=[false,false,false];boat=Vector2(85,110);boat_velocity=Vector2.ZERO;boat_angle=0;elapsed=0;rebuild()
func start_crossing():
	if not active or not valid_source() or source.get_ref().obj.role!="line" or GameState.count("td_line")<1:return
	var station: Node2D=source.get_ref()
	landing=Vector2(station.obj.landing[0]+0.5,station.obj.landing[1]+0.5)*32
	if not world.spawn_fits(landing):return
	start=world.player.position;crossing=true;elapsed=0;root.hide();world.player.facing=(landing-start).normalized();Sound.play("ce_rope",-14)
	float_visual=Node2D.new();float_visual.show_behind_parent=true;world.player.add_child(float_visual)
	float_visual.draw.connect(func():DrawUtil.sprite(float_visual,Art.tex("td_props"),4,0,Vector2(0,9),Vector2i(24,24),1.8))
	float_visual.queue_redraw()
func close():
	if crossing and valid_source(false):world.player.position=start
	if is_instance_valid(float_visual):float_visual.queue_free()
	crossing=false;sailing=false;active=false;root.hide();GameState.set_ui("td_routes",false)
func _process(delta: float):
	if not active:return
	if not valid_source(not crossing):close();return
	elapsed+=delta
	if crossing:
		world.player.position=start.lerp(landing,clampf(elapsed/1.1,0,1))+Vector2(0,sin(clampf(elapsed/1.1,0,1)*PI)*2)
		world.player.queue_redraw()
		if elapsed>=1.1:
			world.player.position=landing;world.player.velocity=Vector2.ZERO;crossing=false;close();GameState.save_requested.emit()
		return
	if sailing:steer(delta)
	layout();preview.queue_redraw()
func steer(delta: float):
	var input:=Input.get_vector("move_left","move_right","move_up","move_down")
	boat_velocity=boat_velocity.move_toward(input*150,400*delta)
	var next:=boat+boat_velocity*delta
	var rocks: Array[Rect2]=[Rect2(235,20,38,56),Rect2(395,104,45,46)]
	var bounds:=Rect2(24,22,preview.size.x-48,preview.size.y-42)
	next=next.clamp(bounds.position,bounds.end)
	for rock in rocks:
		if rock.grow(15).has_point(next):next=boat;boat_velocity=Vector2.ZERO
	boat=next
	for i in buoys.size():
		if boat.distance_to(buoys[i])<25:visited[i]=true
	if boat_velocity.length()>10:boat_angle=lerp_angle(boat_angle,boat_velocity.angle(),minf(1,delta*9))
func _unhandled_input(event: InputEvent):
	if not active or Engine.get_process_frames()<=opened_frame or not Controls.allows_event(event):return
	if event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
	elif not crossing and Style.activate_focused(root,event):get_viewport().set_input_as_handled()
func _exit_tree():
	if is_instance_valid(float_visual):float_visual.queue_free()
	if active:GameState.set_ui("td_routes",false)
func draw_preview():
	if sailing:
		preview.draw_style_box(Style.flat(Color("285a70"),Color("86b7b9"),1),Rect2(Vector2.ZERO,preview.size))
		for rock in [Rect2(235,20,38,56),Rect2(395,104,45,46)]:preview.draw_style_box(Style.flat(Color("5c7774"),Color("b3bea0"),2),rock)
		for i in buoys.size():
			preview.draw_arc(buoys[i],15,0,TAU,24,Color("91ddb6") if visited[i] else Color("e2cb85"),3 if visited[i] else 2)
		preview.draw_set_transform(boat,boat_angle)
		DrawUtil.sprite(preview,Art.tex("ce_boat"),int(elapsed*3)%2,0,Vector2.ZERO,Vector2i(48,32),0.85)
		preview.draw_set_transform(Vector2.ZERO)
	else:
		var x0:=70.0;var x1:=preview.size.x-70
		preview.draw_rect(Rect2(0,0,preview.size.x,preview.size.y),Color("285566"))
		for x in [x0,x1]:preview.draw_circle(Vector2(x,68),25,Color("91a67d"))
		preview.draw_polyline(PackedVector2Array([Vector2(x0,68),Vector2(x0,20),Vector2(x1,20),Vector2(x1,68)]),Color("dfcf9e"),4)
		for i in range(12):
			preview.draw_line(Vector2(x0+i*(x1-x0)/12.0,83),Vector2(x0+(i+0.6)*(x1-x0)/12.0,83),Color("b3c7b8") if Tide.state(GameState.day_time) in ["high","falling"] else Color("d6c6a0"),3)
		preview.draw_line(Vector2(x0,68),Vector2(x1,68),Color("d7bd83"),1.5)
