# Eigen kustavonturen · 0.23.0-preview

Vier optionele verhalen gebruiken de ruimte van de bestaande kustregio.

- **Een bericht zonder afzender:** lees het logboek op Meeuweneiland, bekijk
  schelpgruis in het wrakhout en donker slib bij Zilvermonding. Trek in het
  havenwerkboek een conclusie. Fout antwoorden kost niets; de juiste conclusie
  plaatst een boei naast de werkkade. Waarnemingen mogen vóór het verhaal beginnen.
- **De oude loodsenroute:** de paal boven het havenpad op Lichtkaap wijst naar
  een gespleten rots, bleek zoutgras en de beschutte rustplek. Lees de vormen
  in volgorde, zonder timer of voorwerpen te verzamelen. Zet het lage windscherm terug.
- **Water dat weer loopt:** neem de westelijke zijroute bij Zilvermonding naar
  de Tijholte. Het tijrad heeft gereedschap ter plaatse. De herstelanimatie duurt
  1,8 seconde; Terug, lopen en een kaartwissel annuleren zonder kosten.
  Alleen voltooiing droogt de korte middenbrug.
- **De Schelpenhoeder:** na herstel kies je bij de sluistafel een rustige poel
  of water voor het havenrad met een vrijwillige krachtproef. Vrede laat riet
  groeien; de voltooide proef laat het havenrad draaien. Verhalen geven elk
  één keer 40 held-XP. De hoeder geeft bij een gewonnen proef daarnaast zijn
  gewone 26 vijand-XP; er is geen exclusieve gear of verzamelplicht.

De keus voor de poel is definitief. Een begonnen krachtproef kun je verlaten;
bij de sluistafel blijft vrede mogelijk zolang de proef niet gewonnen is.
Na een voltooide uitkomst verschijnt de vijand niet opnieuw.

## De Tijholte

Eén ruime zijgrot met een permanent open zuidelijke passage en lange brug.
De korte brug is een extra route na herstel. Krab en licht bewaken alleen de
noordwestelijke zijpoel; de hoeder wacht in het noordoosten. De haven, kaap,
eilanden en terugwegen krijgen geen vijanden of respawnende verzamelobjecten.

- **Rotskrab:** vastgelegde amberkleurige schaarwaaier, 0,95 seconde waarschuwing,
  korte slag, 1,6 seconde herstel. Geen contactschade.
- **Getijdenlicht:** aangekondigde uitdijende ring met een vaste veilige sector.
  De ring gaat in 0,7 seconde naar buiten, raakt maximaal eenmaal en stopt bij
  territoriumgrenzen en muren. Het open segment volgt je niet achteraf.
- **Schelpenhoeder:** twee afzonderlijk aangekondigde haakse schaarbogen, daarna
  lang herstel. Geen opgesloten arena, opgeroepen extra vijanden of aanval op de gang.

Aanvallen in dezelfde poel wachten op elkaar. Terugtrekken annuleert waarschuwing
en schade en laat de dieren terugkeren. Grondwaarschuwingen staan onder sprites
en worden tot de kamer begrensd. Bestaande rollen, wapens, pantser en Nieuw spel+
blijven gelden. Vijand- en verhaalvlaggen passen in het bestaande saveformaat.

## Eigen productie en controles

python tools/art_x_adventures.py genereert de grot, vier spritesheets,
twee tegels en vijf korte, zachte geluiden volledig uit eigen code. De eerste
78 atlasvakken blijven pixel voor pixel behouden. De algemene tegelgenerator
kent ook de twee nieuwe tegels; oude kaartobjecten behouden hun index.

coastal_adventures_test test echte interacties, muis, toetsenbord en
gesimuleerde controllerinvoer, aanwijzingen, fout antwoord, eenmalige beloning,
echte grotportal, zuidelijke looproute, annuleren, kaartwissel en opgeslagen gevolgen.
coastal_combat_test test levende waarschuwingen, schade en ontwijken,
de veilige ringsector, gecombineerde aanvallen, terugtrekken, beide hoederslagen,
eenmalige afronding en Nieuw spel+. De bestaande volledige testsuite blijft gelden.

Visuele controle gebruikt aparte saves, NL/EN en 960×540, 1152×648 en 1600×900.
Geen echte spelerssave of fysieke controller gebruikt. Fase 5 (streekmaterialen,
recepten en terugkeerplek) wacht op de volgende go.

Hoge werkprops en het voltooide windscherm hebben een kleine, echte voetafdruk.
Verborgen props en losse aanwijzingen blokkeren niets. Laden binnen een nieuwe
voetafdruk zoekt veilig vrij terrein; de brede routes blijven open.
