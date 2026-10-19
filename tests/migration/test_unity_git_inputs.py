"""Bit-exact Git batch framing and historical Unity input fingerprints.

The recorded identity is only a source-input witness, not a claim that its
first player build passed. No Unity process, network or player save is used.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import build_unity_probe as build


def blob_id(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()


def frame(data: bytes) -> bytes:
    return blob_id(data).encode("ascii") + b" blob " + str(len(data)).encode("ascii") + b"\n" + data + b"\n"


class GitBatchFramingTests(unittest.TestCase):
    def read_mocked(self, ids, raw):
        with patch.object(build.subprocess, "check_output", return_value=raw) as git:
            result = build.read_git_blobs(ROOT, ids)
            git.assert_called_once_with(["git", "cat-file", "--batch"], cwd=ROOT,
                                        input=("\n".join(ids) + "\n").encode("ascii"))
            return result

    def reject(self, ids, raw, message=None):
        with patch.object(build.subprocess, "check_output", return_value=raw):
            if message:
                with self.assertRaisesRegex(build.ProbeError, message):
                    build.read_git_blobs(ROOT, ids)
            else:
                with self.assertRaises(build.ProbeError):
                    build.read_git_blobs(ROOT, ids)

    def test_binary_newlines_nuls_header_lookalikes_and_duplicate_requests_are_lossless(self):
        first = b"text\r\nsecond\n\0\xff\n"
        second = b"abc blob 7\nnot a header\n"
        ids = [blob_id(first), blob_id(second), blob_id(first)]
        self.assertEqual(self.read_mocked(ids, frame(first) + frame(second) + frame(first)),
                         {blob_id(first): first, blob_id(second): second})

    def test_empty_blob_and_empty_request_are_valid(self):
        self.assertEqual(self.read_mocked([blob_id(b"")], frame(b"")), {blob_id(b""): b""})
        with patch.object(build.subprocess, "check_output") as git:
            self.assertEqual(build.read_git_blobs(ROOT, []), {})
            git.assert_not_called()

    def test_invalid_identity_is_rejected_before_invoking_git(self):
        for invalid in ("HEAD", "0" * 39, "a" * 41, "A" * 40, "a" * 40 + "\n"):
            with self.subTest(identity=invalid), patch.object(build.subprocess, "check_output") as git:
                with self.assertRaises(build.ProbeError):
                    build.read_git_blobs(ROOT, [invalid])
                git.assert_not_called()

    def test_wrong_object_type_missing_object_and_wrong_identity_are_rejected(self):
        raw = b"valid source"
        wanted = blob_id(raw)
        for packet in ((wanted + " tree " + str(len(raw)) + "\n").encode() + raw + b"\n",
                       (wanted + " missing\n").encode(), frame(b"different blob")):
            with self.subTest(packet=packet[:70]):
                self.reject([wanted], packet, "different object")

    def test_correct_header_with_corrupted_payload_fails_git_sha1(self):
        raw = b"byte-exact\r\n\0\xff"
        packet = frame(raw)
        start = packet.index(b"\n") + 1
        corrupted = packet[:start] + bytes([packet[start] ^ 1]) + packet[start + 1:]
        self.reject([blob_id(raw)], corrupted, "identity does not match")

    def test_truncated_header_payload_and_invalid_boundary_are_rejected(self):
        raw = b"payload"
        wanted = blob_id(raw)
        for packet in (wanted.encode() + b" blob 7", frame(raw)[:-2], frame(raw)[:-1] + b"\r",
                       (wanted + " blob 536870913\n").encode()):
            with self.subTest(packet=packet[:70]):
                self.reject([wanted], packet)

    def test_declared_size_cannot_consume_the_next_blob_frame(self):
        first, second = b"first", b"second"
        packet = frame(first).replace(b" blob 5\n", b" blob 6\n", 1) + frame(second)
        self.reject([blob_id(first), blob_id(second)], packet)

    def test_trailing_data_or_an_unrequested_extra_object_are_rejected(self):
        raw = b"source"
        for extra in (b"\n", b"unreviewed bytes", frame(b"extra object")):
            with self.subTest(extra=extra[:30]):
                self.reject([blob_id(raw)], frame(raw) + extra, "after Git batch")


class RealGitInputTests(unittest.TestCase):
    def test_real_git_fixture_keeps_crlf_and_binary_bytes_even_when_checkout_differs(self):
        with tempfile.TemporaryDirectory(prefix="BlueMap-Git-Batch-Tests-") as temporary:
            root = Path(temporary)
            subprocess.run(["git", "init", "--quiet", str(root)], check=True, capture_output=True)
            subprocess.run(["git", "config", "core.autocrlf", "false"], cwd=root, check=True)
            files = {"tools/build_unity_probe.py": b"# fixture helper\r\n",
                     "tools/verify_unity_package.py": b"# fixture verifier\n",
                     "unity/.gdignore": b"\n",
                     "unity/Assets/CRLF.txt": b"first\r\nsecond\r\n",
                     "unity/Assets/binary.bytes": b"\x00\xff\r\n\nblob\x00raw"}
            for name, data in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            subprocess.run(["git", "add", "--all"], cwd=root, check=True, capture_output=True)
            subprocess.run(["git", "-c", "user.name=BlueMap Fixture", "-c", "user.email=fixture@example.invalid",
                            "commit", "--quiet", "-m", "Private input-byte fixture"],
                           cwd=root, check=True, capture_output=True)
            commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root).decode().strip()
            (root / "unity/Assets/CRLF.txt").write_bytes(b"first\nsecond\n")
            (root / "unity/Assets/binary.bytes").write_bytes(b"changed working tree")
            source, inputs, fingerprint, copied = build._collect_build_input_data(root, commit)
            self.assertEqual(source, commit)
            self.assertEqual(copied, files)
            self.assertEqual(build.collect_build_inputs(root, commit), (source, inputs, fingerprint))
            for entry in inputs:
                self.assertEqual(entry["bytes"], len(files[entry["path"]]))
                self.assertEqual(entry["sha256"], hashlib.sha256(files[entry["path"]]).hexdigest())
            requested = [blob_id(data) for data in files.values()]
            self.assertEqual(build.read_git_blobs(root, requested), {blob_id(data): data for data in files.values()})

    def test_historical_5352b446_fingerprint_matches_preserved_identity(self):
        fixture = Path(__file__).with_name("fixtures") / "phase6-first-build-identity.json"
        identity = json.loads(fixture.read_text(encoding="utf-8"))
        source, inputs, fingerprint, copied = build._collect_build_input_data(ROOT, identity["sourceCommit"])
        self.assertEqual(source, "5352b446902c1c188c3abadbed0ae0d42e3d5ba3")
        self.assertEqual(fingerprint, "80e229a771c77c5cd0143e913f59e8ff2d5a2b19839dc05df395e740f24fd2d2")
        self.assertEqual(fingerprint, identity["inputFingerprint"])
        self.assertEqual(len(inputs), 876)
        self.assertEqual(set(copied), {entry["path"] for entry in inputs})
        self.assertEqual(build.collect_build_inputs(ROOT, source), (source, inputs, fingerprint))


if __name__ == "__main__":
    unittest.main()
