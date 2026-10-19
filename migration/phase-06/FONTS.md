# De oorspronkelijke fonts behouden

De primaire font is de daadwerkelijke `ThemeDB.fallback_font` uit exact Godot `4.4.1.stable.official.49a5bc7b6`: **Open Sans SemiBold 1.10**. De geëxtraheerde 46.392 WOFF2-bytes hebben SHA256 `661e2d9975d3029aeb32bf37b1b963c31c7c3ce08ac1bab2c8ebe27e135c4ec2`, identiek aan de [gepinde Godot-bron](https://github.com/godotengine/godot/blob/4.4.1-stable/thirdparty/fonts/OpenSans_SemiBold.woff2). Het gaat om de gamefont; andere editorfonts zijn geen vervanging.

De 104 verschillende tekens in de bestaande NL/EN-PO zijn behouden. De recorder controleert daarnaast cijfers, letters en expliciete UI-testtekens: samen 106 codepoints. Zes bestaande symbolen ontbreken in de primaire font: `← ↑ → ↓ ■ ●` (8592–8595, 9632, 9679). Godot stond hiervoor OS-fontfallback toe. In Unity is de aanvullende keuze expliciet: de [met Godot meegeleverde DroidSansFallback](https://github.com/godotengine/godot/blob/4.4.1-stable/thirdparty/fonts/DroidSansFallback.woff2), SHA256 `b41f0f026055325a1c78c7f380e811ab0a5122d1c26a85ec1243f3c024c66002`. Alleen de zes symbolen worden aan dit aanvullende gezicht toegewezen. Dit maakt de keuze platformonafhankelijk en claimt niet dat iedere oorspronkelijke computer hetzelfde OS-gezicht gebruikte.

De Resources-sleutels zijn `BlueMapAssets/Fonts/DefaultFont` en `BlueMapAssets/Fonts/FallbackFont`. Naast beide TTF's staan de oorspronkelijke WOFF2-containers, `font-manifest.json`, Apache-2.0 en copyright-/wijzigingsmeldingen in de Fonts-map. Beide fonts vallen volgens [Godots officiële fontinventaris](https://github.com/godotengine/godot/blob/4.4.1-stable/thirdparty/README.md#fonts) onder Apache 2.0; er zijn geen fonts van de gebruikerscomputer gekopieerd.

## Reproduceerbare conversie

`record_migration_font.py` controleert eerst de enginepin, maakt een aparte projectkopie met UUID-projectnaam en verifieert de werkelijke testopslag voordat het exporteert. Het opent geen bestaande saves. `migration_font_export.gd` leest de echte FontFile-bytes en legt glyphbeschikbaarheid en Godot-advance-/regelmetingen vast voor dertien lettergroottes.

De expliciete conversiestap vereist `fonttools==4.60.1` en `brotli==1.2.0`, bijvoorbeeld in een aparte tijdelijke `pip --target`-map. De converter herberekent geen timestamp. Hij vergelijkt voor ieder font alle zeventien ongecomprimeerde tabellen vóór en na WOFF2→TTF. Alleen de vier `head.checkSumAdjustment`-bytes zijn containerafhankelijk en worden voor die vergelijking geneutraliseerd; namen, outlines, tekenmapping, hints, maten en overige tabelbytes moeten gelijk zijn.

Opnieuw opnemen gebruikt nieuwe uitvoer- en bewijsmappen:

```text
python tools/record_migration_font.py <Godot-4.4.1-executable> --font-deps <tijdelijke-gepinde-dependencies> --output-dir <nieuwe-fontmap> --evidence-dir <nieuwe-externe-bewijsmap>
python -m unittest discover -s tests/migration -p test_migration_font.py
```

De standaardbron voor de aanvullende WOFF2 is het reeds behouden `FallbackFont.woff2.bytes`; de recorder heeft dus geen netwerk nodig. `--fallback-woff2` kan een andere kopie van dezelfde vastgepinde bytes aanwijzen. De tests hebben alleen Python-stdlib nodig: ze controleren hashes, tabellen, glyphcontract, licentie en negatieve fixtures voor beschadigde tabeldirectories en gewijzigde outlines.

Hetzelfde fontgezicht en dezelfde outlines bewijzen geen identieke Godot/Unity-rasterisatie, kerning of regelafbreking. De volledige UI-layout en interactieve menu's worden in hun eigen migratiefase gecontroleerd.
