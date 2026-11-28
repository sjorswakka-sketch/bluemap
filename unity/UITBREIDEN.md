# BlueMap Quest in Unity uitbreiden

Deze gids zegt waar de dingen staan, wat je veilig kunt veranderen en wat eerst een opknapbeurt nodig heeft. Hij beschrijft de stand na fase 23 (versie 0.19).

## Hoe de game in elkaar zit

Het Unity-project staat in `unity/` (Unity 6000.3.26f1, Windows x64, Mono, ingebouwde renderer, 32 pixels per tegel, tekenvlak 1152×648). Alle code zit in één assembly; de mappen onder `unity/Assets` volgen de onderwerpen van de game.

| Map | Wat erin zit |
|---|---|
| `BlueMapFoundation` | De speltoestand (dezelfde 34 velden als de Godot-save), gebeurtenissen, kaarten en gegevens laden |
| `BlueMapContent` | De oorspronkelijke beelden, geluiden, kaarten en catalogi als Unity-resources |
| `BlueMapPhase6` | Catalogus van beelden en geluid, lettertype en vertalingen |
| `BlueMapPlayer` | Lopen, rennen, rollen, invoer en camera |
| `BlueMapWorldAccess` | Doorgangen, sloten, poorten en veilig aankomen |
| `BlueMapInventory`, `BlueMapProgression` | Voorwerpen, opslag, ervaring, uitrusting en uiterlijk |
| `BlueMapCombat` | Gevechten, vijanden, bazen en projectielen |
| `BlueMapStory` | Gesprekken, opdrachten, voorwaarden en acties |
| `BlueMapResidents` | Bewoners met dagroutines en herinneringen |
| `BlueMapProfessions`, `BlueMapHome`, `BlueMapFarm` | Beroepen en winkels, huis en erf, tuin en productie |
| `BlueMapAreas`, `BlueMapAtmosphere`, `BlueMapCompletion` | Bijzondere gebieden, dag en nacht en kaart, einde, Nieuw spel+ en titelscherm |
| `BlueMapPersistence` | Unity-profielen, import van Godot-saves en de kopie terug naar Godot |
| `BlueMapRoute` | De spelregie: één `RouteWorldController` (in delen per onderwerp) en het HUD |
| `BlueMapProbe` | De opstart, de automatische eindtest en de build |

Elk onderwerp heeft dezelfde opbouw: een **model** met de spelregels (geen Unity-scène nodig), een **paneel** voor het menu en een **`…RouteController.cs`** in `BlueMapRoute/Runtime/Session` die het model aan de wereld en de toetsen koppelt.

## Inhoud toevoegen

De inhoud komt op dit moment nog uit de Godot-bron. Kaarten, voorwerpen, vijanden, gesprekken, opdrachten, recepten en vertalingen worden met de hulpmiddelen in `tools/` uit `scripts/` en `translations/` geëxporteerd naar `migration/portable/` en `migration/world/`, en van daaruit naar `unity/Assets/BlueMapContent`. Een contractbestand per fase (`migration/phase-NN/source-contracts.json`) bewaakt met hashes dat Unity nog precies dezelfde gegevens gebruikt.

Dat is veilig, maar het betekent ook: **wie nu een voorwerp of gesprek in de Unity-resources verandert, laat een contractcontrole afgaan.** Voor de eerste echte uitbreiding moet je daarom kiezen:

1. **Godot blijft de bron van de inhoud.** Je voegt inhoud toe in de GDScript-data en draait de export opnieuw. Alles blijft bewezen gelijk, maar je blijft aan Godot vastzitten.
2. **Unity wordt de bron (aangeraden).** De catalogi in `BlueMapContent` worden de plek waar je inhoud bewerkt, en de contracten veranderen van "gelijk aan Godot" naar "gelijk aan de laatste goedgekeurde stand". De kopie terug naar Godot werkt dan alleen nog voor inhoud die Godot ook kent; nieuwe velden worden gemeld en niet stil weggegooid.

Deze omschakeling is nog niet gedaan. Het is de eerste stap van een uitbreiding en een bewuste keuze, omdat de bit-exacte vergelijking met Godot daarna ophoudt voor alles wat nieuw is.

## Regels en systemen aanpassen

- Een spelregel staat in het model van zijn onderwerp, bijvoorbeeld `FarmModel.cs` of `CombatModel.cs`. Voor fases 4 tot en met 19 speelt een `…ModelChecks.cs` opgenomen Godot-gedrag na; verander je daar een regel, dan faalt die vergelijking met opzet. Pas je bewust een regel aan, dan hoort die opname erbij te worden bijgewerkt of uitgezonderd.
- Een nieuw systeem krijgt een eigen map met model, paneel en een eigen `…RouteController.cs` (een `partial` van `RouteWorldController`), met `Initialize…`, `Detach…` en `Tick…` zoals de bestaande delen.
- Tekst die de speler ziet gaat door `Translate(...)` (staat in `translations/en.po`) of `T("Nederlands","English")`.
- De toestand is onveranderlijk per waarde (`FoundationValue`); wijzigen gaat met `State.Set`, `State.SetFlag` en `InventoryModel.Replace`.

## Graphics en engine upgraden

Dit kan, maar de game is nu gebouwd om de Godot-versie exact te volgen, niet om mooi te groeien. Wat je moet weten:

- **Menu's zijn getekend met IMGUI** (Unity's eenvoudige tekensysteem) op een vast vlak van 1152×648. Voor animaties, schaalbare schermen en controllerfocus is een overstap naar UI Toolkit of uGUI nodig. De panelen hebben een model los van het tekenen, dus dat kan paneel voor paneel.
- **De renderer is de ingebouwde pipeline** met eigen eenvoudige shaders voor dag/nacht en licht. Voor 2D-licht, schaduwen en nabewerking is de Universal Render Pipeline (URP 2D) de gebruikelijke stap; de sprites en tegels blijven dan bruikbaar, de twee eigen shaders worden vervangen.
- **De wereld wordt uit data opgebouwd**, niet uit Unity-scènes. Dat is goed voor grote werelden, maar een ontwerper kan nu geen kaart in de Unity-editor bewerken. Een kaarteditor of import uit Tiled is een logische uitbreiding.
- **De code is compact geschreven** (lange regels, weinig tussenstappen) om dicht bij de bron te blijven. Vóór een grote verbouwing loont het om de onderdelen die je aanpakt eerst leesbaar te maken en in eigen assemblies te zetten, zodat compileren sneller gaat en afhankelijkheden zichtbaar worden.
- **De speler heet nog `BlueMapUnityProbe.exe`** en het bedrijf in de projectinstellingen is `BlueMapMigrationTests`. Hernoemen raakt de bouw- en controlehulpmiddelen en is nog niet gedaan. De opslag staat los daarvan in `%LOCALAPPDATA%\BlueMapQuestUnity`.
- **Bouwen gebeurt lokaal.** `python tools/build_unity_probe.py --editor <Unity.exe> --output <nieuwe map>` bouwt de Windows-speler en draait de volledige eindtest (ongeveer een kwartier). GitHub controleert de bron en de gepubliceerde download, maar bouwt Unity niet zelf.

## Wat nog niet gelijk is aan de Godot-game

Bewegend water, stoom en vonken; de zichtbare standen van doelwitten, spiegels, vuurkorven en het tijrad; het geschilderde kaartbeeld en de kaart in de epiloog; de oefenpoppen in Rafs werkplaats. Fases 20 en 21 zijn zonder Godot-opname overgezet. Niemand heeft de Unity-versie nog met de hand van begin tot eind uitgespeeld.

## Controleren voordat je iets deelt

- Snel: `python -m unittest discover -s tests/migration -p "test_*.py"` en de `python tools/build_migration_*.py --check` hulpmiddelen.
- Volledig: de lokale build met eindtest hierboven. Automatische tests draaien altijd met het geluid van de test zelf uit; ze veranderen je systeemvolume en je spelinstellingen niet en raken je eigen saves niet aan.
