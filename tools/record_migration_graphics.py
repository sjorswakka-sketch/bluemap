#!/usr/bin/env python3
"""Record real GPU-drawn original presentation samples in an isolated Godot copy.

Two fresh engine processes must produce byte-identical PNGs and canonical JSON.
This is presentation evidence, not a running Unity world or gameplay port.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import uuid

from migration_data_codec import canonical_bytes, json_read
from record_migration_world import ENGINE_VERSION, ERROR, fingerprint, no_symlink

ROOT = Path(__file__).resolve().parents[1]
EXPORTERS = ("tools/migration_graphics_export.gd", "tools/migration_presentation_canvas.gd")
PNG_NAME = re.compile(r"[a-z0-9][a-z0-9_.-]*\.png\Z")


def source_fingerprint(root):
    result = fingerprint(root)
    for path in [*(root / "assets").rglob("*"), root / "icon.svg", *[root / name for name in EXPORTERS]]:
        if path.is_file():
            result[path.relative_to(root).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def normalize_graphics(directory, exporter_sources=None):
    """Check every declared PNG; retain exact source pixel bytes and IDs."""
    index = json_read(directory / "index.json")
    if index.get("schemaVersion") != 1 or index.get("tilePixels") != 32:
        raise ValueError("Unsupported graphics export schema/scale")
    if index.get("engineVersion", ENGINE_VERSION) != ENGINE_VERSION:
        raise ValueError("Graphics index has a stale engine identity")
    index["engineVersion"] = ENGINE_VERSION
    if exporter_sources is not None:
        if index.get("exporterSources", exporter_sources) != exporter_sources:
            raise ValueError("Graphics index has stale exporter identities")
        index["exporterSources"] = exporter_sources
    if any(type(index.get(key)) is not list or not index[key] for key in ("textures", "sprites", "animations")):
        raise ValueError("Empty renderer export has no complete presentation samples")
    names, ids = set(), set()
    for texture in index["textures"]:
        name = texture["file"]
        if type(name) is not str or not PNG_NAME.fullmatch(name) or name in names or texture["id"] in ids:
            raise ValueError("Unsafe or duplicate generated texture path/ID")
        names.add(name)
        ids.add(texture["id"])
        path = directory / name
        no_symlink(path)
        raw = path.read_bytes()
        if len(raw) < 24 or raw[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError("Generated texture is not a PNG")
        width, height = struct.unpack_from(">II", raw, 16)
        if (width, height) != (texture["width"], texture["height"]) or not 0 < width * height <= 32 * 1024 * 1024:
            raise ValueError("Generated texture dimensions differ from index")
        digest = hashlib.sha256(raw).hexdigest()
        if texture.get("sha256", digest) != digest or texture.get("bytes", len(raw)) != len(raw):
            raise ValueError("Existing generated PNG digest/byte count is stale")
        texture.update(bytes=len(raw), sha256=digest)
    sprite_ids = set()
    textures = {row["id"]: row for row in index["textures"]}
    for sprite in index["sprites"]:
        if sprite["id"] in sprite_ids or sprite["textureId"] not in textures:
            raise ValueError("Duplicate sprite ID or missing texture")
        sprite_ids.add(sprite["id"])
        texture = textures[sprite["textureId"]]
        if (any(type(sprite.get(key)) is not int for key in ("x", "y", "width", "height")) or
                min(sprite["x"], sprite["y"]) < 0 or min(sprite["width"], sprite["height"]) <= 0 or
                sprite["x"] + sprite["width"] > texture["width"] or sprite["y"] + sprite["height"] > texture["height"]):
            raise ValueError("Generated sprite rectangle is outside its texture")
    animation_ids = set()
    for animation in index["animations"]:
        if animation["id"] in animation_ids or not animation["frames"] or not set(animation["frames"]) <= sprite_ids:
            raise ValueError("Duplicate animation ID or missing sprite frame")
        animation_ids.add(animation["id"])
        if type(animation["fps"]) not in (float, int) or not math.isfinite(animation["fps"]) or animation["fps"] <= 0:
            raise ValueError("Generated animation has no finite positive frame rate")
    actual = {path.relative_to(directory).as_posix() for path in directory.rglob("*") if path.is_file()}
    if actual != names | {"index.json"}:
        raise ValueError("Unexpected or missing graphics export documents")
    (directory / "index.json").write_bytes(canonical_bytes(index))
    return {path.relative_to(directory).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(directory.iterdir()) if path.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "migration/presentation/graphics-generated")
    parser.add_argument("--evidence-dir", required=True, type=Path)
    parser.add_argument("--keep", action="store_true")
    args = parser.parse_args()
    task = Path(tempfile.mkdtemp(prefix="bluemap-gpu-presentation-"))
    project = task / "project"
    token = "Bluemap-Codex-Tests-" + uuid.uuid4().hex
    user_dir = None
    before = source_fingerprint(ROOT)
    exporter_sources = {"res://" + name: hashlib.sha256((ROOT / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
                        for name in EXPORTERS}
    receipt = {"schema": 1, "kind": "phase6_actual_gpu_presentation", "checkOnly": args.check,
               "sourceUnchanged": False, "personalSavesUsed": False, "unityRuntimeExecuted": False,
               "token": token, "project": str(project)}
    succeeded = False
    evidence_created = False
    try:
        for path in [args.output_dir, args.evidence_dir]:
            no_symlink(path)
        if args.evidence_dir.resolve().is_relative_to(ROOT.resolve()):
            raise ValueError("Evidence must be outside the source project")
        if args.evidence_dir.exists() or (args.output_dir.exists() and not args.check):
            raise ValueError("Evidence/output must be new; use --check for an existing reference")
        args.evidence_dir.mkdir(parents=True)
        evidence_created = True
        engine = shutil.which(args.godot)
        if not engine:
            raise ValueError("Pinned Godot executable not found")
        engine = str(Path(engine).resolve())
        version = subprocess.run([engine, "--version"], capture_output=True, text=True, timeout=30)
        if version.returncode or version.stdout.strip() != ENGINE_VERSION:
            raise ValueError("Graphics export requires exact Godot " + ENGINE_VERSION)
        receipt["engineVersion"] = ENGINE_VERSION
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
        (project / "graphics_isolation_probe.gd").write_text(probe, encoding="utf-8")

        def run(label, arguments, gpu=False):
            startup = None
            if os.name == "nt":
                startup = subprocess.STARTUPINFO()
                startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startup.wShowWindow = 0
            mode = ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"] if gpu else ["--headless"]
            result = subprocess.run([engine, *mode, "--path", str(project), *arguments], cwd=project,
                                    capture_output=True, text=True, encoding="utf-8", errors="replace",
                                    timeout=1200, env=dict(os.environ, BLUEMAP_LANG="nl"), startupinfo=startup)
            log = result.stdout + result.stderr
            (args.evidence_dir / (label + ".log")).write_text(log, encoding="utf-8")
            if result.returncode or ERROR.search(log):
                raise RuntimeError(label + " failed:\n" + log[-12000:])
            return log

        run("import", ["--editor", "--import"])
        log = run("isolation", ["-s", "res://graphics_isolation_probe.gd"])
        match = re.search(r'^ISOLATED_USER_DIR=(.+)$', log, re.M)
        if not match or Path(match[1].strip()).name != token:
            raise ValueError("Graphics export storage isolation not verified")
        user_dir = Path(match[1].strip())
        receipt["isolatedUserDirectoryVerified"] = True
        receipts = []
        for number in (1, 2):
            directory = args.evidence_dir / ("export-" + str(number))
            log = run("export-" + str(number), ["-s", "res://tools/migration_graphics_export.gd", "--", "--output-dir", str(directory)], gpu=True)
            if "MIGRATION GRAPHICS EXPORT OK" not in log:
                raise ValueError("GPU export completion marker missing")
            receipts.append(normalize_graphics(directory, exporter_sources))
            print("GPU export", number, len(receipts[-1]), "documents", flush=True)
        if receipts[0] != receipts[1]:
            differences = [p for p in sorted(set(receipts[0]) | set(receipts[1])) if receipts[0].get(p) != receipts[1].get(p)]
            raise ValueError("Repeated GPU exports differ: " + ", ".join(differences))
        if source_fingerprint(ROOT) != before:
            raise ValueError("Original source/asset or exporter changed during GPU export")
        if args.check:
            expected = {}
            for path in args.output_dir.rglob("*"):
                no_symlink(path)
                if path.is_file():
                    data = path.read_bytes()
                    if path.suffix == ".json":
                        data = data.replace(b"\r\n", b"\n")
                    expected[path.relative_to(args.output_dir).as_posix()] = hashlib.sha256(data).hexdigest()
            if expected != receipts[0]:
                raise ValueError("GPU export differs from the complete recorded reference")
        else:
            shutil.copytree(args.evidence_dir / "export-1", args.output_dir)
        index = json_read(args.evidence_dir / "export-1/index.json")
        receipt.update(success=True, sourceUnchanged=True, repeatableEngineRuns=2, documents=receipts[0],
                       textures=len(index["textures"]), sprites=len(index["sprites"]), animations=len(index["animations"]),
                       exporterSources={path: before[path] for path in EXPORTERS})
        succeeded = True
        print("MIGRATION GRAPHICS CHECK OK" if args.check else "MIGRATION GRAPHICS RECORDED OK", flush=True)
        return 0
    except (OSError, ValueError, subprocess.SubprocessError, RuntimeError) as error:
        receipt.update(success=False, error=str(error))
        print("MIGRATION GRAPHICS FAILED:", error, file=sys.stderr)
        return 1
    finally:
        receipt["sourceUnchanged"] = source_fingerprint(ROOT) == before
        if evidence_created:
            (args.evidence_dir / "verification.json").write_bytes(canonical_bytes(receipt))
        if user_dir is not None and user_dir.name == token and user_dir.exists():
            shutil.rmtree(user_dir)
        if succeeded and not args.keep:
            shutil.rmtree(project)
        print("Graphics project/evidence:", task, args.evidence_dir, flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
