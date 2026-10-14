extends RefCounted
const DrawUtil := preload("res://scripts/core/draw_util.gd")
const CombatAI := preload("res://scripts/entities/combat_enemy.gd")
const TERRITORY := 144.0
const SAFE_RADIUS := 80.0
const ROOT_START := 18.0
const ROOT_REACH := 100.0
const ROOT_HALF := 12.0
const ROOT_WARN := 1.1
const ROOT_HIT := 0.18
const ROOT_REST := 1.8
const MOTH_REACH := 70.0
const MOTH_HALF := 12.0
const MOTH_WARN := 0.85

static func enter(foe: Node2D, state: String) -> void:
 foe.state=state;foe.state_time=0;foe.habitat_hit=false

static func protected(foe: Node2D, at: Vector2) -> bool:
 # Existing savepoints and both ends of every arrival stay quiet.
 for coords: Array in foe.world.map_data.spawns.values():
  if at.distance_to(Vector2(coords[0]+0.5,coords[1]+0.5)*32)<SAFE_RADIUS:return true
 for obj: Dictionary in foe.world.map_data.objects:
  if obj.type in ["savepoint","portal"] and obj.get("enabled",true):
   var center:=Vector2(obj.pos[0]+0.5,obj.pos[1]+0.5)*32
   if obj.type=="portal":center+=Vector2(obj.get("size",[1,1])[0]-1,obj.get("size",[1,1])[1]-1)*16
   if at.distance_to(center)<SAFE_RADIUS:return true
 return false

static func within_home(foe: Node2D, at: Vector2) -> bool:
 return at.distance_to(foe.home_position+Vector2(0,8))<=TERRITORY

static func clipped_length(foe: Node2D, requested: float, half_width: float) -> float:
 var origin: Vector2=foe.habitat_origin
 var side: Vector2=foe.aim_dir.orthogonal()*half_width
 var length:=0.0
 for step in range(4,int(requested)+1,4):
  var at: Vector2=origin+foe.aim_dir*step
  if not within_home(foe,at) or protected(foe,at):break
  var clear:=true
  for offset: Vector2 in [-side,Vector2.ZERO,side]:
   if protected(foe,at+offset) or not within_home(foe,at+offset) or not foe._clear_line(origin+offset,at+offset):clear=false;break
  if not clear:break
  length=step
 return length

static func in_strip(foe: Node2D, at: Vector2, first: float, last: float, half: float) -> bool:
 var offset: Vector2=at-foe.habitat_origin
 return offset.dot(foe.aim_dir)>=first and offset.dot(foe.aim_dir)<=last and absf(offset.dot(foe.aim_dir.orthogonal()))<=half

static func blocks(foe: Node2D) -> bool:
 return foe.data.behavior=="hb_root" and foe.state in ["idle","hb_root_warn"] and foe.guard_broken<=0

static func interrupt(foe: Node2D, technique:=false) -> void:
 if foe.data.behavior=="hb_root":
  if technique:
   foe.guard_broken=ROOT_REST
   enter(foe,"hb_rest")
 elif foe.data.behavior=="hb_moth":enter(foe,"hb_rest")

static func valid_target(foe: Node2D) -> bool:
 var feet: Vector2=foe.player.global_position+Vector2(0,8)
 return within_home(foe,feet) and not protected(foe,feet) and foe._clear_line(foe.global_position,foe.player.global_position)

static func cue(foe: Node2D, name: String) -> void:
 if foe.global_position.distance_to(foe.player.global_position)<220:
  foe.get_tree().root.get_node("Sound").play(name,-16.0)

static func update(foe: Node2D, delta: float) -> void:
 if foe.data.behavior=="hb_root":root_update(foe)
 else:moth_update(foe,delta)

static func root_update(foe: Node2D) -> void:
 if foe.state=="hb_rest":
  if foe.state_time>=ROOT_REST:enter(foe,"idle")
  return
 if foe.state=="hb_root_warn":
  foe.habitat_length=minf(foe.habitat_length,clipped_length(foe,ROOT_REACH,ROOT_HALF))
  if foe.habitat_length<ROOT_START:enter(foe,"hb_rest");return
  if foe.state_time>=ROOT_WARN:
   enter(foe,"hb_root_hit");cue(foe,"hb_root_strike")
  return
 if foe.state=="hb_root_hit":
  var feet: Vector2=foe.player.global_position+Vector2(0,8)
  if not foe.habitat_hit and valid_target(foe) and in_strip(foe,feet,ROOT_START,foe.habitat_length,ROOT_HALF):
   foe.habitat_hit=true;foe.player.hurt(foe.habitat_origin,1,foe.data.name)
  if foe.state_time>=ROOT_HIT:enter(foe,"hb_rest")
  return
 if foe.state_time<1.6 or not valid_target(foe):return
 var offset: Vector2=foe.player.global_position-foe.global_position
 if offset.length()>ROOT_REACH:return
 if not CombatAI.slot_free(foe):return
 foe.aim_dir=offset.normalized() if offset.length()>0.1 else Vector2.DOWN
 foe.habitat_origin=foe.global_position+Vector2(0,8)
 foe.habitat_length=clipped_length(foe,ROOT_REACH,ROOT_HALF)
 if foe.habitat_length<ROOT_START:return
 enter(foe,"hb_root_warn");cue(foe,"hb_root_ready")

static func light_target(foe: Node2D) -> Dictionary:
 var best: Dictionary={}
 var best_distance:=INF
 # Fixed flames win when nearby. The player's lamp is never disabled or consumed.
 for torch: Node2D in foe.get_tree().get_nodes_in_group("world_lights"):
  if torch.is_queued_for_deletion() or torch.get_parent()!=foe.world.entities or not is_instance_valid(torch.light) or not torch.light.enabled:continue
  var at: Vector2=torch.global_position
  var distance:=foe.global_position.distance_to(at)
  if distance>144 or not within_home(foe,at) or protected(foe,at) or not foe._clear_line(foe.global_position,at):continue
  var score:=distance-56.0
  if score<best_distance:best_distance=score;best={"position":at,"fixed":true}
 var p: Node2D=foe.player
 if p.light.enabled and p.light.energy>0.02 and valid_target(foe):
  var distance:=foe.global_position.distance_to(p.global_position)
  if distance<112 and distance<best_distance:best={"position":p.global_position,"fixed":false}
 return best

static func safe_move(foe: Node2D, direction: Vector2, speed: float, delta: float) -> void:
 var next: Vector2=foe.global_position+direction*maxf(speed*delta,8)
 if within_home(foe,next) and not protected(foe,next) and foe._body_clear(foe.global_position,next):
  foe.desired=direction*speed

static func moth_update(foe: Node2D, delta: float) -> void:
 if foe.state=="hb_rest":
  if foe.state_time>=1.6:enter(foe,"idle")
  return
 if foe.state=="hb_moth_warn":
  # A flame can interrupt a dive even after it has begun preparing.
  var light:=light_target(foe)
  if light.get("fixed",false) or not valid_target(foe):enter(foe,"hb_rest");return
  foe.habitat_length=minf(foe.habitat_length,clipped_length(foe,MOTH_REACH,MOTH_HALF))
  if foe.state_time>=MOTH_WARN:enter(foe,"hb_moth_dash")
  return
 if foe.state=="hb_moth_dash":
  if not valid_target(foe) or foe.state_time>=0.46 or foe.habitat_traveled>=foe.habitat_length:enter(foe,"hb_rest");return
  var remaining: float=foe.habitat_length-foe.habitat_traveled
  safe_move(foe,foe.aim_dir,minf(155.0,remaining/maxf(delta,0.001)),delta)
  if foe.desired==Vector2.ZERO:enter(foe,"hb_rest")
  return
 var target:=light_target(foe)
 foe.habitat_distracted=target.get("fixed",false)
 if target.is_empty():
  var offset: Vector2=foe.home_position-foe.global_position
  if offset.length()>10:safe_move(foe,offset.normalized(),28,delta)
  foe.state_time=minf(foe.state_time,0.7)
  return
 var offset: Vector2=target.position-foe.global_position
 if foe.habitat_distracted:
  if offset.length()>30:safe_move(foe,offset.normalized(),38,delta)
  foe.state_time=minf(foe.state_time,0.7)
  return
 if offset.length()>52:safe_move(foe,offset.normalized(),38,delta)
 elif foe.state_time>1.4 and CombatAI.slot_free(foe):
  foe.aim_dir=offset.normalized() if offset.length()>0.1 else Vector2.DOWN
  foe.habitat_origin=foe.global_position+Vector2(0,8)
  foe.habitat_length=clipped_length(foe,MOTH_REACH,MOTH_HALF)
  foe.habitat_traveled=0
  if foe.habitat_length<20:return
  enter(foe,"hb_moth_warn");cue(foe,"hb_moth_ready")

static func after_move(foe: Node2D, before: Vector2) -> void:
 if foe.state!="hb_moth_dash":return
 var progress: float=(foe.global_position-before).dot(foe.aim_dir)
 var first: float=foe.habitat_traveled
 foe.habitat_traveled=minf(foe.habitat_length,foe.habitat_traveled+maxf(0,progress))
 var feet: Vector2=foe.player.global_position+Vector2(0,8)
 if not foe.habitat_hit and valid_target(foe) and in_strip(foe,feet,first,foe.habitat_traveled,MOTH_HALF):
  foe.habitat_hit=true;foe.player.hurt(foe.global_position,1,foe.data.name)

static func draw(foe: Node2D, sheet: Texture2D, tint: Color) -> void:
 DrawUtil.ellipse(foe,Vector2(0,12),Vector2(foe.data.shadow,3),Color(0,0,0,0.25))
 var frame:=int(foe.t*3)%2
 var lift:=0.0
 if foe.data.behavior=="hb_root":
  if foe.state=="hb_root_warn":frame=2
  elif foe.state=="hb_root_hit":frame=3
  elif foe.state=="hb_rest":frame=4
 else:
  lift=-6+sin(foe.t*6)*2
  if foe.state=="hb_moth_warn":frame=2
  elif foe.state=="hb_moth_dash":frame=3
  elif foe.habitat_distracted:frame=4+int(foe.t*3)%2
 DrawUtil.sprite(foe,sheet,frame,0,Vector2(0,lift),Vector2i(24,24),2,tint)
 if foe.state in ["hb_root_warn","hb_moth_warn"]:
  var duration:=ROOT_WARN if foe.data.behavior=="hb_root" else MOTH_WARN
  foe.draw_arc(Vector2(0,-28),6,-PI/2,-PI/2+TAU*minf(1,foe.state_time/duration),20,Color("f0ca7b"),1.5)
 elif foe.state=="hb_rest":
  foe.draw_arc(Vector2(0,-25),5,foe.t*2,foe.t*2+PI,12,Color("85bdae"),1)

static func draw_ground(canvas: Node2D, foe: Node2D) -> void:
 if foe.state not in ["hb_root_warn","hb_root_hit","hb_moth_warn","hb_moth_dash"]:return
 var root_attack: bool=foe.data.behavior=="hb_root"
 var first:=ROOT_START if root_attack else 0.0
 var half:=ROOT_HALF if root_attack else MOTH_HALF
 var a: Vector2=foe.habitat_origin+foe.aim_dir*first
 var b: Vector2=foe.habitat_origin+foe.aim_dir*foe.habitat_length
 var side: Vector2=foe.aim_dir.orthogonal()*half
 var points:=PackedVector2Array([a-side,b-side,b+side,a+side])
 var color:=Color("dcad68") if root_attack else Color("d6d29f")
 var active: bool=foe.state in ["hb_root_hit","hb_moth_dash"]
 canvas.draw_colored_polygon(points,Color(color,0.38 if active else 0.16))
 canvas.draw_polyline(PackedVector2Array([a-side,b-side,b+side,a+side,a-side]),Color(color,0.95),1.5)
 if root_attack:
  for distance in range(int(first)+4,int(foe.habitat_length),12):
   var center: Vector2=foe.habitat_origin+foe.aim_dir*distance
   canvas.draw_line(center-side*0.7,center+side*0.7,Color(color,0.5),1)
   if active:
    canvas.draw_line(center,center+Vector2(0,-7),Color("ad8754"),3)
    canvas.draw_line(center+Vector2(0,-7),center+Vector2(2,-9),Color("d4bb79"),2)
 else:canvas.draw_line(a,b,Color(color,0.55),1)
