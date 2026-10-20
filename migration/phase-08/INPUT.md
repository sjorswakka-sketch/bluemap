# Fase 8: oorspronkelijke bediening in Unity

`scripts/core/input_manager.gd`, de `[input]`-sectie van `project.godot`,
`scripts/entities/player.gd` en `scripts/ui/crosshair.gd` blijven de bron.
De recorder `tools/record_migration_player_input.py` start twee verse Godot
4.4.1-processen in een kopie met een gecontroleerde, willekeurige gebruikersmap.
De daadwerkelijke autoload vult de InputMap, zonder persoonlijke `controls.cfg`.
Beide processen moeten exact dezelfde 36 actie-ID's, 86 bindings en 16 circulaire
deadzonevoorbeelden opleveren. `input-oracle.json` wordt ongewijzigd als
`BlueMapPlayerInputOracle` in Unity Resources opgenomen.

Unity gebruikt **com.unity.inputsystem 1.20.1**, vastgezet in manifest en lock;
de officiële registry vermeldt Unity 6000.0 als minimum en alleen het ingebouwde
UIElements-module als rechtstreekse afhankelijkheid. De registry-tarball heeft
SHA-1 `2436e68c60c469edbccef8f6b3c319b9441f4675`.
Zie [Unity's pakketdocumentatie](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.20/manual/index.html)
en [Unity 6-pakketinformatie](https://docs.unity3d.com/6000.0/Documentation/Manual/com.unity.inputsystem.html).
De oude invoer blijft naast het nieuwe systeem beschikbaar voor de zes bestaande
presentatiepagina's; de loopproef leest uitsluitend de echte nieuwe Input System.

## Gedrag

- WASD en pijlen lopen; **Ctrl rent, Shift/K rolt**, overeenkomstig de bron.
  Beide Ctrl- en Shift-toetsen werken. Gamepad gebruikt linkerstick/d-pad,
  L3 rennen, B rollen, rechterstick richten en A interactie.
- Alle overige spelactie-ID's blijven beschikbaar, inclusief de ongebonden
  controlleractie `homestead`, techniekmodifier V/LT, de menuacties en vaste UI-invoer.
  Dit betekent niet dat de betreffende gameplay al in fase 8 wordt uitgevoerd.
- Move/Aim gebruiken oorspronkelijke coördinaten met positief Y naar het zuiden;
  MousePosition gebruikt Unity-schermpixels. Gamepad Y wordt eenmaal omgekeerd.
  Onbewerkte stickassen krijgen de oorspronkelijke circulaire deadzone, zonder
  een tweede verborgen Unity-stickdeadzone; diagonalen hebben maximaal lengte 1.
- Verse knoppen of een as die de drempel 0,5 overschrijdt kiezen de controller;
  ingedrukte toetsen, muisknoppen, wiel en minimaal drie pixels muisbeweging kiezen
  toetsenbord/muis. Kleine drift en vastgehouden sticks stelen de muis niet terug.
  Eén geselecteerde gamepad levert acties. Loskoppelen geeft vorige acties vrij.
- Oude fysieke ingedrukte toetsen/sticks komen na omschakelen of focusverlies
  pas terug na loslaten en nieuwe invoer; de verse omschakelende invoer werkt direct.
  Pressed/Released blijven bewaard tot één `Read()` ze consumeert.
- Controller verbergt de muiscursor. Toetsenbord/muis verbergt hem tijdens spelen
  en toont hem in een menu, zoals de bron; een zichtbare crosshair vervangt hem.
  De kijkrichting van het lichaam blijft een afzonderlijk bewegingscontract.
- Rechterstick levert tevens `UiScroll`; de lijst volgt de geselecteerde rij
  en kan onafhankelijk met de rechterstick worden geschoven.

## Kleine bindingsproef

`PlayerControlsPanel` toont per apparaat alle 22 instelbare acties en hun actuele
koppelingen. Toetsenbord, muis en controller kunnen een echte nieuwe invoer
vastleggen. B/Esc sluit; A/Enter kiest; d-pad/linkerstick navigeert; LB/RB wisselt
de categorie. Een enkel conflict wisselt de volledige oude koppelingen om,
meerdere conflicten worden geweigerd. Esc voor sluiten en de rechterstick voor
richten blijven gereserveerd. Een categorie kan worden hersteld.

Deze proef wijzigt bindings **alleen in geheugen**. Er wordt geen persoonlijke
`controls.cfg`, Godot-save of Unity-save gelezen of geschreven. Import/opslag
van gebruikersinstellingen volgt de savefase; de volledige menuport volgt de
UI-fase. Het openen/sluiten van het paneel gebruikt de bestaande sessie-UI-lock.

## Controle en grenzen

`PlayerInputChecks.Verify` gebruikt `InputSystem.AddDevice`, `QueueStateEvent`
en `InputSystem.Update` voor echte virtuele Keyboard-, Mouse- en Gamepad-devices.
Alle 86 bronbindings worden afzonderlijk ingedrukt en losgelaten; daarnaast
worden tegenovergestelde richtingen, beide modifierzijden, diagonalen, drift,
omschakelen, wiel, richten, focusverlies, twee controllers, disconnect/reconnect,
cursorbeleid en echte capture/conflict/reset gecontroleerd. De test bewaart de
update-instelling en cursor, verwijdert uitsluitend eigen testdevices en legt
de vooraf aanwezige apparaatlayouts vast als `HardwareInventory`.

Dit is bewijs voor de native Input System-eventroute, geen claim dat een mens
alle fysieke controllermerken, kabels, draadloze verbindingen of knoppen heeft
doorgespeeld. De volledige gameplay-uitvoering van alle behouden acties en de
uiteindelijke menu-uitstraling blijven bij de latere betreffende fases.

