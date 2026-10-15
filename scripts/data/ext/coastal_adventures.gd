extends RefCounted
const MAPS:={"tidal_hollow":preload("res://scripts/maps/tidal_hollow.gd")}
const OBJECTS:={"coast_adventure":"res://scripts/entities/coastal_adventure.gd"}
const MAP_MARKERS:={"coast_adventure":{"color":Color("edd28f"),"label":"Kustverhaal of waarneming"}}
const SOUNDS:=["ad_work","ad_warn","ad_swipe","ad_pulse","ad_water"]
const QUESTS:={
 "ad_message":{"title":"Een bericht zonder afzender","steps":[{"text":"Lees het aangespoelde logboek op Meeuweneiland. Bekijk de breuksporen aan het eilandstrand en de afzetting bij Zilvermonding."},{"text":"Leg bij het werkboek op de havenkade uit waar het wrakhout vandaan kwam."}],"effect":"De haven markeert de gevaarlijke buitenbank met een waarschuwingsboei."},
 "ad_pilot":{"title":"De oude loodsenroute","steps":[{"text":"Zoek vanaf de loodsenpaal op Lichtkaap de lage, gespleten rots in het noordwestelijke grasland."},{"text":"Volg de beschrijving bij de rots naar de bleke zoutgraspol, oostelijk op de kaap."},{"text":"Lees bij het zoutgras waar de loodsen hun beschutte rustplek maakten."}],"effect":"Bij de bank staat weer een laag windscherm. De kaap blijft vrij en rustig."},
 "ad_wheel":{"title":"Water dat weer loopt","steps":[{"text":"Onderzoek het vastgelopen tijrad in de Tijholte, aan het einde van de westelijke zijroute van Zilvermonding."},{"text":"Maak het rad vrij met het gereedschap ter plaatse. Annuleren kost niets."}],"effect":"Het tijrad draait en de korte brug is droog. De lange zuidelijke route blijft altijd open."},
 "ad_keeper":{"title":"De Schelpenhoeder","steps":[{"text":"Kies bij de sluistafel in de Tijholte: geef de poel rust, of open de werksluis en benader de hoeder voor een vrijwillige krachtproef."}],"effect":"Je keuze verandert de poel of het havenrad. Beide uitkomsten sluiten het verhaal af."}
}
const ENEMIES:={
 "ad_crab":{"name":"Rotskrab","hp":6,"damage":1,"behavior":"ad_crab","speed":30.0,"sight":210.0,"sheet":"ad_crab","cell":24,"scale":2.0,"radius":9.0,"shadow":14.0,"knockback":90.0,"drops":[["coin",1.0,2]],"desc":"Bewoont de noordelijke zijpoel. De amberkleurige waaier staat stil vóór de schaar sluit. Stap opzij en val tijdens het lange herstel aan. Het zuidelijke pad blijft buiten zijn territorium."},
 "ad_wisp":{"name":"Getijdenlicht","hp":4,"damage":1,"behavior":"ad_wisp","speed":22.0,"sight":220.0,"sheet":"ad_wisp","cell":24,"scale":2.0,"radius":7.0,"shadow":10.0,"knockback":60.0,"drops":[["coin",1.0,2]],"desc":"Kondigt een uitdijende lichtkring aan. De open sector blijft veilig; hij draait niet achter je aan. Verlaat de poel of loop door de opening. Geen contactschade."},
 "ad_keeper":{"name":"Schelpenhoeder","hp":16,"damage":2,"behavior":"ad_keeper","speed":24.0,"sight":250.0,"sheet":"ad_keeper","cell":24,"scale":2.8,"radius":13.0,"shadow":19.0,"knockback":30.0,"boss":true,"drops":[],"desc":"Een vrijwillige krachtproef na de werksluiskeuze. Twee afzonderlijk aangekondigde schaarbogen, daarna een lang herstel. De zuidelijke gang blijft open; terugtrekken stopt de aanval."}
}
