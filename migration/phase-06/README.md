# Fase 6 — oorspronkelijke presentatie naar Unity

Deze fase brengt de bestaande pixelart, animatieframes, audiobestanden, lettertypes en Nederlandse/Engelse teksten naar de afzonderlijke Unity-preview. De Godot-game, oorspronkelijke kaartindeling en herstelrelease blijven behouden. De technische spelbasis, volledige gameplay, save-import en complete menuport volgen in hun geplande fases.

## Overdracht en behoud

Alle 244 oorspronkelijke PNG-bestanden blijven byte voor byte beschikbaar, inclusief drie generator-reviewbeelden die niet als wereldobject worden gebruikt. Het SVG-icoon blijft als bron behouden en krijgt een rasterversie. De atlasbeschrijving gebruikt alleen brongetrouw bewezen uitsneden: onder andere de speler, 35 menselijke NPC-sheets, 90 kapsels, 24 kledingstukken en vier gearmaskers, terrein, boomkronen, huis en erf. Onbekende atlasindelingen worden niet ingevuld met gegokte vakmaten of animatiesnelheden; de volledige afbeelding en oorspronkelijke tekenbron blijven beschikbaar.

De daadwerkelijke Godot-renderer tekent aanvullende, deterministische referenties van uiterlijklagen, ogen, gedragen gear, zwaarden, boog, rollen, werkhandelingen, druiven/bloemen, rotsen en watervallen. Twee afzonderlijke GPU-processen moeten dezelfde complete exports produceren. De synthetische voorbeelden gebruiken uitsluitend een geverifieerde UUID-testopslag. Doorlopende effecten worden expliciet als gekozen tijdstappen aangemerkt; acht referentiebeelden vervangen niet de oorspronkelijke continue formule. Alle oorspronkelijke scripts en functiebronnen blijven daarnaast als data-contract opgenomen.

De Unity-import maakt echte Sprite-objecten en AnimationClip-assets. Import behoudt alle RGBA-pixels, gebruikt point filtering, schakelt mipmaps en verliesgevende compressie uit en bewaakt schaal, pivot, uitsneden en verwijzingen. Texturecoördinaten worden van bovenaf naar Unity omgezet. De native catalogus wordt alleen in de tijdelijke bouwkopie gemaakt; Unity-caches komen niet terug in de bron.

Alle 138 WAV-bestanden, twaalf muziekstukken, zeventien sfeerlussen en hun originele ID's blijven behouden. De overdracht bewaart samplefrequentie, kanaalaantal, duur, lusgrenzen, de acht SFX-spelers, volume/pitchregels en muziekfade. De herbruikbare Unity-audioservice speelt de originele clips af. De 211 bronaanroepen blijven afzonderlijk geregistreerd; de volledige koppeling aan gevechten, weer en gameplay volgt met die systemen.

De volledige PO-catalogus omvat 3.187 items, twaalf meervouditems en negen contextitems. Bron, vertaling, placeholdervolgorde, meervoud en context blijven intact. De Unity-lookup wordt tegen ieder item gecontroleerd. Het originele ingebedde Open Sans SemiBold-font wordt zonder wijziging van zijn fonttabellen overgezet; een expliciet, eveneens met Godot meegeleverd aanvullend font maakt zes eerder van OS-fontfallback afhankelijke symbolen beschikbaar. Licenties en container-/tabelhashes blijven behouden; zie [de dekkingskeuzes](COVERAGE.md).

## Zelf controleren

Vanaf de repositorywortel, met Python en de vastgezette PNG-decoder `Pillow==12.2.0`:

```text
python tools/build_migration_graphics.py --check
python tools/build_migration_audio_text.py --check
python -m unittest discover -s tests/migration -p 'test_*.py' -v
python tools/check_migration.py --check --output <nieuw-bronrapport.json>
```

De brongetrouwe GPU-export opnieuw opnemen of vergelijken:

```text
python tools/record_migration_graphics.py <Godot-4.4.1-executable> --check --evidence-dir <nieuwe-lege-externe-map>
```

Gebruik altijd de opnamewrapper; de export weigert een gewone spelopslag en een headless renderer. Fontopname heeft daarnaast de vastgelegde fontTools/brotli-versies nodig; de normale controles controleren de vastgelegde fonttabellen zonder die aanvullende afhankelijkheden.

Een echte, traceerbare Windows-preview bouwen met de reeds aanwezige lokale Unity-activatie:

```text
python tools/build_unity_probe.py --editor <Unity-6000.3.26f1/Unity.exe> --output <nieuwe-lege-externe-map>
```

Het hulpmiddel vereist gecommitteerde bouwinputs, bouwt vanuit hun canonieke Git-bytes in een tijdelijke kopie, start de echte Windows-speler en controleert de GPU-beelden. GitHub controleert bron, referenties en de gekoppelde lokaal gebouwde download; GitHub compileert of start Unity niet. De actuele download en de volledige bestaande game staan bij [Downloads](../DOWNLOADS.md).

## Uitvoeringsbewijs en grenzen

De preview bevat afzonderlijke pagina's voor oorspronkelijke beelden, kapsels, kleding, gear, talen en pixelvergelijking, plus een bewegend animatievoorbeeld. De importcontrole vergelijkt alle texturepixels; de GPU-proef vergelijkt ondoorzichtige bronpixels uit afzonderlijke kapsels, kleding, speler- en terreinframes en bewijst dat opeenvolgende animatieframes veranderen. Dit zijn gerichte presentatiecontroles, geen verklaring dat iedere wereldtoestand, lichtcombinatie of interface al pixelgelijk is tussen de engines.

De complete wereld uit fase 5, bestaande regels en persoonlijke opslagsleutels blijven apart behouden. Deze fase voegt geen gebouwen, monsters, grond of dichtheid aan de wereld toe. Samengestelde dynamische wereldweergave, contextafhankelijke cosmetica/gear, combat, weersfeer en alle menu's worden bij hun eigen geplande systemen geïntegreerd en opnieuw gecontroleerd.

Een bestaande atlasgrens is expliciet bewaard voor de boomgaardport: de oorspronkelijke stamafbeelding heeft vier 64px-vakken (indices 0–3), terwijl de tekenbron ook index 4 kan vragen. De volledige originele afbeelding en functie blijven behouden; de Unity-catalogus maakt geen uitsnede buiten de afbeelding en verzint geen vijfde stam. De daadwerkelijke boomgaardintegratie moet die brongrens gericht afhandelen.

## Vastgelegde uitslag

[De controle-uitkomst](verification.json), [native import](native-import.json) en [GPU-/animatiebewijs](native-presentation.json) leggen 25.237.696 exacte RGBA-pixels, 13.640.367 exacte PCM-samples, 32.040 exacte oorspronkelijke GPU-pixels en 18.861 correcte animatiegrenssamples over alle 201 clips vast. De Windows-preview doorstaat 29 runtimecontroles; zeven bestaande Godot-suites blijven slagen. De lokale Pythonset telt 325 tests, waarvan twee symlinkfixtures op deze Windows-werkplek extra rechten vragen; de Linux-workflow voert de complete set uit.

De native animatiecontrole vergelijkt opgeslagen float32-bits zonder tolerantie; C# kan tussenberekeningen met [extra precisie uitvoeren](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/types#837-floating-point-types). De galerij bepaalt eerst de oorspronkelijke frame-index en samplet het echte native clip via een PlayableGraph binnen dat frame-interval, zodat modulo-afronding rond een loopgrens geen ander beeld kiest. De bron-fps en originele data blijven behouden.
