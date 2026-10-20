# Fase 8 — speler, bewegen en bediening

Deze fase brengt lopen, direct rennen, stamina, rollen, zelfstandig richten, lichaamsrichting, camera en toetsenbord/controller over naar Unity. De bestaande Godot-versie en alle oorspronkelijke inhoud blijven behouden; de wereld krijgt geen nieuwe plaatsingen of bebouwing.

De losse Windows-proef opent een loopbare terreinweergave met de oorspronkelijke pixeltegels, boomkronen en speleranimaties. F1, F2 en F3 kiezen dorp, bos en grot; 1–6 blijven de presentatieproeven, 7 de spelbasis en 8 de loopproef. Ctrl rent, Shift/K rolt, P/Esc pauzeert; controller gebruikt linker stick, L3, B, rechter stick en Start. F9, I/Tab of Select opent het tijdelijke bedieningsmenu, inclusief opnieuw koppelen, conflictwissels en rechterstickscrollen. Deze koppelingen bestaan alleen in geheugen.

Alle oorspronkelijke terrein- en objectvoeten uit de gekozen momentopname worden als echte botsingsvormen gebruikt. Voor objecten waarvan de eigen renderer nog volgt, is de voet zichtbaar omrand: er komen geen onzichtbare blokkades bij. De volledige objectweergave, NPC-gedrag, interacties, quests en gevechten volgen in hun afgesproken fases. De speler gebruikt de oorspronkelijke veilige aankomst en heeft een cirkelvoet met straal zeven pixels en acht pixels verschuiving.

Twee onafhankelijke oorspronkelijke Godot-processen leveren elke bewegings- en invoerreferentie. Unity vergelijkt de bronwaarden en voert daarnaast echte native invoergebeurtenissen, botsingsqueries, muis/controllerwissels en presentatiecontroles uit. De proef leest en schrijft geen persoonlijke saves; veilige import is fase 9.

De bouw- en publicatiecontrole is nog in uitvoering; deze fase is pas afgerond als de native Windows-build, pakketverificatie en GitHub-controles slagen.
