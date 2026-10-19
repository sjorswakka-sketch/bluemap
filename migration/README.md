# Unity-migratie — fase 3 voltooid

Het volgende **go** start fase 4: overdraagbare spelgegevens en vaste IDs ontwerpen; de volledige game is nog niet overgezet.

[Fase 3: afzonderlijke controles en herkenbare downloads](phase-03/README.md) — 62 eigen tests, bronbehoud, Godot-coexistentie, ingebedde buildherkomst en 16 Windows-runtimecontroles; zie [actuele downloads](DOWNLOADS.md).

[Fase 2: bewezen lokale bouwomgeving](phase-02/README.md) — Unity 6.3 LTS 6000.3.26f1, Windows x64 / Mono, 14 geslaagde runtime-/beeldcontroles en een schone herbouw zonder cache of bronwijzigingen. De [kleine Windows-proef](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase2-probe) staat naast het blijvende Godot-herstelpunt.

- [Plan met 28 fases](PLAN.md) en [voortgang](PROGRESS.json).
- [Permanent Godot-herstelpunt met speelbare Windows-download](https://github.com/sjorswakka-sketch/bluemap/releases/tag/godot-baseline-0.34.0) en [herstel-/herbouwinstructies](RECOVERY.md).
- [Behoudsregister](BEHOUDSREGISTER.md) en [save- en ID-contract](SAVE_COMPATIBILITY.md).
- [Alle oorspronkelijke bronbestanden en hashes](reference/source-manifest.json).
- [Samengestelde inhoud en herkomst](reference/content-inventory.json), [37 registry-kaarten](reference/maps-inventory.json) en [opslagvelden](reference/save-contract.json).
- [Fasecontroles](reference/phase1-checks.json), [bestaande 86 geslaagde Godot-suites](reference/godot-test-baseline.json) en [gecontroleerde releasebestanden](reference/published-recovery.json).

De bronreferentie omvat 1.734 bestanden en 383 beeld-/geluidsassets; de inhoudsinventaris bevat 34 catalogi, 226 items, 33 quests, 244 gesprekken, 52 recepten en 37 kaarten met samen 49.758 tegels.

Het losse bron-ZIP is met alle oorspronkelijke Git-blobs vergeleken en de Git-bundel is offline teruggehaald met objectcontrole; de zeven gepubliceerde herstelbestanden hebben dezelfde SHA256 als de gecontroleerde lokale bestanden.

De kaarteninventaris is nog geen volledige export van geladen of door quests veranderde wereldtoestanden: dat volgt in fase 5; save-import en terugexport volgen in fases 9 en 25, en echte persoonlijke saves zijn niet geopend of gepubliceerd.

Deze migratiebranch voegt in fase 1 uitsluitend referenties, documentatie en inventaris-/herstelhulpmiddelen toe; de Godot-game op de Claude-branch en het bestaande uitbreidingsplan blijven behouden.
