#!/usr/bin/env python3
"""Create and verify the explicitly identified phase 3 Windows technical preview.

This stdlib-only check never starts or extracts a player. Checksums establish
integrity against a trusted receipt and source commit; they are not signatures.
No Godot save, Unity activation file, or raw build log belongs in a download.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import stat
import struct
import sys
import unicodedata
import zipfile
import zlib


EDITOR_VERSION = "6000.3.26f1"
EDITOR_REVISION = "de8167e7440c"
PREVIEW_VERSION = "0.1.0-phase3"  # Historical downloads remain verifiable.
PREVIEW_VERSIONS = {3: PREVIEW_VERSION, 6: "0.2.0-phase6"}
MAX_FILES = 10000
MAX_FILE_BYTES = 512 * 1024 * 1024
MAX_TOTAL_BYTES = 1024 * 1024 * 1024
IDENTITY_FIELDS = {
    "schemaVersion", "phase", "previewVersion", "sourceCommit", "inputFingerprint",
    "editorVersion", "editorRevision", "target",
}
RUNTIME_FIELDS = {
    "identity", "success", "editorVersion", "graphicsDeviceType", "frames", "width",
    "height", "companyName", "productName", "captureMode", "gameSaveAccessed", "checks",
}
BASE_CHECKS = {
    "pinned_editor_version", "separate_test_identity", "release_player",
    "graphics_device_active", "orthographic_camera", "native_32px_tiles",
    "physics2d_query", "player_loop_60_frames", "startup_splash_finished",
    "window_1152x648", "rendered_image_available", "rendered_scene_palette",
    "rendered_grass_water_actor", "no_runtime_exceptions",
    "embedded_identity_consistent", "preview_version",
}
PRESENTATION_CHECKS = {
    "original_catalog_available", "native_source_pixels_exact", "native_animation_clips_available",
    "native_audio_available", "original_localization_exact", "original_font_available",
    "ninety_original_hair_styles", "twenty_four_original_clothing",
    "original_audio_playback_started", "gpu_original_pixels_exact", "animated_source_frames_change",
    "supplementary_source_glyphs_rendered",
    "native_animation_boundaries_exact",
}
REQUIRED_FILES = {
    "BlueMapUnityProbe.exe", "UnityPlayer.dll", "UnityCrashHandler64.exe",
    "MonoBleedingEdge/EmbedRuntime/mono-2.0-bdwgc.dll",
    "MonoBleedingEdge/EmbedRuntime/MonoPosixHelper.dll",
    "BlueMapUnityProbe_Data/Managed/Assembly-CSharp.dll",
    "BlueMapUnityProbe_Data/Managed/mscorlib.dll", "BlueMapUnityProbe_Data/app.info",
    "BlueMapUnityProbe_Data/boot.config", "BlueMapUnityProbe_Data/globalgamemanagers",
    "BlueMapUnityProbe_Data/level0", "BUILD-IDENTITY.json", "RUNTIME-CHECKS.json",
    "LEESMIJ.txt", "FILES.json",
}
PE_FILES = {
    "BlueMapUnityProbe.exe", "UnityPlayer.dll", "UnityCrashHandler64.exe",
    "MonoBleedingEdge/EmbedRuntime/mono-2.0-bdwgc.dll",
    "MonoBleedingEdge/EmbedRuntime/MonoPosixHelper.dll",
}
PLAYER_ROOTS = {
    "BlueMapUnityProbe.exe", "UnityPlayer.dll", "UnityCrashHandler64.exe",
    "MonoBleedingEdge", "BlueMapUnityProbe_Data", "D3D12",
}
METADATA_FILES = {"BUILD-IDENTITY.json", "RUNTIME-CHECKS.json", "FILES.json", "LEESMIJ.txt"}
PRIVATE_SUFFIXES = {".log", ".dmp", ".ulf", ".lic", ".license", ".pfx", ".p12", ".pem", ".key"}
GAME_SAVE_NAMES = {"savegame.cfg", "savegame.json", "meta.cfg", "ng_plus.cfg",
                   "controls.cfg", "settings.cfg"}
WINDOWS_RESERVED = {"CON", "PRN", "AUX", "NUL"} | {
    f"{prefix}{number}" for prefix in ("COM", "LPT") for number in range(1, 10)
}


class PackageError(RuntimeError):
    """A package, identity, runtime proof, or trusted receipt is invalid."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise PackageError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    value = {}
    for key, item in pairs:
        require(key not in value, "JSON contains a duplicate key")
        value[key] = item
    return value


def _json(raw: bytes, label: str) -> dict:
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_object)
    except (ValueError, UnicodeError) as error:
        raise PackageError(f"Invalid JSON: {label}") from error
    require(isinstance(value, dict), f"Expected JSON object: {label}")
    return value


def _json_bytes(value: dict) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def validate_identity(identity: dict) -> None:
    require(isinstance(identity, dict) and set(identity) == IDENTITY_FIELDS,
            "Build identity has missing or unexpected fields")
    require(type(identity["schemaVersion"]) is int and identity["schemaVersion"] == 1,
            "Unsupported build identity schema")
    require(type(identity["phase"]) is int and identity["phase"] in PREVIEW_VERSIONS,
            "This verifier requires an explicitly supported technical preview phase")
    require(identity["previewVersion"] == PREVIEW_VERSIONS[identity["phase"]], "Wrong technical preview version")
    require(isinstance(identity["sourceCommit"], str) and
            re.fullmatch(r"[0-9a-f]{40}", identity["sourceCommit"]) is not None and
            identity["sourceCommit"] != "0" * 40,
            "Build sourceCommit must be a full lowercase Git commit")
    require(isinstance(identity["inputFingerprint"], str) and
            re.fullmatch(r"[0-9a-f]{64}", identity["inputFingerprint"]) is not None and
            identity["inputFingerprint"] != "0" * 64,
            "Build inputFingerprint must be a full lowercase SHA256")
    require(identity["editorVersion"] == EDITOR_VERSION and
            identity["editorRevision"] == EDITOR_REVISION,
            "Build identity does not use the pinned Unity Editor")
    require(identity["target"] == "StandaloneWindows64", "Wrong preview target")


def archive_root(identity: dict) -> str:
    validate_identity(identity)
    return f"BlueMapUnityPreview-phase-{identity['phase']:02d}-" + identity["sourceCommit"][:8]


def package_filename(identity: dict) -> str:
    return archive_root(identity) + "-Windows-x64.zip"


def _safe_path(name: str) -> str:
    require(isinstance(name, str) and bool(name) and len(name) <= 1024,
            "Package member path is empty or too long")
    require(not any(ord(char) < 32 or ord(char) == 127 or char in '\\:<>"|?*' for char in name),
            "Package member has unsafe Windows path characters")
    parts = name.split("/")
    require(all(part and part not in {".", ".."} and not part.endswith((" ", "."))
                for part in parts), "Package member path is not relative and normalized")
    require(all(part.split(".")[0].upper() not in WINDOWS_RESERVED for part in parts),
            "Package member uses a reserved Windows filename")
    return unicodedata.normalize("NFC", name).casefold()


def _public_path(relative: str) -> None:
    _safe_path(relative)
    parts = relative.split("/")
    require(parts[0] in PLAYER_ROOTS or relative in METADATA_FILES,
            "Unexpected file outside the technical player's allowed runtime roots")
    require(Path(relative).suffix.lower() not in PRIVATE_SUFFIXES,
            "Private log, dump, credential or activation file is not allowed")
    require(parts[-1].casefold() not in GAME_SAVE_NAMES, "Existing game save/config file is not allowed")
    require(not any(part.casefold() in {"private-logs", "logs", "licenses", "license",
                                        "library", "temp", "usersettings"} or
                    part.casefold().startswith("unitylicense") for part in parts),
            "Private build or licensing directory is not allowed")


def _validate_checks(checks: object) -> list[dict]:
    require(isinstance(checks, list) and len(checks) >= len(BASE_CHECKS),
            "Runtime proof does not include the full probe checks")
    names = set()
    for check in checks:
        require(isinstance(check, dict) and set(check) == {"name", "passed"},
                "Malformed runtime check")
        name = check["name"]
        require(isinstance(name, str) and re.fullmatch(r"[a-z0-9_]{1,80}", name) is not None,
                "Invalid runtime check name")
        require(name not in names and check["passed"] is True,
                "Runtime checks contain a duplicate or a failed check")
        names.add(name)
    require(BASE_CHECKS <= names, "A required rendered-player check is missing")
    return checks


def _validate_runtime(result: dict, identity: dict) -> None:
    require(isinstance(result, dict) and set(result) == RUNTIME_FIELDS,
            "Runtime report has missing or unexpected fields")
    require(result["identity"] == identity, "Runtime embedded identity differs from package identity")
    require(result["success"] is True and result["gameSaveAccessed"] is False,
            "Runtime proof failed or accessed existing game saves")
    require(result["editorVersion"] == EDITOR_VERSION and
            result["companyName"] == "BlueMapMigrationTests" and
            result["productName"] == "BlueMapUnityProbe", "Wrong isolated-player runtime identity")
    require(result["captureMode"] == "Camera.Render to GPU RenderTexture; window overlay excluded",
            "Runtime proof did not use the verified camera capture")
    require(type(result["frames"]) is int and result["frames"] >= 60,
            "Runtime did not render enough frames")
    require(type(result["width"]) is int and type(result["height"]) is int and
            (result["width"], result["height"]) == (1152, 648), "Runtime image has the wrong dimensions")
    require(result["graphicsDeviceType"] in {"Direct3D11"},
            "Runtime did not use the pinned real graphics device")
    _validate_checks(result["checks"])
    if identity["phase"] == 6:
        require(PRESENTATION_CHECKS <= {check["name"] for check in result["checks"]},
                "Phase 6 presentation proof is incomplete")


def _validate_pe(raw: bytes, name: str) -> None:
    require(len(raw) >= 64 and raw[:2] == b"MZ", f"Runtime binary is not PE: {name}")
    offset = struct.unpack_from("<I", raw, 0x3C)[0]
    require(64 <= offset <= 1024 * 1024 and offset + 26 <= len(raw),
            f"Runtime binary has an invalid PE offset: {name}")
    require(raw[offset:offset + 4] == b"PE\0\0" and
            struct.unpack_from("<H", raw, offset + 4)[0] == 0x8664 and
            struct.unpack_from("<H", raw, offset + 24)[0] == 0x20B,
            f"Runtime binary is not Windows x64 PE32+: {name}")


def _instructions(identity: dict) -> bytes:
    return (
        "BLUEMAP QUEST - UNITY TECHNISCHE PREVIEW\n\n" +
        ("Migratiefase 3: deze kleine controlebuild is nog niet de overgezette game.\n" if identity["phase"] == 3 else
         "Migratiefase 6: originele beelden, animaties, audio en teksten; nog niet de overgezette game.\n") +
        "De bestaande Godot-game en het herstelpunt blijven apart beschikbaar.\n\n"
        "Pak de volledige map uit en start BlueMapUnityProbe.exe.\n"
        "Laat alle bijbehorende bestanden en de BlueMapUnityProbe_Data-map staan.\n"
        + ("WASD / pijlen: verplaatsen; Esc: sluiten.\n" if identity["phase"] == 3 else
           "1-6: galerijpagina; M: muziek; N: muziek stoppen; Spatie: geluid; Esc: sluiten.\n") +
        "Deze proef gebruikt geen opslagbestanden van de bestaande game.\n\n"
        f"Preview: {identity['previewVersion']}\nBroncommit: {identity['sourceCommit']}\n"
        f"Bronvingerafdruk: {identity['inputFingerprint']}\n"
        f"Unity {EDITOR_VERSION} ({EDITOR_REVISION}), Windows x64 / Mono.\n"
        "BUILD-IDENTITY.json en RUNTIME-CHECKS.json beschrijven deze controlebuild.\n"
        "FILES.json bevat de bestanden, groottes en SHA256-controlesommen.\n"
    ).encode("utf-8")


def package_player(player: Path, output: Path, identity: dict,
                   runtime_result: dict) -> tuple[Path, int]:
    """Package only the verified runtime payload; never include surrounding logs."""
    validate_identity(identity)
    _validate_runtime(runtime_result, identity)
    player, output = Path(player), Path(output)
    require(player.is_dir() and not player.is_symlink(), "Player directory is missing or a symlink")
    require(output.is_dir(), "Package output directory must already exist")
    require(not output.resolve().is_relative_to(player.resolve()),
            "Package output cannot be inside the player directory")
    package = output / package_filename(identity)
    require(not package.exists(), "Package already exists; previous results are never replaced")
    payload = {
        "LEESMIJ.txt": _instructions(identity), "BUILD-IDENTITY.json": _json_bytes(identity),
        "RUNTIME-CHECKS.json": _json_bytes(runtime_result),
    }
    seen = {_safe_path(name) for name in payload}
    total = sum(map(len, payload.values()))
    for path in sorted(player.rglob("*")):
        require(not path.is_symlink(), "Player output contains a symbolic link")
        if not path.is_file():
            continue
        relative = path.relative_to(player).as_posix()
        _public_path(relative)
        key = _safe_path(relative)
        require(key not in seen, "Player contains a duplicate or reserved package metadata file")
        seen.add(key)
        size = path.stat().st_size
        require(0 < size <= MAX_FILE_BYTES, "Runtime file is empty or exceeds the package limit")
        total += size
        require(total <= MAX_TOTAL_BYTES and len(payload) + 2 <= MAX_FILES,
                "Runtime payload exceeds the package limits")
        payload[relative] = path.read_bytes()
    manifest = {name: {"sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
                for name, data in sorted(payload.items())}
    payload["FILES.json"] = _json_bytes(manifest)
    require(REQUIRED_FILES <= set(payload), "Player output is missing required Windows runtime files")
    for name in PE_FILES:
        _validate_pe(payload[name], name)
    try:
        app_info = payload["BlueMapUnityProbe_Data/app.info"].decode("utf-8-sig").splitlines()
    except UnicodeError as error:
        raise PackageError("Player app.info is invalid UTF-8") from error
    require(app_info == ["BlueMapMigrationTests", "BlueMapUnityProbe"],
            "Player app.info has the wrong identity")
    with zipfile.ZipFile(package, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo(archive_root(identity) + "/" + name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    return package, len(payload)


def verify_package(path: Path, receipt: dict, expected_source_commit: str | None = None) -> dict:
    """Verify an archive against a trusted public receipt without extracting it."""
    path = Path(path)
    require(path.is_file() and not path.is_symlink(), "Package is missing or a symbolic link")
    require(isinstance(receipt, dict), "Expected a receipt JSON object")
    identity = receipt.get("identity")
    validate_identity(identity)
    if expected_source_commit is not None:
        require(re.fullmatch(r"[0-9a-f]{40}", expected_source_commit) is not None and
                identity["sourceCommit"] == expected_source_commit,
                "Package source does not match the expected Git commit")
    package = receipt.get("package")
    require(isinstance(package, dict) and {"file", "sha256", "bytes", "files"} <= set(package),
            "Receipt package metadata is incomplete")
    require(path.name == package_filename(identity) == package["file"],
            "Package filename does not identify the expected phase and source")
    require(type(package["bytes"]) is int and 0 < package["bytes"] <= MAX_TOTAL_BYTES and
            path.stat().st_size == package["bytes"], "Package size differs from trusted receipt")
    require(isinstance(package["sha256"], str) and
            re.fullmatch(r"[0-9a-f]{64}", package["sha256"]) is not None and
            sha256(path) == package["sha256"], "Package checksum differs from trusted receipt")
    require(type(package["files"]) is int and 0 < package["files"] <= MAX_FILES,
            "Receipt package file count is invalid")
    root = archive_root(identity)
    payload = {}
    try:
        with zipfile.ZipFile(path) as archive:
            members = archive.infolist()
            require(not archive.comment and 0 < len(members) == package["files"] <= MAX_FILES,
                    "ZIP comment, member count or trusted file count is invalid")
            total, seen = 0, set()
            for info in members:
                require(info.orig_filename == info.filename, "ZIP member contains a truncated NUL path")
                key = _safe_path(info.filename)
                require(key not in seen, "ZIP contains duplicate Windows member paths")
                seen.add(key)
                require(info.filename.startswith(root + "/"), "ZIP has an unexpected archive root")
                relative = info.filename[len(root) + 1:]
                _public_path(relative)
                mode = info.external_attr >> 16
                require(not info.is_dir() and stat.S_IFMT(mode) in {0, stat.S_IFREG},
                        "ZIP member is a directory, symlink or other special file")
                require(not (info.flag_bits & 1) and not info.comment,
                        "Encrypted or commented ZIP members are not allowed")
                require(info.compress_type in {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED},
                        "ZIP uses an unsupported compression method")
                require(0 < info.file_size <= MAX_FILE_BYTES,
                        "ZIP member is empty or exceeds its size limit")
                total += info.file_size
                require(total <= MAX_TOTAL_BYTES, "ZIP exceeds the uncompressed size limit")
                require(info.file_size <= max(1024 * 1024, info.compress_size * 1000),
                        "ZIP member exceeds the decompression ratio limit")
            # Read only after checking every member path and declared size. ZipFile
            # checks each local header and CRC as well; nothing is extracted.
            for info in members:
                payload[info.filename[len(root) + 1:]] = archive.read(info)
    except (zipfile.BadZipFile, RuntimeError, NotImplementedError, EOFError, zlib.error) as error:
        raise PackageError("ZIP structure, local header or CRC validation failed") from error
    require(REQUIRED_FILES <= set(payload), "ZIP is missing required runtime files")
    manifest = _json(payload["FILES.json"], "FILES.json")
    require(set(manifest) == set(payload) - {"FILES.json"},
            "Package manifest contains missing, extra or self-referential paths")
    for name, proof in manifest.items():
        _public_path(name)
        require(isinstance(proof, dict) and set(proof) == {"sha256", "bytes"},
                "Invalid package file manifest entry")
        require(type(proof["bytes"]) is int and proof["bytes"] == len(payload[name]) and
                isinstance(proof["sha256"], str) and
                re.fullmatch(r"[0-9a-f]{64}", proof["sha256"]) is not None and
                proof["sha256"] == hashlib.sha256(payload[name]).hexdigest(),
                f"File differs from package manifest: {name}")
    embedded = _json(payload["BUILD-IDENTITY.json"], "BUILD-IDENTITY.json")
    validate_identity(embedded)
    require(embedded == identity, "Package identity differs from trusted receipt")
    runtime = _json(payload["RUNTIME-CHECKS.json"], "RUNTIME-CHECKS.json")
    _validate_runtime(runtime, identity)
    require(receipt.get("success") is True and receipt.get("rawLogsPublished") is False and
            receipt.get("godotSavesUsed") is False, "Receipt failed isolation/privacy checks")
    require(receipt.get("checks") == runtime["checks"], "Receipt runtime checks do not match package")
    for field in ("frames", "graphicsDeviceType", "captureMode", "editorVersion"):
        if field in receipt:
            require(receipt[field] == runtime[field], f"Receipt {field} differs from runtime proof")
    if "phase" in receipt:
        require(type(receipt["phase"]) is int and receipt["phase"] == identity["phase"],
                "Receipt phase differs from embedded identity")
    for name in PE_FILES:
        _validate_pe(payload[name], name)
    try:
        app_info = payload["BlueMapUnityProbe_Data/app.info"].decode("utf-8-sig").splitlines()
    except UnicodeError as error:
        raise PackageError("Player app.info is invalid UTF-8") from error
    require(app_info == ["BlueMapMigrationTests", "BlueMapUnityProbe"],
            "Packaged player app.info has the wrong isolated identity")
    require(payload["LEESMIJ.txt"] == _instructions(identity), "Package instructions differ from identity")
    return {
        "schemaVersion": 1, "success": True, "phase": identity["phase"], "identity": identity,
        "package": {"file": path.name, "sha256": package["sha256"], "bytes": path.stat().st_size,
                    "files": len(payload), "uncompressedBytes": total},
        "runtimeChecks": len(runtime["checks"]), "architecture": "Windows-x64-PE32+",
        "extracted": False, "rawLogsPublished": False, "godotSavesUsed": False,
        "trust": "Integrity against supplied receipt and expected source; checksums are not signatures",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True, type=Path)
    parser.add_argument("--receipt", required=True, type=Path)
    parser.add_argument("--expected-source-commit")
    parser.add_argument("--output", type=Path, help="Optional new JSON verification report")
    args = parser.parse_args()
    receipt = _json(args.receipt.read_bytes(), "receipt")
    report = verify_package(args.package, receipt, args.expected_source_commit)
    if args.output:
        require(not args.output.exists(), "Verification output already exists")
        args.output.write_bytes(_json_bytes(report))
    print(f"UNITY PACKAGE OK: {report['package']['files']} files, "
          f"{report['runtimeChecks']} rendered-player checks; source {report['identity']['sourceCommit']}")


if __name__ == "__main__":
    try:
        main()
    except (PackageError, OSError) as error:
        print(f"UNITY PACKAGE FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
