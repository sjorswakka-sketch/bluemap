# Een uitbreidbaar erf — fase 4, 0.31.0-preview

Open buiten **U → Erf inrichten**, of kies het bij de bestaande tuingids.
Je maakt een gepauzeerd ontwerp; **Toepassen en opslaan** bewaart het, **Annuleren**
laat je huidige indeling staan. LB/RB wisselt tussen lijst en plattegrond,
richtingstoetsen of stick verplaatsen de cursor, A/Enter plaatst. Met de muis:
klik kiest een tegel, dubbelklik plaatst, rechtsklik selecteert wat er staat.
De achterkant van het huis heeft een aparte kaartweergave.

## Wat er gebouwd is
- De twee bestaande wijnvaten, mesthoop en bijenkast kunnen verhuizen of worden
  opgeborgen. Hun vaste productie-ID en inhoud veranderen niet. Opgeborgen
  wijn/compost rijpt verder tijdens actief spelen; verzamelen vereist de geplaatste
  werkplek. Opgeborgen bijen pauzeren met behoud van honing en voortgang.
- Bijen gebruiken drie daadwerkelijk bloeiende planten binnen vijf tegels van hun
  huidige kast. Verhuizen neemt geen wilde bloemen mee.
- Drie eigen aansluitende pixelpaden: grind, stapstenen en hout. Dezelfde 1,2×
  padsnelheid als bestaande wegen, met passende voetstappen. Hout is voor droge grond.
- Zelfgetekende lage hekken en poortjes in twee richtingen. Poorten openen van
  beide kanten binnen 64 pixels, sluiten buiten 82 pixels, met een korte animatie
  en zelfgemaakte zachte houtklank. Ze behoeven geen interactieknop.
- Vierentwintig grinddelen, twaalf hekdelen en twee poorten als vrije startvoorraad.
  Meer delen maken kost steen, hout of takken uit je tas en echt bereikbare
  huisvoorraad. Opbergen geeft gebruikte bouwdelen weer vrij, zonder nieuw materiaal.
- Rechte rijen zijn in één handeling te plaatsen. Een hele rij moet passen en
  betaalbaar zijn; anders wordt niets geplaatst.
- Westweide (6 hout + 6 steen) en Oeverweide (8 hout + 8 steen) ontsluiten optioneel
  bouwruimte in bestaande open weiden. Landbouw blijft vóór het ontsluiten volledig
  beschikbaar. Kleine hoekstenen markeren gekochte rechten zonder terrein te blokkeren.

## Ruimte en veiligheid
Alle 36 kaarten, tilematen, oorspronkelijke objectvolgorde, deuren en aankomstpunten
blijven gelijk. Er staan standaard geen extra machines of hekjes. De beekbruggen,
de zuidelijke meerroute, het woningpad, tuingids en voorraad blijven bereikbaar.
Nieuwe productieplekken hebben drie bij drie tegels zichtbare ruimte en één tegel
afstand tussen werkplekken. Bestaande gewassen en kanalen worden nooit overschreven.
De originele plekken blijven compatibel met bestaande tuinen; terugplaatsen op een
inmiddels bewerkte oude plek wordt geweigerd.

De editor staat maximaal tachtig padtegels en veertig hek-/poortdelen toe. Een
bereikbaarheidscontrole over het volledige erf weigert afgesloten stukken zonder
poort of opening. Botsingen met de speler worden vóór toepassen gecontroleerd.
Gemaakte bouwdelen en gekochte rechten zijn expliciete voorraadwijzigingen:
ze blijven ook na het annuleren van een ontwerp beschikbaar.

Opslag bevat de hele indeling en opgeborgen machines. Oudere saves krijgen de
oorspronkelijke vier werkplekken en vrije startersdelen. Ongeldige opgeslagen
inrichting wordt veilig gefilterd; gewassen, kanalen, productiebatches, huis en
inventaris worden niet weggenomen.

## Controle
Twee nieuwe integratiesuites controleren erf, echte productie, lokale materialen,
save/load, bestaande landbouw, rijplaatsing, annuleren/toepassen, muis/controller en
echte beweging door beide poorttypen. De volledige bestaande testsuite draait mee.
De geïsoleerde preview levert Nederlandse en Engelse menubeelden op drie venstermaten,
plus dorps-, tuin-, poort- en bijenkastbeelden. Geen echte spelersave wordt gebruikt.
De kaart-audit wordt vergeleken met 0.30; nieuwe art en audio zijn reproduceerbaar uit
tools/art_x_yard.py. Publicatie bouwt een Windows-pakket via de bestaande CI.

## Volgende ronde
Fase 5: onderscheidende gewassen, kruiden, fruitbomen en struiken. Nieuwe
productiemachines, dierenverblijven en grotere huizen horen bij latere rondes;
fase 4 legt daarvoor de vrije bouwruimte en plaatsingsbediening klaar.
