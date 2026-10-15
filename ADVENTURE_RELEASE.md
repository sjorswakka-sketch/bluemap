# Bluemap Quest 0.25 — fase 6

Deze fase rondt de kustronde af met samenhang, gemeten prestaties en distributie.
Geen nieuwe wereldinhoud: alle 35 kaartdefinities, kaartverrijkingen, materialen,
monsters en assets blijven dezelfde als in 0.24. Geen extra vijanddruk, buitenobjecten,
verzamelquota of dagelijkse klussen. De hoge looproutes en gratis veren blijven vrij.

## Gevonden en hersteld

- Alle twaalf muziekstukken gebruikten het aantal gecomprimeerde bytes als aantal
  samples. QOA maakte de lussen daardoor circa vijfmaal te kort: 5–9 seconden in
  plaats van de volledige 26–46 seconden. Het eindpunt komt nu uit speelduur ×
  samplefrequentie, ook geldig bij stereo. De bestaande eigen audio blijft intact.
- De geleende landingslijn in de Getijdenbaai controleerde gereedschap en vrije
  landing alleen bij vertrek. Bij verdwijnen van de lijn of bezetting van de
  landing tijdens de presentatie keert de speler nu terug naar het vertrekpunt.
  Succesvolle aankomst wist beweging/knockback, reset de camera en geeft dezelfde
  korte oriëntatietijd als de andere veilige overgangen. Geen kosten of beloningen.
- Op 960×540 konden titel, pauze en bediening buiten beeld vallen; met Nieuw spel+
  was het pauzemenu extra hoog. De panelen passen nu binnen de viewport. Titel,
  intro en epiloog behouden samen hun oorspronkelijke compositie bij schalen.
  Muisklikken gebruiken de echte geschaalde Control-posities; focus blijft werken.
- Project, Windows-exportinstellingen, downloadleeswijzer en README zijn 0.25.
  CI controleert versies en NL/EN vóór de speltests. Na export controleert hij de
  echte download-ZIP: CRC, exact de exe en leeswijzer, identieke leeswijzer en een
  Windows-x64 PE-header. Dit bevestigt pakketinhoud, geen fysieke start op iedere pc.

## Samenhang en saves

De nieuwe coast_roundtrip_test gebruikt zelfgemaakte versie-1-savefixtures,
met en zonder uitgespeeld hoofdverhaal. Via de echte reisborden en veerlogica:
kust → haven → Meeuweneiland → Getijdenbaai → kust. Na elke echte autosave wordt
het spel geladen en de wereld opnieuw opgebouwd. Items, hartjes, geld, ervaring,
oude verzamelsleutels en voltooiing blijven gelijk. Daarna is Greta bereikbaar.
Een gecombineerde kustsave bewaart werkplaatslocatie, opslag, gear, meubels,
vreedzame poel, herstelde grotbrug en eerdere streekgevolgen. Nieuw spel+ gebruikt
het bestaande beleid: gedragen/bezitbare gear mee, streekverhalen en opslag reset.

De bestaande suite controleert daarnaast het nieuwe begin, het hoofdverhaal,
Diepte/eindspel, optionele streken, fysieke kaartspawns, beide rivieroevers,
verhalen en vijandpatronen. De tests gebruiken echte systemen en invoer waar
vermeld; routefixtures zijn geen claim dat één mens het hele spel heeft uitgespeeld.
Geen nieuwe save-indeling, migratie of wijziging van de echte spelerssave.

## Reproduceerbare controle

Gebruik altijd tools/run_tests.py: deze verifieert een eigen UUID-save-map.
De drie nieuwe regressies zijn audio_release_test, coast_roundtrip_test en
release_ui_test. Audio wordt echt tot voorbij het einde afgespeeld via de dummy
backend; de test gebruikt echte verstreken tijd voor deze afspeelcontrole.
Release-UI: NL/EN, 960×540, 1152×648 en 1600×900, met NG+, controllerfocus,
een echte muisklik na apparaatwissel en bereikbare laatste remappingactie.

Eigen gereedschap (geen externe afbeeldingen, muziek of spelcode):

    python tools/audit_adventure.py /pad/naar/godot --label profiel
    python tools/audit_adventure.py /pad/naar/godot --preview --label beelden
    python tools/check_release.py
    python tools/i18n.py check

De audit kloont het project, verifieert de afzonderlijke save en bewaart JSON en
logs in een tijdelijke map. Een profiel heeft geen vaste FPS: het meet echte
frame-intervallen, synchrone kaartopbouw, tijd tot enkele stabilisatieframes,
Godot statisch geheugen en node-/objecttellingen. De eerste opstartwaarde bevat
engine/autoload-initialisatie; het is geen stopwatch van dubbelklik tot spelen.
TIME_PROCESS/TIME_PHYSICS_PROCESS zijn Godot-monitors die minder vaak verversen
zonder profiler; de frame-intervalmeting is de directe meetreeks.

Alle kaarten worden geladen, daarna negen scenario's bemonsterd (180 frames,
35 opwarmframes) met dorp, bos, moeras, dag/nacht, kust, grot en werkplaats.
Vier rondes van dertien kaartwissels eindigen steeds in het dorp voor vergelijking.
De preview maakt beelden van rustige aanlopen, dag/nacht, wereldgevolgen en menu's.
Meetbestanden en gerenderde beelden blijven buiten de Windows-download.

Grenzen: lokale ontwikkelbuild op Windows, Godot 4.4.1 Compatibility, RTX 4080 en
dummy-audio. Godot statisch geheugen is geen totale process-RAM of VRAM.
Frame-intervallen hangen ook af van scheduler, driver en achtergrondbelasting;
een snelle ontwikkel-pc bewijst geen minimumspecificaties. Geen claim over fysieke
controllers, hoorbare luidsprekerkwaliteit, iedere resolutie of alle pc's.
De nulmeting meldt al een resource-opruimwaarschuwing bij het afsluiten; de audit
controleert daarom ook node-/objectgroei tijdens herhaald reizen. Geen scriptfout.
Lange tracks blijven gericht ongemoeid: de nulmeting bevat circa 3,8 MB gecodeerde
muziek, met stabiele node-aantallen. Er is geen onderbouwing voor een grotere
streamingverbouwing in deze fase.

## Vastgelegde meting op deze pc

Eén nulmeting en één eindmeting, geen gemiddeld prestatierapport van meerdere pc's.
Engine/autoload klaar: 3,45 → 3,56 s. Eerste wereld inclusief vijf frames:
1,70 → 1,99 s; dit zijn koude script-/renderinitialisaties en achtergrondvariatie.
Er wordt geen snelheidswinst geclaimd. Grootste synchrone kaartopbouw: Zilvermonding,
119 → 112 ms; de bestaande fade-out van 250 ms verbergt deze kaartopbouw.
De negen bemonsterde scènes hebben de volgende echte frame-intervallen, in ms:

| Scène / wereldtijd | Mediaan | p95 |
| --- | ---: | ---: |
| village / 0.5 | 6.99 | 7.57 |
| village / 0.9 | 6.99 | 7.42 |
| forest / 0.5 | 7.00 | 7.92 |
| kruipmoeras / 0.7 | 7.00 | 7.76 |
| harbor / 0.5 | 7.00 | 7.30 |
| harbor / 0.9 | 6.99 | 7.37 |
| headland / 0.9 | 7.00 | 7.26 |
| tidal_hollow / 0.5 | 6.99 | 7.41 |
| coast_workshop / 0.5 | 6.99 | 7.31 |

Na vier rondes blijft de eindmeting op 285 nodes en 2.978 objecten, zonder
weesnodes; statisch geheugen 82.080.391 → 82.082.851 bytes (circa 78,28 MiB).
De nulmeting had eveneens constante node-/objecttellingen. De 3.778.888 bytes
gecodeerde muziek blijven gelijk; nu gebruiken alle twaalf stukken hun volle lengte.

## Hierna

Fase 6 beëindigt dit plan. Eerst het complete avontuur beoordelen en dan een nieuw
faseplan kiezen; een volgende go start niet automatisch ongeplande nieuwe content.
