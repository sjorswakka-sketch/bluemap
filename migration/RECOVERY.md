# Godot-herstelpunt 0.34.0-preview

Deze bestanden bewaren de bestaande Godot-game vóór de Unity-port; dit is geen Unity-build.

Vaste commit: a8a988be27835dec979d2523a3a85a34385eac54
Git-boom: 73ba02ea4db0a1c920360b6570f5209ccb970143
Godot: 4.4.1 stable, Windows Desktop export met ingebedde PCK
Repository: https://github.com/sjorswakka-sketch/bluemap
Hersteltag: godot-baseline-0.34.0

## Spelen
Pak BluemapQuest-v0.34.0-preview-windows.zip uit en open BluemapQuest/BluemapQuest.exe; lees de meegeleverde LEESMIJ voor bediening en bekende previewinformatie.
Dit is exact de bestaande GitHub Actions-build, opnieuw verpakt noch gewijzigd.
SHA256 ZIP: aa70c2655800d6049fe85d9b2b7671afe2f188f0e5d2d722e0869ebf6cbb8958
SHA256 EXE: 5a8eea99e9da3192f31462c5916a9fecd71b0f491b31fc5577e878cf2eed0ff0

## Bron herstellen
BluemapQuest-godot-0.34.0-source.zip bevat alle 1.734 oorspronkelijke bronbestanden met canonieke Git-bytes; project.godot staat in de bovenliggende BluemapQuest-godot-0.34.0-source map.
BluemapQuest-godot-0.34.0-history.bundle bevat de volledige vooroudergeschiedenis van deze referentiecommit, zonder afhankelijkheid van GitHub; dit is geen archief van alle andere, niet-gerelateerde branchhoofden.
Herstel in een nieuwe lege directory, nooit bovenop ongecommit werk:

    git clone --branch codex/unity-migration BluemapQuest-godot-0.34.0-history.bundle herstelde-godot
    cd herstelde-godot
    git rev-parse HEAD

De uitvoer moet de vaste commit hierboven zijn; de bundelbranch bevat op het herstelmoment uitsluitend de Godot-referentie, ook wanneer de online migratiebranch later verdergaat.

## Opnieuw bouwen
Gebruik de officiële Godot 4.4.1 stable editor en de exporttemplates voor precies die versie, met de Windows x86_64 release-template; herhaal de instructies uit .github/workflows/build-windows.yml van de vaste commit.
Open de bron in Godot 4.4.1 en exporteer met preset Windows Desktop; genereer eerst de importcache, neem de oorspronkelijke distribution/LEESMIJ.txt mee en controleer het pakket met tools/check_release.py --package.
De herbouw hoeft niet bytegelijk te zijn aan de bestaande EXE; deze download heeft een vaste hash, broncommit en geslaagd bouw-/testbewijs.
Let op: de pakketcheck vergelijkt de LEESMIJ byte voor byte; de Actions-build en het bron-ZIP gebruiken LF, terwijl Git op Windows bij checkout eventueel CRLF toepast.

## Test- en beeldbewijs
BluemapQuest-godot-0.34.0-evidence.zip bevat het volledige CI-joblog, het compacte referentiebewijs en de bestaande finale native beelden en Windows-testlogs; dit zijn eerder uitgevoerde controles op de vaste referentie, geen nieuwe Unity-tests.
De 86 bestaande suites zijn op deze commit geslaagd in CI; pakket-CRC, Windows-PE en x64 zijn in migratiefase 1 opnieuw gecontroleerd.
Alle tests of previews horen in een aparte projectkopie met unieke Bluemap-Codex-Tests-* opslag; gebruik tools/run_tests.py daarvoor en open nooit ongevraagd echte spelersaves.

## Voortgang en terugkeer
Persoonlijke saves zijn niet opgenomen in deze openbare release; maak bij latere import een lokale, exacte kopie van savegame.json, meta.cfg, ng_plus.cfg, controls.cfg en settings.cfg uit de eigen Godot-opslag.
Unity-import en aparte profielen zijn sinds [fase 9](phase-09/README.md) gebouwd en bewezen. De huidige [fase 13](phase-13/README.md) bewaart voortgang, uitrusting en uiterlijk in afzonderlijke speelkopieën; de oorspronkelijke Godot-bestanden blijven ongewijzigd. Terugexport van nieuw gemaakte Unity-voortgang naar Godot is nog niet bewezen en blijft fase 25.
De werkende Godot-branche blijft beschikbaar. Fase 9 bewijst de import; fase 25 moet de omgekeerde route afzonderlijk bewijzen.

Controleer alle losse herstelbestanden met SHA256SUMS.txt; details staan in recovery-manifest.json.
