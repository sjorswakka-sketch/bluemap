# Fase 3 — gevechten met meer mogelijkheden (0.13)

De bestaande boog, drie zwaarden, derde comboslag, schildwachter, flankeerder,
genezer, kristalkever, prismamot en steenluisteraar blijven bruikbaar. De uitbreiding
maakt voorbereiding, afstand, dekking en doelkeuze belangrijker. Geen nieuwe
verplichte grind, wapenaankoop of questpoort.

## Spelerkeuzes

Houd standaard **V / LT** vast en druk op de bestaande zwaard- of boogknop.
Deze modifier staat in Besturing en kan per apparaat worden gewijzigd. Oude
bedieningsbestanden worden aangevuld; bestaande eigen V/LT-toewijzingen gaan voor.
Er wordt dan een vrije G/Z of RT/R3 gekozen, of de actie blijft ongebonden als
geen van die knoppen vrij is. Geen dubbele actie op dezelfde knop.

| Techniek | Aanloop | Stamina | Effect en afweging |
|---|---:|---:|---|
| Hout: snelle steek | 0,18 s | 16 | 16 px extra bereik, smalle hoek, gewone schade |
| IJzer: breekslag | 0,42 s | 28 | brede hoek, 4 px extra bereik, 1 extra schade |
| Kristal: kristalsteek | 0,32 s | 24 | 34 px extra bereik, zeer smalle hoek, 1 extra schade |
| Boog: precisieschot | 0,65 s | 20 | 3 gewone schade, bereik 400 px, snelheid 420 px/s, één pijl |

Alle zwaardtechnieken openen een schild gedurende de bestaande 1,8 seconden.
Gewone slagen blijven gratis. De bestaande derde comboslag kost 18 stamina en
breekt na herstel van de werkplaats nog steeds schilden. Bosschade van pijlen blijft
1 en het bestaande kristalpantser blijft gelden. Een precisieschot heeft meer bereik
en meer schade per pijl, maar minder schoten per seconde dan de gewone boog.

Stamina wordt bij het begin betaald. Tijdens voorbereiding loopt de speler op 35%
van de gewone snelheid, zonder sprint. De richting wordt vastgelegd, niet telkens
naar de cursor gedraaid. Het lichaam volgt nog steeds de looprichting. Rollen,
geraakt worden, pauzeren of van invoerapparaat wisselen annuleert de voorbereiding.
Geen pijlverbruik tot het schot; geen terugbetalingsexploit voor stamina. Herstel
voorkomt direct een extra aanval. Een menupauze vuurt geen opgeslagen schot af.

De voorbereiding heeft een eigen balkje, wapenpose en geluid. Steken en brede
slagen hebben verschillende effecten; het precisieschot een blauwe staart.
Contextuele toetsenhints verschijnen onder XP en verdwijnen tijdens menu's.

## Vijanden en ontmoetingen

- **Keiram:** zes HP, één schade. Reageert op zicht binnen 140 px; bij hard geluid
  binnen 230 px. Waarschuwt 0,85 s en stormt dan maximaal 0,45 s langs de vastgelegde
  lijn. Een obstakel stopt hem. Daarna 1,3 s herstel. Alleen de stormloop doet
  contactschade. Een treffer onderbreekt hem.
- **Doornschutter:** vier HP, één schade. Dezelfde waarneming; trekt terug bij
  minder dan 85 px afstand. Waarschuwt 0,85 s, schiet één niet-volgende doorn en
  herstelt 1,3 s. Rotsen en vaste objecten stoppen de doorn; zwaardaanvallen kunnen
  hem breken. Geen gratis contactschade terwijl hij aan het richten is.
- Nieuwe speciale aanvallen wachten als een nabijgelegen vijand al waarschuwt of
  stormt. Oranje lijnen stoppen bij dekking. Blauwe hersteltekens geven een opening.
- Schildwachters kiezen binnen bereik een plek tussen speler en een kwetsbare
  schutter/genezer. Bestaande te verdedigen doelen behouden hun bewegingsprioriteit.
- Twee slijmplekken in het bos en twee skeletplekken in de ruïne zijn vervangen;
  het totale aantal vijanden stijgt daar niet. Objectvolgorde en opgeslagen kist-ID's
  blijven gelijk. De bestaande stille route, kristallen en hoofdverhaalpoorten blijven.

Het **oefenerf** is een zijpad bij [3,22] in Fluisterbos. Eerst instructies bij het
vaandel, daarna expliciet nogmaals gebruiken om te starten. Oefeningen: één ram,
één schutter, beide met schildwachter. Elke start toont 2,5 s verschijningswaarschuwing
en wacht als de speler op een verschijningsplek staat. Het vaandel stopt de oefening;
de zuidelijke uitgang blijft open. Oefenaanvallen doen normale schade, maar vijanden
geven geen buit, XP of kill-registratie. Verlaten reset de plaatselijke oefening.

## Eigen werk en compatibiliteit

`tools/art_x_combat.py` maakt twee monsters met vier frames, geanimeerde vaandels,
een wapenrek, de oefenkaart en drie gesynthetiseerde geluiden. Geen externe assets.
De technieken en oefening zijn tijdelijk; geen nieuwe vereiste savevelden.
De nieuwe map-ID wordt via de bestaande registratie opgeslagen en geladen.

Ook een bestaand randgeval bij pijlen is gerepareerd: een muur in hetzelfde korte
vluchtsegment als een overlappende vijand krijgt voorrang. Zo kan een precisieschot
geen treffer door een rots heen maken.

## Controle

`combat_variety_test.gd` gebruikt echte toetsenbord- en controller-events en controleert
onder meer de drie hitvormen, voorbereiding, herstel, onderbrekingen, staminakosten,
pijlverbruik, vaste richting, dekking, geluid, aanvalsafstemming, samenwerking,
oefenstop, veilige spawns, geen XP-farm, heen/terugportals en oude knopinstellingen.
Daarnaast geldt de volledige bestaande suite en de Windows CI-build.

Visuele review: 1152×648, NL/EN, toetsenbord/controller-hints, ingang, oefenerf,
waarschuwingen, precisievoorbereiding, kristalsteek en instructiedialoog. Overzichtsbeeld
met zoom 1,5; de game behoudt zoom 2. Geen fysieke controller of alle resoluties getest.
