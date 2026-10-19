extends CharacterBody2D
const Art := preload("res://scripts/core/art.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const CharacterDraw := preload("res://scripts/core/character_draw.gd")
const Npcs := preload("res://scripts/data/npcs.gd")
const Supper := preload("res://scripts/core/lake_supper.gd")
var visual_direction := 0
var world: Node2D
var director: Node2D
var npc_id := "meer_joris"
var role := "joris"
var exists_if: Array=[]
var data: Dictionary={}
var time := 0.0
var wait_time := 4.0
var path:=PackedVector2Array()
var route_index := 0
var task_index := 0
var evening := false
var stuck := 0.0

func setup(id: String) -> void:
	npc_id=id
	data=Npcs.info(id)

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("supper_actors")
	if npc_id=="meer_joris": add_to_group("npc")
	collision_layer=1
	collision_mask=3
	var shape:=CollisionShape2D.new()
	var rect:=RectangleShape2D.new()
	rect.size=Vector2(14,10)
	shape.shape=rect
	shape.position=Vector2(0,8)
	add_child(shape)

func actor_name() -> String:
	return tr("Visser Joris") if role=="joris" else (tr("Bo de broodbezorger") if role=="bo" else tr("Nelle de hovenier"))

func route() -> Array:
	if GameState.map_id=="lake":
		if evening: return [Vector2(10.5,9.5)]
		return [Vector2(20.5,13.5),Vector2(18.5,11.5),Vector2(10.5,9.5)]
	# Use opposite sides of the table; guests never squeeze past each other in a chair gap.
	if role=="joris": return [Vector2(17.5,4.5)]
	if role=="bo": return [Vector2(20.5,3.5),Vector2(20.5,5.5)]
	return [Vector2(17.5,7.5),Vector2(17.5,6.5)]

func _physics_process(delta: float) -> void:
	time+=delta
	velocity=Vector2.ZERO
	if not is_instance_valid(director): return
	var dark: bool=GameState.day_time<0.12 or GameState.day_time>0.78
	if evening!=dark and GameState.map_id=="lake":
		evening=dark
		path.clear()
		route_index=0
		wait_time=1
	# A dialogue already pauses the world. Merely being the nearest interactable
	# must not freeze a passer-by beside a stationary player forever.
	if wait_time>0:
		wait_time-=delta
	elif path.is_empty():
		var points:=route()
		task_index=route_index%points.size() if GameState.map_id=="lake" else mini(route_index,points.size()-1)
		path=director.walk_path(self,Vector2i(points[task_index]))
		if not path.is_empty(): path.remove_at(0)
		route_index+=1
		if path.is_empty(): wait_time=0.2 if GameState.map_id=="inn" and route_index<points.size() else 8
	else:
		var offset:=path[0]-position
		if offset.length()<2:
			path.remove_at(0)
			if path.is_empty(): wait_time=0.2 if GameState.map_id=="inn" and route_index<route().size() else 8
		else:
			var before:=position
			velocity=offset.normalized()*(36 if GameState.map_id=="inn" else 24)
			move_and_slide()
			stuck=stuck+delta if position.distance_to(before)<0.05 else 0.0
			if stuck>1.0:
				stuck=0
				path.clear()
				route_index=maxi(0,route_index-1)
				wait_time=0.2
	queue_redraw()

func interact() -> void:
	if GameState.input_locked(): return
	if GameState.map_id=="inn":
		GameState.say(actor_name(),Supper.conversation(role))
		return
	GameState.note_talked(npc_id)
	for rule: Dictionary in data.rules:
		if not rule.has("if") or GameState.check_all(rule["if"]):
			GameState.start_dialogue(rule.talk)
			return

func _draw() -> void:
	visual_direction = CharacterDraw.direction(velocity,visual_direction)
	DrawUtil.ellipse(self,Vector2(0,14),Vector2(10,4),Color(0,0,0,0.25))
	var sheet: String="npc_meer_joris" if role=="joris" else ("op_courier" if role=="bo" else "op_gardener")
	CharacterDraw.actor(self,sheet,time,velocity,visual_direction if velocity.length()>1 else 0)
	if GameState.map_id=="lake" and path.is_empty() and not evening:
		if task_index==0:
			draw_line(Vector2(9,2),Vector2(24,-22),Color("c6a172"),2)
			draw_line(Vector2(24,-22),Vector2(31,23+sin(time*2)*2),Color("eee0b3"),1)
			draw_circle(Vector2(31,23+sin(time*2)*2),2,Color("e98964"))
		elif task_index==1:
			draw_line(Vector2(6,6),Vector2(12+sin(time*4)*5,14),Color("e7caa1"),2)
		else: DrawUtil.sprite(self,Art.tex("ls_items"),0,0,Vector2(12,9),Vector2i(16,16),1)
	if world.player.target==self:
		DrawUtil.name_tag(self,Vector2(0,-27),actor_name())
		DrawUtil.prompt(self,Vector2(0,-43),time)
