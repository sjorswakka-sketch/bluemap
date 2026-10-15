extends RefCounted
static func gs() -> Node:return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
static func prepare(data: Dictionary):
 if not gs().flag("ad_wheel_done"):return
 for y in [14,15]:
  var row: String=data.rows[y];data.rows[y]=row.substr(0,28)+"9999"+row.substr(32)
static func evidence() -> bool:return gs().flag("ad_splinter") and gs().flag("ad_silt")
static func sync():
 if gs().quest_state("ad_message")=="active" and evidence() and gs().quest_step("ad_message")<1:gs().set_quest_step("ad_message",1)
static func finish(id: String):
 if not gs().quests.has(id):gs().start_quest(id)
 gs().finish_quest(id);gs().set_flag(id+"_done")
 gs().save_requested.emit()
static func resolve(peace: bool):
 if gs().flag("ad_keeper_done"):return
 gs().set_flag("ad_pool" if peace else "ad_workwater")
 gs().flags.erase("ad_duel")
 finish("ad_keeper")
static func protected(pos: Vector2) -> bool:
 return pos.y>=24*32 or pos.x<7*32
static func room(kind: String) -> Rect2:
 return Rect2(38*32,5*32,18*32,18*32) if kind=="ad_keeper" else Rect2(8*32,5*32,16*32,18*32)
