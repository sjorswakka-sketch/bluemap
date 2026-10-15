extends Node2D
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var obj: Dictionary={}
var key: String=""
var time:=0.0
func _ready():add_to_group("interactable");add_to_group("region_charts")
func label() -> String:return tr("Bekijk de kustregio")
func interact():
	if GameState.input_locked():return
	for ui in get_tree().get_nodes_in_group("coast_atlas"):
		if not ui.is_queued_for_deletion() and ui.world==world:ui.open(self);return
func _process(delta: float):time+=delta;queue_redraw()
func _draw():
	DrawUtil.sprite(self,Art.tex("rg_props"),0,0,Vector2.ZERO,Vector2i(32,24),1.5)
	if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-28),time)
