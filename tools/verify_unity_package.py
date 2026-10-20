#!/usr/bin/env python3
"""Create and verify explicitly identified Windows technical previews.

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
PREVIEW_VERSIONS = {3: PREVIEW_VERSION, 6: "0.2.0-phase6", 7: "0.3.0-phase7",
                    8: "0.4.0-phase8", 9: "0.5.0-phase9", 10: "0.6.0-phase10", 11: "0.7.0-phase11"}
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
    "gpu_premultiplied_pixels_exact",
}
FOUNDATION_CHECKS = {"foundation_runtime_verified"}
FOUNDATION_DETAIL_CHECKS = {
    "foundation_metadata_kind_document_context_lossless",
    "foundation_source_float64_oracle_strict",
    "foundation_world_checks_ran", "foundation_state_checks_ran", "foundation_session_checks_ran",
    "foundation_original_godot_oracle_available", "foundation_source_oracle_count",
    "foundation_world_37_maps_49758_tiles", "foundation_world_980_stable_slots",
    "foundation_all_221_source_documents_native_decoded",
    "foundation_native_physics_layers_and_player_foot",
    "foundation_native_godot_or_masks_real_contacts",
    "foundation_state_all_34_save_fields", "foundation_state_unknown_fields_lossless",
    "session_state_survives_transition", "session_missing_map_does_not_commit",
    "session_missing_arrival_does_not_commit",
} | {f"foundation_source_condition_{index}" for index in range(1, 27)} \
  | {f"foundation_source_clock_{index}" for index in range(1, 10)} \
  | {f"foundation_source_target_{index}" for index in range(1, 7)}
FOUNDATION_FIELDS = {"schemaVersion", "identity", "success", "gameSaveAccessed", "checks"}
PLAYER_CHECKS = {"player_runtime_verified"}
PLAYER_DETAIL_CHECKS = {
    "player_motion_checks_ran", "player_input_checks_ran", "player_world_checks_ran",
    "player_motion_oracle_complete", "player_input_oracle_complete",
    "player_world_source_collision", "player_camera_bounds", "player_body_faces_movement",
    "player_aim_independent",
    "player_input_real_package_virtual_devices", "player_input_all_36_source_actions_native_bindings",
    "player_input_all_binding_releases_no_latched_action", "player_input_keyboard_diagonal_normalized",
    "player_input_opposite_directions_cancel", "player_input_original_ctrl_sprint_shift_roll",
    "player_input_16_original_circular_deadzone_vectors", "player_input_switch_threshold_and_mouse_drift",
    "player_input_held_controller_does_not_steal_mouse", "player_input_old_held_keyboard_requires_fresh_press",
    "player_input_switching_press_works_once_and_releases", "player_input_wheel_activates_mouse_and_scrolls",
    "player_input_right_stick_aim_and_ui_scroll", "player_input_original_cursor_context_policy",
    "player_input_controller_disconnect_reconnect", "player_input_one_selected_gamepad",
    "player_input_focus_loss_releases_without_ghost_resume", "player_input_rebind_swap_reservations_and_reset",
    "player_input_no_real_hardware_or_save_claim",
    "player_input_both_modifier_sides_preserved", "player_input_real_event_rebind_capture_and_cancel",
    "player_input_device_lifecycle_no_callback_errors",
    "player_motion_partial_last_sprint_step", "player_motion_delayed_exhaustion_recovery",
    "player_motion_equipment_reduction_never_refills", "player_motion_invalid_spend_restore_rejected",
    "player_motion_corrupt_stamina_clamped", "player_motion_blocked_sprint_uses_no_energy",
    "player_motion_body_facing_independent_of_crosshair", "player_motion_transition_stops_without_stamina_refill",
    "player_motion_pause_freezes_timers_and_stamina", "player_motion_input_lock_freezes_stamina",
    "player_motion_footsteps_distance_remainder_single_event", "player_motion_frame_cannot_be_applied_twice",
    "player_motion_nonfinite_delta_rejected", "player_motion_roll_safe_window_strict_boundary",
    "player_motion_stamina_exact_source_oracle", "player_motion_surfaces_exact_source_oracle",
    "player_motion_equipment_exact_source_oracle", "player_motion_velocity_facing_exact_source_oracle",
    "player_motion_roll_exact_source_oracle", "player_motion_transition_exact_source_oracle",
    "player_motion_float32_products_round_before_sum", "player_world_avatar_rendered_on_gpu",
    "player_world_three_preview_maps_load", "player_world_source_footsteps_play_after_actual_walk",
}
PLAYER_FIELDS = {"schemaVersion", "identity", "success", "gameSaveAccessed", "checks"}
PERSISTENCE_CHECKS = {"persistence_runtime_verified"}
PERSISTENCE_DETAIL_CHECKS = {
    "persistence_save_model_checks_ran", "persistence_settings_checks_ran", "persistence_store_checks_ran",
    "persistence_save_source_oracle_complete", "persistence_settings_source_oracle_complete",
    "persistence_source_read_only", "persistence_atomic_failure_preserves_previous",
    "persistence_unknown_fields_lossless", "persistence_no_real_saves_accessed",
    "persistence_fixture_import_opens", "persistence_import_keeps_adventure", "persistence_restart_roundtrip",
    "persistence_cosmetic_corruption_archived", "persistence_settings_revision_saved",
    "persistence_original_state_not_replaced_by_preview", "persistence_repeated_import_idempotent",
    "persistence_stale_writer_rejected", "persistence_restore_previous_revision",
    "persistence_corrupt_pointer_not_silently_reset", "persistence_explicit_recovery_after_corruption",
    "persistence_source_target_separated", "persistence_profile_traversal_rejected",
    "persistence_archive_traversal_rejected", "persistence_package_content_damage_rejected",
    "persistence_concurrent_source_change_rejected", "persistence_plain_kind_is_data",
    "persistence_malformed_json_rejected", "persistence_revisions_and_pointer_backups_retained",
    "persistence_truncated_zip_does_not_crash_or_replace_active",
    "persistence_save_unknown_fields_retained", "persistence_save_legacy_flags_and_atlas_distinct",
    "persistence_save_new_adventure_flag_not_leaked", "persistence_save_global_meta_keys_merge_without_rewards",
    "persistence_save_malformed_imports_do_not_construct_partial_state",
    "persistence_settings_preferences_roundtrip", "persistence_settings_unknown_sections_bytes_retained",
    "persistence_settings_malformed_files_safe_defaults", "persistence_settings_legacy_shortcuts_avoid_existing_bindings",
    "persistence_settings_physical_keys_modifiers_retained", "persistence_settings_empty_bindings_retained",
    "persistence_settings_legacy_duplicate_bindings_retained", "persistence_settings_achievement_presence_semantics",
    "persistence_settings_no_object_instantiation", "persistence_settings_original_bytes_immutable",
    "persistence_settings_bounded_untrusted_config", "persistence_settings_imported_real_keyboard_modifiers",
    "persistence_settings_rebind_restore_notifications", "persistence_settings_import_cannot_remove_fixed_menu_controls",
}
PERSISTENCE_FIELDS = {"schemaVersion", "identity", "success", "gameSaveAccessed", "checks"}
ROUTE_CHECKS = {"route_runtime_verified"}
ROUTE_DETAIL_CHECKS = {
    "route_model_checks_ran", "route_source_oracle_complete", "route_world_checks_ran",
    "route_village_home_forest_transitions", "route_transition_state_preserved",
    "route_inventory_ui_verified", "route_dialogue_ui_verified", "route_persistence_roundtrip",
    "route_no_real_saves_accessed",
    "route_quest_rewards_idempotent", "route_cat_calm_and_panic",
    "route_harvest_cooldowns_and_tools", "route_chest_atomic_rewards",
    "route_unknown_fields_retained", "route_rest_source_policy",
    "route_profiles_are_safe_copies", "route_save_failure_preserves_progress",
    "route_controller_navigation_verified",
    "route_inventory_sustained_right_stick_keeps_focus", "route_unconnected_exit_keeps_player_inside_map",
    "route_dialogue_reward_commits_coherently", "route_modal_actions_and_calm_paused",
    "route_invalid_transaction_preserves_state", "route_observer_failure_cannot_duplicate_rewards",
    "route_pickup_unique_claim_and_full_hearts",
    "route_source_gear_base", "route_source_gear_worn_pack", "route_source_gear_owned_not_worn",
    "route_source_gear_negative_speed",
    "route_original_art_source_nodes", "route_original_art_gpu_pixels_exact",
    "route_saved_home_layout_and_appearance_verified",
} | {"route_source_" + name for name in (
    "pim_accept", "pim_decline", "pim_cancel_unread", "bram_accept", "cat_wait_then_find",
    "cat_without_quest", "cat_panic", "cat_calm_interrupted", "pim_reward_once", "pim_reward_level",
    "pim_max_hearts", "chest_basic", "chest_owned_unique", "chest_partial_stack_refused", "chest_heart",
    "gather_active_cooldown", "gather_missing_tool", "gather_strong_tool", "gather_level_required",
    "gather_xp_cap", "rest_no_time_skip", "pickup_coin", "pickup_heart_full", "pickup_heart_hurt",
    "pickup_crystal", "pickup_item_full",
)}
ROUTE_FIELDS = {"schemaVersion", "identity", "success", "gameSaveAccessed", "checks"}
WORLD_ACCESS_CHECKS = {"world_access_runtime_verified"}
WORLD_ACCESS_DETAIL_CHECKS = {
    "world_access_model_checks_ran", "world_access_source_oracle_complete",
    "world_access_all_37_maps_available", "world_access_original_quest_locks",
    "world_access_safe_arrivals", "world_access_native_portal_transitions",
    "world_access_original_art_preserved", "world_access_no_real_saves_accessed",
    "world_access_native_arrivals_fit", "world_access_no_fixture_state_injected",
    "world_access_visits_record_actual_37_maps", "world_access_native_locked_portals_stay_closed",
    "world_access_native_boats_free_and_validated", "world_access_native_boat_cancel_preserves_state",
    "world_access_native_boat_controller_navigation",
    "world_access_loaded_area_retained", "world_access_native_checks_ran",
    "world_access_failed_travel_is_atomic", "world_access_native_gate_key_and_collision",
    "world_access_source_all_162_snapshots", "world_access_source_portal_conditions",
    "world_access_source_gate_conditions", "world_access_source_safe_arrivals",
    "world_access_source_safe_spawn_search", "world_access_source_boat_routes",
    "world_access_no_fixture_progress_applied", "world_access_unknown_fields_retained",
    "world_access_gate_transaction_idempotent", "world_access_tide_occupied_bank_safe",
    "world_access_seal_earned_timing", "world_access_independent_earned_restoration",
    "world_access_unknown_conditions_fail_closed",
    *("world_access_source_case_" + name for name in (
        "gate_no_key", "gate_key", "gate_open_not_interactable", "conditions_fresh",
        "conditions_iron_main", "conditions_both_targets", "boat_distance_0", "boat_distance_6400",
        "boat_distance_6401", "boat_forged_target", "seal_unearned", "seal_earned_timing",
        "tide_occupied_then_released", "world_legacy_migrations", "world_migrations_idempotent")),
    "world_art_all_registered_maps", "world_art_snapshot_variants_available",
    "world_art_native_rgba_exact", "world_art_gpu_pixels_exact", "world_render_all_37_source_maps",
}
WORLD_ACCESS_FIELDS = {"schemaVersion", "identity", "success", "gameSaveAccessed", "checks"}
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
PLAYER_INPUT_DLL = "BlueMapUnityProbe_Data/Managed/Unity.InputSystem.dll"
PE_FILES = {
    "BlueMapUnityProbe.exe", "UnityPlayer.dll", "UnityCrashHandler64.exe",
    "MonoBleedingEdge/EmbedRuntime/mono-2.0-bdwgc.dll",
    "MonoBleedingEdge/EmbedRuntime/MonoPosixHelper.dll",
}
PLAYER_ROOTS = {
    "BlueMapUnityProbe.exe", "UnityPlayer.dll", "UnityCrashHandler64.exe",
    "MonoBleedingEdge", "BlueMapUnityProbe_Data", "D3D12",
}
METADATA_FILES = {"BUILD-IDENTITY.json", "RUNTIME-CHECKS.json", "FOUNDATION-CHECKS.json",
                  "PLAYER-CHECKS.json", "PERSISTENCE-CHECKS.json", "ROUTE-CHECKS.json", "WORLD-ACCESS-CHECKS.json", "FILES.json", "LEESMIJ.txt"}
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
    if identity["phase"] >= 6:
        require(PRESENTATION_CHECKS <= {check["name"] for check in result["checks"]},
                f"Phase {identity['phase']} presentation proof is incomplete")
    if identity["phase"] >= 7:
        require(FOUNDATION_CHECKS <= {check["name"] for check in result["checks"]},
                "Phase 7 foundation runtime proof is incomplete")
    if identity["phase"] >= 8:
        require(PLAYER_CHECKS <= {check["name"] for check in result["checks"]},
                "Phase 8 player runtime proof is incomplete")
    if identity["phase"] >= 9:
        require(PERSISTENCE_CHECKS <= {check["name"] for check in result["checks"]},
                "Phase 9 persistence runtime proof is incomplete")
    if identity["phase"] >= 10:
        require(ROUTE_CHECKS <= {check["name"] for check in result["checks"]},
                "Phase 10 route runtime proof is incomplete")
    if identity["phase"] >= 11:
        require(WORLD_ACCESS_CHECKS <= {check["name"] for check in result["checks"]},
                "Phase 11 world access runtime proof is incomplete")


def validate_foundation(result: dict, identity: dict) -> None:
    """Bind every foundation witness to this exact isolated player build."""
    require(isinstance(result, dict) and set(result) == FOUNDATION_FIELDS,
            "Phase 7 foundation proof has missing or unexpected fields")
    require(result.get("schemaVersion") == 1 and type(result.get("schemaVersion")) is int,
            "Unsupported foundation proof schema")
    require(result.get("identity") == identity, "Foundation embedded identity differs from package identity")
    require(result.get("success") is True and result.get("gameSaveAccessed") is False,
            "Foundation proof failed or accessed existing game saves")
    checks = result.get("checks")
    require(isinstance(checks, list) and len(checks) >= 10, "Foundation detail checks are missing")
    names = set()
    for check in checks:
        require(isinstance(check, dict) and set(check) == {"name", "passed"},
                "Malformed foundation detail check")
        name = check["name"]
        require(isinstance(name, str) and re.fullmatch(r"[a-z0-9_]{1,80}", name) is not None,
                "Invalid foundation detail check name")
        require(name not in names and check["passed"] is True,
                "Foundation detail checks contain a duplicate or a failed check")
        names.add(name)
    require(FOUNDATION_DETAIL_CHECKS <= names, "Required foundation world/state/session checks are missing")


def validate_player(result: dict, identity: dict) -> None:
    """Require the native player witnesses, anchored to this isolated build."""
    require(isinstance(result, dict) and set(result) == PLAYER_FIELDS,
            "Phase 8 player proof has missing or unexpected fields")
    require(type(result.get("schemaVersion")) is int and result["schemaVersion"] == 1,
            "Unsupported player proof schema")
    require(result.get("identity") == identity, "Player embedded identity differs from package identity")
    require(result.get("success") is True and result.get("gameSaveAccessed") is False,
            "Player proof failed or accessed existing game saves")
    checks = result.get("checks")
    require(isinstance(checks, list) and bool(checks), "Player detail checks are missing")
    names = set()
    for check in checks:
        require(isinstance(check, dict) and set(check) == {"name", "passed"},
                "Malformed player detail check")
        name = check["name"]
        require(isinstance(name, str) and re.fullmatch(r"[a-z0-9_]{1,80}", name) is not None,
                "Invalid player detail check name")
        require(name not in names and check["passed"] is True,
                "Player detail checks contain a duplicate or a failed check")
        names.add(name)
    require(PLAYER_DETAIL_CHECKS <= names, "Required player motion/input/world checks are missing")


def validate_persistence(result: dict, identity: dict) -> None:
    """Require isolated save/settings fixtures and safe storage witnesses."""
    require(isinstance(result, dict) and set(result) == PERSISTENCE_FIELDS,
            "Phase 9 persistence proof has missing or unexpected fields")
    require(type(result.get("schemaVersion")) is int and result["schemaVersion"] == 1,
            "Unsupported persistence proof schema")
    require(result.get("identity") == identity,
            "Persistence embedded identity differs from package identity")
    require(result.get("success") is True and result.get("gameSaveAccessed") is False,
            "Persistence proof failed or accessed existing game saves")
    checks = result.get("checks")
    require(isinstance(checks, list) and bool(checks), "Persistence detail checks are missing")
    names = set()
    for check in checks:
        require(isinstance(check, dict) and set(check) == {"name", "passed"},
                "Malformed persistence detail check")
        name = check["name"]
        require(isinstance(name, str) and re.fullmatch(r"[a-z0-9_]{1,80}", name) is not None,
                "Invalid persistence detail check name")
        require(name not in names and check["passed"] is True,
                "Persistence detail checks contain a duplicate or a failed check")
        names.add(name)
    require(PERSISTENCE_DETAIL_CHECKS <= names,
            "Required persistence save/settings/store checks are missing")


def validate_route(result: dict, identity: dict) -> None:
    """Require a playable route witness from the exact isolated native build."""
    require(isinstance(result, dict) and set(result) == ROUTE_FIELDS,
            "Phase 10 route proof has missing or unexpected fields")
    require(type(result.get("schemaVersion")) is int and result["schemaVersion"] == 1,
            "Unsupported route proof schema")
    require(result.get("identity") == identity, "Route embedded identity differs from package identity")
    require(result.get("success") is True and result.get("gameSaveAccessed") is False,
            "Route proof failed or accessed existing game saves")
    checks = result.get("checks")
    require(isinstance(checks, list) and bool(checks), "Route detail checks are missing")
    names = set()
    for check in checks:
        require(isinstance(check, dict) and set(check) == {"name", "passed"}, "Malformed route detail check")
        name = check["name"]
        require(isinstance(name, str) and re.fullmatch(r"[a-z0-9_]{1,80}", name) is not None,
                "Invalid route detail check name")
        require(name not in names and check["passed"] is True,
                "Route detail checks contain a duplicate or a failed check")
        names.add(name)
    require(ROUTE_DETAIL_CHECKS <= names, "Required playable route checks are missing")


def validate_world_access(result: dict, identity: dict) -> None:
    """Require the original entrances and world travel to run in this exact player."""
    require(isinstance(result, dict) and set(result) == WORLD_ACCESS_FIELDS,
            "Phase 11 world access proof has missing or unexpected fields")
    require(type(result.get("schemaVersion")) is int and result["schemaVersion"] == 1,
            "Unsupported world access proof schema")
    require(result.get("identity") == identity, "World access embedded identity differs from package identity")
    require(result.get("success") is True and result.get("gameSaveAccessed") is False,
            "World access proof failed or accessed existing game saves")
    checks = result.get("checks")
    require(isinstance(checks, list) and bool(checks), "World access detail checks are missing")
    names = set()
    for check in checks:
        require(isinstance(check, dict) and set(check) == {"name", "passed"}, "Malformed world access detail check")
        name = check["name"]
        require(isinstance(name, str) and re.fullmatch(r"[a-z0-9_]{1,80}", name) is not None,
                "Invalid world access detail check name")
        require(name not in names and check["passed"] is True,
                "World access detail checks contain a duplicate or a failed check")
        names.add(name)
    require(WORLD_ACCESS_DETAIL_CHECKS <= names, "Required world access checks are missing")


def _validate_runtime_inputs(receipt: dict, payload: dict[str, bytes]) -> None:
    packages = receipt.get("unityPackages")
    require(isinstance(packages, list) and bool(packages), "Phase 8 resolved package identities are missing")
    packages_seen = set()
    for row in packages:
        require(isinstance(row, dict) and set(row) == {"name", "version", "source"},
                "Malformed resolved Unity package identity")
        name = row["name"]
        require(isinstance(name, str) and name not in packages_seen and
                (name.startswith("com.unity.modules.") or name == "com.unity.inputsystem") and
                isinstance(row["version"], str) and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", row["version"]) is not None and
                row["source"] == ("registry" if name == "com.unity.inputsystem" else "builtin"),
                "Invalid or duplicate resolved Unity package identity")
        packages_seen.add(name)
    require("com.unity.inputsystem" in packages_seen, "Native Input System package identity is missing")
    rows = receipt.get("runtimeDllInputs")
    require(isinstance(rows, list) and bool(rows), "Phase 8 native runtime DLL witnesses are missing")
    seen = set()
    for row in rows:
        require(isinstance(row, dict) and set(row) == {"name", "bytes", "sha256"}, "Malformed runtime DLL witness")
        name = row["name"]
        require(isinstance(name, str) and re.fullmatch(r"[A-Za-z0-9_.-]+\.dll", name) is not None and name not in seen,
                "Unsafe or duplicate runtime DLL witness")
        seen.add(name)
        target = "BlueMapUnityProbe_Data/Managed/" + name
        require(target in payload and type(row["bytes"]) is int and row["bytes"] == len(payload[target]) and
                isinstance(row["sha256"], str) and re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) is not None and
                row["sha256"] == hashlib.sha256(payload[target]).hexdigest(),
                "Packaged runtime DLL differs from its build source witness")
    require("Unity.InputSystem.dll" in seen, "Native Input System DLL witness is missing")


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
    description = {
        3: "Migratiefase 3: deze kleine controlebuild is nog niet de overgezette game.\n",
        6: "Migratiefase 6: originele beelden, animaties, audio en teksten; nog niet de overgezette game.\n",
        7: "Migratiefase 7: technische spelbasis en originele presentatie; nog niet de overgezette game.\n",
        8: "Migratiefase 8: speler, camera en bediening; nog niet de volledige overgezette game.\n",
        9: "Migratiefase 9: veilige opslag en import van saves en instellingen; nog niet de volledige overgezette game.\n",
        10: "Migratiefase 10: eerste speelbare route tussen dorp, woning en bos; nog niet de volledige overgezette game.\n",
        11: "Migratiefase 11: alle 37 gebieden, interieurs en toegangspunten; nog niet de volledige overgezette game.\n",
    }
    controls = (
        "9: veilige opslag, import en instellingen; 8: loopwereld.\n"
        "Bronbestanden worden uitsluitend gelezen nadat je ze zelf kiest.\n"
        "De automatische controle gebruikt alleen eigen testbestanden.\n"
        "De Unity-proef bewaart gegevens apart van de bestaande Godot-game.\n"
        if identity["phase"] >= 9 else ""
    ) + (
        "De proef start in de loopwereld (pagina 8).\n"
        "WASD / pijlen: lopen; Ctrl vasthouden: rennen; Shift / K: rollen; muis: richten.\n"
        "Controller: linkerstick lopen; L3 vasthouden rennen; B rollen; rechterstick richten.\n"
        "P / Esc / Start: pauze; F1 dorp; F2 bos; F3 grot (gebiedskeuze voor deze proef).\n"
        "F9: bediening aanpassen in het geheugen van deze proef; nog geen instellingenopslag.\n"
        "1-6: oorspronkelijke presentatie; 7: spelbasis; 8: loopwereld.\n"
        "Buiten de loopwereld sluit Esc de proef.\n"
        "Omrande objectvoeten tonen botsingsruimte van nog niet volledig overgezette objecten.\n"
        if identity["phase"] >= 8 else
        ("WASD / pijlen: verplaatsen; Esc: sluiten.\n" if identity["phase"] == 3 else
         "1-6: galerijpagina; M: muziek; N: muziek stoppen; Spatie: geluid; Esc: sluiten.\n"))
    if identity["phase"] >= 9:
        controls = controls.replace("De proef start in de loopwereld (pagina 8).\n",
                                    "De proef start bij Opslag en instellingen (pagina 9).\n")
        controls = controls.replace(
            "F9: bediening aanpassen in het geheugen van deze proef; nog geen instellingenopslag.\n",
            "F9 / I / Tab / controller Select: bediening aanpassen.\n"
            "Gekoppeld profiel: gewijzigde bediening wordt in een nieuwe veilige revisie bewaard.\n"
            "Zonder gekoppeld profiel blijft gewijzigde bediening tijdelijk.\n")
        controls += ("Pagina 9: zelf importpad kiezen, een kopie importeren, een Unity-profiel openen,\n"
                     "de vorige revisie herstellen en taal/geluid instellen.\n"
                     "De loopproef overschrijft nooit het geïmporteerde avontuur.\n")
    if identity["phase"] >= 10:
        controls = (
            "De proef start bij Avontuur en opslag (pagina 9).\n"
            "Start een nieuw avontuur, hervat een Unity-speelprofiel of maak een veilige speelkopie.\n"
            "De route verbindt dorp, woning, bosrand en bos via de oorspronkelijke doorgangen.\n"
            "WASD / pijlen: lopen; Ctrl vasthouden: rennen; Shift / K: rollen; muis: richten.\n"
            "Controller: linkerstick lopen; L3 vasthouden rennen; B rollen; rechterstick richten.\n"
            "E / Enter / controller A: gebruiken en praten.\n"
            "I / Tab / Select: inventaris; Q / LB: opdrachten; F9: bediening aanpassen.\n"
            "Esc / P / Start: pauzemenu met bewaren, laden en terug naar profielen; F5: snel bewaren.\n"
            "Doorgangen werken tijdens het spelen zonder gebiedskeuzetoetsen.\n"
            "1-6: oorspronkelijke presentatie; 7: spelbasis; 8: loopproef; 9: profielen (buiten een avontuur).\n"
            "De afzonderlijke loopproef bewaart geen spelvoortgang.\n"
            "Bronbestanden worden uitsluitend gelezen nadat je ze zelf kiest.\n"
            "Het oorspronkelijke importprofiel blijft bewaard naast de afzonderlijke speelkopie.\n"
            "De automatische controle gebruikt alleen eigen testbestanden.\n"
            "De Unity-proef bewaart gegevens apart van de bestaande Godot-game.\n"
        )
    if identity["phase"] >= 11:
        controls = controls.replace(
            "De route verbindt dorp, woning, bosrand en bos via de oorspronkelijke doorgangen.\n",
            "Alle 37 bestaande gebieden en interieurs gebruiken hun oorspronkelijke doorgangen en questsloten.\n"
            "Bewaren en laden behouden de bezochte gebieden en je voortgang in de afzonderlijke speelkopie.\n")
    return (
        "BLUEMAP QUEST - UNITY TECHNISCHE PREVIEW\n\n" +
        description[identity["phase"]] +
        "De bestaande Godot-game en het herstelpunt blijven apart beschikbaar.\n\n"
        "Pak de volledige map uit en start BlueMapUnityProbe.exe.\n"
        "Laat alle bijbehorende bestanden en de BlueMapUnityProbe_Data-map staan.\n"
        + controls +
        ("Deze proef wijzigt geen opslagbestanden van de bestaande game.\n\n" if identity["phase"] >= 9 else
           "Deze proef gebruikt geen opslagbestanden van de bestaande game.\n\n") +
        f"Preview: {identity['previewVersion']}\nBroncommit: {identity['sourceCommit']}\n"
        f"Bronvingerafdruk: {identity['inputFingerprint']}\n"
        f"Unity {EDITOR_VERSION} ({EDITOR_REVISION}), Windows x64 / Mono.\n"
        "BUILD-IDENTITY.json en RUNTIME-CHECKS.json beschrijven deze controlebuild.\n"
        + ("FOUNDATION-CHECKS.json bevat de controles van de technische spelbasis.\n" if identity["phase"] >= 7 else "") +
        ("PLAYER-CHECKS.json bevat de controles van speler, camera en bediening.\n" if identity["phase"] >= 8 else "") +
        ("PERSISTENCE-CHECKS.json bevat de controles met eigen opslag- en importtestbestanden.\n" if identity["phase"] >= 9 else "") +
        ("ROUTE-CHECKS.json bevat de controles van de eerste speelbare route.\n" if identity["phase"] >= 10 else "") +
        ("WORLD-ACCESS-CHECKS.json bevat de controles van alle gebieden en toegangspunten.\n" if identity["phase"] >= 11 else "") +
        "FILES.json bevat de bestanden, groottes en SHA256-controlesommen.\n"
    ).encode("utf-8")


def package_player(player: Path, output: Path, identity: dict,
                   runtime_result: dict, foundation_result: dict | None = None,
                   player_result: dict | None = None,
                   persistence_result: dict | None = None,
                   route_result: dict | None = None,
                   world_access_result: dict | None = None) -> tuple[Path, int]:
    """Package only the verified runtime payload; never include surrounding logs."""
    validate_identity(identity)
    _validate_runtime(runtime_result, identity)
    if identity["phase"] >= 7:
        validate_foundation(foundation_result, identity)
    else:
        require(foundation_result is None, "Historical preview cannot contain phase 7 foundation proof")
    if identity["phase"] >= 8:
        validate_player(player_result, identity)
    else:
        require(player_result is None, "Historical preview cannot contain phase 8 player proof")
    if identity["phase"] >= 9:
        validate_persistence(persistence_result, identity)
    else:
        require(persistence_result is None, "Historical preview cannot contain phase 9 persistence proof")
    if identity["phase"] >= 10:
        validate_route(route_result, identity)
    else:
        require(route_result is None, "Historical preview cannot contain phase 10 route proof")
    if identity["phase"] >= 11:
        validate_world_access(world_access_result, identity)
    else:
        require(world_access_result is None, "Historical preview cannot contain phase 11 world access proof")
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
    if foundation_result is not None:
        payload["FOUNDATION-CHECKS.json"] = _json_bytes(foundation_result)
    if player_result is not None:
        payload["PLAYER-CHECKS.json"] = _json_bytes(player_result)
    if persistence_result is not None:
        payload["PERSISTENCE-CHECKS.json"] = _json_bytes(persistence_result)
    if route_result is not None:
        payload["ROUTE-CHECKS.json"] = _json_bytes(route_result)
    if world_access_result is not None:
        payload["WORLD-ACCESS-CHECKS.json"] = _json_bytes(world_access_result)
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
    if identity["phase"] >= 8:
        require(PLAYER_INPUT_DLL in payload, "Phase 8 native Input System runtime is missing")
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
    if identity["phase"] >= 8:
        require(PLAYER_INPUT_DLL in payload, "Phase 8 native Input System runtime is missing")
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
    if identity["phase"] >= 7:
        require("FOUNDATION-CHECKS.json" in payload, "Phase 7 packaged foundation proof is missing")
        foundation = _json(payload["FOUNDATION-CHECKS.json"], "FOUNDATION-CHECKS.json")
        validate_foundation(foundation, identity)
        require(receipt.get("foundation") == foundation, "Receipt foundation proof differs from package")
    else:
        require("FOUNDATION-CHECKS.json" not in payload and "foundation" not in receipt,
                "Historical preview contains unsupported foundation proof")
    if identity["phase"] >= 8:
        require("PLAYER-CHECKS.json" in payload, "Phase 8 packaged player proof is missing")
        player = _json(payload["PLAYER-CHECKS.json"], "PLAYER-CHECKS.json")
        validate_player(player, identity)
        require(receipt.get("player") == player, "Receipt player proof differs from package")
        _validate_runtime_inputs(receipt, payload)
    else:
        require("PLAYER-CHECKS.json" not in payload and "player" not in receipt,
                "Historical preview contains unsupported player proof")
    if identity["phase"] >= 9:
        require("PERSISTENCE-CHECKS.json" in payload, "Phase 9 packaged persistence proof is missing")
        persistence = _json(payload["PERSISTENCE-CHECKS.json"], "PERSISTENCE-CHECKS.json")
        validate_persistence(persistence, identity)
        require(receipt.get("persistence") == persistence,
                "Receipt persistence proof differs from package")
    else:
        require("PERSISTENCE-CHECKS.json" not in payload and "persistence" not in receipt,
                "Historical preview contains unsupported persistence proof")
    if identity["phase"] >= 10:
        require("ROUTE-CHECKS.json" in payload, "Phase 10 packaged route proof is missing")
        route = _json(payload["ROUTE-CHECKS.json"], "ROUTE-CHECKS.json")
        validate_route(route, identity)
        require(receipt.get("route") == route, "Receipt route proof differs from package")
    else:
        require("ROUTE-CHECKS.json" not in payload and "route" not in receipt,
                "Historical preview contains unsupported route proof")
    if identity["phase"] >= 11:
        require("WORLD-ACCESS-CHECKS.json" in payload, "Phase 11 packaged world access proof is missing")
        access = _json(payload["WORLD-ACCESS-CHECKS.json"], "WORLD-ACCESS-CHECKS.json")
        validate_world_access(access, identity)
        require(receipt.get("worldAccess") == access, "Receipt world access proof differs from package")
    else:
        require("WORLD-ACCESS-CHECKS.json" not in payload and "worldAccess" not in receipt,
                "Historical preview contains unsupported world access proof")
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
