extends RefCounted
const Adventure:=preload("res://scripts/core/coastal_adventures.gd")
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
const RANGE:=118.0
const PULSE:=148.0
const GAP:=0.52
static func change(e: Node,state: String):
 e.state=state;e.state_time=0.0;e.ad_hit=false
static func allowed(e: Node,pos: Vector2) -> bool:
 return Adventure.room(e.kind).grow(-20).has_point(pos) and not Adventure.protected(pos)
static func target_valid(e: Node) -> bool:
 return allowed(e,e.player.position) and e.position.distance_to(e.player.position)<float(e.data.sight) and e._clear_line(e.position,e.player.position)
static func slot_free(e: Node) -> bool:
 for other in e.get_tree().get_nodes_in_group("enemies"):
  if other==e or other.is_queued_for_deletion() or other.dead:continue
  if other.position.distance_to(e.position)<280 and str(other.state).begins_with("ad_") and other.state not in ["ad_rest","ad_idle"]:return false
 return true
static func cone_hit(origin: Vector2,point: Vector2,aim: Vector2) -> bool:
 var d:=point-origin
 return d.length()<=RANGE and (d.length()<8 or absf(aim.angle_to(d))<=0.58)
static func ring_hit(origin: Vector2,point: Vector2,aim: Vector2,previous: float,current: float) -> bool:
 var d:=point-origin
 return d.length()<=current+8 and d.length()>=maxf(0,previous-8) and absf(aim.angle_to(d))>GAP
static func damage(e: Node):
 if e.ad_hit or not target_valid(e):return
 e.player.hurt(e.position,int(e.data.damage),e.data.name);e.ad_hit=true
static func update(e: Node,delta: float):
 var valid:=target_valid(e)
 if not valid:
  if e.state!="ad_idle":change(e,"ad_idle")
  e.knockback=Vector2.ZERO
  var home: Vector2=e.home_position-e.position
  if home.length()>3 and allowed(e,e.position+home.normalized()*30*delta):e.desired=home.normalized()*30
  return
 if e.state in ["idle","ad_idle"]:
  if e.state_time<1.2 or not slot_free(e):return
  var distance: float=e.position.distance_to(e.player.position)
  if e.kind!="ad_wisp" and distance>100:
   var direction: Vector2=(e.player.position-e.position).normalized().rotated(0.25*sin(e.t))
   var next: Vector2=e.position+direction*float(e.data.speed)*delta
   if allowed(e,next) and e._body_clear(e.position,next):e.desired=direction*float(e.data.speed)
   return
  e.aim_dir=(e.player.position-e.position).normalized()
  e.ad_origin=e.position;e.ad_radius=0;e.ad_combo=0
  change(e,"ad_warn");Sound.play("ad_warn",-10,1.25 if e.kind=="ad_wisp" else 0.85);return
 if e.state=="ad_warn" or e.state=="ad_warn2":
  if e.state_time<0.95:return
  change(e,"ad_pulse" if e.kind=="ad_wisp" else "ad_swing")
  Sound.play("ad_pulse" if e.kind=="ad_wisp" else "ad_swipe",-9);return
 if e.state=="ad_swing":
  if cone_hit(e.ad_origin,e.player.position,e.aim_dir):damage(e)
  if e.state_time>=0.18:
   if e.kind=="ad_keeper" and e.ad_combo==0:
    e.ad_combo=1;e.aim_dir=e.aim_dir.rotated(PI/2);change(e,"ad_warn2");Sound.play("ad_warn",-10)
   else:change(e,"ad_rest")
 elif e.state=="ad_pulse":
  var previous: float=e.ad_radius;e.ad_radius=minf(PULSE,e.state_time/0.7*PULSE)
  if ring_hit(e.ad_origin,e.player.position,e.aim_dir,previous,e.ad_radius):damage(e)
  if e.state_time>=0.7:change(e,"ad_rest")
 elif e.state=="ad_rest" and e.state_time>=1.6:change(e,"ad_idle")
 # Explicit room clamp applies to knockback as well as movement.
 if not allowed(e,e.position+e.knockback*delta):e.knockback=Vector2.ZERO
static func after_move(e: Node,before: Vector2):
 if not allowed(e,e.position):e.position=before;e.knockback=Vector2.ZERO;e.velocity=Vector2.ZERO
static func draw(e: Node,texture: Texture2D,tint: Color):
 DrawUtil.ellipse(e,Vector2(0,12),Vector2(float(e.data.shadow),5),Color(0,0,0,0.25))
 var frame:=0
 if e.state in ["ad_warn","ad_warn2"]:frame=2
 elif e.state in ["ad_swing","ad_pulse"]:frame=3
 elif e.desired.length()>1:frame=int(e.anim*2)%2
 var bob: float=sin(e.t*2)*3 if e.kind=="ad_wisp" else 0.0
 DrawUtil.sprite(e,texture,frame,0,Vector2(0,bob),Vector2i(24,24),float(e.data.scale),tint)
 if e.state=="ad_rest":
  e.draw_arc(Vector2(0,-28),9,0,TAU*minf(1,e.state_time/1.6),16,Color("9cdbb5"),2)
