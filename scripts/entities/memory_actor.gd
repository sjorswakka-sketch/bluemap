extends CharacterBody2D
const Memory := preload("res://scripts/core/world_memory.gd")
const Art := preload("res://scripts/core/art.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
var world: Node2D
var director: Node2D
var role := ""
var rest := false
var time := 0.0
var wait := 1.0
var path := PackedVector2Array()
var index := 0
var stuck := 0.0
var route_key := ""
func _ready() -> void:
	add_to_group("interactable")
	add_to_group("memory_actors")
	if role in ["hearth","lamplighter"]: add_to_group("living_residents")
	collision_layer = 1
	collision_mask = 3
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(14,10)
	collider.shape = box
	collider.position.y = 8
	add_child(collider)
func route() -> Array:
	if role=="caravan" and not GameState.flag("ra_water_wild"):
		return [[24,14]] if rest else [[24,14],[25,14]]
	return Memory.PLACES[role].rest if rest else Memory.PLACES[role].work
func _physics_process(delta: float) -> void:
	time += delta
	velocity = Vector2.ZERO
	var now := Memory.resting(world.map_data.get("weather",""))
	rest = now
	var key_now := str(route())
	if route_key != key_now:
		route_key = key_now; path.clear(); index = 0; wait = 0
	if GameState.input_locked(): return
	if wait > 0:
		wait -= delta
	elif path.is_empty():
		var points := route()
		var at: Array = points[index % points.size()]
		path = director.walk_path(self,Vector2i(at[0],at[1]))
		if not path.is_empty(): path.remove_at(0)
		index += 1
		if path.is_empty(): wait = 5.0
	else:
		var offset := path[0]-position
		if offset.length() < 2:
			path.remove_at(0)
			if path.is_empty(): wait = 6.0
		else:
			var before := position
			velocity = offset.normalized()*25
			move_and_slide()
			stuck = stuck+delta if position.distance_to(before)<0.05 else 0.0
			if stuck>0.8:
				path.clear(); index = maxi(0,index-1); wait = 0.4; stuck = 0
	queue_redraw()
func interact() -> void:
	if GameState.input_locked() or world.player.position.distance_to(position)>40: return
	var speech := Memory.lines(role,world.map_data.get("weather",""))
	Memory.meet(role)
	GameState.say(Memory.name_for(role),speech)
func _draw() -> void:
	DrawUtil.ellipse(self,Vector2(0,14),Vector2(10,4),Color(0,0,0,0.25))
	var frame := int(time*(5 if velocity.length()>1 else 1.5))%2
	DrawUtil.sprite(self,Art.tex("wm_people"),int(Memory.PLACES[role].frame)*2+frame,0)
	if velocity.length()<1:
		var n := int(Memory.PLACES[role].frame)
		draw_set_transform(Vector2(13,5+sin(time*3)*(0.3 if rest else 2)),sin(time*3)*0.25 if not rest and role in ["miner","gardener"] else 0)
		DrawUtil.sprite(self,Art.tex("wm_tools"),8 if rest and role=="gardener" else n,0,Vector2.ZERO,Vector2i(16,16),1)
		draw_set_transform(Vector2.ZERO)
		if not rest and role in ["hearth","gardener"]:
			for i in 3:
				var drift := fposmod(time*8+i*6,18)
				draw_circle(Vector2(17+i*2,2-drift) if role=="hearth" else Vector2(19+i*2,7+drift),1,Color(0.8,0.9,1,0.55*(1-drift/20)))
	if world.player.target==self:
		DrawUtil.name_tag(self,Vector2(0,-27),Memory.name_for(role))
		DrawUtil.prompt(self,Vector2(0,-43),time)
