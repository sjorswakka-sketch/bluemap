#!/usr/bin/env python3
"""Build, run, and package the isolated Unity phase 2 Windows probe.

Requires the already licensed, pinned Windows Editor; it never installs or
activates Unity. Raw Editor/player logs remain in the external output folder.
"""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import zipfile
import zlib


ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "unity"
EXPECTED_VERSION = "6000.3.26f1"
EXPECTED_REVISION = "de8167e7440c"
TARGET = "StandaloneWindows64"
EXE_NAME = "BlueMapUnityProbe.exe"
PACKAGE_NAME = "BlueMapUnityProbe-Windows-x64.zip"


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


def run_hidden(command: list[str], timeout: int, label: str) -> None:
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
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


def package_player(player: Path, output: Path) -> tuple[Path, int]:
    instructions = (
        "BLUEMAP QUEST - UNITY CONTROLEBUILD\n\n"
        "Dit is de technische controlebuild voor migratiefase 2.\n"
        "De bestaande Godot-game is apart behouden; dit is nog geen overgezette game.\n\n"
        "Pak de volledige map uit en start BlueMapUnityProbe.exe.\n"
        "Laat de bijbehorende bestanden en de BlueMapUnityProbe_Data-map staan.\n"
        "Deze controlebuild gebruikt geen opslagbestanden van de bestaande game.\n"
        "Sluit het venster om te stoppen.\n\n"
        f"Unity {EXPECTED_VERSION} ({EXPECTED_REVISION}), Windows x64 / Mono.\n"
    ).encode("utf-8")
    payload: dict[str, bytes] = {"LEESMIJ.txt": instructions}
    for path in sorted(player.rglob("*")):
        require(not path.is_symlink(), "Player output must not contain symbolic links")
        if path.is_file():
            require(path.suffix.lower() not in {".log", ".dmp"},
                    "Unexpected private log/crash dump inside the player folder")
            relative = path.relative_to(player).as_posix()
            require(relative not in payload, "Player output conflicts with package instructions")
            payload[relative] = path.read_bytes()
    sums = "".join(f"{hashlib.sha256(data).hexdigest()}  {name}\n"
                   for name, data in sorted(payload.items()))
    payload["SHA256SUMS.txt"] = sums.encode("utf-8")
    package = output / PACKAGE_NAME
    with zipfile.ZipFile(package, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo("BlueMapUnityProbe/" + name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    with zipfile.ZipFile(package) as archive:
        require(archive.testzip() is None, "Packaged player ZIP checksum validation failed")
        require(set(archive.namelist()) == {"BlueMapUnityProbe/" + name for name in payload},
                "Packaged player file list differs from verified output")
    return package, len(payload)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--editor", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    editor = args.editor.resolve()
    output = args.output.resolve()
    require(not output.is_relative_to(ROOT) and not ROOT.is_relative_to(output),
            "--output must be external to the repository and may not contain it")
    require(output != Path(output.anchor), "--output may not be a filesystem root")
    require(not output.exists() or (output.is_dir() and not any(output.iterdir())),
            "--output must be a new or empty directory; existing results are never deleted")
    product_version = check_editor(editor)
    output.mkdir(parents=True, exist_ok=True)
    logs = output / "private-logs"
    logs.mkdir()
    player = output / "player"
    runtime = output / "runtime"
    runtime.mkdir()
    print(f"Verified Unity {EXPECTED_VERSION} ({EXPECTED_REVISION}); building isolated Windows probe.", flush=True)
    run_hidden([str(editor), "-batchmode", "-nographics", "-quit", "-projectPath", str(PROJECT),
                "-buildTarget", TARGET, "-executeMethod", "BlueMapMigration.Editor.Phase2Build.BuildWindows",
                "-logFile", str(logs / "editor.log"), "--probe-build-output", str(player)],
               1800, "Unity probe build")
    report = read_json(output / "build-report.json")
    require(report.get("target") == TARGET, "Build report has the wrong target")
    require(report.get("editorVersion") == EXPECTED_VERSION, "Build report has the wrong Editor version")
    require(report.get("editorRevision") == EXPECTED_REVISION, "Build report has the wrong Editor revision")
    require(report.get("buildResult") == "Succeeded", "Unity did not report a successful build")
    require(type(report.get("totalErrors")) is int and report["totalErrors"] == 0,
            "Build report contains errors or lacks its error count")
    require(type(report.get("totalWarnings")) is int and report["totalWarnings"] >= 0,
            "Build report lacks a valid warning count")
    executable = player / EXE_NAME
    validate_pe(executable)
    require((player / "UnityPlayer.dll").is_file(), "Player output is missing UnityPlayer.dll")
    require((player / "BlueMapUnityProbe_Data").is_dir(), "Player output is missing its Data folder")
    print("Windows x64 build verified; running rendered player checks.", flush=True)
    # Player -batchmode is headless; this check must exercise the rendered player.
    # https://docs.unity3d.com/6000.3/Documentation/Manual/PlayerCommandLineArguments.html
    run_hidden([str(executable), "-screen-width", "1152", "-screen-height", "648",
                "-logFile", str(logs / "player.log"), "--probe-automated",
                "--probe-output-directory", str(runtime)], 180, "Unity probe player")
    result = read_json(runtime / "result.json")
    require(result.get("success") is True, "Runtime did not report success")
    require(result.get("editorVersion") == EXPECTED_VERSION, "Runtime has the wrong Unity version")
    require(result.get("companyName") == "BlueMapMigrationTests" and
            result.get("productName") == "BlueMapUnityProbe" and result.get("gameSaveAccessed") is False,
            "Runtime test identity differs from the isolated probe")
    require(result.get("captureMode") == "Camera.Render to GPU RenderTexture; window overlay excluded",
            "Runtime capture method is not the verified GPU camera path")
    graphics = result.get("graphicsDeviceType")
    require(isinstance(graphics, str) and bool(graphics.strip()) and graphics.lower() not in {"null", "none"},
            "Runtime did not use a real graphics device")
    checks = result.get("checks")
    require(isinstance(checks, list) and bool(checks), "Runtime reported no checks")
    require(all(isinstance(check, dict) and isinstance(check.get("name"), str) and
                bool(check["name"].strip()) and check.get("passed") is True for check in checks),
            "One or more runtime checks failed")
    require(len({check["name"] for check in checks}) == len(checks), "Runtime check names are duplicated")
    frames = result.get("frames")
    require(type(frames) is int and frames > 0, "Runtime reported no rendered frames")
    screenshot = validate_png(runtime / "screenshot.png")
    package, file_count = package_player(player, output)
    receipt = {
        "schemaVersion": 1, "phase": 2, "success": True,
        "editorVersion": EXPECTED_VERSION, "editorRevision": EXPECTED_REVISION,
        "editorProductVersion": product_version, "target": TARGET, "scriptingBackend": "Mono",
        "buildResult": report["buildResult"], "totalErrors": report["totalErrors"],
        "totalWarnings": report["totalWarnings"], "playerArchitecture": "x64",
        "graphicsDeviceType": graphics, "frames": frames,
        "captureMode": result["captureMode"],
        "checks": [{"name": check["name"], "passed": True} for check in checks],
        "screenshot": screenshot,
        "package": {"file": package.name, "sha256": sha256(package),
                    "bytes": package.stat().st_size, "files": file_count},
        "rawLogsPublished": False, "godotSavesUsed": False,
    }
    receipt_path = output / "receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    output_sums = "".join(f"{sha256(path)}  {path.relative_to(output).as_posix()}\n"
                          for path in (package, receipt_path, runtime / "screenshot.png"))
    (output / "SHA256SUMS.txt").write_text(output_sums, encoding="utf-8")
    print(f"UNITY PROBE OK: {len(checks)} runtime checks; {frames} frames; {graphics}; 1152x648 image.", flush=True)
    print(f"Package: {package.name} ({package.stat().st_size} bytes), SHA256 {sha256(package)}", flush=True)
    print("Public receipt: receipt.json; raw logs stay external in private-logs/.", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (ProbeError, OSError) as error:
        print(f"UNITY PROBE FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
