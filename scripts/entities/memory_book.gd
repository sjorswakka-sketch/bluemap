extends StaticBody2D
const Memory := preload("res://scripts/core/world_memory.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
var world: Node2D
var obj: Dictionary = {}
var key := ""
var time := 0.0
func _ready() -> void:
	add_to_group("interactable")
	add_to_group("memory_books")
	collision_layer = 1
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new(); box.size = Vector2(22,8)
	collider.shape = box; collider.position.y = 12
	add_child(collider)
func _process(delta: float) -> void:
	time += delta; queue_redraw()
func interact() -> void:
	if GameState.input_locked() or world.player.position.distance_to(position)>40: return
	Sound.play("wm_page",-8)
	GameState.say(tr("Het reizigersboek"),Memory.news())
func _draw() -> void:
	DrawUtil.ellipse(self,Vector2(0,14),Vector2(14,4),Color(0,0,0,0.25))
	DrawUtil.sprite(self,Art.tex("wm_book"),int(time*2)%2,0,Vector2(0,-8),Vector2i(24,24),2)
	if world.player.target==self:
		DrawUtil.name_tag(self,Vector2(0,-34),tr("Het reizigersboek"))
		DrawUtil.prompt(self,Vector2(0,-48),time)
