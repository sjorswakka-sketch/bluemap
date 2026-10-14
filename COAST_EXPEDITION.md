# Eerste kustexpeditie — 0.20
Een optionele rustige reis van Zilvermeer naar Blauwe Kust en Meeuweneiland.

## Reis

Aan de oostelijke bovenkant van het meer staat één richtingbord bij één nieuw
pad naar de riviermonding. Daar begint een open kust met strand, duinen, gras
en een aanlegsteiger. De boot brengt je gratis naar Meeuweneiland en terug.
Een korte overtocht van 2,2 s is over te slaan of af te breken vóór vertrek.

Op het eiland komen een grasroute en een strandroute samen bij het uitzicht.
De strandsteen geeft alleen sfeer en noemt de terugweg. Geen verplichte taak,
nieuwe munt, loot, vijand of dagelijkse activiteit. De eerste fase bewijst
dat een hele kustreis veilig en prettig kan werken; nieuwe havenavonturen
en getijderegels horen bij latere fases van DEVELOPMENT_COAST.md.

## Ruimte en bestaande inhoud

- Twee nieuwe kaarten: 58×36 en 48×36. Open wandelruimte en verschillende ondergrond.
- Zilvermeer houdt alle oorspronkelijke objecten in dezelfde volgorde/posities.
  Achteraan staan één extra portal en één bord. Alleen oostelijke randtegels
  x=39..43 op y=8 en x=40..43 op y=9 openen de aansluiting. Geen nieuwe vijanden in het meer.
- Bosrand, westelijke bosroute en alle andere oude kaartindelingen blijven behouden.
- De oude 71 atlas-tegels behouden hun pixels en volgorde. Zeven eigen kusttegels
  komen achteraan. Zand vertraagt net als ander zand; planken klinken als hout.
  De nieuwe zee/branding is solid en heeft dezelfde pijlregels als water.
- Beide aanlegplaatsen blijven altijd beschikbaar, zonder kosten of unlock.
  De routegraaf begrijpt de veerverbinding, inclusief de terugweg.
- Kleine mooringprops blokkeren de planken niet. De boot ligt in aangrenzend water;
  geen nieuwe collider op een oude savepositie.

## Bootvaart en opslag

De bestaande dialoog biedt Varen of Blijven. De vaaractie start pas nadat het
gesprek zijn invoer heeft vrijgegeven. Het paneel gebruikt de bestaande
keyboard/controllerfocus, native klikknoppen en exclusieve invoerwisseling.
B/Esc of Terug breekt af. Meteen aankomen of de timer draagt eenmaal over
aan de bestaande kaartwisseling; een tweede bevestiging kan geen tweede reis starten.

Voor vertrek controleert het spel dezelfde aanlegplaats, kaart, afstand,
spelerstatus en geldige bestemming. Forceer je een kaartwisseling tijdens
de presentatie, dan verdwijnt het paneel en wordt invoer vrijgegeven.
Er worden geen goederen, gezondheid, ervaring of beroepscooldowns bijgevuld.
Save/load op het eiland gebruikt het bestaande saveformaat. Geen tijdelijke
“op zee”-save of onomkeerbare reis. Na het bestaande einde blijft deze reis mogelijk.

Het paneel pauzeert de wereld; bestaande meldingen wachten en hervatten daarna.
Het schaalt naar het viewport. Nieuwe animaties liggen onder de UI of bij de boot.
Geen nieuwe toetsbinding of nieuw hoofdmenu nodig.

## Eigen bron

tools/art_x_coast.py maakt kusttegels, de twee bootframes, aanleg-/strandprops,
twee handmatig gevormde kaarten, twee korte effecten en een eigen rustige
32 s muziekloop met zeesfeer. Geen externe art of audio.
tools/art_tiles.py kent de kustschilders ook, zodat de volledige atlas opnieuw
gegenereerd kan worden. Alleen artwork en data van deze fase worden gewijzigd.
Windows-bestandsmetadata en LEESMIJ dragen dezelfde 0.20-versie als project.godot.

## Controle

coast_expedition_test loopt echte routes, gebruikt het werkelijke meerportal,
de echte aanleginteractie, toetsen/pad en native muis-events. Getest: beide
richtingpaden, gratis reis, Blijven, annuleren, skip en automatisch aankomen,
geen dubbele transfer, zeebotsing, oude saveposities, eiland-save/load,
voltooide wereld, stale action en geforceerde kaartwisseling. Drie viewportformaten.
Volledige regressiesuite en Windows-export horen bij de oplevering.
Controllerinput is gesimuleerd; geen fysieke controller of alle resoluties geclaimd.

Kaartaudit vergelijkt oppervlak/objecten met 0.19; echte loopcontroles zijn nodig
naast deze vaste aantallen. De eerste fase is een reisproef, geen bewezen aantal
uren extra content of een prestatieclaim op basis van exe-grootte.

Resultaat: alle 49 tests geslaagd, 2.300 Engelse teksten volledig.
De kustwandeling naar de steiger duurt 12,2 s in de echte bewegingssimulatie.
De nieuwe kaarten hebben 1.136 en 591 beloopbare terreintegels. De aansluiting
voegt zes beloopbare tegels aan het meer toe; 26 andere oude kaartaudits identiek.
Atlas geregenereerd: alle oude pixels behouden, alle 78 tegels reproduceerbaar.
Laad-/geheugendiagnostiek staat bij de controlebeelden; de process-monitor omvat
ook PNG-opslag en geforceerde renders en is geen gameplay-FPS-benchmark.
