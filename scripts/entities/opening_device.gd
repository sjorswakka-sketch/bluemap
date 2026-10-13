extends StaticBody2D
const Opening := preload("res://scripts/core/opening.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
var world: Node2D
var kind := "grate"
var time := 0.0
var working := false
var progress := 0.0
var work_origin := Vector2.ZERO

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("opening_devices")
	collision_layer = 1
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24,12)
	collider.shape = box
	collider.position = Vector2(0,6)
	add_child(collider)

func label() -> String:
	return tr("Verstopt rooster") if kind == "grate" else tr("Sluisrad")

func interact() -> void:
	if GameState.input_locked() or working: return
	if kind == "grate":
		if GameState.flag("op_grate"):
			GameState.say(label(),[tr("Onder het riet zit een oud prismateken. Het rooster is schoon; het sluisrad staat iets zuidelijker.")])
		elif GameState.count("op_rake") == 0:
			GameState.say(label(),[tr("Het riet zit vast. Nelle, de hovenier met de strohoed, staat naast de fontein. Ze heeft een hark.")])
		else:
			working = true
			progress = 0
			work_origin = world.player.global_position
			world.player.facing = (global_position-world.player.global_position).normalized()
			Sound.play("op_rake",-8)
	elif not GameState.flag("op_grate"):
		GameState.say(label(),[tr("Eerst het riet uit het rooster halen. Anders loopt het water over het plein.")])
	elif not GameState.flag("op_water"):
		GameState.set_flag("op_water")
		GameState.take("op_rake",1)
		GameState.add_coins(12)
		world.ring(Vector2(20,14)*32,72,Color(0.5,0.9,1))
		Sound.play("op_water",-5)
		GameState.toast.emit(tr("Het water stroomt! Nelle heeft haar hark terug. Het prismateken lijkt op dat van Greta’s werkbank."))
		GameState.save_requested.emit()
	else:
		GameState.toast.emit(tr("Het water stroomt naar de fontein en de bloembakken."))

func _process(delta: float) -> void:
	time += delta
	if working:
		if world.player.global_position.distance_to(work_origin)>8 or world.player.global_position.distance_to(global_position)>58 or GameState.hp<=0 or world.player.attack_timer>0 or world.player.roll_timer>0:
			working = false
			progress = 0
		else:
			progress += delta
			if progress>=1.6:
				working = false
				GameState.set_flag("op_grate")
				world.burst(global_position,Color(0.65,0.55,0.25),12)
				GameState.toast.emit(tr("Het rooster is vrij. Draai nu het sluisrad aan de zuidkant open."))
				GameState.save_requested.emit()
	queue_redraw()

func _draw() -> void:
	var ink := Color("33454c")
	if kind == "grate":
		draw_rect(Rect2(-15,-10,30,24),ink)
		for x in range(-12,14,6): draw_rect(Rect2(x,-8,2,20),Color("9babb0"))
		if not GameState.flag("op_grate"):
			for i in 6:
				var at := Vector2(-12+i*4,-4+(i%3)*4)
				draw_line(at,at+Vector2(8,-9),Color("bd9961"),3)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(0,-8),Vector2(6,0),Vector2(0,8),Vector2(-6,0)]),Color("62cfe1"))
	else:
		draw_rect(Rect2(-4,-12,8,26),ink)
		draw_arc(Vector2(0,-8),13,0,TAU,24,Color("d3ad66"),3)
		for i in 4:
			var angle: float = i*PI/2+(PI/4 if Opening.flowing() else 0)
			draw_line(Vector2(0,-8),Vector2(0,-8)+Vector2.from_angle(angle)*12,Color("d3ad66"),2)
	if working:
		var grip: Vector2 = world.player.global_position-global_position+Vector2(9,0)
		var head := Vector2(0,sin(time*12)*4)
		var axis := (head-grip).normalized()
		var side := axis.orthogonal()
		draw_line(grip,head,Color("d6b47b"),3)
		draw_line(head-side*8,head+side*8,Color("b0c6cc"),3)
		for i in [-1,0,1]: draw_line(head+side*i*6,head+side*i*6+axis*5,Color("b0c6cc"),2)
		draw_rect(Rect2(-18,-31,36,5),ink)
		draw_rect(Rect2(-17,-30,34*minf(progress/1.6,1),3),Color("8bddb6"))
	elif world.player.target == self:
		DrawUtil.name_tag(self,Vector2(0,-31),label())
		DrawUtil.prompt(self,Vector2(0,-47),time)
