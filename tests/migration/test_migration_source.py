"""Synthetic corruption checks; never edit the real game or its save files."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location("migration_source", Path(__file__).resolve().parents[2] / "tools/check_migration.py")
source = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(source)


class SourcePreservationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="bluemap-source-fixture-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.baseline = {"project.godot": b"[application]\nconfig/name=\"BlueMap\"\n",
                         "assets/actor.png": b"\x89PNG\x00\r\n\xff",
                         "tests/smoke_test.gd": b"extends SceneTree\n",
                         "README.md": b"old explanation\n"}
        for name, blob in self.baseline.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(blob)

    def validate(self):
        return source.validate_godot_worktree(self.root, self.baseline)

    def test_same_game_and_windows_text_line_endings_pass(self):
        (self.root / "project.godot").write_bytes(self.baseline["project.godot"].replace(b"\n", b"\r\n"))
        self.assertEqual(self.validate()["filesCompared"], 3)

    def test_documentation_can_describe_migration(self):
        (self.root / "README.md").write_text("two separate downloads\n", encoding="utf-8")
        self.validate()

    def test_deleted_current_game_is_rejected_even_with_reference_present(self):
        (self.root / "project.godot").unlink()
        with self.assertRaisesRegex(source.MigrationError, "missing"):
            self.validate()

    def test_game_rule_change_is_rejected(self):
        (self.root / "project.godot").write_bytes(b"changed autoload\n")
        with self.assertRaisesRegex(source.MigrationError, "changed"):
            self.validate()

    def test_binary_line_endings_are_not_normalized(self):
        (self.root / "assets/actor.png").write_bytes(self.baseline["assets/actor.png"].replace(b"\r\n", b"\n"))
        with self.assertRaisesRegex(source.MigrationError, "changed"):
            self.validate()

    def test_utf8_decodable_binary_is_still_compared_exactly(self):
        self.baseline["assets/actor.png"] = b"binary\r\nbytes"
        (self.root / "assets/actor.png").write_bytes(b"binary\nbytes")
        with self.assertRaisesRegex(source.MigrationError, "changed"):
            self.validate()

    def test_existing_test_cannot_be_deleted(self):
        (self.root / "tests/smoke_test.gd").unlink()
        with self.assertRaises(source.MigrationError):
            self.validate()

    def test_unsafe_reference_path_is_rejected(self):
        with self.assertRaisesRegex(source.MigrationError, "Unsafe"):
            source.validate_godot_worktree(self.root, {"../outside": b"bad"})

    def test_staged_deletion_is_rejected_even_when_file_still_exists(self):
        manifest = {"files": [{"path": "project.godot", "mode": "100644", "git_blob": "a" * 40}]}
        with self.assertRaisesRegex(source.MigrationError, "index entry"):
            source.validate_godot_index(manifest, {})

    def test_staged_edit_is_rejected_even_when_worktree_was_restored(self):
        manifest = {"files": [{"path": "project.godot", "mode": "100644", "git_blob": "a" * 40}]}
        with self.assertRaisesRegex(source.MigrationError, "index entry"):
            source.validate_godot_index(manifest, {"project.godot": ("100644", "b" * 40, "0")})

    def test_original_staged_blob_passes(self):
        manifest = {"files": [{"path": "project.godot", "mode": "100644", "git_blob": "a" * 40}]}
        source.validate_godot_index(manifest, {"project.godot": ("100644", "a" * 40, "0")})


class UnitySourceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="bluemap-unity-fixture-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "Assets/Scenes").mkdir(parents=True)
        (self.root / "ProjectSettings").mkdir()
        self.folder_guid = "a" * 32
        self.scene_guid = "b" * 32
        self.meta("Assets/Scenes", self.folder_guid, folder=True)
        self.write("Assets/Scenes/Start.unity", "%YAML 1.1\n")
        self.meta("Assets/Scenes/Start.unity", self.scene_guid)
        self.settings()
        self.write("ProjectSettings/ProjectVersion.txt",
                   f"m_EditorVersion: {source.EDITOR_VERSION}\n"
                   f"m_EditorVersionWithRevision: {source.EDITOR_VERSION} ({source.EDITOR_REVISION})\n")

    def write(self, name, text):
        (self.root / name).write_text(text, encoding="utf-8")

    def meta(self, name, guid, folder=False):
        self.write(name + ".meta", "fileFormatVersion: 2\nguid: " + guid + "\n" +
                   ("folderAsset: yes\n" if folder else ""))

    def settings(self, name="Assets/Scenes/Start.unity", guid=None):
        self.write("ProjectSettings/EditorBuildSettings.asset", "EditorBuildSettings:\n  m_Scenes:\n"
                   "  - enabled: 1\n    path: " + name + "\n    guid: " + (guid or self.scene_guid) + "\n")

    def test_valid_project_passes_without_editor(self):
        source.validate_editor(self.root)
        self.assertEqual(source.validate_assets(self.root), {"assetGuids": 2, "buildScenes": 1})

    def test_wrong_editor_revision_is_rejected(self):
        path = self.root / "ProjectSettings/ProjectVersion.txt"
        path.write_text(path.read_text().replace(source.EDITOR_REVISION, "000000000000"), encoding="utf-8")
        with self.assertRaisesRegex(source.MigrationError, "revision"):
            source.validate_editor(self.root)

    def test_missing_file_meta_is_rejected(self):
        (self.root / "Assets/Scenes/Start.unity.meta").unlink()
        with self.assertRaisesRegex(source.MigrationError, "no meta"):
            source.validate_assets(self.root)

    def test_missing_folder_meta_is_rejected(self):
        (self.root / "Assets/Scenes.meta").unlink()
        with self.assertRaisesRegex(source.MigrationError, "no meta"):
            source.validate_assets(self.root)

    def test_duplicate_guid_is_rejected(self):
        self.meta("Assets/Scenes/Start.unity", self.folder_guid)
        with self.assertRaisesRegex(source.MigrationError, "Duplicate"):
            source.validate_assets(self.root)

    def test_orphan_meta_is_rejected(self):
        self.meta("Assets/ghost", "c" * 32)
        with self.assertRaisesRegex(source.MigrationError, "Orphan"):
            source.validate_assets(self.root)

    def test_malformed_guid_is_rejected(self):
        self.meta("Assets/Scenes/Start.unity", "broken")
        with self.assertRaisesRegex(source.MigrationError, "valid GUID"):
            source.validate_assets(self.root)

    def test_build_scene_guid_mismatch_is_rejected(self):
        self.settings(guid="c" * 32)
        with self.assertRaisesRegex(source.MigrationError, "does not resolve"):
            source.validate_assets(self.root)

    def test_build_scene_escape_is_rejected(self):
        self.settings(name="../outside.unity")
        with self.assertRaisesRegex(source.MigrationError, "Unsafe"):
            source.validate_assets(self.root)

    def test_empty_build_scene_list_is_rejected(self):
        self.write("ProjectSettings/EditorBuildSettings.asset", "EditorBuildSettings:\n  m_Scenes: []\n")
        with self.assertRaisesRegex(source.MigrationError, "No enabled"):
            source.validate_assets(self.root)


class PackagesAndTrackedFilesTests(unittest.TestCase):
    def setUp(self):
        self.module = "com.unity.modules.physics2d"
        self.manifest = {"dependencies": {self.module: "1.0.0"}}
        self.lock = {"dependencies": {self.module: {"source": "builtin", "version": "1.0.0",
                                                    "depth": 0, "dependencies": {}}}}

    def test_pinned_builtins_pass(self):
        self.assertEqual(source.validate_packages(self.manifest, self.lock)["externalDependencies"], 0)

    def test_only_audited_official_input_system_is_allowed(self):
        manifest = source.read_json(Path(__file__).resolve().parents[2] / "unity/Packages/manifest.json")
        locked = source.read_json(Path(__file__).resolve().parents[2] / "unity/Packages/packages-lock.json")
        self.assertEqual(source.validate_packages(manifest, locked)["externalDependencies"], 1)
        for field, bad in (("version", "1.20.2"), ("source", "git"), ("url", "https://example.com"),
                           ("dependencies", {})):
            with self.subTest(field=field):
                changed = copy.deepcopy(locked)
                changed["dependencies"]["com.unity.inputsystem"][field] = bad
                with self.assertRaisesRegex(source.MigrationError, "audited"):
                    source.validate_packages(manifest, changed)

    def test_external_registry_package_is_rejected(self):
        self.lock["dependencies"][self.module]["source"] = "registry"
        with self.assertRaisesRegex(source.MigrationError, "built-in"):
            source.validate_packages(self.manifest, self.lock)

    def test_version_drift_is_rejected(self):
        self.manifest["dependencies"][self.module] = "2.0.0"
        with self.assertRaisesRegex(source.MigrationError, "differ"):
            source.validate_packages(self.manifest, self.lock)

    def test_missing_transitive_module_is_rejected(self):
        self.lock["dependencies"][self.module]["dependencies"]["com.unity.modules.audio"] = "1.0.0"
        with self.assertRaisesRegex(source.MigrationError, "Missing"):
            source.validate_packages(self.manifest, self.lock)

    def test_unreachable_lock_entry_is_rejected(self):
        entry = copy.deepcopy(self.lock["dependencies"][self.module])
        entry["depth"] = 1
        self.lock["dependencies"]["com.unity.modules.audio"] = entry
        with self.assertRaisesRegex(source.MigrationError, "unreachable"):
            source.validate_packages(self.manifest, self.lock)

    def test_duplicate_json_keys_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text('{"dependencies":{},"dependencies":{}}', encoding="utf-8")
            with self.assertRaisesRegex(source.MigrationError, "Duplicate"):
                source.read_json(path)

    def test_registered_source_is_allowed(self):
        result = source.validate_registered_sources(["unity/Assets/Player.cs", "unity/Assets/Player.cs.meta",
                                                     "unity/ProjectSettings/ProjectVersion.txt"])
        self.assertEqual(result["registeredUnityFiles"], 3)

    def test_tracked_local_outputs_and_license_files_are_rejected(self):
        for name in ["unity/Library/cache.bin", "unity/Temp/probe", "unity/UserSettings/layout.wlt",
                     "unity/Logs/Editor.log", "unity/Build/Game.exe", "unity/Unity_lic.ulf",
                     "unity/license.alf", "unity/Assets/Editor.log", "unity/Probe.csproj"]:
            with self.subTest(name=name), self.assertRaises(source.MigrationError):
                source.validate_registered_sources([name])


if __name__ == "__main__":
    unittest.main()
