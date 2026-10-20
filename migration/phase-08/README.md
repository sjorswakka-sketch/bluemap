# Fase 8 — speler, bewegen en bediening

Deze fase brengt lopen, direct rennen, stamina, rollen, zelfstandig richten, lichaamsrichting, camera en toetsenbord/controller over naar Unity. De bestaande Godot-versie en alle oorspronkelijke inhoud blijven behouden; de wereld krijgt geen nieuwe plaatsingen of bebouwing.

De losse Windows-proef opent een loopbare terreinweergave met de oorspronkelijke pixeltegels, boomkronen en speleranimaties. F1, F2 en F3 kiezen dorp, bos en grot; 1–6 blijven de presentatieproeven, 7 de spelbasis en 8 de loopproef. Ctrl rent, Shift/K rolt, P/Esc pauzeert; controller gebruikt linker stick, L3, B, rechter stick en Start. F9, I/Tab of Select opent het tijdelijke bedieningsmenu, inclusief opnieuw koppelen, conflictwissels en rechterstickscrollen. Deze koppelingen bestaan alleen in geheugen.

Alle oorspronkelijke terrein- en objectvoeten uit de gekozen momentopname worden als echte botsingsvormen gebruikt. Voor objecten waarvan de eigen renderer nog volgt, is de voet zichtbaar omrand: er komen geen onzichtbare blokkades bij. De volledige objectweergave, NPC-gedrag, interacties, quests en gevechten volgen in hun afgesproken fases. De speler gebruikt de oorspronkelijke veilige aankomst en heeft een cirkelvoet met straal zeven pixels en acht pixels verschuiving.

Twee onafhankelijke oorspronkelijke Godot-processen leveren elke bewegings- en invoerreferentie. Unity vergelijkt de bronwaarden en voert daarnaast echte native invoergebeurtenissen, botsingsqueries, muis/controllerwissels en presentatiecontroles uit. De proef leest en schrijft geen persoonlijke saves; veilige import is fase 9.

De [blijvende Windows-download](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase8-preview-3f604417) is vanuit een gecontroleerd concept gepubliceerd en daarna opnieuw via de openbare downloadroute opgehaald. Alle 22 openbare bestanden hebben dezelfde gecontroleerde hashes; de oorspronkelijke Claude-branch blijft op a8a988be27835dec979d2523a3a85a34385eac54.

## Vastgelegde controles

De native Windows-build heeft nul bouwfouten en waarschuwingen en slaagt voor 32 algemene controles, 119 controles van de spelbasis en 69 spelercontroles in 178 frames. [Uitvoeringsbewijs](verification.json), [alle spelercontroles](native-player.json), [alle basiscontroles](native-foundation.json), [pakketbewijs](package-source-verification.json), [publicatiebewijs](published-preview.json) en [openbare herdownload](public-download-verification.json) horen bij bron 3f604417add679adcdaa4af5201025cb14400b32, bronvingerafdruk d64825b1d2fba8e8398139696d13920b78e403fe7f9191517b0e1e2ea3974e68.

De complete Python-set telt 400 tests; lokaal slagen er 398 en worden twee Windows-symlinkfixtures overgeslagen. GitHub voert de Linux-varianten zonder die skips uit. Zeven relevante oorspronkelijke Godot-suites slagen voor 759 controles, met afzonderlijke geverifieerde UUID-opslag en ongewijzigde bronbestanden. De twee nieuwe bronoracles bevatten 137 bewegingsgevallen met 1.528 exacte numerieke waarden, alle 36 acties met 86 bindings en 16 stickvoorbeelden. Zie [bewegingskeuzes](MOVEMENT.md), [invoer en koppelingen](INPUT.md) en [samengevat bewijs](validation-summary.json).

De native controles vonden en herstelden een fout bij het verwijderen van een controller en één Float32-afrondingsverschil bij analoge lichaamsrichting. De bewegingsoracle vergelijkt oorspronkelijke Float64- en Float32-bits zonder toleranties of aangepaste bronuitkomsten. De invoercontrole gebruikt voor berekende stickvectoren een expliciete vectorafstand kleiner dan 0,00001; bindings, bronbestanden en Resources-kopieën blijven exact. Echte Box2D-sweeps controleren stoppen voor obstakels, glijden langs muren, vrij lopen, pauze en geen sprintverbruik wanneer een muur de speler tegenhoudt. Alle drie proefgebieden laden; een echte wandeling over een bronpad veroorzaakt het passende oorspronkelijke geluid.

De grafische controle vergelijkt de daadwerkelijk gerenderde spelerpixels met dezelfde scène zonder speler. De oorspronkelijke roltransformatie blijft apart zichtbaar. Veertien native beelden omvatten ook de echte spel-HUD en het bedieningsmenu. Het menu heeft een dekkend paneel met een gedimde wereld; de HUD verdwijnt terwijl het menu openstaat. Er zijn geen bureaubladbeelden of nagebouwde menuplaatjes gebruikt.

Inputbewijs gebruikt de echte Unity Input System 1.20.1-eventwachtrij met eigen virtuele apparaten. Beide Ctrl-/Shift-zijden, apparaatwissels, focusverlies, twee controllers, verbinding herstellen, indrukken/loslaten en echte bindingscapture worden gecontroleerd. Een handmatige doorspeeltest met een fysieke controller wordt niet geclaimd. Volledige werking van alle behouden spelacties en de uiteindelijke menu's volgen in hun systeemfases.

De ZIP bevat 150 bestanden, is 69.594.717 bytes groot en heeft SHA256 b709af31a21644dd179edbc1c65e5eecdfa9d11db5ff059321e35d5ecbbba4a4. Unity leest geen bestaande Godot-opslag. Het volgende go start uitsluitend fase 9: veilige import van saves en instellingen naar aparte Unity-opslag.

## Zelf herhalen

```text
python tools/build_migration_player.py --check
python tools/record_migration_player_motion.py <Godot-4.4.1> --check --evidence-dir <nieuwe-externe-map>
python tools/record_migration_player_input.py <Godot-4.4.1> --check --evidence-dir <andere-nieuwe-externe-map>
python -m unittest discover -s tests/migration -p 'test_*.py' -v
python tools/build_unity_probe.py --editor <Unity-6000.3.26f1/Unity.exe> --output <nieuwe-externe-map>
python tools/fetch_unity_preview.py --output <nieuwe-externe-downloadmap>
```

