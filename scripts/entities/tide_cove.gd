extends Node2D
## Collision changes only after the occupied bank is clear. Reloads resolve on dry shore.
const Tide:=preload("res://scripts/core/tides.gd")
const Tiles:=preload("res://scripts/data/tiles.gd")
const Style:=preload("res://scripts/core/ui_style.gd")
var world: Node2D
var flooded:=false
var held:=false
var last_state:=""
var status: Label
var badge: PanelContainer
var overlay: CanvasLayer
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("tide_cove")
	flooded=Tide.state(GameState.day_time) in ["high","falling"]
	overlay=CanvasLayer.new();overlay.layer=10;add_child(overlay)
	badge=PanelContainer.new();badge.add_theme_stylebox_override("panel",Style.flat(Color(0.03,0.10,0.15,0.88),Color("a1c3b6"),1));badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(badge)
	status=Style.make_label("",15,Color("e6dbc0"));status.custom_minimum_size=Vector2(380,0);status.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.add_child(status)
func occupied() -> bool:
	return Rect2(Vector2(Tide.BANK.position)*32,Vector2(Tide.BANK.size)*32).grow(10).has_point(world.player.position+Vector2(0,8))
func sync():
	var state:=Tide.state(GameState.day_time)
	var wants_water: bool=state in ["high","falling"]
	held=wants_water and not flooded and occupied()
	if wants_water!=flooded and not held:
		flooded=wants_water
		Tide.set_bank(world.map_data,"8" if flooded else "4")
		for y in range(Tide.BANK.position.y,Tide.BANK.end.y):
			for x in range(Tide.BANK.position.x,Tide.BANK.end.x):
				var cell:=Vector2i(x,y)
				world.tile_layer.set_cell(cell,0,preload("res://scripts/core/pixel_landscape.gd").atlas("ce_shore" if flooded else "ce_sand",cell.x,cell.y))
				if flooded:world.solid_cells[cell]=true
				else:world.solid_cells.erase(cell)
		world.tile_layer.update_internals()
		if is_instance_valid(world.landscape):world.landscape.refresh()
	if state=="rising" and last_state!="rising":
		GameState.toast.emit(tr("Het water komt op. Neem de hoge loopbrug of de lijnpalen; je kunt altijd terug."))
	last_state=state
func _process(_delta: float):
	if is_queued_for_deletion() or GameState.map_id!="tide_cove":return
	sync()
	badge.visible=not GameState.input_locked()
	var viewport:=get_viewport_rect().size
	status.text=(tr("Zandbank sluit zodra je veilig op de oever bent.") if held else Tide.label(GameState.day_time))+"\n"+tr("Hoge loopbrug: altijd open · veer: altijd beschikbaar")
	badge.size=Vector2(400,0);badge.position=Vector2((viewport.x-badge.size.x)/2,viewport.y-104)
	queue_redraw()
func _draw():
	# A fixed elevated railing makes the guaranteed route identifiable from either bank.
	for y in [11*32.0,13*32.0]:
		draw_line(Vector2(15*32,y),Vector2(37*32,y),Color("cebc8e"),2)
		for x in range(15,38,3):
			draw_line(Vector2(x*32,y-4),Vector2(x*32,y+5),Color("655f4a"),3)
	if GameState.count("td_line")>0:
		draw_line(Vector2(19.5,19.5)*32,Vector2(32.5,19.5)*32,Color("d7c38b"),1.5)
	# Exposed sand stays visibly wet, and rising tide gets a gentle moving edge.
	if not flooded:
		var t:=Time.get_ticks_msec()/1000.0
		for x in range(20,32):
			draw_line(Vector2(x*32+4,26*32+18),Vector2(x*32+22,26*32+18+sin(t+x)*2),Color("b6b29a"),1.5)
