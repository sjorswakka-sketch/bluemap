#!/usr/bin/env python3
"""Transfer original audio and gettext data without running Godot or using saves.

Only the owned presentation documents and Unity Resources audio/data copies are
written. Source expressions are provenance, never executable instructions.
"""
from __future__ import annotations

import argparse
import hashlib
import io
from pathlib import Path
import re
import sys
import wave

import i18n
from build_migration_data import BASELINE, TREE, inputs
from migration_data_codec import canonical_bytes, json_read

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_ROOT = "unity/Assets/BlueMapContent/Resources/BlueMapAssets"
AUDIO_SCHEMA = "bluemap.presentation.audio.v1"
TEXT_SCHEMA = "bluemap.presentation.localization.v1"
MANIFEST_SCHEMA = "bluemap.presentation.audio-text.v1"
SAFE_CUE = re.compile(r"[a-z][a-z0-9_]*\Z")


class PresentationError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise PresentationError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def no_symlink(path: Path) -> None:
    require(not any(part.is_symlink() or (hasattr(part, "is_junction") and part.is_junction())
                    for part in (path, *path.parents)), "Symlink/junction presentation path is forbidden")


def unity_guid(unity_relative: str) -> str:
    require(unity_relative.startswith("Assets/") and "\\" not in unity_relative
            and ".." not in unity_relative.split("/"), "Invalid Unity metadata path")
    return sha(("bluemap-presentation:" + unity_relative).encode("utf-8"))[:32]


def meta_bytes(unity_relative: str, *, audio: bool = False, folder: bool = False) -> bytes:
    header = "fileFormatVersion: 2\nguid: " + unity_guid(unity_relative) + "\n"
    if folder:
        header += "folderAsset: yes\n"
    if audio:
        body = ("AudioImporter:\n  externalObjects: {}\n  serializedVersion: 7\n"
                "  defaultSettings:\n    serializedVersion: 2\n    loadType: 0\n"
                "    sampleRateSetting: 0\n    sampleRateOverride: 44100\n"
                "    compressionFormat: 0\n    quality: 1\n    conversionMode: 0\n"
                "    preloadAudioData: 1\n  platformSettingOverrides: {}\n"
                "  forceToMono: 0\n  normalize: 0\n  loadInBackground: 0\n"
                "  ambisonic: 0\n  3D: 0\n")
    else:
        body = "DefaultImporter:\n  externalObjects: {}\n"
    return (header + body + "  userData: \n  assetBundleName: \n  assetBundleVariant: \n").encode("utf-8")


def wav_metadata(data: bytes) -> dict:
    """Count decoded source frames, never encoded byte length as loop samples."""
    require(0 < len(data) <= 128 * 1024 * 1024, "WAV size is outside the presentation bound")
    try:
        with wave.open(io.BytesIO(data), "rb") as stream:
            channels, width, rate, frames, compression, _ = stream.getparams()
            require(compression == "NONE", "Only the original PCM WAV source format is supported")
            require(channels in (1, 2) and width in (1, 2, 3, 4)
                    and 8000 <= rate <= 192000 and frames > 0, "Invalid WAV PCM parameters")
            samples = stream.readframes(frames)
            require(len(samples) == frames * channels * width, "Truncated WAV sample payload")
    except (wave.Error, EOFError) as error:
        raise PresentationError("Invalid WAV source") from error
    return {"bytes": len(data), "sha256": sha(data), "channels": channels,
            "sampleWidth": width, "sampleRate": rate, "sampleFrames": frames,
            "pcmSha256": sha(samples)}


def _read_string(source: str, start: int) -> tuple[str, int]:
    quote = source[start]
    triple = source.startswith(quote * 3, start)
    marker = quote * (3 if triple else 1)
    index, text = start + len(marker), []
    while index < len(source):
        if source.startswith(marker, index):
            return "".join(text), index + len(marker)
        char = source[index]
        if char == "\\" and index + 1 < len(source):
            escaped = source[index + 1]
            if escaped == "u":
                require(bool(re.fullmatch(r"[0-9a-fA-F]{4}", source[index + 2:index + 6])),
                        "Invalid GDScript Unicode string escape")
                text.append(chr(int(source[index + 2:index + 6], 16)))
                index += 6
                continue
            text.append({"n": "\n", "r": "\r", "t": "\t", "\\": "\\", "'": "'", '"': '"'}.get(
                escaped, "\\" + escaped))
            index += 2
            continue
        require(triple or char != "\n", "Unclosed GDScript string literal")
        text.append(char)
        index += 1
    raise PresentationError("Unclosed GDScript string literal")


def _read_arguments(source: str, start: int) -> tuple[list[str], int]:
    depth, at, piece, arguments = 0, start, start, []
    while at < len(source):
        char = source[at]
        if char in "\"'":
            _, at = _read_string(source, at)
            continue
        if char == "#":
            newline = source.find("\n", at)
            at = len(source) if newline < 0 else newline + 1
            continue
        if char in "([{":
            depth += 1
        elif char in ")]}":
            if depth == 0:
                require(char == ")", "Mismatched GDScript audio call")
                last = source[piece:at].strip()
                if last:
                    arguments.append(last)
                return arguments, at + 1
            depth -= 1
        elif char == "," and depth == 0:
            arguments.append(source[piece:at].strip())
            piece = at + 1
        at += 1
    raise PresentationError("Unclosed GDScript audio call")


def audio_calls(source: str, path: str) -> list[dict]:
    """Preserve literal and dynamic cue/pitch expressions; never evaluate them."""
    found, at = [], 0
    call = re.compile(r"Sound\.(play_music|stop_music|play)\s*\(")
    while at < len(source):
        if source[at] in "\"'":
            _, at = _read_string(source, at)
            continue
        if source[at] == "#":
            newline = source.find("\n", at)
            at = len(source) if newline < 0 else newline + 1
            continue
        match = call.match(source, at)
        if match and (at == 0 or not (source[at - 1].isalnum() or source[at - 1] == "_")):
            arguments, end = _read_arguments(source, match.end())
            found.append({"path": path, "line": source.count("\n", 0, at) + 1,
                          "method": match.group(1), "arguments": arguments,
                          "expression": source[at:end]})
            at = end
        else:
            at += 1
    return found


def localization_catalog(path: Path) -> dict:
    """Keep the source-language catalog implicit and all gettext distinctions."""
    try:
        po = i18n.read_po(str(path))
    except (SystemExit, UnicodeError) as error:
        raise PresentationError("Invalid original gettext catalog") from error
    require(re.search(r"^Language: en\s*$", po.header, re.MULTILINE) is not None,
            "Expected English gettext catalog")
    require(re.search(r"^X-Source-Language: nl\s*$", po.header, re.MULTILINE) is not None,
            "Expected implicit Dutch source language")
    require(re.search(r"^Plural-Forms: nplurals=2; plural=\(n != 1\);\s*$", po.header, re.MULTILINE) is not None,
            "Unsupported gettext plural rule; do not execute catalog expressions")
    entries, keys = [], set()
    for entry in po.entries:
        require(entry.msgid != "" and entry.key not in keys, "Empty/duplicate gettext context-source key")
        keys.add(entry.key)
        require(not i18n.entry_problems(entry, 2), "Gettext placeholders/forms differ: " + entry.msgid)
        for text in [entry.ctx, entry.msgid, entry.plural, *entry.forms()]:
            require("\0" not in text, "NUL in gettext source/translation")
        printf, percent, tokens = i18n.placeholders(entry.msgid)
        entries.append({"context": entry.ctx, "source": entry.msgid, "plural": entry.plural,
                        "nl": [entry.msgid, entry.plural] if entry.is_plural() else [entry.msgid],
                        "en": entry.forms(), "fuzzy": "fuzzy" in entry.flags,
                        "translated": entry.translated(), "refs": entry.refs,
                        "comments": entry.extracted, "flags": entry.flags,
                        "printf": printf, "tokens": tokens, "escapedPercentCount": percent})
    return {"schema": TEXT_SCHEMA, "version": 1, "phase": 6,
            "baselineCommit": BASELINE, "baselineTree": TREE, "sourceLocale": "nl",
            "locales": ["nl", "en"], "pluralRule": "n != 1", "fallback": "source_or_plural",
            "header": po.header, "entries": entries,
            "policies": {"key": "context_and_source_pair", "translateBeforeFormatting": True,
                         "automaticDoubleTranslation": False, "sourceLanguageIsImplicit": True,
                         "unknownLocale": "source", "unknownContext": "source",
                         "fuzzyOrMissingEnglish": "source_or_plural",
                         "startupOrder": ["settings.cfg:taal.locale", "BLUEMAP_LANG", "system_language"],
                         "systemLanguageFallback": "nl_if_system_nl_otherwise_en"}}


def translate(catalog: dict, source: str, *, locale: str = "nl", context: str = "",
              plural: str = "", count: int = 1) -> str:
    """Data-only reference lookup, matching the source fallback contract."""
    fallback = plural if plural and count != 1 else source
    code = locale.strip().lower().replace("-", "_").split("_")[0]
    if code != "en":
        return fallback
    for entry in catalog["entries"]:
        if entry["context"] == context and entry["source"] == source:
            form = int(count != 1) if entry["plural"] else 0
            if not entry["fuzzy"] and len(entry["en"]) > form and entry["en"][form]:
                return entry["en"][form]
            return fallback
    return fallback


def _frozen_bytes(root: Path, path: str, manifest: dict, *, text: bool = False) -> bytes:
    require(path in manifest, "Source is not in the preserved Godot baseline: " + path)
    file = root / path
    no_symlink(file)
    data = file.read_bytes()
    if text:
        data = data.replace(b"\r\n", b"\n")
    require(sha(data) == manifest[path]["sha256"] and len(data) == manifest[path]["bytes"],
            "Original baseline source changed: " + path)
    return data


def build_documents(root: Path = ROOT) -> dict[str, bytes]:
    root = Path(root)
    content, _, _ = inputs(root)
    original = json_read(root / "migration/reference/source-manifest.json")
    source_manifest = {entry["path"]: entry for entry in original["files"]}
    anchors = {}

    def frozen(path: str, text: bool = False) -> bytes:
        data = _frozen_bytes(root, path, source_manifest, text=text)
        anchors[path] = {"path": path, "sha256": sha(data), "bytes": len(data)}
        return data

    for path in ("scripts/core/sound.gd", "scripts/core/lang.gd", "scripts/core/daynight.gd",
                 "scripts/entities/atmosphere.gd", "scripts/core/game_state.gd",
                 "tools/i18n.py", "tools/i18n_extract.gd", "translations/en.po"):
        frozen(path, True)

    documents, clips, known_files = {}, [], set()
    for role, catalog_name in (("effect", "sounds"), ("music", "music_tracks")):
        catalog = content["catalogs"][catalog_name]
        ordered = sorted(catalog["entries"], key=lambda item: item["value"]["source_index"])
        require([entry["value"]["source_index"] for entry in ordered] == list(range(len(ordered))),
                "Audio declaration indices changed")
        for entry in ordered:
            cue = entry["id"]
            require(SAFE_CUE.fullmatch(cue) is not None, "Unsafe audio cue ID")
            name = ("music_" if role == "music" else "") + cue
            source_path = "assets/audio/" + name + ".wav"
            require(source_path not in known_files, "Duplicate audio source")
            known_files.add(source_path)
            raw = frozen(source_path)
            # Preserve and anchor the original import policy; Unity reads the
            # original PCM bytes, not the lossy Godot .sample cache.
            import_path = source_path + ".import" if source_path + ".import" in source_manifest else ""
            if import_path:
                frozen(import_path, True)
            metadata = wav_metadata(raw)
            resource = "BlueMapAssets/Audio/" + name
            target = RESOURCE_ROOT + "/Audio/" + name + ".wav"
            documents[target] = raw
            documents[target + ".meta"] = meta_bytes(target[len("unity/"):], audio=True)
            clips.append({"id": cue, "role": role, "sourceIndex": entry["value"]["source_index"],
                          "sourcePath": source_path, "resourcePath": resource,
                          "originalImportMetadata": import_path, **metadata,
                          "loop": role == "music", "loopBeginFrame": 0,
                          "loopEndFrame": metadata["sampleFrames"], "sources": entry["sources"]})
    expected_wavs = {path for path in source_manifest if path.startswith("assets/audio/") and path.endswith(".wav")}
    require(known_files == expected_wavs and len(clips) == 138, "Audio catalog does not cover all 138 original WAVs")
    calls = []
    for path in sorted(source_manifest):
        if path.startswith("scripts/") and path.endswith(".gd"):
            source = frozen(path, True).decode("utf-8")
            calls.extend(audio_calls(source, path))
    ambience = [{"cue": clip["id"], "resourcePath": clip["resourcePath"],
                 "loopBeginFrame": 0, "loopEndFrame": clip["sampleFrames"],
                 "baseDb": -13.0 if clip["id"] == "wereld_regen" else -17.0, "bus": "SFX"}
                for clip in clips if clip["role"] == "effect" and
                (clip["id"].startswith("amb_") or clip["id"] == "wereld_regen")]
    require(len(ambience) == 17, "Original 16 climate/phase loops plus rain must remain available")
    audio = {"schema": AUDIO_SCHEMA, "version": 1, "phase": 6,
             "baselineCommit": BASELINE, "baselineTree": TREE, "clips": clips, "ambience": ambience,
             "callSites": calls, "policies": {
                 "effectPoolSize": 8, "busyPoolStealIndex": 0, "defaultEffectDb": 0.0,
                 "defaultPitch": 1.0, "musicDb": -9.0, "musicFadeStartDb": -40.0,
                 "musicFadeSeconds": 0.8, "musicFallbackTrack": "forest",
                 "sameMusicDoesNotRestart": True, "processingWhilePaused": True,
                 "volumeMinimumLinear": 0.0001, "defaultMusicVolume": 1.0,
                 "defaultSfxVolume": 1.0, "defaultMuted": False,
                 "musicBus": "Music", "sfxBus": "SFX", "muteBus": "Master",
                 "unknownEffect": "silence", "musicStopClearsCurrentTrack": True,
                 "settingsFile": "settings.cfg", "settingsSection": "audio",
                 "settingsKeys": ["muted", "music", "sfx"],
                 "preserveOtherSettingsSections": True, "effectsAreNonSpatial": True,
                 "ambienceFadeSeconds": 2.0, "rainFadeSeconds": 4.0,
                 "ambienceLoopRule": "full_clip_on_separate_SFX_player_not_effect_pool",
                 "import": "original_PCM_preserve_rate_channels_samples_no_normalize"}}
    localization = localization_catalog(root / "translations/en.po")
    require(len(localization["entries"]) == 3187 and all(entry["translated"] for entry in localization["entries"]),
            "Expected all 3187 original translated entries")
    for document in (audio, localization):
        document["sourceAnchors"] = [anchors[path] for path in sorted(anchors)]
    for name, document in (("audio", audio), ("localization", localization)):
        raw = canonical_bytes(document)
        documents["migration/presentation/" + name + ".json"] = raw
        target = RESOURCE_ROOT + "/Data/" + name + ".json"
        documents[target] = raw
        documents[target + ".meta"] = meta_bytes(target[len("unity/"):])
    for folder in ("unity/Assets/BlueMapContent", "unity/Assets/BlueMapContent/Resources", RESOURCE_ROOT,
                   RESOURCE_ROOT + "/Audio", RESOURCE_ROOT + "/Data"):
        documents[folder + ".meta"] = meta_bytes(folder[len("unity/"):], folder=True)
    manifest = {"schema": MANIFEST_SCHEMA, "version": 1, "phase": 6,
                "baselineCommit": BASELINE, "baselineTree": TREE,
                "audioClips": len(clips), "effects": 126, "musicTracks": 12, "ambientLoops": 17,
                "translations": len(localization["entries"]),
                "pluralEntries": sum(bool(entry["plural"]) for entry in localization["entries"]),
                "contextEntries": sum(bool(entry["context"]) for entry in localization["entries"]),
                "multilineEntries": sum("\n" in entry["source"] for entry in localization["entries"]),
                "audioCallSites": len(calls), "audioBytes": sum(clip["bytes"] for clip in clips),
                "personalSavesUsed": False, "engineExecuted": False,
                "scope": "source_assets_catalogs_and_playback_localization_policies_not_gameplay_port",
                "files": [{"path": path, "bytes": len(data), "sha256": sha(data)}
                          for path, data in sorted(documents.items())]}
    documents["migration/presentation/audio-text-manifest.json"] = canonical_bytes(manifest)
    return documents


def write_or_check(root: Path, documents: dict[str, bytes], *, check: bool) -> dict:
    root = Path(root).resolve()
    no_symlink(root)
    for relative, data in documents.items():
        path = root / relative
        no_symlink(path)
        require(path.resolve().is_relative_to(root), "Presentation output escapes root")
        if check:
            require(path.is_file(), "Missing presentation output: " + relative)
            actual = path.read_bytes()
            if not relative.endswith(".wav"):
                actual = actual.replace(b"\r\n", b"\n")
            require(actual == data, "Presentation output differs: " + relative)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    # Extra files under these exclusively owned asset folders cannot silently
    # join a build. Shared ancestors and graphics are owned by other pipelines.
    for folder in (RESOURCE_ROOT + "/Audio", RESOURCE_ROOT + "/Data"):
        expected = {str((root / name).resolve()) for name in documents if name.startswith(folder + "/")}
        # The independent graphics builder owns this pair in the shared Data
        # folder and verifies its exact bytes. It is not an unindexed audio file.
        shared = ({str((root / folder / name).resolve()) for name in ("graphics.json", "graphics.json.meta")}
                  if folder.endswith("/Data") else set())
        actual = set()
        for path in (root / folder).rglob("*"):
            no_symlink(path)
            require(path.is_file(), "Unexpected directory inside flat audio/data assets")
            if str(path.resolve()) not in shared:
                actual.add(str(path.resolve()))
        require(actual == expected, "Unindexed presentation audio/data file")
    return {"success": True, "files": len(documents), "audioClips": 138, "translations": 3187,
            "engineExecuted": False, "personalSavesUsed": False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        report = write_or_check(ROOT, build_documents(ROOT), check=args.check)
        print("AUDIO TEXT TRANSFER OK:", report)
        return 0
    except (OSError, ValueError) as error:
        print("AUDIO TEXT TRANSFER FAILED:", error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
