# Fase 2 — Unity en bouwomgeving

De afgesproken bouwroute gebruikt de reeds geïnstalleerde en werkend geactiveerde **Unity 6.3 LTS, 6000.3.26f1**, revision **de8167e7440c**, met **Windows x64 / Mono**; de game zelf is nog niet overgezet.

[Download de afzonderlijke Windows-proef](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase2-probe); de [bestaande Godot-game](https://github.com/sjorswakka-sketch/bluemap/releases/tag/godot-baseline-0.34.0) blijft de volledige speelbare versie.

## Keuze en bewijs

- De officiële editorpatch is uitgebracht op 8 oktober 2026 en de 6.3-LTS-lijn wordt ondersteund tot december 2027; we pinnen versie én revision in unity/ProjectSettings/ProjectVersion.txt en controleren de Windows-versiemetadata vóór iedere proefbuild.
- Editorstart, C#-compilatie en de echte Windows-export zijn op deze werkplek geslaagd met de bestaande activatie; er is niets geïnstalleerd, geactiveerd, teruggegeven of gekocht, en er zijn geen licentie-/accountgegevens naar GitHub gekopieerd.
- Het geïnstalleerde Windows Mono x64-playbackdeel is daadwerkelijk gebruikt; IL2CPP, andere platformen en andere editorversies zijn hiermee niet bewezen.
- De eigen kleine proef draait in een aparte Unity-map en onder de eigen productidentiteit BlueMapMigrationTests / BlueMapUnityProbe; ze opent geen Godot-content of persoonlijke saves.
- De proef gebruikt een ingebouwde renderroute met Direct3D11, 32-pixeltegels en een 1152×648-venster, zonder externe pakketten of gekochte assets; de minimale tekeningen zijn uitsluitend proefmateriaal en vervangen geen bestaande gamegraphics.
- De volledige Windows-uitvoer wordt verpakt, inclusief UnityPlayer.dll, Mono en de Data-map; alleen de exe kopiëren is onvoldoende.

Een nieuwe schone projectkopie zonder Library-cache is eveneens gebouwd en gestart; alle 34 gekopieerde invoerbestanden bleven ongewijzigd en er ontstonden geen gewijzigde projectinstellingen; zie [clean-room.json](clean-room.json).

Het compacte echte bouw- en runtimebewijs staat in [checks.json](checks.json), met bron-/pakketgegevens in [environment.json](environment.json); de proef controleert onder andere het gestarte releaseprogramma, de actieve grafische kaart, 2D-botsingsquery, tegelgrootte, spelerslus, afzonderlijke identiteit en gerenderd gras, water en proefpersonage.

## Opnieuw uitvoeren

Gebruik een nieuwe of lege uitvoermap buiten de repository; de tool verwijdert geen eerdere resultaten:

    python tools/build_unity_probe.py --editor "C:/Program Files/Unity/Hub/Editor/6000.3.26f1/Editor/Unity.exe" --output "C:/Temp/BlueMapUnityProbe-run"

De tool controleert de versie en de aanwezige Windows-module, start de editor verborgen met -batchmode -nographics -buildTarget StandaloneWindows64 en roept de eigen bouwmethode BlueMapMigration.Editor.Phase2Build.BuildWindows aan; bouwfouten geven een foutcode en een compact mislukkingsbericht.

Daarna start de gemaakte speler met een echte grafische kaart; de speler gebruikt geen -batchmode of -nographics. De automatische proef stopt na de controles, terwijl een gewone start van de download een klein proefgebied laat zien met WASD/pijlen en Esc om te sluiten; dit is nog geen omzetting van de definitieve bediening.

De uitvoermap bevat build-report.json, runtime/result.json, runtime/screenshot.png, receipt.json, SHA256SUMS.txt en het complete Windows-ZIP; ruwe editor-/spelerlogs blijven alleen in de lokale private-logs-map, omdat een editorlog licentie-informatie kan bevatten.

## Beeldcontrole en begrenzing

Op deze computer gaf schermuitlezing uit een verborgen testvenster een zwart beeld, ook na het opstartscherm; de controle keurde dat terecht af. De definitieve automatische proef rendert daarom de echte speler-camera expliciet op de GPU naar een RenderTexture en leest de daadwerkelijke pixels terug, met controles voor de verwachte terrein- en personagekleuren.

Het opgeslagen beeld toont de camerawereld en sluit de vensterinterface uit; het bewijst geen volledige venster-/menucontrole, controllerondersteuning of visuele gelijkheid met Godot. Die vergelijkingen blijven onderdeel van de latere fases. Het opstartscherm staat uit en de proef wacht daarnaast op afgeronde startup.

## Bouwroute tijdens de migratie

De **bewezen route** is een lokale, automatisch aangestuurde export op deze reeds geactiveerde werkplek, gevolgd door controle en publicatie in dezelfde GitHub-repository; daarbij is geen remote licentie of betaald bouwproduct nodig gemaakt.

Een GitHub-hosted Unity-runner is nog niet gelicentieerd of beproefd en wordt dus niet als werkend gepresenteerd; fase 3 richt het verdere migratiespoor en passende controles/downloads in, met een afzonderlijke keuze voor een eventuele toekomstige runner. Een ontbrekende Hub op de gebruikelijke locaties hoeft de al geslaagde lokale export niet tegen te houden, maar bij latere heractivatie moet de officiële activatieroute worden gevolgd.

## Primaire bronnen

- [Officiële 6000.3.26f1-release en revision](https://unity.com/releases/editor/whats-new/6000.3.26f1).
- [Ondersteuningsbeleid Unity 6](https://unity.com/releases/unity-6/support).
- [Officiële activatiemethoden](https://docs.unity.com/en-us/engine/6000.3/manual/get-started/install-and-upgrade/licenses-and-activation/license-activation-methods).
- [Commandoregel voor builds](https://docs.unity.com/en-us/engine/6000.3/manual/building-and-publishing/build-command-line) en [Editorargumenten](https://docs.unity.com/en-us/engine/6000.3/manual/unity-editor/command-line-arguments/editor).
- [Playerargumenten en headless-modus](https://docs.unity3d.com/6000.3/Documentation/Manual/PlayerCommandLineArguments.html).
- [Werkelijke camerauitvoer naar een GPU-textuur](https://docs.unity.com/en-us/engine/6000.3/script-reference/unityengine/camera/render).
- [Bijbehorende Windows-runtimebestanden](https://docs.unity.com/en-us/engine/6000.3/manual/platform-specific/windows/standalone-binaries).
