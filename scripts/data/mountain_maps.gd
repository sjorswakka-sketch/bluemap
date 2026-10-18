extends RefCounted
## Append-only link: every pre-existing IJsdal object index remains stable.
static func enrich(id: String,data: Dictionary):
 if id!="ijsdal":return
 for y in range(16):
  var row: String=data.rows[y];row[24]=",";row[25]=",";data.rows[y]=row
 data.spawns["from_steampeak"]=[24,4]
 data.objects.append({"type":"portal","pos":[24,0],"size":[2,2],"to":"steampeak","spawn":"from_ijsdal"})
 data.objects.append({"type":"sign","pos":[22,3],"lines":["Noordelijk bergpad: Dampkroon","Volg de brede trappen naar de warme bergbronnen. Aan de oevers kun je rustig hartjes herstellen; geisers zijn alleen om naar te kijken."]})
