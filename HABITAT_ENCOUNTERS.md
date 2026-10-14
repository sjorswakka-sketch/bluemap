# Monsters horen bij hun omgeving — 0.19

Fase 3 vervangt precies vier bestaande vijanden, zonder nieuwe plekken,
kaartobjecten, doorgangen, quests, UI-markers of bewoners.

| Omgeving | Vervanging op bestaande tegels | Gedrag |
| --- | --- | --- |
| Fluisterbos | Slijmen op [12,5] en [43,6] → Wortelwakers | Stationair. Een vaste amberkleurige grondstrook kondigt wortels aan; lange kwetsbare herstelperiode. |
| Echo-grot, oostelijke route | Vleermuizen op [31,12] en [37,13] → Schemermotten | Volgen zichtbaar licht dichtbij hun thuisplek. Bestaande fakkels kunnen ze afleiden. Korte, aangekondigde rechte duik als ze de speler volgen. |

De achttien bezette bosvijandplekken en het bestaande aantal grotvijanden blijven
gelijk. De acht uitgedunde bosplekken blijven uitgeschakeld. De Bosrand,
westelijke aankomst/altaarroute, het stille luisterpad, dorp en Zilvermeer
behouden hun inrichting. De bestaande bramen en drie luisterstenen blijven
ongewijzigd. Kaartverrijking wijzigt alleen kinds op dezelfde opgeslagen slots.
Oude kisten, pickups, flags, posities en nieuwe werkplekken behouden hun sleutels.

## Verschillende keuzes tijdens het gevecht

Een Wortelwaker verplaatst zich niet. Zijn bereik is 100 px; de volledige strook
is 24 px breed en begint 18 px voorbij de voeten. Richting en oorsprong liggen
vast bij de waarschuwing van 1,1 s. De wortels blijven 0,18 s actief en kunnen
hooguit één treffer per aanval geven. Daarna is de bast 1,8 s open.
Gewone slagen/pijlen raken tijdens deze herstelperiode; gesloten bast blokkeert ze.
Een bestaande zwaardtechniek of precisieschot opent de bast en breekt de
voorbereiding af. De bestaande technieken behouden hun eigen bereik, hoek,
staminakosten en schade. Rol opzij of loop uit de strook; de boog biedt
afstand tijdens herstel. Geen nieuw wapen, binding of verplichte uitrusting.

Een Schemermot volgt de bestaande spelerslamp alleen binnen 112 px, met zichtlijn.
Zichtbare fakkels binnen 144 px hebben een afstandsvoordeel van 56 px: lok de mot
naar een bestaande vlam om hem rustig te laten zweven. Fakkels en lamp blijven
normaal werken; er is geen nieuw lichtverbruik of verplichte uitknop.
Dichtbij volgt een waarschuwing van 0,85 s, dan een korte rechte duik van maximaal
68 px (afgerond naar vrije stappen van 4 px), begrensd door dekking. De mot raakt
alleen voeten in het gewaarschuwde gebied die hij werkelijk passeert, hooguit
eenmaal. Rustig zweven geeft geen contactschade. Een gewone treffer onderbreekt
de duik; bestaande technieken en pijlen werken ook. Na afloop wacht hij 1,6 s.

## Grenzen die rust bewaren

- Beiden blijven binnen een gebied van 144 px rond hun beginplek. Geen uitbreiding
  door lokken, genezing bij terugkeer of extra vijanden bij een aanval.
- Bestaande aankomstpunten, portalen en savepoints hebben een uitsluitzone van
  80 px voor nieuwe doelkeuze, beweging en aanvallen.
- Grondstroken worden over hun hele breedte afgeknipt bij terreindekking en
  echte vaste objecten; schade controleert daarnaast opnieuw de zichtlijn.
- Vaste waarschuwingen en echte schade gebruiken dezelfde geometrie op de
  grondlaag, onder de personages. Geen waarschuwing over een NPC-naam of gezicht.
- De voorbereiding deelt het bestaande wachtbudget met Keirammen en
  Doornschutters: geen gelijktijdige voorbereiding van die soorten binnen 240 px.
  Andere bestaande vijanden behouden hun eigen gedrag.
- Eigen zachte geluiden klinken alleen bij een aanval dichtbij de speler,
  zonder permanente zoemloop of meldingen tijdens gewoon wandelen.
- De bestaande opbrengsten zijn bescheiden; killgeschiedenis en beestenboek
  gebruiken de bestaande opslagvorm. Een nieuw spel wist de geschiedenis.

Eigen bron: tools/art_x_habitat.py maakt twee animatiesheets en drie
zelf gesynthetiseerde geluiden. Geen externe art/audio. NL/EN bijgewerkt.

## Controle bij publicatie

habitat_test controleert alle vier daadwerkelijke plaatsingen ná routevoorbereiding,
behoud van drie luisterstenen en uitgedunde plekken; vaste waarschuwingen,
geen vroege/dubbele schade, zijstappen, echte rolbescherming, open/gesloten bast,
drie echte zwaardtechnieken en echte gewone/precisiepijlen. Daarnaast fysiek
dekkinglichaam, zichtbaar/onzichtbaar licht, daadwerkelijke duikbeweging,
onderbreking, afleiding en rust bij een fakkel, territorium, altarveiligheid,
wachtbudget met bestaande vijand, echte save/load en nieuw spel.

De bestaande world_space_test loopt de rustige westelijke route en Bosrand
met echte beweging. first_route_test controleert de oorspronkelijke route.
De volledige regressiesuite en Windows-export horen bij de oplevering.

Visuele controle: de vier echte vervangingen, waarschuwing/aanval/herstel,
dag/nacht, mot bij fakkel, westelijke bosroute, Bosrand, luisterpad en altaar,
meer en beide beestenboekteksten in NL/EN. 960×540, 1152×648 en 1600×900.
Controllerinput in bestaande tests is gesimuleerd; geen fysieke controller,
alle resoluties of volledige menselijke doorspeling geclaimd.
