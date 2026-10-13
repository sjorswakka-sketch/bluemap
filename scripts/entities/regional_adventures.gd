extends Node2D
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
const Region:=preload("res://scripts/core/regional_adventures.gd")
var world: Node2D
var time:=0.0
var water:=3
var heat:=0.0
var exposure:=0.0
var last_shelter:=Vector2(4.5,19.5)*32
var status_layer: CanvasLayer
var status: Label
var gauge: ProgressBar
var panel: PanelContainer
const SHELTERS: Array[Vector2]=[Vector2(4.5,18.5)*32,Vector2(15.5,5.5)*32,Vector2(28.5,18.5)*32]
const WIND:=Rect2(10*32,5*32,8*32,2*32)

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_to_group("regional_director")
	if GameState.map_id not in ["sunwell","ridgepass"]: return
	status_layer=CanvasLayer.new()
	add_child(status_layer)
	panel=PanelContainer.new()
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status_layer.add_child(panel)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("182d3be8")
	style.content_margin_left=12
	style.content_margin_right=12
	style.content_margin_top=6
	style.content_margin_bottom=6
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new()
	panel.add_child(column)
	status=Label.new()
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size",16)
	column.add_child(status)
	gauge=ProgressBar.new()
	gauge.show_percentage=false
	gauge.custom_minimum_size.y=6
	column.add_child(gauge)

func refill(safe: Vector2) -> void:
	water=3
	heat=0
	last_shelter=safe
	GameState.toast.emit(tr("Waterzak gevuld: 3 slokken. Schaduw houdt je koel; de blauwe luifels hebben water."))

func sheltered(at: Vector2) -> bool:
	for shelter in SHELTERS:
		if at.distance_to(shelter)<62: return true
	return at.distance_to(Vector2(34.5,5.5)*32)<70 and GameState.flag("ra_spring")

func wind_phase() -> int:
	var phase:=fmod(time,10.0)
	return 2 if phase>=8 else (1 if phase>=6 else 0)

func advance(delta: float) -> void:
	if GameState.input_locked() or GameState.ended: return
	time+=delta
	var at: Vector2=world.player.position
	if GameState.map_id=="sunwell" and not GameState.flag("ra_spring"):
		if sheltered(at):
			heat=maxf(heat-delta*3,0)
		else:
			heat+=delta
			if heat>=6:
				heat=0
				if water>0:
					water-=1
					Sound.play("ra_water",-14)
				else:
					world.player.position=last_shelter
					world.player.velocity=Vector2.ZERO
					world.player.knockback=Vector2.ZERO
					refill(last_shelter)
					GameState.toast.emit(tr("De hitte wordt te veel. Je rust bij de laatste luifel; je spullen en hartjes blijven behouden."))
	elif GameState.map_id=="ridgepass":
		if WIND.has_point(at) and wind_phase()==2 and not GameState.flag("ra_rope"):
			exposure+=delta
			if exposure>=0.65:
				world.player.position=Vector2(9.5 if at.x<14*32 else 18.5,6.5)*32
				world.player.velocity=Vector2.ZERO
				world.player.knockback=Vector2.ZERO
				exposure=0
				GameState.toast.emit(tr("Een windstoot! Wacht naast de wimpel tot hij weer slap hangt, of gebruik het vastgezette touw."))
		else: exposure=0

func _physics_process(delta: float) -> void:
	advance(delta)
	queue_redraw()
	if status==null: return
	panel.visible=not GameState.input_locked() and not GameState.ended
	if not panel.visible: return
	if GameState.map_id=="sunwell":
		status.text=tr("De bron stroomt — de kloof is koel") if GameState.flag("ra_spring") else tr("Water: %d/3 • %s") % [water,tr("In de schaduw") if sheltered(world.player.position) else tr("Zoek de volgende blauwe luifel")]
		gauge.value=0 if GameState.flag("ra_spring") else heat*100/6
	else:
		status.text=tr("Touw vast — veilige oversteek") if GameState.flag("ra_rope") else [tr("Windstil — steek nu over"),tr("Wimpels spannen — zoek dekking"),tr("Windstoot — wacht naast de pas")][wind_phase()]
		gauge.value=fmod(time,10)*10
	var viewport_size:=get_viewport_rect().size
	var right_edge: float=world.hud.tracker_panel.position.x-12.0
	var left_edge:=250.0
	panel.size.x=minf(410,maxf(200,right_edge-left_edge))
	panel.size.y=0
	panel.position=Vector2(left_edge+maxf(0,(right_edge-left_edge-panel.size.x)/2),110)
	if viewport_size.x<800: panel.position=Vector2(16,viewport_size.y-panel.size.y-16)

func _draw() -> void:
	match GameState.map_id:
		"sunwell":
			# Solid mesas replace repeated standalone boulders; edges follow real collisions.
			for y in world.map_size.y:
				for x in world.map_size.x:
					if str(world.map_data.rows[y])[x]!="q": continue
					var at:=Vector2(x+0.5,y+0.5)*32
					DrawUtil.sprite(self,Art.tex("ra_cliff"),(x+y*3)%3,0,at)
					if y+1<world.map_size.y and str(world.map_data.rows[y+1])[x]!="q":
						draw_rect(Rect2(x*32,y*32+23,32,9),Color("977049"))
						draw_line(Vector2(x*32,y*32+23),Vector2(x*32+32,y*32+23),Color("e0b67d"),2)
					if x+1<world.map_size.x and str(world.map_data.rows[y])[x+1]!="q":
						draw_line(Vector2(x*32+30,y*32),Vector2(x*32+30,y*32+32),Color("9e754b"),3)
			for at in SHELTERS:
				DrawUtil.ellipse(self,at,Vector2(62,48),Color(0.13,0.34,0.42,0.26))
				DrawUtil.sprite(self,Art.tex("ra_shelter"),0,0,at+Vector2(0,-35),Vector2i(40,24))
			# Heat motes become cool droplets after the spring is restored.
			for i in 35:
				var at:=Vector2(64+fmod(i*157+time*9,1080),64+fmod(i*83,620))
				if not world.is_solid(at): draw_circle(at,1,Color("9ddbd1") if GameState.flag("ra_spring") else Color("e8bb72"))
		"ridgepass":
			DrawUtil.sprite(self,Art.tex("ra_shelter"),0,0,Vector2(24.5,15.2)*32,Vector2i(40,24),2,Color("c7b394"))
			var color: Color=[Color("87b4c4"),Color("f6cf7b"),Color("ebf6fa")][wind_phase()]
			for x in [9.5,18.5]:
				var at:=Vector2(x,4.5)*32
				draw_line(at,at+Vector2(0,36),Color("83745d"),3)
				var tip:=Vector2(8+wind_phase()*8,16 if wind_phase()==0 else sin(time*18)*3)
				draw_colored_polygon(PackedVector2Array([at,at+tip,at+Vector2(0,10)]),color)
			if GameState.flag("ra_rope"):
				draw_line(Vector2(9.5,5.1)*32,Vector2(18.5,5.1)*32,Color("ceb888"),3)
			elif wind_phase()>0:
				for i in 22:
					var at:=Vector2(10*32+fmod(time*140+i*39,256),5*32+fmod(i*17,64))
					draw_line(at,at+Vector2(17,4),Color(color,0.5),1)
		"dorstvallei":
			DrawUtil.sprite(self,Art.tex("ra_shelter"),0,0,Vector2(14.5,10.5)*32,Vector2i(40,24))
			entrance(Vector2(24.5,3.5)*32,0)
			if GameState.flag("ra_spring"):
				var at:=Vector2(17.5,12.5)*32 if GameState.flag("ra_water_wild") else Vector2(24.5,15.5)*32
				DrawUtil.ellipse(self,at,Vector2(32,16),Color("648d81"))
				DrawUtil.ellipse(self,at,Vector2(26,10),Color("6fafbd"))
				for i in 3: draw_arc(at,8+fmod(time*5+i*8,20),0,TAU,24,Color(0.8,0.94,1,0.45),1)
				if GameState.flag("ra_water_wild"):
					DrawUtil.sprite(self,Art.tex("zandhaas"),int(time*2)%2,0,at+Vector2(35+sin(time)*3,-10))
				else:
					DrawUtil.sprite(self,Art.tex("ra_shelter"),0,0,at+Vector2(0,-44),Vector2i(40,24))
		"ijsdal": entrance(Vector2(43.5,3.5)*32,1)
		"kruipmoeras": entrance(Vector2(24.5,17.5)*32,2)
		"reedvault":
			for x in range(7,19):
				draw_rect(Rect2(x*32,14*32,30,3),Color("9d996f"))
			# Watermarks on the floor and a continuous route to the dry reading gallery.
			for x in range(3,25):
				draw_line(Vector2(x*32,7.4*32),Vector2(x*32+18,7.4*32),Color("659d9c"),2)
			for at in [Vector2(5.5,15.5),Vector2(5.5,4.5),Vector2(23.5,4.5)]:
				DrawUtil.ellipse(self,at*32,Vector2(30,22),Color(0.82,0.7,0.43,0.18))

func entrance(at: Vector2, style: int) -> void:
	# The portal remains a clear walk-through opening, with no invisible new walls.
	if style==2:
		DrawUtil.sprite(self,Art.tex("ra_hatch"),0,0,at)
		return
	DrawUtil.sprite(self,Art.tex("ra_entrances"),style,0,at+Vector2(0,-21),Vector2i(48,40))
