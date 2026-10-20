"""Archive attacks and provenance failures must fail before player extraction."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import verify_unity_package as package
import fetch_unity_preview as download


def identity() -> dict:
    return {
        "schemaVersion": 1, "phase": 3, "previewVersion": "0.1.0-phase3",
        "sourceCommit": "a" * 40, "inputFingerprint": "b" * 64,
        "editorVersion": "6000.3.26f1", "editorRevision": "de8167e7440c",
        "target": "StandaloneWindows64",
    }


def runtime(build_identity: dict) -> dict:
    return {
        "identity": copy.deepcopy(build_identity), "success": True,
        "editorVersion": "6000.3.26f1", "graphicsDeviceType": "Direct3D11",
        "frames": 120, "width": 1152, "height": 648,
        "companyName": "BlueMapMigrationTests", "productName": "BlueMapUnityProbe",
        "captureMode": "Camera.Render to GPU RenderTexture; window overlay excluded",
        "gameSaveAccessed": False,
        "checks": [{"name": name, "passed": True} for name in sorted(package.BASE_CHECKS)],
    }


def foundation(build_identity: dict) -> dict:
    names = sorted(package.FOUNDATION_DETAIL_CHECKS) + [f"foundation_detail_{i}" for i in range(8)]
    return {"schemaVersion": 1, "identity": copy.deepcopy(build_identity), "success": True,
            "gameSaveAccessed": False, "checks": [{"name": name, "passed": True} for name in names]}


def player_proof(build_identity: dict) -> dict:
    return {"schemaVersion": 1, "identity": copy.deepcopy(build_identity), "success": True,
            "gameSaveAccessed": False,
            "checks": [{"name": name, "passed": True} for name in sorted(package.PLAYER_DETAIL_CHECKS)]}


def persistence_proof(build_identity: dict) -> dict:
    return {"schemaVersion": 1, "identity": copy.deepcopy(build_identity), "success": True,
            "gameSaveAccessed": False,
            "checks": [{"name": name, "passed": True} for name in sorted(package.PERSISTENCE_DETAIL_CHECKS)]}


def route_proof(build_identity: dict) -> dict:
    return {"schemaVersion": 1, "identity": copy.deepcopy(build_identity), "success": True,
            "gameSaveAccessed": False,
            "checks": [{"name": name, "passed": True} for name in sorted(package.ROUTE_DETAIL_CHECKS)]}


def pe_stub() -> bytes:
    """Small deliberate fixture, never a runnable executable."""
    raw = bytearray(256)
    raw[:2] = b"MZ"
    struct.pack_into("<I", raw, 0x3C, 64)
    raw[64:68] = b"PE\0\0"
    struct.pack_into("<H", raw, 68, 0x8664)
    struct.pack_into("<H", raw, 88, 0x20B)
    return bytes(raw)


class PreviewReferenceTests(unittest.TestCase):
    def test_all_published_phase_formats_remain_supported(self):
        for phase, version in ((3, "0.1.0-phase3"), (6, "0.2.0-phase6"), (7, "0.3.0-phase7"),
                               (8, "0.4.0-phase8"), (9, "0.5.0-phase9"), (10, "0.6.0-phase10")):
            name = f"BlueMapUnityPreview-phase-{phase:02d}-aaaaaaaa-Windows-x64.zip"
            manifest = {"schemaVersion": 1, "phase": phase, "previewVersion": version,
                        "sourceCommit": "a" * 40, "packageName": name}
            with self.subTest(phase=phase):
                self.assertEqual(download.validate_preview_reference(manifest), (phase, "a" * 40, name))

    def test_cross_phase_version_source_and_filename_are_rejected_before_download(self):
        valid = {"schemaVersion": 1, "phase": 7, "previewVersion": "0.3.0-phase7",
                 "sourceCommit": "a" * 40, "packageName": "BlueMapUnityPreview-phase-07-aaaaaaaa-Windows-x64.zip"}
        for change in ({"phase": 6}, {"previewVersion": "0.2.0-phase6"}, {"schemaVersion": True},
                       {"sourceCommit": "0" * 40}, {"sourceCommit": "A" * 40},
                       {"packageName": "BlueMapUnityPreview-phase-06-aaaaaaaa-Windows-x64.zip"}):
            with self.subTest(change=change), self.assertRaises(package.PackageError):
                download.validate_preview_reference({**valid, **change})


class UnityPackageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="BlueMap-Package-Tests-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.player = self.base / "player"
        self.output = self.base / "output"
        self.player.mkdir()
        self.output.mkdir()
        self.identity = identity()
        self.runtime = runtime(self.identity)
        for name in package.REQUIRED_FILES - package.METADATA_FILES:
            path = self.player / name
            path.parent.mkdir(parents=True, exist_ok=True)
            if name in package.PE_FILES:
                raw = pe_stub()
            elif name.endswith("app.info"):
                raw = b"BlueMapMigrationTests\nBlueMapUnityProbe\n"
            else:
                raw = b"Deliberate non-runnable test fixture\n"
            path.write_bytes(raw)
        self.archive, count = package.package_player(self.player, self.output,
                                                     self.identity, self.runtime)
        self.receipt = {
            "identity": self.identity, "success": True,
            "rawLogsPublished": False, "godotSavesUsed": False,
            "checks": self.runtime["checks"],
            "package": {"file": self.archive.name, "sha256": package.sha256(self.archive),
                        "bytes": self.archive.stat().st_size, "files": count},
        }

    def refresh_receipt(self) -> None:
        self.receipt["package"].update(sha256=package.sha256(self.archive),
                                       bytes=self.archive.stat().st_size)
        with zipfile.ZipFile(self.archive) as archive:
            self.receipt["package"]["files"] = len(archive.infolist())

    def rewrite(self, edit, refresh_manifest: bool = False) -> None:
        with zipfile.ZipFile(self.archive) as archive:
            files = [(info, archive.read(info)) for info in archive.infolist()]
        files = edit(files)
        if refresh_manifest:
            root = package.archive_root(self.identity) + "/"
            manifest = {info.filename[len(root):]: {
                "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)
            } for info, raw in files if info.filename != root + "FILES.json"}
            files = [(info, json.dumps(manifest).encode() if info.filename == root + "FILES.json"
                      else raw) for info, raw in files]
        with zipfile.ZipFile(self.archive, "w", compression=zipfile.ZIP_STORED) as archive:
            for info, raw in files:
                archive.writestr(info, raw)
        self.refresh_receipt()

    def change_payload(self, name: str, raw: bytes, refresh_manifest: bool = True) -> None:
        self.rewrite(lambda files: [(info, raw if info.filename.endswith("/" + name) else data)
                                   for info, data in files], refresh_manifest)

    def rejected(self) -> None:
        with self.assertRaises(package.PackageError):
            package.verify_package(self.archive, self.receipt, "a" * 40)

    def test_complete_preview_verifies_without_extracting(self) -> None:
        before = sorted(str(p.relative_to(self.base)) for p in self.base.rglob("*"))
        report = package.verify_package(self.archive, self.receipt, "a" * 40)
        self.assertTrue(report["success"])
        self.assertFalse(report["extracted"])
        self.assertEqual(report["runtimeChecks"], 16)
        self.assertEqual(before, sorted(str(p.relative_to(self.base)) for p in self.base.rglob("*")))

    def phase6_fixture(self):
        build_identity = {**identity(), "phase": 6, "previewVersion": "0.2.0-phase6"}
        proof = runtime(build_identity)
        proof["checks"] += [{"name": name, "passed": True} for name in sorted(package.PRESENTATION_CHECKS)]
        output = self.base / "phase6-output"
        output.mkdir()
        archive, count = package.package_player(self.player, output, build_identity, proof)
        receipt = {"phase": 6, "identity": build_identity, "success": True,
                   "rawLogsPublished": False, "godotSavesUsed": False, "checks": proof["checks"],
                   "package": {"file": archive.name, "sha256": package.sha256(archive),
                               "bytes": archive.stat().st_size, "files": count}}
        return archive, receipt, proof

    def test_phase6_full_presentation_package_and_historical_phase3_both_verify(self) -> None:
        archive, receipt, _ = self.phase6_fixture()
        phase6 = package.verify_package(archive, receipt, "a" * 40)
        historical = package.verify_package(self.archive, self.receipt, "a" * 40)
        self.assertEqual((phase6["phase"], historical["phase"]), (6, 3))
        self.assertEqual(phase6["runtimeChecks"], len(package.BASE_CHECKS | package.PRESENTATION_CHECKS))
        self.assertEqual(historical["runtimeChecks"], 16)
        self.assertTrue(archive.name.startswith("BlueMapUnityPreview-phase-06-aaaaaaaa-"))
        with zipfile.ZipFile(archive) as packed:
            name = package.archive_root(receipt["identity"]) + "/LEESMIJ.txt"
            self.assertIn("Migratiefase 6", packed.read(name).decode("utf-8"))

    def test_each_phase6_presentation_check_is_required_before_packaging(self) -> None:
        build_identity = {**identity(), "phase": 6, "previewVersion": "0.2.0-phase6"}
        for missing in sorted(package.PRESENTATION_CHECKS):
            proof = runtime(build_identity)
            proof["checks"] += [{"name": name, "passed": True}
                                for name in sorted(package.PRESENTATION_CHECKS - {missing})]
            # The count remains high; unrelated green checks cannot replace a
            # missing source-pixel/font/audio/localization witness.
            proof["checks"].append({"name": "unrelated_green_check", "passed": True})
            with self.subTest(missing=missing), self.assertRaisesRegex(package.PackageError, "presentation proof"):
                package.package_player(self.player, self.output, build_identity, proof)

    def test_phase6_missing_check_cannot_be_bypassed_by_rehashing_archive_and_receipt(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase6_fixture()
        self.identity = self.receipt["identity"]
        changed = copy.deepcopy(self.runtime)
        changed["checks"] = [check for check in changed["checks"] if check["name"] != "gpu_original_pixels_exact"]
        self.receipt["checks"] = changed["checks"]
        self.change_payload("RUNTIME-CHECKS.json", json.dumps(changed).encode())
        with self.assertRaisesRegex(package.PackageError, "presentation proof"):
            package.verify_package(self.archive, self.receipt, "a" * 40)

    def test_phase6_failed_presentation_check_is_rejected(self) -> None:
        build_identity = {**identity(), "phase": 6, "previewVersion": "0.2.0-phase6"}
        proof = runtime(build_identity)
        proof["checks"] += [{"name": name, "passed": name != "original_audio_playback_started"}
                            for name in sorted(package.PRESENTATION_CHECKS)]
        with self.assertRaisesRegex(package.PackageError, "failed check"):
            package.package_player(self.player, self.output, build_identity, proof)

    def phase7_fixture(self):
        build_identity = {**identity(), "phase": 7, "previewVersion": "0.3.0-phase7"}
        proof = runtime(build_identity)
        proof["checks"] += [{"name": name, "passed": True}
                            for name in sorted(package.PRESENTATION_CHECKS | package.FOUNDATION_CHECKS)]
        details = foundation(build_identity)
        output = self.base / "phase7-output"
        output.mkdir()
        archive, count = package.package_player(self.player, output, build_identity, proof, details)
        receipt = {"phase": 7, "identity": build_identity, "success": True, "foundation": details,
                   "rawLogsPublished": False, "godotSavesUsed": False, "checks": proof["checks"],
                   "package": {"file": archive.name, "sha256": package.sha256(archive),
                               "bytes": archive.stat().st_size, "files": count}}
        return archive, receipt, proof

    def phase8_fixture(self):
        build_identity = {**identity(), "phase": 8, "previewVersion": "0.4.0-phase8"}
        proof = runtime(build_identity)
        proof["checks"] += [{"name": name, "passed": True} for name in sorted(
            package.PRESENTATION_CHECKS | package.FOUNDATION_CHECKS | package.PLAYER_CHECKS)]
        details, player = foundation(build_identity), player_proof(build_identity)
        output = self.base / "phase8-output"
        output.mkdir()
        (self.player / package.PLAYER_INPUT_DLL).write_bytes(b"Deliberate non-runnable Input System DLL fixture\n")
        archive, count = package.package_player(self.player, output, build_identity, proof, details, player)
        receipt = {"phase": 8, "identity": build_identity, "success": True,
                   "foundation": details, "player": player,
                   "unityPackages": [{"name": "com.unity.inputsystem", "version": "1.0.0", "source": "registry"}],
                   "runtimeDllInputs": [{"name": "Unity.InputSystem.dll",
                                          "bytes": (self.player / package.PLAYER_INPUT_DLL).stat().st_size,
                                          "sha256": package.sha256(self.player / package.PLAYER_INPUT_DLL)}],
                   "rawLogsPublished": False, "godotSavesUsed": False, "checks": proof["checks"],
                   "package": {"file": archive.name, "sha256": package.sha256(archive),
                               "bytes": archive.stat().st_size, "files": count}}
        return archive, receipt, proof

    def phase9_fixture(self):
        build_identity = {**identity(), "phase": 9, "previewVersion": "0.5.0-phase9"}
        proof = runtime(build_identity)
        proof["checks"] += [{"name": name, "passed": True} for name in sorted(
            package.PRESENTATION_CHECKS | package.FOUNDATION_CHECKS | package.PLAYER_CHECKS |
            package.PERSISTENCE_CHECKS)]
        details, player, persistence = (foundation(build_identity), player_proof(build_identity),
                                        persistence_proof(build_identity))
        output = self.base / "phase9-output"
        output.mkdir()
        (self.player / package.PLAYER_INPUT_DLL).write_bytes(b"Deliberate non-runnable Input System DLL fixture\n")
        archive, count = package.package_player(self.player, output, build_identity, proof,
                                                 details, player, persistence)
        receipt = {"phase": 9, "identity": build_identity, "success": True,
                   "foundation": details, "player": player, "persistence": persistence,
                   "unityPackages": [{"name": "com.unity.inputsystem", "version": "1.0.0", "source": "registry"}],
                   "runtimeDllInputs": [{"name": "Unity.InputSystem.dll",
                                          "bytes": (self.player / package.PLAYER_INPUT_DLL).stat().st_size,
                                          "sha256": package.sha256(self.player / package.PLAYER_INPUT_DLL)}],
                   "rawLogsPublished": False, "godotSavesUsed": False, "checks": proof["checks"],
                   "package": {"file": archive.name, "sha256": package.sha256(archive),
                               "bytes": archive.stat().st_size, "files": count}}
        return archive, receipt, proof

    def phase10_fixture(self):
        build_identity = {**identity(), "phase": 10, "previewVersion": "0.6.0-phase10"}
        proof = runtime(build_identity)
        proof["checks"] += [{"name": name, "passed": True} for name in sorted(
            package.PRESENTATION_CHECKS | package.FOUNDATION_CHECKS | package.PLAYER_CHECKS |
            package.PERSISTENCE_CHECKS | package.ROUTE_CHECKS)]
        details, player, persistence, route = (foundation(build_identity), player_proof(build_identity),
                                               persistence_proof(build_identity), route_proof(build_identity))
        output = self.base / "phase10-output"
        output.mkdir()
        (self.player / package.PLAYER_INPUT_DLL).write_bytes(b"Deliberate non-runnable Input System DLL fixture\n")
        archive, count = package.package_player(self.player, output, build_identity, proof,
                                                details, player, persistence, route)
        receipt = {"phase": 10, "identity": build_identity, "success": True,
                   "foundation": details, "player": player, "persistence": persistence, "route": route,
                   "unityPackages": [{"name": "com.unity.inputsystem", "version": "1.0.0", "source": "registry"}],
                   "runtimeDllInputs": [{"name": "Unity.InputSystem.dll",
                                          "bytes": (self.player / package.PLAYER_INPUT_DLL).stat().st_size,
                                          "sha256": package.sha256(self.player / package.PLAYER_INPUT_DLL)}],
                   "rawLogsPublished": False, "godotSavesUsed": False, "checks": proof["checks"],
                   "package": {"file": archive.name, "sha256": package.sha256(archive),
                               "bytes": archive.stat().st_size, "files": count}}
        return archive, receipt, proof

    def test_phase10_route_and_historical_phase9_both_verify(self) -> None:
        archive, receipt, _ = self.phase10_fixture()
        report = package.verify_package(archive, receipt, "a" * 40)
        self.assertEqual((report["phase"], report["runtimeChecks"]), (10, 34))
        old_archive, old_receipt, _ = self.phase9_fixture()
        self.assertTrue(package.verify_package(old_archive, old_receipt, "a" * 40)["success"])
        with zipfile.ZipFile(archive) as packed:
            root = package.archive_root(receipt["identity"])
            self.assertEqual(json.loads(packed.read(root + "/ROUTE-CHECKS.json")), receipt["route"])
            self.assertIn("Migratiefase 10", packed.read(root + "/LEESMIJ.txt").decode("utf-8"))

    def test_phase10_cannot_drop_previous_or_route_runtime_proof(self) -> None:
        build_identity = {**identity(), "phase": 10, "previewVersion": "0.6.0-phase10"}
        required = (package.PRESENTATION_CHECKS | package.FOUNDATION_CHECKS | package.PLAYER_CHECKS |
                    package.PERSISTENCE_CHECKS | package.ROUTE_CHECKS)
        for missing in required:
            proof = runtime(build_identity)
            proof["checks"] += [{"name": name, "passed": True} for name in sorted(required - {missing})]
            proof["checks"].append({"name": "unrelated_green_check", "passed": True})
            with self.subTest(missing=missing), self.assertRaisesRegex(package.PackageError, "proof"):
                package.package_player(self.player, self.output, build_identity, proof,
                                       foundation(build_identity), player_proof(build_identity),
                                       persistence_proof(build_identity), route_proof(build_identity))

    def test_phase10_route_details_fail_closed(self) -> None:
        build_identity = {**identity(), "phase": 10, "previewVersion": "0.6.0-phase10"}
        changes = {
            "missing": lambda d: None,
            "stub": lambda d: {**d, "checks": [{"name": "route_stub", "passed": True}]},
            "wrong_source": lambda d: {**d, "identity": {**build_identity, "sourceCommit": "c" * 40}},
            "schema_bool": lambda d: {**d, "schemaVersion": True},
            "failed": lambda d: {**d, "success": False},
            "save_access": lambda d: {**d, "gameSaveAccessed": True},
            "extra_field": lambda d: {**d, "privateSavePath": "must not publish"},
            "failed_detail": lambda d: {**d, "checks": d["checks"] + [{"name": "failed_detail", "passed": False}]},
            "duplicate": lambda d: {**d, "checks": d["checks"] + [d["checks"][0]]},
        }
        for label, edit in changes.items():
            with self.subTest(change=label), self.assertRaises(package.PackageError):
                package.validate_route(edit(route_proof(build_identity)), build_identity)

    def test_phase10_each_native_route_check_is_required(self) -> None:
        build_identity = {**identity(), "phase": 10, "previewVersion": "0.6.0-phase10"}
        for missing in package.ROUTE_DETAIL_CHECKS:
            details = route_proof(build_identity)
            details["checks"] = [check for check in details["checks"] if check["name"] != missing]
            details["checks"].append({"name": "unrelated_green_check", "passed": True})
            with self.subTest(missing=missing), self.assertRaisesRegex(package.PackageError, "checks are missing"):
                package.validate_route(details, build_identity)

    def test_phase10_receipt_route_must_match_packaged_proof(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase10_fixture()
        self.identity = self.receipt["identity"]
        self.receipt["route"]["checks"].append({"name": "receipt_only_check", "passed": True})
        with self.assertRaisesRegex(package.PackageError, "Receipt route proof"):
            package.verify_package(self.archive, self.receipt)

    def test_phase10_failed_route_rejected_even_after_rehashing(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase10_fixture()
        self.identity = self.receipt["identity"]
        self.receipt["route"]["checks"][0]["passed"] = False
        self.change_payload("ROUTE-CHECKS.json", json.dumps(self.receipt["route"]).encode())
        self.rejected()

    def test_phase10_missing_route_rejected_even_after_rehashing(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase10_fixture()
        self.identity = self.receipt["identity"]
        self.rewrite(lambda files: [(info, raw) for info, raw in files
                                   if not info.filename.endswith("/ROUTE-CHECKS.json")], True)
        with self.assertRaisesRegex(package.PackageError, "route proof is missing"):
            package.verify_package(self.archive, self.receipt)

    def test_historical_phase9_cannot_claim_route_verified(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase9_fixture()
        self.identity = self.receipt["identity"]
        self.receipt["route"] = route_proof(self.identity)
        with self.assertRaisesRegex(package.PackageError, "unsupported route proof"):
            package.verify_package(self.archive, self.receipt)

    def test_phase9_save_settings_store_proof_and_historical_phase8_both_verify(self) -> None:
        archive, receipt, _ = self.phase9_fixture()
        report = package.verify_package(archive, receipt, "a" * 40)
        self.assertEqual((report["phase"], report["runtimeChecks"]), (9, 33))
        old_archive, old_receipt, _ = self.phase8_fixture()
        self.assertTrue(package.verify_package(old_archive, old_receipt, "a" * 40)["success"])
        with zipfile.ZipFile(archive) as packed:
            root = package.archive_root(receipt["identity"])
            self.assertEqual(json.loads(packed.read(root + "/PERSISTENCE-CHECKS.json")), receipt["persistence"])
            instructions = packed.read(root + "/LEESMIJ.txt").decode("utf-8")
            self.assertIn("Migratiefase 9", instructions)
            self.assertIn("alleen eigen testbestanden", instructions)

    def test_phase9_runtime_cannot_drop_any_previous_or_persistence_proof(self) -> None:
        build_identity = {**identity(), "phase": 9, "previewVersion": "0.5.0-phase9"}
        required = (package.PRESENTATION_CHECKS | package.FOUNDATION_CHECKS | package.PLAYER_CHECKS |
                    package.PERSISTENCE_CHECKS)
        for missing in required:
            proof = runtime(build_identity)
            proof["checks"] += [{"name": name, "passed": True} for name in sorted(required - {missing})]
            proof["checks"].append({"name": "unrelated_green_check", "passed": True})
            with self.subTest(missing=missing), self.assertRaisesRegex(package.PackageError, "proof"):
                package.package_player(self.player, self.output, build_identity, proof,
                                       foundation(build_identity), player_proof(build_identity),
                                       persistence_proof(build_identity))

    def test_phase9_persistence_details_fail_closed_before_packaging(self) -> None:
        build_identity = {**identity(), "phase": 9, "previewVersion": "0.5.0-phase9"}
        changes = {
            "missing": lambda d: None,
            "stub": lambda d: {**d, "checks": [{"name": "persistence_stub", "passed": True}]},
            "wrong_source": lambda d: {**d, "identity": {**build_identity, "sourceCommit": "c" * 40}},
            "schema_bool": lambda d: {**d, "schemaVersion": True},
            "failed": lambda d: {**d, "success": False},
            "save_access": lambda d: {**d, "gameSaveAccessed": True},
            "extra_field": lambda d: {**d, "privateSavePath": "must not publish"},
            "failed_detail": lambda d: {**d, "checks": d["checks"] + [{"name": "failed_detail", "passed": False}]},
            "duplicate": lambda d: {**d, "checks": d["checks"] + [d["checks"][0]]},
        }
        for label, edit in changes.items():
            with self.subTest(change=label), self.assertRaises(package.PackageError):
                package.validate_persistence(edit(persistence_proof(build_identity)), build_identity)

    def test_phase9_each_required_persistence_detail_is_required(self) -> None:
        build_identity = {**identity(), "phase": 9, "previewVersion": "0.5.0-phase9"}
        for missing in package.PERSISTENCE_DETAIL_CHECKS:
            details = persistence_proof(build_identity)
            details["checks"] = [check for check in details["checks"] if check["name"] != missing]
            details["checks"].append({"name": "unrelated_green_check", "passed": True})
            with self.subTest(missing=missing), self.assertRaisesRegex(package.PackageError, "checks are missing"):
                package.validate_persistence(details, build_identity)

    def test_phase9_receipt_persistence_must_match_packaged_proof(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase9_fixture()
        self.identity = self.receipt["identity"]
        self.receipt["persistence"]["checks"].append({"name": "receipt_only_check", "passed": True})
        with self.assertRaisesRegex(package.PackageError, "Receipt persistence proof"):
            package.verify_package(self.archive, self.receipt)

    def test_phase9_failed_persistence_cannot_hide_behind_rehashed_archive(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase9_fixture()
        self.identity = self.receipt["identity"]
        self.receipt["persistence"]["checks"][0]["passed"] = False
        self.change_payload("PERSISTENCE-CHECKS.json", json.dumps(self.receipt["persistence"]).encode())
        self.rejected()

    def test_phase9_missing_persistence_document_is_rejected_with_rehashed_manifest(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase9_fixture()
        self.identity = self.receipt["identity"]
        self.rewrite(lambda files: [(info, raw) for info, raw in files
                                   if not info.filename.endswith("/PERSISTENCE-CHECKS.json")], True)
        with self.assertRaisesRegex(package.PackageError, "persistence proof is missing"):
            package.verify_package(self.archive, self.receipt)

    def test_historical_phase8_cannot_be_mislabelled_as_save_import_verified(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase8_fixture()
        self.identity = self.receipt["identity"]
        self.receipt["persistence"] = persistence_proof(self.identity)
        with self.assertRaisesRegex(package.PackageError, "unsupported persistence proof"):
            package.verify_package(self.archive, self.receipt)

    def test_phase8_player_proof_and_historical_phase7_both_verify(self) -> None:
        archive, receipt, _ = self.phase8_fixture()
        report = package.verify_package(archive, receipt, "a" * 40)
        self.assertEqual((report["phase"], report["runtimeChecks"]), (8, 32))
        old_archive, old_receipt, _ = self.phase7_fixture()
        self.assertTrue(package.verify_package(old_archive, old_receipt, "a" * 40)["success"])
        with zipfile.ZipFile(archive) as packed:
            root = package.archive_root(receipt["identity"])
            self.assertEqual(json.loads(packed.read(root + "/PLAYER-CHECKS.json")), receipt["player"])
            self.assertIn("Migratiefase 8", packed.read(root + "/LEESMIJ.txt").decode("utf-8"))

    def test_phase8_runtime_cannot_drop_player_foundation_or_presentation_proof(self) -> None:
        build_identity = {**identity(), "phase": 8, "previewVersion": "0.4.0-phase8"}
        required = package.PRESENTATION_CHECKS | package.FOUNDATION_CHECKS | package.PLAYER_CHECKS
        for missing in required:
            proof = runtime(build_identity)
            proof["checks"] += [{"name": name, "passed": True} for name in sorted(required - {missing})]
            proof["checks"].append({"name": "unrelated_green_check", "passed": True})
            with self.subTest(missing=missing), self.assertRaisesRegex(package.PackageError, "proof"):
                package.package_player(self.player, self.output, build_identity, proof,
                                       foundation(build_identity), player_proof(build_identity))

    def test_phase8_player_details_fail_closed_before_packaging(self) -> None:
        build_identity = {**identity(), "phase": 8, "previewVersion": "0.4.0-phase8"}
        proof = runtime(build_identity)
        proof["checks"] += [{"name": name, "passed": True} for name in sorted(
            package.PRESENTATION_CHECKS | package.FOUNDATION_CHECKS | package.PLAYER_CHECKS)]
        changes = {
            "missing": lambda d: None,
            "stub": lambda d: {**d, "checks": [{"name": "player_stub", "passed": True}]},
            "wrong_source": lambda d: {**d, "identity": {**build_identity, "sourceCommit": "c" * 40}},
            "schema_bool": lambda d: {**d, "schemaVersion": True},
            "failed": lambda d: {**d, "success": False},
            "save_access": lambda d: {**d, "gameSaveAccessed": True},
            "extra_field": lambda d: {**d, "privateLogPath": "must not publish"},
            "failed_detail": lambda d: {**d, "checks": d["checks"] + [{"name": "failed_detail", "passed": False}]},
            "duplicate": lambda d: {**d, "checks": d["checks"] + [d["checks"][0]]},
        }
        for label, edit in changes.items():
            with self.subTest(change=label), self.assertRaises(package.PackageError):
                package.package_player(self.player, self.output, build_identity, proof,
                                       foundation(build_identity), edit(player_proof(build_identity)))

    def test_phase8_each_required_detail_cannot_be_replaced_by_an_unrelated_green_check(self) -> None:
        build_identity = {**identity(), "phase": 8, "previewVersion": "0.4.0-phase8"}
        for missing in package.PLAYER_DETAIL_CHECKS:
            details = player_proof(build_identity)
            details["checks"] = [check for check in details["checks"] if check["name"] != missing]
            details["checks"].append({"name": "unrelated_green_check", "passed": True})
            with self.subTest(missing=missing), self.assertRaisesRegex(package.PackageError, "checks are missing"):
                package.validate_player(details, build_identity)

    def test_phase8_receipt_player_details_must_exactly_match_packaged_proof(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase8_fixture()
        self.identity = self.receipt["identity"]
        self.receipt["player"]["checks"].append({"name": "receipt_only_check", "passed": True})
        with self.assertRaisesRegex(package.PackageError, "Receipt player proof"):
            package.verify_package(self.archive, self.receipt)

    def test_phase8_failed_player_proof_cannot_be_hidden_by_rehashing(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase8_fixture()
        self.identity = self.receipt["identity"]
        self.receipt["player"]["checks"][0]["passed"] = False
        self.change_payload("PLAYER-CHECKS.json", json.dumps(self.receipt["player"]).encode())
        self.rejected()

    def test_phase8_missing_player_detail_document_is_rejected_with_rehashed_manifest(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase8_fixture()
        self.identity = self.receipt["identity"]
        self.rewrite(lambda files: [(info, raw) for info, raw in files
                                   if not info.filename.endswith("/PLAYER-CHECKS.json")], True)
        with self.assertRaisesRegex(package.PackageError, "player proof is missing"):
            package.verify_package(self.archive, self.receipt)

    def test_phase8_missing_native_input_dll_is_rejected_with_rehashed_manifest(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase8_fixture()
        self.identity = self.receipt["identity"]
        self.rewrite(lambda files: [(info, raw) for info, raw in files
                                   if not info.filename.endswith("/" + package.PLAYER_INPUT_DLL)], True)
        with self.assertRaisesRegex(package.PackageError, "Input System runtime is missing"):
            package.verify_package(self.archive, self.receipt)

    def test_phase8_replaced_input_dll_cannot_hide_behind_a_rehashed_zip_manifest(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase8_fixture()
        self.identity = self.receipt["identity"]
        self.change_payload(package.PLAYER_INPUT_DLL, b"Replacement DLL with a valid archive checksum")
        with self.assertRaisesRegex(package.PackageError, "runtime DLL differs"):
            package.verify_package(self.archive, self.receipt)

    def test_phase8_missing_or_malformed_runtime_dependency_witness_is_rejected(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase8_fixture()
        self.identity = self.receipt["identity"]
        valid = copy.deepcopy(self.receipt)
        edits = (
            {"runtimeDllInputs": []}, {"runtimeDllInputs": None}, {"unityPackages": []},
            {"unityPackages": [{"name": "com.unity.inputsystem", "version": "1.0.0", "source": "builtin"}]},
            {"runtimeDllInputs": [dict(valid["runtimeDllInputs"][0], name="../Unity.InputSystem.dll")]},
            {"runtimeDllInputs": [dict(valid["runtimeDllInputs"][0], privateLogPath="not allowed")]},
            {"runtimeDllInputs": valid["runtimeDllInputs"] * 2},
            {"unityPackages": valid["unityPackages"] * 2},
        )
        for edit in edits:
            with self.subTest(edit=edit), self.assertRaises(package.PackageError):
                package.verify_package(self.archive, {**valid, **edit})

    def test_historical_phase7_cannot_be_mislabelled_as_player_verified(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase7_fixture()
        self.identity = self.receipt["identity"]
        self.receipt["player"] = player_proof(self.identity)
        with self.assertRaisesRegex(package.PackageError, "unsupported player proof"):
            package.verify_package(self.archive, self.receipt)

    def test_phase7_foundation_package_and_historical_versions_verify(self) -> None:
        archive, receipt, _ = self.phase7_fixture()
        phase7 = package.verify_package(archive, receipt, "a" * 40)
        phase6_archive, phase6_receipt, _ = self.phase6_fixture()
        self.assertTrue(package.verify_package(phase6_archive, phase6_receipt, "a" * 40)["success"])
        self.assertTrue(package.verify_package(self.archive, self.receipt, "a" * 40)["success"])
        self.assertEqual(phase7["runtimeChecks"], 31)
        self.assertEqual(phase7["phase"], 7)
        with zipfile.ZipFile(archive) as packed:
            root = package.archive_root(receipt["identity"])
            self.assertEqual(json.loads(packed.read(root + "/FOUNDATION-CHECKS.json")), receipt["foundation"])
            self.assertIn("Migratiefase 7", packed.read(root + "/LEESMIJ.txt").decode("utf-8"))

    def test_phase7_cannot_omit_foundation_aggregate_or_any_presentation_witness(self) -> None:
        build_identity = {**identity(), "phase": 7, "previewVersion": "0.3.0-phase7"}
        for missing in sorted(package.PRESENTATION_CHECKS | package.FOUNDATION_CHECKS):
            proof = runtime(build_identity)
            proof["checks"] += [{"name": name, "passed": True} for name in sorted(
                (package.PRESENTATION_CHECKS | package.FOUNDATION_CHECKS) - {missing})]
            proof["checks"].append({"name": "unrelated_green_check", "passed": True})
            with self.subTest(missing=missing), self.assertRaisesRegex(package.PackageError, "proof"):
                package.package_player(self.player, self.output, build_identity, proof, foundation(build_identity))

    def test_phase7_foundation_details_fail_closed_before_packaging(self) -> None:
        build_identity = {**identity(), "phase": 7, "previewVersion": "0.3.0-phase7"}
        proof = runtime(build_identity)
        proof["checks"] += [{"name": name, "passed": True}
                            for name in sorted(package.PRESENTATION_CHECKS | package.FOUNDATION_CHECKS)]
        changes = {
            "missing": lambda d: None,
            "stub": lambda d: {**d, "checks": [{"name": "foundation_stub", "passed": True}]},
            "wrong_source": lambda d: {**d, "identity": {**build_identity, "sourceCommit": "c" * 40}},
            "schema_bool": lambda d: {**d, "schemaVersion": True},
            "failed": lambda d: {**d, "success": False},
            "save_access": lambda d: {**d, "gameSaveAccessed": True},
            "extra_field": lambda d: {**d, "privateLogPath": "must not publish"},
            "failed_detail": lambda d: {**d, "checks": d["checks"][:-1] + [{"name": "failed_detail", "passed": False}]},
            "duplicate": lambda d: {**d, "checks": d["checks"] + [d["checks"][0]]},
        }
        for label, edit in changes.items():
            with self.subTest(change=label), self.assertRaises(package.PackageError):
                package.package_player(self.player, self.output, build_identity, proof, edit(foundation(build_identity)))
        for missing in sorted(package.FOUNDATION_DETAIL_CHECKS):
            details = foundation(build_identity)
            details["checks"] = [check for check in details["checks"] if check["name"] != missing]
            details["checks"].append({"name": "irrelevant_detail", "passed": True})
            with self.subTest(missing=missing), self.assertRaisesRegex(package.PackageError, "world/state/session"):
                package.package_player(self.player, self.output, build_identity, proof, details)

    def test_phase7_receipt_foundation_details_must_exactly_match_packaged_proof(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase7_fixture()
        self.identity = self.receipt["identity"]
        self.receipt["foundation"]["checks"][-1]["name"] = "receipt_only_detail"
        with self.assertRaisesRegex(package.PackageError, "Receipt foundation proof"):
            package.verify_package(self.archive, self.receipt, "a" * 40)

    def test_phase7_failed_details_cannot_be_hidden_by_rehashing_archive_and_receipt(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase7_fixture()
        self.identity = self.receipt["identity"]
        self.receipt["foundation"]["checks"][-1]["passed"] = False
        self.change_payload("FOUNDATION-CHECKS.json", json.dumps(self.receipt["foundation"]).encode())
        with self.assertRaisesRegex(package.PackageError, "failed check"):
            package.verify_package(self.archive, self.receipt, "a" * 40)

    def test_phase7_missing_oracle_case_cannot_be_hidden_by_rehashing_archive_and_receipt(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase7_fixture()
        self.identity = self.receipt["identity"]
        details = self.receipt["foundation"]
        details["checks"] = [check for check in details["checks"]
                             if check["name"] != "foundation_source_condition_26"]
        details["checks"].append({"name": "unrelated_green_detail", "passed": True})
        self.change_payload("FOUNDATION-CHECKS.json", json.dumps(details).encode())
        with self.assertRaisesRegex(package.PackageError, "world/state/session"):
            package.verify_package(self.archive, self.receipt, "a" * 40)

    def test_phase7_missing_native_source_decode_cannot_be_hidden_by_rehashing(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase7_fixture()
        self.identity = self.receipt["identity"]
        details = self.receipt["foundation"]
        details["checks"] = [check for check in details["checks"]
                             if check["name"] != "foundation_all_221_source_documents_native_decoded"]
        details["checks"].append({"name": "unrelated_green_detail", "passed": True})
        self.change_payload("FOUNDATION-CHECKS.json", json.dumps(details).encode())
        with self.assertRaisesRegex(package.PackageError, "world/state/session"):
            package.verify_package(self.archive, self.receipt, "a" * 40)

    def test_phase7_missing_detail_document_is_rejected_even_with_rehashed_manifest(self) -> None:
        self.archive, self.receipt, self.runtime = self.phase7_fixture()
        self.identity = self.receipt["identity"]
        self.rewrite(lambda files: [(info, raw) for info, raw in files
                                   if not info.filename.endswith("/FOUNDATION-CHECKS.json")], True)
        with self.assertRaisesRegex(package.PackageError, "foundation proof is missing"):
            package.verify_package(self.archive, self.receipt, "a" * 40)

    def test_historical_preview_cannot_be_mislabelled_as_foundation_verified(self) -> None:
        details = foundation(self.identity)
        with self.assertRaisesRegex(package.PackageError, "Historical preview"):
            package.package_player(self.player, self.output, self.identity, self.runtime, details)
        self.receipt["foundation"] = details
        with self.assertRaisesRegex(package.PackageError, "Historical preview"):
            package.verify_package(self.archive, self.receipt, "a" * 40)

    def test_unsupported_phase_and_cross_phase_preview_version_are_rejected(self) -> None:
        for phase, preview in ((4, "0.2.0-phase6"), (True, "0.2.0-phase6"),
                               (6, "0.1.0-phase3"), (3, "0.2.0-phase6"),
                               (7, "0.2.0-phase6"), (6, "0.3.0-phase7")):
            with self.subTest(phase=phase, preview=preview), self.assertRaises(package.PackageError):
                package.validate_identity({**identity(), "phase": phase, "previewVersion": preview})

    def test_packaging_is_deterministic(self) -> None:
        second = self.base / "second"
        second.mkdir()
        rebuilt, _ = package.package_player(self.player, second, self.identity, self.runtime)
        self.assertEqual(self.archive.read_bytes(), rebuilt.read_bytes())

    def test_package_never_overwrites_previous_results(self) -> None:
        before = self.archive.read_bytes()
        with self.assertRaises(package.PackageError):
            package.package_player(self.player, self.output, self.identity, self.runtime)
        self.assertEqual(before, self.archive.read_bytes())

    def test_outer_checksum_detects_byte_tampering(self) -> None:
        raw = bytearray(self.archive.read_bytes())
        raw[len(raw) // 2] ^= 1
        self.archive.write_bytes(raw)
        self.rejected()

    def test_source_must_match_trusted_git_commit(self) -> None:
        with self.assertRaises(package.PackageError):
            package.verify_package(self.archive, self.receipt, "c" * 40)

    def test_renamed_version_is_rejected(self) -> None:
        renamed = self.archive.with_name("Godot-game.zip")
        self.archive.rename(renamed)
        with self.assertRaises(package.PackageError):
            package.verify_package(renamed, self.receipt)

    def test_phase2_identity_is_not_silently_accepted(self) -> None:
        self.receipt["identity"] = {**self.identity, "phase": 2}
        self.rejected()

    def test_identity_boolean_is_not_a_schema_number(self) -> None:
        self.receipt["identity"] = {**self.identity, "schemaVersion": True}
        self.rejected()

    def test_zero_commit_or_fingerprint_cannot_identify_a_build(self) -> None:
        for name, zero in (("sourceCommit", "0" * 40), ("inputFingerprint", "0" * 64)):
            with self.subTest(field=name):
                changed = {**self.identity, name: zero}
                with self.assertRaises(package.PackageError):
                    package.validate_identity(changed)

    def test_manifest_detects_changed_file_even_when_outer_receipt_is_replaced(self) -> None:
        self.change_payload("BlueMapUnityProbe.exe", pe_stub() + b"changed", False)
        self.rejected()

    def test_missing_engine_file_rejected_even_with_rehashed_manifest(self) -> None:
        self.rewrite(lambda files: [(info, raw) for info, raw in files
                                   if not info.filename.endswith("/UnityPlayer.dll")], True)
        self.rejected()

    def test_unlisted_extra_file_rejected(self) -> None:
        name = package.archive_root(self.identity) + "/BlueMapUnityProbe_Data/extra.bin"
        self.rewrite(lambda files: files + [(zipfile.ZipInfo(name), b"extra")])
        self.rejected()

    def test_path_attacks_rejected_before_extraction(self) -> None:
        for suffix in ("../escape.txt", "/absolute.txt", "C:/escape.txt", "\\server\\share",
                       "BlueMapUnityProbe_Data/../escape.txt", "BlueMapUnityProbe_Data/CON.txt",
                       "BlueMapUnityProbe_Data/trailing. "):
            with self.subTest(path=suffix):
                # Restore from a new valid deterministic build for each attack.
                self.archive.unlink()
                self.archive, _ = package.package_player(self.player, self.output,
                                                         self.identity, self.runtime)
                name = package.archive_root(self.identity) + "/" + suffix
                self.rewrite(lambda files: files + [(zipfile.ZipInfo(name), b"attack")])
                self.rejected()

    def test_duplicate_windows_case_path_rejected(self) -> None:
        name = package.archive_root(self.identity) + "/BlueMapUnityProbe.EXE"
        self.rewrite(lambda files: files + [(zipfile.ZipInfo(name), pe_stub())])
        self.rejected()

    def test_zip_symlink_rejected(self) -> None:
        def symlink(files):
            files[0][0].create_system = 3
            files[0][0].external_attr = 0o120777 << 16
            return files
        self.rewrite(symlink)
        self.rejected()

    def test_encrypted_flag_rejected(self) -> None:
        raw = bytearray(self.archive.read_bytes())
        local = raw.index(b"PK\x03\x04")
        central = raw.index(b"PK\x01\x02")
        struct.pack_into("<H", raw, local + 6, struct.unpack_from("<H", raw, local + 6)[0] | 1)
        struct.pack_into("<H", raw, central + 8, struct.unpack_from("<H", raw, central + 8)[0] | 1)
        self.archive.write_bytes(raw)
        self.refresh_receipt()
        self.rejected()

    def test_raw_logs_and_activation_files_rejected(self) -> None:
        for name in ("BlueMapUnityProbe_Data/player.log", "BlueMapUnityProbe_Data/Unity_lic.ulf",
                     "BlueMapUnityProbe_Data/private-logs/editor.txt",
                     "BlueMapUnityProbe_Data/personal.lic", "BlueMapUnityProbe_Data/savegame.cfg"):
            with self.subTest(path=name):
                self.archive.unlink()
                self.archive, _ = package.package_player(self.player, self.output,
                                                         self.identity, self.runtime)
                full = package.archive_root(self.identity) + "/" + name
                self.rewrite(lambda files: files + [(zipfile.ZipInfo(full), b"must not publish")], True)
                self.rejected()

    def test_packager_rejects_private_file(self) -> None:
        (self.player / "BlueMapUnityProbe_Data" / "player.log").write_text("private")
        second = self.base / "second"
        second.mkdir()
        with self.assertRaises(package.PackageError):
            package.package_player(self.player, second, self.identity, self.runtime)

    def test_non_x64_player_rejected_even_with_rehashed_manifest(self) -> None:
        raw = bytearray(pe_stub())
        struct.pack_into("<H", raw, 68, 0x14C)
        self.change_payload("BlueMapUnityProbe.exe", bytes(raw))
        self.rejected()

    def test_runtime_identity_does_not_match_receipt(self) -> None:
        changed = copy.deepcopy(self.runtime)
        changed["identity"]["inputFingerprint"] = "c" * 64
        self.change_payload("RUNTIME-CHECKS.json", json.dumps(changed).encode())
        self.rejected()

    def test_receipt_rendering_facts_must_match_runtime(self) -> None:
        self.receipt["frames"] = self.runtime["frames"] + 1
        self.rejected()

    def test_failed_or_missing_rendered_checks_rejected(self) -> None:
        changed = copy.deepcopy(self.runtime)
        changed["checks"][0]["passed"] = False
        self.change_payload("RUNTIME-CHECKS.json", json.dumps(changed).encode())
        self.rejected()

    def test_embedded_identity_and_preview_version_checks_are_required(self) -> None:
        for required in ("embedded_identity_consistent", "preview_version"):
            with self.subTest(check=required):
                changed = copy.deepcopy(self.runtime)
                changed["checks"] = [check for check in changed["checks"] if check["name"] != required]
                # An unrelated successful check cannot replace identity coverage.
                changed["checks"].append({"name": "unrelated_probe_check", "passed": True})
                with self.assertRaises(package.PackageError):
                    package.package_player(self.player, self.output, self.identity, changed)

    def test_receipt_checks_must_match_runtime_checks(self) -> None:
        self.receipt["checks"] = self.runtime["checks"][:-1]
        self.rejected()

    def test_duplicate_json_keys_rejected(self) -> None:
        self.change_payload("RUNTIME-CHECKS.json", b'{"success":true,"success":true}')
        self.rejected()

    def test_existing_game_save_access_is_rejected(self) -> None:
        changed = copy.deepcopy(self.runtime)
        changed["gameSaveAccessed"] = True
        self.change_payload("RUNTIME-CHECKS.json", json.dumps(changed).encode())
        self.rejected()

    def test_archive_crc_failure_is_rejected(self) -> None:
        # Re-encode as stored bytes, then break a payload without updating ZIP CRC.
        def stored(files):
            for info, _ in files:
                info.compress_type = zipfile.ZIP_STORED
            return files
        self.rewrite(stored)
        with zipfile.ZipFile(self.archive) as archive:
            target = next(info for info in archive.infolist()
                          if info.filename.endswith("/BlueMapUnityProbe.exe"))
        raw = bytearray(self.archive.read_bytes())
        offset = target.header_offset
        name_length, extra_length = struct.unpack_from("<HH", raw, offset + 26)
        raw[offset + 30 + name_length + extra_length + 100] ^= 1
        self.archive.write_bytes(raw)
        self.refresh_receipt()
        self.rejected()

    def test_wrong_player_company_rejected(self) -> None:
        self.change_payload("BlueMapUnityProbe_Data/app.info", b"RealGame\nBlueMapQuest\n")
        self.rejected()

    def test_unexpected_runtime_fields_cannot_leak_paths(self) -> None:
        changed = {**self.runtime, "privateLogPath": "C:/Users/player/private.log"}
        self.change_payload("RUNTIME-CHECKS.json", json.dumps(changed).encode())
        self.rejected()

    def test_archive_comment_is_not_published(self) -> None:
        with zipfile.ZipFile(self.archive, "a") as archive:
            archive.comment = b"unreviewed hidden metadata"
        self.refresh_receipt()
        self.rejected()

    def test_zip_declared_size_limit_rejected_before_decompression(self) -> None:
        raw = bytearray(self.archive.read_bytes())
        central = raw.index(b"PK\x01\x02")
        struct.pack_into("<I", raw, central + 24, package.MAX_FILE_BYTES + 1)
        self.archive.write_bytes(raw)
        self.refresh_receipt()
        self.rejected()

    def test_member_directory_is_not_a_runtime_file(self) -> None:
        full = package.archive_root(self.identity) + "/BlueMapUnityProbe_Data/new-directory/"
        info = zipfile.ZipInfo(full)
        info.external_attr = 0o40755 << 16
        self.rewrite(lambda files: files + [(info, b"")])
        self.rejected()

    def test_cli_verifies_and_writes_a_separate_report(self) -> None:
        receipt_path = self.base / "receipt.json"
        receipt_path.write_text(json.dumps(self.receipt), encoding="utf-8")
        report_path = self.base / "verified.json"
        result = subprocess.run([
            sys.executable, str(Path(package.__file__)), "--package", str(self.archive),
            "--receipt", str(receipt_path), "--expected-source-commit", "a" * 40,
            "--output", str(report_path),
        ], check=False, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("UNITY PACKAGE OK", result.stdout)
        self.assertTrue(json.loads(report_path.read_text(encoding="utf-8"))["success"])


if __name__ == "__main__":
    unittest.main()
