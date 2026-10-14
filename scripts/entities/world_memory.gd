extends Node2D
const Memory := preload("res://scripts/core/world_memory.gd")
const Actor := preload("res://scripts/entities/memory_actor.gd")
var world: Node2D
var actors: Dictionary = {}
var grid := AStarGrid2D.new()
func _ready() -> void:
	add_to_group("world_memory")
	refresh()
func _process(_delta: float) -> void:
	refresh()
func refresh() -> void:
	if is_queued_for_deletion(): return
	# Existing flags may change while this map stays open.
	for role: String in Memory.PLACES:
		var spec: Dictionary = Memory.PLACES[role]
		if spec.map != GameState.map_id: continue
		if Memory.enabled(role) and not actors.has(role):
			build_grid()
			var actor := Actor.new()
			actor.world = world; actor.director = self; actor.role = role
			actor.rest = Memory.resting(world.map_data.get("weather",""))
			var at: Array = actor.route()[0]
			actor.position = safe_spawn(Vector2i(at[0],at[1]))
			world.entities.add_child(actor)
			actors[role] = actor
		elif not Memory.enabled(role) and actors.has(role):
			actors[role].queue_free(); actors.erase(role)
func build_grid() -> void:
	# update() alone preserves old point solidity when dimensions are unchanged.
	grid.clear()
	grid.region = Rect2i(Vector2i.ZERO,world.map_size)
	grid.cell_size = Vector2(32,32); grid.offset = Vector2(16,16)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for cell in world.solid_cells: grid.set_point_solid(cell)
	for node in world.entities.get_children():
		if node==world.player or node.is_queued_for_deletion() or node is Actor: continue
		if node is PhysicsBody2D and node.collision_layer & 1:
			var cell := Vector2i(node.position/32)
			if grid.is_in_boundsv(cell): grid.set_point_solid(cell)
	# No routes through portals, savepoints or trial entrances.
	for spec: Dictionary in world.map_data.objects:
		if spec.type in ["portal","savepoint","gate","trigger"]:
			grid.set_point_solid(Vector2i(spec.pos[0],spec.pos[1]))
func safe_spawn(at: Vector2i) -> Vector2:
	for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.UP]:
		var cell: Vector2i = at+offset
		var point := (Vector2(cell)+Vector2(0.5,0.5))*32
		if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell) and point.distance_to(world.player.position)>30:
			var free := true
			for actor: Node2D in actors.values():
				if point.distance_to(actor.position)<30: free = false
			if free: return point
	# Player occupying every adjacent tile is impossible; keep the fallback clear.
	return (Vector2(at)+Vector2(0.5,0.5))*32
func walk_path(actor: Node2D,goal: Vector2i) -> PackedVector2Array:
	build_grid()
	var start := Vector2i(actor.position/32)
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(goal) or grid.is_point_solid(goal): return PackedVector2Array()
	for other in actors.values()+[world.player]:
		if other==actor: continue
		var cell := Vector2i(other.position/32)
		if cell==goal: return PackedVector2Array()
		if grid.is_in_boundsv(cell) and cell!=start: grid.set_point_solid(cell)
	grid.set_point_solid(start,false)
	# A player occupying a destination makes the resident wait, never overlap.
	if grid.is_point_solid(goal): return PackedVector2Array()
	return grid.get_point_path(start,goal)
