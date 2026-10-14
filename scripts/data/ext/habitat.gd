extends RefCounted
## Environment-specific replacements, no additional spawns or activities.
const SOUNDS := ["hb_root_ready","hb_root_strike","hb_moth_ready"]
const ENEMIES := {
 "hb_root":{"name":"Wortelwaker","hp":4,"damage":1,"behavior":"hb_root","speed":0.0,"sight":104.0,"sheet":"hb_root","cell":24,"scale":2.0,"radius":8.0,"shadow":11.0,"knockback":0.0,"drops":[["coin",1.0,1],["prof_branch",0.4,1]],"desc":"Blijft bij zijn wortels. De amberkleurige grondstrook ligt vast voordat de wortels toeslaan. Stap of rol opzij en sla tijdens het lange herstel. Zijn gesloten bast houdt gewone slagen en pijlen tegen; een techniek opent hem eerder."},
 "hb_moth":{"name":"Schemermot","hp":2,"damage":1,"behavior":"hb_moth","speed":38.0,"sight":112.0,"sheet":"hb_moth","cell":24,"scale":2.0,"radius":6.0,"shadow":8.0,"knockback":120.0,"fly":true,"drops":[["coin",0.8,1],["heart",0.12,1]],"desc":"Volgt dichtbij zichtbaar licht binnen zijn eigen hoek van de grot. Lok hem naar een bestaande fakkel: daar houdt hij rustig de wacht. Zonder afleiding kondigt hij een korte rechte duik aan. Een treffer onderbreekt die; muren, rustplaatsen en aankomsten blijven buiten zijn bereik."}
}
