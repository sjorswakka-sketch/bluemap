extends Node2D
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var obj: Dictionary={}
var key: String=""
var time:=0.0
func _ready():add_to_group("interactable");add_to_group("tide_stations")
func label() -> String:
	match obj.role:
		"kit":return tr("Leenkist en proefvaart")
		"line":return tr("Landingslijn gebruiken")
		"gauge":return tr("Getijde en veilige routes")
	return tr("Bestemmingen en reisroutes")
func interact():
	if GameState.input_locked():return
	for ui in get_tree().get_nodes_in_group("coast_routes"):
		if not ui.is_queued_for_deletion() and ui.world==world:ui.open(self);return
func _process(delta: float):time+=delta;queue_redraw()
func _draw():
	var frame: int={"gauge":0,"kit":1,"line":2,"routes":3}.get(obj.role,0)
	DrawUtil.sprite(self,Art.tex("td_props"),frame,0,Vector2.ZERO,Vector2i(24,24),1.5)
	if obj.role=="line":
		draw_line(Vector2(0,5),Vector2(18 if obj.pos[0]<25 else -18,12),Color("dfc38a"),1.5)
	if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-27),time)
