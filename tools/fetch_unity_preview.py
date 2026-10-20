#!/usr/bin/env python3
"""Download and verify a locally built Unity preview; this does not compile Unity."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import urllib.parse
import urllib.request

from build_unity_probe import collect_build_inputs
from verify_unity_package import PackageError, verify_package, PREVIEW_VERSIONS

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "sjorswakka-sketch/bluemap"


def require(condition, message):
    if not condition:
        raise PackageError(message)


def validate_preview_reference(manifest):
    """Reject cross-phase references before Git lookups or release downloads."""
    require(isinstance(manifest, dict) and type(manifest.get("schemaVersion")) is int and
            manifest["schemaVersion"] == 1, "Unknown preview reference format")
    commit = manifest.get("sourceCommit", "")
    require(isinstance(commit, str) and re.fullmatch(r"[0-9a-f]{40}", commit) is not None and
            commit != "0" * 40, "Invalid preview source commit")
    phase = manifest.get("phase")
    require(type(phase) is int and phase in PREVIEW_VERSIONS and
            manifest.get("previewVersion") == PREVIEW_VERSIONS[phase], "Unsupported preview phase/version")
    name = manifest.get("packageName", "")
    require(name == f"BlueMapUnityPreview-phase-{phase:02d}-{commit[:8]}-Windows-x64.zip",
            "Unexpected preview filename")
    return phase, commit, name


def fetch(url, target, expected_sha, max_bytes):
    parsed = urllib.parse.urlparse(url)
    require(parsed.scheme == "https" and parsed.netloc == "github.com" and not parsed.query and
            not parsed.fragment and parsed.path.startswith("/" + REPOSITORY + "/releases/download/"),
            "Preview URLs must be public release assets from the same repository")
    require(re.fullmatch(r"[0-9a-f]{64}", expected_sha) is not None, "Invalid download checksum")
    request = urllib.request.Request(url, headers={"User-Agent": "BlueMap-Migration-Verification"})
    digest, count = hashlib.sha256(), 0
    with urllib.request.urlopen(request, timeout=120) as response, target.open("xb") as stream:
        while True:
            block = response.read(1024 * 1024)
            if not block:
                break
            count += len(block)
            require(count <= max_bytes, "Release asset exceeds the configured size limit")
            digest.update(block)
            stream.write(block)
    require(digest.hexdigest() == expected_sha, "Downloaded release checksum differs")
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=ROOT / "migration/preview.json")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    phase, commit, name = validate_preview_reference(manifest)
    require(subprocess.run(["git", "merge-base", "--is-ancestor", commit, "HEAD"], cwd=ROOT).returncode == 0,
            "Preview source must be an ancestor of the checked migration branch")
    _, _, fingerprint = collect_build_inputs(ROOT, commit)
    require(fingerprint == manifest.get("inputFingerprint"), "Preview fingerprint differs from its Git source")
    # A later evidence/docs commit may point back to the same actual build inputs.
    require(collect_build_inputs(ROOT, "HEAD")[2] == fingerprint,
            "Current build inputs have changed: publish a new preview before presenting it as current")
    output = args.output.resolve()
    require(not output.exists() or (output.is_dir() and not any(output.iterdir())),
            "Download output must be new or empty")
    require(not output.is_relative_to(ROOT) and not ROOT.is_relative_to(output),
            "Download output must be outside the checkout")
    output.mkdir(parents=True, exist_ok=True)
    receipt_path, package = output / "receipt.json", output / name
    fetch(manifest["receiptUrl"], receipt_path, manifest["receiptSha256"], 1024 * 1024)
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    size = fetch(manifest["packageUrl"], package, manifest["packageSha256"], 512 * 1024 * 1024)
    require(size == manifest.get("packageBytes"), "Preview download size differs")
    require(receipt.get("identity", {}).get("inputFingerprint") == fingerprint, "Receipt source fingerprint differs")
    require(receipt.get("identity", {}).get("phase") == phase and
            receipt["identity"].get("previewVersion") == manifest["previewVersion"],
            "Receipt phase/version differs from preview reference")
    report = verify_package(package, receipt, commit)
    report.update({"sourceAnchoredToGit": True, "inputFingerprint": fingerprint,
                   "locallyBuiltPackageOnly": True, "remoteUnityCompilation": False})
    (output / "download-verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("UNITY PREVIEW DOWNLOAD OK:", name, "source", commit[:8])
    print("This job verifies a locally built package; it does not compile or start Unity.")


if __name__ == "__main__":
    try:
        main()
    except (PackageError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        raise SystemExit("UNITY PREVIEW DOWNLOAD FAILED: " + str(error))
