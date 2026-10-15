extends RefCounted
const Equipment:=preload("res://scripts/core/equipment.gd")
static func mode(bow: bool) -> String:
 var worn:=Equipment.equipped("hands")
 if worn=="gear_cw_anchor" and not bow:return "cw_anchor"
 if worn=="gear_cw_fan" and bow:return "cw_fan"
 return ""
static func profile(bow: bool) -> Dictionary:
 if mode(bow)=="cw_anchor":return {"name":TranslationServer.translate("Ankerwacht"),"mode":"cw_anchor","cost":18.0,"windup":0.12,"reach":20.0,"cone":0.86,"bonus":1}
 if mode(bow)=="cw_fan":return {"name":TranslationServer.translate("Waaierschot"),"mode":"cw_fan","cost":28.0,"windup":0.55,"arrows":3}
 return {}
static func valid(c: RefCounted) -> bool:return str(c.profile.get("mode",""))==mode(c.ranged) and (c.origin_map=="" or c.origin_map==GameState.map_id)
static func update(c: RefCounted,p: Node2D) -> bool:
 var kind: String=c.profile.get("mode","")
 if kind=="":return false
 if not valid(c):c.cancel();return true
 if kind!="cw_anchor":return false
 if c.phase=="prepare" and c.elapsed>=0.12:c.phase="guard";c.elapsed=0
 elif c.phase=="guard" and c.elapsed>=0.32:c.phase="";c.recovery=0.6
 elif c.phase=="counter" and c.elapsed>=0.7:c.phase="";c.recovery=0.4
 elif c.phase=="strike" and c.elapsed>=0.2:c.phase=""
 p.queue_redraw()
 return true
static func block(c: RefCounted,p: Node2D,from: Vector2) -> bool:
 if c.phase!="guard" or c.elapsed>0.32 or c.profile.get("mode","")!="cw_anchor" or not valid(c) or GameState.input_locked():return false
 var offset:=from-p.position
 if offset.length()<1 or c.direction.dot(offset.normalized())<0.5 or not p._attack_clear(from):return false
 c.phase="counter";c.elapsed=0
 Sound.play("cw_guard",-8);p.world.ring(p.position,28,Color("b3e2da"));p.queue_redraw()
 return true
static func counter(c: RefCounted,p: Node2D) -> bool:
 if c.phase!="counter" or c.profile.get("mode","")!="cw_anchor" or not valid(c) or GameState.input_locked():return false
 c.phase="strike";c.elapsed=0;c.recovery=0.6
 var reach: float=GameState.reach()+20.0
 for e: Node2D in p.get_tree().get_nodes_in_group("enemies"):
  if e.is_queued_for_deletion():continue
  var offset: Vector2=e.position-p.position
  if offset.length()<=reach+e.radius and c.direction.dot(offset.normalized())>=0.86 and p._attack_clear(e.position):
   if e.has_method("break_guard"):e.break_guard()
   e.hurt(GameState.damage()+1,c.direction)
 Sound.play("cw_guard",-11,1.3);return true
static func arrows_ready(p: Node2D) -> bool:return GameState.count("bow")>0 and (p._lent_arrow() or GameState.count("arrow")>=3)
static func release_fan(c: RefCounted,p: Node2D) -> bool:
 if not valid(c) or not arrows_ready(p):return false
 if not p._lent_arrow():GameState.take("arrow",3)
 p.bow_cooldown=0.9;p.bow_anim=p.BOW_ANIM_TIME;p.bow_direction=c.direction
 for angle in [-0.4,0.0,0.4]:
  var a: Node2D=load("res://scripts/entities/arrow.gd").new()
  a.world=p.world;a.direction=c.direction.rotated(angle);a.damage=1;a.speed=300;a.max_range=240
  a.position=p.position+p.ARROW_HEIGHT;p.world.entities.add_child(a);a.launch(p.ARROW_START)
 Sound.play("cw_fan",-6);return true
static func draw(c: RefCounted,p: Node2D) -> bool:
 if c.profile.get("mode","")!="cw_anchor" or c.phase=="strike":return false
 var color:=Color("f2d18a") if c.phase=="counter" else Color("a3d9dc")
 p.draw_arc(Vector2.ZERO,23,c.direction.angle()-1.1,c.direction.angle()+1.1,22,color,4)
 p.draw_line(c.direction*8,c.direction*(40 if c.phase=="counter" else 18),color,2)
 if c.phase=="guard":p.draw_arc(Vector2(0,-28),6,0,TAU*clampf(1-c.elapsed/0.32,0,1),14,color,2)
 return true
