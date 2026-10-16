# Persoonlijk huis — fase 3 / 0.30.0-preview

De bestaande woning blijft 14×14 tegels van 32px, met dezelfde zeven kaartobjecten, deur, voorraadkist en dorpsaansluiting. Buiten verandert niets. Een kamer van 10×10 bruikbare tegels krijgt een eigen opgeslagen inrichting.

## Spelen
Open **Je huis inrichten** via bed, woningbord of tuinvoorraad binnen, of druk de ingestelde Tuinstanden-toets (standaard U) in huis. Controller: praat met het bed en kies de inrichtknop. Tijd en personage pauzeren terwijl je ontwerpt.

- Verplaats bed, tafel en boekenkast; hun echte botsing verhuist mee en het bed houdt rusten/opslaan.
- Kies uit 13 meubeltypen: drie basismeubels, stoel, bladplant, bloemenpot, staande lamp, linnen bankje, servieskast, geweven kleed en drie aandenkens. Kleed, stoel, bladplant en lamp zitten al gratis in je meubelvoorraad; alleen het kleed staat aanvankelijk in de kamer.
- Vier originele vloeren, vier wanden, drie stofkleuren en warm/zee/uit voor verlichting zijn vrij te kiezen. Planten vragen geen onderhoud.
- Extra meubels maak je optioneel met bestaande materialen. Tas en bereikbare huisvoorraad tellen mee; kosten worden pas met het nieuwe eigendom opgeslagen. Een servieskast is decoratie, de gedeelde opslag blijft bij de bestaande kist.
- Bos-, sluis- en kustaandenkens controleren echte ontdekkingen. Ook een al ingeleverd boskristal telt mee. Aandenkens kosten geen verhaalvoorwerp en zijn uniek.
- Kies links een soort of boven de plattegrond een geplaatst exemplaar. Klik een plek en kies Bevestig plek; dubbelklik plaatst, rechtsklik kiest een meubel. Richtingstoetsen/stick bewegen de markering, bevestigen plaatst. LB/RB of PageUp/PageDown wisselen tussen lijst en plattegrond.
- Alles blijft een ontwerp totdat je Toepassen kiest. Annuleren laat de kamer staan. Gemaakte meubels blijven in de meubelvoorraad. Opbergen is gratis en vernietigt niets. De drie basismeubels blijven aanwezig maar mogen verhuizen.
- Beginindeling bekijken zet alleen het ontwerp terug; je bewaart die pas met Toepassen.

## Ruimte en beeld
Maximaal twaalf geplaatste stukken en 26 bezette meubeltegels. Markeringen houden entree, hoofdbaan en de benaderingsplekken van kist en woningvoorzieningen vrij. Een volledige bereikbaarheidstest voorkomt afgesloten hoekjes. De zichtbare afmetingen tellen mee, niet alleen een klein botsingspunt. Een kleed blijft onder meubels en personages en blokkeert niets. Je kunt niet op je eigen personage bouwen.

Eigen reproduceerbare pixelkunst in tools/art_x_personal_house.py: dertien silhouetten, drie stoffenpaletten, geweven kleden en acht vloer/wandmaterialen. Alleen huisgebonden objecten worden getekend; het dorp en andere streken houden hun ruimte en rust.

## Bewaren en controle
Nieuwe genormaliseerde savegegevens voor eigendom, indeling, kleur en afwerking; oude saves krijgen de veilige beginindeling. Ongeldige of overlappende indelingen herstellen naar de basis zonder eigendom te verliezen. Een oude positie die nu in een groter meubel valt krijgt een veilige aankomst op het middenpad.

personal_home_test controleert logica, echte collision, opslagkosten, aandenkens, saves en oude posities. personal_home_ui_test bedient native muis, toetsen, controller, herhaling, annuleren en toepassen, en controleert drie resoluties in NL/EN. De bestaande volledige suite blijft draaien. tools/preview_personal_house.py rendert echte geïsoleerde spelbeelden plus een ruimte-audit; de spelerssave wordt niet geopend.

Buitenmeubels, verplaatsbare productie, erfuitbreidingen en extra gebouwen volgen in latere fasen. Volgende gewone go: fase 4 — uitbreidbaar erf.
