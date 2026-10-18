extends StaticBody2D
## Een kist met spullen erin. Eenmaal geopend blijft hij open (ook na opslaan).

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Util := preload("res://scripts/core/util.gd")
const Items := preload("res://scripts/data/items.gd")

var contents: Array = [] # [["potion", 1], ["coins", 25]]
var unique_key := ""
var world: Node
var opened := false
var t := 0.0
var player: Node2D


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	opened = unique_key != "" and GameState.flag(unique_key)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 12)
	shape.shape = rect
	shape.position = Vector2(0, 6)
	add_child(shape)


func _process(delta: float) -> void:
	t += delta
	if player == null:
		player = Util.player(self)
	queue_redraw()


func interact() -> void:
	if opened:
		GameState.toast.emit(tr("De kist is leeg."))
		return
	# A unique reward already owned (including worn gear) is fulfilled ownership,
	# not a full bag. Other rewards remain claimable. Aggregate repeated stacks
	# before checking capacity so opening can never silently truncate later loot.
	var totals: Dictionary={}
	for entry: Array in contents:
		var item: String=entry[0]
		totals[item]=int(totals.get(item,0))+int(entry[1])
	var already_owned: Array[String]=[]
	var grants: Dictionary={}
	for item: String in totals:
		if item=="coins":continue
		var info:=Items.info(item)
		if int(info.get("max",0))==1 and GameState.count(item)>0:
			already_owned.append(item)
			continue
		var space:=GameState.room(item)
		if space<int(totals[item]):
			Sound.play("error", -3.0)
			if info.has("chest_full_text"):GameState.toast.emit(tr(info["chest_full_text"]))
			elif space==0:GameState.toast.emit(GameState.full_text(item))
			else:GameState.toast.emit(tr("Niet genoeg ruimte voor %s: %d nodig, %d vrij.") % [tr(info["name"]),int(totals[item]),space])
			return
		grants[item]=int(totals[item])
	# Commit all inventory, money and the original saved flag before emitting
	# synchronous quest/UI/save notifications. Reentrant interaction sees opened.
	opened = true
	if unique_key != "":
		GameState.flags[unique_key]=true
	for item: String in grants:GameState.inventory[item]=GameState.count(item)+int(grants[item])
	var coins:=int(totals.get("coins",0))
	GameState.coins=maxi(0,GameState.coins+coins)
	if grants.has("heart_container"):
		GameState.hp=mini(GameState.hp+int(grants.heart_container),GameState.max_hp())
	GameState._mark_achievements()
	if grants.has("heart_container"):GameState.hp_changed.emit()
	GameState.items_changed.emit()
	GameState._refresh_quests()
	Sound.play("chest")
	world.burst(global_position + Vector2(0, -6), Color(1, 0.9, 0.5), 12)
	for item: String in already_owned:GameState.toast.emit(GameState.full_text(item))
	if coins!=0:GameState.toast.emit(tr_n("Gevonden: %d munt", "Gevonden: %d munten", coins) % coins)
	for item: String in grants:
		var label:=tr(Items.info(item)["name"]);var amount:=int(grants[item])
		GameState.toast.emit(tr("Gekregen: %s") % label if amount==1 else tr("Gekregen: %s x%d") % [label,amount])
	GameState.save_requested.emit()


func _draw() -> void:
	DrawUtil.ellipse(self, Vector2(0, 12), Vector2(11, 3.5), Color(0, 0, 0, 0.3))
	DrawUtil.sprite(self, Art.tex("chest"), 1 if opened else 0, 0)
	if not opened and player and player.target == self:
		DrawUtil.prompt(self, Vector2(0, -26.0), t)
