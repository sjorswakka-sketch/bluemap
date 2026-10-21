# Downloads van BlueMap Quest

| Wat wil je openen? | Download | Inhoud |
|---|---|---|
| De volledige bestaande game | [Godot 0.34.0-preview](https://github.com/sjorswakka-sketch/bluemap/releases/tag/godot-baseline-0.34.0) | Bestaande game, oorspronkelijke wereld en systemen; bron en herstelgeschiedenis inbegrepen |
| De actuele technische Unity-preview | [Fase 12 — 40b4af28](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase12-preview-40b4af28) | Tas, magnetische buit, veilige kisten, thuis- en kustopslag, zoeken, sorteren en favorieten; nog geen volledige gameport |
| De eerdere wereldproef | [Unity-fase 11](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase11-preview-0e7d75f8) | Alle 37 gebieden en toegangspunten, oorspronkelijke questsloten en veilige voortgang |
| De eerdere eerste speelroute | [Unity-fase 10](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase10-preview-712b2e02) | Dorp, woning, bosrand en bos met Pim en Muis, verzamelen, buit en inventaris |
| De eerdere opslagproef | [Unity-fase 9](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase9-preview-343f8564) | Veilige import, instellingen, aparte Unity-profielen en herstel |
| De eerdere bewegingsproef | [Unity-fase 8](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase8-preview-3f604417) | Speler, rennen, stamina, rollen, richten, camera en toetsenbord/controller |
| De eerdere spelbasisproef | [Unity-fase 7](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase7-preview-66dcb268) | Gebieden, toestand, voorwaarden, interactiedoelen en actieve speeltijd |
| De eerdere presentatieproef | [Unity-fase 6](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase6-preview-c73127ce) | Oorspronkelijke art, animaties, geluid en talen |
| Het eerdere bron- en downloadbewijs | [Unity-fase 3](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase3-preview-95811f4b) | Historische proef van de bouw-, herkomst- en downloadroute |
| Het eerdere bouwbewijs | [Unity-fase 2](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase2-probe) | Historisch eerste geslaagde Windows-bouwproef |

Pak altijd de hele Windows-ZIP uit; de bijbehorende runtimebestanden horen naast de exe te blijven. De Unity-preview heeft een andere productidentiteit. Fase 9 leest de vijf bekende Godot-opslagbestanden uitsluitend na een expliciete kopie-import en bewaart ze ongewijzigd in aparte Unity-opslag.

De actuele verwijzing en vertrouwde hashes staan in [preview.json](preview.json); de [migratieworkflow](https://github.com/sjorswakka-sketch/bluemap/actions/workflows/unity-migration.yml) controleert de gekoppelde release en bewaart daarnaast een herkenbaar Actions-downloadbestand, dat na 30 dagen kan verlopen. De Release-download is de blijvende route.

Alle downloads blijven binnen dezelfde repository; het bouwen van de Unity-speler gebeurt met de bestaande lokale activatie, de GitHub-workflow controleert bron en pakket. [Uitleg en controles](phase-03/README.md).

De actuele fase 12 start bij **Avontuur en opslag**. Begin een nieuw Unity-avontuur of hervat een veilige speelkopie. De 37 gebieden en de eerste route blijven beschikbaar. Gebruik de voorraadkist binnen je woning of de materiaalopslag in de kustwerkplaats; op afstand kun je de voorraad alleen bekijken. I/Tab/Select opent de tas, E/Enter/A gebruikt, Esc/B gaat terug; schouderknoppen kiezen een bedieningselement en de rechterstick volgt lange lijsten. Zoeken, categorieën, sorteren, favorieten en overzetten per 1, 10 of stapel zijn beschikbaar. Alle oorspronkelijke Godot-bestanden blijven behouden; [grenzen en controles](phase-12/README.md).
