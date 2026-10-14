extends Node2D
## Decoration stays on existing solid countertops; no new bodies or map slots.
const Prof:=preload("res://scripts/core/professions.gd")
const Journal:=preload("res://scripts/core/craft_journal.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
const Art:=preload("res://scripts/core/art.gd")
var world: Node2D
var ui: CanvasLayer
var source: WeakRef
var station: Node2D
var kind: String
var map_id: String
var time:=0.0
var committing:=false
func _ready():
	map_id=GameState.map_id;kind="smith" if map_id=="smithy" else "alchemy"
	add_to_group("workshop")
	for npc in get_tree().get_nodes_in_group("npc"):
		if not npc.is_queued_for_deletion() and npc.get_parent()==world.entities and npc.npc_id==("greta" if kind=="smith" else "meer_lena"):source=weakref(npc);break
	ui=load("res://scripts/ui/work_together.gd").new();ui.director=self;add_child(ui)
	station=Node2D.new();station.position=(Vector2(8.5,4.5)*32 if kind=="smith" else Vector2(9.5,5.5)*32)-Vector2(0,1)
	world.entities.add_child(station);station.draw.connect(draw_station) # correct front/back sorting at the countertop
func valid() -> bool:
	var npc: Variant=source.get_ref() if source!=null else null
	return not is_queued_for_deletion() and is_instance_valid(npc) and npc.is_inside_tree() and not npc.is_queued_for_deletion() and GameState.map_id==map_id and not GameState.transitioning and not GameState.ended and npc.position.distance_to(world.player.position)<=64
func open(requested: String):
	if requested!=kind or not valid() or GameState.input_locked():return
	ui.open()
func complete() -> bool:
	if committing or not valid() or not ui.active or not ui.ready_to_finish():return false
	committing=true
	if ui.practice:
		committing=false;return true
	var done: bool=GameState.flag("wt_"+kind+"_done")
	if kind=="alchemy" and not Prof.craft("potion"):
		committing=false;return false
	if not done:
		GameState.set_flag("wt_"+kind+"_done") # before XP/signals: no re-entrant lesson reward
		if kind=="smith":Prof.add_xp("smithing",6)
		Journal.learn("smith" if kind=="smith" else "focus")
	GameState.save_requested.emit()
	committing=false
	return true
func _process(delta: float):
	time+=delta
	if is_instance_valid(station):station.queue_redraw()
func station_frame() -> int:
	if kind=="smith":return 1 if GameState.flag("wt_smith_done") else 0
	return 4+int(time*0.5)%2 if GameState.flag("wt_alchemy_done") else 2
func draw_station():
	var frame:=station_frame()
	if is_instance_valid(ui) and ui.active and ui.working:frame=1 if kind=="smith" else 3
	DrawUtil.sprite(station,Art.tex("wt_stations"),frame,0,Vector2(0,-10),Vector2i(24,24),2)
