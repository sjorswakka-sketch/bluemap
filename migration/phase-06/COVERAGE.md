# Presentatiedekking van fase 6

Het [bronregister](../presentation-coverage.json) is gebaseerd op de ongewijzigde Godot-referentie `a8a988be27835dec979d2523a3a85a34385eac54`. Het bewaart herkomst en vereiste presentatiecontracten; het is op zichzelf geen bewijs dat iedere oorspronkelijke tekenfunctie al in C# draait. De Unity-import en uitvoeringsproeven moeten afzonderlijk aantonen wat daadwerkelijk werkt.

## Volledige broninventaris

De oorspronkelijke 383 beeld- en audiobestanden bestaan uit 241 game-PNG's, 138 WAV's, de SVG-game-icoon en drie review-PNG's van eigen generators. Reviewafbeeldingen worden niet als nieuwe wereldobjecten gebruikt. De binaire hashes moeten exact blijven; alleen de tekstuele SVG mag LF/CRLF normaliseren.

Alle 55 oorspronkelijke Pythonbestanden voor art, audio en hun hulpfuncties hebben bronhashes en importafhankelijkheden. `make_art.py` verzamelt `art_x_*.py`; `art_x_visual.py` roept de native-charactergenerator aan. Andere pakketten, waaronder wintergroenten, bloemen, bosvruchten en de berg, hebben aanvullende zelfstandige generators. Die worden niet in de echte gamebron uitgevoerd: onder andere `art_characters_native.sheets()` schrijft ook `scripts/data/character_art.gd` terug.

Het register bevat de letterlijke scriptafhankelijkheden van alle 306 oorspronkelijke GDScriptbestanden. Een conservatieve bronselectie vindt 140 bestanden met directe teken- of texturehandelingen, 74 met audioverwijzingen en 118 met tekst/fontverwijzingen, met overlap samen 181 bestanden. Hun volledige bestandshashes en functiehashes blijven verankerd. Dynamisch samengestelde texturenamen worden niet als volledig statisch opgelost voorgesteld; alle oorspronkelijke bestanden blijven daarom aanwezig.

## Atlassen, schaal en animatie

| Onderdeel | Oorspronkelijk contract |
|---|---|
| Tegels | `tiles.png`: 80 kolommen van 16×16; `pixel_landscape.png`: dezelfde 80 typen met acht rijen van 32×32. De bestaande tegelindices blijven leidend. |
| Bomen | `pixel_canopies.png`: acht kolommen van 48×64 en drie rijen voor gewone boom, den en wilg; de stam en kroon hebben verschillende tekenlagen. |
| Water | `pixel_water.png`: vier frames van 32×32 voor vier waterrijen; de wereld heeft daarnaast procedurele oevers, stroomtekens, watervallen en stoom. |
| Speler | Legacy 48×64, native 96×128: drie poses × vier richtingen; de bedoelde wereldbox blijft 32 pixels. |
| Menselijke NPC's | 35 native sheets van 96×128; oudere sheets zijn vaak slechts 32×16. Hun native indeling mag dus niet uit de fallbackafmetingen worden afgeleid. |
| Haar | `character_hair.png`: 90 stijlen, één 32px-vak per stijl en vier richtingsrijen; 2880×128. |
| Kleding en gear | `character_clothes.png`: 24 kledingstukken plus vier gearmaskers, telkens drie poses × vier richtingen; 2688×128. |
| Overige atlassen | Vijanden, bazen, props, iconen en meubels gebruiken uiteenlopende vakmaten, onder andere 16, 24, 32, 48 en 64 pixels; originele bronselectie en catalogusvelden blijven leidend. |

`Art.detailed()` kiest waar aanwezig `pixel_<naam>`, terwijl `DrawUtil.sprite()` dezelfde bestemmingsrechthoek behoudt. Unity moet bronrechthoeken van bovenaf naar zijn UV-coördinaten omzetten. Point sampling, geen mipmaps en geen verliesgevende texturecompressie behouden de pixelranden; importinstellingen mogen haar- en kledingatlassen niet verkleinen.

Richtingsrijen zijn onder, boven, rechts, links. De speler gebruikt stilstandkolom nul, loopkolommen één/twee op `walk_time * 9`, en rolkolom één. Menselijke NPC's gebruiken stilstand nul en loopkolommen `1 + int(clock * 5) % 2`. Dieren en monsters hebben eigen framekeuzes; een uniforme loopclip mag hun oorspronkelijke aanvalspose of uitzonderlijke vakmaat niet vervangen.

De volgorde is achterste rugkleding, lichaam, conditionele gear/kleding, haar, procedurele ogen, hoofdgear/hoed en zichtbare gedragen uitrusting. De rugzak, cape, mantel en sjaal hebben verschillende regels; kleding kan gearmaskers onderdrukken. Ogen, handgereedschap, wapens en sommige speciale gear worden deels met tekenprimitieven opgebouwd. Het voetanker en de oorspronkelijke botsingen mogen door de nieuwe weergave niet verschuiven.

## Werk dat geen los PNG-bestand is

De oorspronkelijke bron maakt een 160×16-equipmenticoonatlas en een 128×128-radiale lichttexture in geheugen. De landschapscode maakt chunks, oeverranden, schaduwen en afzonderlijke boomkronen op basis van de geladen kaart. De fase-5-resourceverwijzing met een leeg pad bewaart hun pixels niet.

Daarnaast tekenen de bestaande functies gewassen, irrigatie, mest, werkfeedback, meubels, hekken, rotsen, watervallen, geisers, stoom, fonteinen, projectielen, wapens, effecten en UI-elementen. Een gerenderd voorbeeld bewijst die gekozen toestand; het bewijst niet iedere toekomstige combinatie, tijdstap of gevechtsovergang. De volledige dynamische integratie hoort bij de geplande gameplay-, wereld-, sfeer- en UI-fases 7–24. Behouden broncode wordt niet als uitgevoerde Unity-code aangemerkt.

De [gegenereerde referentie](../presentation/graphics-generated/index.json) bevat twaalf daadwerkelijk door Godot gemaakte textures: 2898 samples en 57 benoemde, bemonsterde animaties, plus de runtime-equipmenticonen, lichtgradient en gerasterde game-icoon. De samples bestaan uit 1656 haar-/kleding-/gearweergaven, 768 oogweergaven, 448 effecten/gereedschapsposebeelden, tien water-/rotsbeelden en zestien gewasbeelden. Twee afzonderlijke GPU-processen produceerden dezelfde dertien volledige bestanden. De index bevat de exacte Godot-versie en LF-bronhashes van beide exporthandlers; gewijzigde exportcode maakt de opname ongeldig.

Bij visuele en alphacontrole bevatten alle appearance-, effect-, omgevings- en gewassamples beeld en raakt geen sample de rand van zijn vak. De 192 lege oogweergaven zijn de bedoelde achteraanzichten: de oorspronkelijke oogfunctie tekent daar niets. Bemonsterde zwaard-, boog-, werk- en rolbeelden behouden hun bronparameters; zij vervangen niet de latere state-machine. Ook de watervalbeelden zijn afzonderlijke tijdsamples, geen bewijs van een naadloze lus van één seconde.

## Audio en teksten

Alle 138 originele WAV's zijn mono PCM16 op 22.050 Hz: 126 sound-ID's en twaalf muziektracks, samen circa 618,61 seconden. Import moet frames, duur en ID's behouden. De bron gebruikt acht SFX-spelers, gescheiden Music/SFX-bussen en een Master-mute; muziek en omgevingslussen lopen van sample nul tot het werkelijke aantal frames. Muziek-, regen- en sfeerfades, volume en pitch zijn gedrag dat naast het alleen importeren van clips moet worden bewezen.

`translations/en.po` bevat 3187 volledig vertaalde NL/EN-items, twaalf meervouditems en negen contextitems. Vertaling vindt eenmaal plaats, vóór het invullen van `%s`/`%d`/precisievelden en `{naam}`-tokens. Context, meervoud, procentescape, brontekst en placeholdervolgorde moeten behouden blijven. Opslag van de taalkeuze en complete menu-interactie blijven onderdeel van hun latere fases.

## Het bestaande lettertype

De game heeft geen eigen getrackt TTF/OTF-bestand. Het echte gamefont komt uit `ThemeDB.fallback_font`: de [Godot-4.4.1-themabron](https://github.com/godotengine/godot/blob/4.4.1-stable/scene/theme/default_theme.cpp) en [bouwregel](https://github.com/godotengine/godot/blob/4.4.1-stable/scene/theme/SCsub) gebruiken `OpenSans_SemiBold.woff2`. De [officiële fontinventaris](https://github.com/godotengine/godot/blob/4.4.1-stable/thirdparty/README.md#fonts) vermeldt Open Sans SemiBold 1.10 onder Apache 2.0.

Het nieuwe hulpmiddel haalt de daadwerkelijke bytes op uit exact Godot 4.4.1, uitsluitend in een tijdelijke projectkopie met geverifieerde UUID-testopslag. De 46.392 bytes moeten overeenkomen met de vastgelegde upstreamhash. WOFF2 wordt voor Unity uitgepakt naar TTF met vastgezette fontTools/brotli-versies en zonder de timestamp opnieuw te berekenen. Alle ongecomprimeerde fonttabellen moeten gelijk blijven, uitgezonderd het containerafhankelijke `head.checkSumAdjustment`. De oorspronkelijke WOFF2, licentie, copyrightmelding, glyphmetingen en tabelhashes blijven beschikbaar.

De PO-teksten gebruiken 104 verschillende tekens. Zes symbolen (`← ↑ → ↓ ■ ●`) ontbreken in het primaire Open Sans-font; de oorspronkelijke Godot-code staat OS-fontfallback toe. Dit is een bestaande afhankelijkheid, geen zes nieuw toegevoegde tekens. Voor die zes tekens wordt nu expliciet het [met Godot meegeleverde DroidSansFallback](https://github.com/godotengine/godot/blob/4.4.1-stable/thirdparty/README.md#fonts) onder Apache 2.0 behouden als `BlueMapAssets/Fonts/FallbackFont`, met dezelfde WOFF2/TTF-tabelcontrole. Het primaire font wordt niet gewijzigd. Deze aanvullende keuze maakt de zes symbolen platformonafhankelijk; hij is geen claim dat Godot vroeger op iedere computer hetzelfde aanvullende font gebruikte. Behoud van hetzelfde primaire fontgezicht bewijst bovendien nog geen pixelgelijke font-rasterisatie, kerning, regelafbreking en volledige menulay-out tussen beide engines.
