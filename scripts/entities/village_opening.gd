extends Node2D
const Opening := preload("res://scripts/core/opening.gd")
const Actor := preload("res://scripts/entities/village_actor.gd")
const Device := preload("res://scripts/entities/opening_device.gd")
var world: Node2D
var grid := AStarGrid2D.new()
var time := 0.0
var hammer_time := 2.0
var last_flowing := false
var gardener: CharacterBody2D
var courier: CharacterBody2D
var water_audio: AudioStreamPlayer2D
var water_stream: AudioStreamWAV
var drip_time := 1.0

func _ready() -> void:
	add_to_group("village_opening")
	grid.region = Rect2i(Vector2i.ZERO,world.map_size)
	grid.cell_size = Vector2(32,32)
	grid.offset = Vector2(16,16)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for cell in world.solid_cells: grid.set_point_solid(cell)
	for spec: Dictionary in world.map_data.objects:
		if spec.type in ["npc","sign","portal","savepoint","wereld_lantaarn","chest"]:
			grid.set_point_solid(Vector2i(spec.pos[0],spec.pos[1]))
	for x in [14,15]:
		var planter := StaticBody2D.new()
		planter.position=Vector2(x+0.5,16.5)*32
		planter.collision_layer=1
		var collider := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size=Vector2(28,20)
		collider.shape=box
		planter.add_child(collider)
		world.entities.add_child(planter)
		planter.add_to_group("opening_planters")
		grid.set_point_solid(Vector2i(x,16))
	if Opening.enabled():
		for entry in [["grate",Vector2i(16,12)],["wheel",Vector2i(16,14)]]:
			var device := Device.new()
			device.world = world
			device.kind = entry[0]
			device.position = Vector2(entry[1])*32+Vector2(16,16)
			world.entities.add_child(device)
			grid.set_point_solid(entry[1])
	# Een oude opslag kan precies op de plaats van een nieuwe bloembak staan.
	var added := [Vector2i(14,16),Vector2i(15,16)]
	if Opening.enabled(): added.append_array([Vector2i(16,12),Vector2i(16,14)])
	var arrival := Vector2i(world.player.position/32)
	if arrival in added:
		for offset in [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP]:
			if grid.is_in_boundsv(arrival+offset) and not grid.is_point_solid(arrival+offset):
				world.player.position=Vector2(arrival+offset)*32+Vector2(16,16)
				break
	gardener = actor("gardener",Vector2(17.5,11.5))
	courier = actor("courier",Vector2(8.5,13.5))
	water_audio = AudioStreamPlayer2D.new()
	water_audio.bus = "SFX"
	water_audio.position = Vector2(20,14)*32
	water_audio.max_distance = 230
	water_audio.volume_db = -20
	var stream: AudioStreamWAV = Sound.streams["op_water"].duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	water_audio.stream = stream
	water_stream = stream
	add_child(water_audio)
	last_flowing = Opening.flowing()

func actor(role: String, at: Vector2) -> CharacterBody2D:
	var node := Actor.new()
	node.world = world
	node.director = self
	node.role = role
	node.position = at*32
	if node.position.distance_to(world.player.position)<28:
		for offset in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
			var cell: Vector2i = Vector2i(at)+offset
			if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
				node.position=Vector2(cell)*32+Vector2(16,16)
				break
	world.entities.add_child(node)
	return node

func _process(delta: float) -> void:
	time += delta
	hammer_time -= delta
	var flowing := Opening.flowing()
	if flowing:
		if water_audio.stream!=water_stream:
			water_audio.stream=water_stream
		if not water_audio.playing: water_audio.play()
	else:
		drip_time -= delta
		if drip_time<=0:
			drip_time=3.5
			water_audio.stream=Sound.streams["op_drip"]
			water_audio.play()
	if flowing != last_flowing:
		last_flowing = flowing
		gardener.bubble = tr("Daar is het water!")
		gardener.bubble_time = 5
		courier.bubble = tr("Dat scheelt een tocht naar het meer!")
		courier.bubble_time = 5
	if hammer_time<=0:
		hammer_time = 3.5
		var distance: float = world.player.position.distance_to(Vector2(6.5,11.5)*32)
		if distance<160 and GameState.day_time>0.12 and GameState.day_time<0.78:
			Sound.play("op_hammer",-12-distance/10)
	if Opening.quiet_hud():
		if Input.is_action_pressed("sprint"): GameState.set_flag("op_sprint_seen")
		if world.player.position.distance_to(gardener.position)<160 and not GameState.flag("op_greeting"):
			GameState.set_flag("op_greeting")
			gardener.bubble = tr("Even helpen? De fontein zit verstopt.")
			gardener.bubble_time = 6
	queue_redraw()

func _draw() -> void:
	var flowing := Opening.flowing()
	# Ondiepe goot naast de looproute; geen verborgen waterbotsing over bestrating.
	var points := PackedVector2Array([Vector2(16.5,12.5)*32,Vector2(16.5,14.5)*32,Vector2(19,14.5)*32])
	draw_polyline(points,Color("6a7069"),12)
	draw_polyline(points,Color("3d8ca7") if flowing else Color("6c5840"),6)
	if flowing:
		for i in 6:
			var at := Vector2(16.6+fmod(time*0.7+i*0.4,2.3),14.5)*32
			draw_line(at,at+Vector2(5,0),Color("b7e8e9"),2)
	for x in [14,15]:
		var origin := Vector2(x,16)*32
		draw_rect(Rect2(origin+Vector2(1,3),Vector2(30,25)),Color("826346"))
		draw_rect(Rect2(origin+Vector2(3,5),Vector2(26,19)),Color("4d4336"))
		for i in 3:
			var at := origin+Vector2(7+i*9,12)
			draw_line(at,at+Vector2(0,9),Color("67a853") if flowing else Color("998b57"),2)
			if flowing:
				draw_rect(Rect2(at-Vector2(4,2),Vector2(8,4)),Color("e9a4ae") if i%2==0 else Color("9bbded"))
				draw_rect(Rect2(at-Vector2(2,4),Vector2(4,8)),Color("e9a4ae") if i%2==0 else Color("9bbded"))
			draw_rect(Rect2(at-Vector2(1,1),Vector2(2,2)),Color("ffe7a1") if flowing else Color("ac9b78"))
