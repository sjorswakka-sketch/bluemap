extends RefCounted
## The existing three coastal maps keep every saved object slot.
static func enrich(id: String,data: Dictionary):
	if id=="coast":
		for y in range(0,18):
			var row: String=data.rows[y]
			data.rows[y]=row.substr(0,14)+("99" if y<2 else ",,")+row.substr(16)
		data.spawns["from_estuary"]=[14,3]
		data.objects.append({"type":"portal","pos":[14,0],"size":[2,2],"to":"river_mouth","spawn":"from_coast"})
		data.objects.append({"type":"sign","pos":[12,3],"lines":["Noordelijk oeverpad: Zilvermonding","Volg de hoge rivierbrug naar Rietwenk Haven. Naar het westen blijft het Zilvermeer bereikbaar."]})
	if id in ["coast","gull_island","tide_cove"]:
		for obj: Dictionary in data.objects:
			if obj.type=="tide_station" and obj.get("role","")=="routes":
				obj.routes.append({"to":"harbor","spawn":"from_coast"})
