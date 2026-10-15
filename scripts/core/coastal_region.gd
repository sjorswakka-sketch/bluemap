extends RefCounted
const IDS: Array[String]=["coast","river_mouth","harbor","headland","gull_island","tide_cove"]
static var pending: WeakRef
static func gs() -> Node:return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
static func open(resident: Node2D,talk: String):
	pending=weakref(resident);gs().start_dialogue(talk)
static func choose(action: String):
	var source: Node2D=pending.get_ref() if pending!=null else null
	if not is_instance_valid(source) or source.is_queued_for_deletion():return
	source.open_service.call_deferred(action)
static func hint(id: String) -> String:
	match id:
		"coast":return TranslationServer.translate("Strand en duinen. West: Zilvermeer. Noord: Zilvermonding. De veer verbindt de eilanden en de haven.")
		"river_mouth":return TranslationServer.translate("Brede oevers en één hoge rivierbrug. Zuid: Blauwe Kust. Oost: Rietwenk Haven. Geen gereedschap nodig.")
		"harbor":return TranslationServer.translate("Een kleine werkkade met Ise en Raf. West: riviermonding. Oost: Lichtkaap. Gratis veer naar kust en eilanden.")
		"headland":return TranslationServer.translate("Hoge graslanden, een vuurtoren en een rustig zeezicht. Het brede westelijke pad brengt je terug naar de haven.")
		"gull_island":return TranslationServer.translate("Grasrug, strand en uitzichtpunt. De oostelijke loopbrug voert naar de Getijdenbaai; de veer brengt je terug.")
	return TranslationServer.translate("Getijdenbaai: zandbank bij laagwater, hoge loopbrug altijd open. Gratis leenlijn en veer bij de westelijke steiger.")
static func walk_path(from: String,to: String) -> Array[String]:
	var maps: Script=load("res://scripts/maps/registry.gd")
	var queue: Array[String]=[from]
	var previous: Dictionary={from:""}
	var result: Array[String]=[]
	while not queue.is_empty():
		var here: String=queue.pop_front()
		if here==to:
			while here!="":result.push_front(here);here=previous[here]
			return result
		for obj: Dictionary in maps.get_map(here).objects:
			if obj.type!="portal" or obj.to not in IDS or previous.has(obj.to):continue
			previous[obj.to]=here;queue.append(obj.to)
	return result
