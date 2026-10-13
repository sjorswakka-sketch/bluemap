extends RefCounted
const OBJECTS := {"combat_post":"res://scripts/entities/combat_post.gd"}
const MAPS := {"watchyard":preload("res://scripts/maps/watchyard.gd")}
const SOUNDS := ["cv_ready","cv_strike","cv_thorn"]
const ENEMIES := {
	"cv_ram":{"name":"Keiram","hp":6,"damage":1,"behavior":"cv_ram","speed":42.0,"sight":230.0,"sheet":"cv_ram","cell":24,"scale":2.0,"radius":10.0,"shadow":12.0,"drops":[["coin",1.0,3],["prof_stone",0.4,1]],"desc":"Een oranje baan verraadt zijn stormloop. De richting ligt vast: stap opzij of lok hem tegen een rots. Na de botsing is hij kwetsbaar. Hard geluid trekt eerder zijn aandacht."},
	"cv_slinger":{"name":"Doornschutter","hp":4,"damage":1,"behavior":"cv_slinger","speed":34.0,"sight":230.0,"sheet":"cv_slinger","cell":24,"scale":2.0,"radius":8.0,"shadow":11.0,"drops":[["coin",1.0,2],["gel",0.25,1]],"desc":"Houdt afstand en richt langs een oranje baan. Dekking stopt zijn doorn; je zwaard kan die ook stukslaan. Een treffer onderbreekt de voorbereiding."}
}
