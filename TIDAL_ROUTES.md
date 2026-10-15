# Kustreizen en Getijdenbaai — 0.21.0-preview

Fase 2 van DEVELOPMENT_COAST.md. Basis: e397e64819c25436f56e9580529871387654c415
op claude/affectionate-mendel-vc1idx. Geen force-push; de eerdere kustversie blijft
onderdeel van de geschiedenis.

## Spelen

Vanaf de bestaande kuststeiger kun je de bekende veer nemen of het lage reisbord
naast de steiger gebruiken. Kies Meeuweneiland of de Getijdenbaai; beide gratis.
Meeuweneiland heeft ook een oostelijke loopbrug naar de baai. De bordjes noemen
de echte bestemming. In de baai staan de terugveer en de westelijke loopbrug
altijd klaar. Geen nieuwe vijanden, pickups, opdrachten of verplichte wachttijd.

De baai is één aparte kaart van 52×36 tegels. De noordelijke houten loopbrug is
hoog en blijft altijd open. De zuidelijke zandbank is een korte route bij laagwater.
De lijnpalen bieden nog een korte oversteek: leen eerst de landingslijn bij de
kist naast de westelijke aanlegplaats. Hij staat als sleutelvoorwerp in je tas,
kost niets en wordt nooit verbruikt. De korte lijnvlotanimatie kun je met
Annuleren afbreken; je komt dan terug op je vertrekplek.

## Getijde en opslag

Eén cyclus duurt 96 seconden wereldtijd: 48 laag, 12 opkomend, 24 hoog en
12 aflopend. De duidelijke waarschuwing komt vóór de sluiting. De hoge route
en terugvaart vragen geen spullen en geen getijde. Als iemand nog op de
zandbank loopt, wacht de lokale afsluiting tot die veilig de oever bereikt.
Er komt geen collider onder de speler, schade of gedwongen resourceverlies.

Getijde gebruikt de reeds opgeslagen dagtijd; menu's, dialogen, lijnanimatie
en proefhaven pauzeren die klok. Geen extra saveveld, real-time timer of
saveversiemigratie. Bij laden wordt het getijde vóór terrein en veilige
voetplaatsing toegepast. Een oude positie op overstroomd zand wordt dichtbij
op een werkelijk droge oever geplaatst. Bestaande objectslots blijven op hun
plaats; nieuwe verbindingen en borden zijn achteraan toegevoegd.

## Vrij varen: alleen een proefstuk

De leenkist biedt een aparte oefenhaven in een menu. Bestaande loopbindings
sturen de boot; loslaten remt, obstakels en grenzen stoppen de boot en drie
boeien kleuren bij aanraking. Toetsen en controller delen de bestaande
exclusieve invoerwisseling. De aanwijzingen veranderen met apparaat/bindings.
Geen timer, schade, betaling, beloning of wereldverplaatsing. De gewone veer
blijft de echte reisroute. Dit kleine proefstuk is geen uitgewerkt vaarsysteem;
eerst speelgevoel/feedback voordat de wereld ermee wordt uitgebreid.

## Eigen beeld en geluid

tools/art_x_tides.py reproduceert de kaart, getijdepaal, leenkist, lijnpaal,
reisbord, lijnvlot en lijnicoon. De bestaande 78 terreintegels blijven identiek.
De bestaande zelfgemaakte kustmuziek en water-/lijngeluiden worden hergebruikt.
Dunne relingen geven de hoge loopbrug aan; natte zandstrepen en rustige branding
houden de baai leesbaar. De overige wereld wordt niet voller gemaakt.

## Controle

tests/tides_test.gd controleert echte loopbeweging over de lage en hoge route,
de fysieke watergrens, afsluiten met een wandelaar, vier getijden, aankomst en
hervatten op overstroomd zand, bestaande voltooid-spel/collectievlaggen, leenlimiet,
ontbrekende tool, heen/terug en afbreken van de lijn, bestemming/annuleren,
gedwongen kaartwissel en opruimen van UI. Native toetsen, muisklikken en
gesimuleerde controllerinput; geen fysieke controller geclaimd.

De volledige suite heeft 50 tests, inclusief de bestaande kustreis. NL/EN en
menu's worden op 960×540, 1152×648 en 1600×900 gecontroleerd. Beelden omvatten
laag/opkomend/hoog water, hoge brug, lijnvlot, beide zijden, leenpaneel,
ontbrekende tool, bestemmingen, proefhaven, kaart en nacht.
Alle spel- en rendertests gebruiken een geverifieerde UUID-save, nooit een
echte spelerssave. Dit is geen claim over alle resoluties/hardware of speeltijd.
Het renderharnas gebruikt geforceerde screenshots; zijn process-monitor is geen
gameplay-FPS. Afsluiten kan bestaande resource-cleanupwaarschuwingen geven.

Definitieve testlogs, beelden, audit, schone bronkopie en Windows-CI-bewijs
worden naast de release bewaard. Eén volgende go start fase 3: de regio ruimte geven.
