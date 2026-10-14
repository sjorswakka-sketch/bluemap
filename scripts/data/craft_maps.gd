extends RefCounted
static func enrich(id: String, data: Dictionary) -> void:
	var placement := {"smithy":["smith",10,7],"library":["focus",5,9],"lake":["pack",15,7]}
	if placement.has(id):
		var entry: Array = placement[id]
		data.objects.append({"type":"craft_notes","kind":entry[0],"pos":[entry[1],entry[2]]})
