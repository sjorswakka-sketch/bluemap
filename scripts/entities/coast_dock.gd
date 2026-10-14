extends Node2D
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var obj: Dictionary={}
var key: String=""
var time:=0.0
func _ready():
	add_to_group("interactable");add_to_group("coast_docks")
func label() -> String:
	return tr("Veer naar Meeuweneiland") if obj.to=="gull_island" else tr("Veer naar de Blauwe Kust")
func interact():
	if GameState.input_locked():return
	for director in get_tree().get_nodes_in_group("coast_voyage"):
		if not director.is_queued_for_deletion() and director.world==world:
			director.offer(self);return
func _process(delta: float):
	time+=delta;queue_redraw()
func _draw():
	var side:=1 if obj.to=="gull_island" else -1
	draw_line(Vector2(0,8),Vector2(side*44,52+sin(time*1.7)),Color("c5b88e"),1.5)
	DrawUtil.sprite(self,Art.tex("ce_boat"),int(time*1.5)%2,0,Vector2(side*54,52+sin(time*1.7)),Vector2i(48,32),1.5)
	DrawUtil.sprite(self,Art.tex("ce_props"),0,0,Vector2.ZERO,Vector2i(24,24),1.5)
	if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-30),time)
