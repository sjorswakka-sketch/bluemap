# Roadmap

Richting: fantasy-RPG met gevechten, verhaal en NPC's, verkennen en verzamelen/upgraden,
pixel art, en te delen met vrienden en de community.

## Klaar
- [x] **Fase 1: prototype en pixel art.** Lopen, zwaard, slijmen, HUD, game over, loopanimaties
- [x] **Fase 2: delen.** Windows-versie (.exe) met automatische build via GitHub, titelscherm, pauzemenu, geluid en muziek
- [x] **Fase 3: gevechten.** Ontwijkrol, drie zwaarden, vleermuizen, skeletten, golems, de Slijmkoning met drie fases,
      schadegetallen, schermschud, hit-stop
- [x] **Fase 4: verhaal en NPC's.** Gesprekken met keuzes en vertakkingen, tien personages, hoofdopdracht en drie zij-opdrachten,
      opdrachtenlogboek
- [x] **Fase 5: verkennen.** Acht gebieden met overgangen, poorten en sleutels, kisten, verborgen plekken, altaren, belichting in
      donkere gebieden, kaartje
- [x] **Fase 6: verzamelen en upgraden.** Inventaris, winkel, smid, hartcontainers, laarzen, opslaan en laden
- [x] **Einde.** Intro, eindbaas, eindscherm met herstelde Blauwe Kaart, epiloog, statistieken en aftiteling
- [x] **Controller en volledig scherm**
- [x] **Fase 7: uitbreidingen.** Zes uitbreidingen, elk als eigen module (scripts/data/ext/):
  - [x] **Boog en pijlen.** Tweede wapen, doelwit-puzzels in bos en ruïne, Tessa's schietbaan
  - [x] **Nieuwe vijanden.** De magiër (teleporteert, tovervonk) en de slijmspuwer (waaier van slijmballen)
  - [x] **Het Zilvermeer.** Visspel, de Gouden Karper, een bibliotheek met oude boeken, drie personages en twee opdrachten
  - [x] **Wereld.** Dag en nacht, regen, slapen in de herberg, snel reizen tussen altaren, 32 prestaties en een beestenboek
  - [x] **De Diepte en Nieuw spel+.** Na het einde een geheime dungeon onder de tempel, de geheime baas De Vergeten Wachter
        met drie fases, het Sterrenzwaard, en Nieuw spel+ met je beste spullen tegen sterkere vijanden
  - [x] **Arena.** Golven vijanden, drie rangen (Brons, Zilver, Goud), publiek, trofeeën, titels en beste tijden
- [x] **Talen.** Vertaalsysteem (gettext, `translations/en.po`, `tools/i18n.py`), taalknop op het titelscherm en in het
      pauzemenu. Nederlands is de brontaal, en het hele spel is in het Engels vertaald

## In de 0.5.0-preview
- [x] Sneller lopen op paden, trager op zand en zes soorten voetstappen
- [x] Sprinten met stamina, met behoud van de bestaande ontwijkrol
- [x] Zeven herkenbare gebouwexterieurs met symbolen en eigen details
- [x] Kruidenzoeken, houthakken, mijnbouw, vissen, smeden, alchemie en koken
- [x] Verzamelplekken, blijvende beroepsvoortgang, gereedschap en bruikbare recepten
- [x] Beroepenmenu en een inventaris die alle voorwerpen bereikbaar houdt
- [x] Claude's taalpakket geïntegreerd; nieuwe bediening en beroepen ook vertaald

## In de 0.5.1-preview
- [x] Alle losse voorwerpen magnetisch, zonder volle stapels of hartjes te verliezen
- [x] Werk-, rust-, sprint- en drinkanimaties; gereedschap ook bij het afronden gecontroleerd
- [x] Richtkruis voor muis en rechterstick, onafhankelijk van lopen
- [x] Opgeslagen toetsen- en controllerinstellingen via titel- en pauzemenu
- [x] Automatische apparaatwisseling, consistente menu's, rasterselectie en klikbediening

## In de 0.5.2-preview
- [x] Grotere geanimeerde fontein in het midden van het dorpsplein
- [x] Heldenervaring via gevechten en opdrachten, met een zichtbare XP-balk en muntbeloningen
- [x] Voortgangstabblad met beroepen, uitrusting en duidelijke volgende upgrades

## In de 0.5.3-preview
- [x] Vijf nieuwe uitrustingsslots met tien koopbare of maakbare stukken en opgeslagen keuzes
- [x] Uitrustingsmenu met bonussen, vereisten en bediening voor muis, toetsenbord en controller
- [x] Kijkrichting volgt lopen; aanvallen en schieten volgen onafhankelijk het richtkruis

## In de 0.6.0-preview
- [x] Het IJsdal: een besneeuwd bergdorp ten noorden van het Dauwbos, met eigen sneeuwklimaat, bevroren meer,
      mijnhoek en een altaar voor snel reizen
- [x] Sneeuwtegels, dennen, ijs en sneeuwvoetstappen; sneeuwvlokken en een koude tint door de dag-nachtcyclus
- [x] Winterse grondstoffen: ijsbloemen, winterbessen, dennenhout en ijskristal, met een vorstelixer (alchemie)
      en wintergloed (koken) als nieuwe recepten
- [x] Twee nieuwe opdrachten (Warmte voor IJsdal, De Ijswacht), drie nieuwe personages en de prestatie Sneeuwvoeten
- [x] Richtkruis laat los zodra de linkerstick weer een nieuwe looprichting geeft

## Ideeën voor later
- Meer zij-opdrachten en personages
- Een vijand die muren doorbreekt, magie als derde wapen en schilden
- Een echte wereldkaart met alle gebieden
- Nog meer talen (een PO-bestand erbij, zie de README onder "Talen")
- Echte pixel art van een kunstenaar en opgenomen muziek: vervang gewoon de bestanden in `assets/`

Elke wijziging eindigt met een geslaagde `python tools/run_tests.py <godot>` in een tijdelijke spelkopie.
