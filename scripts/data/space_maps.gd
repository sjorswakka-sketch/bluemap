extends RefCounted
## Calm routes without renumbering saved chests/pickups or moving old save coordinates.
const THIN_FOREST := [[10,8],[17,16],[20,20],[14,23],[36,18],[33,12],[39,4],[41,3]]
static func enrich(id: String, data: Dictionary) -> void:
	for obj: Dictionary in data.objects:
		if id=="village" and obj.type=="portal" and obj.to=="forest":
			obj.to="forest_edge";obj.spawn="from_village"
		elif id=="village" and obj.type=="npc" and obj.id=="elke":
			obj.pos=[22,17] # step out of the narrow southward road below the fountain
		elif id=="village" and obj.type=="sign" and obj.pos==[37,12]:
			obj.lines[0]="Oostelijke weg: Bosrand en Fluisterbos."
		elif id=="forest":
			if obj.type=="portal" and obj.to=="village":
				obj.to="forest_edge";obj.spawn="from_forest"
			elif obj.type=="sign" and obj.pos==[3,16]:obj["enabled"]=false
			elif obj.type=="sign" and obj.pos==[5,19]:obj.lines[0]="Westelijk pad: Bosrand en Dageraadsdorp."
			elif obj.type=="enemy":
				if obj.pos in THIN_FOREST: obj["enabled"]=false
				obj["patrol_radius"]=160.0
		elif id=="lake" and obj.type=="enemy":obj["patrol_radius"]=160.0
