extends SceneTree
const Maps:=preload("res://scripts/maps/registry.gd")
const Quests:=preload("res://scripts/data/quests.gd")
func _initialize():run.call_deferred()
func run():
	var FastTravel:=load("res://scripts/core/fast_travel.gd")
	for id: String in Quests.QUESTS:
		var q: Dictionary=Quests.QUESTS[id]
		print("QUEST ",id," | ",q.title)
		for s in q.steps:print("  ",s.text)
	for a in FastTravel.all_altars():print("ALTAR ",a.map," ",a.tile," -> ",a.pos/32)
	for id: String in Maps.MAPS:
		var m:=Maps.get_map(id)
		var foes: Array=m.objects.filter(func(o):return o.type=="enemy")
		print("MAP ",id," ",Vector2i(m.rows[0].length(),m.rows.size())," | ",foes.map(func(o):return str(o.kind)+str(o.pos)))
	quit()
