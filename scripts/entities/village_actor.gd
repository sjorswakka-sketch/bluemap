extends CharacterBody2D
## Kleine dagroutines met echte botsing, padzoeken en pauzes bij werkzaamheden.
const Opening := preload("res://scripts/core/opening.gd")
const Art := preload("res://scripts/core/art.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
var world: Node2D
var director: Node2D
var role := "gardener"
var time := 0.0
var wait_time := 2.0
var route_index := 0
var path := PackedVector2Array()
var mode := ""
var bubble := ""
var bubble_time := 0.0

func _ready() -> void:
	# Een reeds uitgesproken losse reactie verdwijnt bij een taalwissel.
	Lang.changed.connect(func(_language: String) -> void: bubble_time = 0; queue_redraw())
	add_to_group("interactable")
	add_to_group("opening_actors")
	collision_layer = 1
	collision_mask = 3
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(14,10)
	collider.shape = box
	collider.position = Vector2(0,8)
	add_child(collider)

func actor_name() -> String:
	return tr("Nelle de hovenier") if role=="gardener" else tr("Bo de broodbezorger")

func interact() -> void:
	if GameState.input_locked(): return
	if role == "gardener":
		if not Opening.flowing():
			if GameState.count("op_rake")==0:
				GameState.give("op_rake",1,true)
				GameState.start_quest("first_water")
				GameState.say(actor_name(),[tr("Hoor je dat gesputter? Er zit riet in het rooster. Hier, leen mijn hark. Het rooster ligt vlak ten zuiden van me."),tr("Gebruik de hark bij het rooster, blijf even staan en draai daarna het sluisrad open. Dan krijgen het plein en mijn bloemen weer water.")])
			else:
				GameState.say(actor_name(),[tr("Eerst het rooster schoonmaken met mijn hark. Daarna het sluisrad open. Je kunt de markering naast de fontein volgen.")])
		elif Opening.enabled():
			GameState.say(actor_name(),[tr("Daar is het water weer! Bo hoeft zijn kruiken niet meer naar het meer te dragen. Bedankt — ik kan mijn bloemen weer verzorgen.")])
		else:
			GameState.say(actor_name(),[tr("Een beetje water en geduld. Meer hebben deze bloemen niet nodig.")])
	else:
		GameState.say(actor_name(),[tr("Mijn brood blijft nu droog en de kruiken vul ik hier. Mooi werk aan de fontein!") if Opening.flowing() else tr("Brood voor de herberg, lege kruiken mee terug. Hopelijk krijgt Nelle de fontein snel aan de praat.")])
	GameState.save_requested.emit()

func route() -> Array:
	if role == "gardener":
		if not Opening.flowing(): return [Vector2(17.5,11.5)]
		return [Vector2(17.5,11.5)] if GameState.day_time>0.78 or GameState.day_time<0.12 else [Vector2(14.5,15.5),Vector2(15.5,15.5)]
	if GameState.day_time>0.78 or GameState.day_time<0.12: return [Vector2(7.5,13.5)]
	return [Vector2(7.5,13.5),Vector2(17.5,13.5),Vector2(21.5,15.5) if Opening.flowing() else Vector2(23.5,15.5),Vector2(29.5,11.5)]

func _physics_process(delta: float) -> void:
	time += delta
	bubble_time = maxf(0,bubble_time-delta)
	var current_mode := str([Opening.flowing(),GameState.day_time>0.78 or GameState.day_time<0.12])
	if current_mode != mode:
		mode = current_mode
		path.clear()
		route_index = 0
		wait_time = 1
	velocity = Vector2.ZERO
	if wait_time>0:
		wait_time -= delta
	elif path.is_empty():
		var points := route()
		var goal: Vector2 = points[route_index%points.size()]*32
		path = director.grid.get_point_path(Vector2i(global_position/32),Vector2i(goal/32))
		if not path.is_empty(): path.remove_at(0)
		route_index += 1
		if path.is_empty(): wait_time = 5
	else:
		var offset := path[0]-global_position
		if offset.length()<2:
			path.remove_at(0)
			if path.is_empty(): wait_time = 5 if role=="gardener" else 3
		else:
			velocity = offset.normalized()*26
			move_and_slide()
	queue_redraw()

func _draw() -> void:
	DrawUtil.ellipse(self,Vector2(0,14),Vector2(10,4),Color(0,0,0,0.22))
	var frame := int(time*5)%2 if velocity.length()>1 else 2+int(time*1.5)%2
	DrawUtil.sprite(self,Art.tex("op_gardener" if role=="gardener" else "op_courier"),frame,0)
	if role=="gardener" and Opening.flowing() and wait_time>0 and global_position.x<17*32 and GameState.day_time<0.78:
		for i in 3: draw_circle(Vector2(9+i*3,10+fmod(time*18+i*3,12)),1,Color("82d8f1"))
	if world.player.target == self:
		DrawUtil.name_tag(self,Vector2(0,-28),actor_name())
		DrawUtil.prompt(self,Vector2(0,-44),time)
	elif bubble_time>0 and not GameState.dialogue_open and world.player.target==null and world.player.position.distance_to(position)<130:
		DrawUtil.name_tag(self,Vector2(0,-28),bubble)
