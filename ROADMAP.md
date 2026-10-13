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
- [x] De Dorstvallei: een snikhete woestijnvallei ten oosten van het Dauwbos, met dwarrelzand, een warme gloed,
      een oase, cactusvelden en zandsteenklippen, en een altaar voor snel reizen
- [x] Wilde dieren: woestijnvossen en zandhazen zijn vreedzaam, vluchten als je dichtbij komt (of raakt) en
      laten rauw vlees en dierenvachten vallen
- [x] Woestijngrondstoffen: cactusvijgen, zandkruid en zandsteen, met zandbalsem (alchemie) en braadstuk
      (koken) als nieuwe recepten
- [x] Twee nieuwe opdrachten (Vellen en vlees, Cactusvijgen voor Sana), drie nieuwe personages en de
      prestatie Zandvoeten
- [x] Het Dauwbos hersteld: de heggenmuren hadden geen openingen op de padcorridors, waardoor het grootste
      deel van het gebied (inclusief beide portalen en het altaar) onbereikbaar was. Een padvindingstest
      bewaakt nu de hele route
- [x] Uiterlijk: het menu heeft een achtste tabblad waar je geslacht, haarstijl (30 per geslacht), haarkleur
      (10), oogstijl (10) en oogkleur (8) kiest, met een live voorvertoning van drie kanten
- [x] Kleding: vijf eigen vakken (hoofd, rug, bovenlijf, onderlijf, voeten) die je óver je uitrusting draagt —
      puur voor de look, zonder bonussen. Vera de kleermaakster verkoopt twaalf stukken in Dageraadsdorp en
      elk gedragen stuk is in twaalf verfkleuren te verven. Alles wordt opgeslagen
- [x] Gebiedenpolis: Dauwbos, IJsdal en Dorstvallei zijn volledig opnieuw vormgegeven en zien er nu alle
      drie anders uit — een organisch mistbos met kronkelpaden, vijver en paddenstoelenkring; een bergdorp
      rond een groot bevroren meer met een herkenbare mijnhoek; en een kloof met zandsteenwanden, een groene
      oase als hart en cactusvelden bij de jachtgronden
- [x] Beroepsplekken liggen nu op logische plekken met passend decor: vuursteen bij rotspartijen, winterbessen
      bij besneeuwde struiken, cactusvijgen tussen de cactusvelden. Het Dauwbos heeft nu ook eigen plekken:
      paddenstoelen, kruiden, bessen, takken, een oude stronk en vuursteen bij de vijver
- [x] Alle veertien personages uit de uitbreidingen hebben hun eigen uiterlijk gekregen (outfits passend bij
      hun rol en gebied) in plaats van de sheets van de basis-personages; een padvindingstest bewaakt nu alle
      drie de gebieden

- [x] Basisgebieden gepolijst: Dageraadsdorp heeft een buurttuin met hekjes, kratten bij de smederij en
      meer groen in de hoeken; het Fluisterbos heeft extra bosvlekken en decor bij de beroepsplekken; het
      Zilvermeer heeft meer lelievelden, dikkere rietkragen en stenen bij de oeverplekken. De
      padvindingstest dekt nu ook deze drie gebieden

- [x] Donjons gepolijst: de Vergeten Ruïne heeft gebarsten vloeren en extra pilaren in de noordoostzaal,
      de Echo-grot heeft stalagmieten langs de wanden en kristaladers bij de mijnplekken, en de
      Kristaltempel heeft extra runen en tapijt in de voorhal. De padvindingstest dekt nu alle negen
      de overwelfde en open gebieden

- [x] Arena en De Diepte: de Kristalgangen hebben extra kristallen en runen op de kruispunten; de
      gevechtsarena's (Arena en Het Hart van de Kaart) en de al volledige arena-hal zijn bewust ongemoeid
      gelaten. Nieuw decor wordt voortaan alleen in wandhoeken geplaatst, zodat de zichtlijnen van
      magiërsbollen intact blijven; de padvindingstest dekt nu alle dertien gebieden

- [x] Dauwbos-alchemie: het Dauwbos heeft nu ook een eigen grondstof (dauwklauwen, drie plekken bij de
      vijver en de westelijke paden), een mistedrank (alchemie in de bibliotheek) en dauwsoep (koken in de
      herberg) als recepten, een nieuwe opdracht bij Mira (Bloemen in de mist) en de prestatie Mistvanger

- [x] Dagritme-geluid: elke buitenkaart heeft nu een achtergrondsfeer die meebeweegt met de klok —
      twaalf zelfgemaakte lussen (drie klimaten x vier dagdelen): vogels in de ochtend, ritselend blad
      overdag, krekels in de avond en een uil in de nacht; koude wind in het IJsdal en droge wind met
      insectengespin in de Dorstvallei. Bij een nieuw dagdeel loopt de sfeer zachtjes over; binnen is
      het stil

- [x] Menu-polis: de tabmarkering glijdt naar het gekozen tabblad en elke bladzijde faden en schuift
      zacht naar binnen bij een wissel; tabbladen en de sluitknop lichten op onder de muis; het gekozen
      voorwerp in je rugzak ademt zachtjes; en alle bladzijden delen nu dezelfde marges (buitenmarge,
      kopregel en bovenkant van lijsten)

- [x] Doorgangen zichtbaar: elke portal tekent nu een zachte, pulserende gloed met zwevende vonkjes,
      zodat je in elk gebied meteen ziet waar je naar een andere plek kunt. En elke doorgang tussen
      twee buitengebieden heeft nu een wegwijzer die het doelgebied noemt (vijf nieuwe borden in het
      Fluisterbos, bij het Zilvermeer, in het Dauwbos, het IJsdal en de Dorstvallei)

## Ideeën voor later
- Meer zij-opdrachten en personages
- Een vijand die muren doorbreekt, magie als derde wapen en schilden
- Een echte wereldkaart met alle gebieden
- Nog meer talen (een PO-bestand erbij, zie de README onder "Talen")
- Echte pixel art van een kunstenaar en opgenomen muziek: vervang gewoon de bestanden in `assets/`

Elke wijziging eindigt met een geslaagde `python tools/run_tests.py <godot>` in een tijdelijke spelkopie.
