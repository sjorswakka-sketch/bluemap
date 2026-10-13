extends Node2D
const Actor:=preload("res://scripts/entities/supper_actor.gd")
var world: Node2D
var grid:=AStarGrid2D.new()
var guests := false
var time := 0.0

func _ready() -> void:
	add_to_group("lake_supper")
	grid.region=Rect2i(Vector2i.ZERO,world.map_size)
	grid.cell_size=Vector2(32,32)
	grid.offset=Vector2(16,16)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for cell in world.solid_cells: grid.set_point_solid(cell)
	for spec: Dictionary in world.map_data.objects:
		if spec.type in ["sign","chest","portal","savepoint","profession_resource"] or (spec.type=="npc" and spec.id!="meer_joris"):
			grid.set_point_solid(Vector2i(spec.pos[0],spec.pos[1]))
	for node in get_tree().get_nodes_in_group("supper_objects"):
		if node.is_queued_for_deletion(): continue
		if node.kind=="table":
			for x in range(17,20): grid.set_point_solid(Vector2i(x,5))
		elif node.kind!="basket": grid.set_point_solid(Vector2i(node.position/32))
	for actor in get_tree().get_nodes_in_group("supper_actors"):
		if not actor.is_queued_for_deletion(): actor.director=self
	refresh()

func refresh() -> void:
	if guests or GameState.map_id!="inn" or not GameState.flag("ls_served"): return
	guests=true
	# Reserve seated neighbours so a late guest walks around them instead of into them.
	for cell in [Vector2i(17,4),Vector2i(20,5),Vector2i(17,6)]: grid.set_point_solid(cell)
	for i in 3:
		var actor:=Actor.new()
		actor.role=["joris","bo","nelle"][i]
		actor.npc_id="ls_"+actor.role
		actor.world=world
		actor.director=self
		actor.position=Vector2(15.5,3.5+i*2)*32
		# Guests enter through separate free tiles so they never stack on the player.
		if actor.position.distance_to(world.player.position)<28: actor.position.x+=32
		actor.wait_time=i*0.8
		world.entities.add_child(actor)

func walk_path(actor: Node2D,goal: Vector2i) -> PackedVector2Array:
	var start:=Vector2i(actor.position/32)
	var changed: Dictionary={}
	for other in get_tree().get_nodes_in_group("supper_actors")+[world.player]:
		if other==actor or other.is_queued_for_deletion(): continue
		var cell:=Vector2i(other.position/32)
		if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
			changed[cell]=false
			grid.set_point_solid(cell)
	for cell in [start,goal]:
		if not grid.is_in_boundsv(cell): continue
		if not changed.has(cell): changed[cell]=grid.is_point_solid(cell)
		grid.set_point_solid(cell,false)
	var result:=grid.get_point_path(start,goal)
	for cell in changed: grid.set_point_solid(cell,changed[cell])
	return result

func _process(delta: float) -> void:
	time+=delta
	refresh()
	queue_redraw()

func _draw() -> void:
	if GameState.map_id=="inn":
		# A floor rug grounds the table without hiding the chair/actor silhouettes.
		draw_rect(Rect2(16*32,3*32,5*32,5*32),Color("796055"))
		draw_rect(Rect2(16*32+4,3*32+4,5*32-8,5*32-8),Color("525962"))
		for y in [3,7]: draw_line(Vector2(16.3,y+0.2)*32,Vector2(20.7,y+0.2)*32,Color("be9b6b"),2)
		for x in range(17,21):
			for y in [3.35,7.35]:
				var at:=Vector2(x,y)*32
				draw_polyline(PackedVector2Array([at+Vector2(-4,0),at+Vector2(0,-3),at+Vector2(4,0),at+Vector2(0,3),at+Vector2(-4,0)]),Color("917e64"),1)
		if GameState.flag("ls_served"):
			for at in [Vector2(17.5,4.5),Vector2(20.5,5.5),Vector2(17.5,6.5)]:
				draw_rect(Rect2(at*32+Vector2(-11,7),Vector2(22,14)),Color("8b6444"))
