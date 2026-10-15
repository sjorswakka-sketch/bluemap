# Deuren en gebiedsovergangen — 0.26.1-preview

Alle 67 standaarddoorgangen in de 36 gebieden zijn gecontroleerd op een fysiek begaanbare route, echte spelerbeweging, bestaande doelkaart en expliciet aankomstpunt. Aankomsten moeten vrij zijn van muren, objecten en teruggaande portaalvlakken. Een half-tile zoekraster gebruikt de echte voetvorm en Godots botsingsdetectie; het kijkt dus verder dan alleen vloer- en muurtekens.

## Wat is hersteld

Een rolbeweging kon bij een lange framepauze volledig over een smalle ingang gaan, waardoor alleen de twee eindposities werden gezien en de overgang niet afging. Een korte, natuurlijke bewegingslijn wordt nu tegen het binnenvlak gecontroleerd. Langs een rand of hoek scheren is geen binnenkomst. Een verplaatsing zoals snelreizen activeert geen tussenliggende deuren. De bestaande voorwaarden blijven ook voor deze controle gelden.

Overgangen stoppen nu een actieve rol, aanval, terugslag en werkbeweging. Dit geldt bij gewone gebiedsovergangen, direct laden en snelreizen binnen dezelfde kaart. De loopbediening en cooldowns blijven behouden. Deurgeschiedenis wordt tijdens een overgang of menu vernieuwd; aankomen binnen een portaal veroorzaakt geen onmiddellijk terugstuiteren.

## Duidelijker toegang

Een enkele rustige hint noemt dichtbij de bestemming en vertelt dat je doorloopt. Een nog gesloten ingang toont de bestaande uitleg. Gesloten portalen gloeien amber; beschikbare portalen houden de blauwe gloed. Ongebruikte woongevels worden als gesloten benoemd en beloven geen nieuw interieur. Die melding is ook vanaf de vrije grond vóór een laag hek leesbaar.

Hints verschijnen alleen in je kijkrichting, met zicht op de ingang. Muren schermen ze af. Een personage of ander interactiedoel heeft voorrang. Menu's, overgangen, kaartbanners en lopende meldingen krijgen ook voorrang. Het paneel past zich aan Nederlands/Engels en kleine vensters aan. Bij een camera aan de kaartrand verplaatst het zich zo nodig omhoog, zodat het personage zichtbaar blijft.

De kaartindeling, objectvolgorde, poorten, sleutels en ontgrendelvoorwaarden zijn behouden. Bestaande veer-, werkplaats- en snelreisbediening blijft werken. De overige woning-, landbouw-, productie- en irrigatiesystemen blijven ongewijzigd.

## Controle

De extra regressietest tests/access_points_test.gd controleert alle 67 geometrische routes en loopt ze vervolgens echt door. De geometrische loopronde opent alleen in de geïsoleerde test de fysieke poorten en portaalvoorwaarden, zodat iedere doorgang kan worden bezocht. De oorspronkelijke spelvoorwaarden worden aanvullend door bestaande verhaal-, arena- en gebiedstests gecontroleerd. Losse regressies controleren een lange framepauze, een rakende rand, een verre verplaatsing, gesloten/geopende voorwaarden, aankomst zonder terugstuiteren en het stoppen van beweging.

De interface wordt op 960×540, 1152×648 en 1600×900 in Nederlands en Engels gecontroleerd. tools/preview_access.py maakt 36 beelden van zes ingangen. tools/run_tests.py gebruikt een afzonderlijk project met geverifieerde UUID-save; echte spelerssaves worden niet gebruikt. Controllerbediening wordt met native events getest; er is geen fysieke controller met de hand getest.
