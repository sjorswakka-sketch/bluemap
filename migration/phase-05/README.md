# Fase 5 — de geladen wereld vastgelegd

De oorspronkelijke Godot-loader heeft alle 37 kaarten werkelijk opgebouwd. De export bevat 59 benoemde, synthetische profielen en 162 kaartopnamen: een nieuwe uitgangssituatie en volledige testvoortgang voor iedere kaart, plus gerichte veranderde toestanden. Dit is de wereldreferentie voor de volgende Unity-fases; de Unity-gameplay is nog niet overgezet.

## Wat bewaard blijft

- Het complete terrein van 49.758 tegels in de nieuwe uitgangssituatie, met daadwerkelijke atlaskeuzes, 640 native tegelvarianten en hun botsingspolygonen.
- Alle 905 bestaande registry-objectslots en 75 tijdens laden achteraan toegevoegde vindplaatsen, inclusief tien uitgeschakelde slots; indices en bestaande opslagsleutels verschuiven niet.
- Werkelijk gemaakte nodes, ook rechtstreekse toevoegingen van directors en geneste, niet-gescripte colliders; lokale en globale transformaties, botsingslagen, uitgeschakelde vormen, zichtbaarheid en native lichtgegevens.
- Benoemde aankomsten met zowel het bedoelde middelpunt als het door de oorspronkelijke helper vrijgemaakte veilige punt. Dit controleert de helper en vrije ruimte; het is geen doorlooptest van iedere deur.
- Toestand vóór en na laden en projecteren, inclusief de oorspronkelijke voortgangsmigraties, woning, erf, landbouw, irrigatie, productie en oorspronkelijke timers.
- Een aanvullende identiteitentabel voor de werkelijk geladen array en runtime-objecten, gekoppeld aan de vaste fase-4-identiteiten. Een tijdelijke nodeverwijzing krijgt geen verzonnen blijvende opslag-ID.

De gegevens staan in [world/index.json](../world/index.json), met één gedeelde tegeldefinitie en afzonderlijke kaartbestanden. [world-coverage.json](../world-coverage.json) verankert alle 24 producentfamilies, 34 loaderafhankelijkheden, 20 registry-voorbereiders en 49 objecthandlers aan de ongewijzigde bron. [COVERAGE.md](COVERAGE.md) beschrijft de dekking en grenzen.

## Gerichte toestanden

Opnamen omvatten de herstelde moerasbrug en afzonderlijke sluizen, drooggelegde oevers, vier getijfasen en de tijdelijk opengehouden bezette zandbank, het tijrad, kustkeuzes, geheime bibliotheekvloer, routeherstel, bewoners en avondgasten. De Wachter heeft zijn zes werkelijk aangemaakte pilaren of zijn juiste beloningskist, inclusief geopende beloning en de variant bij volledige hartcapaciteit.

Andere profielen leggen verplaatste meubels en opgeslagen verlichting, verplaatste/ingepakte werkplaatsen, automatische erfpoorten, droge/aangesloten/onderbroken kanalen, rijpe gewassen, bloemen rond bijen en opgeslagen mestdrops vast. Gerichte inhoudscontroles testen de bedoelde verschillen naast de algemene structuur- en hashcontroles. Synthetische fixtures bewijzen de opname van die toestand, niet dat iedere combinatie via normaal spelen bereikbaar is.

## Formaat en reproduceerbaarheid

Het nieuwe wireformaat heet **bluemap.world.variant.v2**. Het bewaart ook StringName, NodePath, getypeerde vectoren en dictionarysleutels, ingevoegde volgorde, ingepakte arrays, vormen en transformaties. Alle scriptvelden worden gelezen; onbekende waarden veroorzaken een zichtbare fout. Verwijzingen naar nodes worden structurele adressen. Resources blijven verwijzingen; tijdelijke native handles krijgen een expliciete data-only markering en worden niet uitgevoerd. De fase-4-catalogi blijven ongewijzigd.

Godot schrijft op Windows en Linux soms verschillende decimale teksten voor exact dezelfde IEEE 754 Float64-bits: bijvoorbeeld `0.29999999999999999` en `0.299999999999999989`. Alleen de tekst in expliciet getypeerde floatwaarden krijgt daarom één canonieke weergave, met controle dat teruglezen dezelfde 64 bits oplevert; ook het teken van nul blijft behouden. Er wordt geen tolerantie of afronding naar minder precieze waarden gebruikt. Integers, ID's, gewone tekst en de volgorde van arrays en dictionaryparen blijven exact behouden. Na deze verliesloze normalisatie worden hashes opnieuw berekend en moeten de volledige bestanden nog steeds exact gelijk zijn, zowel tussen afzonderlijke opnamen als tegenover de vastgelegde referentie.

Klok, AI, invoer en beweging staan stil. Een beperkte, brongecontroleerde lijst methoden projecteert opgeslagen gevolgen zonder tijd te laten verlopen; dit is geen algemene physicsstap. Uitgestelde toevoegingen en vormwijzigingen worden verwerkt en opnieuw bevroren. Aanroepen die zelfs bij nul tijd gevechten of verhaalovergangen kunnen starten, zoals diepte_seal, zijn uitgesloten.

Het opnamehulpmiddel vereist exact Godot 4.4.1 stable (49a5bc7b6), maakt een tijdelijke projectkopie en controleert eerst de unieke testopslag. Persoonlijke saves worden niet geopend of gepubliceerd. Twee afzonderlijke engineprocessen moeten dezelfde volledige bestandenverzameling produceren; de oorspronkelijke scripts en scenes worden vóór en na vergeleken. Het resultaat is aan de referentiecommit, originele bronhashes en beide exporthandlers gekoppeld. Groei en productie krijgen geen offline inhaalsimulatie.

Voor offline controle vanaf de repositorywortel:

```text
python tools/migration_world_data.py --directory migration/world
python tools/check_world_witnesses.py --directory migration/world --output <nieuw-extern-rapport.json>
python tools/migration_runtime_ids.py --directory migration/world --output <nieuw-extern-identiteitenrapport.json>
python -m unittest discover -s tests/migration -p 'test_*.py' -v
```

Volledig opnieuw opnemen en vergelijken, altijd met het veilige hulpmiddel:

```text
python tools/record_migration_world.py <Godot-4.4.1-executable> --check --evidence-dir <nieuwe-lege-externe-map>
```

De migratieworkflow herhaalt dit in twee Linux-engineprocessen en vergelijkt hun volledige resultaat met de op Windows vastgelegde referentie. De drie bestaande jobs voor bronbehoud, Godot-coexistentie en de eerdere Unity-proefdownload blijven aanwezig.

## Bewijs en grenzen

[verification.json](verification.json) bevat de lokale meetwaarden, bronbehoud en controles: twee identieke exports van 164 documenten, 391 gerichte gevolgcontroles en 233 migratietests (231 geslaagd; twee symlinkfixtures vragen rechten die op deze Windows-werkplek niet beschikbaar zijn). De native referentie bevat 593 veilige benoemde aankomsten over alle opnamen. [world-witnesses.json](world-witnesses.json) en [runtime-identities.json](runtime-identities.json) beschrijven de vastgelegde gevolgen en werkelijk aangetroffen sleutels.

Daarnaast zijn 13 bestaande Godot-suites opnieuw geslaagd: toegangspunten, meldingen/moeras, levende wereld, eerste route, huis, erf, boomgaard, kustverhalen, getij, homestead, Diepte, water en atlas. Bekende Godot-opruimwaarschuwingen bij afsluiten blijven in de logs zichtbaar; de controle accepteert uitsluitend de bestaande exacte resource-exitmelding en geen script-, parse- of andere enginefouten.

Niet iedere animatiefase, AI-route, aanval, weerovergang of arenagolf is opgenomen. De oorspronkelijke code en bronankers blijven daarvoor behouden. UI-bomen worden expliciet apart geregistreerd; tijdelijke gegenereerde textures zijn geen geïmporteerde pixelart. Unity-rendering, C#-uitvoering, gameplaygelijkwaardigheid en saveconversie volgen in hun eigen fases. De eerdere Unity-proefdownload blijft geldig omdat de bouwinputs niet wijzigen; deze gegevensfase heeft geen nieuwe exe nodig.

Het volgende **go** start fase 6: de eigen graphics, animatielagen, geluiden en teksten naar Unity brengen. De speelbare Godot-game, Claude-branch en persoonlijke saves blijven behouden.
