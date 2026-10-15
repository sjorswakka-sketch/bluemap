extends Node2D
const DrawUtil:=preload("res://scripts/core/draw_util.gd")
var world: Node2D
var kind:="cw_target"
var data:={"behavior":"cw_dummy","boss":false,"name":"Oefenpop"}
var radius:=11.0
var hp:=9999
var max_hp:=9999
var dead:=false
var active:=true
var air_height:=0.0
var state:=""
var flash:=0.0
var count:=0
var timer:=0.0
var waiting:=false
func _ready():add_to_group("enemies");add_to_group("interactable");add_to_group("coastal_targets")
func label() -> String:return tr("Oefenpop · tik voor wachtproef")
func hurt(amount: int,_direction: Vector2):
 count+=1;flash=.2
 world.damage_number(position+Vector2(0,-28),str(amount),Color("e9d499"));Sound.play("cw_stow",-15)
func break_guard():pass
func interact():
 if GameState.input_locked() or waiting or position.distance_to(world.player.position)>40:return
 waiting=true;timer=.9;queue_redraw()
func _process(delta: float):
 flash=maxf(0,flash-delta)
 if waiting and not GameState.input_locked():
  timer-=delta
  if timer<=0:
   waiting=false
   if world.player.position.distance_to(position)<90:
    if not world.player.combat.try_block(world.player,position):GameState.toast.emit(tr("Geen blokkade. De oefenpop doet geen schade; probeer de korte frontale wacht nog eens."))
 queue_redraw()
func _draw():
 DrawUtil.ellipse(self,Vector2(0,12),Vector2(12,4),Color(0,0,0,.2))
 draw_line(Vector2(0,10),Vector2(0,-17),Color("816b51"),5)
 draw_circle(Vector2(0,-12),12,Color("e4d5a3") if flash>0 else Color("91b0a0"));draw_circle(Vector2(0,-12),5,Color("cbd5b2"))
 if count>0:DrawUtil.name_tag(self,Vector2(0,-30),str(count))
 if waiting:draw_arc(Vector2.ZERO,44,0,TAU*clampf(timer/.9,0,1),24,Color("ecd091"),2)
 if world.player.target==self:DrawUtil.prompt(self,Vector2(0,-45),timer)
