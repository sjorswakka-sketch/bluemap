#!/usr/bin/env python3
"""Vertalingen van Bluemap Quest (gettext, PO-bestanden in translations/). Nederlands is de brontaal: msgid is de
Nederlandse tekst uit de code en de data, msgstr de vertaling. Zie de README, sectie "Talen".

  python3 tools/i18n.py extract [--godot PAD] [--lang en]
      Zoekt alle tekst (Godot draait tools/i18n_extract.gd) en werkt translations/en.po bij: nieuwe teksten erbij
      met een lege vertaling, bestaande vertalingen blijven staan, verdwenen teksten gaan eruit.
  python3 tools/i18n.py check [PO ...] [--allow-missing] [--all]
      Meldt ontbrekende vertalingen en plaatsaanduidingen die niet kloppen ({teken}, %s, %d, %.1f...).
      Eindigt met code 1 als er iets mis is (met --allow-missing tellen alleen fouten in plaatsaanduidingen).
  python3 tools/i18n.py split --parts N --out MAP [--lang en] [--untranslated]
      Verdeelt het PO-bestand in N ongeveer even grote delen (op aantal woorden), elk een geldig PO-bestand.
  python3 tools/i18n.py merge MAP [--lang en]
      Zet de vertalingen uit de (ingevulde) delen in MAP terug in het PO-bestand.
  python3 tools/i18n.py stats [--lang en]
      Hoeveel teksten en woorden er zijn, en hoeveel er al vertaald zijn.

De Godot-binary: --godot PAD, of de omgevingsvariabele GODOT, anders "godot".
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRANSLATIONS = os.path.join(ROOT, "translations")
EXTRACT_SCRIPT = "tools/i18n_extract.gd"

# Plaatsaanduidingen. GDScript vult "%s" % [...] op volgorde in, dus die moeten in dezelfde volgorde blijven;
# {tekens} worden op naam ingevuld (GameState.fmt), de volgorde maakt daar niet uit.
PRINTF = re.compile(r"%(?:%|[-+0*]*\d*(?:\.(?:\d+|\*))?[scdoxXfv])")
TOKEN = re.compile(r"\{[A-Za-z_][A-Za-z0-9_]*\}")
WORD = re.compile(r"[^\W\d_]+(?:['’-][^\W\d_]+)*", re.UNICODE)


def default_header(lang):
    return (
        "Project-Id-Version: Bluemap Quest\n"
        f"Language: {lang}\n"
        "MIME-Version: 1.0\n"
        "Content-Type: text/plain; charset=UTF-8\n"
        "Content-Transfer-Encoding: 8bit\n"
        "Plural-Forms: nplurals=2; plural=(n != 1);\n"
        "X-Source-Language: nl\n"
    )


# --- PO lezen en schrijven ---------------------------------------------------------------------------------------

class Entry:
    def __init__(self):
        self.translator = []  # "# ..." (eigen aantekeningen van vertalers, blijven bewaard)
        self.extracted = []  # "#. ..." (uitleg uit de extractie)
        self.refs = []  # "#: ..."
        self.flags = []  # "#, fuzzy"
        self.ctx = ""
        self.msgid = ""
        self.plural = ""
        self.msgstr = ""
        self.msgstr_plural = []  # bij een meervoud: msgstr[0], msgstr[1], ...

    @property
    def key(self):
        return (self.ctx, self.msgid)

    def is_plural(self):
        return self.plural != ""

    def forms(self):
        return self.msgstr_plural if self.is_plural() else [self.msgstr]

    def translated(self):
        return "fuzzy" not in self.flags and all(form != "" for form in self.forms())

    def words(self):
        return len(WORD.findall(self.msgid + " " + self.plural))


class PoFile:
    def __init__(self, header="", entries=None):
        self.header = header
        self.entries = entries or []

    def by_key(self):
        return {entry.key: entry for entry in self.entries}

    def nplurals(self):
        match = re.search(r"nplurals\s*=\s*(\d+)", self.header)
        return int(match.group(1)) if match else 2


def unescape(text):
    out = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == "\\" and i + 1 < len(text):
            nxt = text[i + 1]
            out.append({"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"'}.get(nxt, "\\" + nxt))
            i += 2
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def escape(text):
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")


def read_po(path):
    po = PoFile()
    entry = Entry()
    field = None  # ("msgid" | "msgid_plural" | "msgctxt" | "msgstr" | ("msgstr", n))
    has_content = False

    def finish():
        nonlocal entry, field, has_content
        if has_content:
            if entry.msgid == "" and entry.ctx == "":
                po.header = entry.msgstr
            else:
                po.entries.append(entry)
        entry = Entry()
        field = None
        has_content = False

    def append(value):
        if field == "msgid":
            entry.msgid += value
        elif field == "msgid_plural":
            entry.plural += value
        elif field == "msgctxt":
            entry.ctx += value
        elif field == "msgstr":
            entry.msgstr += value
        elif isinstance(field, tuple):
            entry.msgstr_plural[field[1]] += value

    with open(path, encoding="utf-8") as handle:
        for number, raw in enumerate(handle, 1):
            line = raw.rstrip("\n").rstrip("\r")
            stripped = line.strip()
            if stripped == "":
                finish()
                continue
            if stripped.startswith("#"):
                if has_content and field is not None and field != "msgctxt":
                    finish()  # commentaar hoort bij de volgende tekst
                if stripped.startswith("#~"):
                    continue  # vervallen teksten slaan we over
                if stripped.startswith("#."):
                    entry.extracted.append(stripped[2:].strip())
                elif stripped.startswith("#:"):
                    entry.refs.extend(stripped[2:].split())
                elif stripped.startswith("#,"):
                    entry.flags.extend(flag.strip() for flag in stripped[2:].split(",") if flag.strip())
                elif stripped.startswith("#|"):
                    pass
                else:
                    entry.translator.append(stripped[1:].strip())
                continue
            match = re.match(r'^(msgctxt|msgid_plural|msgid|msgstr(?:\[(\d+)\])?)\s+"(.*)"\s*$', stripped)
            if match:
                keyword, index, value = match.group(1), match.group(2), unescape(match.group(3))
                if keyword in ("msgctxt", "msgid") and field is not None and field not in ("msgctxt",):
                    finish()
                has_content = True
                if keyword.startswith("msgstr["):
                    n = int(index)
                    while len(entry.msgstr_plural) <= n:
                        entry.msgstr_plural.append("")
                    field = ("msgstr", n)
                else:
                    field = keyword
                append(value)
                continue
            match = re.match(r'^"(.*)"\s*$', stripped)
            if match and field is not None:
                append(unescape(match.group(1)))
                continue
            raise SystemExit(f"{path}:{number}: kan deze regel niet lezen: {line}")
    finish()
    return po


def write_po(path, po):
    lines = ['msgid ""', 'msgstr ""']
    for header_line in po.header.splitlines(keepends=True):
        lines.append('"%s"' % escape(header_line))
    for entry in po.entries:
        lines.append("")
        lines.extend("# " + note if note else "#" for note in entry.translator)
        lines.extend("#. " + note for note in entry.extracted)
        if entry.refs:
            lines.append("#: " + " ".join(entry.refs))
        if entry.flags:
            lines.append("#, " + ", ".join(entry.flags))
        if entry.ctx:
            lines.append('msgctxt "%s"' % escape(entry.ctx))
        lines.append('msgid "%s"' % escape(entry.msgid))
        if entry.is_plural():
            lines.append('msgid_plural "%s"' % escape(entry.plural))
            for i, form in enumerate(entry.msgstr_plural):
                lines.append('msgstr[%d] "%s"' % (i, escape(form)))
        else:
            lines.append('msgstr "%s"' % escape(entry.msgstr))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")


def po_path(lang):
    return os.path.join(TRANSLATIONS, f"{lang}.po")


def load_or_new(lang):
    path = po_path(lang)
    if os.path.exists(path):
        return read_po(path)
    return PoFile(default_header(lang))


# --- Plaatsaanduidingen -------------------------------------------------------------------------------------------

def placeholders(text):
    printf = [p for p in PRINTF.findall(text) if p != "%%"]
    percent = text.count("%%")
    tokens = sorted(TOKEN.findall(text))
    return printf, percent, tokens


def placeholder_problem(source, translation):
    """Waarom de plaatsaanduidingen van de vertaling niet kloppen, of None."""
    s_printf, s_percent, s_tokens = placeholders(source)
    t_printf, t_percent, t_tokens = placeholders(translation)
    if s_printf != t_printf:
        return "%%-tekens: %s in de brontekst, %s in de vertaling (zelfde volgorde nodig)" % (
            " ".join(s_printf) or "geen", " ".join(t_printf) or "geen")
    if s_percent != t_percent:
        return "%%%% (een procentteken in een sjabloon): %d in de brontekst, %d in de vertaling" % (s_percent, t_percent)
    if s_tokens != t_tokens:
        return "{tekens}: %s in de brontekst, %s in de vertaling" % (
            " ".join(s_tokens) or "geen", " ".join(t_tokens) or "geen")
    return None


def entry_problems(entry, nplurals):
    """Fouten in een vertaalde tekst (lege vertalingen tellen hier niet; die meldt check apart)."""
    problems = []
    if entry.is_plural():
        source_problem = placeholder_problem(entry.msgid, entry.plural)
        if source_problem:
            problems.append("enkelvoud en meervoud van de brontekst verschillen: " + source_problem)
        if len(entry.msgstr_plural) != nplurals:
            problems.append("%d meervoudsvormen, de kop van het bestand zegt %d" % (len(entry.msgstr_plural), nplurals))
        for i, form in enumerate(entry.msgstr_plural):
            if form:
                problem = placeholder_problem(entry.plural if i > 0 else entry.msgid, form)
                if problem:
                    problems.append("msgstr[%d]: %s" % (i, problem))
    elif entry.msgstr:
        problem = placeholder_problem(entry.msgid, entry.msgstr)
        if problem:
            problems.append(problem)
    return problems


def shown(path):
    """Een pad om te tonen: relatief als dat korter is, anders volledig."""
    rel = os.path.relpath(path, os.getcwd())
    return path if rel.startswith("..") else rel


def describe(entry):
    ctx = "[%s] " % entry.ctx if entry.ctx else ""
    text = entry.msgid if len(entry.msgid) <= 90 else entry.msgid[:87] + "..."
    where = (" (%s)" % entry.refs[0]) if entry.refs else ""
    return '%s"%s"%s' % (ctx, text.replace("\n", "\\n"), where)


# --- Subcommando's ----------------------------------------------------------------------------------------------

def godot_binary(args):
    return args.godot or os.environ.get("GODOT") or "godot"


def run_extract_script(godot):
    """Draait tools/i18n_extract.gd en geeft de gevonden teksten terug."""
    try:
        subprocess.run([godot, "--headless", "--path", ROOT, "--import"], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, check=False)
    except OSError as error:
        raise SystemExit("Kan Godot niet starten (%s): %s. Geef het pad mee met --godot of zet GODOT." % (godot, error))
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "teksten.json")
        result = subprocess.run([godot, "--headless", "--path", ROOT, "-s", EXTRACT_SCRIPT, "--", "--out=" + out],
                                capture_output=True, text=True, timeout=600)
        if not os.path.exists(out):
            sys.stderr.write(result.stdout + result.stderr)
            raise SystemExit("De extractie in Godot is mislukt (zie hierboven).")
        with open(out, encoding="utf-8") as handle:
            data = json.load(handle)
    for line in (result.stdout + result.stderr).splitlines():
        if "SCRIPT ERROR" in line or "Parse Error" in line:
            sys.stderr.write(result.stdout + result.stderr)
            raise SystemExit("Scriptfout tijdens de extractie (zie hierboven).")
    return data


def cmd_extract(args):
    data = run_extract_script(godot_binary(args))
    for error in data["errors"]:
        print("FOUT: " + error)
    for text in data["unclaimed"]:
        print("LET OP: tekst in de data die de extractie niet kent (zie tools/i18n_extract.gd): " + text)
    if data["errors"]:
        raise SystemExit(1)
    po = load_or_new(args.lang)
    old = po.by_key()
    entries = []
    added = kept = 0
    for found in data["entries"]:
        entry = Entry()
        entry.ctx = found["ctx"]
        entry.msgid = found["msgid"]
        entry.plural = found["plural"]
        entry.extracted = [comment.replace("\n", " ") for comment in found["comments"]]
        entry.refs = list(found["refs"])
        previous = old.get(entry.key)
        if entry.is_plural():
            entry.msgstr_plural = [""] * po.nplurals()
        if previous is None:
            added += 1
        else:
            kept += 1
            entry.translator = previous.translator
            entry.flags = [flag for flag in previous.flags if flag != "fuzzy"]
            if entry.is_plural() and previous.is_plural():
                forms = previous.msgstr_plural + [""] * po.nplurals()
                entry.msgstr_plural = forms[:po.nplurals()]
                if previous.plural != entry.plural and any(entry.msgstr_plural):
                    entry.flags.append("fuzzy")  # het meervoud is veranderd: even nakijken
            elif not entry.is_plural() and not previous.is_plural():
                entry.msgstr = previous.msgstr
            else:
                # Van gewoon naar meervoud of andersom: de oude vertaling als startpunt, ter controle.
                old_text = previous.msgstr if not previous.is_plural() else (previous.msgstr_plural or [""])[0]
                if entry.is_plural():
                    entry.msgstr_plural[0] = old_text
                else:
                    entry.msgstr = old_text
                if old_text:
                    entry.flags.append("fuzzy")
        entries.append(entry)
    removed = len([key for key in old if key not in {entry.key for entry in entries}])
    po.entries = entries
    write_po(po_path(args.lang), po)
    translated = sum(1 for entry in entries if entry.translated())
    words = sum(entry.words() for entry in entries)
    print("%s: %d teksten (%d woorden): %d nieuw, %d bewaard, %d verdwenen. Vertaald: %d, nog te doen: %d." % (
        os.path.relpath(po_path(args.lang), ROOT), len(entries), words, added, kept, removed, translated,
        len(entries) - translated))


def check_file(path, allow_missing, show_all):
    po = read_po(path)
    nplurals = po.nplurals()
    missing = [entry for entry in po.entries if not entry.translated()]
    broken = []
    for entry in po.entries:
        for problem in entry_problems(entry, nplurals):
            broken.append((entry, problem))
    rel = shown(path)
    if "Plural-Forms" not in po.header:
        broken.append((None, "de kop van het bestand mist Plural-Forms"))
    print("%s: %d teksten, %d vertaald, %d ontbreken, %d fouten in plaatsaanduidingen" % (
        rel, len(po.entries), len(po.entries) - len(missing), len(missing), len(broken)))
    limit = None if show_all else 20
    for entry, problem in broken[:limit]:
        print("  FOUT  %s: %s" % (describe(entry) if entry else rel, problem))
    if limit is not None and len(broken) > limit:
        print("  ... en nog %d fouten (--all toont alles)" % (len(broken) - limit))
    if not allow_missing:
        for entry in missing[:limit]:
            print("  MIST  %s%s" % (describe(entry), "  (fuzzy: nakijken)" if "fuzzy" in entry.flags else ""))
        if limit is not None and len(missing) > limit:
            print("  ... en nog %d ontbrekende (--all toont alles)" % (len(missing) - limit))
    return len(broken) == 0 and (allow_missing or not missing)


def cmd_check(args):
    paths = args.po or sorted(glob.glob(os.path.join(TRANSLATIONS, "*.po")))
    if not paths:
        raise SystemExit("Geen PO-bestanden gevonden in translations/.")
    ok = True
    for path in paths:
        ok = check_file(path, args.allow_missing, args.all) and ok
    print("CHECK OK" if ok else "CHECK MISLUKT")
    raise SystemExit(0 if ok else 1)


def group_of(entry):
    """Teksten die bij elkaar horen (hetzelfde gesprek, hetzelfde script) houden we liefst in hetzelfde deel."""
    if entry.extracted:
        first = entry.extracted[0]
        match = re.match(r"(Gesprek \S+|Boek \S+|Opdracht \S+|Kaart \S+)", first)
        if match:
            return match.group(1).rstrip(",:")
        return first.split(" ")[0]
    return entry.refs[0].split(":")[0] if entry.refs else ""


def cmd_split(args):
    po = read_po(po_path(args.lang))
    entries = [entry for entry in po.entries if not args.untranslated or not entry.translated()]
    if args.parts < 1:
        raise SystemExit("--parts moet minstens 1 zijn.")
    if not entries:
        raise SystemExit("Er is niets om te verdelen.")
    parts = min(args.parts, len(entries))
    words = [max(entry.words(), 1) for entry in entries]
    total = sum(words)
    # Grenzen op ongeveer total * k / parts woorden; mag een paar teksten opschuiven naar het begin van een nieuw
    # gesprek of onderwerp, zolang de delen ongeveer even groot blijven.
    cumulative = [0]
    for count in words:
        cumulative.append(cumulative[-1] + count)
    cuts = [0]
    for k in range(1, parts):
        target = total * k / parts
        best = min(range(cuts[-1] + 1, len(entries) - (parts - k) + 1), key=lambda i: abs(cumulative[i] - target))
        window = max(int(total / parts * 0.04), 1)  # 4% van een deel in woorden
        candidates = [i for i in range(max(cuts[-1] + 1, best - 12), min(len(entries) - (parts - k), best + 12) + 1)
                      if abs(cumulative[i] - target) <= window and group_of(entries[i - 1]) != group_of(entries[i])]
        if candidates:
            best = min(candidates, key=lambda i: abs(cumulative[i] - target))
        cuts.append(best)
    cuts.append(len(entries))
    os.makedirs(args.out, exist_ok=True)
    for old in glob.glob(os.path.join(args.out, "%s_deel*.po" % args.lang)):
        os.remove(old)
    width = max(2, len(str(parts)))
    for k in range(parts):
        chunk = entries[cuts[k]:cuts[k + 1]]
        name = os.path.join(args.out, "%s_deel%0*d.po" % (args.lang, width, k + 1))
        write_po(name, PoFile(po.header, chunk))
        print("%s: %d teksten, %d woorden" % (shown(name), len(chunk), sum(e.words() for e in chunk)))
    print("SPLIT OK: %d delen, samen %d teksten en %d woorden" % (parts, len(entries), sum(e.words() for e in entries)))


def cmd_merge(args):
    target_path = po_path(args.lang)
    po = read_po(target_path)
    index = po.by_key()
    files = sorted(glob.glob(os.path.join(args.dir, "*.po")))
    if not files:
        raise SystemExit("Geen PO-bestanden in %s." % args.dir)
    merged = unchanged = 0
    seen = {}
    warnings = []
    for path in files:
        part = read_po(path)
        for entry in part.entries:
            target = index.get(entry.key)
            rel = shown(path)
            if target is None:
                warnings.append("%s: %s staat niet (meer) in %s" % (rel, describe(entry), os.path.basename(target_path)))
                continue
            if target.plural != entry.plural:
                warnings.append("%s: %s heeft een ander meervoud dan in %s" % (rel, describe(entry), os.path.basename(target_path)))
                continue
            if not any(entry.forms()):
                continue  # nog niet vertaald in dit deel
            forms = entry.forms()
            if entry.key in seen and seen[entry.key][1] != forms:
                warnings.append("%s: %s is ook (anders) vertaald in %s; deze vertaling wint" % (rel, describe(entry), seen[entry.key][0]))
            seen[entry.key] = (rel, forms)
            if target.forms() == forms and "fuzzy" not in target.flags:
                unchanged += 1
                continue
            if target.is_plural():
                target.msgstr_plural = (list(forms) + [""] * po.nplurals())[:po.nplurals()]
            else:
                target.msgstr = forms[0]
            target.flags = [flag for flag in target.flags if flag != "fuzzy"]
            if "fuzzy" in entry.flags:
                target.flags.append("fuzzy")
            for note in entry.translator:
                if note not in target.translator:
                    target.translator.append(note)
            merged += 1
    write_po(target_path, po)
    for warning in warnings:
        print("LET OP: " + warning)
    missing = sum(1 for entry in po.entries if not entry.translated())
    print("MERGE OK: %d vertalingen bijgewerkt, %d waren al zo, %d teksten nog zonder vertaling in %s" % (
        merged, unchanged, missing, shown(target_path)))
    broken = [(entry, problem) for entry in po.entries for problem in entry_problems(entry, po.nplurals())]
    for entry, problem in broken[:20]:
        print("  FOUT  %s: %s" % (describe(entry), problem))
    if broken:
        print("Er zijn %d fouten in plaatsaanduidingen: draai tools/i18n.py check voor de hele lijst." % len(broken))
        raise SystemExit(1)


def cmd_stats(args):
    po = read_po(po_path(args.lang))
    total = len(po.entries)
    done = [entry for entry in po.entries if entry.translated()]
    words = sum(entry.words() for entry in po.entries)
    done_words = sum(entry.words() for entry in done)
    print("%s: %d teksten, %d woorden; vertaald %d teksten (%d woorden)" % (
        os.path.relpath(po_path(args.lang), ROOT), total, words, len(done), done_words))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Vertalingen van Bluemap Quest (zie de docstring bovenin).")
    sub = parser.add_subparsers(dest="command", required=True)

    extract = sub.add_parser("extract", help="teksten zoeken en translations/<taal>.po bijwerken")
    extract.add_argument("--godot", help="pad naar Godot (anders $GODOT of 'godot')")
    extract.add_argument("--lang", default="en", help="taalcode van het PO-bestand (standaard en)")
    extract.set_defaults(func=cmd_extract)

    check = sub.add_parser("check", help="ontbrekende vertalingen en foute plaatsaanduidingen melden")
    check.add_argument("po", nargs="*", help="PO-bestanden (standaard alle in translations/)")
    check.add_argument("--allow-missing", action="store_true", help="ontbrekende vertalingen zijn (nog) geen fout")
    check.add_argument("--all", action="store_true", help="alles tonen, niet alleen de eerste 20")
    check.set_defaults(func=cmd_check)

    split = sub.add_parser("split", help="het PO-bestand in N delen verdelen (op aantal woorden)")
    split.add_argument("--parts", type=int, required=True, help="aantal delen")
    split.add_argument("--out", required=True, help="map voor de delen")
    split.add_argument("--lang", default="en")
    split.add_argument("--untranslated", action="store_true", help="alleen teksten die nog geen vertaling hebben")
    split.set_defaults(func=cmd_split)

    merge = sub.add_parser("merge", help="de vertaalde delen terugzetten in het PO-bestand")
    merge.add_argument("dir", help="map met de delen (*.po)")
    merge.add_argument("--lang", default="en")
    merge.set_defaults(func=cmd_merge)

    stats = sub.add_parser("stats", help="aantallen teksten en woorden")
    stats.add_argument("--lang", default="en")
    stats.set_defaults(func=cmd_stats)

    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
