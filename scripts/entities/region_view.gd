extends StaticBody2D
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var obj: Dictionary={}
var key: String=""
var time:=0.0
func _ready():
	add_to_group("interactable");add_to_group("region_views");collision_layer=1
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(32,12);collider.shape=shape;collider.position=Vector2(0,9);add_child(collider)
func label() -> String:return tr("Uitzicht over de zee")
func interact():
	if not GameState.input_locked():GameState.say(tr("Aan de kaap"),obj.lines.map(func(line: String) -> String:return tr(line)))
func _process(delta: float):time+=delta;queue_redraw()
func _draw():
	DrawUtil.sprite(self,Art.tex("rg_props"),1,0,Vector2.ZERO,Vector2i(32,24),2)
	if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-24),time)
