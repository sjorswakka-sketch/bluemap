extends StaticBody2D
const Route := preload("res://scripts/core/first_route.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
var world: Node2D
var obj: Dictionary={}
var key := ""
var kind := "track"
var id := ""
var time := 0.0
var listening := false
var progress := 0.0
var origin := Vector2.ZERO
var health := 0
var pulse := 0.0
func _ready() -> void:
	if not obj.is_empty():
		kind=obj.get("kind","track")
		id=obj.get("id","")
	add_to_group("interactable")
	add_to_group("route_objects")
	collision_layer=0
	if kind=="memorial":
		collision_layer=1
		var collider:=CollisionShape2D.new()
		var box:=RectangleShape2D.new()
		box.size=Vector2(24,12)
		collider.shape=box
		collider.position=Vector2(0,6)
		add_child(collider)
		if world.player.position.distance_to(position)<25:
			for offset in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
				var safe: Vector2=position+offset*38
				if not world.is_solid(safe):
					world.player.position=safe
					break
	# Platte tekens en lage schalen zijn bewust beloopbaar; blokkeren geen oude saveposities.
	if kind in ["bowl","memorial"]:
		var glow:=PointLight2D.new()
		glow.texture=Art.light_texture()
		glow.texture_scale=0.28
		glow.color=Color("8cd9da")
		glow.energy=0.12 if kind=="memorial" else 0.25
		add_child(glow)
func label() -> String:
	match kind:
		"track": return tr("Pootafdrukken")
		"relief": return tr("Beschadigd reliëf")
		"journal": return tr("Wachtersboek")
		"memorial": return tr("Wilfreds gedenksteen")
	return tr("Klankschaal")
func interact() -> void:
	if GameState.input_locked() or listening: return
	match kind:
		"track":
			GameState.start_quest("kat")
			Route.mark(id)
			GameState.say(label(),[tr("Kleine pootjes, een witte haar. De afdrukken lopen zuidwaarts langs de vijver. Muis lijkt bang voor haastige stappen.")])
		"relief", "journal":
			pulse=6
			if not GameState.flag("rf_memorial"): GameState.start_quest("rf_memory")
			Route.mark(id)
			GameState.say(label(),[tr("Een bewaker houdt een poort omhoog. Achter hem trekken families naar een grot. Het medaillon op zijn borst lijkt op dat van Wilfred.") if kind=="relief" else tr("Laatste wacht: de poort bleef open. De families volgden drie klankschalen naar de westelijke schuilplaats. Wilfred keerde niet terug. Hij bewaakte mensen, niet het goud.")])
		"memorial":
			if GameState.flag("rf_memorial"):
				GameState.say(label(),[tr("Hier wordt Wilfred herinnerd: de gids die anderen liet ontsnappen.") if GameState.flag("rf_guide") else tr("Hier wordt Wilfred herinnerd: de bewaker die bleef.")])
			elif ready_to_remember():
				Route.pending=weakref(self)
				GameState.start_dialogue("rf_inscription")
			else:
				GameState.start_quest("rf_memory")
				GameState.say(label(),[tr("De steen mist zijn verhaal. Onderzoek het reliëf en het wachtersboek, en breng Wilfred zijn medaillon terug.")])
		"bowl":
			GameState.start_quest("rf_echo")
			var required := "rf_echo_begin" if id=="rf_echo_mid" else "rf_echo_mid"
			if id!="rf_echo_begin" and not GameState.flag(required):
				GameState.say(label(),[tr("De schaal blijft stil. Begin bij de ingang en volg daarna de blauwe tekens via de middelste kamer naar het westen.")])
				return
			listening=true
			origin=world.player.global_position
			health=GameState.hp
			progress=0
func ready_to_remember() -> bool:
	return GameState.flag("rf_relief") and GameState.flag("rf_journal") and GameState.quest_state("medaillon")=="done"
func remember(choice: String) -> void:
	if GameState.flag("rf_memorial") or not ready_to_remember(): return
	GameState.start_quest("rf_memory")
	Route.mark("rf_"+choice)
	Route.mark("rf_memorial")
	GameState.give("gear_rf_keepsake",1)
	GameState.finish_quest("rf_memory")
	Sound.play("rf_high",-5)
	world.ring(global_position,55,Color("efda9d"))
	GameState.save_requested.emit()
func _process(delta: float) -> void:
	time+=delta
	pulse=maxf(0,pulse-delta)
	if listening:
		if GameState.input_locked() or Route.loud(world.player) or world.player.position.distance_to(origin)>7 or world.player.position.distance_to(position)>60 or GameState.hp<health:
			listening=false
			progress=0
		else:
			progress+=delta
			if progress>=1.5:
				listening=false
				pulse=3
				Sound.play("rf_low" if id=="rf_echo_begin" else ("rf_mid" if id=="rf_echo_mid" else "rf_high"),-7)
				if not GameState.flag(id):
					Route.mark(id)
					if id=="rf_echo_end":
						GameState.give("gear_rf_cord",1)
						GameState.finish_quest("rf_echo")
						GameState.toast.emit(tr("De oude schuilplaats licht op. In de westelijke kamer staat een kist. Je vindt ook een stiltekoord: draag het via Uitrusting."))
					else:
						GameState.toast.emit(tr("Een echo antwoordt. Volg de oplichtende tekens; rustig lopen laat de steenluisteraars slapen."))
					GameState.save_requested.emit()
	queue_redraw()
func _draw() -> void:
	var selected: bool=world.player.target==self
	if kind=="track":
		for i in 3:
			var at:=Vector2(-8+i*7,3-(i%2)*8)
			draw_circle(at,2,Color("927b5c"))
			for x in [-2,0,2]: draw_circle(at+Vector2(x,-4),0.8,Color("927b5c"))
	elif kind=="bowl":
		DrawUtil.sprite(self,Art.tex("rf_objects"),0,0,Vector2.ZERO,Vector2i(16,16),2)
		var color:=Color("93e1e1") if GameState.flag(id) else Color("8a9999")
		draw_arc(Vector2(0,-3),8,0,TAU,20,color,2)
		if pulse>0: draw_arc(Vector2.ZERO,10+(3-pulse)*16,0,TAU,30,Color(color, pulse/3),1)
	elif kind=="memorial":
		DrawUtil.sprite(self,Art.tex("rf_objects"),3 if GameState.flag("rf_memorial") else 2,0,Vector2(0,-6),Vector2i(16,16),2)
		if GameState.flag("rf_memorial"):
			for i in 5: draw_circle(Vector2(-22+i*11,13+sin(time+i)*2),2,Color("e6c685"))
	else:
		DrawUtil.sprite(self,Art.tex("rf_objects"),1 if kind=="journal" else 4,0,Vector2.ZERO,Vector2i(16,16),2)
		if pulse>0:
			# Een korte herinnering boven het reliëf: drie reizigers gaan langs de poort.
			for i in 3:
				var at:=Vector2(-22+i*13+(6-pulse)*4,-37-i%2*3)
				var tint:=Color(0.65,0.85,0.9,minf(pulse,1)*0.6)
				draw_circle(at,3,tint)
				draw_colored_polygon(PackedVector2Array([at+Vector2(-4,11),at+Vector2(0,3),at+Vector2(4,11)]),tint)
	if listening:
		draw_rect(Rect2(-20,-29,40,5),Color("293d4c"))
		draw_rect(Rect2(-19,-28,38*minf(progress/1.5,1),3),Color("8fe2d3"))
	elif selected:
		DrawUtil.name_tag(self,Vector2(0,-30),label())
		DrawUtil.prompt(self,Vector2(0,-46),time)
