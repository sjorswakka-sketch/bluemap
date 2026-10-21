# Inventaris, buit en opslag in Unity

**Fase 12 is gecontroleerd en gepubliceerd.** De tas, magnetische pickups, kisten en opslag werken samen in de bestaande Unity-avonturen; de wereld behoudt dezelfde 37 kaarten en 49.758 tegels.

De oorspronkelijke 226 itemsoorten en hun eigen stapellimieten blijven behouden. De tas heeft geen afzonderlijke limiet op verschillende soorten. Alle voorwerpen worden aangetrokken, ook hartjes en volle stapels die pas worden opgepakt zodra er ruimte of behoefte is. Kisten verwerken alle beloningen en de unieke vlag samen; herhaald openen geeft geen dubbele spullen en reeds bezeten unieke uitrusting blokkeert andere beloningen niet.

De voorraadkist staat binnen de woning. Thuis zijn er 144 soorten met maximaal 999 per stapel; de kustwerkplaats bewaart 12 soorten materialen met maximaal 99 per stapel. Op afstand blijft de opslag alleen leesbaar. Overzetten per 1, 10 of stapel en grotere materiaalhandelingen bewaren de totale voorraad; favorieten blijven bij bulkoverzetten bij je.

De tas toont zes kolommen met 24 vakken per pagina; de opslag heeft twee lijsten. Zoeken, categorieën, vier sorteervolgordes en favorieten werken met toetsenbord, muis en controller. De rechterstick houdt de geselecteerde rij zichtbaar, schouderknoppen kiezen bedieningsonderdelen en zoeken met een controller heeft eigen letterkeuze. Grotere overzettingen vragen een bevestiging. Eten, drinken en potions volgen de bestaande herstelregels zonder verspilling bij volle waarden. Volledige gearbediening volgt in fase 13.

Itemmeldingen staan afzonderlijk rechts van de directe locatieberichten. De vier meldingen behouden ieder hun eigen 4,5 seconden en pauzeren tijdens menu’s en gesprekken. De kist gebruikt het oorspronkelijke open/dicht-beeld en loot gebruikt de bestaande itemafbeeldingen; er zijn geen extra wereldobjecten toegevoegd.

## Controles

De oorspronkelijke Godot-methoden zijn tweemaal uitgevoerd met eigen tijdelijke UUID-opslag: 304 gedragsgevallen, 226 items, 71 consumables en buit uit alle 162 geladen wereldtoestanden. Het broncontract vergelijkt stabiele sleutels, inhoud en posities met de bewaarde kaarten. Alle 34 opslagvelden en onbekende toekomstige velden blijven behouden.

De echte Windows-speler slaagt voor 37 algemene controles, 119 spelbasis-, 69 speler-, 115 opslag/import-, 73 route-, 57 wereld/toegangs- en 44 inventariscontroles. De bouw geeft nul fouten en waarschuwingen. De oorspronkelijke Godot-regressie slaagt voor 18 suites / 2109 controles. De Python-suite bevat 548 tests, nul fouten/mislukkingen en 2 Windows-symlinkskips; die gevallen blijven actief in Linux CI.

Daarnaast zijn 13 gerichte controles voor exacte getallen en de oorspronkelijke voorraadvolgorde geslaagd; deze draaien ook expliciet in GitHub. Na de laatste sneltoetskoppeling zijn de 106 betrokken pakket- en broncontracttests opnieuw geslaagd.

Vier nieuwe native screenshots tonen tas, thuisopslag, kustopslag en controllerlijsten. NL/EN wordt ook op 960×540 en 1152×648 gecontroleerd. De controllerproeven gebruiken echte virtuele gebeurtenissen via het Unity-invoersysteem; fysieke controllerhardware is niet met de hand getest. Alle testprofielen zijn synthetisch. Persoonlijke saves zijn niet geopend of gepubliceerd.

## Download en grenzen

[Download de fase 12-proef](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase12-preview-40b4af28). Broncommit `40b4af28919873e322ff1711822781fd807c4dec`, invoerfingerprint `63bd33dc0c218dea7dc16bbd767a7cf7cf95ea32d3ce3ea7b3816efafb18c322`. Unity 6000.3.26f1, Windows x64 / Mono. ZIP: 70,871,793 bytes / 154 bestanden; SHA256 `ed0853e0549843963ae8627654874411d9e41b387ec737bab8589a4cb490e7dc`.

Alle 45 publieke bestanden, inclusief 33 screenshots en alle eerdere rapporten, zijn onafhankelijk opnieuw gedownload en gecontroleerd. GitHub controleert bron en download; de Unity-speler is lokaal gebouwd met de vaste editor. Ruwe logs, testprofielen en activatiegegevens blijven buiten de release.

De volledige port is nog niet klaar. Ervaring, volledige uitrusting en uiterlijk volgen in fase 13; gevechten, alle quests, beroepen, landbouw en productie blijven hun eigen volgende fases. De Godot-game, oorspronkelijke Claude-branch en herstelbestanden blijven behouden.
