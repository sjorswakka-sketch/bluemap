extends RefCounted
## Append only: old chests, fish spots, residents and saved object indices stay put.
static func enrich(id: String, data: Dictionary) -> void:
	if id=="coast":
		data.objects.append({"type":"tide_station","pos":[40,21],"role":"routes","to":"gull_island","spawn":"from_coast","routes":[{"to":"gull_island","spawn":"from_coast"},{"to":"tide_cove","spawn":"from_coast"}]})
	if id=="gull_island":
		for y in [22,23]:
			var row: String=data.rows[y]
			data.rows[y]=row.substr(0,38)+"9".repeat(10)
		var row: String=data.rows[21]
		data.rows[21]=row.substr(0,42)+"99"+row.substr(44)
		data.spawns["from_cove"]=[43,23]
		data.objects.append({"type":"portal","pos":[46,22],"size":[2,2],"to":"tide_cove","spawn":"from_island"})
		data.objects.append({"type":"sign","pos":[43,21],"lines":["Oostelijke loopbrug: Getijdenbaai","Een hoge loopbrug, een zandbank bij laagwater en een gratis te lenen landingslijn. De veer blijft beschikbaar."]})
		data.objects.append({"type":"tide_station","pos":[10,21],"role":"routes","to":"coast","spawn":"from_island","routes":[{"to":"coast","spawn":"from_island"},{"to":"tide_cove","spawn":"from_coast"}]})
	if id!="lake":return
	for y in [8,9]:
		var row: String=data.rows[y]
		var first:=39 if y==8 else 40
		data.rows[y]=row.substr(0,first)+",".repeat(44-first)
	data.spawns["from_coast"]=[40,8]
	data.objects.append({"type":"portal","pos":[42,8],"size":[2,2],"to":"coast","spawn":"from_lake"})
	data.objects.append({"type":"sign","pos":[40,7],"lines":["Oostelijk pad: Blauwe Kust","Volg de riviermonding naar het strand. De veerboot brengt je gratis naar Meeuweneiland en terug."]})
