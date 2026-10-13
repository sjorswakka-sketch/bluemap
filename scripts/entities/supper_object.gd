extends StaticBody2D
const Supper := preload("res://scripts/core/lake_supper.gd")
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
var world: Node2D
var obj: Dictionary={}
var key := ""
var kind := "notice"
var time := 0.0
var progress := 0.0
var pulling := false
var origin := Vector2.ZERO
var health := 0
var stitch := 0

func _ready() -> void:
	kind=obj.get("kind","notice")
	add_to_group("interactable")
	add_to_group("supper_objects")
	collision_layer=0
	if kind in ["stove","table","net","notice"]:
		collision_layer=1
		var collider:=CollisionShape2D.new()
		var box:=RectangleShape2D.new()
		box.size=Vector2(78,26) if kind=="table" else Vector2(22,12)
		collider.shape=box
		collider.position=Vector2(0,5)
		add_child(collider)
		# A saved position from the previous version may be under the new furniture.
		var occupied:=Rect2(position+collider.position-box.size/2-Vector2(10,12),box.size+Vector2(20,24))
		if occupied.has_point(world.player.position):
			for offset in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
				var safe: Vector2=position+offset*52
				if not world.is_solid(safe) and not occupied.has_point(safe):
					world.player.position=safe
					break
	if kind=="basket" and GameState.flag("ls_basket"):
		remove_from_group("interactable")
		hide()

func label() -> String:
	match kind:
		"basket": return tr("Losgeraakte vismand")
		"net": return tr("Joris' nettenrek")
		"stove": return tr("Mila's fornuis")
		"table": return tr("De dorpstafel")
	return tr("Een plek aan tafel")

func interact() -> void:
	if GameState.input_locked() or pulling: return
	match kind:
		"notice": GameState.start_dialogue("ls_invite")
		"basket":
			if GameState.flag("ls_basket"): return
			if GameState.count("fishing_rod")==0:
				GameState.say(label(),[tr("De mand zit vast tussen de palen. Leen een hengel van Joris en haal hem vanaf de steiger rustig naar je toe.")])
				return
			GameState.start_quest("ls_supper")
			pulling=true
			progress=0
			origin=world.player.position
			health=GameState.hp
			GameState.toast.emit(tr("De lijn zit vast. Blijf even staan om de mand binnen te halen."))
		"net":
			if GameState.flag("ls_net"):
				GameState.say(label(),[tr("Het net is weer heel. Joris kan zijn vangst nu veilig bewaren.")])
			else:
				Supper.pending=weakref(self)
				GameState.start_dialogue("ls_net")
		"stove":
			var ui:=world.get_node_or_null("SupperKitchen")
			if ui==null:
				ui=load("res://scripts/ui/supper_kitchen.gd").new()
				ui.name="SupperKitchen"
				world.add_child(ui)
			ui.open(self)
		"table":
			if GameState.flag("ls_served"):
				GameState.say(label(),[tr("De tafel blijft gedekt. Jouw gerecht staat op Mila's kaart. Met verse baars kun je bij het fornuis opnieuw koken; de recepten staan ook bij Beroepen.")])
			elif not GameState.flag("ls_cooked") or GameState.count("ls_chowder")+GameState.count("ls_broth")==0:
				GameState.start_quest("ls_supper")
				GameState.say(label(),[tr("Hier komt iedereen samen zodra het eten klaar is. Bereid een portie bij het fornuis links van de eetkamer. De maaltijd kan op elk moment beginnen.")])
			else:
				Supper.pending=weakref(self)
				GameState.start_dialogue("ls_share")

func weave(side: String) -> void:
	if GameState.flag("ls_net"): return
	if side != ["over","under","over"][stitch]:
		stitch=0
		GameState.toast.emit(tr("De draad schiet los. Volg opnieuw: boven, onder, boven."))
		return
	stitch+=1
	Sound.play("ls_chop",-12)
	if stitch==3:
		GameState.set_flag("ls_net")
		GameState.give("meer_baars",2,true)
		GameState.give("prof_herb",1,true)
		Supper.Professions.add_xp("fishing",8)
		GameState.save_requested.emit()

func share(dish: String) -> void:
	if GameState.flag("ls_served") or not GameState.flag("ls_cooked") or dish not in Supper.DISHES or GameState.count(dish)<1: return
	GameState.set_flag("ls_served") # commit before inventory/quest signals
	GameState.set_flag("ls_favorite_broth",dish=="ls_broth")
	GameState.take(dish,1)
	GameState.start_quest("ls_supper")
	GameState.finish_quest("ls_supper")
	Sound.play("ls_serve",-6)
	GameState.toast.emit(tr("Er is een plek voor iedereen. Praat met de gasten; beide recepten zijn nu blijvend beschikbaar."))
	GameState.save_requested.emit()

func _process(delta: float) -> void:
	time+=delta
	if pulling:
		if GameState.input_locked() or world.player.position.distance_to(origin)>8 or GameState.hp<health or preload("res://scripts/core/first_route.gd").loud(world.player):
			pulling=false
			progress=0
		else:
			progress+=delta
			if progress>=1.8:
				pulling=false
				if not GameState.flag("ls_basket"):
					GameState.set_flag("ls_basket")
					GameState.give("ls_crate",1)
					GameState.save_requested.emit()
					Sound.play("ls_reel",-7)
					GameState.toast.emit(tr("De vangst is gered! Breng de maaltijdmand naar Mila's fornuis in de herberg."))
				remove_from_group("interactable")
				hide()
	queue_redraw()

func _draw() -> void:
	if kind=="table":
		var frame:=0
		if GameState.flag("ls_served"): frame=2 if GameState.flag("ls_favorite_broth") else 1
		DrawUtil.sprite(self,Art.tex("ls_table"),frame,0,Vector2.ZERO,Vector2i(48,32))
	elif kind=="net":
		DrawUtil.sprite(self,Art.tex("ls_net"),1 if GameState.flag("ls_net") else 0,0,Vector2(0,-7),Vector2i(24,24))
	elif kind=="stove":
		DrawUtil.sprite(self,Art.tex("ls_stove"),int(time*3)%2,0,Vector2(0,-4),Vector2i(24,24))
		for i in 3:
			var rise:=fmod(time*9+i*6,22)
			draw_circle(Vector2(-6+i*6+sin(time*2+i)*2,-24-rise),1.7,Color(0.95,0.89,0.73,(1-rise/22)*0.4))
	elif kind=="basket":
		var at:=Vector2(sin(time)*3,sin(time*2)*2)
		DrawUtil.ellipse(self,at+Vector2(0,9),Vector2(17,5),Color(0.8,0.94,1,0.5))
		DrawUtil.sprite(self,Art.tex("ls_items"),0,0,at)
		if pulling:
			draw_line(world.player.position-position+Vector2(0,-10),at,Color("e6d7ad"),1)
			draw_rect(Rect2(-19,-27,38*minf(progress/1.8,1),3),Color("c3e3c1"))
	else:
		DrawUtil.sprite(self,Art.tex("ls_notice"),0,0)
	if world.player.target==self and not pulling:
		DrawUtil.name_tag(self,Vector2(0,-42 if kind in ["net","stove"] else -30),label())
		DrawUtil.prompt(self,Vector2(0,-58 if kind in ["net","stove"] else -46),time)
