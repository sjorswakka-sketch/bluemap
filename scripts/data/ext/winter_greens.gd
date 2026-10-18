extends RefCounted
## Frost-hardy foods. All sixteen are hand harvested and use their own item art.
const ITEMS := {
 "winter_kale": {
  "name": "Boerenkool",
  "type": "use",
  "sheet": "winter_items",
  "icon": 0,
  "heal": 1,
  "stamina": 8,
  "sell": 3,
  "desc": "Stevige, gekrulde bladeren die na een nacht vorst zachter smaken. Herstelt 1 hartje en 8 uithoudingsvermogen."
 },
 "winter_broccoli": {
  "name": "Broccoli",
  "type": "use",
  "sheet": "winter_items",
  "icon": 1,
  "heal": 1,
  "stamina": 8,
  "sell": 4,
  "desc": "Een groene winterroos uit een beschutte sneeuwberm. Herstelt 1 hartje en 8 uithoudingsvermogen."
 },
 "winter_cauliflower": {
  "name": "Bloemkool",
  "type": "use",
  "sheet": "winter_items",
  "icon": 2,
  "heal": 1,
  "stamina": 7,
  "sell": 4,
  "desc": "Een roomwitte koolroos; de buitenste bladeren beschermen haar tegen lichte vorst. Herstelt 1 hartje en 7 uithoudingsvermogen."
 },
 "winter_sprouts": {
  "name": "Spruiten",
  "type": "use",
  "sheet": "winter_items",
  "icon": 3,
  "heal": 1,
  "stamina": 7,
  "sell": 3,
  "desc": "Kleine kooltjes langs een stevige stengel. Vorst maakt ze milder. Herstelt 1 hartje en 7 uithoudingsvermogen."
 },
 "winter_beet": {
  "name": "Rode biet",
  "type": "use",
  "sheet": "winter_items",
  "icon": 4,
  "heal": 1,
  "stamina": 8,
  "sell": 3,
  "desc": "Een donkerrode, zoete wortel die onder de beschutte grond rijpt. Herstelt 1 hartje en 8 uithoudingsvermogen."
 },
 "winter_carrot": {
  "name": "Winterpeen",
  "type": "use",
  "sheet": "winter_items",
  "icon": 5,
  "heal": 1,
  "stamina": 9,
  "sell": 3,
  "desc": "Een stevige oranje wortel, bewaard onder een deken van sneeuw. Herstelt 1 hartje en 9 uithoudingsvermogen."
 },
 "winter_parsnip": {
  "name": "Pastinaak",
  "type": "use",
  "sheet": "winter_items",
  "icon": 6,
  "heal": 1,
  "stamina": 10,
  "sell": 3,
  "desc": "Een roomkleurige wortel die juist zoeter wordt na koude nachten. Herstelt 1 hartje en 10 uithoudingsvermogen."
 },
 "winter_leek": {
  "name": "Winterprei",
  "type": "use",
  "sheet": "winter_items",
  "icon": 7,
  "heal": 1,
  "stamina": 7,
  "sell": 3,
  "desc": "Dikke blauwgroene bladeren beschermen het bleke hart tegen de kou. Herstelt 1 hartje en 7 uithoudingsvermogen."
 },
 "winter_savoy": {
  "name": "Savooiekool",
  "type": "use",
  "sheet": "winter_items",
  "icon": 8,
  "heal": 1,
  "stamina": 8,
  "sell": 4,
  "desc": "Een compacte kool met dikke, bobbelige bladeren tegen de vorst. Herstelt 1 hartje en 8 uithoudingsvermogen."
 },
 "winter_red_cabbage": {
  "name": "Rode kool",
  "type": "use",
  "sheet": "winter_items",
  "icon": 9,
  "heal": 1,
  "stamina": 8,
  "sell": 4,
  "desc": "Dieprode bladeren vormen een stevige kool onder de rijp. Herstelt 1 hartje en 8 uithoudingsvermogen."
 },
 "winter_spinach": {
  "name": "Winterspinazie",
  "type": "use",
  "sheet": "winter_items",
  "icon": 10,
  "heal": 1,
  "stamina": 6,
  "sell": 2,
  "desc": "Lage, groene rozetten die in zachte sneeuw beschutting vinden. Herstelt 1 hartje en 6 uithoudingsvermogen."
 },
 "winter_lambs_lettuce": {
  "name": "Veldsla",
  "type": "use",
  "sheet": "winter_items",
  "icon": 11,
  "heal": 1,
  "stamina": 6,
  "sell": 2,
  "desc": "Kleine, ronde blaadjes die bij lage temperaturen langzaam doorgroeien. Herstelt 1 hartje en 6 uithoudingsvermogen."
 },
 "winter_purslane": {
  "name": "Winterpostelein",
  "type": "use",
  "sheet": "winter_items",
  "icon": 12,
  "heal": 1,
  "stamina": 7,
  "sell": 2,
  "desc": "Sappige, hartvormige winterblaadjes uit een beschutte rotsrand. Herstelt 1 hartje en 7 uithoudingsvermogen."
 },
 "winter_swede": {
  "name": "Koolraap",
  "type": "use",
  "sheet": "winter_items",
  "icon": 13,
  "heal": 1,
  "stamina": 10,
  "sell": 4,
  "desc": "Een zware geelviolette knol die onder de vorstgrens groeit. Herstelt 1 hartje en 10 uithoudingsvermogen."
 },
 "winter_celeriac": {
  "name": "Knolselderij",
  "type": "use",
  "sheet": "winter_items",
  "icon": 14,
  "heal": 1,
  "stamina": 9,
  "sell": 4,
  "desc": "Een ruwe, geurige knol met stevige bleekgroene bladstelen. Herstelt 1 hartje en 9 uithoudingsvermogen."
 },
 "winter_salsify": {
  "name": "Schorseneer",
  "type": "use",
  "sheet": "winter_items",
  "icon": 15,
  "heal": 1,
  "stamina": 10,
  "sell": 4,
  "desc": "Lange, donkere wortels die na vorst mild en zoet smaken. Herstelt 1 hartje en 10 uithoudingsvermogen."
 }
}
