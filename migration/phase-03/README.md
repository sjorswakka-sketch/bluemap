# Fase 3 — afzonderlijk migratiespoor

Status: in uitvoering; bron- en pakketcontroles worden nu gepubliceerd en vervolgens met een echte Windows-proefdownload gecontroleerd.

Dezelfde repository blijft behouden. De huidige game en haar herstelpunt blijven op de Claude-branch en de Godot-tag; de Unity-port staat op codex/unity-migration.

De nieuwe workflow controleert bronbehoud, Unity-instellingen, eigen negatieve migratie-/pakkettests en het starten van Godot naast de Unity-map. Ze valideert straks de op de geactiveerde werkplek gebouwde Windows-proef; de workflow compileert Unity niet en bevat geen activatiegegevens.

Voor de lokale route gebruik je tools/build_unity_probe.py met de vastgepinde editor en een nieuwe externe uitvoermap; eerst moeten alle bouwinvoerbestanden gecommit zijn. De build wordt uitsluitend in een tijdelijke projectkopie gemaakt, met ingebedde broncommit en invoerfingerprint. Elke download noemt fase en broncommit en bevat controleerbare bestandschecksums; ruwe logs en persoonlijke saves blijven buiten de download.

Een daaropvolgend bewijscommit koppelt de werkelijk geteste release en GitHub-run aan deze bron; het laatste go van fase 3 start de volgende fase nog niet.
