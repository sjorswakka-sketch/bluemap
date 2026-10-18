extends RefCounted
const ITEMS:={"trail_flower":{"name":"Bermbloemen","type":"material","sheet":"trail_items","icon":1,"sell":2,"desc":"Een klein bosje geplukte wilde bloemen uit een natuurlijke berm."},"trail_nut":{"name":"Bosnoten","type":"use","heal":1,"sheet":"trail_items","icon":0,"sell":2,"desc":"Eetbare noten van de padberm. Herstellen één hartje."}}
const ENEMIES:={
 "trail_hare":{"name":"Veldhaas","hp":2,"damage":0,"behavior":"animal","speed":32.0,"chase_speed":80.0,"sight":100.0,"panic_range":70.0,"sheet":"trail_hare","cell":16,"scale":2.0,"radius":5.0,"shadow":7.0,"drops":[["jacht_vlees",.7,1]],"desc":"Een rustige veldhaas die in de berm scharrelt en voor reizigers opzij springt."},
 "trail_fox":{"name":"Bosvos","hp":3,"damage":0,"behavior":"animal","speed":28.0,"chase_speed":76.0,"sight":100.0,"panic_range":72.0,"sheet":"trail_fox","cell":16,"scale":2.0,"radius":6.0,"shadow":8.0,"drops":[["jacht_vacht",.6,1]],"desc":"Een kleine bosvos die dicht bij zijn eigen schuilplek blijft."},
 "trail_moth":{"name":"Nachtvlinder","hp":1,"damage":0,"behavior":"animal","speed":22.0,"chase_speed":48.0,"sight":80.0,"panic_range":45.0,"sheet":"trail_moth","cell":16,"scale":1.5,"radius":3.0,"shadow":4.0,"drops":[],"desc":"Een stille vlinder bij ruïnes, grotingangen en wilde kruiden."},
 "trail_gull":{"name":"Strandloper","hp":2,"damage":0,"behavior":"animal","speed":26.0,"chase_speed":70.0,"sight":100.0,"panic_range":65.0,"sheet":"trail_gull","cell":16,"scale":2.0,"radius":4.0,"shadow":6.0,"drops":[],"desc":"Een kleine kustvogel die voedsel zoekt op droge oevers."}
}
