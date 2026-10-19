#!/usr/bin/env python3
"""Document the preserved Godot rule language; do not execute or port its rules.

The scanner checks authored JSON invocations in the effective catalogs, source
declarations and registry map views. It does not interpret arbitrary GDScript,
simulate a world, or infer that an argument which passes a shape check will be
usable in every runtime state. Source functions remain the algorithm authority.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import re


class RuleContractError(ValueError):
    """The authored rule data or documented contract is inconsistent."""


CONDITION_FIELDS = {"if", "requires", "block_if", "advance_if", "exists_if", "open_if", "conditions"}
ACTION_FIELDS = {"do", "actions"}
CORE = "scripts/core/game_state.gd"
CONTENT = "scripts/data/content.gd"
EXT = "scripts/data/ext/"


def _arg(name, kind="string", namespace=None, *, optional=False, default=None, values=None):
    result = {"name": name, "type": kind, "optional": optional}
    if namespace:
        result["namespace"] = namespace
    if optional:
        result["default"] = default
    if values is not None:
        result["allowedValues"] = values
    return result


def _definition(identifier, arguments, semantics, module=None, delegates=(), variadic=None):
    return {"id": identifier, "arguments": arguments, "semantics": semantics,
            "module": module, "delegates": delegates, "variadic": variadic}


def _definitions():
    flag = lambda: _arg("flag", namespace="open_flags")
    quest = lambda: _arg("quest", namespace="quests")
    item = lambda: _arg("item", namespace="items")
    amount = lambda: _arg("amount", "integer", optional=True, default=1)
    threshold = lambda: _arg("threshold", "integer")
    conditions = [
        _definition("flag", [flag()], "Return flags.get(flag, false); absent flags are false."),
        _definition("no_flag", [flag()], "Negate flag(flag)."),
        _definition("quest", [quest(), _arg("state", values=["none", "active", "done"])], "Compare quest_state; an absent quest has state none."),
        _definition("step", [quest(), _arg("step", "integer")], "True only when quest is active AND quest_step equals step; absent step is -1."),
        _definition("has", [item(), amount()], "Inventory count >= amount; omitted amount is 1."),
        _definition("lacks", [item(), amount()], "Inventory count < amount; omitted amount is 1."),
        _definition("coins", [threshold()], "Current coins >= threshold."),
        _definition("map", [_arg("map", namespace="maps")], "Current map_id equals map."),
        _definition("weapon", [_arg("weapon", namespace="weapons")], "Current weapon equals weapon ID."),
        _definition("crystals", [threshold()], "crystal_count() >= threshold."),
        _definition("hurt", [], "Current hp < max_hp()."),
    ]
    world = [
        ("kills", [threshold()], "kills >= int(threshold)."),
        ("kills_of", [_arg("enemy", namespace="enemies"), threshold()], "int(kills_by.get(enemy, 0)) >= int(threshold)."),
        ("kinds_killed", [_arg("enemies", "string_array", "enemies")], "Every listed enemy has kills_by count > 0; empty list returns true."),
        ("rolls", [threshold()], "rolls >= int(threshold)."),
        ("potions_drunk", [threshold()], "potions_drunk >= int(threshold)."),
        ("talked_to_all", [_arg("npcs", "string_array", "npcs")], "Every listed NPC key occurs in talked; empty list returns true."),
        ("max_deaths", [threshold()], "deaths <= int(threshold)."),
        ("max_boss_deaths", [threshold()], "boss_deaths <= int(threshold)."),
        ("finished_within", [_arg("seconds", "number")], "game_completed flag AND play_time <= float(seconds)."),
        ("chests_in", [_arg("maps", "string_array", "maps")], "Every listed map has a chest:<map>: prefix in saved flag keys; helper checks key existence, not bool value. Empty list returns true."),
        ("phase", [_arg("phase", values=["ochtend", "dag", "avond", "nacht"])], "Daynight.phase_at(day_time) equals the supplied Dutch phase token."),
    ]
    for identifier, arguments, semantics in world:
        delegates = [(EXT + "wereld.gd", "_chest_opened_in")] if identifier == "chests_in" else []
        if identifier == "phase":
            delegates.append(("scripts/core/daynight.gd", "phase_at"))
        conditions.append(_definition(identifier, arguments, semantics, "wereld", delegates))
    conditions.append(_definition("any", [], "Evaluate nested conditions left-to-right; stop at first true. Zero operands returns false.", "wereld", variadic=_arg("condition", "condition")))
    conditions.append(_definition("boog_missing", [], "Return true at first absent flag, left-to-right; zero flags returns false.", "boog", variadic=flag()))
    for identifier, semantics in [
        ("arena_open", "arena.is_open()."), ("arena_registered", "arena.registered_rank() != empty string."),
        ("arena_fight", "arena.is_run_active()."), ("arena_free", "not arena.is_run_active()."),
    ]:
        helper = {"arena_open": "is_open", "arena_registered": "registered_rank", "arena_fight": "is_run_active", "arena_free": "is_run_active"}[identifier]
        conditions.append(_definition(identifier, [], semantics, "arena", [("scripts/data/arena.gd", helper)]))
    for identifier, arguments, semantics, helper in [
        ("meer_vis", [], "True when sellable_fish() is nonempty.", "sellable_fish"),
        ("meer_vol", [], "sold_count() >= Vis.FULL_PRICE_FISH.", "sold_count"),
        ("meer_boeken", [threshold()], "books_found() >= int(threshold).", "books_found"),
        ("meer_gelezen", [threshold()], "read_count() >= int(threshold).", "read_count"),
    ]:
        conditions.append(_definition(identifier, arguments, semantics, "meer", [(EXT + "meer_logic.gd", "check"), (EXT + "meer_logic.gd", helper)]))
    conditions.append(_definition("echo_ready", [], "Current weapon is one of iron, crystal, star; does not test hero level.", "echo"))

    actions = [
        _definition("start_quest", [quest()], "start_quest: no-op if already present; otherwise active step 0, toast and quest refresh.", delegates=[(CORE, "start_quest")]),
        _definition("quest_step", [quest(), _arg("step", "integer")], "Set existing quest step, emit and refresh; absent quest is unchanged.", delegates=[(CORE, "set_quest_step")]),
        _definition("finish_quest", [quest()], "Finish an existing unfinished quest, emit toast, award hero XP and refresh; absent/already done is unchanged.", delegates=[(CORE, "finish_quest")]),
        _definition("set_flag", [flag()], "set_flag(flag, true), then achievement marking and quest refresh.", delegates=[(CORE, "set_flag")]),
        _definition("clear_flag", [flag()], "set_flag(flag, false) erases the key, then achievement marking and quest refresh.", delegates=[(CORE, "set_flag")]),
        _definition("give", [item(), amount()], "give(item, amount): respect item capacity, may grant only available room, emit item feedback and refresh quests. Not transactional.", delegates=[(CORE, "give")]),
        _definition("take", [item(), amount()], "Subtract inventory amount or erase depleted key, reconcile equipment/appearance, emit and refresh.", delegates=[(CORE, "take")]),
        _definition("coins", [_arg("delta", "integer")], "add_coins(delta) clamps resulting coin count to at least zero.", delegates=[(CORE, "add_coins")]),
        _definition("heal", [], "full_rest(), including its existing health/stamina/rest behavior; not a numeric heal argument.", delegates=[(CORE, "full_rest")]),
        _definition("weapon", [_arg("weapon", namespace="weapons")], "Set weapon, emit items_changed, then toast translated weapon name.", delegates=[(CORE, "set_weapon")]),
        _definition("toast", [_arg("text")], "Emit tr(text) on the shared toast signal; retain the original feedback routing."),
        _definition("sound", [_arg("sound", namespace="sounds")], "Sound.play(sound).", delegates=[("scripts/core/sound.gd", "play")]),
        _definition("shop", [_arg("shop", namespace="shops")], "Emit shop_requested(shop)."),
        _definition("save", [], "Emit save_requested; actual save handling belongs to the connected world."),
        _definition("ending", [], "Emit ending_requested; world handles completion/save/scene transition.", delegates=[("scripts/world.gd", "_on_ending")]),
        _definition("sell_all", [item()], "If inventory count >0: add count*int(item sell price default1), take all, emit translated sale toast. Preserve this operation order."),
        _definition("talk", [_arg("dialogue", namespace="talks")], "start_dialogue(dialogue) emits dialogue_requested.", delegates=[(CORE, "start_dialogue")]),
        _definition("boss_start", [], "Emit world_action; world plays boss sound/music and activates king bosses.", delegates=[("scripts/world.gd", "_on_world_action")]),
        _definition("music", [_arg("track", namespace="music_tracks")], "Emit world_action; world calls Sound.play_music(track).", delegates=[("scripts/world.gd", "_on_world_action")]),
        _definition("lock_arena", [], "Legacy dispatch emits world_action, but the preserved world handler has no lock_arena branch. No current consumer is claimed.", delegates=[("scripts/world.gd", "_on_world_action")]),
    ]
    additions = [
        ("arena_enter", [_arg("rank", namespace="arena_ranks")], "arena.register(rank): checks known/unlocked rank, existing registration, active run and coins before charging fee/setting registration flag.", "arena", [("scripts/data/arena.gd", "register")]),
        ("arena_cancel", [], "arena.cancel(): cancel eligible registration and refund its fee; retain helper guards.", "arena", [("scripts/data/arena.gd", "cancel")]),
        ("arena_forfeit", [], "Find first arena_master group node; call forfeit only if it exists.", "arena", []),
        ("boog_range_start", [], "Start first boog_range group node if present; otherwise no-op.", "boog", []),
        ("meer_verkoop", [], "Delegate to meer_logic.run then sell_fish; preserve inventory, sales counter and price logic in source.", "meer", [(EXT + "meer_logic.gd", "run"), (EXT + "meer_logic.gd", "sell_fish")]),
        ("wereld_sleep", [], "Get first world group node; invoke atmosphere.sleep_in_bed only if world exists (its cost/time/guards are not in this dispatcher).", "wereld", []),
        ("ce_sail", [], "Iterate coast_voyage nodes in group order; queue begin on every node not queued for deletion. Deferred, not synchronous.", "coast", []),
        ("rg_routes", [], "Forward action ID to coastal_region.choose; valid pending resident queues open_service(action).", "coastal_region", [("scripts/core/coastal_region.gd", "choose")]),
        ("rg_atlas", [], "Forward action ID to coastal_region.choose; valid pending resident queues open_service(action).", "coastal_region", [("scripts/core/coastal_region.gd", "choose")]),
        ("wt_open", [_arg("workshopKind")], "First non-deleting matching workshop kind queues open(kind), then returns; no matching workshop is a no-op.", "work_together", []),
        ("regional", [_arg("choice")], "Forward full array to regional_adventures.action: valid non-deleting pending node inside tree and within 64 pixels chooses str(choice); otherwise no-op.", "regional", [("scripts/core/regional_adventures.gd", "action")]),
        ("ls_weave", [_arg("direction", values=["over", "under"])], "lake_supper.action: valid pending node inside tree within 66 pixels, kind net, calls weave(str(direction)); retain node algorithm in source.", "lake_supper", [("scripts/core/lake_supper.gd", "action")]),
        ("ls_share", [_arg("dish", namespace="items")], "lake_supper.action: valid pending node inside tree within 66 pixels, kind table, calls share(str(dish)); retain node algorithm in source.", "lake_supper", [("scripts/core/lake_supper.gd", "action")]),
        ("rf_choose", [_arg("choice", values=["guard", "guide"])], "first_route.choose(str(choice)): only guard/guide, valid pending node inside tree and within 64 pixels may remember(choice).", "first_route", [("scripts/core/first_route.gd", "choose")]),
        ("living", [_arg("choice")], "living_world.run(choice): valid pending node inside tree within 72 pixels calls node.choose(choice); otherwise no-op.", "living", [("scripts/core/living_world.gd", "run")]),
    ]
    actions.extend(_definition(*entry) for entry in additions)
    actions.append(_definition("boog_progress", [], "Count true supplied flags left-to-right; toast all-hit if done>=number supplied, otherwise progress. Zero flags gives all-hit toast.", "boog", variadic=flag()))
    return {"conditions": conditions, "actions": actions}


def _source_anchor(root, relative, function):
    text = (root / relative).read_text(encoding="utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
    lines = text.splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines)
                  if re.match(r"^(?:static )?func " + re.escape(function) + r"\(", line)), None)
    if start is None:
        raise RuleContractError(f"Missing preserved handler {relative}:{function}")
    end = start + 1
    while end < len(lines):
        line = lines[end]
        if line.strip() and not line[0].isspace() and not line.startswith("#"):
            break
        end += 1
    body = "".join(lines[start:end]).rstrip() + "\n"
    return {"path": "res://" + relative, "function": function, "line": start + 1,
            "endLine": start + len(body.splitlines()),
            "sourceSha256LF": hashlib.sha256(text.encode("utf-8")).hexdigest(),
            "bodySha256LF": hashlib.sha256(body.encode("utf-8")).hexdigest(),
            "authority": "Preserved GDScript body; opaque to this contract builder"}


def _namespaces(content, maps):
    result = {name: {entry["id"] for entry in catalog["entries"]}
              for name, catalog in content["catalogs"].items()}
    result["maps"] = {value["id"] for value in maps["maps"]}
    ranks = [declaration for declaration in content.get("declarations", [])
             if declaration.get("source", {}).get("path") == "res://scripts/data/arena.gd"
             and declaration.get("source", {}).get("constant") == "RANKS"]
    result["arena_ranks"] = set(ranks[0]["value"]) if ranks else set()
    return result


def scan_rule_usages(content, maps, definitions=None):
    """Validate recursive authored invocations; return uses + explicit diagnostics.

    This validates the portable authoring contract, which rejects malformed data
    rather than reproducing Godot index errors or silently dropping extra args.
    Every diagnostic records the separate original dispatch behavior.
    """
    definitions = definitions or _definitions()
    rules = {kind: {rule["id"]: rule for rule in values} for kind, values in definitions.items()}
    namespaces = _namespaces(content, maps)
    uses, diagnostics, empty_lists = [], [], []

    def diagnostic(code, location, message, value, legacy, severity="error"):
        diagnostics.append({"severity": severity, "code": code, "location": location,
                            "message": message, "observed": value, "legacyBehavior": legacy})

    def invocation(value, kind, location):
        if not isinstance(value, list) or not value or not isinstance(value[0], str):
            diagnostic("malformed_invocation", location, "Expected nonempty operation array beginning with a string ID.", value,
                       "check([])/run([]) do not have a fallback: indexing/type errors are not equivalent to an empty condition list.")
            return
        identifier = value[0]
        uses.append({"kind": kind, "id": identifier, "location": location, "invocation": value})
        rule = rules[kind].get(identifier)
        if rule is None:
            legacy = "Warn and return false after base and extension lookup." if kind == "conditions" else "Warn and perform no action after base and extension lookup."
            diagnostic("unknown_operation", location, f"Unknown {kind} ID {identifier!r}.", value, legacy)
            return
        args, supplied = rule["arguments"], value[1:]
        minimum = sum(not argument["optional"] for argument in args)
        if len(supplied) < minimum or (not rule["variadic"] and len(supplied) > len(args)):
            diagnostic("incorrect_arity", location, "Operation argument count violates its documented signature.", value,
                       "Missing indexed arguments can fail at runtime; fixed handlers ignore unused trailing arguments. No reinterpretation is applied.")
        for index, item in enumerate(supplied):
            argument = args[index] if index < len(args) else rule["variadic"]
            if argument is None:
                continue
            arg_location = location + f"/{index + 1}"
            kind_name = argument["type"]
            valid = ((kind_name == "string" and isinstance(item, str)) or
                     (kind_name == "integer" and type(item) is int) or
                     (kind_name == "number" and type(item) in {int, float}) or
                     (kind_name == "string_array" and isinstance(item, list) and all(isinstance(v, str) for v in item)) or
                     (kind_name == "condition" and isinstance(item, list)))
            if not valid:
                diagnostic("incorrect_type", arg_location, f"Expected {kind_name} for {argument['name']}.", item,
                           "The preserved handler's indexed access/casts remain authoritative; this validator does not coerce JSON.")
                continue
            if kind_name == "condition":
                invocation(item, "conditions", arg_location)
                continue
            namespace = argument.get("namespace")
            if namespace and namespace != "open_flags":
                for link in item if kind_name == "string_array" else [item]:
                    if link not in namespaces.get(namespace, set()):
                        diagnostic("unknown_reference", arg_location, f"Unknown {namespace} ID {link!r}.", link,
                                   "Source helper behavior varies (false, no-op or lookup error); no replacement ID is inferred.")
            if "allowedValues" in argument and item not in argument["allowedValues"]:
                diagnostic("unknown_argument_value", arg_location, "Value is outside the documented token vocabulary.", item,
                           "Preserve source equality/guard behavior; do not substitute a translated or guessed token.")

    def walk(value, location):
        if isinstance(value, dict):
            for key in sorted(value):
                child = value[key]
                path = location + "/" + str(key).replace("~", "~0").replace("/", "~1")
                kind = "conditions" if key in CONDITION_FIELDS else "actions" if key in ACTION_FIELDS else None
                if kind:
                    if not isinstance(child, list):
                        diagnostic("malformed_operation_list", path, "Expected an ordered array of operation arrays.", child,
                                   "The GDScript consumer expects Array; no implicit wrapping is performed.")
                    else:
                        if not child:
                            empty_lists.append({"kind": kind, "location": path})
                        for index, operation in enumerate(child):
                            invocation(operation, kind, path + "/" + str(index))
                else:
                    walk(child, path)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, location + "/" + str(index))

    for name, catalog in sorted(content["catalogs"].items()):
        for entry in catalog["entries"]:
            if "value" in entry:
                walk(entry["value"], f"catalogs/{name}/{entry['id']}/value")
    for index, declaration in enumerate(content.get("declarations", [])):
        walk(declaration.get("value"), f"declarations/{index}/value")
    for value in maps["maps"]:
        walk(value, f"maps/{value['id']}")
    return {"invocations": uses, "diagnostics": diagnostics, "emptyOperationLists": empty_lists,
            "scope": "All rule-bearing fields recursively in effective catalog values, declaration values and complete registry map views; duplicate source/effective views are counted separately. Arbitrary executable GDScript and runtime-spawned rules are not interpreted."}


def build_rule_contracts(root: Path, content: dict, maps: dict) -> dict:
    root = Path(root)
    definitions = _definitions()
    modules = {value["path"]: value["index"] for value in content["modules"]}
    result = {"schemaVersion": 1, "phase": 4,
              "scope": "Semantic contracts and authored-data validation only; no rule algorithms have been ported or executed in Unity.",
              "sourceHashMode": "UTF-8 source and function bodies normalized to LF, SHA256; line references are one-based.",
              "implementation": {"godot": "preserved source is authoritative", "unity": "not_implemented", "runtimeEquivalenceProven": False},
              "dispatch": {
                  "baseFirst": True, "extensionOrder": content["modules"],
                  "extensionSelection": "First Content.MODULES declaration containing ID wins; conditions return its result, actions call handler then report handled even when helper performs no action.",
                  "conditions": "check_all uses ordered logical AND and stops at first false; an empty list returns true. check itself requires a nonempty operation array.",
                  "actions": "run_all executes synchronously left-to-right with no rollback; signals may synchronously change state and some extension handlers queue deferred work. Later actions observe earlier mutations; no implicit transaction or await is introduced.",
                  "unknownCondition": "Warning then false after base/extension lookup.",
                  "unknownAction": "Warning then no-op after base/extension lookup.",
                  "fixedArityLegacy": "Fixed handlers generally ignore unreferenced trailing arguments; the portable authoring validator rejects them and never silently changes saved/source data.",
                  "source": [_source_anchor(root, CORE, function) for function in ("check", "check_all", "run", "run_all")]
                            + [_source_anchor(root, CONTENT, function) for function in ("check_condition", "run_action")],
              },
              "contexts": {
                  "dialogue": "Node do actions run after its last line, before choices/branches/next; branch is first passing condition in source order, with an absent if acting as fallback. Choice do runs before its next.",
                  "npc": "First passing rule in source order chooses dialogue; absent if is eligible. exists_if empty does not remove NPC.",
                  "portal": "Empty requires/conditions permits passage; portal arming/crossing remains separate from rule evaluation.",
                  "gate": "Empty block_if leaves the gate blocked (true); otherwise check_all decides blocked, so true means closed.",
                  "trigger": "Empty conditions permit trigger; once flag is set BEFORE its ordered actions.",
                  "achievement": "Empty achievement conditions are explicitly excluded by check_achievements despite check_all([]) returning true.",
                  "quest": "advance_if can advance multiple consecutive active steps in a while loop; it does not advance beyond the last step.",
              },
              "contextSources": [
                  _source_anchor(root, "scripts/ui/dialogue_box.gd", "_finish_node"),
                  _source_anchor(root, "scripts/ui/dialogue_box.gd", "_choose"),
                  _source_anchor(root, "scripts/entities/npc.gd", "interact"),
                  _source_anchor(root, "scripts/entities/portal.gd", "available"),
                  _source_anchor(root, "scripts/entities/gate.gd", "_refresh"),
                  _source_anchor(root, "scripts/entities/trigger.gd", "_process"),
                  _source_anchor(root, CORE, "check_achievements"),
                  _source_anchor(root, CORE, "_refresh_quests"),
              ],
              "conditions": [], "actions": []}
    for kind, values in definitions.items():
        catalog_ids = {entry["id"] for entry in content["catalogs"][kind]["entries"]}
        if catalog_ids != {value["id"] for value in values}:
            raise RuleContractError(f"{kind} registry IDs differ from explicit contracts")
        for value in sorted(values, key=lambda item: item["id"]):
            module = value["module"]
            handler_path = EXT + module + ".gd" if module else CORE
            function = "check" if kind == "conditions" else "run"
            if module and "res://" + handler_path not in modules:
                raise RuleContractError(f"Unregistered rule module {module}")
            result[kind].append({
                "id": value["id"], "arguments": value["arguments"], "variadic": value["variadic"],
                "arity": {"minimumArguments": sum(not a["optional"] for a in value["arguments"]),
                          "maximumArguments": None if value["variadic"] else len(value["arguments"])},
                "semantics": value["semantics"],
                "dispatch": {"tier": "extension" if module else "base", "moduleIndex": modules.get("res://" + handler_path)},
                "handlers": [_source_anchor(root, handler_path, function)]
                            + [_source_anchor(root, path, func) for path, func in value["delegates"]],
                "implementation": "documented_only; original handler preserved; Unity implementation pending",
            })
    result["usage"] = scan_rule_usages(content, maps, definitions)
    for kind in ("conditions", "actions"):
        for record in result[kind]:
            record["observedInvocations"] = sum(value["kind"] == kind and value["id"] == record["id"]
                                                for value in result["usage"]["invocations"])
    result["diagnostics"] = [{"severity": "warning", "code": "legacy_unhandled_world_action", "id": "lock_arena",
                              "message": "Declared base action is emitted but preserved world._on_world_action has no matching branch; retain this legacy no-op until a separately reviewed change.",
                              "evidence": _source_anchor(root, "scripts/world.gd", "_on_world_action")}]
    result["counts"] = {"conditions": len(result["conditions"]), "actions": len(result["actions"]),
                        "invocations": len(result["usage"]["invocations"]),
                        "usageErrors": sum(d["severity"] == "error" for d in result["usage"]["diagnostics"])}
    return result


def validate_rule_contracts(contract: dict) -> None:
    if contract.get("schemaVersion") != 1 or contract.get("phase") != 4:
        raise RuleContractError("Unsupported rule contract schema/phase")
    if contract.get("implementation", {}).get("unity") != "not_implemented" or contract.get("implementation", {}).get("runtimeEquivalenceProven") is not False:
        raise RuleContractError("This phase does not implement or prove Unity rule execution")
    expected = _definitions()
    for kind, count in (("conditions", 33), ("actions", 36)):
        records = contract.get(kind, [])
        if len(records) != count or {r.get("id") for r in records} != {r["id"] for r in expected[kind]}:
            raise RuleContractError(f"Incomplete or duplicate {kind} contracts")
        for record in records:
            definition = next(value for value in expected[kind] if value["id"] == record["id"])
            arity = {"minimumArguments": sum(not value["optional"] for value in definition["arguments"]),
                     "maximumArguments": None if definition["variadic"] else len(definition["arguments"])}
            if record.get("arguments") != definition["arguments"] or record.get("variadic") != definition["variadic"] or record.get("arity") != arity:
                raise RuleContractError("Changed rule arguments/defaults/arity without updating its semantic contract")
            if not record.get("handlers") or record.get("implementation") != "documented_only; original handler preserved; Unity implementation pending":
                raise RuleContractError("Missing source authority or false implementation claim")
            for anchor in record["handlers"]:
                if not re.fullmatch(r"[0-9a-f]{64}", anchor.get("bodySha256LF", "")):
                    raise RuleContractError("Invalid handler body hash")
    errors = [diagnostic for diagnostic in contract.get("usage", {}).get("diagnostics", []) if diagnostic.get("severity") == "error"]
    if errors:
        raise RuleContractError(f"Invalid authored rule usage: {errors[0]['code']} at {errors[0]['location']}: {errors[0]['message']}")
