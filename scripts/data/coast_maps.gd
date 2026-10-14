extends RefCounted
## Append only: old chests, fish spots, residents and saved object indices stay put.
static func enrich(id: String, data: Dictionary) -> void:
	if id!="lake":return
	for y in [8,9]:
		var row: String=data.rows[y]
		var first:=39 if y==8 else 40
		data.rows[y]=row.substr(0,first)+",".repeat(44-first)
	data.spawns["from_coast"]=[40,8]
	data.objects.append({"type":"portal","pos":[42,8],"size":[2,2],"to":"coast","spawn":"from_lake"})
	data.objects.append({"type":"sign","pos":[40,7],"lines":["Oostelijk pad: Blauwe Kust","Volg de riviermonding naar het strand. De veerboot brengt je gratis naar Meeuweneiland en terug."]})
