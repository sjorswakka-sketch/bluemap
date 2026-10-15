# Meldingen, moerassluizen en zuidelijke meeruitgang — 0.28

Aanvullende bugmelding van sjors/Exodus2045, meegenomen vóór de publicatie van de grafische ronde.

- Itemontvangsten gebruiken nu een begrensde feed rechts onder de opdrachtinformatie, in Nederlands en Engels. Ze nemen geen invoerfocus over en wachten niet in de centrale meldingenrij. Menu’s bewaren hun resterende leestijd.
- De bestemming en voorwaarden van een nabije doorgang verschijnen onmiddellijk op de bestaande centrale plek, ook tijdens andere meldingen of gebiedsbanners. Gewone meldingen hervatten zodra je wegloopt; de tuinhint wijkt voor doorgangsinformatie.
- De westelijke moerasbrug liep oorspronkelijk slechts over x=18..22, terwijl x=16..17 water bleef: het volledige tweebrede dek loopt nu van de westelijke landing naar het eiland (x=16..22, y=16..17). De westelijke geul blijft na drainage water, zodat repareren een echte kortere route oplevert.
- Sluizen hebben zichtbare schuivende hekken, open/dichtlabels, peilschalen en lokale stroming. Het juiste resultaat legt een bredere oostelijke slikoever bloot; water trekt kort zichtbaar terug en de bestaande archiefingang krijgt herkenbare verzonken treden. De bestaande puzzel, materialen, beloningen en questvlaggen blijven leidend.
- Afgeronde oude saves tonen dezelfde veilige sluisstanden als nieuw opgeloste saves; brug, laagwater en terugkeer naar het archief blijven na laden correct.
- Op bevestiging van sjors gaat het om **Zilvermeer / Silver Lake**: de bestaande dorpsportal verplaatst van [19,26] naar [19,42] aan de zuidrand van het vergrote dorp. Het blijft één gratis toegankelijke verbinding, met veilige terugkomst op [19,40]. Het pad sluit aan onder de woning; een licht uitgesleten grasstrook behoudt alle bewerkbare tuin- en kanaalcellen.

`notifications_waterworks_test.gd` controleert directe doorgangstekst met volle meldingen, de zijfeed op drie venstermaten in beide talen, menupauze, de echte klepvolgorde, volledige brugoversteek met echte beweging, save/load en lopen door de nieuwe meeruitgang. Bestaande meer- en thuistests zijn aangepast aan de uitdrukkelijk gevraagde nieuwe locatie. `preview_bugfix.py` rendert hoogwater, beide klepstanden, laagwater, brug, bediening, zijfeed en de zuidelijke route in een geïsoleerde kopie.

Deze gerichte wereldwijzigingen komen boven op de grafische laag. Alle overige kaarten, oude media, opgeslagen verzamelobjectslots en overige overgangen blijven behouden.
