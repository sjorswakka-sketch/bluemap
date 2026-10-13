extends Node2D
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
var world: Node
var obj: Dictionary = {}
var key := ""
var t := 0.0
var countdown := 0.0
var lesson := 0
var foes: Array[Node2D] = []
var running := false
const LESSONS := [["cv_ram"],["cv_slinger"],["cv_ram","cv_slinger","lw_warden"]]
const SPAWNS := [Vector2(8.5,7.5)*32,Vector2(17.5,7.5)*32,Vector2(14.5,5.5)*32]

func _ready() -> void:
	if obj.get("kind","") != "rack":
		add_to_group("interactable")
		add_to_group("combat_posts")
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64,10) if obj.get("kind","") == "rack" else Vector2(10,8)
	shape.shape = rect
	shape.position = Vector2(0,12)
	body.add_child(shape)
	add_child(body)

func interact() -> void:
	if GameState.input_locked(): return
	if obj.get("kind","") == "entrance":
		GameState.say(tr("Oefenerf"),[tr("Het verlichte pad naast dit vaandel leidt naar het oefenerf. Probeer technieken en leer aanvalssignalen lezen. De uitgang blijft open.")])
		return
	if running:
		stop()
		GameState.toast.emit(tr("Oefening gestopt. Je kunt meteen opnieuw beginnen."))
		return
	# Read instructions first, then explicitly use the post again to start.
	if not has_meta("read"):
		set_meta("read",true)
		GameState.say(tr("Oefenerf"),[
			tr("Houd %s vast en druk op %s voor je zwaardtechniek, of op %s voor een precisieschot. Gewone aanvallen kosten geen stamina.") % [Controls.action_label("technique"),Controls.action_label("attack"),Controls.action_label("bow")],
			tr("Hout: snelle steek, 16 stamina. IJzer: brede breekslag, 28. Kristal: verre smalle steek, 24. Alle technieken openen een schild. Precisieschot: 20 stamina, 1 pijl, langere voorbereiding en groter bereik."),
			tr("Tijdens voorbereiding loop je langzaam. Rollen, een treffer of een menu onderbreekt de techniek; bestede stamina komt vanzelf terug. De pijl wordt pas bij het schot verbruikt."),
			tr("Gebruik dit vaandel opnieuw: eerst de keiram, dan de doornschutter, daarna samen met een schildwachter. Aanvallen doen echte schade. Gebruik het vaandel om te stoppen. Geen buit of XP; de uitgang blijft vrij.")])
		return
	running = true
	countdown = 2.5
	GameState.toast.emit(tr("Oefening %d / 3: houd de oranje banen in de gaten.") % (lesson+1))

func stop() -> void:
	for foe in foes:
		if is_instance_valid(foe): foe.queue_free()
	foes.clear()
	for shot in world.entities.get_children():
		if shot.get_script() == preload("res://scripts/entities/projectile.gd"): shot.queue_free()
	running = false
	countdown = 0.0

func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if not running or GameState.input_locked(): return
	if countdown > 0:
		countdown -= delta
		if countdown <= 0:
			for i in LESSONS[lesson].size():
				if world.player.global_position.distance_to(SPAWNS[i]) < 65:
					countdown = 0.2
					return
			for i in LESSONS[lesson].size():
				var foe: Node2D = world.spawn_enemy(LESSONS[lesson][i],SPAWNS[i])
				foe.set_meta("practice",true)
				foe.state_time = 0.0
				foes.append(foe)
		return
	for i in range(foes.size()-1,-1,-1):
		if not is_instance_valid(foes[i]) or foes[i].dead: foes.remove_at(i)
	if foes.is_empty():
		running = false
		lesson = (lesson+1)%3
		GameState.toast.emit(tr("Goed geoefend. Bij het vaandel kun je de volgende oefening starten."))
		Sound.play("quest",-9.0)

func _draw() -> void:
	if obj.get("kind","") == "rack":
		DrawUtil.ellipse(self,Vector2(0,14),Vector2(36,5),Color(0,0,0,0.25))
		DrawUtil.sprite(self,Art.tex("cv_rack"),0,0,Vector2(0,-8),Vector2i(40,24),2)
		return
	if obj.get("kind","") == "entrance":
		draw_arc(Vector2(-64,0),15,0,TAU,32,Color(0.55,0.85,1,0.6+sin(t*2)*0.2),2)
		draw_line(Vector2(-45,5),Vector2(-55,0),Color(0.85,0.93,1),2)
		draw_line(Vector2(-45,-5),Vector2(-55,0),Color(0.85,0.93,1),2)
	DrawUtil.ellipse(self,Vector2(0,12),Vector2(12,4),Color(0,0,0,0.25))
	DrawUtil.sprite(self,Art.tex("cv_posts"),int(t*3)%2,0,Vector2(0,-6),Vector2i(24,32),2)
	if world.player.target == self: DrawUtil.prompt(self,Vector2(0,-47),t)
	if countdown > 0:
		for i in LESSONS[lesson].size():
			var at: Vector2 = SPAWNS[i]-global_position
			draw_arc(at,22,0,TAU,32,Color(1,0.65,0.3),2)
			DrawUtil.prompt(self,at+Vector2(0,-30),t,str(ceili(countdown)))
