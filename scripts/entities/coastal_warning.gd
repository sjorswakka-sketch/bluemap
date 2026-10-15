extends Node2D
const AI:=preload("res://scripts/entities/coastal_enemy.gd")
var enemy: WeakRef
func _process(_delta: float):
 var e: Node2D=enemy.get_ref() if enemy!=null else null
 if not is_instance_valid(e) or e.is_queued_for_deletion():queue_free();return
 global_position=e.ad_origin;queue_redraw()
func _draw():
 var e: Node2D=enemy.get_ref() if enemy!=null else null
 if not is_instance_valid(e) or e.is_queued_for_deletion() or e.dead:return
 if e.state not in ["ad_warn","ad_warn2","ad_swing","ad_pulse"]:return
 var angle: float=e.aim_dir.angle()
 var warning: bool=e.state in ["ad_warn","ad_warn2"]
 var color:=Color(0.98,0.72,0.25,0.25 if warning else 0.55)
 if e.kind=="ad_wisp":
  var radius: float=AI.PULSE if warning else e.ad_radius
  var bounds: Rect2=AI.Adventure.room(e.kind).grow(-6)
  for i in 60:
   var a:=Vector2.from_angle(angle+AI.GAP+i*(TAU-2*AI.GAP)/60)*radius
   var b:=Vector2.from_angle(angle+AI.GAP+(i+1)*(TAU-2*AI.GAP)/60)*radius
   if bounds.has_point(a+global_position) and bounds.has_point(b+global_position):draw_line(a,b,color,3 if warning else 9)
  for side in [-1,1]:
   var end: Vector2=(global_position+Vector2.from_angle(angle+side*AI.GAP)*AI.PULSE).clamp(bounds.position,bounds.end)-global_position
   draw_line(Vector2.ZERO,end,Color("8ce0cb"),2)
 else:
  var polygon:=PackedVector2Array([Vector2.ZERO])
  for i in 25:polygon.append(Vector2.from_angle(angle-0.58+i*1.16/24)*AI.RANGE)
  var bounds: Rect2=AI.Adventure.room(e.kind).grow(-6)
  var local:=PackedVector2Array([bounds.position-global_position,Vector2(bounds.end.x,bounds.position.y)-global_position,bounds.end-global_position,Vector2(bounds.position.x,bounds.end.y)-global_position])
  for clipped in Geometry2D.intersect_polygons(polygon,local):
   draw_colored_polygon(clipped,color);draw_polyline(clipped,Color("f9d58a"),2)
