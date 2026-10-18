extends RefCounted
## Specific regional wildflowers; no new map slots or garden crop definitions.
const ITEMS := {
 "flower_daisy": {
  "name": "Madeliefje",
  "wild_category": "flower",
  "species": "daisy",
  "type": "material",
  "sheet": "flower_items",
  "icon": 0,
  "sell": 2,
  "desc": "Een lage witte weidebloem met een goudgeel hart uit de rustige dorpsberm."
 },
 "flower_bluebell": {
  "name": "Boshyacint",
  "wild_category": "flower",
  "species": "bluebell",
  "type": "material",
  "sheet": "flower_items",
  "icon": 1,
  "sell": 3,
  "desc": "Blauwe klokjes die in kleine groepen onder de bomen van het Fluisterbos groeien."
 },
 "flower_foxglove": {
  "name": "Vingerhoedskruid",
  "wild_category": "flower",
  "species": "foxglove",
  "type": "material",
  "sheet": "flower_items",
  "icon": 2,
  "sell": 3,
  "desc": "Een hoge roze bloemenaar die beschutte bosranden opzoekt."
 },
 "flower_edelweiss": {
  "name": "Edelweiss",
  "wild_category": "flower",
  "species": "edelweiss",
  "type": "material",
  "sheet": "flower_items",
  "icon": 3,
  "sell": 5,
  "desc": "Een wollige sterbloem van de schrale, besneeuwde rotsbermen op Dampkroon."
 },
 "flower_sea_aster": {
  "name": "Zeeaster",
  "wild_category": "flower",
  "species": "sea_aster",
  "type": "material",
  "sheet": "flower_items",
  "icon": 4,
  "sell": 3,
  "desc": "Een lila bloem met een geel hart uit de brakke randen van de riviermonding."
 },
 "flower_hollyhock": {
  "name": "Stokroos",
  "wild_category": "flower",
  "species": "hollyhock",
  "type": "material",
  "sheet": "flower_items",
  "icon": 5,
  "sell": 3,
  "desc": "Een stevige rode bloemenstengel die warmte vindt bij de stenen muren van de haven."
 },
 "flower_thrift": {
  "name": "Engelsgras",
  "wild_category": "flower",
  "species": "thrift",
  "type": "material",
  "sheet": "flower_items",
  "icon": 6,
  "sell": 3,
  "desc": "Roze bloemkussens op korte stelen; gewend aan zoute wind op de kaap."
 },
 "flower_sea_lavender": {
  "name": "Lamsoor",
  "wild_category": "flower",
  "species": "sea_lavender",
  "type": "material",
  "sheet": "flower_items",
  "icon": 7,
  "sell": 4,
  "desc": "Een luchtige paarse bloempluim uit de zilte, hoge oever van de getijdenkom."
 },
 "flower_horned_poppy": {
  "name": "Gele hoornpapaver",
  "wild_category": "flower",
  "species": "horned_poppy",
  "type": "material",
  "sheet": "flower_items",
  "icon": 8,
  "sell": 3,
  "desc": "Een gele duinbloem met een lange zaaddoos tussen droog strandzand en schelpen."
 },
 "flower_sea_campion": {
  "name": "Zeesilene",
  "wild_category": "flower",
  "species": "sea_campion",
  "type": "material",
  "sheet": "flower_items",
  "icon": 9,
  "sell": 3,
  "desc": "Een witte kelkbloem met grijsgroen blad van de open eilandkust."
 },
 "flower_yellow_iris": {
  "name": "Gele lis",
  "wild_category": "flower",
  "species": "yellow_iris",
  "type": "material",
  "sheet": "flower_items",
  "icon": 10,
  "sell": 4,
  "desc": "Grote gele bloemen boven zwaardvormig blad aan de vochtige meeroever."
 },
 "flower_forget_me_not": {
  "name": "Vergeet-mij-nietje",
  "wild_category": "flower",
  "species": "forget_me_not",
  "type": "material",
  "sheet": "flower_items",
  "icon": 11,
  "sell": 3,
  "desc": "Kleine blauwe sterren uit de vochtige, mistige bermen van het Dauwbos."
 },
 "flower_snowdrop": {
  "name": "Sneeuwklokje",
  "wild_category": "flower",
  "species": "snowdrop",
  "type": "material",
  "sheet": "flower_items",
  "icon": 12,
  "sell": 4,
  "desc": "Een hangend wit klokje dat uit beschutte smeltsneeuw in IJsdal tevoorschijn komt."
 },
 "flower_desert_marigold": {
  "name": "Woestijngoudsbloem",
  "wild_category": "flower",
  "species": "desert_marigold",
  "type": "material",
  "sheet": "flower_items",
  "icon": 13,
  "sell": 3,
  "desc": "Een goudgele bloem op zilvergrijs blad, aangepast aan de droge Dorstvallei."
 },
 "flower_loosestrife": {
  "name": "Grote kattenstaart",
  "wild_category": "flower",
  "species": "loosestrife",
  "type": "material",
  "sheet": "flower_items",
  "icon": 14,
  "sell": 4,
  "desc": "Een lange paarse bloempluim op de vaste, vochtige rietbermen van het Kruipmoeras."
 },
 "flower_alpine_aster": {
  "name": "Alpenaster",
  "wild_category": "flower",
  "species": "alpine_aster",
  "type": "material",
  "sheet": "flower_items",
  "icon": 15,
  "sell": 5,
  "desc": "Een lage paarse sterbloem tussen de koude steenranden van de Bergpas."
 }
}
const RESOURCES := {
 "flower_daisy":{"name":"Madeliefje","wild_category":"flower","species":"daisy","skill":"foraging","item":"flower_daisy","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("eee7d5"),"sheet":"flower_plants","frame":0,"cell":32},
 "flower_bluebell":{"name":"Boshyacint","wild_category":"flower","species":"bluebell","skill":"foraging","item":"flower_bluebell","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("858fc7"),"sheet":"flower_plants","frame":1,"cell":32},
 "flower_foxglove":{"name":"Vingerhoedskruid","wild_category":"flower","species":"foxglove","skill":"foraging","item":"flower_foxglove","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("bc86ad"),"sheet":"flower_plants","frame":2,"cell":32},
 "flower_edelweiss":{"name":"Edelweiss","wild_category":"flower","species":"edelweiss","skill":"foraging","item":"flower_edelweiss","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("d5dac6"),"sheet":"flower_plants","frame":3,"cell":32},
 "flower_sea_aster":{"name":"Zeeaster","wild_category":"flower","species":"sea_aster","skill":"foraging","item":"flower_sea_aster","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("a8a0c4"),"sheet":"flower_plants","frame":4,"cell":32},
 "flower_hollyhock":{"name":"Stokroos","wild_category":"flower","species":"hollyhock","skill":"foraging","item":"flower_hollyhock","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("c58994"),"sheet":"flower_plants","frame":5,"cell":32},
 "flower_thrift":{"name":"Engelsgras","wild_category":"flower","species":"thrift","skill":"foraging","item":"flower_thrift","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("d7a6b1"),"sheet":"flower_plants","frame":6,"cell":32},
 "flower_sea_lavender":{"name":"Lamsoor","wild_category":"flower","species":"sea_lavender","skill":"foraging","item":"flower_sea_lavender","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("ac9bc5"),"sheet":"flower_plants","frame":7,"cell":32},
 "flower_horned_poppy":{"name":"Gele hoornpapaver","wild_category":"flower","species":"horned_poppy","skill":"foraging","item":"flower_horned_poppy","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("e6c26f"),"sheet":"flower_plants","frame":8,"cell":32},
 "flower_sea_campion":{"name":"Zeesilene","wild_category":"flower","species":"sea_campion","skill":"foraging","item":"flower_sea_campion","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("dfdcc8"),"sheet":"flower_plants","frame":9,"cell":32},
 "flower_yellow_iris":{"name":"Gele lis","wild_category":"flower","species":"yellow_iris","skill":"foraging","item":"flower_yellow_iris","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("e0c663"),"sheet":"flower_plants","frame":10,"cell":32},
 "flower_forget_me_not":{"name":"Vergeet-mij-nietje","wild_category":"flower","species":"forget_me_not","skill":"foraging","item":"flower_forget_me_not","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("8db6cf"),"sheet":"flower_plants","frame":11,"cell":32},
 "flower_snowdrop":{"name":"Sneeuwklokje","wild_category":"flower","species":"snowdrop","skill":"foraging","item":"flower_snowdrop","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("d6e4d6"),"sheet":"flower_plants","frame":12,"cell":32},
 "flower_desert_marigold":{"name":"Woestijngoudsbloem","wild_category":"flower","species":"desert_marigold","skill":"foraging","item":"flower_desert_marigold","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("dfbb6b"),"sheet":"flower_plants","frame":13,"cell":32},
 "flower_loosestrife":{"name":"Grote kattenstaart","wild_category":"flower","species":"loosestrife","skill":"foraging","item":"flower_loosestrife","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("b782b6"),"sheet":"flower_plants","frame":14,"cell":32},
 "flower_alpine_aster":{"name":"Alpenaster","wild_category":"flower","species":"alpine_aster","skill":"foraging","item":"flower_alpine_aster","amount":2,"xp":4,"cooldown":180.0,"duration":0.65,"color":Color("b3a2cc"),"sheet":"flower_plants","frame":15,"cell":32}
}
