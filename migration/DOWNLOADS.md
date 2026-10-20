# Downloads van BlueMap Quest

| Wat wil je openen? | Download | Inhoud |
|---|---|---|
| De volledige bestaande game | [Godot 0.34.0-preview](https://github.com/sjorswakka-sketch/bluemap/releases/tag/godot-baseline-0.34.0) | Bestaande game, oorspronkelijke wereld en systemen; bron en herstelgeschiedenis inbegrepen |
| De actuele technische Unity-preview | [Fase 8 — 3f604417](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase8-preview-3f604417) | Speler, lopen/rennen, stamina, rollen, richten, camera en toetsenbord/controller; nog geen volledige gameport |
| De eerdere spelbasisproef | [Unity-fase 7](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase7-preview-66dcb268) | Gebieden, toestand, voorwaarden, interactiedoelen en actieve speeltijd |
| De eerdere presentatieproef | [Unity-fase 6](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase6-preview-c73127ce) | Oorspronkelijke art, animaties, geluid en talen |
| Het eerdere bron- en downloadbewijs | [Unity-fase 3](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase3-preview-95811f4b) | Historische proef van de bouw-, herkomst- en downloadroute |
| Het eerdere bouwbewijs | [Unity-fase 2](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase2-probe) | Historisch eerste geslaagde Windows-bouwproef |

Pak altijd de hele Windows-ZIP uit; de bijbehorende runtimebestanden horen naast de exe te blijven. De Unity-preview heeft een andere productidentiteit en leest geen Godot-saves.

De actuele verwijzing en vertrouwde hashes staan in [preview.json](preview.json); de [migratieworkflow](https://github.com/sjorswakka-sketch/bluemap/actions/workflows/unity-migration.yml) controleert de gekoppelde release en bewaart daarnaast een herkenbaar Actions-downloadbestand, dat na 30 dagen kan verlopen. De Release-download is de blijvende route.

Alle downloads blijven binnen dezelfde repository; het bouwen van de Unity-speler gebeurt met de bestaande lokale activatie, de GitHub-workflow controleert bron en pakket. [Uitleg en controles](phase-03/README.md).

De actuele fase 8 start in de loopwereld; F1/F2/F3 kiezen dorp, bos en grot. Ctrl rent en Shift/K rolt. F9, I/Tab of Select opent het tijdelijke bedieningsmenu. Persoonlijke opslag, volledige objectfuncties en de complete game volgen in hun migratiefases; [grenzen en controles](phase-08/README.md).
