# Fase 22 — het einde, Nieuw spel+ en de terugweg naar Godot

De overgezette game is nu compleet tot en met het einde. Als de Slijmkoning valt, volgt de epiloog: de stilte in de tempel, de Blauwe Kaart die weer heel is, en Oudste Bram, Greta, Tobias, Mila en Pim die elk iets zeggen. Daarna zie je je avontuur in cijfers (speeltijd, verslagen vijanden, munten, zwaard, hartjes en voltooide opdrachten), rolt de aftiteling en speel je verder in het dorp. De prestaties van het einde worden meteen behaald en bewaard.

Elke opslag na het einde onthoudt je beste zwaard, je hartcontainers, je laarzen, je heldenervaring en je uitrusting — nooit minder dan wat al bewaard was. In het profielscherm staat daarna **Nieuw spel+**: een nieuw verhaal zonder de openingsles, met die spullen en 100 munten. Vijanden hebben per voltooide ronde de helft meer levens en geven anderhalf keer zoveel munten. Dit zijn de regels en getallen van de Godot-game.

Met **Kopie voor Godot** in het profielscherm schrijf je je Unity-voortgang terug in de vorm die de Godot-game 0.34 leest: `savegame.json` met dezelfde 34 velden in dezelfde volgorde, `meta.cfg` met al je prestaties, `ng_plus.cfg` als je het spel hebt uitgespeeld, je oorspronkelijke instellingen en bediening als het profiel ooit uit Godot kwam, en een LEESMIJ met de stappen. De kopie komt altijd in een **nieuwe, eigen map** naast de Unity-profielen. Er wordt nooit iets in een bestaande Godot-opslagmap geschreven en nooit een bestand overschreven; het terugzetten doe je zelf, na een backup.

## Bewijs van de terugweg

De terugweg is bewezen met de echte Godot 4.4.1 ([opname](export-oracle.json), `tools/record_migration_return.py`). Voor elk van de 24 oorspronkelijke saves uit fase 9 gebeurt dit: Unity importeert de save en schrijft hem terug; de echte Godot-game laadt eerst de oude save en slaat hem zelf opnieuw op, en laadt daarna de bytes van Unity. In alle 24 gevallen is de voortgang daarna **exact gelijk**, tot op de bits van elk getal. De opname is twee keer gedraaid in verse, afgeschermde processen. De Windows-speler controleert bij elke eindtest dat hij nog precies dezelfde bytes schrijft als Godot toen heeft geladen. Eén verschil is daarbij gevonden en gelijkgetrokken: Godot bewaart het teken van een nul (-0,0) niet, de terugweg nu ook niet. `meta.cfg` en `ng_plus.cfg` zijn teruggelezen met de in fase 9 tegen Godot bewezen lezer; daarvoor is geen aparte Godot-opname gemaakt.

## Vergelijking en metingen

Alle 86 oorspronkelijke testsuites hebben een plek in de [leeswijzer](COVERAGE.md): per suite de fase waarin het onderwerp is overgezet en hoe die fase is bewezen. Dat is een indeling per onderwerp, geen bewering dat elke afzonderlijke Godot-controle opnieuw is uitgevoerd; de suites zelf blijven ongewijzigd bij de Godot-bron.

Beeldtijden, gemeten in de echte Windows-speler met dag en nacht, weer en lamplicht aan en bewoners in beweging, op lage procesprioriteit en zonder beeldsnelheidslimiet: village 7.0 ms (traagste twintigste 7.1 ms), forest 7.0 ms (traagste twintigste 7.4 ms), ijsdal 7.0 ms (traagste twintigste 7.2 ms), dorstvallei 7.3 ms (traagste twintigste 7.4 ms), lake 7.0 ms (traagste twintigste 7.2 ms). De grens is 33,4 ms (dertig beelden per seconde); er is geen knelpunt gevonden dat een aanpassing vroeg. De gemeten tijden liggen rond de verversing van het testscherm; de speler wacht daar dus op het scherm en de eigen rekentijd is gelijk of korter. De Godot-game is in deze fase niet op dezelfde manier gemeten; een getal naast getal ontbreekt dus.

De lange speelsessie liep 12 gesimuleerde minuten door alle 37 gebieden, met bewoners in beweging en tussendoor opslaan en herladen: 0 fouten, geheugengroei -148.0 MB. Dit is een automatische sessie die de spelsystemen per gebied laat doorlopen; de dagklok en de speeltijd liepen daarbij niet mee, en een mens heeft niet urenlang achter elkaar gespeeld.

De echte Windows-speler slaagt voor 48 algemene, 119 basis-, 69 speler-, 115 opslag-, 73 route-, 57 wereld/toegangs-, 44 inventaris-, 32 uitrusting/uiterlijk-, 37 gevechts-, 32 verhaal-, 23 bewoners-, 18 beroeps-, 18 huis- en erf-, 20 tuin-, 19 gebieds-, 15 sfeer- en 62 afrondingscontroles: 801 in totaal, nul fouten en waarschuwingen. Alle eerdere controles blijven verplicht.

Alle 820 Python-tests eindigen zonder fouten en alle stappen van de broncontrole op GitHub zijn vooraf lokaal uitgevoerd. Alle 1.732 oorspronkelijke bestanden en Git-modes blijven behouden.

[Windows-download](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase22-preview-f22f846e), versie 0.18.0-phase22. ZIP `BlueMapUnityPreview-phase-22-f22f846e-Windows-x64.zip`: 76,767,921 bytes, SHA256 `35ff65bb2eeb2e3c11056a4a3da83943cddae9e13c7275a88f856b4f0547eb1b`. De gepubliceerde ZIP is daarna werkelijk gedownload en opnieuw gecontroleerd. De drie nieuwe beelden tonen de epiloog, je avontuur in cijfers en het begin van Nieuw spel+. Een fysieke controller is niet handmatig getest.

Automatische Unity-tests zetten vanaf het opstarten uitsluitend de testlistener stil. Het systeemvolume en gewone gamevoorkeuren worden daarvoor niet veranderd.

## Hersteld in deze fase

In de testversie van fase 21 werden behaalde prestaties als een woordenlijst bewaard in plaats van als de lijst die de Godot-save gebruikt. Daardoor kon een geïmporteerd profiel eerdere prestaties opnieuw aankondigen. Prestaties worden nu als de oorspronkelijke lijst bewaard; een profiel dat nog de oude vorm heeft wordt bij de eerstvolgende prestatie en bij elke kopie voor Godot omgezet.

## Nog niet in deze fase

Het titelscherm en de intro van Godot zijn niet overgezet: de Unity-testversie begint in het profielscherm. In de epiloog ontbreekt het beeld waarin de kaart weer kleur krijgt; de zin staat er wel. Na het einde keer je terug naar het dorp in plaats van naar een titelscherm. Bewegend water, stoom, vonken, de zichtbare standen van doelwitten, spiegels en vuurkorven, hartjes in het HUD en de oefenpoppen in Rafs werkplaats ontbreken nog. Een kopie voor Godot bevat de 34 velden van de Unity-voortgang; onbekende toekomstige velden uit een ooit geïmporteerde Godot-save blijven in het Unity-profiel bewaard maar gaan niet mee terug. Fases 20 en 21 hebben geen Godot-opname en dus geen bit-exacte vergelijking. Unity is nog niet de hoofdversie op de Claude-branch: dat is fase 23 en wacht op een laatste go.

Broncommit `f22f846e2000f22ca8e6823966c188faf3d67f92`, fingerprint `6cee96bd1a819d7e81ecafb13e1b44da5472ea1ef3e89109409b3502167d5bbd`. GitHub controleert bron en de werkelijk gepubliceerde download; een gehoste Unity-compilatie wordt niet geclaimd. Ruwe logs, testprofielen, caches en activatiegegevens blijven buiten publieke pakketten. De Claude-branch en het Godot-herstelpunt blijven beschikbaar.
