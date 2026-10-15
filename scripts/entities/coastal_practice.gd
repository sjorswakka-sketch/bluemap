extends Node2D
## Loans only exist as a local capability; no inventory, quest or save mutations.
var world: Node2D
var targets: Array[Node2D]=[]
var active:=false
func _ready():add_to_group("coastal_practice");add_to_group("boog_range")
func start():
 if active:return
 active=true
 for offset in [Vector2(-50,8),Vector2.ZERO,Vector2(50,8)]:
  var n: Node2D=load("res://scripts/entities/coastal_target.gd").new();n.world=world;n.position=Vector2(22.5,9.5)*32+offset;world.entities.add_child(n);targets.append(n)
 GameState.toast.emit(tr("Vrije proef: geen schade, buit of XP. Pijlen zijn hier geleend; stamina blijft echt. Gebruik het rustaltaar als je wilt bijvullen."))
func lends_arrows() -> bool:
 return active and not is_queued_for_deletion() and GameState.map_id=="coast_workshop" and world.player.position.distance_to(Vector2(22.5,12.5)*32)<210
func _exit_tree():
 for target in targets:
  if is_instance_valid(target):target.queue_free()
