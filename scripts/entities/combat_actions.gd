extends RefCounted
## Deliberate techniques: pay stamina on preparation, commit aim, then recover.
## No extra save state. A cancelled preparation never spends an arrow.
const PROFILES := {
	"wood": {"name":"Snelle steek", "cost":16.0, "windup":0.18, "reach":16.0, "cone":0.8, "bonus":0},
	"iron": {"name":"Breekslag", "cost":28.0, "windup":0.42, "reach":4.0, "cone":-0.25, "bonus":1},
	"crystal": {"name":"Kristalsteek", "cost":24.0, "windup":0.32, "reach":34.0, "cone":0.9, "bonus":1},
}
var phase := ""
var elapsed := 0.0
var recovery := 0.0
var profile: Dictionary = {}
var direction := Vector2.DOWN
var ranged := false
var hint_time := 0.0

static func effective_profile(weapon: String, bow := false) -> Dictionary:
	var equipment: Script = preload("res://scripts/core/equipment.gd")
	var result: Dictionary = {"name":"Precisieschot","cost":20.0,"windup":0.65} if bow else PROFILES.get(weapon,PROFILES.wood).duplicate()
	result.cost = maxf(1,roundf(float(result.cost)*(1-equipment.bonus("technique_cost_reduction"))))
	if bow: result.windup = float(result.windup)*(1-equipment.bonus("bow_preparation_reduction"))
	return result

static func display_name(weapon: String) -> String:
	match weapon:
		"iron": return TranslationServer.translate("Breekslag")
		"crystal": return TranslationServer.translate("Kristalsteek")
	return TranslationServer.translate("Snelle steek")

func busy() -> bool:
	return phase != "" or recovery > 0.0

func cancel() -> void:
	phase = ""
	elapsed = 0.0

func begin(p: Node2D, bow: bool) -> void:
	if busy() or p.roll_timer > 0 or p.cooldown > 0 or p.bow_cooldown > 0 or GameState.input_locked(): return
	if bow and (GameState.count("bow") <= 0 or (GameState.count("arrow") <= 0 and not p._lent_arrow())):
		p._shoot(false)
		return
	profile = effective_profile(GameState.weapon,bow)
	if not GameState.movement.spend(profile.cost):
		if hint_time <= 0:
			GameState.toast.emit(tr("Deze techniek vraagt %d stamina. Gewone aanvallen blijven beschikbaar.") % int(profile.cost))
			hint_time = 2.5
		return
	p.cancel_work_animation()
	p._update_aim()
	direction = p.aim_direction
	ranged = bow
	phase = "prepare"
	elapsed = 0.0
	p.combo_step = 0
	p.combo_window = 0.0
	Sound.play("cv_ready", -9.0, 1.2 if bow else 0.8)

func update(p: Node2D, delta: float) -> void:
	hint_time = maxf(0.0, hint_time - delta)
	recovery = maxf(0.0, recovery - delta)
	if GameState.input_locked():
		cancel()
		return
	if phase == "": return
	elapsed += delta
	if phase == "prepare" and elapsed >= float(profile.windup):
		phase = "strike"
		elapsed = 0.0
		recovery = 0.5 if ranged else 0.4
		if ranged:
			# Validate inventory again; menus and device changes cancel preparation.
			if GameState.count("bow") > 0 and (GameState.count("arrow") > 0 or p._lent_arrow()):
				p._shoot(false, true, direction)
		else:
			var reach: float = GameState.reach() + float(profile.reach)
			for foe: Node2D in p.get_tree().get_nodes_in_group("enemies"):
				var offset: Vector2 = foe.global_position - p.global_position
				if offset.length() <= reach + foe.radius and direction.dot(offset.normalized()) >= float(profile.cone) and p._attack_clear(foe.global_position):
					if foe.has_method("break_guard"): foe.break_guard()
					foe.hurt(GameState.damage() + int(profile.bonus), direction)
			for thing: Node2D in p.get_tree().get_nodes_in_group("breakable"):
				if p._attack_clear(thing.global_position): thing.sword_hit(p.global_position, direction, reach)
			Sound.play("cv_strike", -4.0)
	elif phase == "strike" and elapsed >= 0.2:
		phase = ""

func draw(p: Node2D) -> void:
	if phase == "": return
	var color := Color(0.55,0.9,1)
	if phase == "prepare":
		var progress := clampf(elapsed / float(profile.windup),0,1)
		p.draw_rect(Rect2(-15,-28,30,4),Color(0.03,0.07,0.1))
		p.draw_rect(Rect2(-14,-27,28*progress,2),color)
		p.draw_line(direction*12,direction*32,Color(color,0.5),2)
		if ranged:
			p.draw_arc(direction*12,11,direction.angle()-PI/2,direction.angle()+PI/2,12,color,2)
		else:
			p.draw_line(-direction*4,-direction*17,color,3)
	elif not ranged:
		var reach: float = GameState.reach() + float(profile.reach)
		var length: float = reach * sin(clampf(elapsed/0.2,0,1)*PI)
		if float(profile.cone) < 0:
			p.draw_arc(Vector2.ZERO,reach-4,direction.angle()-1.8,direction.angle()+1.8,24,Color(color,0.6),5)
		else:
			p.draw_line(direction*8,direction*length,color,5)
			p.draw_line(direction*8,direction*length,Color.WHITE,1)
