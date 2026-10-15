extends Node2D
## Quiet, local hydraulic feedback: actual bank geometry lives in the shared core definition.
const Art:=preload("res://scripts/core/art.gd")
const Rules:=preload("res://scripts/core/marsh_waterworks.gd")
const Maps:=preload("res://scripts/maps/registry.gd")
var world: Node2D
var time:=0.0
var level:=1.0
var exposed: Array[Vector2i]=[]
var last_frame:=-1
func _ready():
	add_to_group("marsh_waterworks");texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var rows: Array=Maps.get_map("kruipmoeras").rows
	for at: Vector2i in Rules.changes(rows,true,false):
		if rows[at.y][at.x]=="F":exposed.append(at)
	level=target_level()
func target_level() -> float:
	if GameState.flag("lw_drained"):return .25
	return .7 if GameState.flag("lw_sluice_west") and not GameState.flag("lw_sluice_east") else .9 if GameState.flag("lw_sluice_west") else 1.0
func _process(delta: float):
	time+=delta;level=move_toward(level,target_level(),delta*.32)
	var next:=int(time*10)
	if next!=last_frame:last_frame=next;queue_redraw()
func r(rect: Rect2,color: String):draw_rect(rect,Color(color))
func caption(at: Vector2,text: String,color: Color):
	var font:=ThemeDB.fallback_font;var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	draw_rect(Rect2(at-Vector2(width*.5+4,12),Vector2(width+8,17)),Color(.07,.13,.14,.93))
	draw_string(font,at-Vector2(width*.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
func _draw():
	# Receding water washes off the newly walkable mud bank over a short visible transition.
	if GameState.flag("lw_drained") and level>.26:
		for cell in exposed:draw_rect(Rect2(Vector2(cell)*32,Vector2(32,32)),Color(.28,.46,.40,clampf((level-.25)/.75,0,1)*.8))
	# Former high-water marks remain around the newly exposed eastern bank.
	if GameState.flag("lw_drained"):
		for y in range(16,20):
			for x in range(28,34):
				if world.map_data.rows[y][x]=="2":
					var at:=Vector2(x*32,y*32)
					draw_line(at+Vector2(7,25),at+Vector2(22,25),Color(.45,.46,.32,.38),1)
					draw_rect(Rect2(at+Vector2(5+(x+y)%6,16),Vector2(3,1)),Color("a0a17b"))
	# Railings lie on the outer edge; the whole two-tile deck stays open.
	for y in [16*32.0,18*32.0]:
		for x in [15*32.0+28,23*32.0+3]:
			r(Rect2(x-2,y-8,4,14),"4c5040");r(Rect2(x-2,y-8,4,2),"c0b28a")
		if GameState.flag("lw_bridge"):
			draw_line(Vector2(16*32,y),Vector2(23*32,y),Color("9e966a"),1)
		else:
			# Broken ends make the missing span readable before repair.
			for x in [16*32.0,22*32.0+17]:
				r(Rect2(x,y+(-5 if y>16*32 else 3),15,3),"8e7952")
	for entry in [["lw_sluice_west",Vector2(17.5,11.5),true],["lw_sluice_east",Vector2(35.5,18.5),false]]:
		var id: String=entry[0];var at: Vector2=entry[1]*32
		var opened:=GameState.flag(id)
		# Small timber sluice trough and a visibly lifted/lowered metal gate.
		r(Rect2(at+Vector2(-20,8),Vector2(40,12)),"414f44")
		r(Rect2(at+Vector2(-18,10),Vector2(36,8)),"547e73")
		for side in [-1,1]:
			r(Rect2(at+Vector2(side*18-2,-17),Vector2(4,38)),"635b42")
			r(Rect2(at+Vector2(side*18-2,-17),Vector2(4,2)),"bbb081")
		var gate_y:=-16.0 if opened else 1.0
		r(Rect2(at+Vector2(-16,gate_y),Vector2(32,8)),"81928a")
		r(Rect2(at+Vector2(-16,gate_y),Vector2(32,2)),"c0c5a9")
		for x in [-12,-4,4,12]:r(Rect2(at+Vector2(x,gate_y+2),Vector2(1,5)),"4d675f")
		var gauge:=at+Vector2(25,-20)
		r(Rect2(gauge,Vector2(5,38)),"344c45")
		r(Rect2(gauge+Vector2(1,38-34*level),Vector2(3,34*level)),"76b4af")
		for y in [3,15,27,37]:r(Rect2(gauge+Vector2(-2,y),Vector2(2,1)),"d2c492")
		caption(at+Vector2(0,35),(tr("West") if entry[2] else tr("Oost"))+" · "+(tr("open") if opened else tr("dicht")),Color("bed8a6") if opened else Color("dfc18a"))
		if opened:
			for i in 3:
				var phase:=fposmod(time*.6+i*.33,1)
				draw_line(at+Vector2(-14+phase*22,13+i%2*3),at+Vector2(-8+phase*22,13+i%2*3),Color(.67,.85,.77,.65),1)
	# Water follows the western channel rather than blinking on the dry archive route.
	if GameState.flag("lw_sluice_west"):
		for i in 5:
			var at:=Vector2(18.3+i*.6,12.4+fposmod(time*.32+i*.55,2.5))*32
			if world.map_data.rows[int(at.y/32)][int(at.x/32)]=="F":
				draw_line(at,at+Vector2(0,4),Color(.67,.85,.77,.65),1)
	# A recessed stair and masonry surround explain the existing one-tile archive portal.
	var origin:=Vector2(24,17)*32
	r(Rect2(origin+Vector2(1,1),Vector2(30,30)),"414f4a")
	r(Rect2(origin+Vector2(3,3),Vector2(26,26)),"879783")
	for i in 4:
		r(Rect2(origin+Vector2(6,6+i*5),Vector2(20,5)),"465f59" if GameState.flag("lw_drained") else "567f73")
		r(Rect2(origin+Vector2(6,6+i*5),Vector2(20,1)),"bbc4a4")
	if not GameState.flag("lw_drained"):
		draw_rect(Rect2(origin+Vector2(5,5),Vector2(22,23)),Color(.27,.47,.42,.74))
