extends StaticBody2D
const Art:=preload("res://scripts/core/art.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var obj: Dictionary={}
var key: String=""
var time:=0.0
func _ready():
 add_to_group("stock_chests");add_to_group("interactable")
 collision_layer=1;collision_mask=0
 var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new()
 rect.size=Vector2(24,12);shape.shape=rect;shape.position=Vector2(0,7);add_child(shape)
func label() -> String:return tr("Huisvoorraad")
func interact():
 if GameState.input_locked() or position.distance_to(world.player.position)>52:return
 var ui: CanvasLayer=load("res://scripts/ui/stock_ui.gd").new()
 ui.world=world;world.add_child(ui);ui.open("home")
func _process(delta: float):
 time+=delta;queue_redraw()
func _draw():
 var opened:=false
 for ui in get_tree().get_nodes_in_group("stock_ui"):
  if ui.active and ui.kind=="home":opened=true
 DrawUtil.sprite(self,Art.tex("stock_chest"),1 if opened else 0,0,Vector2(0,-3),Vector2i(32,32),1)
 if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-25),time)
