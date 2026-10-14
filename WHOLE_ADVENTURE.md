# Het avontuur als geheel — 0.16

De zes fases hebben eigen avonturen, bewoners, gevechten en materiaalroutes
toegevoegd. Deze laatste fase verbindt ze tot een reis die beter te volgen is.

## Audit en verbeteringen

| Bevinding | Gedrag in 0.16 |
| --- | --- |
| Een hoofddoel of lokale automatische tracker kon een andere bezigheid verdringen. | De speler kiest één actieve opdracht. Dat doel blijft op de HUD en in de save; afronden hervat de automatische doelen. |
| De opdrachtlijst gaf tekst, maar geen reisverband of voorbereiding. | Alle 31 opdrachten en 69 stappen hebben doelgebieden. Portaalroutes komen uit echte kaartdata. Ontbrekende sleutels/herstelvoorwaarden en de volgende doorgang worden genoemd. |
| De drie kristallen en verloren boeken hadden meerdere vindplaatsen. | Het doelgebied volgt nog ontbrekende kristallen/boeken en daarna de juiste ontvanger. |
| Twaalf altaren vulden een ongebegrensde lijst; de bevestiging viel onder het paneel. | Vijf zichtbare altaren, selectie die meescrollt, teller en een vaste ruimte voor de vraag. Controller en muis gebruiken dezelfde zichtbare rijen. |
| Een lange kaartlegenda kon over de reislijst lopen. | Legenda in twee rijen binnen de kaartkolom; coördinaten en een gouden ring helpen de volgende doorgang herkennen. |
| Een echt klein venster sneed de vaste menupositie af; prestaties konden lange doelen bedekken. | Het volledige menu past zich aan het viewport aan. Prestatiekaarten schuiven links beneden in, buiten opdracht-, materiaal- en regiobalken en de centrale spelerplek. Tijdens een baasgevecht wachten ze. |
| Oude posities of een reizende bewoner konden een aankomstplek bezetten. | Nieuwe kaart/laden en snel reizen controleren actuele tegel- en voetbotsingen. Een bezette plek wordt lokaal gecorrigeerd. Reizen op dezelfde kaart herlaadt geen vijanden of kisten. |
| Een rustpunt genas hartjes maar liet een vermoeide staminabalk staan. | Bewust rusten bij het altaar herstelt beide. Alleen reizen geeft geen herstel. Na een echte reis is er 1,25 s bescherming, deels tijdens de fade. |
| De Slijmkoning waarschuwde bij zichzelf en koos pas daarna waar hij landde. De getekende kring was kleiner/verschoven ten opzichte van schade. | Vanaf de aanloop liggen bestemming en fase vast. De vloerkring heeft de echte impactradius. Bewegen of schade aan de baas verplaatst/vergroot de aangekondigde landing niet. |

De normale rustactie bij Mila en slapen in een bed gebruiken hetzelfde volledige
herstel. Gewone drankjes houden hun eigen effect en worden niet gewijzigd.

## Tempo en voorbereiding

De uitleg verbindt gevechtsroutes met Greta's echte zwaardkosten en toont
huidige drankjes, hartjes, stamina en gedragen pantser. Muis levert bij Pim een
hartcontainer op; Wilfred geeft twee scherven voor het kristalzwaard. Zo loont
een sociaal verhaal vóór een zwaar gevecht. De rustige
routes voor vissen, koken, lezen en kruiden blijven opties; er is geen nieuwe
levelgrens, verplicht grindquotum of tijdslot toegevoegd.

De golem, de hoofdroute, de mijn, de klimaatgebieden en de Diepte behouden hun
beloningen en voorwaarden. Een balansbot wees vooral op landingsschade bij de
eindbaas. De correctie geeft een langere leesbare aanloop (0,65/0,60/0,50 s),
een vast aangegeven landingspunt, veilige grond en 0,65 s herstel na de landing.
De drie bestaande impactradii (64/74/86) en schade blijven behouden.

Vaste-seedvergelijking, zes gevechten per combinatie, geen gedragen pantser:

| Tegenstander / zwaard / hartjes | Overwinningen 0.15 | Overwinningen 0.16 | Gemiddelde schade 0.15 → 0.16 |
| --- | --- | --- | --- |
| Slijmkoning / hout / 5 | 0/6 | 0/6 | 13,8 → 12,8 |
| Slijmkoning / ijzer / 5 | 2/6 | 0/6 | 13,3 → 13,3 |
| Slijmkoning / ijzer / 6 | 1/6 | 2/6 | 17,2 → 10,7 |
| Slijmkoning / kristal / 5 | 5/6 | 4/6 | 11,2 → 10,3 |
| Slijmkoning / kristal / 6 | 5/6 | 4/6 | 11,2 → 11,8 |
| Golem / hout / 5 | 6/6 | 6/6 | 6,3 → 6,3 |
| Golem / ijzer / 5 | 6/6 | 6/6 | 2,0 → 2,0 |

Dit ondersteunt zwaard- en hartjesvoorbereiding; het bewijst geen hogere algemene
winstkans. De bot leest de beschikbare landingsinformatie en heeft een beperkt
ontwijkbeleid. De belangrijkste correctie wordt afzonderlijk gecontroleerd:
de zichtbare bestemming/radius liggen vast en buiten die radius krijg je geen
landingsschade. De vergelijking omvat 84 gevechten met dezelfde seeds en
startmiddelen; extra potions en gedragen gear zijn hier niet gesimuleerd.

## Opslag en bediening

De optionele keuze gebruikt `jr_focus_<quest>` in het bestaande flags-woordenboek.
Er is geen nieuw saveformaat. Oude saves beginnen met de bestaande automatische
doelen; ongeldige of afgeronde keuzes worden genegeerd. Nieuw spel en Nieuw spel+
wissen de keuze met de gewone flags. De hoofdroute, opening, alle oude kist-ID's,
materiaaldoelen, gear en eerdere wereldgevolgen blijven werken.

Opdrachten heeft een lijst en scrollbare uitleg. Rechts opent uitlegfocus;
omhoog/omlaag scrollt daar, links keert terug. Enter/A of de zichtbare knop volgt
of stopt. Het kaartmenu bladert door alle altaren; bevestigen en annuleren blijven
zichtbaar, ook bij de laatste rij. De nieuwe landingsmarkering is zelf getekend
in code; teksten en vormgeving zijn zelf gemaakt en in NL/EN beschikbaar.

## Controle en grenzen

- `whole_adventure_test`: alle 69 stapdoelen, opgeslagen focus, toetsenbord,
  gesimuleerde controller en muisklikgebieden, echte voorraad, contextdoelen,
  twaalf altaren, kaartlegenda's, 146 kaartspawns en 24 altaaraankomsten in nieuwe
  en herstelde wereldtoestanden. De eigen plaatsingscontrole wordt onafhankelijk
  getoetst met Godots physics-query voor de echte spelervoet.
- Ook getest: bezette aankomst, reizen zonder kaartreset of gratis herstel,
  expliciet rusten, en de echte schade net binnen/buiten de eindbaasmarkering.
  De aankondiging blijft gelijk wanneer de speler beweegt en de baas van fase
  verandert. Het volgende patroon krijgt weer zijn eigen nieuwe fase.
- De bestaande hoofdverhaal-, eerste route-, gebied-, beroep-, save- en
  bedieningstests draaien samen met de nieuwe test in de volledige suite.
  GitHub CI draait de suite opnieuw en exporteert de Windows-versie.
- Visuals: NL/EN-opdrachten en uitleg, opvolgdoel plus materiaaldoel, volgende
  kaartdoorgang, de laatste altaar, bevestiging en baasaanloop/sprong/fase 3.
  Menu's zijn beoordeeld op 1152×648, 960×540 en 1600×900.
- `tests/boss_sim.gd` gebruikt vaste seeds en accepteert `--episodes=N`.
  Oude/nieuwe gevechten worden in aparte testkopieën met dezelfde uitrusting
  vergeleken. Dit is een eenvoudige bot, geen bewijs voor iedere menselijke
  speelstijl. Fysieke controllers en alle schermformaten zijn niet getest.

`tools/journey_audit.gd` drukt actuele opdrachten, altaren en gevechtsverdeling
uit de kaartdata af. Draai gameplaytests en balanssimulaties altijd in een kopie
met een geverifieerde aparte opslag; `tools/run_tests.py` regelt dat voor tests.
