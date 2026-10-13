extends StaticBody2D
const Region:=preload("res://scripts/core/regional_adventures.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
const Art:=preload("res://scripts/core/art.gd")
var world: Node2D
var obj: Dictionary={}
var key: String=""
var kind: String=""
var time:=0.0

func _ready() -> void:
	kind=obj.get("kind","")
	add_to_group("regional_objects")
	add_to_group("interactable")
	collision_layer=1
	var shape:=CollisionShape2D.new()
	var box:=RectangleShape2D.new()
	box.size=Vector2(22,12)
	if kind=="shelf":
		box.size=Vector2(46,12)
		remove_from_group("interactable")
	shape.shape=box
	shape.position=Vector2(0,6)
	add_child(shape)
	# Existing saves may be standing where a new landmark is placed.
	if Rect2(position+shape.position-box.size/2-Vector2(10,12),box.size+Vector2(20,24)).has_point(world.player.position):
		for offset in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
			var safe: Vector2=position+offset*40
			if not world.is_solid(safe):
				world.player.position=safe
				break

func label() -> String:
	return tr(str(obj.get("name","")))

func director() -> Node:
	for node in get_tree().get_nodes_in_group("regional_director"):
		if not node.is_queued_for_deletion() and node.world==world: return node
	return null

func interact() -> void:
	if GameState.input_locked(): return
	match kind:
		"water":
			GameState.start_quest("cactusvijgen")
			if GameState.count("ra_waterskin")==0: GameState.give("ra_waterskin",1,true)
			Region.mark("ra_prepared")
			GameState.say(label(),[tr("Een volle waterzak, gratis van Nour. In de Zonnekloof drink je automatisch. Onder blauwe luifels kun je bijvullen. De ingang ligt in de noordelijke zandsteenwand, rechts van de oase.")])
		"refill":
			var route:=director()
			if route!=null: route.refill(position+Vector2(0,36))
			Sound.play("ra_water",-8)
		"spring": Region.open(self,"ra_spring")
		"camp":
			GameState.start_quest("ra_ridge")
			if GameState.flag("ra_chart") and GameState.flag("ra_rope") and not GameState.flag("ra_ridge_done"):
				GameState.set_flag("ra_ridge_done")
				GameState.finish_quest("ra_ridge")
				GameState.give("gear_ra_grip",1,true)
				GameState.save_requested.emit()
				Sound.play("quest")
				GameState.say(label(),[tr("De weerkaart hangt weer in het kamp. De bewoners weten nu wanneer de pas rustig is. Neem deze klimhandschoenen mee; de gespannen lijn blijft bruikbaar.")])
			else:
				Region.mark("ra_rope_kit")
				GameState.say(label(),[tr("Neem het klimtouw mee. De verloren weerkaart ligt bij de zuidoostelijke schuilhut. Steek bovenlangs over: slappe wimpels betekenen rust, gele wimpels waarschuwen, witte sneeuwstrepen betekenen wind.") ,tr("Een windstoot brengt je terug naar de veilige kant. Zet het touw vast aan de oostelijke paal om voortaan beschermd over te steken. Je verliest geen hartjes of spullen.")])
		"anchor":
			if not GameState.flag("ra_rope_kit"):
				GameState.say(label(),[tr("Haal eerst het klimtouw bij het kamp naast de ingang.")])
			else:
				Region.mark("ra_rope")
				Sound.play("ra_rope",-6)
				GameState.toast.emit(tr("De lijn zit vast. Windvlagen houden je hier niet meer tegen."))
		"chart":
			GameState.start_quest("ra_ridge")
			Region.mark("ra_chart")
			GameState.say(label(),[tr("Tussen de sneeuw ligt de weerkaart. Breng hem naar het kamp bij de ingang; de markeringen helpen reizigers de wind te lezen.")])
		"folio":
			GameState.start_quest("ra_archive")
			Region.mark(str(obj["id"]))
			GameState.say(label(),[tr(str(obj["clue"]))])
		"desk":
			GameState.start_quest("ra_archive")
			if not GameState.flag("ra_folio_reed") or not GameState.flag("ra_folio_port") or not GameState.flag("ra_folio_flood"):
				GameState.say(label(),[tr("Drie reliëfs vertellen hoe het moeras veranderde. Onderzoek de rietvelden in het zuidwesten, de aanlegplaats in het noordwesten en de hoogwatersteen in het noordoosten. Lees daarna hier hun volgorde.")])
			else: Region.open(self,"ra_exhibit" if GameState.flag("ra_archive_done") else "ra_order")
		"exhibit":
			if GameState.flag("ra_archive_done"):
				Region.open(self,"ra_exhibit")
			else: GameState.say(label(),[tr("Mees heeft ruimte vrijgemaakt voor een tentoonstelling. In het Rietarchief onder het eiland wachten de oude reliëfs.")])

func choose(choice: String) -> void:
	if kind=="spring" and choice in ["wild","caravan"]:
		if not GameState.flag("ra_prepared") and not GameState.flag("ra_spring"): return
		GameState.set_flag("ra_spring")
		GameState.set_flag("ra_water_wild",choice=="wild")
		GameState.set_flag("ra_water_caravan",choice=="caravan")
		GameState.start_quest("cactusvijgen")
		GameState.save_requested.emit()
		Sound.play("ra_water",-6)
		GameState.toast.emit(tr("De bron stroomt weer. Vertel Sana bij de oase waar het water naartoe gaat."))
	elif kind=="desk" and choice in ["correct","wrong"] and not GameState.flag("ra_archive_done"):
		if not GameState.flag("ra_folio_reed") or not GameState.flag("ra_folio_port") or not GameState.flag("ra_folio_flood"): return
		if choice=="wrong":
			GameState.toast.emit(tr("Kijk naar wat er bijkomt: eerst riet zonder huizen, dan de aanlegplaats, pas daarna het hoge water boven diezelfde palen."))
			return
		GameState.set_flag("ra_archive_done")
		GameState.set_flag("ra_exhibit_routes")
		GameState.finish_quest("ra_archive")
		GameState.give("gear_ra_compass",1,true)
		GameState.save_requested.emit()
		Sound.play("ra_pages",-6)
	elif kind in ["desk","exhibit"] and GameState.flag("ra_archive_done") and choice in ["routes","stories"]:
		GameState.set_flag("ra_exhibit_routes",choice=="routes")
		GameState.save_requested.emit()
		GameState.toast.emit(tr("De tentoonstelling bij Mees is bijgewerkt. Je kunt je keuze hier later veranderen."))

func _process(delta: float) -> void:
	time+=delta
	queue_redraw()

func _draw() -> void:
	if kind=="shelf":
		DrawUtil.sprite(self,Art.tex("ra_shelf"),0,0,Vector2(0,-20),Vector2i(28,32))
		return
	var frame: int={"water":0,"refill":0,"spring":1,"camp":2,"anchor":3,"chart":4,"folio":5,"desk":6,"exhibit":6}.get(kind,0)
	DrawUtil.sprite(self,Art.tex("ra_objects"),frame,0,Vector2(0,-8),Vector2i(24,24))
	if kind in ["water","refill","spring"]:
		if kind!="spring" or GameState.flag("ra_spring"):
			for i in 4:
				var y:=fmod(time*12+i*5,18)
				draw_line(Vector2(-4+i*3,-14+y),Vector2(-4+i*3,-11+y),Color("acdceb"),1)
	if kind=="anchor" and GameState.flag("ra_rope"):
		draw_line(Vector2(-20,-5),Vector2(0,-10),Color("e6c987"),3)
	if kind=="camp":
		var col:=Color("eecb77") if GameState.flag("ra_ridge_done") else Color("d28564")
		draw_colored_polygon(PackedVector2Array([Vector2(8,-25),Vector2(28,-23+sin(time*4)*3),Vector2(8,-16)]),col)
	if kind=="folio":
		var index: int={"ra_folio_reed":0,"ra_folio_port":1,"ra_folio_flood":2}.get(obj.get("id",""),0)
		DrawUtil.sprite(self,Art.tex("ra_reliefs"),index,0,Vector2(0,-12),Vector2i(20,14),1.5)
	if kind in ["desk","exhibit"] and GameState.flag("ra_archive_done"):
		var col:=Color("8ec9d4") if GameState.flag("ra_exhibit_routes") else Color("e5b27c")
		draw_line(Vector2(-17,-16),Vector2(15,-16),col,3)
	if world.player.target==self:
		DrawUtil.name_tag(self,Vector2(0,-39),label())
		DrawUtil.prompt(self,Vector2(0,-54),time)
