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

## Ideeën voor later
- Meer zij-opdrachten en personages
- Een vijand die muren doorbreekt, magie als derde wapen, schilden en uitrusting
- Een echte wereldkaart met alle gebieden
- Meerdere talen
- Echte pixel art van een kunstenaar en opgenomen muziek: vervang gewoon de bestanden in `assets/`

Elke wijziging eindigt met een geslaagde `sh tools/run_tests.sh`.
