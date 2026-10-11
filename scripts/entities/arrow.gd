extends Node2D
## Een pijl van de speler (de boog, F). Hij vliegt rechtdoor en raakt de eerste vijand of het eerste doelwit op zijn
## pad. Tegen een muur (of een poortje, personage, kist...) blijft hij steken; over water vliegt hij gewoon heen.
##
## Een uitbreiding kan meer tegels laten overvliegen (zoals waterlelies) met `const ARROW_OVER := ["tegelnaam"]` in haar
## module (zie scripts/data/content.gd).

const DrawUtil := preload("res://scripts/core/draw_util.gd")
const Art := preload("res://scripts/core/art.gd")
const Tiles := preload("res://scripts/data/tiles.gd")
const Content := preload("res://scripts/data/content.gd")

const SPEED := 320.0
const RANGE := 280.0 # na zoveel pixels valt hij neer
const DAMAGE := 2
const BOSS_DAMAGE := 1 # bazen houden het gevecht eerlijk: een pijl doet daar maar 1 schade
const HIT_MARGIN := 3.0 # hoe ruim de punt van de pijl een vijand of doelwit raakt
const BODY_OFFSET := Vector2(0, 4) # het lichaam van een vijand zit iets onder zijn middelpunt (net als de handen van de speler)
const MAX_STEP := 8.0 # in stukjes vliegen, zodat hij nooit dwars door iets heen springt
const STICK_TIME := 0.6 # hoe lang hij in de muur blijft zitten
const FADE_TIME := 0.25
const OVER := ["water"] # tegels waar je wel overheen kunt schieten, ook al kun je er niet op lopen
const ICON_FRAME := 2 # het vliegende pijltje in items_boog.png
const TRAIL := 16.0 # lengte van het spoor achter de pijl
const AIR_HEIGHT := 4.0 # een vijand die hoger in de lucht hangt (springende baas) kun je niet raken
## Vijanden met een pantser (op gedrag): een pijl ketst af, behalve als ze in een van deze toestanden zijn. De
## kristalgolem is alleen kwetsbaar als hij uithaalt voor een klap of net heeft geslagen. Zo schiet je hem niet
## zonder gevaar van veraf kapot: je moet dichtbij komen, net als met het zwaard.
const ARMOR := {"golem": ["windup", "recover"]}
const BOUNCE_SPEED := 110.0 # een afgeketste pijl tolt nog even terug...
const BOUNCE_TIME := 0.4 # ...en is dan weg
const BOUNCE_SPIN := 18.0 # radialen per seconde
const SPARK := Color(0.75, 0.9, 1.0) # vonkjes van het kristal

static var _over_tiles: Array = []

var world: Node
var direction := Vector2.RIGHT
var damage := DAMAGE
var traveled := 0.0
var state := "flying" # flying, stuck, fading of bounce (afgeketst)
var timer := 0.0
var spin := 0.0


func _physics_process(delta: float) -> void:
	match state:
		"flying":
			_advance(SPEED * delta)
		"bounce":
			position -= direction * BOUNCE_SPEED * (timer / BOUNCE_TIME) * delta
			spin += BOUNCE_SPIN * delta
			timer -= delta
			if timer <= 0.0:
				queue_free()
				return
		"stuck", "fading":
			timer -= delta
			if timer <= 0.0:
				if state == "stuck":
					state = "fading"
					timer = FADE_TIME
				else:
					queue_free()
					return
	queue_redraw()


## Het eerste stukje, van de hand van de speler tot voor hem. Met dezelfde botsingen als in de vlucht, zodat de pijl
## niet door een poortje of kist springt waar je tegenaan staat. Dit stukje telt niet mee voor het bereik.
func launch(distance: float) -> void:
	_advance(distance)
	traveled = 0.0


func _advance(distance: float) -> void:
	var left := distance
	while left > 0.0 and state == "flying":
		var step := minf(left, MAX_STEP)
		left -= step
		var from := position
		var to := from + direction * step
		if _hit_something(from, to):
			return
		if _blocked(to) or _blocked_by_body(from, to):
			_stick(from)
			return
		position = to
		traveled += step
		if traveled >= RANGE:
			_land()
			return


## Raakt de pijl op dit stukje pad een doelwit of een vijand? Dan is hij op.
func _hit_something(from: Vector2, to: Vector2) -> bool:
	var best: Node2D = null
	var best_dist := INF
	for target: Node2D in get_tree().get_nodes_in_group("boog_target"):
		var distance := _segment_distance(target.hit_center(), from, to)
		if distance <= target.hit_radius() + HIT_MARGIN:
			var along := from.distance_to(target.hit_center())
			if along < best_dist:
				best = target
				best_dist = along
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if not _can_be_hit(enemy):
			continue
		var center := enemy.global_position + BODY_OFFSET
		if _segment_distance(center, from, to) <= enemy.radius + HIT_MARGIN:
			var along := from.distance_to(center)
			if along < best_dist:
				best = enemy
				best_dist = along
	if best == null:
		return false
	position = to
	if best.is_in_group("boog_target"):
		best.arrow_hit(self)
		world.burst(global_position, Color(1, 0.95, 0.6), 4)
	elif _armored(best):
		_bounce(best)
		return true
	else:
		best.hurt(BOSS_DAMAGE if _is_boss(best) else damage, direction)
		world.burst(global_position, Color(1, 1, 1), 4)
	queue_free()
	return true


## Slapende bazen en de Slijmkoning in de lucht raak je niet: de pijl vliegt erlangs of eronderdoor.
func _can_be_hit(enemy: Node2D) -> bool:
	if enemy.get("dead") == true or enemy.get("active") == false:
		return false
	var height: Variant = enemy.get("air_height")
	return height == null or float(height) <= AIR_HEIGHT


## Ketst de pijl nu af op het pantser van deze vijand?
func _armored(enemy: Node2D) -> bool:
	var info: Variant = enemy.get("data")
	if not (info is Dictionary) or not ARMOR.has((info as Dictionary).get("behavior", "")):
		return false
	return not (enemy.get("state") in ARMOR[(info as Dictionary)["behavior"]])


## Afgeketst: een tik, vonkjes en de pijl tolt terug. De eerste keer bij deze vijand vertelt een melding wat je moet doen.
func _bounce(enemy: Node2D) -> void:
	state = "bounce"
	timer = BOUNCE_TIME
	Sound.play("boog_kets", -4.0, randf_range(0.95, 1.08))
	world.burst(global_position, SPARK, 8)
	world.damage_number(global_position + Vector2(0, -18), "Ketst af!", SPARK)
	if not enemy.has_meta("boog_kets_hint"):
		enemy.set_meta("boog_kets_hint", true)
		GameState.toast.emit("Je pijl ketst af op het kristal! Schiet als de golem uithaalt voor een klap.")


func _is_boss(enemy: Node2D) -> bool:
	var info: Variant = enemy.get("data")
	return info is Dictionary and (info as Dictionary).get("boss", false)


func _segment_distance(point: Vector2, from: Vector2, to: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, from, to))


## Zit er op deze plek een muur, boom of rots? Water telt niet mee.
func _blocked(pos: Vector2) -> bool:
	if not world.is_solid(pos):
		return false
	var cell := Vector2i(int(floorf(pos.x / world.TILE)), int(floorf(pos.y / world.TILE)))
	var rows: Array = world.map_data["rows"]
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= String(rows[cell.y]).length():
		return true # buiten de kaart
	return not (Tiles.name_for(String(rows[cell.y])[cell.x], cell.x, cell.y) in over_tiles())


## De tegels waar een pijl overheen vliegt: water, plus wat uitbreidingen erbij zetten (ARROW_OVER).
static func over_tiles() -> Array:
	if _over_tiles.is_empty():
		_over_tiles = Content.appended("ARROW_OVER", OVER)
	return _over_tiles


## Poortjes, personages, kisten en borden zijn geen tegels maar wel in de weg.
func _blocked_by_body(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.hit_from_inside = true # begint het stukje al in een kist of poortje, dan telt dat ook
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] is StaticBody2D


func _stick(at: Vector2) -> void:
	state = "stuck"
	timer = STICK_TIME
	position = at + direction * 4.0 # de punt zit net in de muur
	world.burst(position + direction * 3.0, Color(0.85, 0.8, 0.7), 4)
	Sound.play("hit", -9.0, 1.6)


## Aan het eind van zijn bereik valt hij neer. In het water geeft dat een plons.
func _land() -> void:
	state = "fading"
	timer = FADE_TIME
	if world.is_solid(position):
		world.burst(position, Color(0.6, 0.8, 1.0), 6)
		world.ring(position, 12.0, Color(0.7, 0.88, 1.0))


func _draw() -> void:
	var alpha := 1.0
	if state == "fading":
		alpha = clampf(timer / FADE_TIME, 0.0, 1.0)
	elif state == "bounce":
		alpha = clampf(timer / BOUNCE_TIME * 1.5, 0.0, 1.0)
	elif state == "flying":
		# Een zacht spoor achter de pijl, zodat je hem ziet komen.
		for i in 3:
			var from := -direction * (TRAIL * float(i) / 3.0 + 6.0)
			var to := -direction * (TRAIL * float(i + 1) / 3.0 + 6.0)
			draw_line(from, to, Color(1, 1, 1, 0.35 - float(i) * 0.1), 2.0)
	var wiggle := 0.0
	if state == "stuck":
		wiggle = sin(timer * 70.0) * 0.12 * clampf(timer / STICK_TIME * 3.0, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, direction.angle() + wiggle + spin, Vector2.ONE)
	DrawUtil.sprite(self, Art.tex("items_boog"), ICON_FRAME, 0, Vector2.ZERO, Vector2i(16, 16), 2.0, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
