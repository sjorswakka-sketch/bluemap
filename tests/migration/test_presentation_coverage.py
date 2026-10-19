"""Exhaustive source/asset coverage; no original generator or engine is run."""
import ast
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CONTRACTS = {"texture_resolution", "character_layers", "runtime_textures", "procedural_draw", "audio", "translation", "font"}
ROLES = {"visual": r"\bdraw_\w+\s*\(|\b(?:ImageTexture|GradientTexture2D|AtlasTexture|SpriteFrames|AnimationPlayer)\b|\bqueue_redraw\s*\(",
         "audio": r"\b(?:AudioStream\w*|AudioServer)\b|\bSound\.",
         "text": r"\btr(?:_n)?\s*\(|\bTranslationServer\.|\bThemeDB\.fallback_font|add_theme_font"}


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def text(path):
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")


def check_coverage(coverage):
    original = load(ROOT / "migration/reference/source-manifest.json")
    content = load(ROOT / "migration/reference/content-inventory.json")
    if coverage.get("schema") != "bluemap.presentation.source-coverage.v1" or coverage.get("phase") != 6:
        raise ValueError("Unsupported presentation coverage schema")
    if (coverage.get("baselineCommit"), coverage.get("baselineTree")) != (original["commit"], original["tree"]):
        raise ValueError("Presentation source authority changed")
    assets = coverage["assets"]
    if len(assets) != len(original["asset_paths"]) or {r["path"] for r in assets} != set(original["asset_paths"]):
        raise ValueError("Original art/audio/icon/review asset is missing")
    source = {r["path"]: r for r in original["files"]}
    for row in assets:
        if row["sha256"] != source[row["path"]]["sha256"]:
            raise ValueError("Asset differs from original frozen authority")
    expected_generators = {p for p in original["python_tool_paths"] if Path(p).name.startswith(("art", "audio_", "make_art", "make_audio"))}
    generators = coverage["generators"]
    if len(generators) != len(expected_generators) or {r["path"] for r in generators} != expected_generators:
        raise ValueError("Original art/audio generator is missing")
    for row in generators:
        body = text(ROOT / row["path"])
        tree = ast.parse(body)
        imports = sorted({n.module or "" for n in ast.walk(tree) if isinstance(n, ast.ImportFrom)} |
                         {v.name for n in ast.walk(tree) if isinstance(n, ast.Import) for v in n.names})
        if (row["sourceSha256LF"] != hashlib.sha256(body.encode()).hexdigest() or
                row["originalBlobSha256"] != source[row["path"]]["sha256"] or row["imports"] != imports or
                row["executedForThisAudit"] is not False):
            raise ValueError("Generator source/import authority or execution claim differs")
    authority = {r["path"]: r["sha256"] for r in content["source_files"]}
    dependencies = coverage["allOriginalScriptDependencies"]
    if len(dependencies) != len(authority) or {r["path"] for r in dependencies} != set(authority):
        raise ValueError("An original script dependency source is missing")
    expected_sources = {}
    for row in dependencies:
        body = text(ROOT / row["path"][6:])
        deps = sorted(set(re.findall(r'(?:preload|load)\("(res://[^\"]+)"\)', body)))
        if row["sourceSha256LF"] != authority[row["path"]] or row["literalDependencies"] != deps:
            raise ValueError("Original delegated presentation dependency differs")
        roles = [role for role, pattern in ROLES.items() if re.search(pattern, body)]
        if roles:
            expected_sources[row["path"]] = (body, roles)
    rows = coverage["presentationSources"]
    if len(rows) != len(expected_sources) or {r["path"] for r in rows} != set(expected_sources):
        raise ValueError("An original direct presentation source is missing")
    for row in rows:
        body, roles = expected_sources[row["path"]]
        if row["sourceSha256LF"] != authority[row["path"]] or row["roles"] != roles:
            raise ValueError("Presentation source roles or authority differ")
        lines = body.splitlines(keepends=True)
        starts = {i + 1: match[1] for i, line in enumerate(lines)
                  if (match := re.match(r"^(?:static )?func (\w+)\(", line))}
        if len(row["functions"]) != len(starts) or {r["line"] for r in row["functions"]} != set(starts):
            raise ValueError("An original presentation function anchor is missing")
        for anchor in row["functions"]:
            start = anchor["line"] - 1
            end = start + 1
            while end < len(lines) and (not lines[end].strip() or lines[end][0].isspace() or lines[end].startswith("#")):
                end += 1
            function = "".join(lines[start:end]).rstrip() + "\n"
            if (anchor["function"] != starts[start + 1] or
                    anchor["bodySha256LF"] != hashlib.sha256(function.encode()).hexdigest() or
                    anchor["endLine"] != start + len(function.splitlines())):
                raise ValueError("Original presentation function body differs")
    if len(coverage["contracts"]) != len(CONTRACTS) or {r["id"] for r in coverage["contracts"]} != CONTRACTS:
        raise ValueError("A required presentation contract is missing")
    for row in coverage["contracts"]:
        if not row["sourcePaths"] or not set(row["sourcePaths"]) <= set(authority):
            raise ValueError("Presentation contract has no original source anchor")
    if coverage.get("personalSavesUsed") is not False or coverage.get("unityExecutionProvenByThisContract") is not False:
        raise ValueError("Source register claims unsupported execution")


class PresentationCoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.coverage = load(ROOT / "migration/presentation-coverage.json")

    def test_all_original_assets_generators_dependencies_and_functions_are_covered(self):
        check_coverage(self.coverage)

    def test_dropping_tool_review_or_game_asset_is_detected(self):
        changed = deepcopy(self.coverage)
        changed["assets"].pop()
        with self.assertRaisesRegex(ValueError, "asset is missing"):
            check_coverage(changed)

    def test_dropping_generator_is_detected(self):
        changed = deepcopy(self.coverage)
        changed["generators"].pop()
        with self.assertRaisesRegex(ValueError, "generator is missing"):
            check_coverage(changed)

    def test_dropping_delegated_source_is_detected(self):
        changed = deepcopy(self.coverage)
        changed["allOriginalScriptDependencies"].pop()
        with self.assertRaisesRegex(ValueError, "dependency source is missing"):
            check_coverage(changed)

    def test_dropping_draw_function_anchor_is_detected(self):
        changed = deepcopy(self.coverage)
        next(r for r in changed["presentationSources"] if r["functions"])["functions"].pop()
        with self.assertRaisesRegex(ValueError, "function anchor is missing"):
            check_coverage(changed)

    def test_changed_procedural_function_hash_is_detected(self):
        changed = deepcopy(self.coverage)
        next(r for r in changed["presentationSources"] if r["functions"])["functions"][0]["bodySha256LF"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "function body differs"):
            check_coverage(changed)

    def test_source_retention_cannot_claim_unity_execution(self):
        changed = deepcopy(self.coverage)
        changed["unityExecutionProvenByThisContract"] = True
        with self.assertRaisesRegex(ValueError, "unsupported execution"):
            check_coverage(changed)


if __name__ == "__main__":
    unittest.main()
