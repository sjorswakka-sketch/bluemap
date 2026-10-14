# Meewerken op bestaande werkplekken — 0.18

Fase 2 verdiept twee bestaande bewoners in hun binnenruimte. Buitenkaarten,
vijandplaatsing, zijpaden, kisten en opdrachten blijven gelijk aan de rustigere
0.17-basis. De Bosrand houdt alleen doorgangen en wegwijzers; het bos houdt
achttien vijandplekken. Er is geen nieuwe bewoner, dagelijkse taak of valuta.

## De twee samenwerkingen

| Werkplek | Handeling | Gereedschap, kosten en resultaat |
| --- | --- | --- |
| Greta, smederij | Schuif de losse klembek naar de witte naad; stel daarna stevige druk in en controleer het proefstuk. | Greta leent tang en sleutel. Geen materiaalverbruik. Eerste herstel: 6 Smeden-XP, het bestaande slagbandenpatroon en een blijvend rechte klem. Daarna oefenen zonder extra XP of buit. |
| Lena, bibliotheek | Kies twee hele bladeren, leg gekneusde/droge bladeren apart, maal en meng, beslis vervolgens of je bottelt. | Lena leent de vijzel. Eén echte fles gebruikt het bestaande `potion`-recept: 2 zilverkruid, 1 slijmgel, Alchemie niveau 1, bibliotheek; één Helddrank en 10 Alchemie-XP. Eerste echte bereiding leert het bestaande richtlenspatroon en maakt Lena's doseerrek zichtbaar. |

Vrij oefenen bij Lena werkt ook zonder ingrediënten. Het geeft geen drankje,
XP, patroon of opgeslagen afronding. Het nieuwe paneel toont actuele voorraad,
vereist niveau en receptreden vóór je begint. Materialen worden pas bij het
bottelen verwerkt; deze activiteit gebruikt de bestaande centrale craftfunctie,
met dezelfde capaciteit-, station-, niveau- en ingrediëntcontrole.

Opnieuw betaalde drankjes maken blijft mogelijk met normale kosten/ervaring,
zoals in Maken. Eerste samenwerking geeft geen extra Alchemie-XP boven het recept.
Bekende patronen worden niet dubbel beloond. Greta's eerste herstel is eenmaal
per avontuur; beide afrondingen zitten in bestaande opgeslagen flags.

## Ruimte, gedrag en bediening

- Toegang via een extra optie in het bestaande NPC-gesprek. Geen marker of
  opdracht op de wandelroute. De ster- en kristalzwaardbegroetingen behouden
  hun tekst en gevolgen en bieden daarna ook de vrijwillige samenwerking.
- De twee kleine props staan op bestaande vaste toonbanken. Ze voegen geen
  collider of nieuw opgeslagen objectslot toe. Hun sorteerpunt staat bij de
  toonbank, zodat achterlangs/voorlangs wandelen en NPC-naamlabels goed blijven.
  Greta's bestaande hamergebaar past bij de klem; Lena mengt na herstel rustig
  bij haar vijzel. Beide activiteiten blijven 's avonds bereikbaar.
- Links/rechts of de muispijlen stelt de klem af; Enter/E of A bevestigt.
  De bladeren gebruiken een raster met richtingfocus en klikbare kaarten.
  Esc/B of Sluiten annuleert; de sluitknop blijft tijdens animatie beschikbaar.
  De bestaande invoerwisseling, bindings en muiszichtbaarheid blijven leidend.
- Sluiten, weglopen, een verdwijnende NPC of kaartwisseling breekt niet afgerond
  werk af. Tussentijdse minigamevoortgang wordt niet opgeslagen. Voltooide
  werkplekveranderingen en patronen worden wel opgeslagen; oude saves hebben
  gewoon nog geen nieuwe afrondingsflags.
- Het paneel schaalt naar het echte viewport. Meldingen en prestatiekaarten
  verbergen zich bij gepauzeerde menu's/gesprekken, bewaren tijd en wachtrij en
  hervatten daarna. Het werkpaneel ligt boven gewone meldingslagen.

Eigen bronbestanden: `tools/art_x_work.py` maakt twee pixelsheets en drie zachte,
zelf gesynthetiseerde geluiden. Geen externe art/audio. NL/EN is bijgewerkt.

## Controle

`work_together_test` gebruikt bestaande gesprekkeuzes, echte gesimuleerde
toets-/controller-events en native muis-events in een passend fysiek testvenster.
Getest: mislukte afstelling zonder beloning, eerste en herhaalde reparatie,
echte Greta-interactie met kristal/sterren, verkeerde bladeren, kosteloos
oefenen, annuleren na mengen, precies één fles per bevestiging, hercontrole
van ingrediënten en een volle tas. Ook echte save/load, nieuw spel,
kaartwisseling tijdens de animatie, behoud van buitenroute-inhoud en hervatten
van een actieve én wachtende melding.

De bestaande ster- en bibliotheektests controleren nog steeds de oorspronkelijke
verhaalregels/effecten, met de bedoelde extra vrijwillige keuze. De volledige
regressiesuite en Windows-export horen bij publicatie.

Visuele review: beide kamers vóór/na, samenwerking en menganimatie, vrije
proefbereiding, ontbrekende ingrediënten, NL/EN, late Greta-begroeting en de
maximale vijf Lena-keuzes op 960×540. Werkpanelen op 1152×648, 960×540 en
1600×900. Geen fysieke controller of alle mogelijke resoluties getest.
