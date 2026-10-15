extends RefCounted
const OBJECTS := {"craft_notes":"res://scripts/entities/craft_notes.gd"}
const SOUNDS := ["pg_pattern","pg_forge"]
const MAP_MARKERS := {"craft_notes":{"color":Color(0.9,0.75,0.4),"label":"Werktekening"}}
const NOTES := {
	"smith":{"name":"Greta’s werktekeningen","flag":"pg_smith_notes","recipe":"pg_grip","lines":["Koperen banden verdelen de kracht van een zwaardtechniek. Maak slagbanden bij Greta; een gewone zwaardaanval blijft gratis.","Met zeeagaat uit de veilige Tijholte en zoutdrijfhout smeed je ankerbanden voor een gerichte wacht en tegenstoot. Hetzelfde handvak vraagt een keuze; oude handschoenen blijven bruikbaar.","Na herstel van Sana’s bron kun je met ijzer en zandsteen hardere banden smeden. Het gedragen paar wordt bij verbeteren meteen vervangen."]},
	"focus":{"name":"Lena’s lensonderzoek","flag":"pg_focus_notes","recipe":"pg_focus","lines":["Een kleine lens helpt je boog sneller voorbereiden. Maak een richtlens aan de alchemietafel en draag hem in je halsvak.","Zeeagaat en oevervezels maken waaierbanden: drie lichte pijlen voor spreiding, met drie pijlen als kosten. De havenwerkplaats heeft een veilige proefopstelling.","Na het ordenen van het Rietarchief kun je met ijskristal en watermunt een heldere lens maken. Minder voorbereiding betekent eerder schieten; je staminakosten en pijlschade veranderen niet."]},
	"pack":{"name":"Joris’ vlechtpatroon","flag":"pg_pack_notes","recipe":"pg_pack","lines":["Een stevig gevlochten werkpak houdt je gereedschap bij de hand. Berkenhout en losse takken zijn genoeg voor het eerste patroon. Draag het in je borstvak om sneller te verzamelen.","De klimlijn in de Bergpas leert je een sterker vlechtwerk. Combineer daarna dennenhout en wilgentwijgen voor een bergwerkpak met extra oppakbereik."]}
}
