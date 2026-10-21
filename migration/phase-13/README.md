# Ervaring, uitrusting en uiterlijk in Unity

**Fase 13 is gecontroleerd en gepubliceerd.** De bestaande Unity-avonturen hebben hun oorspronkelijke heldervaring, uitrusting, upgrades en persoonlijke uiterlijk terug. De rustige indeling van de 37 kaarten en 49.758 tegels blijft behouden.

Heldervaring volgt de oorspronkelijke grenzen en beloningen; levels geven de bestaande muntenbeloning. De bron bepaalt schade, hartjes en voorwaarden. Alle 24 uitrustingsstukken over 5 vakken worden afzonderlijk van bezit behandeld: alleen werkelijk gedragen gear geeft de oorspronkelijke bonussen. Wisselen of verliezen van een helm begrenst stamina zonder gratis energie bij te vullen.

Het overzicht en de uitrustingsschermen tonen de werkelijke waarden en vergelijken kandidaatvoorwerpen. Wapenniveaus en de 3 gear-upgrades volgen oorspronkelijke materialen, vaardigheid, verdiende vlaggen en werkplekken. De smid controleert de volledige prijs opnieuw; annuleren, alleen kijken, onvoldoende materialen of buiten bereik staan geven geen gratis upgrade. Het verdiende Sterrenzwaard krijgt geen verzonnen kooproute.

Er zijn 90 oorspronkelijke haarstijlen, 16 oogvormen en 24 kledingstukken over 5 cosmetische vakken. Haar-, oog- en verftabellen blijven dezelfde. De zichtbare lagen volgen de bron; cosmetische kleding verandert geen spelbonussen. Toetsenbord, muis en controller kunnen de schermen bedienen, inclusief lange lijsten en bevestigingen. De gekozen uitrusting, kleuren en kleding blijven na bewaren en laden behouden.

## Controles

De originele Godot-methoden zijn tweemaal op Windows en onafhankelijk tweemaal op Linux uitgevoerd met eigen tijdelijke UUID-opslag: 442 gedragsgevallen, 6580 exacte Float64-waarden en 39 bronmethoden. Het contract bindt 144 originele bronbestanden, de catalogi, Greta’s kosten en acties, de oorspronkelijke dictionaryvolgorde en alle 34 opslagvelden. Onbekende toekomstige velden blijven behouden.

De echte Windows-speler slaagt voor 38 algemene controles, 119 spelbasis-, 69 speler-, 115 opslag/import-, 73 route-, 57 wereld/toegangs-, 44 inventaris- en 32 voortgangscontroles. De bouw geeft nul fouten en waarschuwingen. De oorspronkelijke Godot-regressie slaagt voor 24 suites / 2656 controles. De Python-suite bevat 589 tests, nul fouten/mislukkingen en 2 Windows-symlinkskips; die gevallen blijven actief in Linux CI. De 13 aanvullende exacte voorraadbewakers blijven ook verplicht in CI.

Vier nieuwe openbare native screenshots tonen overzicht, uitrusting, uiterlijk en upgrades. Daarnaast worden NL/EN-layouts op 960×540 en 1152×648 visueel beoordeeld. Controllerproeven gebruiken echte virtuele gebeurtenissen via Unity; fysieke controllerhardware is niet met de hand getest. Alle testprofielen zijn synthetisch; persoonlijke saves zijn niet geopend of gepubliceerd.

## Download en grenzen

[Download de fase 13-proef](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase13-preview-f15a1641). Broncommit `f15a16411d9264730e5db35f759c1ce46424bd04`, invoerfingerprint `4cd2ed4b866f527a9b9cd7ef9fab0f0d1096f35823948d93686b094009ac72cd`. Unity 6000.3.26f1, Windows x64 / Mono. ZIP: 71112245 bytes / 155 bestanden; SHA256 `435cea60ababedb61a7469c48e22150cc6c82d20c05f156914b14b68f49c4f05`.

Alle 50 publieke bestanden, inclusief 37 screenshots en alle eerdere rapporten, zijn onafhankelijk daadwerkelijk opnieuw gedownload en gecontroleerd. GitHub controleert bron en download; de Unity-speler is lokaal met de vaste editor gebouwd. Ruwe logs, testprofielen, caches en activatiegegevens blijven buiten de release.

De volledige port is nog niet klaar. Het volgende go start fase 14: gevechten, monsters en wild. Alle quests, beroepen, landbouw en productie volgen in hun eigen fases. De Godot-game, oorspronkelijke Claude-branch en herstelbestanden blijven behouden.
