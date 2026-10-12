extends SceneTree
## Zoekt alle tekst die de speler kan zien, voor de vertaling (translations/*.po). Gebruikt door tools/i18n.py
## (subcommando extract) en door tests/taal_test.gd.
##
##   godot --headless --path . -s tools/i18n_extract.gd -- --out=/pad/naar/teksten.json
##
## Twee bronnen, zonder gokwerk:
##   1. De data: de echte woordenboeken van het spel (gesprekken, voorwerpen, opdrachten, personages, vijanden,
##      prestaties, winkels, alle kaarten, de aftiteling, de boeken van het Zilvermeer, de arena...), inclusief alles
##      wat de uitbreidingen (scripts/data/ext/) toevoegen. Zie collect_data().
##   2. De code: elke aanroep van tr("..."), tr_n("...", "...", n), TranslationServer.translate("...") en
##      TranslationServer.translate_plural("...", "...", n) met letterlijke tekst, in alle scripts onder scripts/.
##      Een regel commentaar vlak boven de aanroep die begint met "# Vertalers:" komt als uitleg in het PO-bestand.
##
## Het resultaat is een lijst teksten: {msgid, plural, ctx, comments, refs}. Daarnaast `unclaimed`: tekst-achtige
## waarden in de data die geen van beide bronnen heeft gevonden (die moeten er ook bij, zie tests/taal_test.gd).

const Dialogue := preload("res://scripts/data/dialogue.gd")
const Items := preload("res://scripts/data/items.gd")
const Quests := preload("res://scripts/data/quests.gd")
const Npcs := preload("res://scripts/data/npcs.gd")
const Enemies := preload("res://scripts/data/enemies.gd")
const Achievements := preload("res://scripts/data/achievements.gd")
const Shops := preload("res://scripts/data/shops.gd")
const Credits := preload("res://scripts/data/credits.gd")
const Maps := preload("res://scripts/maps/registry.gd")
const Content := preload("res://scripts/data/content.gd")
const Boeken := preload("res://scripts/data/ext/meer_boeken.gd")
const Beroepen := preload("res://scripts/data/ext/beroepen.gd")

const CODE_ROOT := "res://scripts"
## Sleutels in de data waarvan de waarde nooit tekst voor de speler is (de guard in find_unclaimed slaat ze over).
const NOT_TEXT_KEYS := ["rows", "sheet", "type", "music", "weather", "item", "id", "to", "spawn", "talk", "trophy", "behavior"]
## Context voor de aanvallen achter de naam van een vijand ("Kristalgolem (klap)"), zie Enemies.ATTACKS en hud.gd.
const ATTACK_CONTEXT := "aanval"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var result := collect()
	var json := JSON.stringify(result, "\t")
	if out == "":
		print(json)
	else:
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file == null:
			printerr("Kan %s niet schrijven" % out)
			quit(1)
			return
		file.store_string(json)
		file.close()
		print("I18N EXTRACT OK: %d teksten, %d fouten, %d zonder vertaling-bron" % [
			result["entries"].size(), result["errors"].size(), result["unclaimed"].size()])
	quit(0 if result["errors"].is_empty() else 1)


# --- Verzamelen --------------------------------------------------------------------------------------------------

## Alles: {"entries": [...], "errors": [...], "unclaimed": [...]}.
static func collect() -> Dictionary:
	var c := Collector.new()
	collect_data(c)
	collect_code(c)
	c.attach_refs()
	return {"entries": c.entries(), "errors": c.errors, "unclaimed": find_unclaimed(c)}


## Een verzameling teksten. Een tekst is uniek per (context, msgid); dezelfde tekst op meer plekken krijgt alle
## uitleg en verwijzingen.
class Collector:
	var order: Array[String] = []
	var by_key: Dictionary = {}
	var errors: Array[String] = []
	var literal_refs: Dictionary = {} # tekst -> ["scripts/...:regel"] voor elke letterlijke tekst in de scripts

	func key_of(msgid: String, ctx: String) -> String:
		return ctx + "\u0004" + msgid

	func add(msgid: String, comment: String, ctx := "", plural := "", ref := "") -> void:
		if msgid.strip_edges() == "":
			return
		var key := key_of(msgid, ctx)
		if not by_key.has(key):
			by_key[key] = {"msgid": msgid, "plural": plural, "ctx": ctx, "comments": [], "refs": []}
			order.append(key)
		var entry: Dictionary = by_key[key]
		if entry["plural"] != plural:
			if entry["plural"] == "" or plural == "":
				errors.append("\"%s\" staat er zowel met als zonder meervoud in (%s)" % [msgid, ref if ref != "" else comment])
			else:
				errors.append("\"%s\" heeft twee verschillende meervouden: \"%s\" en \"%s\"" % [msgid, entry["plural"], plural])
		if comment != "" and not comment in entry["comments"] and entry["comments"].size() < 6:
			entry["comments"].append(comment)
		if ref != "" and not ref in entry["refs"]:
			entry["refs"].append(ref)

	## Elke tekst krijgt ook de plekken in de scripts waar hij letterlijk staat (de data), hooguit vier.
	func attach_refs() -> void:
		for key: String in order:
			var entry: Dictionary = by_key[key]
			for ref: String in literal_refs.get(entry["msgid"], []):
				if entry["refs"].size() >= 4:
					break
				if not ref in entry["refs"]:
					entry["refs"].append(ref)

	func entries() -> Array:
		var list: Array = []
		for key: String in order:
			list.append(by_key[key])
		return list

	func has_text(text: String) -> bool:
		for key: String in order:
			if by_key[key]["msgid"] == text or by_key[key]["plural"] == text:
				return true
		return false


## 1. Alle tekst uit de data (Nederlands), met uitleg voor de vertalers.
static func collect_data(c: Collector) -> void:
	var menu_pages: GDScript = load("res://scripts/ui/menu_pages.gd") # gebruikt GameState: pas nu laden
	# Kaarten: naam (en de vorm midden in een zin, zie menu_pages.in_sentence), borden, gesloten deuren...
	for map_id: String in Maps.MAPS:
		var data: Dictionary = Maps.get_map(map_id)
		var map_name: String = data.get("name", "")
		c.add(map_name, "Naam van gebied %s" % map_id)
		var in_sentence: String = menu_pages.in_sentence(map_name)
		if in_sentence != map_name:
			c.add(in_sentence, "Naam van gebied %s midden in een zin (\"Reizen naar %%s?\"); de vorm met hoofdletter is \"%s\"" % [map_id, map_name])
		var objects: Array = data.get("objects", [])
		for i in objects.size():
			var obj: Dictionary = objects[i]
			var where := "Kaart %s, %s %s" % [map_id, obj.get("type", "?"), str(obj.get("pos", ""))]
			for line: String in obj.get("lines", []):
				c.add(line, where + ": tekst op een bord")
			if obj.has("speaker"):
				c.add(obj["speaker"], where + ": wie er spreekt")
			if obj.has("locked_text"):
				c.add(obj["locked_text"], where + ": melding als hij op slot zit")
			_add_actions(c, obj.get("do", []), where)
	# Gesprekken.
	for talk_id: String in Dialogue.TALKS:
		var talk: Dictionary = Dialogue.TALKS[talk_id]
		var speaker: String = talk.get("speaker", "")
		var where := "Gesprek %s" % talk_id
		c.add(speaker, "Naam van wie er praat (%s)" % where)
		for line: String in talk.get("lines", []):
			c.add(line, where + (", %s zegt" % speaker if speaker != "" else ", verteller"))
		for choice: Dictionary in talk.get("choices", []):
			c.add(choice.get("text", ""), where + ": keuze van de speler")
			_add_actions(c, choice.get("do", []), where)
		_add_actions(c, talk.get("do", []), where)
	# Personages, opdrachten, voorwerpen, zwaarden.
	for npc_id: String in Npcs.NPCS:
		c.add(Npcs.NPCS[npc_id].get("name", ""), "Naam van personage %s (boven zijn hoofd)" % npc_id)
	for quest_id: String in Quests.QUESTS:
		var quest: Dictionary = Quests.QUESTS[quest_id]
		c.add(quest.get("title", ""), "Titel van opdracht %s" % quest_id)
		var steps: Array = quest.get("steps", [])
		for i in steps.size():
			c.add(steps[i].get("text", ""), "Opdracht %s, stap %d" % [quest_id, i + 1])
	for item_id: String in Items.ITEMS:
		var item: Dictionary = Items.ITEMS[item_id]
		c.add(item.get("name", ""), "Naam van voorwerp %s" % item_id)
		c.add(item.get("desc", ""), "Beschrijving van voorwerp %s" % item_id)
		for field: String in ["full_text", "almost_full_text", "chest_full_text"]:
			if item.has(field):
				c.add(item[field], "Voorwerp %s: melding (%s)" % [item_id, field])
	for weapon_id: String in Items.WEAPONS:
		c.add(Items.WEAPONS[weapon_id].get("name", ""), "Naam van zwaard %s" % weapon_id)
	# Vijanden (naam, beestenboek, tip) en hun aanvallen.
	for kind: String in Enemies.ENEMIES:
		var enemy: Dictionary = Enemies.ENEMIES[kind]
		c.add(enemy.get("name", ""), "Naam van vijand %s" % kind)
		c.add(enemy.get("desc", ""), "Vijand %s: grappige beschrijving in het beestenboek" % kind)
		c.add(enemy.get("hint", ""), "Vijand %s: tip als je hem voor het eerst ziet" % kind)
	for attack: String in Enemies.ATTACKS:
		c.add(attack, "Een aanval van een vijand, tussen haakjes achter zijn naam: \"Kristalgolem (klap)\" op het game-over-scherm", ATTACK_CONTEXT)
	# Prestaties en winkels.
	for id: String in Achievements.ACHIEVEMENTS:
		var achievement: Dictionary = Achievements.ACHIEVEMENTS[id]
		c.add(achievement.get("name", ""), "Naam van prestatie %s" % id)
		c.add(achievement.get("desc", ""), "Uitleg bij prestatie %s" % id)
	for shop_id: String in Shops.SHOPS:
		var shop: Dictionary = Shops.SHOPS[shop_id]
		c.add(shop.get("name", ""), "Naam van winkel %s" % shop_id)
		for entry: Dictionary in shop.get("items", []):
			if entry.has("label"):
				c.add(entry["label"], "Winkel %s: naam in de lijst (%s)" % [shop_id, entry.get("item", "")])
	# De arena (pas laden nu het spel draait: het script gebruikt GameState).
	var arena: GDScript = load("res://scripts/data/arena.gd")
	for rank: String in arena.RANKS:
		c.add(arena.RANKS[rank].get("name", ""), "Naam van arena-rang %s" % rank)
		c.add(arena.RANKS[rank].get("title", ""), "Titel die je krijgt voor arena-rang %s (\"Hé {arena_title}!\")" % rank)
	# De boeken in de bibliotheek van het Zilvermeer.
	for book_id: String in Boeken.TEXTS:
		var book: Dictionary = Boeken.TEXTS[book_id]
		c.add(book.get("title", ""), "Titel van boek %s (bibliotheek)" % book_id)
		for line: String in book.get("lines", []):
			c.add(line, "Boek %s (bibliotheek)" % book_id)
	# Stipjes op het kaartje (legenda) van de uitbreidingen.
	var markers := Content.map_markers()
	for marker_type: String in markers:
		c.add(markers[marker_type].get("label", ""), "Legenda op het kaartje (menu): %s" % marker_type)
	# Beroepen: UI-sjablonen en grondstoffen zijn data, geen letterlijke tr-aanroepen.
	for text_id: String in Beroepen.TEXT:
		c.add(Beroepen.TEXT[text_id], "Beroepen: tekst of sjabloon %s" % text_id)
	for skill_id: String in Beroepen.SKILLS:
		for field: String in ["name", "desc"]:
			c.add(Beroepen.SKILLS[skill_id].get(field, ""), "Beroep %s: %s" % [skill_id, field])
	for resource_id: String in Beroepen.RESOURCES:
		c.add(Beroepen.RESOURCES[resource_id].get("name", ""), "Oogstbare grondstof %s" % resource_id)
	# Receptnamen komen nu van hun uitvoervoorwerp. Neem eventuele eigen
	# beschrijvingen ook mee als een uitbreiding ze later toevoegt.
	for recipe_id: String in Beroepen.RECIPES:
		for field: String in ["name", "desc", "hint"]:
			c.add(Beroepen.RECIPES[recipe_id].get(field, ""), "Recept %s: %s" % [recipe_id, field])
	# De invoermodule gebruikt autoloads: net als menu_pages pas nu laden.
	var controls: GDScript = load("res://scripts/core/input_manager.gd")
	for action: String in controls.ACTION_NAMES:
		c.add(controls.ACTION_NAMES[action], "Instelbare bediening: %s" % action)
	for label: String in controls.JOY_NAMES:
		c.add(label, "Naam van een controllerknop; Xbox / PlayStation waar van toepassing")
	# De aftiteling.
	for entry: Array in Credits.LINES:
		if entry[0] != "":
			c.add(entry[1], "Aftiteling (%s)" % entry[0])


## Teksten in acties: ["toast", "..."] (een melding).
static func _add_actions(c: Collector, actions: Array, where: String) -> void:
	for action: Array in actions:
		if action.size() > 1 and action[0] == "toast":
			c.add(action[1], where + ": melding")


# --- De code ---------------------------------------------------------------------------------------------------

## 2. Alle letterlijke teksten in tr(), tr_n() en TranslationServer.translate(_plural)() in scripts/.
static func collect_code(c: Collector) -> void:
	for path: String in _script_files(CODE_ROOT):
		scan_source(c, path, FileAccess.get_file_as_string(path))


static func _script_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	var names := dir.get_files()
	names.sort()
	for file_name: String in names:
		if file_name.ends_with(".gd"):
			files.append(dir_path.path_join(file_name))
	var subdirs := dir.get_directories()
	subdirs.sort()
	for sub: String in subdirs:
		files.append_array(_script_files(dir_path.path_join(sub)))
	return files


## Leest één script: commentaar overslaan, alle letterlijke teksten onthouden (voor de verwijzingen) en de
## vertaal-aanroepen eruit halen.
static func scan_source(c: Collector, path: String, source: String) -> void:
	var rel := path.trim_prefix("res://")
	var lines := source.split("\n")
	var i := 0
	var line := 1
	var n := source.length()
	while i < n:
		var ch := source[i]
		if ch == "\n":
			line += 1
			i += 1
		elif ch == "#":
			while i < n and source[i] != "\n":
				i += 1
		elif ch == "\"" or ch == "'":
			var lit := _read_string(source, i)
			if lit.is_empty():
				c.errors.append("%s:%d: tekst zonder eind" % [rel, line])
				return
			var refs: Array = c.literal_refs.get(lit["value"], [])
			refs.append("%s:%d" % [rel, line])
			c.literal_refs[lit["value"]] = refs
			line += source.substr(i, lit["end"] - i).count("\n")
			i = lit["end"]
		elif _is_ident_start(ch):
			var start := i
			while i < n and _is_ident_char(source[i]):
				i += 1
			var word := source.substr(start, i - start)
			var kind := ""
			if word == "tr" or word == "tr_n":
				kind = word
			elif (word == "translate" or word == "translate_plural") and start >= 18 and source.substr(start - 18, 18) == "TranslationServer.":
				kind = "tr" if word == "translate" else "tr_n"
			if kind == "":
				continue
			var j := i
			while j < n and (source[j] == " " or source[j] == "\t"):
				j += 1
			if j >= n or source[j] != "(":
				continue
			if start >= 5 and source.substr(start - 5, 5) == "func ":
				continue # de definitie zelf
			var call := _read_args(source, j + 1)
			if call.is_empty():
				c.errors.append("%s:%d: aanroep van %s zonder eind" % [rel, line, word])
				continue
			_add_call(c, kind, call["args"], rel, line, _translator_comment(lines, line))
			# Verder lezen vanaf het haakje: aanroepen in de argumenten (tr_n(...) % tr(...)) tellen ook mee.
		else:
			i += 1


## Uitleg voor vertalers: regels "# Vertalers: ..." direct boven de aanroep.
static func _translator_comment(lines: PackedStringArray, line: int) -> String:
	var notes: Array[String] = []
	var k := line - 2 # index van de regel erboven
	while k >= 0:
		var text := lines[k].strip_edges()
		var match_at := text.find("Vertalers:")
		if text.begins_with("#") and match_at >= 0:
			notes.push_front(text.substr(match_at + "Vertalers:".length()).strip_edges())
			k -= 1
		else:
			break
	return " ".join(notes)


## Zet een gevonden aanroep om in een tekst. Alleen letterlijke teksten tellen: tr(naam) vertaalt data.
static func _add_call(c: Collector, kind: String, args: Array, rel: String, line: int, note: String) -> void:
	var ref := "%s:%d" % [rel, line]
	if args.is_empty() or args[0] == null:
		return
	if kind == "tr":
		var ctx := ""
		if args.size() > 1:
			if args[1] == null:
				c.errors.append("%s: de context van tr() moet letterlijke tekst zijn" % ref)
				return
			ctx = args[1]
		c.add(args[0], note, ctx, "", ref)
	else:
		if args.size() < 3 or args[1] == null:
			c.errors.append("%s: tr_n() heeft letterlijke tekst nodig voor enkelvoud en meervoud" % ref)
			return
		var ctx := ""
		if args.size() > 3:
			if args[3] == null:
				c.errors.append("%s: de context van tr_n() moet letterlijke tekst zijn" % ref)
				return
			ctx = args[3]
		c.add(args[0], note, ctx, args[1], ref)


static func _is_ident_start(ch: String) -> bool:
	return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_"


static func _is_ident_char(ch: String) -> bool:
	return _is_ident_start(ch) or (ch >= "0" and ch <= "9")


## Leest een letterlijke tekst die begint bij `at` (een " of '). Geeft {"value", "end"} of {} als hij niet eindigt.
static func _read_string(source: String, at: int) -> Dictionary:
	var quote := source[at]
	var triple := source.substr(at, 3) == quote.repeat(3)
	var i := at + (3 if triple else 1)
	var value := ""
	var n := source.length()
	while i < n:
		var ch := source[i]
		if ch == "\\" and i + 1 < n:
			var next := source[i + 1]
			match next:
				"n":
					value += "\n"
				"t":
					value += "\t"
				"r":
					value += "\r"
				"\\", "\"", "'":
					value += next
				"u":
					value += char(source.substr(i + 2, 4).hex_to_int())
					i += 4
				_:
					value += "\\" + next
			i += 2
			continue
		if triple and source.substr(i, 3) == quote.repeat(3):
			return {"value": value, "end": i + 3}
		if not triple and ch == quote:
			return {"value": value, "end": i + 1}
		if not triple and ch == "\n":
			return {}
		value += ch
		i += 1
	return {}


## Leest de argumenten van een aanroep (na het openingshaakje). Een argument dat alleen uit één letterlijke tekst
## bestaat wordt die tekst; al het andere wordt null. Geeft {"args", "end"} of {} als het haakje niet sluit.
static func _read_args(source: String, at: int) -> Dictionary:
	var args: Array = []
	var depth := 0
	var i := at
	var n := source.length()
	var current_literal: Variant = null
	var current_other := false
	while i < n:
		var ch := source[i]
		if ch == "\"" or ch == "'":
			var lit := _read_string(source, i)
			if lit.is_empty():
				return {}
			if depth == 0 and current_literal == null and not current_other:
				current_literal = lit["value"]
			else:
				current_other = true
			i = lit["end"]
			continue
		if ch == "#":
			while i < n and source[i] != "\n":
				i += 1
			continue
		if ch in ["(", "[", "{"]:
			depth += 1
			current_other = true
		elif ch in [")", "]", "}"]:
			if depth == 0:
				if current_literal != null or current_other:
					args.append(current_literal if not current_other else null)
				return {"args": args, "end": i + 1}
			depth -= 1
		elif ch == "," and depth == 0:
			args.append(current_literal if not current_other else null)
			current_literal = null
			current_other = false
		elif not ch in [" ", "\t", "\n", "\r"]:
			current_other = true
		i += 1
	return {}


# --- Controle: tekst in de data die nergens gevonden is ---------------------------------------------------------

## Tekst-achtige waarden in de data (een spatie erin, of een hoofdletter vooraan) die de extractie niet kent. Als die
## lijst niet leeg is, toont het spel tekst die niet vertaald kan worden: voeg hem toe aan collect_data().
static func find_unclaimed(c: Collector) -> Array:
	var found: Array = []
	var sources: Array = [Dialogue, Items, Quests, Npcs, Enemies, Achievements, Shops, Credits, Boeken]
	sources.append_array(Content.MODULES)
	sources.append(load("res://scripts/data/arena.gd"))
	sources.append(load("res://scripts/core/input_manager.gd"))
	for script: Script in sources:
		var constants := script.get_script_constant_map()
		for name: String in constants:
			_walk(constants[name], "%s.%s" % [script.resource_path.get_file(), name], c, found)
	for map_id: String in Maps.MAPS:
		_walk(Maps.get_map(map_id), "kaart %s" % map_id, c, found)
	return found


static func _walk(value: Variant, where: String, c: Collector, found: Array) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			for key: Variant in dict:
				if typeof(key) == TYPE_STRING and key in NOT_TEXT_KEYS:
					continue
				_walk(dict[key], "%s/%s" % [where, str(key)], c, found)
		TYPE_ARRAY:
			var list: Array = value
			for i in list.size():
				_walk(list[i], "%s/%d" % [where, i], c, found)
		TYPE_STRING:
			var text: String = value
			if _looks_like_text(text) and not c.has_text(text):
				found.append("%s: %s" % [where, text])


static func _looks_like_text(text: String) -> bool:
	if text.begins_with("res://") or text.begins_with("user://"):
		return false
	var first := text.substr(0, 1)
	return " " in text or (first == first.to_upper() and first != first.to_lower())


# --- PO-bestanden lezen en plaatsaanduidingen vergelijken (voor tests/taal_test.gd; tools/i18n.py doet hetzelfde) ---

## Leest een PO-bestand: een lijst {msgid, plural, ctx, forms (de vertaling(en)), fuzzy}, zonder de kop.
static func read_po(path: String) -> Array:
	var entries: Array = []
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return entries
	var entry := _new_po_entry()
	var field := ""
	var form := -1
	var started := false
	var keyword := RegEx.create_from_string("^(msgctxt|msgid_plural|msgid|msgstr)(?:\\[(\\d+)\\])?\\s+\"(.*)\"\\s*$")
	var continuation := RegEx.create_from_string("^\"(.*)\"\\s*$")
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or (line.begins_with("#") and started and field != "msgctxt" and field != ""):
			if started:
				_finish_po_entry(entry, entries)
				entry = _new_po_entry()
				started = false
				field = ""
			if line == "":
				continue
		if line.begins_with("#"):
			if line.begins_with("#,") and "fuzzy" in line:
				entry["fuzzy"] = true
			continue
		var m := keyword.search(line)
		if m != null:
			var name := m.get_string(1)
			if (name == "msgid" or name == "msgctxt") and started and field != "msgctxt":
				_finish_po_entry(entry, entries)
				entry = _new_po_entry()
			started = true
			field = name
			form = int(m.get_string(2)) if m.get_string(2) != "" else -1
			_append_po(entry, field, form, _po_unescape(m.get_string(3)))
			continue
		var c := continuation.search(line)
		if c != null and field != "":
			_append_po(entry, field, form, _po_unescape(c.get_string(1)))
	if started:
		_finish_po_entry(entry, entries)
	return entries


static func _new_po_entry() -> Dictionary:
	return {"msgid": "", "plural": "", "ctx": "", "forms": [], "fuzzy": false}


static func _append_po(entry: Dictionary, field: String, form: int, value: String) -> void:
	match field:
		"msgid":
			entry["msgid"] += value
		"msgid_plural":
			entry["plural"] += value
		"msgctxt":
			entry["ctx"] += value
		"msgstr":
			var index := maxi(form, 0)
			while entry["forms"].size() <= index:
				entry["forms"].append("")
			entry["forms"][index] += value


static func _finish_po_entry(entry: Dictionary, entries: Array) -> void:
	if entry["msgid"] != "" or entry["ctx"] != "":
		entries.append(entry)


static func _po_unescape(text: String) -> String:
	var out := ""
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch == "\\" and i + 1 < text.length():
			var next := text[i + 1]
			match next:
				"n":
					out += "\n"
				"t":
					out += "\t"
				"r":
					out += "\r"
				"\\", "\"":
					out += next
				_:
					out += "\\" + next
			i += 2
		else:
			out += ch
			i += 1
	return out


## Waarom de plaatsaanduidingen van een vertaling niet kloppen, of "" als ze kloppen. %-tekens moeten in dezelfde
## volgorde staan (GDScript vult "%s %d" % [...] op volgorde in); {tekens} mogen overal staan.
static func placeholder_problem(source: String, translation: String) -> String:
	var printf := RegEx.create_from_string("%(?:%|[-+0*]*\\d*(?:\\.(?:\\d+|\\*))?[scdoxXfv])")
	var token := RegEx.create_from_string("\\{[A-Za-z_][A-Za-z0-9_]*\\}")
	var lists := []
	for text: String in [source, translation]:
		var marks: Array[String] = []
		var percent := 0
		for m in printf.search_all(text):
			if m.get_string() == "%%":
				percent += 1
			else:
				marks.append(m.get_string())
		var tokens: Array[String] = []
		for m in token.search_all(text):
			tokens.append(m.get_string())
		tokens.sort()
		lists.append([marks, percent, tokens])
	if lists[0][0] != lists[1][0]:
		return "%%-tekens: %s in de brontekst, %s in de vertaling" % [" ".join(lists[0][0]), " ".join(lists[1][0])]
	if lists[0][1] != lists[1][1]:
		return "%% (procentteken): %d in de brontekst, %d in de vertaling" % [lists[0][1], lists[1][1]]
	if lists[0][2] != lists[1][2]:
		return "{tekens}: %s in de brontekst, %s in de vertaling" % [" ".join(lists[0][2]), " ".join(lists[1][2])]
	return ""
