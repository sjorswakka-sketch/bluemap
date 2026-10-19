#!/usr/bin/env python3
"""Extract Godot's exact embedded font in an isolated project, then unwrap WOFF2.

Requires fonttools==4.60.1 and brotli==1.2.0 only for this explicit recording step;
normal asset verification and tests do not install or import those dependencies.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import uuid

from migration_data_codec import canonical_bytes
from record_migration_world import ENGINE_VERSION, ERROR, fingerprint, no_symlink

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = "661e2d9975d3029aeb32bf37b1b963c31c7c3ce08ac1bab2c8ebe27e135c4ec2"
FALLBACK_SHA256 = "b41f0f026055325a1c78c7f380e811ab0a5122d1c26a85ec1243f3c024c66002"
FALLBACK_CODEPOINTS = [8592, 8593, 8594, 8595, 9632, 9679]
FONTTOOLS_VERSION = "4.60.1"
BROTLI_VERSION = "1.2.0"
SOURCE_BASE = "https://raw.githubusercontent.com/godotengine/godot/4.4.1-stable/"


def sfnt_tables(data):
    """Read bounded TTF table bytes; ignore only the container checksum fixup."""
    if len(data) < 12 or data[:4] != b"\x00\x01\x00\x00":
        raise ValueError("Expected the original TrueType outline flavor")
    count = struct.unpack_from(">H", data, 4)[0]
    if not 1 <= count <= 128 or len(data) < 12 + count * 16:
        raise ValueError("Invalid TrueType table directory")
    result = {}
    intervals = []
    for index in range(count):
        tag, checksum, offset, size = struct.unpack_from(">4sIII", data, 12 + index * 16)
        tag_text = tag.decode("ascii")
        if tag_text in result or offset < 12 + count * 16 or offset + size > len(data):
            raise ValueError("Duplicate or out-of-bounds TrueType table")
        if any(max(offset, start) < min(offset + size, end) for start, end in intervals):
            raise ValueError("Overlapping TrueType tables")
        intervals.append((offset, offset + size))
        table = data[offset:offset + size]
        if tag == b"head":
            if len(table) < 12:
                raise ValueError("Truncated TrueType head table")
            table = table[:8] + b"\0" * 4 + table[12:]
        result[tag_text] = table
    return result


def table_hashes(tables):
    return {tag: hashlib.sha256(data).hexdigest() for tag, data in sorted(tables.items())}


def convert_font(source, destination, codepoints, expected_sha256=SOURCE_SHA256):
    import fontTools
    import brotli
    from fontTools.ttLib import TTFont
    if fontTools.__version__ != FONTTOOLS_VERSION or brotli.__version__ != BROTLI_VERSION:
        raise ValueError("Use the pinned fonttools/brotli conversion versions")
    if hashlib.sha256(source.read_bytes()).hexdigest() != expected_sha256:
        raise ValueError("Font differs from its pinned Godot-bundled source")
    font = TTFont(source, recalcTimestamp=False, lazy=False)
    original = {}
    for tag in font.keys():
        if tag == "GlyphOrder":
            continue
        value = font.getTableData(tag)
        if tag == "head":
            value = value[:8] + b"\0" * 4 + value[12:]
        original[tag] = value
    cmap = font.getBestCmap()
    missing = sorted(set(codepoints) - set(cmap) - {9, 10, 13})
    names = {str(index): sorted({entry.toUnicode() for entry in font["name"].names if entry.nameID == index})
             for index in [0, 1, 2, 5, 6, 13, 14]}
    font.flavor = None
    font.save(destination, reorderTables=False)
    actual = sfnt_tables(destination.read_bytes())
    if original != actual:
        changed = sorted(tag for tag in set(original) | set(actual) if original.get(tag) != actual.get(tag))
        raise ValueError("Font conversion changed original tables: " + ", ".join(changed))
    return {"sourceSha256": expected_sha256, "ttfSha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
            "fontNames": names, "tableHashes": table_hashes(actual), "tableCount": len(actual),
            "checksumAdjustmentNormalized": True, "timestampRecalculated": False,
            "missingPrimaryCodepoints": missing, "fonttoolsVersion": FONTTOOLS_VERSION,
            "brotliVersion": BROTLI_VERSION, "fontSubstituted": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot")
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--evidence-dir", required=True, type=Path)
    parser.add_argument("--font-deps", type=Path)
    parser.add_argument("--fallback-woff2", type=Path,
                        default=ROOT / "unity/Assets/BlueMapContent/Resources/BlueMapAssets/Fonts/FallbackFont.woff2.bytes")
    args = parser.parse_args()
    if args.font_deps:
        sys.path.insert(0, str(args.font_deps.resolve()))
    task = Path(tempfile.mkdtemp(prefix="bluemap-font-"))
    project = task / "project"
    user_dir = None
    before = fingerprint(ROOT)
    token = "Bluemap-Codex-Tests-" + uuid.uuid4().hex
    try:
        for path in [args.output_dir, args.evidence_dir]:
            no_symlink(path)
            if path.exists():
                raise ValueError("Output and evidence directories must be new")
        args.evidence_dir.mkdir(parents=True)
        engine = shutil.which(args.godot)
        if not engine:
            raise ValueError("Pinned Godot executable not found")
        version = subprocess.run([engine, "--version"], capture_output=True, text=True, timeout=30)
        if version.returncode or version.stdout.strip() != ENGINE_VERSION:
            raise ValueError("Font extraction requires exact Godot " + ENGINE_VERSION)
        shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(
            ".git", ".godot", ".testdata", "build", "dist", "__pycache__", "Library", "Temp"))
        settings = project / "project.godot"
        text = settings.read_text(encoding="utf-8")
        text = re.sub(r'^config/name=.*$', 'config/name=' + json.dumps(token), text, flags=re.M)
        text = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n?', '', text, flags=re.M)
        text = text.replace('[application]', '[application]\nconfig/use_custom_user_dir=false', 1)
        settings.write_text(text, encoding="utf-8")
        probe = ('extends SceneTree\nfunc _initialize():\n\tvar path:=OS.get_user_data_dir()\n'
                 '\tprint("ISOLATED_USER_DIR="+path)\n\tquit(0 if path.replace(char(92),"/").get_file()=='
                 + json.dumps(token) + ' else 1)\n')
        (project / "font_isolation_probe.gd").write_text(probe, encoding="utf-8")

        def run(label, arguments):
            process = subprocess.run([engine, "--headless", "--path", str(project), *arguments],
                                     cwd=project, capture_output=True, text=True, encoding="utf-8",
                                     errors="replace", timeout=600, env=dict(os.environ, BLUEMAP_LANG="nl"))
            log = process.stdout + process.stderr
            (args.evidence_dir / (label + ".log")).write_text(log, encoding="utf-8")
            if process.returncode or ERROR.search(log):
                raise ValueError(label + " failed: " + log[-10000:])
            return log

        run("import", ["--editor", "--import"])
        log = run("isolation", ["-s", "res://font_isolation_probe.gd"])
        match = re.search(r'^ISOLATED_USER_DIR=(.+)$', log, re.M)
        if not match or Path(match[1].strip()).name != token:
            raise ValueError("Font export storage isolation not verified")
        user_dir = Path(match[1].strip())
        import i18n
        po = i18n.read_po(str(ROOT / "translations/en.po"))
        characters = {ord(c) for entry in po.entries for c in entry.msgid + entry.plural + entry.msgstr + "".join(entry.msgstr_plural)}
        # Include digits and common control/action labels, not personal/system text.
        characters.update(map(ord, "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzéëïĳ€"))
        codepoints = sorted(characters)
        codepoint_path = args.evidence_dir / "codepoints.json"
        codepoint_path.write_bytes(canonical_bytes(codepoints))
        extracted = args.evidence_dir / "extracted"
        log = run("font", ["-s", "res://tools/migration_font_export.gd", "--", "--output-dir", str(extracted),
                           "--codepoints", str(codepoint_path)])
        if "MIGRATION FONT EXPORT OK" not in log:
            raise ValueError("Font export did not complete")
        metrics = json.loads((extracted / "metrics.json").read_text(encoding="utf-8"))
        if metrics["sha256"] != SOURCE_SHA256 or metrics["fontSubstituted"] is not False:
            raise ValueError("Actual engine font identity did not match")
        converted = extracted / "DefaultFont.ttf"
        conversion = convert_font(extracted / "DefaultFont.woff2", converted, codepoints)
        if conversion["missingPrimaryCodepoints"] != FALLBACK_CODEPOINTS or metrics["missingPrimaryGlyphs"] != FALLBACK_CODEPOINTS:
            raise ValueError("Original primary font missing-glyph set differs from its measured six-symbol contract")
        fallback_ttf = extracted / "FallbackFont.ttf"
        fallback = convert_font(args.fallback_woff2, fallback_ttf, FALLBACK_CODEPOINTS, FALLBACK_SHA256)
        if fallback["missingPrimaryCodepoints"]:
            raise ValueError("Pinned supplementary font lacks an existing symbol")
        if fingerprint(ROOT) != before:
            raise ValueError("Original Godot sources changed during font extraction")
        result = {"schema": "bluemap.migration.font.v1", "baselineCommit": "a8a988be27835dec979d2523a3a85a34385eac54",
                  "engineVersion": ENGINE_VERSION, "embeddedSource": SOURCE_BASE + "thirdparty/fonts/OpenSans_SemiBold.woff2",
                  "license": "Apache-2.0", "sourceStorage": "DefaultFont.woff2.bytes", "unityFont": "DefaultFont.ttf",
                  "resourceKey": "BlueMapAssets/Fonts/DefaultFont", "codepoints": codepoints,
                  "metrics": metrics, "conversion": conversion, "sourceUnchanged": True,
                  "fallback": {"embeddedSource": SOURCE_BASE + "thirdparty/fonts/DroidSansFallback.woff2",
                               "sourceStorage": "FallbackFont.woff2.bytes", "unityFont": "FallbackFont.ttf",
                               "resourceKey": "BlueMapAssets/Fonts/FallbackFont", "codepoints": FALLBACK_CODEPOINTS,
                               "conversion": fallback, "previousSelection": "Unspecified Godot OS font fallback",
                               "selection": "Explicit pinned Godot-bundled DroidSansFallback for the six missing symbols only",
                               "platformIndependent": True, "claimedSameAsOriginalOsFace": False},
                  "personalSavesUsed": False, "fontSubstituted": False,
                  "scope": "Same embedded outline/font tables; text engine rasterization/layout equivalence remains a later UI check"}
        args.output_dir.mkdir(parents=True)
        shutil.copyfile(extracted / "DefaultFont.woff2", args.output_dir / "DefaultFont.woff2.bytes")
        shutil.copyfile(converted, args.output_dir / "DefaultFont.ttf")
        shutil.copyfile(args.fallback_woff2, args.output_dir / "FallbackFont.woff2.bytes")
        shutil.copyfile(fallback_ttf, args.output_dir / "FallbackFont.ttf")
        (args.output_dir / "font-manifest.json").write_bytes(canonical_bytes(result))
        license_path = ROOT / "migration/phase-06/font-licenses/Apache-2.0.txt"
        shutil.copyfile(license_path, args.output_dir / "Apache-2.0.txt")
        shutil.copyfile(license_path.parent / "LICENSE.DroidSans.txt", args.output_dir / "LICENSE.DroidSans.txt")
        copyright_text = "\n".join(conversion["fontNames"]["0"])
        (args.output_dir / "NOTICE.txt").write_text(
            "Open Sans SemiBold 1.10 — extracted unchanged from Godot 4.4.1 game fallback.\n" + copyright_text
            + "\nLicense: Apache-2.0; see Apache-2.0.txt.\n"
            "Container conversion only: embedded WOFF2 unwrapped to TTF for Unity; original tables preserved.\n"
            "Supplementary DroidSansFallback: " + "\n".join(fallback["fontNames"]["0"])
            + "\nCopyright (C) 2008 The Android Open Source Project. Apache-2.0.\n"
            "Explicit supplementary font for six symbols previously resolved by OS fallback; no claim of the same OS font face.\n",
            encoding="utf-8", newline="\n")
        (args.evidence_dir / "verification.json").write_bytes(canonical_bytes({"success": True, **result}))
        print("MIGRATION FONT RECORDED OK:", metrics["family"], metrics["style"], len(codepoints), "codepoints")
        return 0
    except (OSError, ValueError, ImportError, subprocess.SubprocessError) as error:
        print("MIGRATION FONT FAILED:", error, file=sys.stderr)
        return 1
    finally:
        if user_dir is not None and user_dir.name == token and user_dir.exists():
            shutil.rmtree(user_dir)
        print("Font extraction project and evidence retained:", task)


if __name__ == "__main__":
    raise SystemExit(main())
