extends "res://scripts/entities/player.gd"
var fixture_clear:=true
var fixture_lent:=false
func _ready():disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE;add_to_group("player");camera=Camera2D.new();add_child(camera);set_physics_process(false)
func _update_aim():pass
func _update_target():pass
func _update_shake(_delta:float):pass
func ground_tile()->String:return ""
func _attack_clear(_at:Vector2)->bool:return fixture_clear
func _lent_arrow()->bool:return fixture_lent
