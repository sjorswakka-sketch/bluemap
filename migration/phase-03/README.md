# Fase 3 — afzonderlijk migratiespoor

De Unity-migratie blijft op **codex/unity-migration** binnen dezelfde GitHub; de volledige Godot-game blijft op **claude/affectionate-mendel-vc1idx** en het [vaste herstelpunt](https://github.com/sjorswakka-sketch/bluemap/releases/tag/godot-baseline-0.34.0) beschikbaar.

[Herkenbare Windows-preview](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase3-preview-95811f4b) — fase 3, 0.1.0-phase3, bron 95811f4b; dit is nog de kleine technische proef en niet de overgezette game. De oorspronkelijke wereld, quests, graphics en savebestanden zijn in deze fase niet gewijzigd.

## Automatische controles

De aparte workflow .github/workflows/unity-migration.yml start bij pushes naar de migratiebranch en pull requests met die branch als doel; de oude Godot-workflow is ongewijzigd. De workflow gebruikt uitsluitend leesrechten en vastgepinde officiële actions en publiceert eigen controlerapporten.

- **Bronbehoud en migratietests:** 62 eigen tests, waaronder gewijzigde of verwijderde spelbestanden, verborgen staged wijzigingen, verkeerde Unity-revisie, ontbrekende/duplicaat-metadata, onjuiste sceneverwijzingen, pakketdrift, corrupte downloads, ontbrekende runtimebestanden en afwijkende bronherkomst.
- **Huidige bron:** alle 1.732 oorspronkelijke bestanden buiten de twee expliciet toegestane documentatie-/ignorebestanden worden tegen de vastgelegde Git-blobs én huidige werkbestanden gecontroleerd; de huidige index mag geen verborgen wijzigingen bevatten. Het oorspronkelijke bronregister blijft met 1.734 bestanden behouden.
- **Godot blijft werken naast Unity:** echte Godot 4.4.1-start- en wereldatlastests lopen met afzonderlijke tijdelijke opslag; unity/.gdignore voorkomt import van de andere engine-map. De eerdere 86 volledige suites en hun bewijs blijven bewaard; ze worden hiermee niet vervangen door een claim van 86 nieuwe Unity-tests.
- **Downloadcontrole:** GitHub haalt de gekoppelde, lokaal gebouwde Windows-ZIP en het vertrouwde rapport op, vergelijkt broncommit en invoerfingerprint met Git, valideert ieder bestand en publiceert dezelfde herkenbare ZIP als tijdelijk Actions-artifact. De Release-download blijft daarnaast beschikbaar.

De workflow compileert of start Unity niet op een GitHub-hosted runner; de bewezen export blijft de al geactiveerde Windows-werkplek. Er zijn geen licentiegegevens, nieuwe betaalde diensten of extra runnerrechten gebruikt.

## Bouw en download

Voer eerst alle bouwinvoerbestanden als een schone broncommit in; start daarna:

    python tools/build_unity_probe.py --editor "C:/Program Files/Unity/Hub/Editor/6000.3.26f1/Editor/Unity.exe" --output "C:/Temp/BlueMapUnityPreview-run"

De tool bouwt een tijdelijke projectkopie uit de canonieke Git-bytes. Alleen die kopie krijgt gegenereerde Resources/BuildIdentity.json en Unity-caches; de werkbron blijft gelijk. Een tijdelijk vastgehouden Windows-cachemap wordt apart gerapporteerd en maakt een geslaagde export niet ongeldig; de echte bouw-, start- en pakketcontroles moeten wel slagen.

De identiteit bevat fase, previewversie, volledige broncommit, invoerfingerprint, editor/revisie en target. Diezelfde identiteit wordt in de speler geladen en in buildrapport, runtimebewijs, pakket en extern rapport vergeleken; de 16 runtimecontroles omvatten ook ingebouwde identiteit en previewversie.

Het ZIP bevat de volledige Windows-/Mono-runtime, BUILD-IDENTITY.json, RUNTIME-CHECKS.json, FILES.json met ieder bestand en een duidelijke Nederlandse LEESMIJ; de bestandsnaam noemt fase en de eerste acht committekens. Iedere download moet volledig worden uitgepakt.

Controleer een losse download met:

    python tools/verify_unity_package.py --package <Windows-ZIP> --receipt <receipt.json> --expected-source-commit <volledige-broncommit>

Of download en controleer de aan deze branch gekoppelde preview tegelijk:

    python tools/fetch_unity_preview.py --output <nieuwe-externe-map>

De bronkoppeling staat in [../preview.json](../preview.json), de echte Windows-uitvoer in [runtime-receipt.json](runtime-receipt.json) en de pakketcontrole in [package-verification.json](package-verification.json). Een bewijs-/documentatiecommit kan na de build volgen; alleen wanneer alle daadwerkelijke bouwinputs gelijk zijn, mag die nieuwe branchkop dezelfde preview aanwijzen. Zodra die inputs veranderen, moet de referentie naar een nieuwe gecontroleerde preview worden bijgewerkt.

## Wat dit bewijs omvat

| Onderdeel | Type controle | Huidige dekking |
|---|---|---|
| Oude gamebron en IDs | Vergelijking met onveranderlijke Git-referentie | Alle originele bestanden behalve README en .gitignore |
| Unity-bronnen | Structuur-, versie- en metadata-integratie | Editor/revisie, ingebouwde pakketten, Assets/GUIDs/buildscene |
| Verkeerde bron of onvolledig pakket | Gerichte negatieve fixtures en CLI-tests | 62 gezamenlijke migratie-/pakkettests |
| Beide engines naast elkaar | Echte engine-integratie op GitHub | Godot-start en atlas, in eigen tijdelijke opslag |
| Windows-export en GPU | Werkelijk gebouwde speler op Windows | 16 runtimecontroles, geen compilerfouten/-waarschuwingen |
| Gepubliceerde download | Onafhankelijke GitHub-controle | Broncommit, fingerprint, ZIP/CRC, elk bestand, x64 en runtimebewijs |

De camerafoto komt van echte GPU Camera.Render/RenderTexture-uitvoer en sluit de vensterinterface uit. Toets-/controllergelijkheid, volledige spelregels, save-import, wereldexport en visuele vergelijking van de echte game blijven de afgesproken latere fases; de eenvoudige proefbeelden vervangen geen gamekunst. Checksums controleren integriteit ten opzichte van de vertrouwde Git-koppeling en zijn geen afzonderlijke uitgevershandtekening.

## Primaire bronnen voor de inrichting

[GitHub-workflowfilters en rechten](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax), [vastgepinde actions en minimale rechten](https://docs.github.com/en/actions/reference/security/secure-use), [checkout v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1), [setup-python v7.0.0](https://github.com/actions/setup-python/releases/tag/v7.0.0), [upload-artifact v7.0.2](https://github.com/actions/upload-artifact/releases/tag/v7.0.2).
