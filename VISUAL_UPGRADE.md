# Eigen pixelart-upgrade — 0.28.0-preview

Op verzoek van sjors: de bestaande game grafisch verbeteren binnen zijn pixelartstijl, met rust, ruimte en leesbare gameplay als uitgangspunt.

## Gebouwd
- Native 32×32 terreinplaat: 80 bestaande tegelidentiteiten met acht deterministische materiaalvarianten; de fysieke wereldtegel blijft exact 32×32.
- Eigen gras-, pad-, zand-, sneeuw-, water-, hout-, steen-, rots-, struik-, gevel-, raam- en deurmaterialen; overige tegelkunst krijgt passende grondkleuren en selectieve pixelaccenten.
- Grotere gelaagde loofbomen, besneeuwde dennen en wilgen met eigen 48×64 kruinen, gesorteerd op stamhoogte; stammen en botsingen blijven op hun oorspronkelijke plaats.
- Kruinen worden lokaal doorzichtig rond de speler en nabije NPC’s, werkplekken en vijanden zodat gameplay zichtbaar blijft.
- Organische padranden, oeverranden, dakafwerking en contactschaduwen worden in stukken van 512×512 gecacht en uitsluitend bij terreinwijziging herbouwd.
- Vier rustige waterframes worden alleen binnen de cameraruimte getekend; geen zware schermshaders toegevoegd.
- Originele nieuwe groene/blauwe/rode slijmen en fijnere pixelaccenten voor speler en bestaande NPC-/vijandsprites, met behoud van hun identiteit, framevolgorde en kledingcoördinaten.
- Gedetailleerde eigen wijnvaten en bijenkasten, pixelbijen, meer dakmateriaal, fonteinaccenten, bijpassend titelterrein en scherpe menuvensters; de zeven beroepskleuren en werkplekinterfaces blijven behouden.
- Nachtelijke raamgloed sluit aan op het nieuwe glas.
- Getij, levende bruggen en de geheime boekenkast vernieuwen de visuele oever/schaduwcache wanneer het echte terrein verandert.

Alle oorspronkelijke PNG’s blijven beschikbaar; de spritehelper gebruikt de nieuwe detailplaten terwijl directe UI-tekening oude atlasmaten behoudt. De grafische laag verplaatst op zichzelf geen kaart, route, spawn, objectslot, buit, recept of saveformaat. De aanvullende, uitdrukkelijk gevraagde verbeteringen aan moerasroutes en de zuidelijke meeruitgang staan in [BUGFIX_WATERWORKS.md](BUGFIX_WATERWORKS.md).

## Reproduceren en controleren
`python tools/art_x_visual.py` bouwt uitsluitend deze eigen beelden opnieuw met Pillow; er zijn geen externe afbeeldingen of downloads nodig. `tools/make_art.py` neemt dezelfde uitbreiding op.

`tools/run_tests.py GODOT --keep` draait alle speltests in een afzonderlijk gecontroleerd UUID-opslagpad. `visual_upgrade_test.gd` controleert alle atlasbotsingen en alle 36 kaarten, kruinzichtbaarheid, cachegedrag, getij en boekenkastvloer.

`tools/preview_visual.py GODOT` rendert alle gebieden dichtbij en uitgezoomd, dorpbeelden op 960×540 en 1600×900, nachtbeelden en animatieparen. `--source PAD` maakt een vergelijkbare nulmeting vanuit een eerdere bronkopie.

Prestaties: 90 geforceerde tekenframes per scène op dezelfde computer; diagnostische wachttijden inclusief het gebeurtenislusverloop, geen hardware-onafhankelijke FPS-garantie. Vergelijking met 0.27 en controlebeelden worden bij de lokale versie vastgelegd.

## Grenzen en vervolg
Niet ieder oud personage of iedere regionale decoratie is volledig opnieuw ontworpen. Grotere kruinen overlappen zoals in een bos; nabijgelegen belangrijke acteurs worden onthuld. Obstakeltegels behouden hun oorspronkelijke maat. De bestaande kleine resource-waarschuwing bij afsluiten blijft in de logs; script-/parsefouten worden als mislukking behandeld.

Deze extra grafische ronde verbruikt geen fase van DEVELOPMENT_LIVING_GAME.md; het volgende gewone go blijft fase 2 (voorraad en opbergen).
