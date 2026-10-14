# Ruimte en rust op de eerste route — 0.17

De gebruiker vroeg om een kleinere wereld niet vol te stapelen met ontmoetingen.
De tweede ronde begint daarom met ruimte en reisritme. De twee geplande nieuwe
ontmoetingen zijn geschrapt. Er zijn geen nieuwe quests, bewoners of beloningen.

## Audit en keuze

`tools/world_space_audit.gd` leest de actuele verrijkte kaarten, de eerste-route
vijandverplaatsingen en beroepsobjecten. De JSON telt vaste kaartdata, geen
tijdelijke vijandgolven, bewegende bewoners of colliders. Aantallen zijn een
signaal voor nadere routecontrole, geen automatische dichtheidsscore.

| Gebied in 0.16 | Belangrijkste bevinding |
| --- | --- |
| Dageraadsdorp, 40×28 | 596 beloopbare terreintegels en 12 vaste NPC-slots; daarnaast Nelle en Bo. De dorpsuitgang ging rechtstreeks naar het bos. Elke stond midden in de smalle zuidelijke straat. |
| Fluisterbos, 54×38 | 1.383 beloopbare terreintegels, 26 vijandplekken; altaar, westelijke hinderlaag, oefeningang en meerdere borden zaten dicht bij de aankomst. |
| Zilvermeer, 44×32 | 682 beloopbare terreintegels, 4 vijanden aan de rand. Vissen, keukenverhaal en bibliotheek hebben al verschillende plekken. Geen reden om hier nieuwe ontmoetingen te plaatsen. |

Ook de andere bestaande kaarten zijn in dezelfde JSON opgenomen, zodat volgende
fases vanaf echte aantallen beginnen. De ingreep van deze fase blijft gericht
op de eerste route; dit is geen volledige balansbeoordeling van alle streken.

## Wat veranderde

- De **Bosrand** is een eigen, zelf ontworpen kaart van 44×24 met 520 beloopbare
  terreintegels. De weide vernauwt naar bos; een vijver heeft rustige bewegende
  kringen. Alleen twee doorgangen en twee wegwijzers. Eigen bestaande pixeltiles,
  eigen kaartsamenstelling en getekende animatie; geen externe assets.
- De gemeten terreindoorgang van westelijke naar oostelijke aankomst kost
  **11,2 seconden** normaal lopen met standaarduitrusting, via het pad.
  Met andere gear, sprinten of rondkijken verschilt dat. Bestaande altaren blijven
  beschikbaar voor later snel reizen; geen extra verplicht rustpunt.
- Het Fluisterbos krijgt **18 in plaats van 26** vaste vijandplekken. Uitgeschakelde
  slots blijven in de data staan; indexen van kisten en unieke pickups verschuiven niet.
  Beide nieuwe gevechtssoorten en gevechten verderop blijven aanwezig.
- De westelijke struikhinderlaag verhuist naar een zijplek; een slijm ligt verder
  van het altaar. De oefeningang verhuist vijf tegels zuidwaarts op zijn bestaande
  zijpad; terugkeer en doorgang volgen die plek. Eén dubbel bord bij de aankomst vervalt.
- Elke stapt naast de zuidelijke dorpsstraat. Andere dorpsactiviteiten en de
  indeling/inhoud van het Zilvermeer blijven behouden.
- Normaal rondzwerven in bos/meer stuurt vijanden terug richting hun beginplek.
  Gewone jagende slijmen volgen niet verder wanneer de speler meer dan 160
  wereldpixels van hun beginplek is. Geen genezing of respawn bij terugkeer.
  Andere speciale aanvallen houden hun eigen regels; deze fase maakt geen
  onzichtbare veilige zone die alle schade verhindert. Bazen en dynamische
  oefen-/trialvijanden hebben deze instelling niet.
- Portaalgrafiek, opgeslagen opdrachtkeuze en volgende-doorgangmarkering gebruiken
  de echte nieuwe verbinding. Wegwijzers en gebiedsnaam zijn in NL/EN beschikbaar.

Ter vergelijking: van twaalf meetpunten op de hoofdweg tussen
kolommen 4–15 zaten eerst twaalf binnen 140 pixels van een vaste vijandplek; nu
nul. In kolommen 16–27 daalt dat van elf naar drie. Dit is een **geometrische
beginsituatie zonder zichtlijnen**, geen voorspelling van daadwerkelijke aggro.
De echte westelijke wandeling wordt daarom afzonderlijk met actieve vijanden getest.

## Controle en grenzen

`world_space_test` loopt de nieuwe overgang in beide richtingen met echte
spelerbeweging en botsingen, gebruikt echte portaalovergangen en test de
westelijke boswandeling zonder invulnerability. Hij controleert doelroutes,
behouden objectslots, de achttien vijanden, vrije vloer, territoriumgedrag zonder
gratis genezing, echte save/load in het nieuwe gebied en oude verzamelflags.
De hoofdverhaaltest loopt nu via de Bosrand heen en terug. De doorgangstest
controleert werkelijk aanwezige borden, niet uitgeschakelde data-slots.

Bij de visuele review zat de kaarttitel te dicht op de kolomcoördinaten.
Alleen de kaarttitel staat nu iets hoger, met ruimte onder de tabknoppen en
boven de coördinaten; het kaart- en reispaneel houden hun afmetingen.

De verplichte volledige suite en Windows-CI horen bij publicatie. Visuele review:
dorpsplein vóór/na herstel, bosingang en brugroute, meer, bosrand/weide/vijver,
avond/nacht/regen, NL/EN-kaart met doelroute en 1152×648, 960×540, 1600×900.
Controllerinput wordt in de bestaande suite gesimuleerd; een fysieke controller
en alle mogelijke resoluties zijn niet getest. Geen claim dat iedere toekomstige
positie van een rondlopende vijand even veilig is. De vastgestelde rustige
route en beperkte nieuwe inhoud zijn de basis voor de volgende fases.
