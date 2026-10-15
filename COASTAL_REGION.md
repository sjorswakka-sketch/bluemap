# De kustregio krijgt ruimte — 0.22.0-preview

Fase 3 van DEVELOPMENT_COAST.md. Basis f4a4321d61bdfd396786af24df16502d07fe73b8,
branch claude/affectionate-mendel-vc1idx. Bestaande getijdenfase behouden.

## Zes plekken met een eigen functie

- Blauwe Kust: de bestaande strand-/duinenroute, veer en verbinding met Zilvermeer.
  Een optioneel noordelijk oeverpad sluit nu aan op de riviermonding.
- Zilvermonding: brede oevers, riet, een hoge houten rivierbrug en een rustig
  westelijk ommetje. Zuid: kust. Oost: haven.
- Rietwenk Haven: één compacte werkkade, twee herkenbare werkplekken en twee
  bewoners. De brede westelijke aanloop en noordelijke grasroute blijven rustig.
- Lichtkaap: hoog grasland, windbegroeiing, vuurtoren en een zuidelijk zeezicht.
  Het westelijke pad naar de haven is altijd open.
- Meeuweneiland en Getijdenbaai: bestaande paden, uitzicht, getijde en leenlijn
  behouden. De veerborden bieden ook de haven aan.

Nieuwe kaarten: 76×46, 74×46 en 76×46. Samen 6.525 terreinvloertegels, plus vier
nieuwe aansluittegels aan de kust. De statische audit groeit van 16.921 naar
23.450 (+38,6%). Dit telt vloer vóór gebouwvoetafdrukken en andere bezetting;
het is geen claim dat iedere tegel leeg of vrij bereikbaar is.
De nieuwe gebouwen blokkeren werkelijk 26 vloerlocaties en hebben fysieke
rechthoeken; veilige aankomst controleert ook personen en andere botsvormen.

Geen nieuwe vijanden, kisten, resourceplekken, dagelijkse eisen of opdrachten.
De omvang is het gevolg van bruikbare brede landschappen, geen bestandsquota.
Van de 30 bestaande kaarten blijven 29 terreinaudits exact gelijk. De 27 kaarten
buiten de drie bestaande kustgebieden blijven ook inhoudelijk ongewijzigd.
Meeuweneiland en Getijdenbaai krijgen alleen één bestemming op hun bestaande
reisboard. De kust krijgt een noordelijke aansluiting en richtingbord.
De volgorde van bestaande objects en hun save-ID's blijft behouden.

## Praktische bewoners en routes

Ise de veervrouw opent na haar gesprek dezelfde veilige bestemmingselector als
het reisbord. Raf de nettenmaker toont de regiokaart. Beiden bieden ook een
keuze om rustig door te lopen. Geen beloningen of fetch-opdracht via hun gesprek.
De bestaande veerpresentatie blijft gratis, kort, over te slaan en af te breken.
De haven is rechtstreeks per veer bereikbaar vanaf kust en de twee eilanden.

De regio is zonder gereedschap te wandelen:
Blauwe Kust → Zilvermonding → Rietwenk Haven → Lichtkaap, en terug.
Meeuweneiland → Getijdenbaai blijft een aparte loopbrug. De regiokaart
onderscheidt de twee landnetwerken; een route tussen beide gebruikt de echte
veerverbindingen uit Journey.graph(). Nummerknoppen en tekst koppelen namen
aan het diagram. Goud toont de wandelpaden; blauw alleen de gekozen veerroute.
De kaart is informatie, geen gratis teleport buiten de veer om.

## Eigen beeld, animatie en geluid

tools/art_x_coastal_region.py reproduceert alle drie landschappen, vuurtoren,
veerwerkplek, nettenwerkplaats, Ise/Raf, regiobord, bankje, riet, veldbloemen,
drijfhout, zoutgras en een zacht zelfgesynthetiseerd belgeluid.
Geen externe assets. De bestaande 78 terreintegels, boot en kustmuziek blijven
bytegelijk. Eigen lage details maken de oevers/kaap herkenbaar zonder prompts.
Raf knoopt zijn net, Ise beweegt haar vaarstok. Het vuurtorenlicht draait langzaam
en wordt bij nacht zichtbaar, met twee rustige boeien over zee.

Hoge gebouwen krijgen dichtbij extra ruimte boven de speler door een rustige,
begrensde camera-offset. Bij kaartwisseling reset die. De gebouwen hebben
echte voetafdrukken; geen looproute door een geschilderde gevel.
De havenboot ligt op water buiten de planken, met aansluitende landvast.

## Controle en grenzen

tests/coastal_region_test.gd bewaakt zes gebieden, oude slots, de kleine
kustterreinaansluiting, rustige kaartinhoud en beide echte routegrafen.
Hij loopt werkelijk heen en terug, controleert fysieke gebouwbotsing,
bewonersdiensten, muisselectie, controllerafsluiten en NL/EN-uitleg voor alle
bestemmingen op 960×540, 1152×648 en 1600×900. Echte save/load op de kaap,
oude collecties/voltooid-spel, veilige vloer bij geveloverlap, nieuwe veeraankomst
en geforceerde kaartwissel met geopend regiopaneel worden meegenomen.

De volledige suite heeft nu 51 tests. Alle tests en renders gebruiken een
geverifieerde eigen UUID-opslag, nooit een echte spelerssave. Native muis en
toetsen en gesimuleerde controllerinput; geen fysieke controllerclaim.
De eerste muiskliktest las direct na resize nog oude coördinaten; hij wacht nu,
zoals de game zelf, op de nieuwe schermindeling en test daarna de echte klik.

De definitieve beeldcontrole omvat rivierbrug/oevers, havenaanloop, beide
werkplekken, steiger, kaappad, vuurtoren, bankje, nacht/regen, overzichten,
NL/EN-regiokaart en veerpaneel op drie formaten, bewonersgesprekken en bestaande
rustplekken. Uitgezoomde overzichten zijn diagnostisch, met zwart buiten de wereld.
Het renderharnas met screenshots is geen betrouwbare gameplay-FPS-meting.
Bestaande resource-cleanupwaarschuwingen bij stoppen zijn geen scriptfouten.
Geen claim over alle hardware, resoluties of toegevoegde speeltijd.

Testlogs, beelden, audits, exacte schone bronkopie en succesvolle Windows-export
worden naast de release bewaard. Eén volgende go start alleen fase 4:
eigen avonturen en ontmoetingen, met behoud van deze vrije aanloop/terugwegen.
