# Werelddekking van fase 5

Het [dekkingsregister](../world-coverage.json) beschrijft 37 kaarten na de echte samenstelling en het laden door de behouden Godot-code, plus benoemde synthetische toestanden; het is geen Unity-implementatie en geen bewijs van alle mogelijke combinaties of een volledige doorspeelbeurt.

Iedere bronverwijzing bevat de volledige oorspronkelijke bestandshash, functiehash en locatie. De 24 producentfamilies, 34 directe afhankelijkheden van `world.load_map`, 20 registry-voorbereiders en alle 49 objecthandlers worden afzonderlijk gecontroleerd. Een verdwenen hook, producent, handler of vereiste scenariogetuige laat de contracttest mislukken. De hashes horen bij de bewaarde referentie `a8a988be27835dec979d2523a3a85a34385eac54`.

## Wat een geladen kaart toevoegt

`world.load_map` voert eerst drie voortgangsmigraties uit, verplaatst routevijanden, bereidt deuren voor, voegt oude beroepsvindplaatsen achteraan toe en kiest specifieke soorten planten. Daarna volgen getij, het herstelde tijrad, waterbeschrijvingen en de daadwerkelijke tegels. Bestaande objectslots blijven behouden, ook als ze uitgeschakeld zijn of hun voorwaarden een node tegenhouden.

De levende wereld verandert vervolgens terrein, echte botsingen en vindplaatsen in mijn, bos, ijsdorp en moeras. Vuurtoren en andere grote herkenningspunten voegen rechtstreeks bezette cellen toe. Deze wijzigingen zijn niet af te leiden uit alleen de oorspronkelijke kaartregels. Ook de geheime boekenkast schrijft vloer terug in de kaart en verwijdert de bijbehorende botsingen.

Directors voegen pootafdrukken, reliëf, dagboek en luisterschalen toe; het dorpsbegin maakt twee echte bloembakcolliders, apparaten en acteurs. Herstelvlaggen laten acht bewoners verschijnen en `ls_served` laat drie herberggasten binnenkomen. Hun werk- en rustkeuze gebruikt dezelfde klok, weersregels en opgeslagen keuzes als de oorspronkelijke game.

Woning en erf gebruiken opgeslagen plaatsingen. De functionele basismeubels verplaatsen daadwerkelijk; extra meubels, appelstammen, hekken en automatische poortjes hebben eigen colliders. Ingepakte werkplekken worden verborgen en verliezen hun botsingslaag. Landbouw bewaart grond, gewas, groei, mest, productie en honing; irrigatie berekent een aangesloten netwerk opnieuw zonder tijd te laten verstrijken. Opgeslagen mestdrops worden afzonderlijk gematerialiseerd.

De Vergeten Wachter voegt zijn zes pilaren pas via uitgestelde aanroepen toe. Na zijn nederlaag verschijnt in plaats daarvan de kist met de vaste sleutel `chest:depths2:heart`; de inhoud hangt af van de bestaande hartcapaciteit. Een geopende beloningskist blijft zichtbaar. Gewone geopende kisten blijven eveneens staan, unieke verzamelde pickups verdwijnen en NPC-aanwezigheid wordt ook via `exists_if` gecontroleerd.

## Vereiste toestandsgroepen

| Groep | Verschillen die een getuige nodig hebben |
|---|---|
| Alle kaarten | Nieuwe uitgangssituatie en volledig ingevulde synthetische voortgang, met alle oorspronkelijke aankomsten. |
| Moeras | Beide kleppen dicht, iedere afzonderlijke klep open, beide open, drooggelegde oever en herstelde brug; bijbehorende water- en botsingsgegevens. |
| Getij | Laag, opkomend, hoog, aflopend, tijdelijk opengehouden bezette zandbank en sluiten na veilig verlaten. |
| Kustverhalen | Hersteld rad, vredige poel, lopend duel, werkwateruitkomst en herstelde beschutting. |
| Oude en regionale routes | Kat thuis, aanwijzingen, drie luisterstappen, beide gedenkkeuzes, mijn/bos/herstelde huizen, bronkeuzes, klimlijn en beide archiefpresentaties. |
| Dorp en bewoners | Nieuw begin, hersteld water, oudere start zonder openingsvlag en vaste avondroutines. |
| Woning, erf en landbouw | Andere meubels, verplaatste en ingepakte werkplekken, poort dichtbij/veraf, droge/aangesloten/onderbroken irrigatie, rijpe gewassen, honing met/zonder bloemen en opgeslagen mestdrop. |
| Geheimen, poorten en bazen | Geheime bibliotheekvloer, gesloten/open routepoorten, slapende Wachter met pilaren, verslagen Wachter, geopende beloning en beloning bij volledige hartcapaciteit. |

De precieze scenario-ID's en noodzakelijke eigenschappen staan per producent in het register. De scenariofixtures zijn in geheugen opgebouwd; persoonlijke saves worden hiervoor niet geopend of gepubliceerd. De daadwerkelijke exportcontrole moet naast deze bron- en scenariodekking ook de volledige verwachte verzameling snapshots en hun inhoud verifiëren.

## Grenzen van een vaste opname

Een gewone opname bevriest klok, AI en beweging. Alleen benoemde projectiemethoden mogen expliciet worden aangeroepen: bijvoorbeeld een herstelverversing, het herberekenen van irrigatie of een gecontroleerde nuldelta-aanroep voor een aanwezigheidsvoorwaarde. Willekeurige `_process`- of physics-aanroepen kunnen triggers, reizen, buit en voortgang uitvoeren en zijn geen algemene exportstrategie. Nieuwe nodes en uitgestelde colliderwijzigingen moeten vóór de opname verwerkt en opnieuw bevroren zijn. De 27 benoemde projecties bevatten ook de veilige lichtvelden van meubels, fakkels, lantaarns, altaren, ramen, herkenningspunten en dieptelampen. `living_object` mag alleen met `active == false` worden geprojecteerd, zodat de vroege return vóór gevechten en voortgang blijft gelden. `diepte_seal._process(0)` is expliciet uitgesloten: ook zonder tijdstap kan het een verhaalovergang starten; alleen de bevroren aanmaaktoestand en volledige oorspronkelijke bron blijven daarvan opgenomen.

De opname bevat terrein, werkelijke tegelcellen en botsingspolygonen, `solid_cells`, ook niet-gescripte geneste colliders, transformaties, lagen, uitgeschakelde vormen en relevante scriptvelden. De toestand vóór laden en ná de drie migraties blijft apart zichtbaar. Een tijdelijke referentie-ID voor een runtime-node vervangt nooit een bestaande opgeslagen sleutel.

Niet iedere animatiefase, bewegingspositie, weersovergang, aanval, projectile of arenagolf wordt door deze vaste toestandsgetuigen beschreven. Die oorspronkelijke producenten en hun volledige code blijven met bronankers behouden; hun uitvoering en gelijkwaardigheid horen bij de latere gameplay- en presentatiefases. Fase 5 claimt geen gerenderde Unity-wereld, saveconversie, grafische gelijkwaardigheid of onbeperkte toestanddekking.
