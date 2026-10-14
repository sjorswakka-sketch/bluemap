extends Node2D
## Kleine, ontworpen gebeurtenissen; geen willekeurige quest-generator.
const Route := preload("res://scripts/core/first_route.gd")
const ObjectScript := preload("res://scripts/entities/route_object.gd")
const Art := preload("res://scripts/core/art.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
var world: Node2D
var time := 0.0
var bird_time := 4.0
var birds: Array[Vector2]=[]
var birds_home: Array[Vector2]=[]
var bird_panic := 0.0
var map_id := ""
var refuge_light: PointLight2D
const ECHO_PATH := [Vector2(8.5,27.5),Vector2(8.5,23.5),Vector2(10.5,23.5),Vector2(15.5,23.5),Vector2(17.5,22.5),Vector2(17.5,18.5),Vector2(17.5,16.5),Vector2(17.5,13.5),Vector2(17.5,9.5),Vector2(13.5,9.5),Vector2(10.5,9.5),Vector2(8.5,8.5)]
static func prepare(data: Dictionary, map: String) -> void:
	# Alleen eigenschappen wijzigen: indexen van bestaande kisten/pickups blijven gelijk.
	for spec: Dictionary in data.objects:
		if spec.type!="enemy": continue
		if map=="forest":
			if spec.pos in [[8,17],[31,24]]: spec.kind="rf_bramble"
			# Let the west entrance/altar breathe; the first ambush belongs in a side clearing.
			if spec.pos==[8,17]: spec.pos=[20,11]
			# De kattenplek is een adempauze; gevechten liggen langs het pad ernaartoe.
			if spec.pos==[7,31]: spec.pos=[8,24]
			if spec.pos==[14,29]: spec.pos=[19,26]
			if spec.pos==[12,28]: spec.pos=[20,25]
		elif map=="cave":
			if spec.pos in [[14,18],[19,20],[16,10]]: spec.kind="rf_listener"
			# Het luisterpad moet echt stil te passeren zijn. Gewone jagers bewaken de oostelijke route.
			if spec.pos==[13,22]: spec.pos=[38,10]
			if spec.pos==[20,17]: spec.pos=[36,24]
			if spec.pos==[12,20]: spec.pos=[32,15]
func add_object(kind: String, id: String, at: Vector2) -> void:
	var node:=ObjectScript.new()
	node.world=world
	node.kind=kind
	node.id=id
	node.position=at*32+Vector2(16,16)
	world.entities.add_child(node)
func _ready() -> void:
	add_to_group("first_route")
	map_id=GameState.map_id
	match map_id:
		"forest":
			for at in [Vector2(11,20),Vector2(12,25),Vector2(10,28)]: add_object("track","rf_tracks",at)
			birds_home=[Vector2(6.5,21.5)*32,Vector2(17.5,27.5)*32]
			birds=birds_home.duplicate()
		"ruins":
			add_object("relief","rf_relief",Vector2(5,12))
			add_object("journal","rf_journal",Vector2(19,25))
		"cave":
			add_object("bowl","rf_echo_begin",Vector2(8,28))
			add_object("bowl","rf_echo_mid",Vector2(17,17))
			add_object("bowl","rf_echo_end",Vector2(10,9))
			refuge_light=PointLight2D.new()
			refuge_light.texture=Art.light_texture()
			refuge_light.position=Vector2(6.5,5.5)*32
			refuge_light.texture_scale=0.7
			refuge_light.color=Color("b0ded9")
			refuge_light.energy=0.8
			add_child(refuge_light)
func _process(delta: float) -> void:
	time+=delta
	if is_instance_valid(refuge_light): refuge_light.visible=GameState.flag("rf_echo_end")
	if map_id=="forest":
		bird_time-=delta
		bird_panic=maxf(0,bird_panic-delta)
		for at in birds:
			if at.distance_to(world.player.position)<90 and Route.loud(world.player): bird_panic=3
		for i in birds.size():
			var dest: Vector2=birds_home[i]+(Vector2(65,-65) if bird_panic>0 else Vector2(sin(time+i)*10,0))
			birds[i]=birds[i].move_toward(dest,delta*(65 if bird_panic>0 else 14))
		if bird_time<=0:
			bird_time=11
			if GameState.day_time<0.78 and GameState.day_time>0.12:
				for at in birds:
					if world.player.position.distance_to(at)<170: Sound.play("rf_bird",-18)
	queue_redraw()
func _draw() -> void:
	if map_id=="forest":
		# Sporen staan laag op de grond; vogels kunnen boven struiken wegvliegen.
		for i in birds.size():
			var at: Vector2=birds[i]
			DrawUtil.sprite(self,Art.tex("rf_bird"),int(time*(12 if bird_panic>0 else 2))%2,0,at,Vector2i(16,16),1.3)
	elif map_id=="cave":
		if GameState.flag("rf_echo_end"):
			for at in [Vector2(7,4),Vector2(8,5)]:
				var corner: Vector2=at*32+Vector2(4,6)
				draw_rect(Rect2(corner,Vector2(18,24)),Color("557879"))
				draw_rect(Rect2(corner,Vector2(18,5)),Color("c0c0a4"))
		for i in ECHO_PATH.size():
			var at: Vector2=ECHO_PATH[i]*32
			var on: bool=GameState.flag("rf_echo_begin") if i<7 else GameState.flag("rf_echo_mid")
			var color:=Color("84cbd8") if on else Color("4e6573")
			draw_arc(at,5+sin(time*2-i)*1.5,PI*0.15,PI*0.85,8,color,2)
			if on: draw_circle(at,1.2,Color("c4ede5"))
	elif map_id=="ruins" and GameState.flag("rf_memorial"):
		for at in [Vector2(10,30),Vector2(13,30),Vector2(12,31)]:
			for i in 3:
				var p: Vector2=at*32+Vector2(6+i*8,16)
				draw_line(p,p+Vector2(0,7),Color("76a88b"),2)
				draw_circle(p,3,Color("dac896"))
