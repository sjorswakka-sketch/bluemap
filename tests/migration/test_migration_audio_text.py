"""Original WAV identity, playback contracts and lossless gettext transfer."""
from __future__ import annotations

import copy
import hashlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
import wave

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import build_migration_audio_text as transfer
from migration_data_codec import json_read


HEADER = ('msgid ""\nmsgstr ""\n"Language: en\\n"\n'
          '"X-Source-Language: nl\\n"\n'
          '"Plural-Forms: nplurals=2; plural=(n != 1);\\n"\n\n')


def wav_bytes(*, channels=1, width=2, rate=22050, frames=6):
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as stream:
        stream.setnchannels(channels)
        stream.setsampwidth(width)
        stream.setframerate(rate)
        stream.writeframes(bytes(range(frames * channels * width)))
    return buffer.getvalue()


def read_fixture(body):
    with tempfile.TemporaryDirectory(prefix="BlueMap-Audio-Text-Tests-") as temporary:
        path = Path(temporary) / "fixture.po"
        path.write_text(HEADER + body, encoding="utf-8")
        return transfer.localization_catalog(path)


class SourceAudioTests(unittest.TestCase):
    def test_stereo_loop_uses_frames_not_encoded_bytes_or_channel_samples(self):
        raw = wav_bytes(channels=2, width=2, frames=7)
        meta = transfer.wav_metadata(raw)
        self.assertEqual(meta["sampleFrames"], 7)
        self.assertEqual(meta["channels"], 2)
        self.assertEqual(meta["sampleWidth"], 2)
        self.assertEqual(meta["bytes"], 44 + 7 * 2 * 2)
        self.assertEqual(meta["sha256"], hashlib.sha256(raw).hexdigest())

    def test_truncated_or_invalid_wav_is_rejected(self):
        for raw in (b"not a WAV", wav_bytes()[:-3], b""):
            with self.subTest(data=raw[:12]), self.assertRaises(transfer.PresentationError):
                transfer.wav_metadata(raw)

    def test_unsupported_rate_or_channel_count_is_rejected(self):
        for options in ({"rate": 0x7FFFFFFF}, {"channels": 3}):
            with self.subTest(options=options), self.assertRaises(transfer.PresentationError):
                transfer.wav_metadata(wav_bytes(**options))

    def test_audio_calls_retain_ternaries_pitch_and_multiline_arguments(self):
        source = ('# Sound.play("fake")\nvar x="Sound.play(\\"also_fake\\")"\n'
                  'Sound.play("hit" if hard else "hurt", -7,\n rng.randf_range(0.9, 1.1))\n'
                  'Sound.play_music("forest")\nSound.stop_music()\n')
        calls = transfer.audio_calls(source, "scripts/fixture.gd")
        self.assertEqual([entry["method"] for entry in calls], ["play", "play_music", "stop_music"])
        self.assertEqual(calls[0]["arguments"], ['"hit" if hard else "hurt"', '-7',
                                                 'rng.randf_range(0.9, 1.1)'])
        self.assertEqual(calls[0]["line"], 3)
        self.assertEqual(calls[2]["arguments"], [])

    def test_unclosed_audio_call_is_not_silently_lost(self):
        with self.assertRaises(transfer.PresentationError):
            transfer.audio_calls('Sound.play("hit", randf_range(0.9, 1.1)', "scripts/fixture.gd")

    def test_pcm_import_does_not_resample_normalize_or_force_mono(self):
        meta = transfer.meta_bytes("Assets/BlueMapContent/Resources/BlueMapAssets/Audio/hit.wav", audio=True).decode()
        for setting in ("compressionFormat: 0", "sampleRateSetting: 0", "forceToMono: 0", "normalize: 0"):
            self.assertIn(setting, meta)

    def test_guid_is_stable_path_derived_and_collision_separated(self):
        first = "Assets/BlueMapContent/Resources/BlueMapAssets/Audio/boss.wav"
        second = "Assets/BlueMapContent/Resources/BlueMapAssets/Audio/music_boss.wav"
        self.assertEqual(transfer.unity_guid(first), hashlib.sha256(
            ("bluemap-presentation:" + first).encode()).hexdigest()[:32])
        self.assertNotEqual(transfer.unity_guid(first), transfer.unity_guid(second))
        with self.assertRaises(transfer.PresentationError):
            transfer.unity_guid("Assets/../outside.wav")

    def test_frozen_source_mutation_is_rejected_in_a_private_fixture(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-Audio-Text-Tests-") as temporary:
            root = Path(temporary)
            original = wav_bytes()
            (root / "sound.wav").write_bytes(original[:-1] + b"\xff")
            manifest = {"sound.wav": {"sha256": transfer.sha(original), "bytes": len(original)}}
            with self.assertRaisesRegex(transfer.PresentationError, "baseline source changed"):
                transfer._frozen_bytes(root, "sound.wav", manifest)


class LocalizationTests(unittest.TestCase):
    def test_implicit_dutch_and_all_english_plural_forms(self):
        catalog = read_fixture('msgid "%d munt"\nmsgid_plural "%d munten"\n'
                               'msgstr[0] "%d coin"\nmsgstr[1] "%d coins"\n')
        entry = catalog["entries"][0]
        self.assertEqual(entry["nl"], ["%d munt", "%d munten"])
        self.assertEqual(entry["en"], ["%d coin", "%d coins"])
        for count, en in ((0, "%d coins"), (1, "%d coin"), (2, "%d coins"), (-1, "%d coins")):
            self.assertEqual(transfer.translate(catalog, "%d munt", plural="%d munten", count=count, locale="en_US"), en)
            self.assertEqual(transfer.translate(catalog, "%d munt", plural="%d munten", count=count, locale="nl"),
                             "%d munt" if count == 1 else "%d munten")

    def test_context_pair_does_not_collapse_identical_sources(self):
        catalog = read_fixture('msgctxt "aanval"\nmsgid "steen"\nmsgstr "boulder"\n\n'
                               'msgid "steen"\nmsgstr "stone"\n')
        self.assertEqual(transfer.translate(catalog, "steen", locale="en", context="aanval"), "boulder")
        self.assertEqual(transfer.translate(catalog, "steen", locale="en"), "stone")
        self.assertEqual(transfer.translate(catalog, "steen", locale="en", context="unknown"), "steen")

    def test_multiline_quotes_tabs_and_backslashes_survive(self):
        catalog = read_fixture('msgid ""\n"Lijn 1\\n"\n"\\t\\\"pad\\\\boek\\\""\n'
                               'msgstr ""\n"Line 1\\n"\n"\\t\\\"path\\\\book\\\""\n')
        entry = catalog["entries"][0]
        self.assertEqual(entry["source"], 'Lijn 1\n\t"pad\\boek"')
        self.assertEqual(entry["en"], ['Line 1\n\t"path\\book"'])

    def test_fuzzy_or_missing_english_uses_original_source(self):
        catalog = read_fixture('#, fuzzy\nmsgid "Fakkel"\nmsgstr "Old torch"\n\n'
                               'msgid "Lamp"\nmsgstr ""\n')
        self.assertFalse(catalog["entries"][0]["translated"])
        self.assertEqual(transfer.translate(catalog, "Fakkel", locale="en"), "Fakkel")
        self.assertEqual(transfer.translate(catalog, "Lamp", locale="en"), "Lamp")

    def test_unknown_source_plural_or_locale_retains_caller_source(self):
        catalog = read_fixture('msgid "Munt"\nmsgstr "Coin"\n')
        self.assertEqual(transfer.translate(catalog, "Missing", plural="Many missing", count=2, locale="en"), "Many missing")
        self.assertEqual(transfer.translate(catalog, "Munt", locale="fr"), "Munt")
        self.assertEqual(transfer.translate(catalog, "Munt", locale=" EN-us "), "Coin")

    def test_translate_before_formatting_and_do_not_translate_twice(self):
        catalog = read_fixture('msgid "Gekregen: %s"\nmsgstr "Obtained: %s"\n')
        translated = transfer.translate(catalog, "Gekregen: %s", locale="en")
        self.assertEqual(translated % "Appel", "Obtained: Appel")
        self.assertEqual(transfer.translate(catalog, "Gekregen: Appel", locale="en"), "Gekregen: Appel")
        self.assertEqual(transfer.translate(catalog, translated, locale="en"), translated)

    def test_named_tokens_and_escaped_percent_keep_their_counts(self):
        catalog = read_fixture('msgid "%s: %d en {coins} / 100%%"\n'
                               'msgstr "%s: %d and {coins} / 100%%"\n')
        entry = catalog["entries"][0]
        self.assertEqual(entry["printf"], ["%s", "%d"])
        self.assertEqual(entry["tokens"], ["{coins}"])
        self.assertEqual(entry["escapedPercentCount"], 1)

    def test_printf_order_token_loss_and_wrong_plural_count_reject(self):
        for body in ('msgid "%s %d"\nmsgstr "%d %s"\n',
                     'msgid "Dag {coins}"\nmsgstr "Hello"\n',
                     'msgid "%d munt"\nmsgid_plural "%d munten"\nmsgstr[0] "%d coin"\n'):
            with self.subTest(body=body), self.assertRaises(transfer.PresentationError):
                read_fixture(body)

    def test_duplicate_context_source_and_executable_plural_rule_reject(self):
        with self.assertRaises(transfer.PresentationError):
            read_fixture('msgid "Munt"\nmsgstr "Coin"\n\nmsgid "Munt"\nmsgstr "Duplicate"\n')
        with tempfile.TemporaryDirectory(prefix="BlueMap-Audio-Text-Tests-") as temporary:
            path = Path(temporary) / "fixture.po"
            path.write_text(HEADER.replace("nplurals=2", "nplurals=3") + 'msgid "A"\nmsgstr "B"\n', encoding="utf-8")
            with self.assertRaises(transfer.PresentationError):
                transfer.localization_catalog(path)


class CompleteFrozenTransferTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.documents = transfer.build_documents(ROOT)
        cls.audio = __import__("json").loads(cls.documents["migration/presentation/audio.json"])
        cls.text = __import__("json").loads(cls.documents["migration/presentation/localization.json"])

    def test_all_138_original_wavs_are_bit_identical(self):
        copies = {path: data for path, data in self.documents.items() if path.endswith(".wav")}
        self.assertEqual(len(copies), 138)
        for clip in self.audio["clips"]:
            original = (ROOT / clip["sourcePath"]).read_bytes()
            copied = copies[transfer.RESOURCE_ROOT + "/Audio/" + Path(clip["sourcePath"]).name]
            self.assertEqual(original, copied)
            self.assertEqual(clip["sha256"], transfer.sha(copied))

    def test_effect_music_same_id_has_different_namespace_and_resource(self):
        boss = [clip for clip in self.audio["clips"] if clip["id"] == "boss"]
        self.assertEqual({clip["role"] for clip in boss}, {"effect", "music"})
        self.assertEqual(len({clip["resourcePath"] for clip in boss}), 2)
        for role, count in (("effect", 126), ("music", 12)):
            clips = [clip for clip in self.audio["clips"] if clip["role"] == role]
            self.assertEqual(len(clips), count)
            self.assertEqual([clip["sourceIndex"] for clip in clips], list(range(count)))

    def test_music_full_loops_and_separate_ambient_loops_match_sources(self):
        for clip in self.audio["clips"]:
            self.assertEqual(clip["loop"], clip["role"] == "music")
            self.assertEqual((clip["loopBeginFrame"], clip["loopEndFrame"]), (0, clip["sampleFrames"]))
        self.assertEqual(len(self.audio["ambience"]), 17)
        self.assertTrue(all(item["bus"] == "SFX" for item in self.audio["ambience"]))
        self.assertEqual([item["baseDb"] for item in self.audio["ambience"] if item["cue"] == "wereld_regen"], [-13])

    def test_sound_pool_fallback_fade_volume_and_settings_contract(self):
        policy = self.audio["policies"]
        self.assertEqual((policy["effectPoolSize"], policy["busyPoolStealIndex"]), (8, 0))
        self.assertEqual((policy["musicFadeStartDb"], policy["musicDb"], policy["musicFadeSeconds"]), (-40, -9, 0.8))
        self.assertEqual(policy["musicFallbackTrack"], "forest")
        self.assertEqual(policy["volumeMinimumLinear"], .0001)
        self.assertEqual(policy["settingsKeys"], ["muted", "music", "sfx"])
        self.assertTrue(policy["processingWhilePaused"] and policy["preserveOtherSettingsSections"])

    def test_dynamic_footstep_pitch_is_retained_as_source_expression(self):
        calls = [call for call in self.audio["callSites"] if call["path"] == "scripts/entities/player.gd"]
        footsteps = [call for call in calls if call["arguments"] and '"step_" + surface' in call["arguments"][0]]
        self.assertEqual(len(footsteps), 1)
        self.assertEqual(footsteps[0]["arguments"][1:], ['-13.0 if sprinting else -17.0', 'randf_range(0.94, 1.06)'])

    def test_all_3187_translations_contexts_plurals_and_multiline_preserved(self):
        entries = self.text["entries"]
        self.assertEqual(len(entries), 3187)
        self.assertEqual(sum(bool(entry["plural"]) for entry in entries), 12)
        self.assertEqual(sum(bool(entry["context"]) for entry in entries), 9)
        self.assertEqual(sum("\n" in entry["source"] for entry in entries), 3)
        self.assertTrue(all(entry["translated"] for entry in entries))
        self.assertEqual(transfer.translate(self.text, ",", context="decimaalteken", locale="en"), ".")
        self.assertEqual(transfer.translate(self.text, "Dageraadsdorp", locale="en"), "Daybreak Village")

    def test_unity_and_reference_catalogs_are_identical_data(self):
        for name in ("audio", "localization"):
            self.assertEqual(self.documents["migration/presentation/" + name + ".json"],
                             self.documents[transfer.RESOURCE_ROOT + "/Data/" + name + ".json"])

    def test_manifest_proves_every_owned_byte_without_self_hash(self):
        manifest = __import__("json").loads(self.documents["migration/presentation/audio-text-manifest.json"])
        self.assertFalse(manifest["engineExecuted"] or manifest["personalSavesUsed"])
        self.assertEqual(len(manifest["files"]), len(self.documents) - 1)
        for entry in manifest["files"]:
            data = self.documents[entry["path"]]
            self.assertEqual(entry["sha256"], transfer.sha(data))
            self.assertEqual(entry["bytes"], len(data))

    def test_optional_generated_outputs(self):
        if not (ROOT / "migration/presentation/audio-text-manifest.json").is_file():
            self.skipTest("Owned presentation outputs have not yet been generated")
        self.assertTrue(transfer.write_or_check(ROOT, self.documents, check=True)["success"])


class OutputBoundaryTests(unittest.TestCase):
    def test_shared_graphics_pair_is_allowed_but_other_data_files_are_not(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-Audio-Text-Tests-") as temporary:
            root = Path(temporary)
            folder = root / transfer.RESOURCE_ROOT / "Data"
            documents = {transfer.RESOURCE_ROOT + "/Audio/example.wav": wav_bytes(),
                         transfer.RESOURCE_ROOT + "/Data/example.json": b"{}\n"}
            transfer.write_or_check(root, documents, check=False)
            (folder / "graphics.json").write_bytes(b"independently checked graphics")
            (folder / "graphics.json.meta").write_bytes(b"independently checked metadata")
            self.assertTrue(transfer.write_or_check(root, documents, check=True)["success"])
            (folder / "unexpected.txt").write_bytes(b"not indexed by either builder")
            with self.assertRaisesRegex(transfer.PresentationError, "Unindexed"):
                transfer.write_or_check(root, documents, check=True)

    def test_extra_file_and_tampered_bytes_fail_exact_check(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-Audio-Text-Tests-") as temporary:
            root = Path(temporary)
            audio = transfer.RESOURCE_ROOT + "/Audio/example.wav"
            text = transfer.RESOURCE_ROOT + "/Data/example.json"
            documents = {audio: wav_bytes(), text: b'{"value":"kept"}\n'}
            transfer.write_or_check(root, documents, check=False)
            (root / audio).write_bytes(wav_bytes(frames=7))
            with self.assertRaisesRegex(transfer.PresentationError, "output differs"):
                transfer.write_or_check(root, documents, check=True)
            (root / audio).write_bytes(documents[audio])
            (root / text).write_bytes(documents[text].replace(b"\n", b"\r\n"))
            self.assertTrue(transfer.write_or_check(root, documents, check=True)["success"])
            (root / audio).with_name("unexpected.bin").write_bytes(b"extra")
            with self.assertRaisesRegex(transfer.PresentationError, "Unindexed"):
                transfer.write_or_check(root, documents, check=True)

    def test_escape_path_is_rejected_before_output(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-Audio-Text-Tests-") as temporary:
            with self.assertRaisesRegex(transfer.PresentationError, "escapes root"):
                transfer.write_or_check(Path(temporary), {"../escape.json": b"{}"}, check=False)


if __name__ == "__main__":
    unittest.main()
