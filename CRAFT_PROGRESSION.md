# Fase 4 — beroepen, materialen en uitrusting (0.14)

Zeven beroepen, bestaande tools, regionale materialen en zestien gearstukken waren
al aanwezig. Er ontbrak een verbinding tussen regionale avonturen en gemaakte gear.
Gemengde gearbonussen werden onvolledig getoond; langere lijsten overlapten de uitleg.
Deze fase geeft ontdekkingen een functie in drie verschillende speelstijlen.

## Ontdekken → maken → verbeteren

Drie eigen werktafels met tekeningen zijn bij **Greta in de smederij [10,7]**, in
**Lena's bibliotheek [5,9]** en op **de westelijke oever van het meer [15,7]** geplaatst.
Lezen leert één basispatroon. Herlezen geeft geen spullen of XP. De tafels hebben
een kleine voetbotsing, staan op begaanbare tegels en behouden doorgangen en oude
object-ID's door uitsluitend achteraan toegevoegd te worden. Op de kaart staan ze
als Werktekening.

| Keten | Basisrecept | Basisfunctie | Verbetering en ontdekking |
|---|---|---|---|
| Slagbanden → geharde slagbanden | Smeden 2; Greta; 2 koperstaven + 1 berkenhout | 10% minder techniekstamina | Bron hersteld: oude banden + 2 ijzerstaven + 2 zandsteen; 20% minder techniekstamina en 6% minder gewone zwaardwachttijd |
| Richtlens → heldere richtlens | Alchemie 1; Lena; 1 koperstaaf + 2 zilverkruid | 15% kortere precisievoorbereiding | Rietarchief geordend, Alchemie 2: oude lens + 2 ijskristal + 2 watermunt; 25% kortere voorbereiding en 10% sneller staminaherstel |
| Werkpak → bergwerkpak | Houthakken 1; overal; 2 berkenhout + 2 droge takken | 15% korter verzamelen | Klimlijn vastgezet, Houthakken 2: oud pak + 2 dennenhout + 2 wilgentwijgen; 25% korter verzamelen en 10 extra oppakbereik |

Deze gear gebruikt de bestaande hand-, hals- en borstvakken. Bezit geeft geen bonus;
uitrusten is een bewuste keuze. Werkpakken geven geen pantser. Bestaande bescherming,
snelheidsgear, regen-amuletten en aanvalshandschoenen blijven alternatieven.

De techniekstaminabonus geldt voor voorbereide steken, breekslagen en precisieschoten.
Kosten worden afgerond op hele stamina. Gewone slagen, de derde comboslag, rollen en
sprinten behouden hun regels. De lens verandert alleen voorbereiding, niet pijlschade,
bosschade, bereik, verbruik of staminakosten. Het werkpak verandert alleen de duur van
verzamelen; opbrengst, XP en opgeslagen cooldown blijven gelijk.

Verbeteren is een echt recept: de oude basisgear wordt verbruikt. Alle vereisten worden
vooraf gecontroleerd; een ontbrekend materiaal of nog niet afgerond avontuur kost niets.
Als het basisstuk gedragen is, wordt de verbetering na het maken direct gedragen.
Een los basisstuk in de tas wordt niet automatisch uitgerust. Wisselen of verbeteren
vult stamina niet. Maken slaat de afgeronde transactie via de bestaande autosave op.

## Materialen met een functie

- Dennenhout kan berkenhout vervangen bij koper smelten en vijf pijlen maken.
- Twee ijzeroer + één dennenhout geven bij Greta één ijzerstaaf, met dezelfde
  beroepsvereisten en XP als het bestaande ijzerrecept.
- Zandsteen hardt slagbanden; ijskristal en watermunt helpen de heldere lens;
  dennenhout en wilgentwijgen versterken het werkpak.
- Acht eerder ontbrekende regionale consumables zijn toegevoegd aan de bruikbare
  voorraad: vorstelixer, wintergloed, zandbalsem, braadstuk, mistedrank, dauwsoep,
  moeraselixer en veenbespap. Volle waarden verspillen geen portie; gemengde gerechten
  kunnen gebruikt worden als ten minste één van hun effecten nodig is.

Geen nieuw materiaal of extra harvest-cooldown nodig. De basis- en verbeterrecepten
geven 15–20 beroeps-XP; drie normale koperstaafrecepten bereiken Smeden 2. De
bereikbaarheid en gereedschapsroutes blijven via de bestaande systemen lopen.

## Begrijpelijke schermen

Het receptenmenu toont aantallen complete materialen en de eerste nog ontbrekende
vereiste. De uitleg bevat alle ingredientaantallen, echte vindplaatsen uit de
grondstoffentabel, nodig gereedschap, niveau en werkplek. Verwerkte materialen
verwijzen naar Maken. De uitleg is scrollbaar met muis en controller; rechts gaat
van een recept naar de uitleg en daarna naar de doelknop.

Eén recept kan als materiaaldoel worden gevolgd. Dat doel staat onder de huidige
quest, verdwijnt tijdens menu's en blijft bewaard bij save/load. Beroepen openen
selecteert het gevolgde recept en bijpassende filter. Maken wist het bereikte doel.
Invalid/unknown opgeslagen doelen worden genegeerd; saves zonder doel blijven geldig.

De uitrustingspagina toont maximaal twee opties tegelijk. Pijltjes bij de paginateller
en de bestaande controllernavigatie bereiken alle opties. Geen lijst loopt achter de
uitleg of actieknoppen door. Alle bonussen worden getoond, met een vergelijking van
de hele gedragen set die de bestaande bonuslimieten meerekent. Lange uitleg krijgt
zo nodig 16 of 15px tekst; de gebruikelijke grootte is 17px. Bronnen voor eerdere
avontuurbeloningen staan nu ook op de gearpagina.

De inventaris toont bij materiaal waarvoor het gebruikt wordt en waar het vandaan
komt. De gevechtshint gebruikt de echte huidige techniekstaminakosten. Het werkpak,
slagbanden en de lens hebben een eigen kleine zichtbare toevoeging aan het personage;
een vooraan hangende lens wordt niet over de rugzak aan de achterkant getekend.

## Eigen werk en controle

`tools/art_x_craft.py` maakt zes eigen gear-iconen, drie werktafels met twee frames
en twee gesynthetiseerde geluiden. Geen externe assets.

`craft_progression_test.gd` controleert fysiek lezen met keyboard/controller, bruikbare
plekken, verzamelen naar gear, bronnen, een controller-materiaaldoel, echte gemeten
bonussen, regionale blokkades, gedragen verbetering, dubbele uitvoering, werkelijke
save/load, corrupte doelen en alle acht regionale consumables. Bestaande gear-, menu-,
beroeps-, gevechts- en wereldtests blijven onderdeel van de verplichte volledige suite.
Extra zichtbaarheidstest controleert ook een diep recept in een geschaald menu.

Visuele review: 1152×648, NL/EN, werktafels, materiaaldoel, recepten/uitleg,
gearpagina's en gedragen set. Geen fysieke controller of alle resoluties getest.
