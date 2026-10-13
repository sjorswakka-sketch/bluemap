extends RefCounted
## Uitbreiding "dagritme": achtergrondsfeer die meebeweegt met de klok, per klimaat.
## Vier klimaten (bos, sneeuw, dorst, moeras) x vier dagdelen = zestien lussen.
## De wereld kiest er een via Daynight.ambience(); scripts/entities/atmosphere.gd speelt hem af.
## De lussen zelf maken tools/audio_x_dagritme.py en audio_x_moeras.py (python tools/make_audio.py).

const SOUNDS := [
	"amb_bos_ochtend", "amb_bos_dag", "amb_bos_avond", "amb_bos_nacht",
	"amb_sneeuw_ochtend", "amb_sneeuw_dag", "amb_sneeuw_avond", "amb_sneeuw_nacht",
	"amb_dorst_ochtend", "amb_dorst_dag", "amb_dorst_avond", "amb_dorst_nacht",
	"amb_moeras_ochtend", "amb_moeras_dag", "amb_moeras_avond", "amb_moeras_nacht",
]
