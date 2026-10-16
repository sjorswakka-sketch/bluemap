# Voorraad en opslag — fase 2 / 0.29.0-preview

Twee zelf getekende, 32px kisten: binnen in het eigen huis op (10,5) en naast het erfpad op (9,26); beide openen dezelfde huisvoorraad. Geen tegel, doorgang, tuinveld, vijand, waterbron of bestaande objectindex verandert. De nieuwe objecten zijn achteraan toegevoegd.

## Spelen
- Open een kist met de gebruikelijke interactie, of open **Voorraad** boven in de tas; de ingestelde Beroepen-toets werkt in het tasmenu ook als sneltoets (standaard C / rechterstick indrukken).
- Zoek op vertaalde naam of itemcode, kies een categorie, sorteer op gevonden volgorde/categorie/naam/aantal en markeer favorieten; sorteren en sterretjes gelden ook voor de gewone tas.
- Verplaats 1, 10 of de hele stapel; bevestigen in een lijst verplaatst 1. Aanvullen vult alleen bestaande soorten aan. Grondstoffen opbergen verplaatst materialen. Beide bulkacties slaan favorieten over.
- De huisvoorraad bewaart maximaal 48 soorten, elk 999 stuks; de bestaande havenkist behoudt 12 soorten, elk 99 materialen.
- Materialen, voedsel/drank en pijlen kunnen thuis worden bewaard. Gereedschap, gear, kleding, permanente bonussen, sleutels en verhaalvoorwerpen blijven bij je.
- Binnen 176px van een huiskist gebruiken recepten eerst de tas en daarna deze kist; beide wijnvaten vallen binnen dit bereik. De mesthoop staat verder weg en heeft meegenomen poep nodig. Binnen 96px van de havenkist telt die lokale materiaalvoorraad mee.
- Receptniveau, ontgrendeling, werkplaats en outputlimiet blijven vereist. Favorieten zijn beschermd tegen bulkopslag, maar een expliciet gekozen recept mag ze gebruiken. Gereedschap voor veldwerk en consumptie blijven in de tas nodig.
- Op afstand kun je thuisvoorraad bekijken, zoeken en plannen, maar niet verplaatsen of gebruiken. Er is geen extra onderhoud of dagelijkse verplichting.

## Bediening en beeld
Eigen deterministische pixeltekening in tools/art_x_storage.py: hout, doffe groene banden en twee dekselstanden; de kleine collision laat de bestaande routes vrij. Het rustige voorraadscherm heeft twee lijsten, exacte aantallen en expliciete richting/bereik. Native focus, muis, toetsenbord en controller; de knop Letters biedt een controlleralfabet. Het volledige venster past op 960×540, 1152×648 en 1600×900. NL/EN aanwezig.

## Techniek en controle
Stockroom bewaart eigen genormaliseerde savegegevens; oude saves krijgen lege opslag, favorieten en standaardvolgorde. Overzetten en bulkacties valideren eerst, schrijven beide kanten vóór signalen en blokkeren herhaalde synchrone transacties. Te grote stapels, onbekende IDs, NaN, negatieve aantallen en permanente gear worden geweigerd of begrensd. Overschot blijft in de tas.

Nieuwe suites stockroom_test en stock_ui_test controleren echte transacties, bewaren/herladen, nieuwe spellen, caps, favorieten, bronafstand, recepten/werkplaatsen, beide wijnvaten, bestaande havenopslag en native invoer/venstergroottes. De bestaande volledige suite blijft onderdeel van elke uitgave. tools/preview_storage.py maakt geïsoleerde, echte Godot-beelden en een wereldruimte-audit zonder de spelerssave te openen.

Fase 3 blijft meubelplaatsing en persoonlijke woningafwerking; vrij plaatsbare kisten, productiequeues en extra erfgebouwen vallen buiten deze ronde.
