# Fase 23 — Unity is de hoofdversie

Op 28 november 2026 gaf sjors het laatste go. De branch `claude/affectionate-mendel-vc1idx`, tot nu toe de Godot-game, is doorgeschoven naar de Unity-migratie. Dat is een gewone vooruitspoeling: de Godot-commit `a8a988be27835dec979d2523a3a85a34385eac54` is een voorouder van de Unity-branch, er is niets overschreven en er is geen force-push gebruikt. Pull request 28 is daarmee samengevoegd.

## Wat er nu op de hoofdbranch staat

- Het Unity-project in `unity/`, met alle 22 overgezette fases en hun controles.
- De **volledige Godot-bron, ongewijzigd**: alle 1.732 oorspronkelijke bestanden staan nog op dezelfde plek met dezelfde bytes en Git-modes. Je kunt het project nog steeds in Godot 4.4.1 openen.
- Beide bouwroutes: `Windows-versie bouwen` bouwt en test de Godot-game zoals altijd; `Unity-migratie controleren` controleert de Unity-bron en de gepubliceerde Unity-download, nu ook bij elke wijziging op de hoofdbranch.

De speelbare Unity-versie is de [Windows-download 0.19](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase23-preview-4259c060) uit de afwerkronde hieronder. De omschakeling zelf veranderde geen spelcode en is gedaan op de eindcontroles van fase 22: 801 controles in de echte Windows-speler, 820 Python-tests en alle stappen van de broncontrole.

## Afwerkronde: een gewone opstart

Direct na de omschakeling is de opstart afgewerkt. De game begint nu met een **titelscherm**: Doorgaan (het avontuur dat je het laatst hebt opgeslagen wordt geopend, met je taal en volume), Nieuw spel, Nieuw spel+ zodra je het hebt uitgespeeld, geluid, bediening, opslag en import, afsluiten en de taalknop. Een nieuw avontuur opent met de **openingspagina's** van de Godot-game; in Nieuw spel+ is dat de legende van de Blauwe Kaart. Je levens staan als **hartjes** in beeld, getekend met het oorspronkelijke hartjesbeeld. Escape brengt je vanuit de menu's terug naar het titelscherm; "Opslaan en naar profielen" in het pauzemenu doet dat nu ook. Het scherm voor import van je Godot-opslag zit achter **Opslag en import**.

[Windows-download](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase23-preview-4259c060), versie 0.19.0-phase23. ZIP `BlueMapUnityPreview-phase-23-4259c060-Windows-x64.zip`: 76,774,718 bytes, SHA256 `26fdedb8b39596df5f96d9e20c19eea148baf397d7500411f4533aabf4401dcf`. De echte Windows-speler slaagt voor 802 controles en alle 820 Python-tests zijn groen. Het titelscherm is in de automatische test getekend en op zijn keuzes gecontroleerd; de gewone opstart met muis en toetsenbord is niet door een mens nagelopen.

Voor wie verder wil bouwen staat in [unity/UITBREIDEN.md](../../unity/UITBREIDEN.md) hoe de game in elkaar zit, hoe je inhoud en regels toevoegt en wat eerst een opknapbeurt nodig heeft voordat graphics en engine worden geüpgraded.

## Terug naar Godot blijft mogelijk

- De tag `godot-baseline-0.34.0` wijst naar de laatste Godot-commit `a8a988be27835dec979d2523a3a85a34385eac54`.
- Het [herstelpunt](https://github.com/sjorswakka-sketch/bluemap/releases/tag/godot-baseline-0.34.0) bevat de speelbare Godot-game, de bron en de volledige Git-geschiedenis; zie de [herstelinstructies](../RECOVERY.md).
- Je Unity-voortgang kan terug naar Godot met **Kopie voor Godot** in het profielscherm ([fase 22](../phase-22/README.md)).
- De hoofdbranch terugzetten kan met één nieuwe commit of door de branch weer naar de tag te laten wijzen; dat is een bewuste handeling en gebeurt niet vanzelf.

## Eerlijk over wat "hoofdversie" nu betekent

Unity is de versie waarop verder wordt gebouwd. De Unity-game is nog niet in alles gelijk aan de Godot-game: het kaartbeeld in de epiloog, bewegend water, stoom en vonken en de oefenpoppen in Rafs werkplaats ontbreken nog, en fases 20 en 21 zijn zonder Godot-opname overgezet. De volledige lijst staat bij [fase 22](../phase-22/README.md). De speler heet nog `BlueMapUnityProbe.exe`. GitHub bouwt de Unity-speler niet zelf: de Windows-versie wordt lokaal gebouwd en getest, en GitHub controleert bron en download. Een fysieke controller is niet handmatig getest. Wie de complete oorspronkelijke game wil spelen, gebruikt tot die punten zijn afgewerkt de Godot-download.

De standaardbranch van de repository op GitHub is niet gewijzigd; beide branches wijzen na deze fase naar dezelfde commit. De branch `main` is niet aangeraakt.
