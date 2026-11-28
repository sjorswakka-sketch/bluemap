# Fase 23 — Unity is de hoofdversie

Op 28 november 2026 gaf sjors het laatste go. De branch `claude/affectionate-mendel-vc1idx`, tot nu toe de Godot-game, is doorgeschoven naar de Unity-migratie. Dat is een gewone vooruitspoeling: de Godot-commit `a8a988be27835dec979d2523a3a85a34385eac54` is een voorouder van de Unity-branch, er is niets overschreven en er is geen force-push gebruikt. Pull request 28 is daarmee samengevoegd.

## Wat er nu op de hoofdbranch staat

- Het Unity-project in `unity/`, met alle 22 overgezette fases en hun controles.
- De **volledige Godot-bron, ongewijzigd**: alle 1.732 oorspronkelijke bestanden staan nog op dezelfde plek met dezelfde bytes en Git-modes. Je kunt het project nog steeds in Godot 4.4.1 openen.
- Beide bouwroutes: `Windows-versie bouwen` bouwt en test de Godot-game zoals altijd; `Unity-migratie controleren` controleert de Unity-bron en de gepubliceerde Unity-download, nu ook bij elke wijziging op de hoofdbranch.

De speelbare Unity-versie is de [Windows-download van fase 22](https://github.com/sjorswakka-sketch/bluemap/releases/tag/unity-phase22-preview-f22f846e). Fase 23 verandert geen spelcode; er is daarom geen nieuwe build gemaakt. De eindcontroles zijn die van fase 22: 801 controles in de echte Windows-speler, 820 Python-tests en alle stappen van de broncontrole.

## Terug naar Godot blijft mogelijk

- De tag `godot-baseline-0.34.0` wijst naar de laatste Godot-commit `a8a988be27835dec979d2523a3a85a34385eac54`.
- Het [herstelpunt](https://github.com/sjorswakka-sketch/bluemap/releases/tag/godot-baseline-0.34.0) bevat de speelbare Godot-game, de bron en de volledige Git-geschiedenis; zie de [herstelinstructies](../RECOVERY.md).
- Je Unity-voortgang kan terug naar Godot met **Kopie voor Godot** in het profielscherm ([fase 22](../phase-22/README.md)).
- De hoofdbranch terugzetten kan met één nieuwe commit of door de branch weer naar de tag te laten wijzen; dat is een bewuste handeling en gebeurt niet vanzelf.

## Eerlijk over wat "hoofdversie" nu betekent

Unity is de versie waarop verder wordt gebouwd. De Unity-game is nog niet in alles gelijk aan de Godot-game: het titelscherm en de intro, het kaartbeeld in de epiloog, bewegend water, stoom en vonken, hartjes in het HUD en de oefenpoppen in Rafs werkplaats ontbreken nog, en fases 20 en 21 zijn zonder Godot-opname overgezet. De volledige lijst staat bij [fase 22](../phase-22/README.md). De speler heet nog `BlueMapUnityProbe.exe` en toont "Unity-proef · fase 22". GitHub bouwt de Unity-speler niet zelf: de Windows-versie wordt lokaal gebouwd en getest, en GitHub controleert bron en download. Een fysieke controller is niet handmatig getest. Wie de complete oorspronkelijke game wil spelen, gebruikt tot die punten zijn afgewerkt de Godot-download.

De standaardbranch van de repository op GitHub is niet gewijzigd; beide branches wijzen na deze fase naar dezelfde commit. De branch `main` is niet aangeraakt.
