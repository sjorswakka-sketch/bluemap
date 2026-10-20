#!/usr/bin/env python3
"""Build, run, and package the identified Unity migration technical preview.

Requires the already licensed, pinned Windows Editor; it never installs or
activates Unity. Raw Editor/player logs remain in the external output folder.
"""

from __future__ import annotations

import argparse
import ctypes
from contextlib import contextmanager
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
import zlib


ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "unity"
EXPECTED_VERSION = "6000.3.26f1"
EXPECTED_REVISION = "de8167e7440c"
TARGET = "StandaloneWindows64"
EXE_NAME = "BlueMapUnityProbe.exe"
PREVIEW_VERSION = "0.4.0-phase8"
PHASE = 8

from verify_unity_package import (PackageError, package_player, validate_identity, verify_package,
                                  validate_foundation, FOUNDATION_CHECKS, validate_player, PLAYER_CHECKS)


class ProbeError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ProbeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path: Path) -> dict:
    require(path.is_file(), f"Required report is missing: {path.name}")
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (ValueError, UnicodeError) as error:
        raise ProbeError(f"Invalid JSON in {path.name}") from error
    require(isinstance(value, dict), f"Expected a JSON object in {path.name}")
    return value


def editor_product_version(editor: Path) -> str:
    """Read a Windows version resource without running the executable."""
    from ctypes import wintypes

    version = ctypes.WinDLL("version", use_last_error=True)
    size_fn = version.GetFileVersionInfoSizeW
    size_fn.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(wintypes.DWORD)]
    size_fn.restype = wintypes.DWORD
    info_fn = version.GetFileVersionInfoW
    info_fn.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p]
    info_fn.restype = wintypes.BOOL
    query_fn = version.VerQueryValueW
    query_fn.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR,
                        ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(wintypes.UINT)]
    query_fn.restype = wintypes.BOOL
    unused = wintypes.DWORD()
    size = size_fn(str(editor), ctypes.byref(unused))
    require(size > 0, "Unity executable has no readable Windows version resource")
    data = ctypes.create_string_buffer(size)
    require(bool(info_fn(str(editor), 0, size, data)), "Cannot read Editor version metadata")
    pointer = ctypes.c_void_p()
    length = wintypes.UINT()
    require(bool(query_fn(data, "\\VarFileInfo\\Translation", ctypes.byref(pointer),
                          ctypes.byref(length))) and length.value >= 4,
            "Editor version resource has no language table")
    translations = ctypes.string_at(pointer.value, length.value)
    for language, codepage in struct.iter_unpack("<HH", translations):
        key = f"\\StringFileInfo\\{language:04x}{codepage:04x}\\ProductVersion"
        if query_fn(data, key, ctypes.byref(pointer), ctypes.byref(length)):
            value = ctypes.wstring_at(pointer.value, length.value).rstrip("\0")
            if value:
                return value
    raise ProbeError("Editor version resource has no ProductVersion")


def check_editor(editor: Path) -> str:
    require(os.name == "nt", "This Windows player probe must run on Windows")
    require(editor.is_file() and editor.name.lower() == "unity.exe",
            "--editor must identify an existing Unity.exe")
    project_version = PROJECT / "ProjectSettings" / "ProjectVersion.txt"
    require(project_version.is_file(), "Pinned Unity ProjectVersion.txt is missing")
    content = project_version.read_text(encoding="utf-8-sig")
    require(re.search(r"^m_EditorVersion: " + re.escape(EXPECTED_VERSION) + r"\s*$",
                      content, re.M) is not None, "Project Editor version differs from the phase 2 pin")
    require(f"m_EditorVersionWithRevision: {EXPECTED_VERSION} ({EXPECTED_REVISION})" in content,
            "Project Editor revision differs from the phase 2 pin")
    product_version = editor_product_version(editor)
    require(product_version == f"{EXPECTED_VERSION}_{EXPECTED_REVISION}",
            f"Editor metadata differs from the required {EXPECTED_VERSION} ({EXPECTED_REVISION})")
    playback = editor.parent / "Data" / "PlaybackEngines" / "windowsstandalonesupport"
    release = playback / "Variations" / "win64_player_nondevelopment_mono"
    require((release / "WindowsPlayer.exe").is_file() and (release / "UnityPlayer.dll").is_file(),
            "Pinned Editor is missing Windows x64 Mono player support")
    return product_version


def run_hidden(command: list[str], timeout: int, label: str, *, rendered_player_window: bool = False) -> None:
    # Camera.Render works in a hidden window, but the player's own OnGUI
    # backbuffer needs a presented window for ScreenCapture. Show only our
    # isolated player, without activating it or capturing any desktop surface.
    require(not rendered_player_window or (bool(command) and Path(command[0]).name == EXE_NAME),
            "Only the isolated preview player may use a rendered test window")
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 7 if rendered_player_window else 0  # SW_SHOWNOACTIVATE / SW_HIDE.
    try:
        result = subprocess.run(command, cwd=ROOT, stdin=subprocess.DEVNULL,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                timeout=timeout, startupinfo=startup,
                                creationflags=subprocess.CREATE_NO_WINDOW, check=False)
    except subprocess.TimeoutExpired as error:
        raise ProbeError(f"{label} exceeded its {timeout}s limit; inspect private logs") from error
    require(result.returncode == 0,
            f"{label} failed with exit code {result.returncode}; inspect private logs")


def validate_pe(path: Path) -> None:
    require(path.is_file(), "Built player executable is missing")
    with path.open("rb") as stream:
        header = stream.read(64)
        require(len(header) == 64 and header[:2] == b"MZ", "Player has no DOS executable header")
        offset = struct.unpack_from("<I", header, 0x3C)[0]
        require(64 <= offset <= 1024 * 1024, "Player PE header offset is invalid")
        stream.seek(offset)
        pe = stream.read(26)
    require(len(pe) == 26 and pe[:4] == b"PE\0\0", "Player has no PE executable header")
    require(struct.unpack_from("<H", pe, 4)[0] == 0x8664, "Expected Windows x64 player")
    require(struct.unpack_from("<H", pe, 24)[0] == 0x20B, "Expected PE32+ player")


def validate_png(path: Path) -> dict:
    require(path.is_file(), "Runtime screenshot is missing")
    raw = path.read_bytes()
    require(raw[:8] == b"\x89PNG\r\n\x1a\n", "Runtime screenshot is not PNG")
    offset, chunks, idat = 8, [], bytearray()
    width = height = channels = 0
    while offset < len(raw):
        require(offset + 12 <= len(raw), "Truncated screenshot PNG")
        size = struct.unpack_from(">I", raw, offset)[0]
        kind = raw[offset + 4:offset + 8]
        end = offset + size + 12
        require(end <= len(raw), "Truncated screenshot PNG chunk")
        payload = raw[offset + 8:offset + 8 + size]
        crc = struct.unpack_from(">I", raw, offset + 8 + size)[0]
        require(zlib.crc32(kind + payload) & 0xFFFFFFFF == crc, "Screenshot PNG checksum failed")
        chunks.append(kind)
        if kind == b"IHDR":
            require(size == 13 and len(chunks) == 1, "Invalid screenshot PNG header")
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            require((width, height) == (1152, 648), "Screenshot dimensions must be 1152x648")
            require(depth == 8 and color in (2, 6) and compression == filtering == interlace == 0,
                    "Expected a noninterlaced RGB/RGBA screenshot PNG")
            channels = 3 if color == 2 else 4
        elif kind == b"IDAT":
            idat.extend(payload)
        elif kind == b"IEND":
            require(size == 0 and end == len(raw), "Invalid PNG ending")
            break
        offset = end
    require(chunks and chunks[-1] == b"IEND" and channels > 0 and idat,
            "Screenshot PNG is incomplete")
    stride = width * channels
    expected_bytes = height * (stride + 1)
    inflater = zlib.decompressobj()
    try:
        pixels = inflater.decompress(bytes(idat), expected_bytes + 1)
    except zlib.error as error:
        raise ProbeError("Screenshot PNG pixel data is invalid") from error
    require(inflater.eof and not inflater.unused_data and len(pixels) == expected_bytes,
            "Screenshot PNG pixel length is invalid")
    previous = bytearray(stride)
    first_rgb = None
    distinct = False
    for row in range(height):
        row_start = row * (stride + 1)
        filter_kind = pixels[row_start]
        require(0 <= filter_kind <= 4, "Screenshot PNG uses an invalid row filter")
        decoded = bytearray(pixels[row_start + 1:row_start + 1 + stride])
        for index in range(stride):
            left = decoded[index - channels] if index >= channels else 0
            above = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_kind == 1:
                predictor = left
            elif filter_kind == 2:
                predictor = above
            elif filter_kind == 3:
                predictor = (left + above) // 2
            elif filter_kind == 4:
                estimate = left + above - upper_left
                distances = (abs(estimate - left), abs(estimate - above), abs(estimate - upper_left))
                predictor = (left, above, upper_left)[distances.index(min(distances))]
            else:
                predictor = 0
            decoded[index] = (decoded[index] + predictor) & 0xFF
        for index in range(0, stride, channels):
            rgb = bytes(decoded[index:index + 3])
            if first_rgb is None:
                first_rgb = rgb
            elif rgb != first_rgb:
                distinct = True
        previous = decoded
    require(distinct, "Runtime screenshot is a flat single-color image")
    return {"width": width, "height": height, "nonFlat": True, "sha256": sha256(path)}


def read_git_blobs(root: Path, object_ids: list[str]) -> dict[str, bytes]:
    """One bounded Git batch, retaining exact blob bytes and object identities."""
    require(all(re.fullmatch(r"[0-9a-f]{40}", value) for value in object_ids), "Invalid Git blob identity")
    if not object_ids:
        return {}
    raw = subprocess.check_output(["git", "cat-file", "--batch"], cwd=root,
                                  input=("\n".join(object_ids) + "\n").encode("ascii"))
    result, offset = {}, 0
    for wanted in object_ids:
        end = raw.find(b"\n", offset)
        require(end >= offset, "Truncated Git batch header")
        header = raw[offset:end].split()
        require(len(header) == 3 and header[0] == wanted.encode() and header[1] == b"blob" and
                header[2].isdigit(), "Git batch returned a different object")
        size = int(header[2])
        require(size <= 512 * 1024 * 1024 and end + size + 2 <= len(raw), "Invalid Git blob size")
        data = raw[end + 1:end + 1 + size]
        require(raw[end + 1 + size:end + 2 + size] == b"\n", "Git blob boundary is invalid")
        require(hashlib.sha1(b"blob " + str(size).encode() + b"\0" + data).hexdigest() == wanted,
                "Git blob identity does not match its bytes")
        result[wanted] = data
        offset = end + 2 + size
    require(offset == len(raw), "Unexpected data after Git batch")
    return result


def _collect_build_input_data(root: Path = ROOT, commit: str | None = None) -> tuple[str, list[dict], str, dict[str, bytes]]:
    """Read exact committed build inputs, independent of checkout line endings."""
    def git(*arguments: str) -> bytes:
        return subprocess.check_output(["git", *arguments], cwd=root)
    source_commit = git("rev-parse", commit or "HEAD").decode().strip()
    require(re.fullmatch(r"[0-9a-f]{40}", source_commit) is not None, "Invalid source commit")
    prefixes = ("unity/Assets/", "unity/Packages/", "unity/ProjectSettings/")
    helpers = {"tools/build_unity_probe.py", "tools/verify_unity_package.py", "unity/.gdignore"}
    entries = []
    for row in git("ls-tree", "-rz", "--full-tree", source_commit).split(b"\0"):
        if not row:
            continue
        meta, raw_path = row.split(b"\t", 1)
        path = raw_path.decode("utf-8")
        if not (path.startswith(prefixes) or path in helpers):
            continue
        mode, kind, blob = meta.decode().split()
        require(kind == "blob" and mode == "100644", "Only ordinary source files are build inputs")
        require("/Resources/BuildIdentity.json" not in path, "Generated build identity must not be committed")
        entries.append((path, blob))
    require(helpers <= {path for path, _ in entries}, "Required committed build helpers are missing")
    inputs, canonical_files = [], {}
    blobs = read_git_blobs(root, [blob for _, blob in sorted(entries)])
    for path, blob in sorted(entries):
        data = blobs[blob]
        inputs.append({"path": path, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
        canonical_files[path] = data
    if commit is None:
        selected = [*prefixes, *sorted(helpers)]
        status = subprocess.run(["git", "diff", "--quiet", "HEAD", "--", *selected], cwd=root)
        require(status.returncode == 0, "Commit all build inputs before building a traceable preview")
        untracked = git("ls-files", "--others", "--exclude-standard", "-z", "--", *selected)
        require(not untracked, "Untracked build inputs must be committed before the preview")
    payload = json.dumps(inputs, sort_keys=True, separators=(",", ":")).encode("utf-8")
    fingerprint = hashlib.sha256(payload).hexdigest()
    return source_commit, inputs, fingerprint, canonical_files


def collect_build_inputs(root: Path = ROOT, commit: str | None = None) -> tuple[str, list[dict], str]:
    source_commit, inputs, fingerprint, _ = _collect_build_input_data(root, commit)
    return source_commit, inputs, fingerprint


def validate_unity_packages(packages: object, lock_bytes: bytes) -> None:
    """Bind actual resolved package identities to the committed package lock."""
    try:
        lock = json.loads(lock_bytes.decode("utf-8-sig"))
    except (ValueError, UnicodeError) as error:
        raise ProbeError("Invalid committed Unity package lock") from error
    require(isinstance(lock, dict) and isinstance(lock.get("dependencies"), dict),
            "Committed Unity package lock is missing its dependencies")
    require(all(isinstance(name, str) and isinstance(value, dict) and
                isinstance(value.get("version"), str) and isinstance(value.get("source"), str)
                for name, value in lock["dependencies"].items()), "Malformed committed Unity package lock")
    expected = {name: {"name": name, "version": value["version"], "source": value["source"]}
                for name, value in lock["dependencies"].items()}
    require("com.unity.inputsystem" in expected, "Phase 8 requires the pinned native Input System package")
    require(isinstance(packages, list) and bool(packages), "Resolved Unity packages are missing")
    observed = {}
    for row in packages:
        require(isinstance(row, dict) and set(row) == {"name", "version", "source"},
                "Malformed resolved Unity package")
        require(isinstance(row["name"], str) and row["name"] not in observed,
                "Duplicate or malformed resolved Unity package name")
        observed[row["name"]] = row
    require(observed == expected, "Resolved Unity packages differ from the committed package lock")


def validate_runtime_dll_inputs(rows: object, player: Path) -> None:
    """Hash the actual built DLL, not a possibly different Editor assembly."""
    require(isinstance(rows, list) and bool(rows), "Runtime DLL inputs are missing")
    seen = set()
    for row in rows:
        require(isinstance(row, dict) and set(row) == {"name", "bytes", "sha256"},
                "Malformed runtime DLL input")
        name = row["name"]
        require(isinstance(name, str) and re.fullmatch(r"[A-Za-z0-9_.-]+\.dll", name) is not None and name not in seen,
                "Unsafe or duplicate runtime DLL input name")
        seen.add(name)
        path = player / "BlueMapUnityProbe_Data" / "Managed" / name
        require(type(row["bytes"]) is int and row["bytes"] > 0 and path.is_file() and
                path.stat().st_size == row["bytes"] and isinstance(row["sha256"], str) and
                re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) is not None and sha256(path) == row["sha256"],
                "Runtime DLL differs from its native build report")
    require("Unity.InputSystem.dll" in seen, "Native Input System DLL source witness is missing")


@contextmanager
def disposable_build_directory():
    """Keep a failed isolated import for diagnosis; clean only our new cache."""
    parent = Path(tempfile.gettempdir()).resolve()
    path = Path(tempfile.mkdtemp(prefix="bluemap-unity-build-")).resolve()
    require(path.parent == parent and path.name.startswith("bluemap-unity-build-") and not path.is_symlink(),
            "Invalid disposable project location")
    try:
        yield str(path)
    except BaseException:
        print("Failed disposable project retained for diagnosis:", path, file=sys.stderr, flush=True)
        raise
    else:
        # Unity children may retain a cache lock briefly. Never weaken checks or
        # delete a different directory merely because cache cleanup is delayed.
        require(path.parent == parent and path.name.startswith("bluemap-unity-build-") and not path.is_symlink(),
                "Disposable project moved during the build")
        shutil.rmtree(path, ignore_errors=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--editor", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    editor, output = args.editor.resolve(), args.output.resolve()
    require(not output.is_relative_to(ROOT) and not ROOT.is_relative_to(output),
            "--output must be external to the repository and may not contain it")
    require(output != Path(output.anchor), "--output may not be a filesystem root")
    require(not output.exists() or (output.is_dir() and not any(output.iterdir())),
            "--output must be new or empty; previous results are never deleted")
    product_version = check_editor(editor)
    source_commit, inputs, fingerprint, canonical_files = _collect_build_input_data()
    identity = {"schemaVersion": 1, "phase": PHASE, "previewVersion": PREVIEW_VERSION,
                "sourceCommit": source_commit, "inputFingerprint": fingerprint,
                "editorVersion": EXPECTED_VERSION, "editorRevision": EXPECTED_REVISION, "target": TARGET}
    validate_identity(identity)
    output.mkdir(parents=True, exist_ok=True)
    logs, player, runtime = output / "private-logs", output / "player", output / "runtime"
    logs.mkdir()
    runtime.mkdir()
    identity_path = output / "identity.json"
    identity_path.write_text(json.dumps(identity, indent=2) + "\n", encoding="utf-8")
    (output / "build-inputs.json").write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
    print(f"Verified Unity {EXPECTED_VERSION}; building committed preview {source_commit[:8]}.", flush=True)
    # Import/build only a disposable project assembled from canonical Git bytes.
    # Generated Resources identity and Unity caches never touch the source checkout.
    # Unity's child processes can briefly retain the Windows working directory
    # after a successful export. Cache cleanup is best effort; it must not hide
    # build/player validation or turn an ordinary file lock into a failed build.
    with disposable_build_directory() as temporary:
        project = Path(temporary) / "project"
        for entry in inputs:
            if entry["path"].startswith("unity/"):
                path = project / entry["path"][len("unity/"):]
                path.parent.mkdir(parents=True, exist_ok=True)
                data = canonical_files[entry["path"]]
                require(hashlib.sha256(data).hexdigest() == entry["sha256"], "Build input changed")
                path.write_bytes(data)
        run_hidden([str(editor), "-batchmode", "-nographics", "-quit", "-projectPath", str(project),
                    "-buildTarget", TARGET, "-executeMethod", "BlueMapMigration.Editor.Phase2Build.BuildWindows",
                    "-logFile", str(logs / "editor.log"), "--probe-build-output", str(player),
                    "--probe-build-identity", str(identity_path)], 1800, "Unity preview build")
    report = read_json(output / "build-report.json")
    require(report.get("target") == TARGET and report.get("editorVersion") == EXPECTED_VERSION and
            report.get("editorRevision") == EXPECTED_REVISION, "Build report version/target mismatch")
    require(report.get("identity") == identity, "Build identity differs from committed inputs")
    require(report.get("buildResult") == "Succeeded" and type(report.get("totalErrors")) is int and
            report["totalErrors"] == 0, "Unity did not report an error-free build")
    require(type(report.get("totalWarnings")) is int and report["totalWarnings"] >= 0,
            "Invalid build warning count")
    validate_unity_packages(report.get("unityPackages"), canonical_files["unity/Packages/packages-lock.json"])
    validate_runtime_dll_inputs(report.get("runtimeDllInputs"), player)
    executable = player / EXE_NAME
    validate_pe(executable)
    require((player / "UnityPlayer.dll").is_file() and (player / "BlueMapUnityProbe_Data").is_dir(),
            "Required Unity runtime files are missing")
    print("Windows x64 build verified; running the rendered player.", flush=True)
    run_hidden([str(executable), "-screen-width", "1152", "-screen-height", "648",
                "-logFile", str(logs / "player.log"), "--probe-automated",
                "--probe-output-directory", str(runtime)], 180, "Isolated BlueMap player: native game UI proof",
               rendered_player_window=True)
    result = read_json(runtime / "result.json")
    require(result.get("success") is True and result.get("identity") == identity,
            "Runtime checks or embedded identity failed")
    require(result.get("editorVersion") == EXPECTED_VERSION and
            result.get("companyName") == "BlueMapMigrationTests" and
            result.get("productName") == "BlueMapUnityProbe" and result.get("gameSaveAccessed") is False,
            "Runtime identity is not the isolated technical preview")
    graphics = result.get("graphicsDeviceType")
    require(isinstance(graphics, str) and bool(graphics.strip()) and graphics.lower() not in {"null", "none"},
            "Runtime did not use a real graphics device")
    checks = result.get("checks")
    require(isinstance(checks, list) and bool(checks) and all(isinstance(c, dict) and
            isinstance(c.get("name"), str) and c["name"] and c.get("passed") is True for c in checks),
            "Runtime reported a failed or missing check")
    require(len({c["name"] for c in checks}) == len(checks), "Runtime check names are duplicated")
    require(FOUNDATION_CHECKS <= {c["name"] for c in checks},
            "Required foundation runtime check is missing")
    require(PLAYER_CHECKS <= {c["name"] for c in checks},
            "Required player runtime check is missing")
    require(type(result.get("frames")) is int and result["frames"] >= 60, "Runtime loop did not advance")
    require(result.get("captureMode") == "Camera.Render to GPU RenderTexture; window overlay excluded",
            "Unexpected runtime capture method")
    screenshot = validate_png(runtime / "screenshot.png")
    imported = read_json(output / "import-report.json")
    presentation = read_json(runtime / "presentation-result.json")
    require(imported.get("success") is True and imported.get("allNativePixelsExact") is True and
            imported.get("allNativeAudioExact") is True and imported.get("allNativeAnimationCurvesExact") is True and
            presentation.get("success") is True and presentation.get("supplementaryGlyphsRendered") is True and
            presentation.get("nativeBoundaryFramesExact") is True and presentation.get("nativeBoundaryFailures") == 0 and
            presentation.get("nativeBoundarySamples", 0) >= 18861 and
            presentation.get("premultipliedPixelsExact") is True and presentation.get("premultipliedTextureCount") == 9 and
            presentation.get("premultipliedComparedPixels", 0) > 0 and presentation.get("premultipliedMismatches") == 0 and
            presentation.get("premultipliedTintComparedPixels", 0) > 0 and presentation.get("premultipliedTintMismatches") == 0,
            "Original presentation import/runtime proof failed")
    captures = {}
    for name in ("screenshot-hair.png", "screenshot-clothing.png", "screenshot-equipment.png",
                 "screenshot-languages.png", "screenshot-pixels.png", "screenshot-animation.png",
                 "screenshot-premultiplied.png", "screenshot-foundation.png", "screenshot-foundation-cave.png",
                 "screenshot-player.png", "screenshot-player-roll.png", "screenshot-player-ui.png",
                 "screenshot-player-controls.png"):
        captures[name] = validate_png(runtime / name)
    foundation = read_json(runtime / "foundation-result.json")
    validate_foundation(foundation, identity)
    player_checks = read_json(runtime / "player-result.json")
    validate_player(player_checks, identity)
    require(collect_build_inputs()[2] == fingerprint, "Original build source changed during the build")
    package, file_count = package_player(player, output, identity, result, foundation, player_checks)
    receipt = {"schemaVersion": 2, "phase": PHASE, "success": True, "identity": identity,
               "editorVersion": EXPECTED_VERSION, "editorRevision": EXPECTED_REVISION,
               "editorProductVersion": product_version, "target": TARGET, "scriptingBackend": "Mono",
               "buildResult": report["buildResult"], "totalErrors": report["totalErrors"],
               "totalWarnings": report["totalWarnings"], "playerArchitecture": "x64",
               "graphicsDeviceType": graphics, "frames": result["frames"], "captureMode": result["captureMode"],
               "checks": checks, "screenshot": screenshot,
               "presentation": presentation, "import": imported, "captures": captures,
               "foundation": foundation,
               "player": player_checks,
               "unityPackages": report["unityPackages"], "runtimeDllInputs": report["runtimeDllInputs"],
               "package": {"file": package.name, "sha256": sha256(package), "bytes": package.stat().st_size,
                           "files": file_count}, "rawLogsPublished": False, "godotSavesUsed": False,
               "buildSourceUnchanged": True, "buildProjectWasDisposable": True,
               "temporaryCacheRemoved": not Path(temporary).exists()}
    verified = verify_package(package, receipt, source_commit)
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    (output / "package-verification.json").write_text(json.dumps(verified, indent=2) + "\n", encoding="utf-8")
    sums = "".join(f"{sha256(path)}  {path.relative_to(output).as_posix()}\n"
                   for path in (package, output / "receipt.json", runtime / "screenshot.png"))
    (output / "SHA256SUMS.txt").write_text(sums, encoding="utf-8")
    print(f"UNITY PREVIEW OK: {len(checks)} checks, {result['frames']} frames; source {source_commit[:8]}.", flush=True)
    print(f"Package: {package.name} ({package.stat().st_size} bytes), SHA256 {sha256(package)}", flush=True)
    print("Raw logs stay external; only verified package and public reports may be published.", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (ProbeError, PackageError, OSError, subprocess.SubprocessError) as error:
        print(f"UNITY PREVIEW FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
