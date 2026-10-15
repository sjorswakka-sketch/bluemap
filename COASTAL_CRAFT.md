# Kustambachten en havenwerkplaats · 0.24.0-preview

Fase 5 gebruikt de bestaande zeven beroepen en de ruimte van de kustregio.

## Vier rustige materiaalplekken

| Materiaal | Vindplaats | Beroep / gereedschap | Eén oogst |
| --- | --- | --- | --- |
| Zoutdrijfhout | Blauwe Kust, buiten het pad op de zuidelijke zandvlakte | Houthakken 1, stenen of ijzeren bijl | 6 |
| Oevervezel | Westelijke graslandzijde van Zilvermonding | Kruidenzoeken 1, geen tool | 6 |
| Zeeagaat | Veilige zuidelijke gang van de Tijholte | Mijnbouw 1, stenen of koperen pikhouweel | 6 |
| Zoutblad | Open grasland van Lichtkaap | Kruidenzoeken 1, geen tool | 4 |

Eén kleine vindplaats per materiaal. De bestaande oogstanimatie, toolcontrole,
annulering en opgeslagen actieve-speeltijd werken ook hier. Herstelduur is vijf
minuten actief spel; slapen, een kaartwissel en laden versnellen dat niet.
Een oogst van elke plek levert samen genoeg nieuwe materialen voor alle eerste
plannen. Bestaande gewone ingrediënten blijven nodig; geen dagelijkse ronde.

## Bestaande bewoners en zes recepten

Raf deelt het lijn- en rekpatroon tijdens zijn gewone gesprek op de havenkade.
Zijn veer/kaartdiensten houden hun bestaande keuzes. De deurmat vóór de
nettenloods opent de gratis werkplaats. Greta en Lena noemen de nieuwe plannen
op hun bestaande werktekeningen; oude geleerde patronen blijven geldig.

Alle nieuwe recepten beginnen op beroepsniveau 1. Het bestaande receptenboek
toont echte kosten, vindplaatsen, ontbrekende tools, werkplek en materiaaldoel.
Een expliciet gekozen recept opent ook als je een ander materiaaldoel volgt.
Opgeslagen ingrediënten tellen niet als tasvoorraad: de tekst noemt wat in de
havenkist zit en vraagt het eerst op te halen.

- Rafs werkbank: oeverlijn (2 drijfhout, 2 vezel, 1 koperstaaf) en wandrek
  (2 drijfhout, 2 droge takken).
- Greta's smederij: ankerbanden (2 drijfhout, 2 zeeagaat, 1 koperstaaf).
- Lena's alchemietafel: waaierbanden (2 vezel, 2 zeeagaat, 1 zilverkruid)
  en lamp (2 zeeagaat, 1 slijmgel).
- Mila's keuken: kustbouillon (1 baars van het Zilvermeer, 1 zoutblad),
  voor 2 hartjes en 20 stamina. Joris' bestaande vangsten blijven vissen-XP geven.

Kosten worden volledig gecontroleerd vóór verbruik. Unieke tools, meubels en
gear hebben maximaal één exemplaar: opnieuw maken geeft geen kosten of XP.

## Twee echte keuzes voor hetzelfde handvak

**Ankerbanden:** 1 pantser en 10 extra stamina, binnen de bestaande setlimieten.
Techniek + zwaard begint 0,12 seconde voorbereiding, gevolgd door een frontale
wacht van 0,32 seconde. Alleen een tijdige treffer van voren wordt gestopt.
Daarna geeft een gewone zwaarddruk binnen 0,7 seconde één smalle tegenstoot
met 20 extra bereik en 1 extra schade. Een gemiste wacht herstelt 0,6 seconde.
Zij- en rugtreffers blijven gevaarlijk; de wacht stopt geen tweede treffer.
Basisprijs 18 stamina; bestaande techniekbonussen gelden.

**Waaierbanden:** 15% korter verzamelen en 8 extra oppakbereik, geen pantser.
Techniek + boog schiet na 0,55 seconde drie lichte pijlen in verschillende
richtingen. Elk doet 1 gewone schade, met 240 bereik, en de totale prijs is
28 stamina plus drie pijlen. Dit geeft spreiding tegenover het bestaande verre
precisieschot. Minder dan drie pijlen starten geen actie en kosten niets.

Alleen gedragen gear werkt. Wisselen vult geen stamina bij. Oude handschoenen
houden hun eigen sterke kanten, gewone aanvallen blijven beschikbaar en de
bestaande bindings blijven herbruikbaar met toetsenbord/muis of controller.
Rollen, geraakt worden, menu, invoerwissel, gear verwijderen en kaartwissel
onderbreken onvoltooide technieken; pijlen gaan pas bij het schot uit je tas.

De twee stijlen zijn eerst onafhankelijk getest met echte vijanden en pijlen,
daarna in de speler geïntegreerd. De vrijwillige proefopstelling in de werkplaats
heeft onschadelijke poppen, een wachtproef en lokale leenpijlen. Ze geeft geen
buit, kills of XP, geen gratis gear en schrijft geen tijdelijke voorwerpen weg.
Je eigen boog en banden blijven nodig; stamina blijft echt. Verlaten verwijdert
poppen en uitleenmogelijkheid. Het rustaltaar werkt volgens de gewone regels.

## Werkplaats, opslag en inrichting

Eén interieur van 30×22 in het bestaande havengebouw, zonder nieuwe bewoners.
Een brede doorgang naar de uitgang blijft vrij. Ontdek het rustaltaar om de
werkplaats later via de bestaande snelreiskaart te bereiken.

De kist bewaart maximaal twaalf materiaalsoorten, elk maximaal 99. Sleutels,
questvoorwerpen, gear en eten gaan er niet in. Verplaats 1, 5 of het getoonde
maximum. Volle kist, te groot aantal en ongeldige items worden vóór enige
mutatie geweigerd; gelijktijdige inventarissignalen kunnen niets dupliceren.
Het eigen optionele saveveld normaliseert onbekende/ongeldige data; oude saves
beginnen met een lege kist en behouden hun inventaris. Nieuw spel en Nieuw spel+
starten een nieuwe kist; bestaande gearregels voor Nieuw spel+ blijven gelden.

Wandrek en lamp hebben vaste plekken met een zichtbare sokkel en fysieke
voetafdruk. Plaatsen en opbergen verbruiken geen meubel. Lamp uit blijft zichtbaar;
warm licht en zeelicht zijn opgeslagen keuzes. Geen huur, slijtage of onderhoud.

De herbruikbare oeverlijn werkt aan beide rivierpalen. De presentatie duurt
1,2 seconde en kan met Terug of lopen worden afgebroken. De landingsplek en tool
worden opnieuw gecontroleerd. De hoge brug blijft altijd beschikbaar; alle
bestaande terreintegels en buitenvijandplekken blijven behouden.

## Eigen productie en verificatie

tools/art_x_coastal_craft.py maakt het interieur, materiaalicoontjes, bronnen,
werkprops en vier zachte geluiden uit eigen code. Bestaande art blijft gelijk.
Nieuwe grondstoffen mogen een eigen sheet gebruiken; oude frames behouden hun index.

coastal_style_prototype_test beproeft de twee technieken los.
coastal_styles_test controleert echte invoer, blokkade, tegenstoot, pijlkosten,
gesimuleerde controller, annuleren en de vrijblijvende oefenplek.
coastal_home_test controleert oogsten, kosten, bewoners, werkplaats, opslag,
inrichting, save/load, muis/controller, volle kist en beide rivieroevers.
De volledige bestaande suite blijft gelden, met afzonderlijke UUID-saves.
Visuele controle: NL/EN op 960×540, 1152×648 en 1600×900.
Geen echte spelerssave of fysieke controller gebruikt.

De volgende go is fase 6: het gehele avontuur, terugkeer, prestaties en distributie
als geheel nalopen. Er komt nu geen extra regio of verzameldruk bij.
