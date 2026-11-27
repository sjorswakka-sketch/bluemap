# Fase 17 — beroepen, crafting en handel (in uitvoering)

**Status: nog niet afgerond.** De spelregels zijn overgezet en bewezen gelijk aan de Godot-bron. De Windows-build, de controles in de echte Unity-speler, de beelden en de download ontbreken nog: op 27 november 2026 startte de Unity-editor op deze werkplek niet meer omdat er geen actieve Unity-licentie werd gevonden. Fase 17 telt pas als afgerond wanneer die stappen zijn geslaagd.

## Wat is overgezet

De zeven beroepen met ervaring en niveaus, alle 95 grondstofsoorten met hun gereedschap, niveau-eis, verzameltijd en hersteltijd, alle 52 recepten met werkplek, ontgrendeling, materiaalgebruik uit tas en nabije kist, het materiaaldoel en de werktekeningen, de bronvermeldingen in het veldboek, beide winkels met hun 33 regels, eenmalige aankopen en weigeringen, en het vissen in het Zilvermeer: beet, haspel, vangstregistratie, de Gouden Karper en de visprijzen.

In de speelbare wereld opent **C** het beroepenboek, loopt verzamelen via de oorspronkelijke tijd en regels, openen winkels vanuit het gesprek, zijn werktekeningen te lezen en start een visplek het visspel. De tijdelijke melding dat winkels later volgen is vervangen door de echte winkel.

## Wat is bewezen

De oorspronkelijke Godot 4.4.1-methoden zijn uitgevoerd in twee verse stille processen: **1.306 gevallen met 5.420 handelingen** en ruim 43.000 exacte Float64-getuigen. Elk recept, elke grondstofsoort en elke winkelregel heeft een eigen brongeval. Het Unity-model geeft voor ieder geval exact hetzelfde resultaat, dezelfde meldingen en dezelfde 34 opslagvelden, zonder tolerantie. Dat is gecontroleerd met de vastgezette Unity-compiler en de Mono-runtime van dezelfde editor, buiten de editor om.

Toevalswaarden zijn een expliciete invoergrens: de opname legt vast welke waarden de Godot-generator leverde, en het Unity-model verbruikt precies die waarden in dezelfde volgorde. Deze port claimt geen identieke randomgenerator. Veertig haspelsimulaties en dertien vissessies lopen daarmee bit-exact gelijk.

Vijf aanvullende modelcontroles slagen: bladeren verandert niets en behoudt onbekende toekomstige velden, een geweigerde aankoop of een onmogelijk recept verandert niets, en een luisteraar kan tijdens het maken geen beloning verdubbelen.

De volledige Unity-runtime (106 bronbestanden) compileert zonder fouten of waarschuwingen. Alle 1.732 oorspronkelijke Godot-bestanden zijn ongewijzigd. Persoonlijke saves zijn niet gebruikt en elke enginetest draaide zonder geluid.

## Wat nog ontbreekt

- De Windows-build en de controles in de echte speler. De 18 beoogde beroepscontroles staan klaar in `ProfessionsProbeRunner`, maar zijn nog nooit uitgevoerd; de schermen en de wereldkoppeling zijn dus alleen gecompileerd, niet gespeeld.
- De drie beelden (beroepenboek, winkel, vissen), het pakket en de publieke download.
- De Linux-herhaling van de opname via GitHub.
- De visverkoop aan Joris en Mila liep al via de gesprekken van fase 15; het model bevat nu ook de bronregels, maar het gesprek gebruikt nog zijn eigen route.
- De speler draait bij het uitwerpen nog niet naar het water.

Huisinrichting, landbouw, water en productie volgen hun eigen fases.

## Verder gaan

Meld je aan in Unity (Hub) zodat de editor weer een geldige licentie heeft. Daarna:

    python tools/build_unity_probe.py --editor "C:/Program Files/Unity/Hub/Editor/6000.3.26f1/Editor/Unity.exe" --output "C:/Temp/BlueMapUnityProbe-fase17"

De opname opnieuw controleren kan zonder Unity:

    python tools/record_migration_professions.py Godot_v4.4.1-stable_win64_console.exe --check --evidence-dir <nieuwe map buiten de repository>
    python tools/build_migration_professions.py --check

Zie het [broncontract](source-contracts.json) en de [bronopname](professions-oracle.json). De Claude-branch en het Godot-herstelpunt blijven beschikbaar.
