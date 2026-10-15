# Landbouw en irrigatie — ronde 1, 0.27.0-preview

Deze ronde verdiept de bestaande woningtuin uit 0.26; alle kaarten, buitenobjecten,
routes, bestaande inventaris en irrigatieregels blijven behouden.

## Gereedschap en veldwerk

U, of de bestaande route Beroepen → Tuinstanden op controller, opent een compact
raster van twee kolommen. De laatst gekozen stand heeft voorrang bij openen.
Links/rechts en omhoog/omlaag volgen de kolommen; muis en controller blijven
exclusief volgens de bestaande invoerregels. Een korte uitleg volgt de focus.
Alle bestaande bindings blijven intact.

De gemarkeerde tegel ligt vóór de looprichting van de speler, onafhankelijk van
het gevechtsvizier. Groene hoeken tonen een uitvoerbare handeling; amber geeft een
concrete reden, zoals ontbrekend zaad, onrijpe druiven of een beschermde plek.
Dezelfde validatie bepaalt de voorvertoning en de echte actie.

E/A vasthouden en lopen werkt langs een rij. Een korte sprong van de richttegel
langs dezelfde rij wordt binnen het echte werkbereik aangevuld; een verre
verplaatsing bewerkt geen tussenliggende grond. Een tegel wordt per vasthoudactie
hooguit eenmaal succesvol bewerkt. Rollen, terugslag en gevechten blokkeren werk;
interactie met bestaande werkplekken houdt voorrang.

Herstellen werkt één tegel per verse druk, zodat vasthouden geen geplante rij
wist. Plantzaad komt alleen terug als er ruimte is. De waarschuwing meldt dat de
plant verdwijnt. Menu's en wisselen van invoerapparaat stoppen een lopende
vasthoudactie; bevestigen in het menu lekt geen tuinhandeling naar buiten.

## Groei, water en productie

Druiven krijgen een kiem, bladgroei, een kleine steun en groene/rijpe trossen;
bloemen krijgen hun eigen groeivorm en bloeistadium. De tekeningen blijven binnen
hun eigen tile. Kleine werkdeeltjes en twee eigen zachte geluiden geven feedback.
De originele bestanden blijven behouden; tools/art_x_garden.py maakt de nieuwe
geluiden reproduceerbaar zonder externe assets.

Het veldpaneel verschijnt alleen bij actief tuinwerk of gekozen hulp in de tuin
en wijkt voor menu's, interactiedoelen, meldingen en kaartbanners. Het toont groei,
actieve resterende tijd, oogstopbrengst en de oorzaak van een blokkade.
Droge gewassen wachten veilig; rijpe planten blijven rijp.

De bestaande vierwegs-waterverbinding berekent ook een route terug naar de bron;
subtiele glinsteringen laten de stroomrichting zien. Het optionele wateroverzicht
markeert aangesloten en droge kanalen en bewaterde/droge grond. Een nieuw kanaal
toont vooraf of het meteen water krijgt. Alternatieve bronverbindingen houden
een veld nat als één tak wordt weggehaald. Smalle kanalen houden geen collision
en blijven gewoon oversteekbaar.

De bestaande wijnvaten, mesthoop en bijenkast krijgen kleine fysieke
voortgangs- en gereedtekens. Er zijn geen extra productieplekken, wachtrijen,
gewassen, bewoners, beloningen of onderhoudsverplichtingen toegevoegd.

## Vrijwillige tuinhulp en saves

Bij het tuinbord, de binnenvoorraad en de tuinstanden kan de speler de tuinhulp
starten of stoppen. Vier stappen volgen echte bewerkte grond, aangesloten water,
een bewaterde druivenstok en de eerste oogst; bestaande tuinen worden herkend.
Tijdens groeien moedigt de hulp aan om op pad te gaan. Er is geen verplichte
quest, extra XP-beloning of tijdslot.

De hulpkeuze en eerste oogst gebruiken het bestaande flags-woordenboek; oude
saves krijgen geen nieuw verplicht formaat. Wateroverzicht en gereedschapsstand
zijn tijdelijke keuzes en worden bij een nieuwe sessie rustig teruggezet.
Groei, meststof, zaden, productie en water blijven de bestaande opgeslagen
actieve speeltijd gebruiken. Geen offline opbrengst of verdorren toegevoegd.

## Controle

garden_phase1_test gebruikt echte native invoer voor menu en veldwerk en
controleert gedeelde validatie, vertakte irrigatie, droogvallen/heraansluiten,
groei, bemeste oogst, korte rijgaten, verre verplaatsingen, bewust herstellen,
menu-/apparaatwissel, voorrang van de bijenkast, save/load en rustige HUD.
De volledige bestaande suite blijft vereist.

tools/preview_garden.py maakt 112 beelden: elf werk-/veldscenario's en zeven
beroepen in NL/EN op 960×540, 1152×648 en 1600×900, plus rustige dag-/nachtbeelden
en twee beelden van een groot veld. De preview en tests
draaien in aparte UUID-projecten met geverifieerde save-mappen.
Fysieke controller niet handmatig getest; native controller-events wel.

## Eigen interfaces per vak en werkplek

Op extra verzoek van sjors heeft elk van de zeven beroepen een eigen titel,
kleurpalet, zelfgetekend embleem en gerichte uitleg. Het actieve recept toont
werkelijke ingredienticonen/aantallen en het resultaat. Navigatie en bestaande
receptregels blijven gelijk; het gekozen beroep en filter blijven gesynchroniseerd.

Tuinstanden gebruiken een gereedschapsraster; woninghulp toont vier stappen,
compost een mest-naar-meststofdiagram, wijn een druif-vat-flesdiagram, de bijenkast
bloemen rond de kast en het bed een eigen rustbeeld. Iedere werkplek heeft
specifieke actieknoppen en toont alleen zijn eigen productieproces.
workplace_ui_test controleert native muis-/controllerinvoer, echte wijnkosten,
alle zeven vakken, voorraadsbehoud en de lay-outs op de drie formaten in NL/EN.
Het grote veld krijgt een apart renderprofiel; gemeten tijden zijn diagnostisch
en geen garantie voor alle computers.
