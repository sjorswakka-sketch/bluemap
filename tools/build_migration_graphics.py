#!/usr/bin/env python3
"""Preserve original PNG bytes and proven pixel-art regions for Unity phase 6.

Unknown atlases retain their entire image. Generated images must come from the
separate pinned Godot export; this tool neither runs Godot nor invents art.
All region coordinates are measured from the source image's top-left corner.
"""
from __future__ import annotations

import argparse
import io
import json
import math
from pathlib import Path
import re
import sys

from PIL import Image

from build_migration_audio_text import (RESOURCE_ROOT, PresentationError, _frozen_bytes,
                                       meta_bytes, no_symlink, require, sha, unity_guid)
from build_migration_data import BASELINE, TREE, inputs
from migration_data_codec import canonical_bytes, json_read

ROOT = Path(__file__).resolve().parents[1]
GENERATED_ROOT = "migration/presentation/graphics-generated"
GRAPHICS_ROOT = RESOURCE_ROOT + "/Graphics"
MAX_PIXELS = 32 * 1024 * 1024
DIRECTIONS = ("down", "up", "right", "left")
POSES = ("idle", "step1", "step2")
ENGINE_VERSION = "4.4.1.stable.official.49a5bc7b6"
EXPORTERS = ("res://tools/migration_graphics_export.gd", "res://tools/migration_presentation_canvas.gd")


def png_metadata(data: bytes) -> dict:
    require(0 < len(data) <= 128 * 1024 * 1024, "PNG byte bound exceeded")
    try:
        with Image.open(io.BytesIO(data)) as checked:
            require(checked.format == "PNG", "Expected PNG format")
            checked.verify()
        with Image.open(io.BytesIO(data)) as image:
            require(image.format == "PNG", "Expected PNG format")
            width, height = image.size
            require(width > 0 and height > 0 and width * height <= MAX_PIXELS, "PNG dimensions exceed bound")
            rgba = image.convert("RGBA").tobytes()
    except (OSError, ValueError, SyntaxError) as error:
        raise PresentationError("Invalid PNG source") from error
    return {"width": width, "height": height, "bytes": len(data),
            "sha256": sha(data), "rgbaSha256": sha(rgba)}


def texture_meta(unity_relative: str) -> bytes:
    # The real editor importer independently asserts these settings and pixel
    # identity. Transparent RGB must survive: alphaIsTransparency stays off.
    return ("fileFormatVersion: 2\nguid: " + unity_guid(unity_relative) + "\n"
            "TextureImporter:\n  externalObjects: {}\n  serializedVersion: 13\n"
            "  mipmaps:\n    enableMipMap: 0\n    sRGBTexture: 1\n"
            "  isReadable: 1\n  textureFormat: 1\n  maxTextureSize: 8192\n"
            "  textureSettings:\n    serializedVersion: 2\n    filterMode: 0\n"
            "    aniso: 0\n    mipBias: 0\n    wrapU: 1\n    wrapV: 1\n    wrapW: 1\n"
            "  nPOTScale: 0\n  textureType: 0\n  textureShape: 1\n"
            "  alphaIsTransparency: 0\n  textureCompression: 0\n"
            "  userData: \n  assetBundleName: \n  assetBundleVariant: \n").encode("utf-8")


def literal_constant(source: str, name: str):
    """Read only a JSON-shaped frozen GDScript constant, never evaluate code."""
    match = re.search(r"(?m)^const\s+" + re.escape(name) + r"\s*(?::[^=\n]+)?\s*:?=\s*", source)
    require(match is not None, "Missing literal layout constant: " + name)
    start = match.end()
    require(source[start] in "[{", "Layout constant is not an array/dictionary")
    depth, at, quoted, escaped, cleaned = 0, start, False, False, []
    while at < len(source):
        char = source[at]
        if quoted:
            cleaned.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
            cleaned.append(char)
        elif char == "#":
            newline = source.find("\n", at)
            require(newline >= 0, "Unclosed literal layout constant")
            at = newline
            cleaned.append("\n")
        else:
            cleaned.append(char)
            if char in "[{":
                depth += 1
            elif char in "]}":
                depth -= 1
                if depth == 0:
                    text = re.sub(r",\s*([\]}])", r"\1", "".join(cleaned))
                    try:
                        return json.loads(text)
                    except ValueError as error:
                        raise PresentationError("Layout constant is not data-only JSON: " + name) from error
        at += 1
    raise PresentationError("Unclosed literal layout constant: " + name)


def validate_catalog(catalog: dict) -> None:
    require(catalog.get("schemaVersion") == 1 and catalog.get("tilePixels") == 32,
            "Graphics schema/source scale differs")
    textures = {}
    for texture in catalog["textures"]:
        require(texture["id"] not in textures, "Duplicate texture identity")
        require(type(texture["width"]) is int and type(texture["height"]) is int and
                0 < texture["width"] * texture["height"] <= MAX_PIXELS, "Invalid texture dimensions")
        require(re.fullmatch(r"[0-9a-f]{64}", texture["sha256"]) is not None and
                re.fullmatch(r"[0-9a-f]{64}", texture["rgbaSha256"]) is not None, "Invalid texture digests")
        require(texture["resourcePath"].startswith("BlueMapAssets/Graphics/") and
                ".." not in texture["resourcePath"].split("/") and "\\" not in texture["resourcePath"],
                "Unsafe graphics resource path")
        textures[texture["id"]] = texture
    sprites = {}
    for sprite in catalog["sprites"]:
        require(sprite["id"] not in sprites, "Duplicate sprite identity")
        require(sprite["textureId"] in textures, "Sprite references missing texture")
        texture = textures[sprite["textureId"]]
        require(all(type(sprite[field]) is int for field in ("x", "y", "width", "height")),
                "Sprite rectangle must use integer source pixels")
        require(sprite["x"] >= 0 and sprite["y"] >= 0 and sprite["width"] > 0 and sprite["height"] > 0 and
                sprite["x"] + sprite["width"] <= texture["width"] and
                sprite["y"] + sprite["height"] <= texture["height"], "Sprite region outside source texture")
        require(all(type(sprite[field]) in (int, float) and math.isfinite(sprite[field])
                    and 0 <= sprite[field] <= 1 for field in ("pivotX", "pivotY")) and
                type(sprite["pixelsPerUnit"]) in (int, float) and sprite["pixelsPerUnit"] == 32,
                "Sprite pivot/source scale changed")
        sprites[sprite["id"]] = sprite
    animations = set()
    for animation in catalog["animations"]:
        require(animation["id"] not in animations and animation["frames"] and
                all(frame in sprites for frame in animation["frames"]), "Invalid animation identity/frames")
        require(type(animation["fps"]) in (int, float) and math.isfinite(animation["fps"]) and
                animation["fps"] > 0 and type(animation["loop"]) is bool, "Invalid animation timing")
        animations.add(animation["id"])


def _source_frames(source: str) -> dict[str, int]:
    # Only records with an explicit authored frame are used. Other complex
    # dictionaries (Vector2i, logic) are not evaluated or converted.
    return {name: int(frame) for name, frame in re.findall(
        r'^\s*"([^"\n]+)"\s*:\s*\{[^\n]*?"frame"\s*:\s*(\d+)', source, re.MULTILINE)}


def procedural_contract(path: str, source: str) -> dict:
    """Exact source witnesses, never instructions executed by the importer.

    The complete file preserves comments, classes and initializer dependencies;
    function spans are a navigation aid, not a substitute for that full source.
    """
    lines = source.splitlines(keepends=True)
    declarations = []
    pattern = re.compile(r"^(\s*)(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
    for index, line in enumerate(lines):
        match = pattern.match(line)
        if match:
            declarations.append((index, len(match.group(1).expandtabs(4)), match.group(2)))
    functions = []
    for start, indent, name in declarations:
        end = len(lines)
        for index in range(start + 1, len(lines)):
            stripped = lines[index].strip()
            if not stripped or stripped.startswith("#"):
                continue
            current_indent = len(lines[index]) - len(lines[index].lstrip(" \t"))
            current_indent = len(lines[index][:current_indent].expandtabs(4))
            if current_indent <= indent:
                end = index
                break
        raw = "".join(lines[start:end])
        functions.append({"name": name, "line": start + 1, "endLine": end,
                          "sha256": sha(raw.encode("utf-8")), "source": raw})
    return {"path": path, "sha256": sha(source.encode("utf-8")), "source": source,
            "functions": functions, "execution": "not_executed_source_only"}


def validate_generated_provenance(index: dict, root: Path) -> None:
    require(index.get("engineVersion") == ENGINE_VERSION, "Generated graphics require the exact pinned Godot engine")
    handlers = index.get("exporterSources")
    require(type(handlers) is dict and set(handlers) == set(EXPORTERS),
            "Generated graphics exporter provenance is incomplete")
    for source in EXPORTERS:
        path = Path(root) / source[len("res://"):]
        no_symlink(path)
        require(path.is_file() and handlers[source] == sha(path.read_bytes().replace(b"\r\n", b"\n")),
                "Stale generated graphics exporter source: " + source)


def known_regions(textures: list[dict], sources: dict[str, str]) -> tuple[list[dict], list[dict], list[dict]]:
    by_path = {texture["sourcePath"]: texture for texture in textures}
    sprites, animations = [], []

    def add(identifier, path, category, x, y, width, height, pivot=(.5, .5)):
        require(path in by_path, "Proven layout texture missing: " + path)
        sprites.append({"id": identifier, "textureId": by_path[path]["id"], "category": category,
                        "x": x, "y": y, "width": width, "height": height,
                        "pivotX": pivot[0], "pivotY": pivot[1], "pixelsPerUnit": 32})

    for texture in textures:
        add("image:" + texture["sourcePath"], texture["sourcePath"], "full_image", 0, 0,
            texture["width"], texture["height"])
    manifest = sources["scripts/data/character_art.gd"]
    npcs = literal_constant(manifest, "NPC_SHEETS")
    hair = literal_constant(manifest, "HAIR")
    clothes = literal_constant(manifest, "CLOTHES")
    require(len(npcs) == 35 and len(hair) == 90 and len(clothes) == 28, "Native character layout coverage changed")
    for actor in ["player", *npcs]:
        path = "assets/pixel_" + actor + ".png"
        require((by_path[path]["width"], by_path[path]["height"]) == (96, 128), "Native actor grid changed")
        for row, direction in enumerate(DIRECTIONS):
            for column, pose in enumerate(POSES):
                add(actor + ":" + direction + ":" + pose, path, "actor", column * 32, row * 32, 32, 32)
            animations.append({"id": "actor:" + actor + ":" + direction,
                               "frames": [actor + ":" + direction + ":step1", actor + ":" + direction + ":step2"],
                               "fps": 9 if actor == "player" else 5, "loop": True})
    for name, index in hair.items():
        for row, direction in enumerate(DIRECTIONS):
            add("hair:" + name + ":" + direction, "assets/character_hair.png", "hair", index * 32, row * 32, 32, 32)
    for name, index in clothes.items():
        for row, direction in enumerate(DIRECTIONS):
            for column, pose in enumerate(POSES):
                add("clothes:" + name + ":" + direction + ":" + pose, "assets/character_clothes.png", "clothes",
                    (index * 3 + column) * 32, row * 32, 32, 32)
    tiles = literal_constant(sources["scripts/data/tiles.gd"], "NAMES")
    require(len(tiles) == 80, "Original 80 terrain types changed")
    for index, name in enumerate(tiles):
        for variant in range(8):
            add("tile:" + name + ":" + str(variant), "assets/pixel_landscape.png", "terrain",
                index * 32, variant * 32, 32, 32)
    for row, name in enumerate(("tree", "pine", "willow")):
        for variant in range(8):
            add("canopy:" + name + ":" + str(variant), "assets/pixel_canopies.png", "canopy",
                variant * 48, row * 64, 48, 64, (.5, 6 / 64))
    for kind, frame in _source_frames(sources["scripts/data/house_catalog.gd"]).items():
        if kind != "rug":
            for tint in range(3):
                add("furniture:" + kind + ":" + str(tint), "assets/house_furniture.png", "furniture",
                    frame * 64, tint * 64, 64, 64, (.5, .25))
    for tint in range(3):
        add("rug:" + str(tint), "assets/house_rugs.png", "furniture", tint * 128, 0, 128, 64)
    for index in range(8):
        add("house_surface:" + str(index), "assets/house_surfaces.png", "surface", index * 32, 0, 32, 32)
    yard = _source_frames(sources["scripts/data/yard_catalog.gd"])
    for name in ("gravel", "stone", "boards"):
        for mask in range(16):
            add("yard:path:" + name + ":" + str(mask), "assets/yard_paths.png", "yard",
                mask * 32, yard[name] * 32, 32, 32)
    for index in range(6):
        add("yard:fence:" + str(index), "assets/yard_fences.png", "yard", index * 64, 0, 64, 64, (.5, .25))
    for name, row in _source_frames(sources["scripts/data/orchard_catalog.gd"]).items():
        for stage in range(4):
            add("crop:" + name + ":" + str(stage), "assets/orchard_crops.png", "crop", stage * 32, row * 32, 32, 32)
    for kind in ("trunks", "canopies"):
        path = "assets/orchard_" + kind + ".png"
        for stage in range(by_path[path]["width"] // 64):
            add("orchard:" + kind + ":" + str(stage), path, "orchard", stage * 64, 0, 64, 64, (.5, .25))
    aliases = []
    for path, texture in sorted(by_path.items()):
        name = Path(path).stem
        detailed = str(Path(path).with_name("pixel_" + Path(path).name)).replace("\\", "/")
        if not name.startswith("pixel_") and detailed in by_path:
            aliases.append({"name": name, "originalTextureId": texture["id"],
                            "detailedTextureId": by_path[detailed]["id"], "density": 2})
    return sprites, animations, aliases


def build_documents(root: Path = ROOT, *, require_generated: bool = True) -> dict[str, bytes]:
    root = Path(root)
    inputs(root)
    original = json_read(root / "migration/reference/source-manifest.json")
    manifest = {entry["path"]: entry for entry in original["files"]}
    documents, textures, anchors = {}, [], []

    def source(path, text=False):
        raw = _frozen_bytes(root, path, manifest, text=text)
        anchors.append({"path": path, "sha256": sha(raw), "bytes": len(raw)})
        return raw

    for path in sorted(manifest):
        if not path.endswith(".png"):
            continue
        raw = source(path)
        target = GRAPHICS_ROOT + "/Original/" + path
        documents[target] = raw
        documents[target + ".meta"] = texture_meta(target[len("unity/"):])
        textures.append({"id": "png:" + path, "sourcePath": path,
                         "resourcePath": "BlueMapAssets/Graphics/Original/" + path[:-4], **png_metadata(raw)})
    require(len(textures) == 244, "Not all 244 original PNGs were retained")
    sources = {}
    source_paths = ("scripts/data/character_art.gd", "scripts/data/tiles.gd", "scripts/core/art.gd",
                    "scripts/core/character_draw.gd", "scripts/core/character_layers.gd", "scripts/core/draw_util.gd",
                    "scripts/entities/player.gd", "scripts/entities/pixel_canopy.gd", "scripts/core/pixel_landscape.gd",
                    "scripts/core/house_art.gd", "scripts/core/yard_art.gd", "scripts/core/orchard_art.gd",
                    "scripts/data/house_catalog.gd", "scripts/data/yard_catalog.gd", "scripts/data/orchard_catalog.gd")
    for path in source_paths:
        sources[path] = source(path, True).decode("utf-8")
    procedural = []
    for path in sorted(manifest):
        if path.startswith("scripts/") and path.endswith(".gd"):
            raw_source = sources.get(path)
            if raw_source is None:
                raw_source = _frozen_bytes(root, path, manifest, text=True).decode("utf-8")
            procedural.append(procedural_contract(path, raw_source))
    sprites, animations, aliases = known_regions(textures, sources)
    generated_index = root / GENERATED_ROOT / "index.json"
    generated_provenance = None
    if require_generated:
        require(generated_index.is_file(), "Pinned Godot-generated graphics index has not been supplied")
    if generated_index.is_file():
        no_symlink(generated_index)
        generated = json_read(generated_index)
        require(generated.get("schemaVersion") == 1, "Unsupported generated graphics index")
        validate_generated_provenance(generated, root)
        generated_provenance = {"engineVersion": generated["engineVersion"],
                                "exporterSources": generated["exporterSources"],
                                "indexSha256": sha(canonical_bytes(generated))}
        indexed = {"index.json"}
        for entry in generated["textures"]:
            name = entry["file"]
            require(type(name) is str and re.fullmatch(r"[A-Za-z0-9_-]+\.png", name) is not None,
                    "Unsafe generated PNG name")
            path = root / GENERATED_ROOT / name
            no_symlink(path)
            raw = path.read_bytes()
            metadata = png_metadata(raw)
            require(metadata["width"] == entry["width"] and metadata["height"] == entry["height"],
                    "Generated graphics dimensions differ")
            for field in ("sha256", "rgbaSha256"):
                if field in entry:
                    require(metadata[field] == entry[field], "Generated graphics digest differs")
            target = GRAPHICS_ROOT + "/Generated/" + name
            documents[target] = raw
            documents[target + ".meta"] = texture_meta(target[len("unity/"):])
            textures.append({**entry, **metadata, "sourcePath": entry["sourcePath"],
                             "resourcePath": "BlueMapAssets/Graphics/Generated/" + name[:-4]})
            sprites.append({"id": "image:" + entry["id"], "textureId": entry["id"],
                            "category": "generated_full_image", "x": 0, "y": 0,
                            "width": metadata["width"], "height": metadata["height"],
                            "pivotX": .5, "pivotY": .5, "pixelsPerUnit": 32})
            if entry["id"] == "generated:equipment-icons":
                require((metadata["width"], metadata["height"]) == (160, 16),
                        "Original generated equipment icon grid changed")
                for frame in range(10):
                    sprites.append({"id": "equipment:icon:" + str(frame), "textureId": entry["id"],
                                    "category": "equipment", "x": frame * 16, "y": 0,
                                    "width": 16, "height": 16, "pivotX": .5, "pivotY": .5,
                                    "pixelsPerUnit": 32})
            indexed.add(name)
        for path in (root / GENERATED_ROOT).iterdir():
            no_symlink(path)
            require(path.is_file() and path.name in indexed, "Unindexed generated graphics file")
        sprites += generated.get("sprites", [])
        animations += generated.get("animations", [])
    svg = source("icon.svg", True)
    documents[GRAPHICS_ROOT + "/Original/icon.svg.txt"] = svg
    documents[GRAPHICS_ROOT + "/Original/icon.svg.txt.meta"] = meta_bytes((GRAPHICS_ROOT + "/Original/icon.svg.txt")[len("unity/"):])
    catalog = {"schemaVersion": 1, "version": 1, "phase": 6, "tilePixels": 32,
               "baselineCommit": BASELINE, "baselineTree": TREE, "textures": textures,
               "sprites": sprites, "animations": animations, "aliases": aliases,
               "sourceAnchors": sorted(anchors, key=lambda entry: entry["path"]),
               "proceduralSources": procedural,
               "proceduralScope": "conservative_all_original_scripts_including_nonvisual_helpers_no_execution_claim",
               "generatedProvenance": generated_provenance,
               "coordinateConvention": "top_left_source_pixels_unity_y_equals_textureHeight_minus_y_minus_height",
               "pivotConvention": "native_world_anchor_where_defined_else_center_of_image",
               "scope": "all_original_PNG_bytes_proven_regions_and_source_generated_images_not_gameplay_render_equivalence",
               "originalSvg": {"sourcePath": "icon.svg", "sha256": sha(svg), "bytes": len(svg),
                               "resourcePath": "BlueMapAssets/Graphics/Original/icon.svg"}}
    validate_catalog(catalog)
    for path in ("migration/presentation/graphics.json", RESOURCE_ROOT + "/Data/graphics.json"):
        documents[path] = canonical_bytes(catalog)
        if path.startswith("unity/"):
            documents[path + ".meta"] = meta_bytes(path[len("unity/"):])
    folders = set()
    for name in list(documents):
        if name.startswith(GRAPHICS_ROOT + "/"):
            parent = Path(name).parent
            while str(parent).replace("\\", "/").startswith(GRAPHICS_ROOT):
                folders.add(parent.as_posix())
                parent = parent.parent
    for folder in sorted(folders):
        documents[folder + ".meta"] = meta_bytes(folder[len("unity/"):], folder=True)
    return documents


def write_or_check(root: Path, documents: dict[str, bytes], *, check: bool) -> dict:
    root = Path(root).resolve()
    for name, raw in documents.items():
        path = root / name
        no_symlink(path)
        require(path.resolve().is_relative_to(root), "Graphics output escapes root")
        if check:
            require(path.is_file(), "Missing graphics output: " + name)
            actual = path.read_bytes()
            if not name.endswith(".png"):
                actual = actual.replace(b"\r\n", b"\n")
            require(actual == raw, "Graphics output differs: " + name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    expected = {str((root / name).resolve()) for name in documents if name.startswith(GRAPHICS_ROOT + "/")}
    actual = set()
    for path in (root / GRAPHICS_ROOT).rglob("*"):
        no_symlink(path)
        if path.is_file():
            actual.add(str(path.resolve()))
    require(expected == actual, "Unindexed graphics output file")
    catalog = json.loads(documents["migration/presentation/graphics.json"])
    return {"success": True, "textures": len(catalog["textures"]), "sprites": len(catalog["sprites"]),
            "animations": len(catalog["animations"]), "engineExecuted": False, "personalSavesUsed": False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        print("GRAPHICS TRANSFER OK:", write_or_check(ROOT, build_documents(ROOT), check=args.check))
        return 0
    except (OSError, ValueError) as error:
        print("GRAPHICS TRANSFER FAILED:", error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
