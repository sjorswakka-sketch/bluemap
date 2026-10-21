# Unity-migratie — fase 12 voltooid

Het volgende **go** start fase 13: ervaring, gear en uiterlijk; de volledige game is nog niet overgezet.

[Fase 12: voorwerpen, buit en opslag](phase-12/README.md) — oorspronkelijke magnetische buit, veilige kisten, tas, woning- en kustopslag, zoeken, sorteren, favorieten en controllerlijsten; 37 algemene Windows-controles en 44 inventariscontroles.

[Fase 11: alle gebieden en toegangspunten](phase-11/README.md) — alle 37 bestaande gebieden en interieurs, oorspronkelijke questsloten, sleutels, boten, veilige aankomsten en terugroutes; 36 Windows-controles en 57 wereld-/toegangscontroles.

[Fase 10: eerste speelbare route](phase-10/README.md) — dorp, woning, bosrand en bos; Pim en Muis, verzamelen, pickups, kisten, inventaris, opdrachten, rust, veilige speelkopieën, bewaren en laden; 35 Windows-controles en 73 routecontroles.

[Fase 9: veilige opslag en instellingen](phase-09/README.md) — alle 34 opslagvelden, oorspronkelijke bronbytes, prestaties, Nieuw spel+, taal, audio en bediening; aparte Unity-profielen met herstel, 33 Windows-controles en 115 import-/opslagcontroles.

[Fase 8: speler, camera en bediening](phase-08/README.md) — lopen, rennen, stamina, rollen, onafhankelijke kijkrichting, crosshair, native invoer en tijdelijk bindingsmenu; drie loopbare terreinproeven, 32 Windows-controles, 119 basiscontroles en 69 spelercontroles.

[Fase 7: de technische spelbasis](phase-07/README.md) — alle 221 bronbestanden en 162 wereldopnamen native geladen, zelfstandige speltoestand, gebieden, gebeurtenissen, voorwaarden, interactiedoelen, actieve speeltijd en gecontroleerde coördinaten/botsingen; 31 Windows-controles en 119 deelcontroles.

[Fase 6: oorspronkelijke presentatie in Unity](phase-06/README.md) — alle originele PNGs en WAVs, native sprites en animatieclips, 90 kapsels, 24 kledingstukken, fonts en alle 3.187 NL/EN-teksten; 30 echte Windows-runtimecontroles, 18.861 animatiegrenssamples en brongetrouwe transparantie.

[Fase 5: de daadwerkelijk geladen wereld](phase-05/README.md) — alle 37 kaarten, 59 synthetische profielen en 162 kaartopnamen met oorspronkelijke slots, runtime-objecten, echte colliders, aankomsten en veranderde toestanden; zie [de wereldindex](world/index.json).

[Fase 4: overdraagbare spelgegevens en vaste IDs](phase-04/README.md) — 34 catalogi, 377 tabellen, 905 objectslots, 33 voorwaarden, 36 acties en 139 migratietests; zie [het gegevensformaat](DATA_FORMAT.md).

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

De oorspronkelijke registry-inventaris blijft behouden; fase 5 voegt de daadwerkelijk geladen kaarten en benoemde veranderde toestanden toe, met expliciete dekkingsgrenzen. Save-import is in fase 9 bewezen met eigen testprofielen; terugexport volgt in fase 25. Echte persoonlijke saves zijn niet geopend of gepubliceerd.

Deze migratiebranch voegt in fase 1 uitsluitend referenties, documentatie en inventaris-/herstelhulpmiddelen toe; de Godot-game op de Claude-branch en het bestaande uitbreidingsplan blijven behouden.
