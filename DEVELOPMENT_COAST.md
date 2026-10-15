# Blauwe Kust — grotere ontwikkelronde
Plan aangepast op verzoek van sjors, 14 oktober 2026.
Basis: 0.19.0-preview, commit 8a496cbd5e79ce254f77d0943c1ac96806c0f102,
branch claude/affectionate-mendel-vc1idx.

Dit is het actieve faseplan. De eerste drie fases van DEVELOPMENT_ROUND_2
blijven afgerond in 0.17–0.19. De nog niet uitgevoerde fases 4–6 van die ronde
gaan op in deze grotere ronde: grotuitstapjes in fase 4, samenwerking/gevolgen
in fases 4–5 en totaalcontrole in fase 6. Er is één eerstvolgende fase.
Het uitbreidingsonderzoek is de onderbouwing; een exe-grootte is geen contentbudget.

## Werkafspraak

Eén go start alleen de volgende fase. Binnen die fase maak ik ontwerp, art,
animaties, geluid, NL/EN, implementatie en controle zelf af en publiceer ik op
de Claude-branch zonder force-push. Vergelijk eerst de actuele remote met
de lokale basis; behoud werk van Claude. Controleer visueel en test met
afzonderlijke saves. Elke fase krijgt een speelbare versie en succesvolle Windows-CI.

De wereld krijgt ruimte door nieuw terrein, niet door de bestaande routes
weer te vullen. Overgangen en uitzicht mogen rustig blijven. Nieuwe vijanden
krijgen beperkte leefgebieden. Geen dagelijkse onderhoudsdruk, verplichte grind,
lange bootanimaties of lange wachttijden bij getijde.

## 1. Eerste kustexpeditie — uitgevoerd in 0.20

Een hele kleine complete reis: een rustige kustkaart, één eiland en veilige
heen- en terugvaart tussen aanlegplaatsen. Aansluiting via een optioneel
oostelijk pad bij het Zilvermeer. Eigen landschap, boot, animaties en muziek.
Geen vijanden, beloningskisten of verplichte verzamelopdracht in deze eerste fase.

De kust is 58×36 en Meeuweneiland 48×36 tegels. Wandelpaden, strand en gras bieden
verschillende routes; het uitzichtpunt is optioneel. De boot heeft een gratis
presentatie van 2,2 s, een knop om meteen aan te komen en een knop om af te breken.
Voor vertrek controleert het spel opnieuw aanlegplaats, afstand en bestemming.
Kaartwisseling gebruikt bestaande aankomstbescherming, veilige voetplaatsing en save.
Lopen naar de aanlegplaats en bootvaart worden echt getest. Oude kaartslots,
saves, voltooid spel, native muis en gesimuleerde controller/toetsen blijven werken.

**Klaar wanneer:** nieuwe-speler en bestaande speler kunnen lopen naar de kust,
heenvaren, het eiland verkennen, terugvaren en teruglopen; zonder vastlopen,
dubbele transacties of nieuwe druk op Bosrand/bosroute. Drie schermformaten,
NL/EN, dag/nacht/weer en volledige regressiesuite plus Windows-export gecontroleerd.
Opgeleverd: de heen- en terugreis slaagt met echte loopbeweging, toetsen, native
muis en gesimuleerde controller. De directe kustwandeling duurt 12,2 s.
Alle 49 tests slagen; 2.300 Engelse teksten volledig. Fase 2 is hieronder uitgevoerd.
Details en bewijs: COAST_EXPEDITION.md.

## 2. Reizen en regionale spelregels — uitgevoerd in 0.21

Bestemmingskeuze en route-informatie uitwerken. Getijde eerst op één aparte
testkaart, met altijd een veilige route of eenvoudige uitweg. Een functionele
landingslijn of vergelijkbaar hulpmiddel kan een korte alternatieve route openen.
Geen resourceverlies als de speler afbreekt. Vrij varen eerst in een afzonderlijk
proefstuk met toetsen/controller; alleen verder bouwen als het prettig en helder werkt.
De huidige automatische veer blijft een betrouwbare terugweg.

**Klaar wanneer:** getijde nooit een save of terugreis blokkeert, het hulpmiddel
een echte keuze geeft en ontbrekende eisen vooraf duidelijk zijn.

Opgeleverd: één aparte Getijdenbaai (52×36), hoge looproute zonder eisen,
waarschuwing voor opkomend water en veilig sluiten van de lage zandbank.
Een aanwezige wandelaar mag eerst de oever bereiken; hervatten op een inmiddels
overstroomde plek gebruikt de bestaande veilige voetplaatsing op droog land.
De gratis leenlijn werkt aan beide oevers, met een korte afbreekbare animatie.
Reisborden bieden echte bestemmingen met vooraf route-informatie. Het getijde
loopt op de bestaande opgeslagen wereldklok en pauzeert met menu's.
De afzonderlijke proefhaven heeft sturen, remmen, boeien en botsingen; geen
wereldvaart of vervanging van de veer. Eerst feedback voordat vrij varen groeit.
Eigen kaart/props/icoon; bestaande eigen kustmuziek en lijn-/watergeluiden.
Controle en grenzen: TIDAL_ROUTES.md. Fase 3 is hieronder uitgevoerd.

## 3. De regio ruimte geven — uitgevoerd in 0.22

Uitbreiden naar in totaal zes tot acht samenhangende kaarten, na beoordeling
van de eerste expeditie. Ontwerprichting: riviermonding, kustpad, kleine haven,
getijdenstrand, verschillende eilanden en vuurtoren. Eerst routes en
landschappelijke functie tekenen; daarna beperkte ontmoetingen plaatsen.
Een kleine haven krijgt hooguit enkele betekenisvolle bewoners in de eerste versie.
Het doel van circa 30–50% meer beloopbaar terrein is richtinggevend,
geen eis om lege kaarten of extra omwegen toe te voegen.

**Klaar wanneer:** plekken herkenbaar verschillen, reisroutes leesbaar zijn
en elke drukke plek een rustige aanloop/terugweg heeft.

Opgeleverd: de kustregio telt nu zes kaarten. Zilvermonding (76×46),
Rietwenk Haven (74×46) en Lichtkaap (76×46) voegen 6.529 terreinvloertegels toe;
de optionele noordelijke aansluiting aan de kust nog vier. Dat is ongeveer
38,6% meer statische vloer ten opzichte van 0.21, vóór gebouwen/overige bezetting.
De twee werkplekken en vuurtoren hebben echte voetafdrukken. De oude meerroute,
Bosrand, eilanden en getijdenproef worden niet voller gemaakt.

De haven heeft alleen Ise (werkende veerkeuze) en Raf (regiokaart), beide met eigen
art en werkbeweging. Geen extra opdrachten, vijanden, kisten of verzamelplaatsen.
De rivierbrug en het pad naar de kaap zijn zonder eisen heen en terug te lopen.
Een oversteek naar de haven voorkomt verplichte lange herhaalwandelingen.
De regiokaart toont wandelverbindingen, de gekozen veerroute en gebiedsinformatie.
Eigen exterieurs/landschap, lichtbundel en rustige animaties; camera geeft hoge
gebouwen meer ruimte en reset bij vertrek. Bestaande slots en saves behouden.
Controle: COASTAL_REGION.md. De volgende go start alleen fase 4.

## 4. Eigen avonturen, monsters en challenges — volgende fase

Vier tot zes verschillende verhaallijnen met onderzoek, navigatie, een
herstelhandeling, een keuze met zichtbare gevolgen en een bijzondere ontmoeting.
Geen nieuwe reeks van “haal drie spullen, versla vijf vijanden”.
Twee of drie regionale vijandpatronen met eigen assets en aangekondigde aanvallen.
De eerder geplande grotuitstapjes passen hier alleen als hun ingangen en routes
ruimte hebben. Een tweede grot mag vervallen; geen kopie van spiegels of klankschalen.

**Klaar wanneer:** doelen verschillende handelingen vragen, gevolgen begrijpelijk
zijn en solo/gecombineerde gevechten, waarschuwingen en rustzones getest zijn.

## 5. Beroepen, uitrusting en terugkeerplek

Gebruik de bestaande zeven beroepen. Eerst drie tot vijf streekmaterialen,
gerichte recepten en twee duidelijke gearkeuzes in bestaande slots.
Nieuwe tools openen specifieke routes. Een kleine werkplaats met opslag/inrichting
kan een praktische terugkeerplek worden, met vaste meubelplaatsen als veilige start.
Samenwerking met bestaande bewoners verbindt oude en nieuwe regio's en houdt
de oorspronkelijke wereldgevolgen als ontwerpdoel.
Twee nieuwe vechtstijlen alleen na een zelfstandig geteste proefversie;
nieuwe wapens moeten een andere aanpak bieden, niet alleen hogere getallen.

**Klaar wanneer:** kosten, gearafwegingen, opslaan, afbreken en bestaande
craftregels kloppen; oude uitrusting blijft bruikbaar.

## 6. Het grotere avontuur als geheel

Nieuwe-spelroute, hervatten van oude en voltooide saves, terugkeer naar oude
bewoners, optionele routes en wereldgevolgen controleren. Meet framekosten,
geheugen, kaartwissels en audio/startup; laad lange tracks gericht als metingen
dat nodig maken. Werk versionering, NL/EN, menu's en Windows-distributie bij.
Los werkelijk gevonden problemen op; voeg geen content toe om de fase te vullen.

**Klaar wanneer:** een coherent getest avontuur, passende rust en variatie,
succesvolle Windows-CI en duidelijke grenzen aan wat werkelijk gecontroleerd is.
Na fase 6 volgt eerst een beoordeling en een nieuw plan.

## Vast kwaliteitsniveau

Eigen en reproduceerbare art/audio, bestaande bindings en exclusieve invoerwisseling.
Controle op 960×540, 1152×648 en 1600×900; geen begraven waarschuwingen,
panelen buiten beeld, props op looproutes of onbedoelde overlap in de geteste scènes.
Geen echte spelerssave gebruiken; geen claim over fysieke controllers,
alle resoluties of extra speeltijd zonder die te meten.
